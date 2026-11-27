extends SceneTree

# Точечная проверка седьмого этапа: один регион, три режима, 30 этапов
# кампании, 30 ярусов Башни и три подземелья ресурсов.
# Запуск: godot --headless --path . --script tests/test_modes.gd

const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const CampaignCatalog = preload("res://scripts/campaign/campaign_catalog.gd")
const CampaignState = preload("res://scripts/campaign/campaign_state.gd")
const ModeCatalog = preload("res://scripts/campaign/mode_catalog.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	print("Проверка контента и режимов седьмого этапа")
	var data: Dictionary = CombatCatalog.load_balance()
	_check("Версия баланса седьмого этапа", int(data.get("version", 0)) == 7)
	_test_modes_data(data)
	_test_catalog(data)
	_test_state(data)
	_test_snapshots(data)
	print("Итого: %d проверок пройдено, %d провалено" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(name: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("  ✓ ", name)
	else:
		failed += 1
		printerr("  ✗ ", name)


static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


static func _array(value: Variant) -> Array:
	return value as Array if value is Array else []


func _test_modes_data(data: Dictionary) -> void:
	var modes: Dictionary = data.get("modes", {}) as Dictionary
	var list: Array = _array(modes.get("list", []))
	var ids: Array = ModeCatalog.mode_ids(data)
	_check("В данных ровно три режима", list.size() == 3 and ids == ["campaign", "tower", "dungeon"])
	_check("Кампания и Башня содержат по 30 шагов", CampaignCatalog.stage_count(data) == 30 and ModeCatalog.stage_count(data, "tower") == 30)
	_check("Подземелье — один повторяемый бой", ModeCatalog.stage_count(data, "dungeon") == 1)
	_check("Режимы открываются поэтапно", ModeCatalog.mode_unlock_stage(data, "campaign") == 1 and ModeCatalog.mode_unlock_stage(data, "tower") == 5 and ModeCatalog.mode_unlock_stage(data, "dungeon") == 8)

	var campaign: Dictionary = CampaignCatalog.campaign(data)
	_check("Один регион и пять глав", str(campaign.get("region", "")) == "Пепельные земли" and _array(campaign.get("chapters", [])).size() == 5)
	var enemies: Dictionary = data.get("enemies", {}) as Dictionary
	var categories: Dictionary = {}
	for enemy_id in enemies.keys():
		var category: String = str(_dict(enemies[enemy_id]).get("category", ""))
		categories[category] = int(categories.get(category, 0)) + 1
	_check("Восемь обычных, три элиты и три босса", int(categories.get("обычный", 0)) == 8 and int(categories.get("элита", 0)) == 3 and int(categories.get("босс", 0)) == 3)

	var floors: Array = ModeCatalog.tower_floors(data)
	var boss_floors: int = 0
	var floor_names: Dictionary = {}
	var floors_valid: bool = floors.size() == 30
	for floor_entry in floors:
		var floor_data: Dictionary = floor_entry as Dictionary
		var floor_name: String = str(floor_data.get("name", ""))
		if floor_name == "" or floor_names.has(floor_name):
			floors_valid = false
		floor_names[floor_name] = true
		if str(floor_data.get("kind", "")) == "босс":
			boss_floors += 1
		for wave in _array(floor_data.get("enemies", [])):
			if not enemies.has(str(_dict(wave).get("id", ""))):
				floors_valid = false
		var reward: Dictionary = _dict(floor_data.get("reward", {}))
		if int(reward.get("experience", 0)) <= 0 or int(reward.get("gold", 0)) <= 0 or int(reward.get("materials", 0)) <= 0:
			floors_valid = false
	_check("Тридцать уникальных ярусов с известными врагами и наградами", floors_valid)
	_check("Каждый пятый ярус завершается боссом", boss_floors == 6)

	var runs: Array = ModeCatalog.dungeon_runs(data)
	_check("Три подземелья ресурсов", runs.size() == 3 and ModeCatalog.dungeon_ids(data) == ["gold", "materials", "experience"])
	var runs_valid: bool = true
	for run in runs:
		var run_data: Dictionary = run as Dictionary
		var cost: Dictionary = _dict(run_data.get("entry_cost", {}))
		var reward: Dictionary = _dict(run_data.get("reward", {}))
		if int(cost.get("gold", 0)) < 0 or int(cost.get("materials", 0)) < 0:
			runs_valid = false
		if int(reward.get("experience", 0)) <= 0 or int(reward.get("gold", 0)) <= 0 or int(reward.get("materials", 0)) <= 0:
			runs_valid = false
		for wave in _array(run_data.get("enemies", [])):
			if not enemies.has(str(_dict(wave).get("id", ""))):
				runs_valid = false
	_check("Цены, награды и враги подземелий заданы в балансе", runs_valid)


func _test_catalog(data: Dictionary) -> void:
	var state: Dictionary = ModeCatalog.default_state(data)
	_check("Начальное состояние режимов", str(state.get("active_mode", "")) == "campaign" and int(state.get("dungeon_runs", -1)) == 0)
	_check("Каталог знает регионы режимов", ModeCatalog.mode_region(data, "campaign") == "Пепельные земли" and ModeCatalog.mode_region(data, "tower") == "Башня испытаний")
	_check("Башня закрыта на первом этапе", not ModeCatalog.is_mode_unlocked(data, "tower", 1) and "этапе 5" in ModeCatalog.mode_unlock_reason(data, "tower", 1))
	_check("Башня открыта на пятом этапе", ModeCatalog.is_mode_unlocked(data, "tower", 5))
	_check("Подземелья открыты на восьмом этапе", ModeCatalog.is_mode_unlocked(data, "dungeon", 8))

	var first_stage: Dictionary = ModeCatalog.stage_at(data, "campaign", 0, state)
	var first_floor: Dictionary = ModeCatalog.stage_at(data, "tower", 0, state)
	var dungeon_stage: Dictionary = ModeCatalog.stage_at(data, "dungeon", 0, state)
	_check("Каталог возвращает первый этап кампании", str(first_stage.get("name", "")) == "Тропа праха" and str(first_stage.get("mode_id", "")) == "campaign")
	_check("Каталог возвращает первый ярус", "Ярус 1" in str(first_floor.get("name", "")) and str(first_floor.get("region", "")) == "Башня испытаний")
	_check("Каталог собирает бой подземелья", str(dungeon_stage.get("dungeon_id", "")) == "gold" and not _array(dungeon_stage.get("enemies", [])).is_empty())
	var final_floor: Dictionary = ModeCatalog.stage_at(data, "tower", 29, state)
	var final_waves: Array = _array(final_floor.get("enemies", []))
	_check("Финальный ярус содержит босса", final_waves.size() == 1 and bool(_dict(final_waves[0]).get("boss", false)))

	_check("Прогресс кампании", "Этап 1/30" in ModeCatalog.progress_text(data, "campaign", state, 1, 30))
	_check("Прогресс башни", "Ярус 1/30" in ModeCatalog.progress_text(data, "tower", state, 1, 30))
	_check("Прогресс подземелья", "ЗОЛОТО" in ModeCatalog.progress_text(data, "dungeon", state, 1, 1))
	_check("Действия режимов различаются", ModeCatalog.action_text(data, "campaign", "victory", 1, state) == "ДАЛЬШЕ · ЭТАП 2" and ModeCatalog.action_text(data, "tower", "victory", 1, state) == "ВЫШЕ · ЯРУС 2")
	_check("Поражение и завершение имеют подписи", ModeCatalog.action_text(data, "dungeon", "defeat", 1, state) == "ПОВТОРИТЬ БОЙ" and ModeCatalog.action_text(data, "campaign", "complete", 30, state) == "НОВЫЙ ПОХОД")
	_check("Ключи статусов", ModeCatalog.status_key(CampaignState.STATUS_BATTLE) == "battle" and ModeCatalog.status_key(CampaignState.STATUS_VICTORY) == "victory" and ModeCatalog.status_key(CampaignState.STATUS_COMPLETE) == "complete")

	var normalized: Dictionary = ModeCatalog.normalize_state({
		"active_mode": "arena",
		"tower_floor": 999,
		"dungeon_id": "неизвестное",
		"dungeon_runs": -7,
		"mode_victories": {"tower": -4},
	}, data, 8)
	_check("Нормализация возвращает доступный режим", str(normalized.get("active_mode", "")) == "campaign" and int(normalized.get("tower_floor", -1)) <= 29)
	_check("Нормализация исправляет подземелье и счётчики", str(normalized.get("dungeon_id", "")) == "gold" and int(normalized.get("dungeon_runs", -1)) == 0 and int(_dict(normalized.get("mode_victories", {})).get("tower", -1)) == 0)
	_check("Сводка режимов показывает лучший ярус и победы", "Лучший ярус 1" in ModeCatalog.mode_stats_text(data, state) and "КАМПАНИЯ 0" in ModeCatalog.mode_stats_text(data, state))


func _test_state(data: Dictionary) -> void:
	var state = CampaignState.new(data, 31337)
	_check("Старт в кампании из 30 этапов", state.mode_id() == "campaign" and state.mode_count() == 30)
	var summary: Dictionary = state.get_summary()
	_check("Сводка содержит режим и прогресс", str(summary.get("mode_id", "")) == "campaign" and "Этап 1/30" in str(summary.get("mode_progress", "")))
	_check("Башня закрыта на старте", not state.mode_is_unlocked("tower") and not bool(state.select_mode("tower").get("success", false)))

	state.highest_stage = 5
	_check("Башня открыта на пятом этапе", state.mode_is_unlocked("tower"))
	_check("Выбор башни", bool(state.select_mode("tower").get("success", false)) and state.mode_id() == "tower" and state.mode_number() == 1 and state.mode_count() == 30)
	_check("Текущий ярус и регион", "Ярус 1" in str(state.current_stage().get("name", "")) and str(state.current_stage().get("region", "")) == "Башня испытаний")
	_check("Награда яруса приходит из баланса", int(_dict(state.current_stage().get("reward", {})).get("gold", 0)) > 0)
	state._register_victory()
	_check("Победа в башне даёт переход", state.status == CampaignState.STATUS_VICTORY and state.next_stage())
	_check("Второй ярус сохранён", state.mode_number() == 2 and int(state.mode_state_view().get("tower_floor", -1)) == 1)
	_check("Победа башни учтена отдельно", int(_dict(state.mode_state_view().get("mode_victories", {})).get("tower", 0)) == 1)

	state.mode_state["tower_floor"] = 29
	state.start_stage()
	state._register_victory()
	_check("Тридцатый ярус завершает башню", state.status == CampaignState.STATUS_COMPLETE and str(state.get_summary().get("status_name", "")) == "Башня пройдена")
	_check("Новый заход башни", state.restart_mode() and state.mode_number() == 1 and state.status == CampaignState.STATUS_BATTLE)
	_check("Новый поход кампании недоступен из башни", not state.restart_campaign())

	var dungeon = CampaignState.new(data, 31338)
	dungeon.highest_stage = 8
	_check("Подземелье закрыто без ресурсов", not bool(dungeon.select_dungeon("gold").get("success", false)) and "Нужно" in dungeon.dungeon_block_reason("gold"))
	dungeon.gold = 500
	dungeon.materials = 500
	var cost: Dictionary = ModeCatalog.dungeon_entry_cost(data, "gold")
	var gold_before: int = dungeon.gold
	var materials_before: int = dungeon.materials
	var selected: Dictionary = dungeon.select_dungeon("gold")
	_check("Вход в золотое подземелье", bool(selected.get("success", false)) and dungeon.mode_id() == "dungeon" and dungeon.mode_count() == 1)
	_check("Цена входа списана один раз", dungeon.gold == gold_before - int(cost.get("gold", 0)) and dungeon.materials == materials_before - int(cost.get("materials", 0)))
	_check("Заход учтён", int(dungeon.mode_state_view().get("dungeon_runs", 0)) == 1)
	_check("Бой подземелья собран из баланса", str(dungeon.current_stage().get("name", "")) == ModeCatalog.dungeon_name(data, "gold") and not dungeon.current_stage().is_empty())
	dungeon._register_victory()
	_check("Подземелье после победы можно повторить", dungeon.status == CampaignState.STATUS_VICTORY and dungeon.next_stage())
	_check("Повтор списывает цену и увеличивает счётчик", int(dungeon.mode_state_view().get("dungeon_runs", 0)) == 2)
	dungeon._register_victory()
	dungeon.gold = 0
	_check("Повтор без ресурсов запрещён", not dungeon.next_stage() and "Нужно" in dungeon.dungeon_block_reason("gold"))
	_check("Неизвестное подземелье недоступно", not bool(dungeon.select_dungeon("неизвестное").get("success", false)))


func _test_snapshots(data: Dictionary) -> void:
	var state = CampaignState.new(data, 424242)
	state.highest_stage = 20
	_check("Переход в башню для снимка", bool(state.select_mode("tower").get("success", false)))
	state.mode_state["tower_floor"] = 9
	state.mode_state["highest_tower_floor"] = 10
	state.mode_state["dungeon_id"] = "experience"
	state.mode_state["dungeon_runs"] = 4
	var wins: Dictionary = state.mode_state.get("mode_victories", {}) as Dictionary
	wins["dungeon"] = 3
	var snapshot: Dictionary = state.export_state()
	var restored = CampaignState.new(data, 999)
	restored.import_state(snapshot)
	_check("Снимок восстанавливает башню и ярус", restored.mode_id() == "tower" and restored.mode_number() == 10)
	_check("Снимок сохраняет лучший ярус и подземелье", int(restored.mode_state_view().get("highest_tower_floor", 0)) == 10 and str(restored.mode_state_view().get("dungeon_id", "")) == "experience")
	_check("Снимок сохраняет счётчики режимов", int(restored.mode_state_view().get("dungeon_runs", 0)) == 4 and int(_dict(restored.mode_state_view().get("mode_victories", {})).get("dungeon", 0)) == 3)
	var normalized: Dictionary = ModeCatalog.state_from_snapshot({
		"modes": {"active_mode": "campaign", "tower_floor": 7},
		"active_mode": "tower",
		"mode_index": 7,
	}, data, 20)
	_check("Поля совместимости переносятся в состояние режимов", str(normalized.get("active_mode", "")) == "tower" and int(normalized.get("tower_floor", -1)) == 7)
	var legacy = CampaignState.new(data, 111)
	legacy.import_state({"stage_index": 4, "status": CampaignState.STATUS_COMPLETE, "highest_stage": 5, "level": 4, "gold": 40, "materials": 12})
	_check("Снимок без режимов открывает кампанию", legacy.mode_id() == "campaign" and legacy.mode_count() == 30)
	_check("Старое завершение не обрывает 30 этапов", legacy.status == CampaignState.STATUS_BATTLE and legacy.stage_number() == 5)
