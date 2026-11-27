extends RefCounted

# Чтение и расчёт прогрессии пятого этапа. Здесь собраны формулы
# характеристик, уровни навыков, пассивные бонусы, питомцы и оценка баланса.
# Состояние игрока хранится отдельно в progression_state.gd.


static func leveling(balance: Dictionary) -> Dictionary:
	return balance.get("progression", {}) as Dictionary


static func combat_settings(balance: Dictionary) -> Dictionary:
	return balance.get("combat", {}) as Dictionary


static func attributes(balance: Dictionary) -> Array:
	return balance.get("attributes", []) as Array


static func attribute_ids(balance: Dictionary) -> Array:
	var result: Array = []
	for entry in attributes(balance):
		if entry is Dictionary:
			result.append(str((entry as Dictionary).get("id", "")))
	return result


static func attribute_by_id(balance: Dictionary, attribute_id: String) -> Dictionary:
	for entry in attributes(balance):
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == attribute_id:
			return entry as Dictionary
	return {}


static func attribute_max_points(balance: Dictionary, attribute_id: String) -> int:
	return maxi(1, int(attribute_by_id(balance, attribute_id).get("max_points", 20)))


static func coefficients(balance: Dictionary) -> Dictionary:
	return balance.get("attribute_coefficients", {}) as Dictionary


static func skills(balance: Dictionary) -> Dictionary:
	return balance.get("skills", {}) as Dictionary


static func skill_ids(balance: Dictionary) -> Array:
	var source: Dictionary = skills(balance)
	var ids: Array = source.keys()
	ids.sort_custom(func(first, second):
		var left: Dictionary = source.get(str(first), {}) as Dictionary
		var right: Dictionary = source.get(str(second), {}) as Dictionary
		var left_unlock: int = int(left.get("unlock_level", 1))
		var right_unlock: int = int(right.get("unlock_level", 1))
		if left_unlock != right_unlock:
			return left_unlock < right_unlock
		return float(left.get("cooldown_seconds", 0.0)) < float(right.get("cooldown_seconds", 0.0))
	)
	return ids


static func skill_by_id(balance: Dictionary, skill_id: String) -> Dictionary:
	var entry: Variant = skills(balance).get(skill_id, {})
	if entry is Dictionary:
		return entry as Dictionary
	return {}


static func skill_variants(balance: Dictionary) -> Dictionary:
	return balance.get("skill_variants", {}) as Dictionary


static func passives(balance: Dictionary) -> Dictionary:
	return balance.get("passives", {}) as Dictionary


static func passive_ids(balance: Dictionary) -> Array:
	var source: Dictionary = passives(balance)
	var ids: Array = source.keys()
	ids.sort_custom(func(first, second):
		var left: Dictionary = source.get(str(first), {}) as Dictionary
		var right: Dictionary = source.get(str(second), {}) as Dictionary
		return int(left.get("unlock_level", 1)) < int(right.get("unlock_level", 1))
	)
	return ids


static func passive_by_id(balance: Dictionary, passive_id: String) -> Dictionary:
	var entry: Variant = passives(balance).get(passive_id, {})
	if entry is Dictionary:
		return entry as Dictionary
	return {}


static func pets(balance: Dictionary) -> Dictionary:
	return balance.get("pets", {}) as Dictionary


static func pet_ids(balance: Dictionary) -> Array:
	var source: Dictionary = pets(balance)
	var ids: Array = source.keys()
	ids.sort_custom(func(first, second):
		var left: Dictionary = source.get(str(first), {}) as Dictionary
		var right: Dictionary = source.get(str(second), {}) as Dictionary
		return int(left.get("unlock_stage", 1)) < int(right.get("unlock_stage", 1))
	)
	return ids


static func pet_by_id(balance: Dictionary, pet_id: String) -> Dictionary:
	var entry: Variant = pets(balance).get(pet_id, {})
	if entry is Dictionary:
		return entry as Dictionary
	return {}


static func balance_settings(balance: Dictionary) -> Dictionary:
	return balance.get("balance", {}) as Dictionary


static func auto_battle_settings(balance: Dictionary) -> Dictionary:
	return balance_settings(balance).get("auto_battle", {}) as Dictionary


static func auto_battle_report(balance: Dictionary, auto_skill_count: int, stage_duration_seconds: float) -> Dictionary:
	# Диагностика автобоя: доля включённых авто-навыков от всех активных
	# способностей и длительность текущего этапа сравниваются с целями баланса.
	var settings: Dictionary = auto_battle_settings(balance)
	var total_skills: int = maxi(1, skill_ids(balance).size())
	var count: int = clampi(auto_skill_count, 0, total_skills)
	var max_share: float = clampf(float(settings.get("max_skill_share", 0.5)), 0.0, 1.0)
	var min_duration: float = maxf(0.0, float(settings.get("min_stage_duration_seconds", 8.0)))
	var share: float = float(count) / float(total_skills)
	var duration: float = maxf(0.0, stage_duration_seconds)
	var share_ok: bool = share <= max_share + 0.001
	var duration_ok: bool = duration >= min_duration
	var status: String = "в коридоре"
	if not share_ok:
		status = "много авто-навыков"
	elif not duration_ok:
		status = "короткий бой"
	return {
		"auto_skill_count": count,
		"total_skill_count": total_skills,
		"auto_skill_share": share,
		"max_skill_share": max_share,
		"stage_duration": duration,
		"min_stage_duration": min_duration,
		"within": share_ok and duration_ok,
		"status": status,
	}


static func stage_power_targets(balance: Dictionary) -> Array:
	return balance_settings(balance).get("stage_power_targets", []) as Array


static func power_weights(balance: Dictionary) -> Dictionary:
	return balance_settings(balance).get("power_weights", {}) as Dictionary


static func effective_points(balance: Dictionary, points: int) -> float:
	var settings: Dictionary = leveling(balance)
	var cap: float = maxf(1.0, float(settings.get("attribute_soft_cap", 10)))
	var scale: float = clampf(float(settings.get("attribute_soft_cap_scale", 0.5)), 0.0, 1.0)
	var value: float = maxf(0.0, float(points))
	if value <= cap:
		return value
	return cap + (value - cap) * scale


static func empty_bonuses() -> Dictionary:
	return {
		"max_health": 0.0,
		"physical_attack": 0.0,
		"magic_attack": 0.0,
		"defense": 0.0,
		"crit_chance": 0.0,
		"critical_multiplier": 0.0,
		"attack_speed": 0.0,
		"lifesteal": 0.0,
		"dodge": 0.0,
		"resistance": 0.0,
		"health_regen": 0.0,
	}


static func merge_bonuses(target: Dictionary, source: Dictionary) -> void:
	for key in target.keys():
		target[str(key)] = float(target[str(key)]) + float(source.get(str(key), 0.0))


static func attribute_bonuses(balance: Dictionary, allocated: Dictionary) -> Dictionary:
	var c: Dictionary = coefficients(balance)
	var result: Dictionary = empty_bonuses()
	var strength: float = effective_points(balance, int(allocated.get("strength", 0)))
	var agility: float = effective_points(balance, int(allocated.get("agility", 0)))
	var intellect: float = effective_points(balance, int(allocated.get("intellect", 0)))
	var stamina: float = effective_points(balance, int(allocated.get("stamina", 0)))
	var spirit: float = effective_points(balance, int(allocated.get("spirit", 0)))
	result["max_health"] = strength * float(c.get("health_per_strength", 0.0)) + stamina * float(c.get("health_per_stamina", 0.0)) + spirit * float(c.get("health_per_spirit", 0.0))
	result["physical_attack"] = strength * float(c.get("physical_attack_per_strength", 0.0)) + agility * float(c.get("physical_attack_per_agility", 0.0))
	result["magic_attack"] = intellect * float(c.get("magic_attack_per_intellect", 0.0)) + spirit * float(c.get("magic_attack_per_spirit", 0.0))
	result["defense"] = strength * float(c.get("defense_per_strength", 0.0)) + stamina * float(c.get("defense_per_stamina", 0.0)) + spirit * float(c.get("defense_per_spirit", 0.0))
	result["crit_chance"] = agility * float(c.get("crit_chance_per_agility", 0.0)) + intellect * float(c.get("crit_chance_per_intellect", 0.0))
	result["critical_multiplier"] = intellect * float(c.get("critical_multiplier_per_intellect", 0.0))
	result["attack_speed"] = agility * float(c.get("attack_speed_per_agility", 0.0))
	result["lifesteal"] = spirit * float(c.get("lifesteal_per_spirit", 0.0))
	result["dodge"] = agility * float(c.get("dodge_per_agility", 0.0))
	result["resistance"] = spirit * float(c.get("resistance_per_spirit", 0.0))
	result["health_regen"] = stamina * float(c.get("health_regen_per_stamina", 0.0)) + spirit * float(c.get("health_regen_per_spirit", 0.0))
	return result


static func passive_bonuses(balance: Dictionary, levels: Dictionary) -> Dictionary:
	var result: Dictionary = empty_bonuses()
	for passive_id in passive_ids(balance):
		var passive: Dictionary = passive_by_id(balance, str(passive_id))
		var level: int = clampi(int(levels.get(str(passive_id), 0)), 0, maxi(1, int(passive.get("max_level", 5))))
		if level <= 0:
			continue
		var bonuses: Dictionary = passive.get("bonuses", {}) as Dictionary
		for key in result.keys():
			result[str(key)] = float(result[str(key)]) + float(bonuses.get(str(key), 0.0)) * float(level)
	return result


static func pet_bonuses(balance: Dictionary, selected_pet_id: String, pet_levels: Dictionary) -> Dictionary:
	var result: Dictionary = empty_bonuses()
	if selected_pet_id == "":
		return result
	var pet: Dictionary = pet_by_id(balance, selected_pet_id)
	if pet.is_empty():
		return result
	var level: int = clampi(int(pet_levels.get(selected_pet_id, 0)), 0, maxi(1, int(pet.get("max_level", 5))))
	if level <= 0:
		return result
	var base: Dictionary = pet.get("base_bonuses", {}) as Dictionary
	var per_level: Dictionary = pet.get("per_level_bonuses", {}) as Dictionary
	for key in result.keys():
		var total: float = float(base.get(str(key), 0.0)) + float(per_level.get(str(key), 0.0)) * float(level - 1)
		result[str(key)] = float(result[str(key)]) + total
	return result


static func total_bonuses(balance: Dictionary, allocated: Dictionary, passive_levels: Dictionary, selected_pet_id: String, pet_levels: Dictionary) -> Dictionary:
	var result: Dictionary = empty_bonuses()
	merge_bonuses(result, attribute_bonuses(balance, allocated))
	merge_bonuses(result, passive_bonuses(balance, passive_levels))
	merge_bonuses(result, pet_bonuses(balance, selected_pet_id, pet_levels))
	return result


static func build_hero_data(balance: Dictionary, base_hero: Dictionary, hero_level: int, equipment_bonuses: Dictionary, development_bonuses: Dictionary) -> Dictionary:
	var settings: Dictionary = leveling(balance)
	var combat: Dictionary = combat_settings(balance)
	var c: Dictionary = coefficients(balance)
	var hero: Dictionary = base_hero.duplicate()
	var level_bonus: int = maxi(0, hero_level - 1)
	var physical: float = float(hero.get("physical_attack", hero.get("attack", 0.0))) + float(level_bonus) * float(settings.get("attack_per_level", 0.0)) + float(equipment_bonuses.get("attack", 0.0)) + float(development_bonuses.get("physical_attack", 0.0))
	var magic: float = float(hero.get("magic_attack", 0.0)) + float(development_bonuses.get("magic_attack", 0.0))
	var max_health: float = float(hero.get("max_health", 1.0)) + float(level_bonus) * float(settings.get("max_health_per_level", 0.0)) + float(equipment_bonuses.get("max_health", 0.0)) + float(development_bonuses.get("max_health", 0.0))
	var defense: float = float(hero.get("defense", 0.0)) + float(level_bonus) * float(settings.get("defense_per_level", 0.0)) + float(equipment_bonuses.get("defense", 0.0)) + float(development_bonuses.get("defense", 0.0))
	hero["max_health"] = maxf(1.0, max_health)
	hero["physical_attack"] = maxf(0.0, physical)
	hero["magic_attack"] = maxf(0.0, magic)
	hero["attack"] = maxf(0.0, physical + magic * float(c.get("magic_attack_weight", 0.65)))
	hero["defense"] = maxf(0.0, defense)
	hero["crit_chance"] = clampf(float(hero.get("crit_chance", 0.0)) + float(development_bonuses.get("crit_chance", 0.0)), 0.0, float(combat.get("max_crit_chance", 0.45)))
	hero["critical_multiplier"] = clampf(float(hero.get("critical_multiplier", combat.get("critical_multiplier", 1.5))) + float(development_bonuses.get("critical_multiplier", 0.0)), 1.0, float(combat.get("max_critical_multiplier", 2.5)))
	var interval: float = float(hero.get("attack_interval_seconds", combat.get("attack_interval_seconds", 1.0))) - float(development_bonuses.get("attack_speed", 0.0))
	hero["attack_interval_seconds"] = maxf(float(combat.get("min_attack_interval", 0.45)), interval)
	hero["lifesteal"] = clampf(float(hero.get("lifesteal", 0.0)) + float(development_bonuses.get("lifesteal", 0.0)), 0.0, float(combat.get("max_lifesteal", 0.25)))
	hero["dodge"] = clampf(float(hero.get("dodge", 0.0)) + float(development_bonuses.get("dodge", 0.0)), 0.0, float(combat.get("max_dodge", 0.25)))
	hero["resistance"] = clampf(float(hero.get("resistance", 0.0)) + float(development_bonuses.get("resistance", 0.0)), 0.0, float(combat.get("max_resistance", 0.35)))
	hero["health_regen"] = clampf(float(hero.get("health_regen", 0.0)) + float(development_bonuses.get("health_regen", 0.0)), 0.0, float(combat.get("max_health_regen", 8.0)))
	return hero


static func effective_skill_map(balance: Dictionary, hero_level: int, skill_levels: Dictionary, variants: Dictionary, auto_overrides: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var variant_data: Dictionary = skill_variants(balance)
	for skill_id in skill_ids(balance):
		var id: String = str(skill_id)
		var base: Dictionary = skill_by_id(balance, id)
		if hero_level < int(base.get("unlock_level", 1)):
			continue
		var max_level: int = maxi(1, int(base.get("max_level", 5)))
		var level: int = clampi(int(skill_levels.get(id, 1)), 1, max_level)
		var variant_id: String = str(variants.get(id, "power"))
		if not variant_data.has(variant_id):
			variant_id = "power"
		var variant: Dictionary = variant_data.get(variant_id, {}) as Dictionary
		var effect: float = maxf(0.1, float(variant.get("effect_multiplier", 1.0)))
		var cooldown_multiplier: float = maxf(0.1, float(variant.get("cooldown_multiplier", 1.0)))
		var skill: Dictionary = base.duplicate()
		var step: int = level - 1
		skill["level"] = level
		skill["variant"] = variant_id
		skill["variant_name"] = str(variant.get("name", "Мощь"))
		skill["unlocked"] = true
		skill["auto_use"] = bool(auto_overrides.get(id, base.get("auto_use", false)))
		skill["cooldown_seconds"] = maxf(0.5, (float(base.get("cooldown_seconds", 1.0)) - float(step) * float(base.get("cooldown_per_level", 0.0))) * cooldown_multiplier)
		if base.has("damage_multiplier"):
			skill["damage_multiplier"] = maxf(0.0, (float(base.get("damage_multiplier", 0.0)) + float(step) * float(base.get("damage_per_level", 0.0))) * effect)
		if base.has("shield_ratio"):
			skill["shield_ratio"] = maxf(0.0, (float(base.get("shield_ratio", 0.0)) + float(step) * float(base.get("shield_per_level", 0.0))) * effect)
		if base.has("heal_ratio"):
			skill["heal_ratio"] = maxf(0.0, (float(base.get("heal_ratio", 0.0)) + float(step) * float(base.get("heal_per_level", 0.0))) * effect)
		if base.has("critical_chance_bonus"):
			skill["critical_chance_bonus"] = maxf(0.0, (float(base.get("critical_chance_bonus", 0.0)) + float(step) * float(base.get("crit_bonus_per_level", 0.0))) * effect)
		result[id] = skill
	return result


static func skill_upgrade_cost(balance: Dictionary, skill_id: String, current_level: int, hero_level: int) -> Dictionary:
	var skill: Dictionary = skill_by_id(balance, skill_id)
	if skill.is_empty():
		return {"valid": false, "reason": "Навык не найден"}
	if hero_level < int(skill.get("unlock_level", 1)):
		return {"valid": false, "reason": "Навык ещё не открыт"}
	var max_level: int = maxi(1, int(skill.get("max_level", 5)))
	if current_level >= max_level:
		return {"valid": false, "reason": "Достигнут предел навыка"}
	var config: Dictionary = leveling(balance).get("skill_upgrade", {}) as Dictionary
	var step: int = maxi(1, current_level)
	return {
		"valid": true,
		"reason": "",
		"skill_points": int(config.get("skill_point_cost", 1)),
		"gold": int(config.get("gold_base", 0)) + int(config.get("gold_per_level", 0)) * step,
		"materials": int(config.get("materials_base", 0)) + int(config.get("materials_per_level", 0)) * step,
		"max_level": max_level,
	}


static func passive_upgrade_cost(balance: Dictionary, passive_id: String, current_level: int, hero_level: int) -> Dictionary:
	var passive: Dictionary = passive_by_id(balance, passive_id)
	if passive.is_empty():
		return {"valid": false, "reason": "Пассивная способность не найдена"}
	if hero_level < int(passive.get("unlock_level", 1)):
		return {"valid": false, "reason": "Способность ещё не открыта"}
	var max_level: int = maxi(1, int(passive.get("max_level", 5)))
	if current_level >= max_level:
		return {"valid": false, "reason": "Достигнут предел способности"}
	var config: Dictionary = leveling(balance).get("passive_upgrade", {}) as Dictionary
	var step: int = maxi(1, current_level + 1)
	return {
		"valid": true,
		"reason": "",
		"skill_points": int(config.get("skill_point_cost", 1)),
		"gold": int(config.get("gold_base", 0)) + int(config.get("gold_per_level", 0)) * step,
		"materials": int(config.get("materials_base", 0)) + int(config.get("materials_per_level", 0)) * step,
		"max_level": max_level,
	}


static func pet_upgrade_cost(balance: Dictionary, pet_id: String, current_level: int, stage_number: int) -> Dictionary:
	var pet: Dictionary = pet_by_id(balance, pet_id)
	if pet.is_empty():
		return {"valid": false, "reason": "Питомец не найден"}
	if stage_number < int(pet.get("unlock_stage", 1)):
		return {"valid": false, "reason": "Питомец ещё не открыт"}
	var max_level: int = maxi(1, int(pet.get("max_level", 5)))
	if current_level >= max_level:
		return {"valid": false, "reason": "Достигнут предел питомца"}
	var config: Dictionary = leveling(balance).get("pet_upgrade", {}) as Dictionary
	var step: int = maxi(1, current_level + 1)
	return {
		"valid": true,
		"reason": "",
		"gold": int(config.get("gold_base", 0)) + int(config.get("gold_per_level", 0)) * step,
		"materials": int(config.get("materials_base", 0)) + int(config.get("materials_per_level", 0)) * step,
		"max_level": max_level,
	}


static func pet_combat_data(balance: Dictionary, selected_pet_id: String, pet_levels: Dictionary) -> Dictionary:
	if selected_pet_id == "":
		return {}
	var pet: Dictionary = pet_by_id(balance, selected_pet_id)
	if pet.is_empty():
		return {}
	var level: int = clampi(int(pet_levels.get(selected_pet_id, 0)), 0, maxi(1, int(pet.get("max_level", 5))))
	if level <= 0:
		return {}
	var assist: Dictionary = pet.get("assist", {}) as Dictionary
	var config: Dictionary = leveling(balance).get("pet_upgrade", {}) as Dictionary
	var growth: float = 1.0 + float(level - 1) * float(config.get("assist_growth_per_level", 0.15))
	return {
		"pet_name": str(pet.get("name", "Питомец")),
		"assist_name": str(assist.get("name", "Помощь")),
		"attack_ratio": maxf(0.0, float(assist.get("attack_ratio", 0.0))) * growth,
		"interval_seconds": maxf(0.5, float(assist.get("interval_seconds", 3.0))),
		"level": level,
	}


static func power_score(balance: Dictionary, hero_stats: Dictionary) -> float:
	var weights: Dictionary = power_weights(balance)
	var interval: float = maxf(0.1, float(hero_stats.get("attack_interval_seconds", 1.0)))
	var attack_speed: float = maxf(0.0, 1.0 / interval - 1.0)
	var score: float = 0.0
	score += float(hero_stats.get("max_health", 0.0)) * float(weights.get("max_health", 0.0))
	score += float(hero_stats.get("physical_attack", 0.0)) * float(weights.get("physical_attack", 0.0))
	score += float(hero_stats.get("magic_attack", 0.0)) * float(weights.get("magic_attack", 0.0))
	score += float(hero_stats.get("defense", 0.0)) * float(weights.get("defense", 0.0))
	score += float(hero_stats.get("crit_chance", 0.0)) * float(weights.get("crit_chance", 0.0))
	score += float(hero_stats.get("critical_multiplier", 0.0)) * float(weights.get("critical_multiplier", 0.0))
	score += attack_speed * float(weights.get("attack_speed", 0.0))
	score += float(hero_stats.get("lifesteal", 0.0)) * float(weights.get("lifesteal", 0.0))
	score += float(hero_stats.get("dodge", 0.0)) * float(weights.get("dodge", 0.0))
	score += float(hero_stats.get("resistance", 0.0)) * float(weights.get("resistance", 0.0))
	score += float(hero_stats.get("health_regen", 0.0)) * float(weights.get("health_regen", 0.0))
	return maxf(0.0, score)


static func balance_report(balance: Dictionary, hero_stats: Dictionary, stage_number: int) -> Dictionary:
	var targets: Array = stage_power_targets(balance)
	if targets.is_empty():
		return {"hero_power": 0.0, "target": 1.0, "ratio": 0.0, "within": false, "status": "Нет целей баланса"}
	var index: int = clampi(stage_number - 1, 0, targets.size() - 1)
	var target: float = maxf(1.0, float(targets[index]))
	var power: float = power_score(balance, hero_stats)
	var ratio: float = power / target
	var tolerance: float = maxf(0.01, float(balance_settings(balance).get("tolerance", 0.45)))
	var within: bool = absf(ratio - 1.0) <= tolerance
	return {
		"hero_power": power,
		"target": target,
		"ratio": ratio,
		"within": within,
		"status": "в коридоре" if within else "требует правки",
	}


static func attribute_button_text(balance: Dictionary, attribute_id: String, points: int) -> String:
	var attribute: Dictionary = attribute_by_id(balance, attribute_id)
	return "%s %d" % [str(attribute.get("short", "?")), points]


static func is_skill_unlocked(balance: Dictionary, skill_id: String, hero_level: int) -> bool:
	return hero_level >= int(skill_by_id(balance, skill_id).get("unlock_level", 1))


static func is_passive_unlocked(balance: Dictionary, passive_id: String, hero_level: int) -> bool:
	return hero_level >= int(passive_by_id(balance, passive_id).get("unlock_level", 1))


static func is_pet_unlocked(balance: Dictionary, pet_id: String, stage_number: int) -> bool:
	return stage_number >= int(pet_by_id(balance, pet_id).get("unlock_stage", 1))
