extends RefCounted

# Состояние экипировки четвёртого этапа: призывы, редкости, инвентарь,
# сравнение, надевание, улучшение, блокировка и защита от разбора.

const EquipmentCatalog = preload("res://scripts/equipment/equipment_catalog.gd")

var balance: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_value: int = 54321
var next_item_id: int = 1
var inventory: Array = []
var equipped: Dictionary = {}
var history: Array = []
var summons_since_guaranteed: Dictionary = {}
var total_summons: int = 0
var filter_slot_index: int = 0
var filter_rarity_index: int = 0
var filter_affix_index: int = 0


func _init(data: Dictionary, initial_seed: int = 54321) -> void:
	balance = data
	seed_value = initial_seed
	rng.seed = seed_value


func reset() -> void:
	inventory.clear()
	equipped.clear()
	history.clear()
	summons_since_guaranteed.clear()
	total_summons = 0
	next_item_id = 1
	filter_slot_index = 0
	filter_rarity_index = 0
	filter_affix_index = 0
	rng.seed = seed_value


func get_summon_ids() -> Array:
	return EquipmentCatalog.summon_ids(balance)


func get_summon_cost(summon_id: String, count: int) -> Dictionary:
	var summon: Dictionary = EquipmentCatalog.summon_by_id(balance, summon_id)
	if summon.is_empty():
		return {"valid": false, "gold": 0, "materials": 0}
	var amount: int = maxi(1, count)
	return {
		"valid": true,
		"gold": int(summon.get("cost_gold", 0)) * amount,
		"materials": int(summon.get("cost_materials", 0)) * amount,
	}


func is_summon_unlocked(summon_id: String, stage_number: int) -> bool:
	var summon: Dictionary = EquipmentCatalog.summon_by_id(balance, summon_id)
	if summon.is_empty():
		return false
	return stage_number >= int(summon.get("unlock_stage", 1))


func summon_block_reason(summon_id: String, count: int, stage_number: int, gold: int, materials: int) -> String:
	var summon: Dictionary = EquipmentCatalog.summon_by_id(balance, summon_id)
	if summon.is_empty():
		return "Неизвестный призыв"
	if not is_summon_unlocked(summon_id, stage_number):
		return "Призыв откроется на этапе %d" % int(summon.get("unlock_stage", 1))
	var cost: Dictionary = get_summon_cost(summon_id, count)
	if not bool(cost.get("valid", false)):
		return "Некорректная стоимость призыва"
	if gold < int(cost.get("gold", 0)) or materials < int(cost.get("materials", 0)):
		return "Недостаточно золота или пепла"
	return ""


func roll_summons(summon_id: String, count: int, stage_number: int) -> Dictionary:
	var summon: Dictionary = EquipmentCatalog.summon_by_id(balance, summon_id)
	if summon.is_empty():
		return {"success": false, "reason": "Неизвестный призыв", "items": [], "guaranteed_count": 0}
	if not is_summon_unlocked(summon_id, stage_number):
		return {"success": false, "reason": "Призыв ещё не открыт", "items": [], "guaranteed_count": 0}
	var amount: int = maxi(1, count)
	var items: Array = []
	var guaranteed_count: int = 0
	for pull in range(amount):
		var rolled: Dictionary = _roll_rarity(summon_id, summon)
		var rarity_id: String = str(rolled.get("id", "common"))
		if bool(rolled.get("guaranteed", false)):
			guaranteed_count += 1
		var item: Dictionary = _create_item(rarity_id, bool(rolled.get("guaranteed", false)), str(summon.get("name", "")))
		items.append(item)
	return {"success": true, "reason": "", "items": items, "guaranteed_count": guaranteed_count}


func _roll_rarity(summon_id: String, summon: Dictionary) -> Dictionary:
	var guaranteed_id: String = str(summon.get("guaranteed_rarity", "rare"))
	var guaranteed_score: int = maxi(1, EquipmentCatalog.rarity_score(balance, guaranteed_id))
	var threshold: int = maxi(1, int(summon.get("pity_threshold", 10)))
	var since: int = int(summons_since_guaranteed.get(summon_id, 0))
	if since + 1 >= threshold:
		summons_since_guaranteed[summon_id] = 0
		return {"id": guaranteed_id, "guaranteed": true}
	var chances: Dictionary = summon.get("chances", {}) as Dictionary
	var rarities: Array = EquipmentCatalog.rarities(balance)
	var chosen: String = ""
	if rarities.size() > 0 and rarities[rarities.size() - 1] is Dictionary:
		chosen = str((rarities[rarities.size() - 1] as Dictionary).get("id", "common"))
	var roll: float = rng.randf()
	var cumulative: float = 0.0
	for rarity in rarities:
		if not rarity is Dictionary:
			continue
		var entry: Dictionary = rarity as Dictionary
		cumulative += float(chances.get(str(entry.get("id", "")), 0.0))
		if roll < cumulative:
			chosen = str(entry.get("id", "common"))
			break
	if EquipmentCatalog.rarity_score(balance, chosen) >= guaranteed_score:
		summons_since_guaranteed[summon_id] = 0
	else:
		summons_since_guaranteed[summon_id] = since + 1
	return {"id": chosen, "guaranteed": false}


func _create_item(rarity_id: String, guaranteed: bool, summon_name: String) -> Dictionary:
	var slots: Array = EquipmentCatalog.slots(balance)
	var slot: Dictionary = slots[rng.randi_range(0, slots.size() - 1)] as Dictionary
	var names: Array = slot.get("names", []) as Array
	var item_name: String = str(slot.get("name", "Предмет"))
	if names.size() > 0:
		item_name = str(names[rng.randi_range(0, names.size() - 1)])
	var base_stats: Dictionary = (slot.get("base_stats", {}) as Dictionary).duplicate()
	var rarity: Dictionary = EquipmentCatalog.rarity_by_id(balance, rarity_id)
	var affix_sources: Array = EquipmentCatalog.affixes(balance)
	var item_affixes: Array = []
	for affix_number in range(int(rarity.get("affix_count", 0))):
		if affix_sources.size() == 0:
			break
		var source: Dictionary = affix_sources[rng.randi_range(0, affix_sources.size() - 1)] as Dictionary
		item_affixes.append({
			"stat": str(source.get("stat", "")),
			"name": str(source.get("name", "")),
			"value": rng.randf_range(float(source.get("min", 0.0)), float(source.get("max", 0.0))),
		})
	var item: Dictionary = {
		"id": "item-%d" % next_item_id,
		"name": item_name,
		"slot": str(slot.get("id", "")),
		"slot_name": str(slot.get("name", "")),
		"rarity": rarity_id,
		"rarity_name": str(rarity.get("name", "")),
		"rarity_score": int(rarity.get("score", 1)),
		"base_stats": base_stats,
		"affixes": item_affixes,
		"level": 0,
		"locked": false,
	}
	next_item_id += 1
	_recalculate_stats(item)
	inventory.append(item)
	history.insert(0, {
		"item_name": item_name,
		"rarity_name": str(rarity.get("name", "")),
		"rarity_id": rarity_id,
		"color": str(rarity.get("color", "#E6DCCB")),
		"guaranteed": guaranteed,
		"summon_name": summon_name,
	})
	if history.size() > 20:
		history.resize(20)
	total_summons += 1
	return item


func _recalculate_stats(item: Dictionary) -> void:
	var rarity: Dictionary = EquipmentCatalog.rarity_by_id(balance, str(item.get("rarity", "")))
	var upgrade: Dictionary = EquipmentCatalog.upgrade_data(balance)
	var level: int = int(item.get("level", 0))
	var multiplier: float = float(rarity.get("multiplier", 1.0)) * (1.0 + float(level) * float(upgrade.get("stat_growth", 0.0)))
	var base_stats: Dictionary = item.get("base_stats", {}) as Dictionary
	var weights: Dictionary = EquipmentCatalog.score_weights(balance)
	var stats: Dictionary = {}
	for key in weights.keys():
		stats[str(key)] = float(base_stats.get(str(key), 0.0)) * multiplier
	var affixes_value: Variant = item.get("affixes", [])
	var affixes: Array = affixes_value as Array
	for entry in affixes:
		if not entry is Dictionary:
			continue
		var affix: Dictionary = entry as Dictionary
		var stat_key: String = str(affix.get("stat", ""))
		if stat_key == "":
			continue
		if not stats.has(stat_key):
			stats[stat_key] = 0.0
		stats[stat_key] = float(stats[stat_key]) + float(affix.get("value", 0.0)) * multiplier
	item["stats"] = stats
	item["power"] = EquipmentCatalog.score(balance, stats)


func _find_index(item_id: String) -> int:
	for index in range(inventory.size()):
		var entry: Variant = inventory[index]
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == item_id:
			return index
	return -1


func get_item(item_id: String) -> Dictionary:
	var index: int = _find_index(item_id)
	if index < 0:
		return {}
	return inventory[index] as Dictionary


func set_filters(slot_index: int, rarity_index: int, affix_index: int) -> void:
	filter_slot_index = clampi(slot_index, 0, EquipmentCatalog.slots(balance).size())
	filter_rarity_index = clampi(rarity_index, 0, EquipmentCatalog.rarities(balance).size())
	filter_affix_index = clampi(affix_index, 0, EquipmentCatalog.affixes(balance).size())


func get_filter_values() -> Dictionary:
	return {
		"slot": filter_slot_index,
		"rarity": filter_rarity_index,
		"affix": filter_affix_index,
	}


func get_filtered_inventory() -> Array:
	var slot_id: String = EquipmentCatalog.slot_id_by_index(balance, filter_slot_index)
	var rarity_id: String = EquipmentCatalog.rarity_id_by_index(balance, filter_rarity_index)
	var stat_key: String = EquipmentCatalog.stat_key_by_index(balance, filter_affix_index)
	var result: Array = []
	for entry in inventory:
		if not entry is Dictionary:
			continue
		var item: Dictionary = entry as Dictionary
		if slot_id != "" and str(item.get("slot", "")) != slot_id:
			continue
		if rarity_id != "" and str(item.get("rarity", "")) != rarity_id:
			continue
		var stats: Dictionary = item.get("stats", {}) as Dictionary
		if stat_key != "" and float(stats.get(stat_key, 0.0)) <= 0.0:
			continue
		result.append(item)
	result.sort_custom(func(first, second): return float((first as Dictionary).get("power", 0.0)) > float((second as Dictionary).get("power", 0.0)))
	return result


func equip(item_id: String) -> bool:
	var item: Dictionary = get_item(item_id)
	if item.is_empty():
		return false
	var slot_id: String = str(item.get("slot", ""))
	if slot_id == "":
		return false
	equipped[slot_id] = item_id
	return true


func auto_equip() -> int:
	var changed: int = 0
	for slot in EquipmentCatalog.slots(balance):
		if not slot is Dictionary:
			continue
		var slot_id: String = str((slot as Dictionary).get("id", ""))
		var best_id: String = ""
		var best_power: float = -1.0
		for entry in inventory:
			if not entry is Dictionary:
				continue
			var item: Dictionary = entry as Dictionary
			if str(item.get("slot", "")) != slot_id:
				continue
			var power: float = float(item.get("power", 0.0))
			if power > best_power:
				best_power = power
				best_id = str(item.get("id", ""))
		if best_id != "" and str(equipped.get(slot_id, "")) != best_id:
			equipped[slot_id] = best_id
			changed += 1
	return changed


func is_equipped(item_id: String) -> bool:
	for slot_id in equipped.keys():
		if str(equipped[slot_id]) == item_id:
			return true
	return false


func get_equipped_item(slot_id: String) -> Dictionary:
	return get_item(str(equipped.get(slot_id, "")))


func get_total_bonuses() -> Dictionary:
	var bonuses: Dictionary = {}
	for key in EquipmentCatalog.score_weights(balance).keys():
		bonuses[str(key)] = 0.0
	for slot_id in equipped.keys():
		var item: Dictionary = get_item(str(equipped[slot_id]))
		if item.is_empty():
			continue
		var stats: Dictionary = item.get("stats", {}) as Dictionary
		for key in bonuses.keys():
			bonuses[key] = float(bonuses[key]) + float(stats.get(str(key), 0.0))
	return bonuses


func compare(item_id: String) -> Dictionary:
	var item: Dictionary = get_item(item_id)
	if item.is_empty():
		return {"found": false}
	var slot_id: String = str(item.get("slot", ""))
	var equipped_item: Dictionary = get_equipped_item(slot_id)
	var equipped_power: float = float(equipped_item.get("power", 0.0))
	var item_power: float = float(item.get("power", 0.0))
	return {
		"found": true,
		"item": item,
		"equipped": equipped_item,
		"equipped_power": equipped_power,
		"power": item_power,
		"difference": item_power - equipped_power,
		"better": item_power > equipped_power,
		"already_equipped": is_equipped(item_id),
	}


func get_upgrade_cost(item_id: String) -> Dictionary:
	var item: Dictionary = get_item(item_id)
	if item.is_empty():
		return {"valid": false, "reason": "Предмет не найден", "gold": 0, "materials": 0}
	var upgrade: Dictionary = EquipmentCatalog.upgrade_data(balance)
	var level: int = int(item.get("level", 0))
	var max_level: int = int(upgrade.get("max_level", 5))
	if level >= max_level:
		return {"valid": false, "reason": "Достигнут предел улучшения", "gold": 0, "materials": 0, "max_level": true}
	var score: int = EquipmentCatalog.rarity_score(balance, str(item.get("rarity", "")))
	var gold: int = int(upgrade.get("gold_per_level", 0)) * (level + 1) + int(upgrade.get("gold_per_rarity", 0)) * score
	var materials: int = int(upgrade.get("materials_per_level", 0)) * (level + 1) + int(upgrade.get("materials_per_rarity", 0)) * score
	return {"valid": true, "reason": "", "gold": gold, "materials": materials, "max_level": false}


func upgrade(item_id: String) -> bool:
	var cost: Dictionary = get_upgrade_cost(item_id)
	if not bool(cost.get("valid", false)):
		return false
	var item: Dictionary = get_item(item_id)
	item["level"] = int(item.get("level", 0)) + 1
	_recalculate_stats(item)
	return true


func dismantle_block_reason(item_id: String, force: bool) -> String:
	var item: Dictionary = get_item(item_id)
	if item.is_empty():
		return "Предмет не найден"
	if bool(item.get("locked", false)):
		return "Предмет заблокирован"
	if is_equipped(item_id):
		return "Предмет надет"
	var protection: Dictionary = EquipmentCatalog.protection_data(balance)
	var valuable: int = int(protection.get("valuable_min_score", 3))
	if int(item.get("rarity_score", 1)) >= valuable and not force:
		return "Ценный предмет защищён от случайного разбора"
	return ""


func can_dismantle(item_id: String, force: bool = false) -> bool:
	return dismantle_block_reason(item_id, force) == ""


func dismantle(item_id: String, force: bool = false) -> Dictionary:
	var reason: String = dismantle_block_reason(item_id, force)
	if reason != "":
		return {"success": false, "reason": reason, "gold": 0, "materials": 0, "item_name": ""}
	var item: Dictionary = get_item(item_id)
	var reward: Dictionary = _dismantle_reward(item)
	var index: int = _find_index(item_id)
	inventory.remove_at(index)
	return {
		"success": true,
		"reason": "",
		"gold": int(reward.get("gold", 0)),
		"materials": int(reward.get("materials", 0)),
		"item_name": str(item.get("name", "")),
	}


func mass_dismantle() -> Dictionary:
	var protection: Dictionary = EquipmentCatalog.protection_data(balance)
	var max_score: int = int(protection.get("mass_dismantle_max_score", 2))
	var ids: Array = []
	for entry in inventory:
		if not entry is Dictionary:
			continue
		var item: Dictionary = entry as Dictionary
		var item_id: String = str(item.get("id", ""))
		if bool(item.get("locked", false)) or is_equipped(item_id):
			continue
		if int(item.get("rarity_score", 1)) <= max_score:
			ids.append(item_id)
	var total_gold: int = 0
	var total_materials: int = 0
	var removed: int = 0
	for item_id in ids:
		var result: Dictionary = dismantle(str(item_id), false)
		if bool(result.get("success", false)):
			removed += 1
			total_gold += int(result.get("gold", 0))
			total_materials += int(result.get("materials", 0))
	return {"success": true, "count": removed, "gold": total_gold, "materials": total_materials}


func toggle_lock(item_id: String) -> bool:
	var item: Dictionary = get_item(item_id)
	if item.is_empty():
		return false
	var locked: bool = not bool(item.get("locked", false))
	item["locked"] = locked
	return locked


func _dismantle_reward(item: Dictionary) -> Dictionary:
	var data: Dictionary = EquipmentCatalog.dismantle_data(balance)
	var gold_map: Dictionary = data.get("gold", {}) as Dictionary
	var materials_map: Dictionary = data.get("materials", {}) as Dictionary
	var rarity_id: String = str(item.get("rarity", "common"))
	var level: int = int(item.get("level", 0))
	var bonus: int = 1 + level * int(data.get("level_bonus_per_level", 1))
	return {
		"gold": int(gold_map.get(rarity_id, 0)) * bonus,
		"materials": int(materials_map.get(rarity_id, 0)) * bonus,
	}


static func _as_dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


static func _as_array(value: Variant) -> Array:
	return value as Array if value is Array else []


func export_state() -> Dictionary:
	return {
		"seed_value": seed_value,
		"rng_state": str(rng.state),
		"next_item_id": next_item_id,
		"inventory": inventory.duplicate(true),
		"equipped": equipped.duplicate(true),
		"history": history.duplicate(true),
		"summons_since_guaranteed": summons_since_guaranteed.duplicate(true),
		"total_summons": total_summons,
		"filter_slot_index": filter_slot_index,
		"filter_rarity_index": filter_rarity_index,
		"filter_affix_index": filter_affix_index,
	}


func import_state(snapshot: Dictionary) -> void:
	var saved_rng_state: String = str(snapshot.get("rng_state", ""))
	seed_value = int(snapshot.get("seed_value", seed_value))
	reset()
	rng.seed = seed_value
	if saved_rng_state != "":
		rng.state = int(saved_rng_state)
	next_item_id = maxi(1, int(snapshot.get("next_item_id", 1)))
	var seen: Dictionary = {}
	var source_inventory: Array = _as_array(snapshot.get("inventory", []))
	for entry in source_inventory:
		if not entry is Dictionary:
			continue
		var item: Dictionary = (entry as Dictionary).duplicate(true)
		var item_id: String = str(item.get("id", ""))
		if item_id == "" or seen.has(item_id):
			continue
		seen[item_id] = true
		item["level"] = maxi(0, int(item.get("level", 0)))
		item["locked"] = bool(item.get("locked", false))
		item["rarity_score"] = maxi(1, int(item.get("rarity_score", 1)))
		_recalculate_stats(item)
		inventory.append(item)
		var suffix: String = item_id.trim_prefix("item-")
		if suffix.is_valid_int():
			next_item_id = maxi(next_item_id, int(suffix) + 1)
	var source_equipped: Dictionary = _as_dictionary(snapshot.get("equipped", {}))
	for slot_id in source_equipped.keys():
		var item_id: String = str(source_equipped[slot_id])
		var item: Dictionary = get_item(item_id)
		if not item.is_empty() and str(item.get("slot", "")) == str(slot_id):
			equipped[str(slot_id)] = item_id
	var source_history: Array = _as_array(snapshot.get("history", []))
	for entry in source_history:
		if entry is Dictionary:
			history.append((entry as Dictionary).duplicate(true))
	if history.size() > 20:
		history.resize(20)
	var source_pity: Dictionary = _as_dictionary(snapshot.get("summons_since_guaranteed", {}))
	for summon_id in get_summon_ids():
		summons_since_guaranteed[str(summon_id)] = maxi(0, int(source_pity.get(str(summon_id), 0)))
	total_summons = maxi(0, int(snapshot.get("total_summons", 0)))
	filter_slot_index = clampi(int(snapshot.get("filter_slot_index", 0)), 0, EquipmentCatalog.slots(balance).size())
	filter_rarity_index = clampi(int(snapshot.get("filter_rarity_index", 0)), 0, EquipmentCatalog.rarities(balance).size())
	filter_affix_index = clampi(int(snapshot.get("filter_affix_index", 0)), 0, EquipmentCatalog.affixes(balance).size())


func get_summary() -> Dictionary:
	var bonuses: Dictionary = get_total_bonuses()
	return {
		"inventory_count": inventory.size(),
		"equipped_count": equipped.size(),
		"power": EquipmentCatalog.score(balance, bonuses),
		"bonuses": bonuses,
		"total_summons": total_summons,
		"history_count": history.size(),
		"pity": summons_since_guaranteed.duplicate(),
	}


func history_text(limit: int = 3) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var count: int = mini(limit, history.size())
	for index in range(count):
		var entry: Dictionary = history[index] as Dictionary
		var suffix: String = " · гарантия" if bool(entry.get("guaranteed", false)) else ""
		var rarity_id: String = str(entry.get("rarity_id", ""))
		var marks: String = EquipmentCatalog.rarity_marks(balance, rarity_id)
		lines.append("%s %s · %s%s" % [marks, str(entry.get("item_name", "")), str(entry.get("rarity_name", "")), suffix])
	if lines.is_empty():
		return "История призывов пуста"
	return "История: " + " | ".join(lines)
