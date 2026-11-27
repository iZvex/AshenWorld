extends RefCounted

# Преобразование данных кампании в список противников для одного этапа.
# Все названия, масштабы и награды берутся из единого файла баланса.

const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")


static func campaign(balance: Dictionary) -> Dictionary:
	return CombatCatalog.campaign_data(balance)


static func stages(balance: Dictionary) -> Array:
	return CombatCatalog.campaign_stages(balance)


static func stage_at(balance: Dictionary, index: int) -> Dictionary:
	var list: Array = stages(balance)
	if index < 0 or index >= list.size():
		return {}
	var entry: Variant = list[index]
	if entry is Dictionary:
		return entry as Dictionary
	return {}


static func stage_count(balance: Dictionary) -> int:
	return stages(balance).size()


static func stage_is_boss(stage: Dictionary) -> bool:
	if str(stage.get("kind", "")) == "босс":
		return true
	var waves: Array = stage.get("enemies", []) as Array
	for item in waves:
		if item is Dictionary and bool((item as Dictionary).get("boss", false)):
			return true
	return false


static func stage_kind(stage: Dictionary) -> String:
	return str(stage.get("kind", "обычный")).to_upper()


static func build_enemy_list(stage: Dictionary, balance: Dictionary) -> Array:
	var source: Dictionary = balance.get("enemies", {}) as Dictionary
	var defaults: Dictionary = campaign(balance)
	var waves: Array = stage.get("enemies", []) as Array
	var result: Array = []
	for item in waves:
		if not item is Dictionary:
			continue
		var wave: Dictionary = item as Dictionary
		var enemy_id: String = str(wave.get("id", ""))
		if not source.has(enemy_id):
			push_error("В кампании указан неизвестный противник: %s" % enemy_id)
			continue
		var base: Dictionary = (source[enemy_id] as Dictionary).duplicate()
		var count: int = maxi(1, int(wave.get("count", 1)))
		var health_scale: float = maxf(0.1, float(wave.get("health_scale", 1.0)))
		var attack_scale: float = maxf(0.1, float(wave.get("attack_scale", 1.0)))
		var defense_scale: float = maxf(0.1, float(wave.get("defense_scale", 1.0)))
		var custom_name: String = str(wave.get("name", ""))
		var boss: bool = bool(wave.get("boss", false))
		var phase_threshold: float = clampf(
			float(wave.get("phase_threshold", stage.get("phase_threshold", defaults.get("boss_phase_threshold", 0.5)))),
			0.0,
			0.99,
		)
		var phase_multiplier: float = maxf(
			1.0,
			float(wave.get("phase_attack_multiplier", stage.get("phase_attack_multiplier", defaults.get("boss_phase_attack_multiplier", 1.0)))),
		)
		var phase_name: String = str(wave.get("phase_name", defaults.get("boss_phase_name", "Ярость")))
		for number in range(count):
			var enemy: Dictionary = base.duplicate()
			enemy["id"] = enemy_id
			if custom_name != "":
				if count == 1:
					enemy["name"] = custom_name
				else:
					enemy["name"] = "%s %d" % [custom_name, number + 1]
			enemy["max_health"] = float(base.get("max_health", 1.0)) * health_scale
			enemy["attack"] = float(base.get("attack", 0.0)) * attack_scale
			enemy["defense"] = float(base.get("defense", 0.0)) * defense_scale
			if boss:
				enemy["is_boss"] = true
				enemy["phase_threshold"] = phase_threshold
				enemy["phase_attack_multiplier"] = phase_multiplier
				enemy["phase_name"] = phase_name
			result.append(enemy)
	return result
