extends SceneTree

# Точечная проверка ТОЛЬКО прогрессии пятого этапа и её связи с боем.
# Запуск: godot --headless --path . --script tests/test_progression.gd
# Полная сборка APK для этой проверки не требуется.

const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const CombatFormulas = preload("res://scripts/combat/combat_formulas.gd")
const CombatSystem = preload("res://scripts/combat/combat_system.gd")
const Combatant = preload("res://scripts/combat/combatant.gd")
const CampaignCatalog = preload("res://scripts/campaign/campaign_catalog.gd")
const CampaignState = preload("res://scripts/campaign/campaign_state.gd")
const ProgressionCatalog = preload("res://scripts/progression/progression_catalog.gd")
const ProgressionState = preload("res://scripts/progression/progression_state.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	print("Проверка прогрессии пятого этапа")
	var data: Dictionary = CombatCatalog.load_balance()
	_check("Файл баланса загружен", not data.is_empty())
	_test_data(data)
	_test_catalog(data)
	_test_state(data)
	_test_derived_stats(data)
	_test_skill_map(data)
	_test_costs(data)
	_test_combat_formulas(data)
	_test_combat_system(data)
	_test_campaign_integration(data)
	_test_balance(data)
	print("Итого: %d проверок пройдено, %d провалено" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(name: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("  ✓ ", name)
	else:
		failed += 1
		printerr("  ✗ ", name)


func _test_data(data: Dictionary) -> void:
	_check("Версия баланса восьмого этапа", int(data.get("version", 0)) == 8)
	var hero: Dictionary = CombatCatalog.hero_data(data)
	_check("Один базовый класс задан", str(hero.get("class_name", "")) != "")
	_check("Характеристик пять", ProgressionCatalog.attributes(data).size() == 5)
	_check("Активных навыков шесть", ProgressionCatalog.skill_ids(data).size() == 6)
	_check("Пассивных способностей три", ProgressionCatalog.passive_ids(data).size() == 3)
	_check("Питомцев три", ProgressionCatalog.pet_ids(data).size() == 3)
	_check("Вариантов развития два", ProgressionCatalog.skill_variants(data).size() == 2)
	var stages: Array = CampaignCatalog.stages(data)
	_check("Целей баланса по числу этапов", ProgressionCatalog.stage_power_targets(data).size() == stages.size())
	var skills_valid: bool = true
	for skill_id in ProgressionCatalog.skill_ids(data):
		var skill: Dictionary = ProgressionCatalog.skill_by_id(data, str(skill_id))
		if skill.is_empty() or float(skill.get("cooldown_seconds", 0.0)) <= 0.0 or int(skill.get("max_level", 0)) <= 0 or not skill.has("auto_use"):
			skills_valid = false
	_check("У каждого навыка есть откат, предел и авто-режим", skills_valid)
	var passives_valid: bool = true
	for passive_id in ProgressionCatalog.passive_ids(data):
		var passive: Dictionary = ProgressionCatalog.passive_by_id(data, str(passive_id))
		if passive.is_empty() or (passive.get("bonuses", {}) as Dictionary).is_empty():
			passives_valid = false
	_check("У каждой пассивной способности есть бонусы", passives_valid)
	var pets_valid: bool = true
	for pet_id in ProgressionCatalog.pet_ids(data):
		var pet: Dictionary = ProgressionCatalog.pet_by_id(data, str(pet_id))
		var assist: Dictionary = pet.get("assist", {}) as Dictionary
		if pet.is_empty() or (pet.get("base_bonuses", {}) as Dictionary).is_empty() or float(assist.get("attack_ratio", 0.0)) <= 0.0:
			pets_valid = false
	_check("У каждого питомца есть бонусы и помощь в бою", pets_valid)
	var coefficients: Dictionary = ProgressionCatalog.coefficients(data)
	var coefficients_valid: bool = not coefficients.is_empty()
	for key in coefficients.keys():
		if float(coefficients[str(key)]) <= 0.0:
			coefficients_valid = false
	_check("Все коэффициенты характеристик положительные", coefficients_valid)
	var combat: Dictionary = CombatCatalog.combat_balance(data)
	_check("Пределы боевых параметров заданы", float(combat.get("max_lifesteal", 0.0)) > 0.0 and float(combat.get("max_dodge", 0.0)) > 0.0 and float(combat.get("max_resistance", 0.0)) > 0.0)
	var weights: Dictionary = ProgressionCatalog.power_weights(data)
	_check("Веса оценки силы заданы", not weights.is_empty() and float(weights.get("max_health", 0.0)) > 0.0)


func _test_catalog(data: Dictionary) -> void:
	_check("До мягкого предела очки работают полностью", is_equal_approx(ProgressionCatalog.effective_points(data, 10), 10.0))
	_check("После мягкого предела рост замедляется", is_equal_approx(ProgressionCatalog.effective_points(data, 20), 15.0))
	var ids: Array = ProgressionCatalog.attribute_ids(data)
	_check("Порядок характеристик сохранён", ids.size() == 5 and str(ids[0]) == "strength" and str(ids[4]) == "spirit")
	_check("Максимум очков характеристики положителен", ProgressionCatalog.attribute_max_points(data, "strength") > 0)
	_check("Идентификатор навыка находится", not ProgressionCatalog.skill_by_id(data, "heavy_strike").is_empty())
	_check("Идентификатор пассивной способности находится", not ProgressionCatalog.passive_by_id(data, "ashen_endurance").is_empty())
	_check("Идентификатор питомца находится", not ProgressionCatalog.pet_by_id(data, "ash_fox").is_empty())
	_check("Неизвестный питомец не находится", ProgressionCatalog.pet_by_id(data, "неизвестный").is_empty())
	_check("Пепельная лиса открыта с первого этапа", ProgressionCatalog.is_pet_unlocked(data, "ash_fox", 1))
	_check("Рунная сова закрыта на первом этапе", not ProgressionCatalog.is_pet_unlocked(data, "rune_owl", 1))
	_check("Рунная сова открыта на пятом этапе", ProgressionCatalog.is_pet_unlocked(data, "rune_owl", 5))
	_check("Навык четвёртого уровня закрыт на первом", not ProgressionCatalog.is_skill_unlocked(data, "soul_flare", 1))
	_check("Навык четвёртого уровня открыт на четвёртом", ProgressionCatalog.is_skill_unlocked(data, "soul_flare", 4))


func _test_state(data: Dictionary) -> void:
	var settings: Dictionary = ProgressionCatalog.leveling(data)
	var start_attributes: int = int(settings.get("starting_attribute_points", 0))
	var start_skills: int = int(settings.get("starting_skill_points", 0))
	var state = ProgressionState.new(data, 1)
	_check("Стартовые очки характеристик из баланса", state.attribute_points == start_attributes)
	_check("Стартовые очки навыков из баланса", state.skill_points == start_skills)
	_check("Характеристики изначально не распределены", int(state.get_attribute_points("strength")) == 0)
	_check("Уровни навыков изначально первые", state.get_skill_level("heavy_strike") == 1)
	_check("Вариант развития изначально «Мощь»", state.get_skill_variant("heavy_strike") == "power")
	_check("Авто-режим первого навыка из баланса", state.is_skill_auto("heavy_strike"))
	_check("Пассивные способности изначально нулевые", state.get_passive_level("ashen_endurance") == 0)
	_check("Питомец изначально не выбран", state.selected_pet_id == "")
	_check("Распределение очка выполняется", state.allocate_attribute("strength"))
	_check("Очко характеристики списано", state.attribute_points == start_attributes - 1)
	_check("Сила увеличена", state.get_attribute_points("strength") == 1)
	state.allocated["agility"] = ProgressionCatalog.attribute_max_points(data, "agility")
	state.attribute_points = 5
	_check("Предел характеристики не превышается", not state.allocate_attribute("agility"))
	state.grant_level_rewards(2)
	_check("Уровень даёт очки характеристик", state.attribute_points > 5)
	_check("Уровень даёт очки навыков", state.skill_points > start_skills)
	state.skill_points = 5
	_check("Очки навыков списываются", state.spend_skill_points(2))
	_check("Уровень навыка повышается", state.increase_skill_level("heavy_strike") and state.get_skill_level("heavy_strike") == 2)
	var auto_before: bool = state.is_skill_auto("heavy_strike")
	var auto_after: bool = state.toggle_skill_auto("heavy_strike")
	_check("Авто-режим переключается", auto_after != auto_before)
	_check("Вариант переключается на «Темп»", state.cycle_skill_variant("heavy_strike") == "haste")
	_check("Вариант возвращается к «Мощи»", state.cycle_skill_variant("heavy_strike") == "power")
	_check("Пассивная способность повышается", state.increase_passive_level("ashen_endurance") and state.get_passive_level("ashen_endurance") == 1)
	_check("Закрытый питомец не выбирается", not state.select_pet("rune_owl", 1))
	_check("Открытый питомец выбирается", state.select_pet("ash_fox", 1))
	_check("Выбранный питомец получает первый уровень", state.get_pet_level("ash_fox") == 1)
	_check("Питомец повышается", state.increase_pet_level("ash_fox") and state.get_pet_level("ash_fox") == 2)
	_check("Сводка содержит выбранного питомца", str(state.get_summary().get("selected_pet_name", "")) == "Пепельная лиса")
	state.reset()
	_check("Сброс возвращает стартовые очки", state.attribute_points == start_attributes and state.skill_points == start_skills)
	_check("Сброс очищает питомца", state.selected_pet_id == "")


func _test_derived_stats(data: Dictionary) -> void:
	var base_hero: Dictionary = CombatCatalog.hero_data(data)
	var leveling: Dictionary = ProgressionCatalog.leveling(data)
	var state = ProgressionState.new(data, 1)
	var empty_bonuses: Dictionary = ProgressionCatalog.empty_bonuses()
	var base_stats: Dictionary = ProgressionCatalog.build_hero_data(data, base_hero, 1, {}, empty_bonuses)
	_check("Базовое здоровье осталось из баланса", is_equal_approx(float(base_stats.get("max_health", 0.0)), 120.0))
	_check("Базовая атака осталась из баланса", is_equal_approx(float(base_stats.get("attack", 0.0)), 14.0))
	_check("Физическая и магическая атаки разделены", float(base_stats.get("physical_attack", 0.0)) > 0.0 and float(base_stats.get("magic_attack", 0.0)) == 0.0)
	var allocated: Dictionary = {}
	for attribute_id in ProgressionCatalog.attribute_ids(data):
		allocated[str(attribute_id)] = 5
	var bonuses: Dictionary = ProgressionCatalog.attribute_bonuses(data, allocated)
	var developed: Dictionary = ProgressionCatalog.build_hero_data(data, base_hero, 1, {}, bonuses)
	_check("Характеристики увеличивают здоровье", float(developed.get("max_health", 0.0)) > float(base_stats.get("max_health", 0.0)))
	_check("Характеристики увеличивают атаку", float(developed.get("attack", 0.0)) > float(base_stats.get("attack", 0.0)))
	_check("Характеристики увеличивают защиту", float(developed.get("defense", 0.0)) > float(base_stats.get("defense", 0.0)))
	_check("Ловкость ускоряет атаку", float(developed.get("attack_interval_seconds", 1.0)) < float(base_stats.get("attack_interval_seconds", 1.0)))
	_check("Дух добавляет вампиризм и сопротивление", float(developed.get("lifesteal", 0.0)) > 0.0 and float(developed.get("resistance", 0.0)) > 0.0)
	_check("Интеллект добавляет магическую атаку", float(developed.get("magic_attack", 0.0)) > 0.0)
	var passive_levels: Dictionary = {"ashen_endurance": 3, "cinder_precision": 2, "spirit_embrace": 2}
	var passive_bonuses: Dictionary = ProgressionCatalog.passive_bonuses(data, passive_levels)
	var with_passives: Dictionary = ProgressionCatalog.build_hero_data(data, base_hero, 1, {}, passive_bonuses)
	_check("Пассивные способности дают суммарный бонус", float(with_passives.get("max_health", 0.0)) > float(base_stats.get("max_health", 0.0)))
	var pet_levels: Dictionary = {"ash_fox": 2}
	var pet_bonuses: Dictionary = ProgressionCatalog.pet_bonuses(data, "ash_fox", pet_levels)
	var with_pet: Dictionary = ProgressionCatalog.build_hero_data(data, base_hero, 1, {}, pet_bonuses)
	_check("Питомец увеличивает атаку", float(with_pet.get("attack", 0.0)) > float(base_stats.get("attack", 0.0)))
	var total: Dictionary = ProgressionCatalog.total_bonuses(data, allocated, passive_levels, "ash_fox", pet_levels)
	_check("Общие бонусы сильнее отдельной характеристики", float(total.get("physical_attack", 0.0)) > float(bonuses.get("physical_attack", 0.0)))
	var equipment: Dictionary = {"attack": 5.0, "max_health": 10.0, "defense": 2.0}
	var with_equipment: Dictionary = ProgressionCatalog.build_hero_data(data, base_hero, 3, equipment, total)
	_check("Экипировка и уровень складываются с прогрессией", float(with_equipment.get("max_health", 0.0)) > float(with_pet.get("max_health", 0.0)))
	_check("Уровень из формулы прогрессии", float(with_equipment.get("max_health", 0.0)) >= 120.0 + 2.0 * float(leveling.get("max_health_per_level", 0.0)))
	var huge: Dictionary = ProgressionCatalog.empty_bonuses()
	huge["attack_speed"] = 100.0
	huge["lifesteal"] = 100.0
	huge["dodge"] = 100.0
	huge["resistance"] = 100.0
	huge["crit_chance"] = 100.0
	huge["critical_multiplier"] = 100.0
	huge["health_regen"] = 100.0
	var capped: Dictionary = ProgressionCatalog.build_hero_data(data, base_hero, 1, {}, huge)
	var combat: Dictionary = CombatCatalog.combat_balance(data)
	_check("Интервал атаки ограничен минимумом", is_equal_approx(float(capped.get("attack_interval_seconds", 0.0)), float(combat.get("min_attack_interval", 0.45))))
	_check("Вампиризм ограничен", is_equal_approx(float(capped.get("lifesteal", 0.0)), float(combat.get("max_lifesteal", 0.25))))
	_check("Уклонение ограничено", is_equal_approx(float(capped.get("dodge", 0.0)), float(combat.get("max_dodge", 0.25))))
	_check("Сопротивление ограничено", is_equal_approx(float(capped.get("resistance", 0.0)), float(combat.get("max_resistance", 0.35))))


func _test_skill_map(data: Dictionary) -> void:
	var state = ProgressionState.new(data, 1)
	var map_level1: Dictionary = state.get_effective_skill_map()
	_check("На первом уровне открыты два навыка", map_level1.size() == 2)
	_check("Закрытый навык четвёртого уровня не попал в карту", not map_level1.has("soul_flare"))
	state.set_level(4, false)
	var map_level4: Dictionary = state.get_effective_skill_map()
	_check("На четвёртом уровне открыты все шесть навыков", map_level4.size() == 6)
	var power: Dictionary = map_level4.get("heavy_strike", {}) as Dictionary
	state.cycle_skill_variant("heavy_strike")
	var haste: Dictionary = state.get_effective_skill_map().get("heavy_strike", {}) as Dictionary
	_check("Вариант «Темп» сокращает откат", float(haste.get("cooldown_seconds", 99.0)) < float(power.get("cooldown_seconds", 0.0)))
	_check("Вариант «Мощь» сильнее по урону", float(power.get("damage_multiplier", 0.0)) > float(haste.get("damage_multiplier", 0.0)))
	state.skill_levels["heavy_strike"] = 3
	var upgraded: Dictionary = state.get_effective_skill_map().get("heavy_strike", {}) as Dictionary
	_check("Уровень навыка увеличивает урон", float(upgraded.get("damage_multiplier", 0.0)) > float(haste.get("damage_multiplier", 0.0)))
	_check("Уровень навыка сокращает откат", float(upgraded.get("cooldown_seconds", 99.0)) < float(haste.get("cooldown_seconds", 0.0)))
	_check("Авто-навыки перечисляются", state.get_auto_skill_ids().size() >= 2)
	_check("Карта навыков хранит вариант", str(upgraded.get("variant", "")) == "haste")
	_check("Карта навыков хранит авто-режим", upgraded.has("auto_use"))


func _test_costs(data: Dictionary) -> void:
	var state = ProgressionState.new(data, 4)
	var skill_cost: Dictionary = state.get_skill_upgrade_cost("heavy_strike")
	_check("Стоимость навыка положительная", bool(skill_cost.get("valid", false)) and int(skill_cost.get("gold", 0)) > 0 and int(skill_cost.get("materials", 0)) > 0)
	state.skill_levels["heavy_strike"] = 5
	_check("Предел навыка запрещает улучшение", not bool(state.get_skill_upgrade_cost("heavy_strike").get("valid", false)))
	var passive_cost: Dictionary = state.get_passive_upgrade_cost("ashen_endurance")
	_check("Стоимость пассивной способности положительная", bool(passive_cost.get("valid", false)) and int(passive_cost.get("gold", 0)) > 0)
	var pet_cost: Dictionary = state.get_pet_upgrade_cost("ash_fox", 1)
	_check("Стоимость питомца положительная", bool(pet_cost.get("valid", false)) and int(pet_cost.get("gold", 0)) > 0)
	_check("Закрытый питомец не улучшается", not bool(state.get_pet_upgrade_cost("rune_owl", 1).get("valid", false)))
	state.select_pet("ash_fox", 1)
	var assist: Dictionary = state.get_pet_combat_data()
	_check("Выбранный питомец даёт помощь в бою", float(assist.get("attack_ratio", 0.0)) > 0.0)
	_check("Имя помощи питомца задано", str(assist.get("assist_name", "")) != "")


func _test_combat_formulas(data: Dictionary) -> void:
	var balance: Dictionary = CombatCatalog.combat_balance(data)
	var plain: float = CombatFormulas.calculate_damage(10.0, 0.0, 1.0, false, balance, -1.0, 0.0)
	var resisted: float = CombatFormulas.calculate_damage(10.0, 0.0, 1.0, false, balance, -1.0, 0.2)
	_check("Сопротивление снижает урон", resisted < plain)
	var overridden: float = CombatFormulas.calculate_damage(10.0, 0.0, 1.0, true, balance, 2.0, 0.0)
	_check("Множитель крита участника применяется", is_equal_approx(overridden, 20.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	_check("Полное уклонение срабатывает", CombatFormulas.roll_dodge(1.0, rng))
	_check("Нулевое уклонение не срабатывает", not CombatFormulas.roll_dodge(0.0, rng))
	var fighter = Combatant.new({"name": "Испытуемый", "max_health": 100.0, "attack": 10.0})
	fighter.receive_damage(30.0)
	var healed: float = fighter.heal(20.0)
	_check("Лечение восстанавливает здоровье", is_equal_approx(healed, 20.0) and is_equal_approx(fighter.health, 90.0))
	_check("Лечение не превышает максимум", is_equal_approx(fighter.heal(100.0), 10.0))


func _high_hp_enemy() -> Array:
	return [{"name": "Тренировочный манекен", "max_health": 100000.0, "attack": 0.0, "defense": 0.0, "crit_chance": 0.0}]


func _make_hero(data: Dictionary, extra: Dictionary) -> Dictionary:
	var hero: Dictionary = CombatCatalog.hero_data(data).duplicate()
	for key in extra.keys():
		hero[str(key)] = extra[str(key)]
	return hero


func _test_combat_system(data: Dictionary) -> void:
	var balance: Dictionary = CombatCatalog.combat_balance(data)
	var skills: Dictionary = CombatCatalog.skill_map(data)
	var fast_hero: Dictionary = _make_hero(data, {"attack_interval_seconds": 0.5, "crit_chance": 0.0, "critical_multiplier": 1.5})
	var fast = CombatSystem.new(fast_hero, _high_hp_enemy(), skills, balance, 101)
	var hits: Array = []
	fast.damage_dealt.connect(func(_target: String, amount: float, _critical: bool): hits.append(amount))
	fast.advance(0.5)
	fast.advance(0.5)
	_check("Ускоренная атака даёт два удара за секунду", hits.size() >= 2)

	var lifesteal_hero: Dictionary = _make_hero(data, {"attack_interval_seconds": 1.0, "lifesteal": 0.5, "crit_chance": 0.0, "health_regen": 0.0})
	var lifesteal = CombatSystem.new(lifesteal_hero, _high_hp_enemy(), skills, balance, 102)
	lifesteal.hero.receive_damage(20.0)
	var before: float = lifesteal.hero.health
	lifesteal.advance(1.0)
	_check("Вампиризм лечит героя после урона", lifesteal.hero.health > before)

	var dodge_hero: Dictionary = _make_hero(data, {"dodge": 1.0, "crit_chance": 0.0, "health_regen": 0.0})
	var dodger = CombatSystem.new(dodge_hero, [{"name": "Атакующий манекен", "max_health": 100000.0, "attack": 20.0, "defense": 0.0, "crit_chance": 0.0}], skills, balance, 103)
	var dodges: Array = []
	dodger.attack_dodged.connect(func(_target: String): dodges.append(true))
	dodger.advance(1.0)
	_check("Уклонение предотвращает урон", is_equal_approx(dodger.hero.health, dodger.hero.max_health))
	_check("Событие уклонения выдано", dodges.size() >= 1)

	var regen_hero: Dictionary = _make_hero(data, {"health_regen": 2.0, "crit_chance": 0.0})
	var regen = CombatSystem.new(regen_hero, _high_hp_enemy(), skills, balance, 104)
	regen.hero.receive_damage(10.0)
	var regen_before: float = regen.hero.health
	regen.advance(1.0)
	_check("Восстановление здоровья работает в бою", regen.hero.health > regen_before)

	var pet_data: Dictionary = {"pet_name": "Пепельная лиса", "assist_name": "Укус лисы", "attack_ratio": 0.5, "interval_seconds": 0.5}
	var pet_system = CombatSystem.new(_make_hero(data, {"crit_chance": 0.0, "health_regen": 0.0}), _high_hp_enemy(), skills, balance, 105, pet_data)
	var pet_events: Array = []
	pet_system.pet_attack.connect(func(_pet: String, _assist: String, amount: float): pet_events.append(amount))
	pet_system.advance(0.5)
	_check("Питомец наносит помощь в бою", pet_system.pet_attack_count >= 1 and pet_events.size() >= 1)

	var heal_skill: Dictionary = {
		"name": "Испытание лечения",
		"cooldown_seconds": 1.0,
		"damage_multiplier": 1.0,
		"heal_ratio": 0.1,
		"critical_chance_bonus": 0.0,
	}
	var heal_system = CombatSystem.new(_make_hero(data, {"crit_chance": 0.0, "health_regen": 0.0}), _high_hp_enemy(), {"heal": heal_skill}, balance, 106)
	var heals: Array = []
	heal_system.hero_healed.connect(func(amount: float): heals.append(amount))
	heal_system.hero.receive_damage(30.0)
	_check("Навык с лечением применяется", heal_system.use_skill("heal"))
	_check("Навык с лечением выдал событие", heals.size() >= 1)
	_check("Повтор навыка до отката запрещён", not heal_system.use_skill("heal"))


func _test_campaign_integration(data: Dictionary) -> void:
	var state = CampaignState.new(data, 211)
	var summary: Dictionary = state.get_summary()
	_check("Сводка содержит базовый класс", str(summary.get("class_name", "")) != "")
	_check("Сводка содержит очки прогрессии", int(summary.get("attribute_points", 0)) > 0 and int(summary.get("skill_points", 0)) > 0)
	_check("Сводка содержит оценку баланса", float(summary.get("balance_ratio", 0.0)) > 0.0)
	_check("Сводка содержит авто-навыки", int(summary.get("auto_skill_count", 0)) >= 1)
	_check("Сводка содержит долю авто-навыков", float(summary.get("auto_skill_share", 0.0)) > 0.0)
	_check("Сводка содержит статус автобоя", str(summary.get("auto_battle_status", "")) != "")
	var hero_before: Dictionary = state.hero_data()
	_check("Параметры героя содержат новые поля", hero_before.has("physical_attack") and hero_before.has("magic_attack") and hero_before.has("lifesteal") and hero_before.has("dodge"))
	state.gold = 300
	state.materials = 300
	var start_attribute_points: int = state.development.attribute_points
	_check("Очко характеристики распределяется через кампанию", state.allocate_attribute("strength"))
	_check("Очки характеристик списаны через кампанию", state.development.attribute_points == start_attribute_points - 1)
	var hero_after: Dictionary = state.hero_data()
	_check("Характеристика усиливает героя кампании", float(hero_after.get("attack", 0.0)) > float(hero_before.get("attack", 0.0)))
	var skill_before: Dictionary = state.system.skills.get("heavy_strike", {}) as Dictionary
	var skill_result: Dictionary = state.upgrade_skill("heavy_strike")
	_check("Навык улучшается через кампанию", bool(skill_result.get("success", false)))
	_check("Уровень навыка вырос", state.development.get_skill_level("heavy_strike") == 2)
	_check("Очки навыков списаны", state.development.skill_points < int(data.get("progression", {}).get("starting_skill_points", 2)))
	var skill_after: Dictionary = state.system.skills.get("heavy_strike", {}) as Dictionary
	_check("Текущий бой получил обновлённый навык", float(skill_after.get("damage_multiplier", 0.0)) > float(skill_before.get("damage_multiplier", 0.0)))
	var campaign_auto_before: bool = state.development.is_skill_auto("heavy_strike")
	var campaign_auto_after: bool = state.toggle_skill_auto("heavy_strike")
	_check("Авто-режим переключается через кампанию", campaign_auto_after != campaign_auto_before)
	_check("Вариант развития меняется через кампанию", state.cycle_skill_variant("heavy_strike") != "")
	state.level = 2
	state.development.set_level(2, false)
	state.development.skill_points = 5
	var passive_result: Dictionary = state.upgrade_passive("ashen_endurance")
	_check("Пассивная способность улучшается через кампанию", bool(passive_result.get("success", false)))
	_check("Уровень пассивной способности вырос", state.development.get_passive_level("ashen_endurance") == 1)
	_check("Закрытый питомец не выбирается на первом этапе", not state.select_pet("rune_owl"))
	_check("Открытый питомец выбирается", state.select_pet("ash_fox"))
	_check("Уровень выбранного питомца первый", state.development.get_pet_level("ash_fox") == 1)
	_check("Помощь питомца подключена к текущему бою", state.system.pet_attack_ratio > 0.0)
	var before_pet_upgrade: float = float(state.hero_data().get("attack", 0.0))
	var pet_result: Dictionary = state.upgrade_pet("ash_fox")
	_check("Питомец улучшается через кампанию", bool(pet_result.get("success", false)))
	_check("Уровень питомца вырос", state.development.get_pet_level("ash_fox") == 2)
	_check("Улучшение питомца усиливает героя", float(state.hero_data().get("attack", 0.0)) > before_pet_upgrade)
	_check("Данные помощи питомца заполнены", float(state.development.get_pet_combat_data().get("attack_ratio", 0.0)) > 0.0)
	_check("Улучшение помощи обновлено в текущем бою", state.system.pet_attack_ratio > 0.0)
	state.stage_index = 4
	_check("Питомец пятого этапа открывается", state.select_pet("rune_owl"))

	var auto_state = CampaignState.new(data, 212)
	auto_state.advance(1.0)
	var used_auto: bool = false
	for skill_id in auto_state.development.get_auto_skill_ids():
		if auto_state.get_cooldown_remaining(str(skill_id)) > 0.0:
			used_auto = true
	_check("Автобой применяет навык по таймеру", used_auto)

	var level_state = CampaignState.new(data, 213)
	var start_points: int = level_state.development.attribute_points
	_check("Первый этап пройден", _finish_stage(level_state))
	_check("Переход ко второму этапу", level_state.next_stage())
	_check("Второй этап пройден", _finish_stage(level_state))
	_check("Повышение уровня выдало очки характеристик", level_state.development.attribute_points > start_points)
	_check("Награда показывает очки прогрессии", int(level_state.last_reward.get("attribute_points", 0)) > 0 or int(level_state.last_reward.get("skill_points", 0)) > 0)

	var full = CampaignState.new(data, 214)
	for stage_number in range(CampaignCatalog.stage_count(data)):
		_finish_stage(full)
		if full.status == CampaignState.STATUS_VICTORY:
			full.next_stage()
	_check("Кампания с прогрессией завершается", full.status == CampaignState.STATUS_COMPLETE)
	_check("Новый поход сбрасывает прогрессию", full.restart_campaign())
	_check("После сброса очки характеристик стартовые", full.development.attribute_points == int(data.get("progression", {}).get("starting_attribute_points", 0)))
	_check("После сброса питомец не выбран", full.development.selected_pet_id == "")


func _test_balance(data: Dictionary) -> void:
	var base_hero: Dictionary = CombatCatalog.hero_data(data)
	var balanced: Dictionary = {}
	for attribute_id in ProgressionCatalog.attribute_ids(data):
		balanced[str(attribute_id)] = 10
	var single: Dictionary = {}
	for attribute_id in ProgressionCatalog.attribute_ids(data):
		single[str(attribute_id)] = 0
	single["strength"] = 20
	var balanced_stats: Dictionary = ProgressionCatalog.build_hero_data(data, base_hero, 1, {}, ProgressionCatalog.attribute_bonuses(data, balanced))
	var single_stats: Dictionary = ProgressionCatalog.build_hero_data(data, base_hero, 1, {}, ProgressionCatalog.attribute_bonuses(data, single))
	var balanced_power: float = ProgressionCatalog.power_score(data, balanced_stats)
	var single_power: float = ProgressionCatalog.power_score(data, single_stats)
	_check("Сбалансированное развитие сильнее одного атрибута", balanced_power > single_power)
	_check("Оценка силы положительна", balanced_power > 0.0)
	var report: Dictionary = ProgressionCatalog.balance_report(data, balanced_stats, 1)
	_check("Отчёт баланса содержит цель и отношение", float(report.get("target", 0.0)) > 0.0 and float(report.get("ratio", 0.0)) > 0.0)
	var base_report: Dictionary = ProgressionCatalog.balance_report(data, base_hero, 1)
	_check("Стартовый герой попадает в коридор баланса", bool(base_report.get("within", false)))
	var stage5: Dictionary = ProgressionCatalog.balance_report(data, balanced_stats, 5)
	_check("Цель пятого этапа выше первой", float(stage5.get("target", 0.0)) > float(report.get("target", 0.0)))
	var auto_ok: Dictionary = ProgressionCatalog.auto_battle_report(data, 3, 10.0)
	_check("Отчёт автобоя содержит долю и длительность", int(auto_ok.get("auto_skill_count", 0)) == 3 and float(auto_ok.get("stage_duration", 0.0)) == 10.0)
	_check("Базовые настройки автобоя в коридоре", bool(auto_ok.get("within", false)))
	var auto_many: Dictionary = ProgressionCatalog.auto_battle_report(data, 6, 10.0)
	_check("Избыток авто-навыков отмечен", not bool(auto_many.get("within", false)) and str(auto_many.get("status", "")) == "много авто-навыков")
	var auto_short: Dictionary = ProgressionCatalog.auto_battle_report(data, 3, 2.0)
	_check("Слишком короткий бой отмечен", not bool(auto_short.get("within", false)) and str(auto_short.get("status", "")) == "короткий бой")


func _finish_stage(state, max_steps: int = 300) -> bool:
	for step in range(max_steps):
		if state.status != CampaignState.STATUS_BATTLE:
			return true
		if state.system == null:
			return false
		for skill_id in state.development.get_auto_skill_ids():
			if state.get_cooldown_remaining(str(skill_id)) <= 0.0:
				state.use_skill(str(skill_id))
				break
		state.advance(1.0)
	return state.status != CampaignState.STATUS_BATTLE
