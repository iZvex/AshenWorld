extends SceneTree

# Точечная проверка ТОЛЬКО экипировки четвёртого этапа.
# Запуск: godot --headless --path . --script tests/test_equipment.gd
# Полная сборка APK для этой проверки не требуется.

const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const CampaignState = preload("res://scripts/campaign/campaign_state.gd")
const EquipmentCatalog = preload("res://scripts/equipment/equipment_catalog.gd")
const EquipmentState = preload("res://scripts/equipment/equipment_state.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	print("Проверка экипировки четвёртого этапа")
	var data: Dictionary = CombatCatalog.load_balance()
	_test_data(data)
	_test_initial_state(data)
	_test_pity(data)
	_test_summons(data)
	_test_equip_and_filters(data)
	_test_upgrade(data)
	_test_dismantle_and_protection(data)
	_test_campaign_integration(data)
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
	_check("Версия баланса седьмого этапа", int(data.get("version", 0)) == 7)
	_check("Слотов экипировки девять", EquipmentCatalog.slots(data).size() == 9)
	_check("Редкостей шесть", EquipmentCatalog.rarities(data).size() == 6)
	_check("Случайных свойств три", EquipmentCatalog.affixes(data).size() == 3)
	_check("Категорий призыва две", EquipmentCatalog.summon_ids(data).size() == 2)
	var ids: Array = EquipmentCatalog.summon_ids(data)
	var sums_valid: bool = true
	for summon_id in ids:
		var total: float = EquipmentCatalog.probability_sum(data, str(summon_id))
		if not is_equal_approx(total, 1.0):
			sums_valid = false
	_check("Вероятности каждого призыва дают единицу", sums_valid)
	var ash: Dictionary = EquipmentCatalog.summon_by_id(data, "ash")
	var rune: Dictionary = EquipmentCatalog.summon_by_id(data, "rune")
	var ash_chances: Dictionary = ash.get("chances", {}) as Dictionary
	var rune_chances: Dictionary = rune.get("chances", {}) as Dictionary
	var ash_high: float = 0.0
	var rune_high: float = 0.0
	for rarity in EquipmentCatalog.rarities(data):
		if not rarity is Dictionary:
			continue
		var entry: Dictionary = rarity as Dictionary
		if int(entry.get("score", 0)) >= 3:
			ash_high += float(ash_chances.get(str(entry.get("id", "")), 0.0))
			rune_high += float(rune_chances.get(str(entry.get("id", "")), 0.0))
	_check("Рунный призыв качественнее пепельного", rune_high > ash_high)
	_check("Рунный призыв открывается позже", int(rune.get("unlock_stage", 0)) > int(ash.get("unlock_stage", 0)))
	_check("Текст вероятностей содержит все редкости", "М" in EquipmentCatalog.probability_text(data, "ash"))
	_check("Описание призывает содержит гарантию", "гарантия" in EquipmentCatalog.summon_info(data, "ash"))
	_check("Цвет редкости читается", EquipmentCatalog.rarity_color(data, "legendary").a > 0.9)
	_check("Метки редкости вычисляются", EquipmentCatalog.rarity_marks(data, "mythic").length() == 6)


func _test_initial_state(data: Dictionary) -> void:
	var state = EquipmentState.new(data, 17)
	_check("Инвентарь изначально пуст", state.inventory.is_empty())
	_check("Надетых предметов изначально нет", state.equipped.is_empty())
	_check("История призывов изначально пуста", state.history.is_empty())
	_check("Бонусы изначально нулевые", EquipmentCatalog.score(data, state.get_total_bonuses()) == 0.0)
	_check("Пепельный призыв открыт с первого этапа", state.is_summon_unlocked("ash", 1))
	_check("Рунный призыв закрыт на первом этапе", not state.is_summon_unlocked("rune", 1))
	_check("Рунный призыв открыт на третьем этапе", state.is_summon_unlocked("rune", 3))
	var cost_one: Dictionary = state.get_summon_cost("ash", 1)
	var cost_ten: Dictionary = state.get_summon_cost("ash", 10)
	_check("Стоимость одиночного призыва из баланса", int(cost_one.get("gold", 0)) == 10)
	_check("Стоимость пакета в десять раз выше", int(cost_ten.get("gold", 0)) == 100)
	_check("Без валюты призыв заблокирован", "Недостаточно" in state.summon_block_reason("ash", 1, 1, 0, 0))
	_check("Закрытый призыв объясняет условие", "этапе 3" in state.summon_block_reason("rune", 1, 1, 100, 100))


func _test_pity(data: Dictionary) -> void:
	var pity_data: Dictionary = data.duplicate(true)
	var equipment_data: Dictionary = pity_data.get("equipment", {}) as Dictionary
	var summons_data: Dictionary = equipment_data.get("summons", {}) as Dictionary
	var ash_data: Dictionary = summons_data.get("ash", {}) as Dictionary
	ash_data["pity_threshold"] = 2
	ash_data["guaranteed_rarity"] = "rare"
	var chances: Dictionary = ash_data.get("chances", {}) as Dictionary
	for key in chances.keys():
		chances[str(key)] = 0.0
	chances["common"] = 1.0
	ash_data["chances"] = chances
	summons_data["ash"] = ash_data
	equipment_data["summons"] = summons_data
	pity_data["equipment"] = equipment_data
	var state = EquipmentState.new(pity_data, 99)
	var result: Dictionary = state.roll_summons("ash", 3, 1)
	var items: Array = result.get("items", []) as Array
	var rare_count: int = 0
	for item in items:
		if item is Dictionary and str((item as Dictionary).get("rarity", "")) == "rare":
			rare_count += 1
	_check("Гарантия сработала при только обычных шансах", int(result.get("guaranteed_count", 0)) >= 1)
	_check("Гарантированный предмет редкий", rare_count >= 1)
	_check("Гарантия попала в историю", "гарантия" in state.history_text(3))


func _test_summons(data: Dictionary) -> void:
	var state = EquipmentState.new(data, 11)
	var result: Dictionary = state.roll_summons("ash", 10, 1)
	var items: Array = result.get("items", []) as Array
	_check("Пакетный призыв вернул десять предметов", items.size() == 10)
	_check("Призыв прошёл успешно", bool(result.get("success", false)))
	var all_valid: bool = true
	for item in items:
		if not _valid_item(data, item):
			all_valid = false
	_check("Каждый предмет ссылается на слот и редкость из баланса", all_valid)
	_check("Инвентарь содержит десять предметов", state.inventory.size() == 10)
	_check("История содержит десять записей", state.history.size() == 10)
	_check("Счётчик призывов равен десяти", state.total_summons == 10)
	_check("Сводка показывает нулевую силу без надетых предметов", is_equal_approx(float(state.get_summary().get("power", 0.0)), 0.0))


func _valid_item(data: Dictionary, item: Variant) -> bool:
	if not item is Dictionary:
		return false
	var entry: Dictionary = item as Dictionary
	if EquipmentCatalog.slot_by_id(data, str(entry.get("slot", ""))).is_empty():
		return false
	if EquipmentCatalog.rarity_by_id(data, str(entry.get("rarity", ""))).is_empty():
		return false
	var stats: Dictionary = entry.get("stats", {}) as Dictionary
	if float(stats.get("attack", 0.0)) < 0.0 or float(stats.get("max_health", 0.0)) < 0.0 or float(stats.get("defense", 0.0)) < 0.0:
		return false
	return float(entry.get("power", 0.0)) > 0.0


func _test_equip_and_filters(data: Dictionary) -> void:
	var state = EquipmentState.new(data, 23)
	state.roll_summons("ash", 10, 1)
	state.set_filters(0, 0, 0)
	_check("Без фильтров видны все предметы", state.get_filtered_inventory().size() == 10)
	var first: Dictionary = state.inventory[0] as Dictionary
	var second: Dictionary = state.inventory[1] as Dictionary
	var slot_id: String = str(first.get("slot", ""))
	second["slot"] = slot_id
	first["power"] = 1.0
	second["power"] = 100.0
	second["stats"] = {"attack": 10.0, "max_health": 0.0, "defense": 0.0}
	_check("Надевание предмета выполняется", state.equip(str(first.get("id", ""))))
	var comparison: Dictionary = state.compare(str(second.get("id", "")))
	_check("Сравнение находит более сильный предмет", bool(comparison.get("better", false)))
	_check("Разница силы положительная", float(comparison.get("difference", 0.0)) > 0.0)
	var changed: int = state.auto_equip()
	_check("Автонадевание обновило слоты", changed >= 1)
	_check("Выбран лучший предмет слота", str(state.equipped.get(slot_id, "")) == str(second.get("id", "")))
	_check("Бонусы надетых предметов положительные", float(state.get_total_bonuses().get("attack", 0.0)) > 0.0)
	_check("Сводка показывает надетый предмет", int(state.get_summary().get("equipped_count", 0)) >= 1)
	var slot_index: int = 0
	for index in range(EquipmentCatalog.slots(data).size()):
		if EquipmentCatalog.slot_id_by_index(data, index + 1) == slot_id:
			slot_index = index + 1
			break
	state.set_filters(slot_index, 0, 0)
	var filtered: Array = state.get_filtered_inventory()
	var slot_filter_valid: bool = true
	for item in filtered:
		if item is Dictionary and str((item as Dictionary).get("slot", "")) != slot_id:
			slot_filter_valid = false
	_check("Фильтр слота оставляет только нужные предметы", slot_filter_valid)
	state.set_filters(0, 0, 2)
	var attack_filter_valid: bool = true
	for item in state.get_filtered_inventory():
		if item is Dictionary:
			var stats: Dictionary = (item as Dictionary).get("stats", {}) as Dictionary
			if float(stats.get("attack", 0.0)) <= 0.0:
				attack_filter_valid = false
	_check("Фильтр параметра оставляет предметы с атакой", attack_filter_valid)


func _test_upgrade(data: Dictionary) -> void:
	var state = CampaignState.new(data, 31)
	state.gold = 200
	state.materials = 100
	var summon_result: Dictionary = state.summon_equipment("ash", 10)
	_check("Кампания провела пакетный призыв", bool(summon_result.get("success", false)))
	_check("Золото списано за пакет", state.gold == 100)
	var first: Dictionary = state.equipment.inventory[0] as Dictionary
	var item_id: String = str(first.get("id", ""))
	var cost: Dictionary = state.equipment.get_upgrade_cost(item_id)
	var power_before: float = float(first.get("power", 0.0))
	var gold_before: int = state.gold
	var materials_before: int = state.materials
	var result: Dictionary = state.upgrade_item(item_id)
	_check("Улучшение выполнено", bool(result.get("success", false)))
	_check("Уровень предмета увеличен", int(state.equipment.get_item(item_id).get("level", 0)) == 1)
	_check("Сила предмета выросла", float(state.equipment.get_item(item_id).get("power", 0.0)) > power_before)
	_check("Золото списано по расчёту", state.gold == gold_before - int(cost.get("gold", 0)))
	_check("Пепел списан по расчёту", state.materials == materials_before - int(cost.get("materials", 0)))
	state.gold = 1000
	state.materials = 1000
	for step in range(10):
		state.upgrade_item(item_id)
	var max_level: int = int(EquipmentCatalog.upgrade_data(data).get("max_level", 5))
	_check("Предел улучшения не превышен", int(state.equipment.get_item(item_id).get("level", 0)) == max_level)
	_check("Улучшение сверх предела запрещено", not bool(state.upgrade_item(item_id).get("success", false)))


func _test_dismantle_and_protection(data: Dictionary) -> void:
	var state = CampaignState.new(data, 41)
	state.gold = 200
	state.materials = 100
	state.summon_equipment("ash", 10)
	var first: Dictionary = state.equipment.inventory[0] as Dictionary
	var first_id: String = str(first.get("id", ""))
	_check("Блокировка предмета включается", state.toggle_item_lock(first_id))
	var locked_result: Dictionary = state.dismantle_item(first_id, false)
	_check("Заблокированный предмет не разбирается", not bool(locked_result.get("success", false)))
	_check("Причина блокировки понятна", "заблокирован" in str(locked_result.get("reason", "")))
	_check("Блокировка предмета снимается", not state.toggle_item_lock(first_id))
	first["rarity"] = "legendary"
	first["rarity_score"] = 5
	var protected_result: Dictionary = state.dismantle_item(first_id, false)
	_check("Ценный предмет защищён от случайного разбора", not bool(protected_result.get("success", false)))
	_check("Причина защиты указана", "Ценный" in str(protected_result.get("reason", "")))
	var forced_result: Dictionary = state.dismantle_item(first_id, true)
	_check("Явный разбор ценного предмета возможен", bool(forced_result.get("success", false)))
	_check("Разбор вернул золото", int(forced_result.get("gold", 0)) > 0)
	_check("Разбор вернул пепел", int(forced_result.get("materials", 0)) > 0)
	var second: Dictionary = state.equipment.inventory[0] as Dictionary
	second["rarity"] = "mythic"
	second["rarity_score"] = 6
	second["locked"] = false
	for index in range(1, mini(4, state.equipment.inventory.size())):
		var item: Dictionary = state.equipment.inventory[index] as Dictionary
		item["rarity"] = "common"
		item["rarity_score"] = 1
		item["locked"] = false
	var materials_before: int = state.materials
	var mass_result: Dictionary = state.mass_dismantle_items()
	_check("Массовый разбор удалил низшие редкости", int(mass_result.get("count", 0)) >= 1)
	_check("Массовый разбор вернул пепел", state.materials > materials_before)
	_check("Мифический предмет не попал в массовый разбор", not state.equipment.get_item(str(second.get("id", ""))).is_empty())


func _test_campaign_integration(data: Dictionary) -> void:
	var state = CampaignState.new(data, 51)
	var base: Dictionary = CombatCatalog.hero_data(data)
	var base_total: float = float(base.get("max_health", 0.0)) + float(base.get("attack", 0.0)) + float(base.get("defense", 0.0))
	state.gold = 200
	state.materials = 100
	state.summon_equipment("ash", 10)
	state.auto_equip_items()
	var boosted: Dictionary = state.hero_data()
	var boosted_total: float = float(boosted.get("max_health", 0.0)) + float(boosted.get("attack", 0.0)) + float(boosted.get("defense", 0.0))
	_check("Экипировка усиливает параметры героя", boosted_total > base_total)
	_check("Сводка кампании показывает силу экипировки", float(state.get_summary().get("equipment_power", 0.0)) > 0.0)
	state.status = CampaignState.STATUS_VICTORY
	state.stage_index = 0
	_check("Переход к следующему этапу разрешён", state.next_stage())
	var battle_total: float = state.system.hero.max_health + state.system.hero.attack + state.system.hero.defense
	_check("Бонусы применены в новом бою", battle_total > base_total)
	state.gold = 200
	state.materials = 100
	state.stage_index = 2
	var rune_result: Dictionary = state.summon_equipment("rune", 1)
	_check("Рунный призыв доступен на третьем этапе", bool(rune_result.get("success", false)))
	_check("Рунный призыв списал золото и пепел", state.gold == 175 and state.materials == 92)
	state.status = CampaignState.STATUS_COMPLETE
	_check("Новый поход сбрасывает состояние", state.restart_campaign())
	_check("После сброса инвентарь пуст", int(state.get_summary().get("inventory_count", -1)) == 0)
	_check("После сброса валюты обнулены", state.gold == 0 and state.materials == 0)
