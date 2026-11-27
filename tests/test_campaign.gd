extends SceneTree

# Точечная проверка игрового цикла третьего этапа и контента восьмого этапа.
# Запуск: godot --headless --path . --script tests/test_campaign.gd
# Полная сборка APK для этой проверки не требуется.

const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const CampaignCatalog = preload("res://scripts/campaign/campaign_catalog.gd")
const CampaignState = preload("res://scripts/campaign/campaign_state.gd")
const ModeCatalog = preload("res://scripts/campaign/mode_catalog.gd")
const ProgressionCatalog = preload("res://scripts/progression/progression_catalog.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	print("Проверка игрового цикла и контента восьмого этапа")
	var data: Dictionary = CombatCatalog.load_balance()
	_check("Файл баланса загружен", not data.is_empty())
	_test_campaign_data(data)
	_test_progression(data)
	_test_boss_phase(data)
	_test_defeat_and_retry(data)
	_test_full_campaign(data)
	_test_auto_campaign_with_development(data)
	print("Итого: %d проверок пройдено, %d провалено" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(name: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("  ✓ ", name)
	else:
		failed += 1
		printerr("  ✗ ", name)


func _test_campaign_data(data: Dictionary) -> void:
	_check("Версия баланса восьмого этапа", int(data.get("version", 0)) == 8)
	var stages: Array = CampaignCatalog.stages(data)
	_check("Кампания содержит тридцать этапов", stages.size() == 30)
	var campaign_data: Dictionary = CampaignCatalog.campaign(data)
	_check("Один регион и пять глав", str(campaign_data.get("region", "")) == "Пепельные земли" and (campaign_data.get("chapters", []) as Array).size() == 5)
	var enemies: Dictionary = data.get("enemies", {}) as Dictionary
	var categories: Dictionary = {}
	for enemy_id in enemies.keys():
		var enemy_data: Dictionary = enemies[enemy_id] as Dictionary
		var category: String = str(enemy_data.get("category", ""))
		categories[category] = int(categories.get(category, 0)) + 1
	_check("Противники MVP: восемь обычных, три элиты, три босса", int(categories.get("обычный", 0)) == 8 and int(categories.get("элита", 0)) == 3 and int(categories.get("босс", 0)) == 3)
	_check("Три режима MVP", ModeCatalog.mode_ids(data).size() == 3)
	var rewards_valid: bool = true
	var ids_valid: bool = true
	var boss_count: int = 0
	var names: Dictionary = {}
	for stage in stages:
		if not stage is Dictionary:
			ids_valid = false
			rewards_valid = false
			continue
		var entry: Dictionary = stage as Dictionary
		var stage_name: String = str(entry.get("name", ""))
		names[stage_name] = true
		if CampaignCatalog.stage_is_boss(entry):
			boss_count += 1
		var reward: Dictionary = entry.get("reward", {}) as Dictionary
		if int(reward.get("experience", 0)) <= 0 or int(reward.get("gold", 0)) <= 0 or int(reward.get("materials", 0)) <= 0:
			rewards_valid = false
		var list: Array = CampaignCatalog.build_enemy_list(entry, data)
		if list.is_empty():
			ids_valid = false
		for enemy in list:
			if not enemies.has(str((enemy as Dictionary).get("id", ""))):
				ids_valid = false
	_check("Названия этапов не повторяются", names.size() == stages.size())
	_check("У каждого этапа есть противники из баланса", ids_valid)
	_check("У каждого этапа есть опыт, золото и пепел", rewards_valid)
	_check("В кампании семь боссовых этапов", boss_count == 7)
	var last_stage: Dictionary = CampaignCatalog.stage_at(data, stages.size() - 1)
	var final_enemies: Array = CampaignCatalog.build_enemy_list(last_stage, data)
	_check("Финальный босс собран", final_enemies.size() == 1)
	if final_enemies.size() == 1:
		var boss: Dictionary = final_enemies[0] as Dictionary
		_check("У финального босса своё имя", str(boss.get("name", "")) == "Хранитель бездны")
		_check("У финального босса задан порог фазы", float(boss.get("phase_threshold", 0.0)) > 0.0)
		_check("У финального босса задано усиление", float(boss.get("phase_attack_multiplier", 1.0)) > 1.0)


func _test_progression(data: Dictionary) -> void:
	var state = CampaignState.new(data)
	_check("Начальный этап первый", state.stage_number() == 1)
	_check("Начальный уровень первый", state.level == 1)
	_check("Начальное здоровье из баланса", is_equal_approx(float(state.hero_data().get("max_health", 0.0)), 120.0))
	_check("Начальный бой активен", state.status == CampaignState.STATUS_BATTLE and state.system.running)
	_check("Первый этап не босс", not CampaignCatalog.stage_is_boss(state.current_stage()))
	_check("Первый этап завершён победой", _finish_stage(state))
	_check("Статус победы", state.status == CampaignState.STATUS_VICTORY)
	_check("Начислен опыт первого этапа", state.experience == 45)
	_check("Начислено золото первого этапа", state.gold == 12)
	_check("Начислен пепел первого этапа", state.materials == 5)
	_check("Победа учтена один раз", state.victories == 1)
	_check("Уровень до порога не вырос", state.level == 1)
	var reward: Dictionary = state.last_reward
	_check("Награда содержит опыт, золото и пепел", int(reward.get("experience", 0)) == 45 and int(reward.get("gold", 0)) == 12 and int(reward.get("materials", 0)) == 5)
	_check("Переход ко второму этапу разрешён", state.next_stage())
	_check("Второй этап начался", state.stage_number() == 2 and state.status == CampaignState.STATUS_BATTLE)
	_check("Герой восстановлен перед этапом", is_equal_approx(state.system.hero.health, state.system.hero.max_health))
	_check("Второй этап завершён победой", _finish_stage(state))
	_check("После второго этапа получен уровень", state.level >= 2)
	_check("Порог опыта вырос", state.experience_to_next() > 100)
	_check("Здоровье героя выросло с уровнем", float(state.hero_data().get("max_health", 0.0)) > 120.0)
	_check("Переход к третьему этапу разрешён", state.next_stage())
	_check("Третий этап — босс", CampaignCatalog.stage_is_boss(state.current_stage()))
	_check("Противник третьего этапа помечен боссом", state.system.enemy.is_boss)
	_check("Сводка содержит регион и этап", str(state.get_summary().get("region", "")) == "Пепельные земли")


func _test_boss_phase(data: Dictionary) -> void:
	var state = CampaignState.new(data)
	var phases: Array = []
	var multipliers: Array = []
	state.boss_phase_started.connect(func(_enemy_name: String, phase_name: String): phases.append(phase_name))
	for stage_number in range(2):
		_check("Подготовка к боссу: этап %d пройден" % (stage_number + 1), _finish_stage(state))
		_check("Подготовка к боссу: переход %d" % (stage_number + 1), state.next_stage())
	_check("Босс ожидает фазу", state.system.enemy.is_boss and state.system.enemy.phase_threshold > 0.0)
	state.system.enemy_phase_started.connect(func(_enemy_name: String, _phase_name: String, multiplier: float): multipliers.append(multiplier))
	var initial_attack: float = state.system.enemy.attack
	_check("Бой с боссом завершён", _finish_stage(state))
	_check("Фаза босса выдала сигнал", phases.size() >= 1)
	_check("Фаза босса усиливает атаку", multipliers.size() >= 1 and float(multipliers[0]) > 1.0)
	_check("Атака босса была положительной", initial_attack > 0.0)
	_check("Фаза учтена в состоянии", state.boss_phase_count >= 1)
	_check("Состояние фазы сохранено", state.current_boss_phase_active)
	if phases.size() > 0:
		_check("Название фазы пришло из баланса", "пепла" in str(phases[0]))


func _test_defeat_and_retry(data: Dictionary) -> void:
	var weak_data: Dictionary = data.duplicate(true)
	var weak_hero: Dictionary = weak_data.get("hero", {}) as Dictionary
	weak_hero["max_health"] = 1
	weak_hero["attack"] = 1
	weak_hero["physical_attack"] = 1
	weak_hero["magic_attack"] = 0
	weak_hero["crit_chance"] = 0
	weak_hero["critical_multiplier"] = 1.0
	weak_hero["dodge"] = 0.0
	weak_hero["health_regen"] = 0.0
	weak_data["hero"] = weak_hero
	var state = CampaignState.new(weak_data)
	for step in range(10):
		state.advance(1.0)
		if state.status != CampaignState.STATUS_BATTLE:
			break
	_check("Слабый герой терпит поражение", state.status == CampaignState.STATUS_DEFEAT)
	_check("Поражение учтено", state.defeats == 1)
	_check("Опыт за поражение не начислен", state.experience == 0)
	_check("Повтор этапа разрешён", state.retry_stage())
	_check("Тот же этап после повтора", state.stage_number() == 1)
	_check("Бой после повтора активен", state.status == CampaignState.STATUS_BATTLE and state.system.hero.alive)


func _test_full_campaign(data: Dictionary) -> void:
	var state = CampaignState.new(data)
	var stages: int = CampaignCatalog.stage_count(data)
	for stage_number in range(stages):
		_check("Этап %d проходим" % (stage_number + 1), _finish_stage(state))
		if state.status == CampaignState.STATUS_VICTORY:
			_check("Переход после этапа %d" % (stage_number + 1), state.next_stage())
	_check("Кампания завершена", state.status == CampaignState.STATUS_COMPLETE)
	_check("Все этапы засчитаны", state.victories == stages)
	_check("Поражений в прохождении нет", state.defeats == 0)
	_check("Герой получил уровни", state.level > 1)
	_check("Золото накоплено", state.gold > 0)
	_check("Пепел накоплен", state.materials > 0)
	_check("Обе фазы боссов сработали", state.boss_phase_count >= 2)
	_check("Дальше финала перехода нет", not state.next_stage())
	var summary: Dictionary = state.get_summary()
	_check("Сводка сообщает о завершении", str(summary.get("status_name", "")) == "Кампания пройдена")
	_check("Новый поход разрешён", state.restart_campaign())
	_check("Новый поход начинается с первого этапа", state.stage_number() == 1 and state.level == 1)
	_check("Прогресс нового похода сброшен", state.gold == 0 and state.materials == 0 and state.experience == 0)
	_check("Инвентарь нового похода пуст", int(state.get_summary().get("inventory_count", -1)) == 0)


func _test_auto_campaign_with_development(data: Dictionary) -> void:
	# Проверяем критерий MVP: 30 этапов проходятся активным автобоем с обычным
	# развитием персонажа, без принудительной победы и случайной экипировки.
	var state = CampaignState.new(data, 4242)
	var stages: int = CampaignCatalog.stage_count(data)
	var cleared: int = 0
	for stage_number in range(stages):
		_prepare_development(state, stage_number + 1)
		if not _finish_auto_stage(state):
			break
		if state.status == CampaignState.STATUS_DEFEAT:
			break
		cleared += 1
		if state.status == CampaignState.STATUS_VICTORY and not state.next_stage():
			break
		if state.status == CampaignState.STATUS_COMPLETE:
			break
	_check("Тридцать этапов пройдены в автобое", cleared == stages and state.status == CampaignState.STATUS_COMPLETE)
	_check("Поражений при развитии героя нет", state.defeats == 0)
	_check("Герой вырос за полное прохождение", state.level >= 15)
	_check("Награды за тридцатый этап получены", int(state.last_reward.get("experience", 0)) > int(data.get("campaign", {}).get("stages", [])[0].get("reward", {}).get("experience", 0)))
	_check("Экипировка не нужна для проверки баланса", int(state.get_summary().get("inventory_count", -1)) == 0)


func _prepare_development(state, stage_number: int) -> void:
	for i in range(state.development.attribute_points):
		state.allocate_attribute("strength" if i % 3 < 2 else "stamina")
	for skill_id in ProgressionCatalog.skill_ids(state.balance):
		if ProgressionCatalog.is_skill_unlocked(state.balance, str(skill_id), state.level) and not state.development.is_skill_auto(str(skill_id)):
			state.toggle_skill_auto(str(skill_id))
	for i in range(4):
		var upgraded: bool = false
		for skill_id in ProgressionCatalog.skill_ids(state.balance):
			if bool(state.upgrade_skill(str(skill_id)).get("success", false)):
				upgraded = true
		if not upgraded:
			break
	for i in range(4):
		var improved: bool = false
		for passive_id in ProgressionCatalog.passive_ids(state.balance):
			if bool(state.upgrade_passive(str(passive_id)).get("success", false)):
				improved = true
		if not improved:
			break
	for pet_id in ProgressionCatalog.pet_ids(state.balance):
		if ProgressionCatalog.is_pet_unlocked(state.balance, str(pet_id), stage_number):
			state.select_pet(str(pet_id))
	for i in range(3):
		for pet_id in ProgressionCatalog.pet_ids(state.balance):
			state.upgrade_pet(str(pet_id))


func _finish_auto_stage(state) -> bool:
	for step in range(2000):
		if state.status != CampaignState.STATUS_BATTLE:
			return true
		if state.system == null:
			return false
		state.advance(0.1)
	return false


func _finish_stage(state, max_steps: int = 240) -> bool:
	for step in range(max_steps):
		if state.status != CampaignState.STATUS_BATTLE:
			return true
		if state.system == null:
			return false
		if state.get_cooldown_remaining("heavy_strike") <= 0.0:
			state.use_skill("heavy_strike")
		if state.system.hero.health < state.system.hero.max_health * 0.75 and state.get_cooldown_remaining("ash_guard") <= 0.0:
			state.use_skill("ash_guard")
		state.advance(1.0)
	return state.status != CampaignState.STATUS_BATTLE
