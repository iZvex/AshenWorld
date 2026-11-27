extends RefCounted

# Чтение данных экипировки из единого файла баланса и общие вычисления силы.
# Здесь нет состояния игрока: инвентарь и призывы живут в equipment_state.gd.


static func equipment_data(balance: Dictionary) -> Dictionary:
	return balance.get("equipment", {}) as Dictionary


static func slots(balance: Dictionary) -> Array:
	return equipment_data(balance).get("slots", []) as Array


static func rarities(balance: Dictionary) -> Array:
	return equipment_data(balance).get("rarities", []) as Array


static func affixes(balance: Dictionary) -> Array:
	return equipment_data(balance).get("affixes", []) as Array


static func summons(balance: Dictionary) -> Dictionary:
	return equipment_data(balance).get("summons", {}) as Dictionary


static func upgrade_data(balance: Dictionary) -> Dictionary:
	return equipment_data(balance).get("upgrade", {}) as Dictionary


static func dismantle_data(balance: Dictionary) -> Dictionary:
	return equipment_data(balance).get("dismantle", {}) as Dictionary


static func protection_data(balance: Dictionary) -> Dictionary:
	return equipment_data(balance).get("protection", {}) as Dictionary


static func score_weights(balance: Dictionary) -> Dictionary:
	return equipment_data(balance).get("score_weights", {}) as Dictionary


static func summon_ids(balance: Dictionary) -> Array:
	var ids: Array = summons(balance).keys()
	ids.sort()
	return ids


static func slot_by_id(balance: Dictionary, slot_id: String) -> Dictionary:
	for slot in slots(balance):
		if slot is Dictionary and str((slot as Dictionary).get("id", "")) == slot_id:
			return slot as Dictionary
	return {}


static func rarity_by_id(balance: Dictionary, rarity_id: String) -> Dictionary:
	for rarity in rarities(balance):
		if rarity is Dictionary and str((rarity as Dictionary).get("id", "")) == rarity_id:
			return rarity as Dictionary
	return {}


static func summon_by_id(balance: Dictionary, summon_id: String) -> Dictionary:
	var entry: Variant = summons(balance).get(summon_id, {})
	if entry is Dictionary:
		return entry as Dictionary
	return {}


static func rarity_score(balance: Dictionary, rarity_id: String) -> int:
	return int(rarity_by_id(balance, rarity_id).get("score", 0))


static func rarity_color(balance: Dictionary, rarity_id: String) -> Color:
	var text: String = str(rarity_by_id(balance, rarity_id).get("color", "#E6DCCB"))
	return Color(text)


static func rarity_marks(balance: Dictionary, rarity_id: String) -> String:
	var result: String = ""
	for mark in range(rarity_score(balance, rarity_id)):
		result += "◆"
	return result


static func slot_id_by_index(balance: Dictionary, index: int) -> String:
	if index <= 0:
		return ""
	var list: Array = slots(balance)
	if index > list.size():
		return ""
	var slot: Variant = list[index - 1]
	if slot is Dictionary:
		return str((slot as Dictionary).get("id", ""))
	return ""


static func rarity_id_by_index(balance: Dictionary, index: int) -> String:
	if index <= 0:
		return ""
	var list: Array = rarities(balance)
	if index > list.size():
		return ""
	var rarity: Variant = list[index - 1]
	if rarity is Dictionary:
		return str((rarity as Dictionary).get("id", ""))
	return ""


static func stat_key_by_index(balance: Dictionary, index: int) -> String:
	if index <= 0:
		return ""
	var list: Array = affixes(balance)
	if index > list.size():
		return ""
	var affix: Variant = list[index - 1]
	if affix is Dictionary:
		return str((affix as Dictionary).get("stat", ""))
	return ""


static func score(balance: Dictionary, stats: Dictionary) -> float:
	var weights: Dictionary = score_weights(balance)
	var total: float = 0.0
	for key in weights.keys():
		total += float(stats.get(str(key), 0.0)) * float(weights[key])
	return total


static func stats_text(stats: Dictionary) -> String:
	return "АТК %.0f · ХП %.0f · ЗАЩ %.0f" % [
		float(stats.get("attack", 0.0)),
		float(stats.get("max_health", 0.0)),
		float(stats.get("defense", 0.0)),
	]


static func probability_sum(balance: Dictionary, summon_id: String) -> float:
	var summon: Dictionary = summon_by_id(balance, summon_id)
	var chances: Dictionary = summon.get("chances", {}) as Dictionary
	var total: float = 0.0
	for rarity in rarities(balance):
		if rarity is Dictionary:
			total += float(chances.get(str((rarity as Dictionary).get("id", "")), 0.0))
	return total


static func probability_text(balance: Dictionary, summon_id: String) -> String:
	var chances: Dictionary = summon_by_id(balance, summon_id).get("chances", {}) as Dictionary
	var parts: PackedStringArray = PackedStringArray()
	for rarity in rarities(balance):
		if not rarity is Dictionary:
			continue
		var entry: Dictionary = rarity as Dictionary
		var chance: float = float(chances.get(str(entry.get("id", "")), 0.0)) * 100.0
		parts.append("%s %.1f%%" % [str(entry.get("short", "?")), chance])
	return "Шансы: " + " · ".join(parts)


static func summon_info(balance: Dictionary, summon_id: String) -> String:
	var summon: Dictionary = summon_by_id(balance, summon_id)
	if summon.is_empty():
		return "Неизвестный призыв"
	var guaranteed_id: String = str(summon.get("guaranteed_rarity", ""))
	var guaranteed: String = str(rarity_by_id(balance, guaranteed_id).get("name", "редкая"))
	return "%s · %d золота · %d пепла · гарантия «%s» через %d призывов · %s" % [
		str(summon.get("name", "")),
		int(summon.get("cost_gold", 0)),
		int(summon.get("cost_materials", 0)),
		guaranteed,
		int(summon.get("pity_threshold", 10)),
		probability_text(balance, summon_id),
	]
