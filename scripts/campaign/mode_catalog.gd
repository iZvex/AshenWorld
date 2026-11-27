extends RefCounted

# Единый каталог трёх режимов седьмого этапа: кампания из 30 этапов,
# Башня испытаний и Подземелья ресурсов. Все названия, цены входа,
# награды, масштабы и подписи читаются из раздела modes файла balance.json.

const CampaignCatalog = preload("res://scripts/campaign/campaign_catalog.gd")


static func modes_data(balance: Dictionary) -> Dictionary:
	var value: Variant = balance.get("modes", {})
	return value as Dictionary if value is Dictionary else {}


static func mode_list(balance: Dictionary) -> Array:
	var value: Variant = modes_data(balance).get("list", [])
	return value as Array if value is Array else []


static func mode_ids(balance: Dictionary) -> Array:
	var result: Array = []
	for entry in mode_list(balance):
		if entry is Dictionary:
			result.append(str((entry as Dictionary).get("id", "")))
	return result


static func mode_by_id(balance: Dictionary, mode_id: String) -> Dictionary:
	for entry in mode_list(balance):
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == mode_id:
			return entry as Dictionary
	return {}


static func mode_name(balance: Dictionary, mode_id: String) -> String:
	return str(mode_by_id(balance, mode_id).get("name", mode_id))


static func mode_short(balance: Dictionary, mode_id: String) -> String:
	return str(mode_by_id(balance, mode_id).get("short", mode_id.to_upper()))


static func mode_region(balance: Dictionary, mode_id: String) -> String:
	return str(mode_by_id(balance, mode_id).get("region", mode_name(balance, mode_id)))


static func mode_description(balance: Dictionary, mode_id: String) -> String:
	return str(mode_by_id(balance, mode_id).get("description", ""))


static func mode_unlock_stage(balance: Dictionary, mode_id: String) -> int:
	return maxi(1, int(mode_by_id(balance, mode_id).get("unlock_stage", 1)))


static func is_mode_unlocked(balance: Dictionary, mode_id: String, highest_stage: int) -> bool:
	if not mode_ids(balance).has(mode_id):
		return false
	return maxi(1, highest_stage) >= mode_unlock_stage(balance, mode_id)


static func mode_unlock_reason(balance: Dictionary, mode_id: String, highest_stage: int) -> String:
	if is_mode_unlocked(balance, mode_id, highest_stage):
		return ""
	return "Откроется на этапе %d" % mode_unlock_stage(balance, mode_id)


static func tower_data(balance: Dictionary) -> Dictionary:
	var value: Variant = modes_data(balance).get("tower", {})
	return value as Dictionary if value is Dictionary else {}


static func tower_floors(balance: Dictionary) -> Array:
	var value: Variant = tower_data(balance).get("floors", [])
	return value as Array if value is Array else []


static func dungeon_data(balance: Dictionary) -> Dictionary:
	var value: Variant = modes_data(balance).get("dungeon", {})
	return value as Dictionary if value is Dictionary else {}


static func dungeon_runs(balance: Dictionary) -> Array:
	var value: Variant = dungeon_data(balance).get("runs", [])
	return value as Array if value is Array else []


static func dungeon_ids(balance: Dictionary) -> Array:
	var result: Array = []
	for entry in dungeon_runs(balance):
		if entry is Dictionary:
			result.append(str((entry as Dictionary).get("id", "")))
	return result


static func first_dungeon_id(balance: Dictionary) -> String:
	var ids: Array = dungeon_ids(balance)
	return str(ids[0]) if not ids.is_empty() else ""


static func dungeon_by_id(balance: Dictionary, dungeon_id: String) -> Dictionary:
	for entry in dungeon_runs(balance):
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == dungeon_id:
			return entry as Dictionary
	return {}


static func dungeon_name(balance: Dictionary, dungeon_id: String) -> String:
	return str(dungeon_by_id(balance, dungeon_id).get("name", dungeon_id))


static func dungeon_short(balance: Dictionary, dungeon_id: String) -> String:
	return str(dungeon_by_id(balance, dungeon_id).get("short", dungeon_name(balance, dungeon_id)))


static func dungeon_unlock_stage(balance: Dictionary, dungeon_id: String) -> int:
	return maxi(1, int(dungeon_by_id(balance, dungeon_id).get("unlock_stage", 1)))


static func is_dungeon_unlocked(balance: Dictionary, dungeon_id: String, highest_stage: int) -> bool:
	if not dungeon_ids(balance).has(dungeon_id):
		return false
	return maxi(1, highest_stage) >= dungeon_unlock_stage(balance, dungeon_id)


static func dungeon_entry_cost(balance: Dictionary, dungeon_id: String) -> Dictionary:
	var value: Variant = dungeon_by_id(balance, dungeon_id).get("entry_cost", {})
	return value as Dictionary if value is Dictionary else {}


static func dungeon_block_reason(
	balance: Dictionary,
	dungeon_id: String,
	highest_stage: int,
	gold: int,
	materials: int,
) -> String:
	var mode_reason: String = mode_unlock_reason(balance, "dungeon", highest_stage)
	if mode_reason != "":
		return mode_reason
	if not dungeon_ids(balance).has(dungeon_id):
		return "Неизвестное подземелье"
	if not is_dungeon_unlocked(balance, dungeon_id, highest_stage):
		return "Откроется на этапе %d" % dungeon_unlock_stage(balance, dungeon_id)
	var cost: Dictionary = dungeon_entry_cost(balance, dungeon_id)
	var gold_cost: int = maxi(0, int(cost.get("gold", 0)))
	var materials_cost: int = maxi(0, int(cost.get("materials", 0)))
	if gold < gold_cost or materials < materials_cost:
		return "Нужно %d золота и %d пепла" % [gold_cost, materials_cost]
	return ""


static func dungeon_reward(balance: Dictionary, dungeon_id: String) -> Dictionary:
	var value: Variant = dungeon_by_id(balance, dungeon_id).get("reward", {})
	return value as Dictionary if value is Dictionary else {}


static func stage_count(balance: Dictionary, mode_id: String) -> int:
	match mode_id:
		"campaign":
			return CampaignCatalog.stage_count(balance)
		"tower":
			return tower_floors(balance).size()
		"dungeon":
			return 1
	return 0


static func default_state(balance: Dictionary) -> Dictionary:
	var victories: Dictionary = {}
	for mode_id in mode_ids(balance):
		victories[str(mode_id)] = 0
	return {
		"active_mode": "campaign" if mode_ids(balance).has("campaign") else first_mode_id(balance),
		"tower_floor": 0,
		"highest_tower_floor": 1,
		"dungeon_id": first_dungeon_id(balance),
		"dungeon_runs": 0,
		"mode_victories": victories,
	}


static func first_mode_id(balance: Dictionary) -> String:
	var ids: Array = mode_ids(balance)
	return str(ids[0]) if not ids.is_empty() else "campaign"


static func normalize_state(value: Variant, balance: Dictionary, highest_stage: int = 1) -> Dictionary:
	var result: Dictionary = default_state(balance)
	if value is Dictionary:
		var source: Dictionary = value as Dictionary
		for key in result.keys():
			if source.has(str(key)):
				result[str(key)] = source[str(key)]
	var active: String = str(result.get("active_mode", "campaign"))
	if not mode_ids(balance).has(active) or not is_mode_unlocked(balance, active, highest_stage):
		active = "campaign" if mode_ids(balance).has("campaign") else first_mode_id(balance)
	result["active_mode"] = active
	var tower_max: int = maxi(0, stage_count(balance, "tower") - 1)
	result["tower_floor"] = clampi(int(result.get("tower_floor", 0)), 0, tower_max)
	result["highest_tower_floor"] = clampi(int(result.get("highest_tower_floor", 1)), 1, maxi(1, tower_max + 1))
	var dungeon_id: String = str(result.get("dungeon_id", first_dungeon_id(balance)))
	if not dungeon_ids(balance).has(dungeon_id) or not is_dungeon_unlocked(balance, dungeon_id, highest_stage):
		dungeon_id = first_dungeon_id(balance)
	result["dungeon_id"] = dungeon_id
	result["dungeon_runs"] = maxi(0, int(result.get("dungeon_runs", 0)))
	var victories_value: Variant = result.get("mode_victories", {})
	var victories: Dictionary = victories_value as Dictionary if victories_value is Dictionary else {}
	var normalized_victories: Dictionary = {}
	for mode_id in mode_ids(balance):
		normalized_victories[str(mode_id)] = maxi(0, int(victories.get(str(mode_id), 0)))
	result["mode_victories"] = normalized_victories
	return result


static func state_from_snapshot(snapshot: Dictionary, balance: Dictionary, highest_stage: int = 1) -> Dictionary:
	# Снимки CampaignState хранят полное состояние в поле modes. Поля
	# active_mode и mode_index верхнего уровня остаются для совместимости:
	# они переносятся внутрь modes и проходят ту же нормализацию.
	var state_value: Variant = snapshot.get("modes", {})
	var state: Dictionary = normalize_state(state_value, balance, highest_stage)
	if snapshot.has("active_mode"):
		state["active_mode"] = str(snapshot.get("active_mode", "campaign"))
	if snapshot.has("mode_index") and str(state.get("active_mode", "campaign")) == "tower":
		state["tower_floor"] = int(snapshot.get("mode_index", 0))
	return normalize_state(state, balance, highest_stage)


static func _decorate(stage: Dictionary, balance: Dictionary, mode_id: String) -> Dictionary:
	var result: Dictionary = stage.duplicate(true)
	result["mode_id"] = mode_id
	result["mode_name"] = mode_name(balance, mode_id)
	result["mode_short"] = mode_short(balance, mode_id)
	result["mode_region"] = mode_region(balance, mode_id)
	if not result.has("region") or str(result.get("region", "")) == "":
		result["region"] = mode_region(balance, mode_id)
	return result


static func stage_at(balance: Dictionary, mode_id: String, index: int, state: Dictionary) -> Dictionary:
	match mode_id:
		"campaign":
			var campaign_stage: Dictionary = CampaignCatalog.stage_at(balance, index)
			return _decorate(campaign_stage, balance, mode_id) if not campaign_stage.is_empty() else {}
		"tower":
			var floors: Array = tower_floors(balance)
			if floors.is_empty():
				return {}
			var floor_index: int = clampi(index, 0, floors.size() - 1)
			if not floors[floor_index] is Dictionary:
				return {}
			return _decorate(floors[floor_index] as Dictionary, balance, mode_id)
		"dungeon":
			var dungeon_id: String = str(state.get("dungeon_id", first_dungeon_id(balance)))
			var dungeon: Dictionary = dungeon_by_id(balance, dungeon_id)
			if dungeon.is_empty():
				return {}
			var waves_value: Variant = dungeon.get("enemies", [])
			var waves: Array = waves_value as Array if waves_value is Array else []
			var dungeon_stage: Dictionary = {
				"name": dungeon_name(balance, dungeon_id),
				"kind": "подземелье",
				"chapter": dungeon_short(balance, dungeon_id),
				"region": mode_region(balance, mode_id),
				"enemies": waves.duplicate(true),
				"reward": dungeon_reward(balance, dungeon_id).duplicate(true),
				"dungeon_id": dungeon_id,
			}
			return _decorate(dungeon_stage, balance, mode_id)
	return {}


static func progress_text(balance: Dictionary, mode_id: String, state: Dictionary, current: int, total: int) -> String:
	var mode: Dictionary = mode_by_id(balance, mode_id)
	var template: String = str(mode.get("progress_label", "{current}/{total}"))
	var name_value: String = mode_short(balance, mode_id)
	if mode_id == "dungeon":
		name_value = dungeon_short(balance, str(state.get("dungeon_id", first_dungeon_id(balance))))
	var text: String = template.replace("{current}", str(current))
	text = text.replace("{total}", str(total))
	text = text.replace("{name}", name_value)
	return "%s · %s" % [mode_region(balance, mode_id), text]


static func action_text(
	balance: Dictionary,
	mode_id: String,
	status_key: String,
	current: int,
	state: Dictionary,
) -> String:
	var mode: Dictionary = mode_by_id(balance, mode_id)
	match status_key:
		"defeat":
			return str(modes_data(balance).get("defeat_action", "ПОВТОРИТЬ БОЙ"))
		"complete":
			return str(mode.get("action_restart", "НОВЫЙ ЗАХОД"))
		"victory":
			var template: String = str(mode.get("action_next", "ДАЛЬШЕ"))
			return template.replace("{next}", str(current + 1))
	return ""


static func status_key(status: int) -> String:
	match status:
		1:
			return "victory"
		2:
			return "defeat"
		3:
			return "complete"
	return "battle"


static func mode_stats_text(balance: Dictionary, state: Dictionary) -> String:
	var tower: int = int(state.get("highest_tower_floor", 1))
	var dungeon_runs_count: int = int(state.get("dungeon_runs", 0))
	var victories_value: Variant = state.get("mode_victories", {})
	var victories: Dictionary = victories_value as Dictionary if victories_value is Dictionary else {}
	var parts: PackedStringArray = PackedStringArray()
	for mode_id in mode_ids(balance):
		parts.append("%s %d" % [mode_short(balance, str(mode_id)), int(victories.get(str(mode_id), 0))])
	return "Лучший ярус %d · заходов %d · победы: %s" % [tower, dungeon_runs_count, ", ".join(parts)]
