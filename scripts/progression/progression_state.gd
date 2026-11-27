extends RefCounted

# Состояние прогрессии игрока: очки характеристик и навыков, уровни активных
# и пассивных способностей, варианты развития, автоприменение и питомцы.
# Валюты живут в CampaignState, поэтому здесь нет копий кошелька.

const ProgressionCatalog = preload("res://scripts/progression/progression_catalog.gd")

var balance: Dictionary = {}
var level: int = 1
var attribute_points: int = 0
var skill_points: int = 0
var allocated: Dictionary = {}
var skill_levels: Dictionary = {}
var skill_variants: Dictionary = {}
var skill_auto_use: Dictionary = {}
var passive_levels: Dictionary = {}
var pet_levels: Dictionary = {}
var selected_pet_id: String = ""


func _init(data: Dictionary, initial_level: int = 1) -> void:
	balance = data
	reset()
	if initial_level > 1:
		set_level(initial_level, true)


func reset() -> void:
	var settings: Dictionary = ProgressionCatalog.leveling(balance)
	level = 1
	attribute_points = maxi(0, int(settings.get("starting_attribute_points", 0)))
	skill_points = maxi(0, int(settings.get("starting_skill_points", 0)))
	allocated = {}
	skill_levels = {}
	skill_variants = {}
	skill_auto_use = {}
	passive_levels = {}
	pet_levels = {}
	selected_pet_id = ""
	for attribute_id in ProgressionCatalog.attribute_ids(balance):
		allocated[str(attribute_id)] = 0
	for skill_id in ProgressionCatalog.skill_ids(balance):
		var id: String = str(skill_id)
		var skill: Dictionary = ProgressionCatalog.skill_by_id(balance, id)
		skill_levels[id] = 1
		skill_variants[id] = "power"
		skill_auto_use[id] = bool(skill.get("auto_use", false))
	for passive_id in ProgressionCatalog.passive_ids(balance):
		passive_levels[str(passive_id)] = 0
	for pet_id in ProgressionCatalog.pet_ids(balance):
		pet_levels[str(pet_id)] = 0


func set_level(new_level: int, grant_rewards: bool = false) -> void:
	var gained: int = maxi(0, new_level - level)
	level = maxi(1, new_level)
	if grant_rewards:
		grant_level_rewards(gained)


func grant_level_rewards(levels_gained: int) -> void:
	var settings: Dictionary = ProgressionCatalog.leveling(balance)
	var count: int = maxi(0, levels_gained)
	attribute_points += count * maxi(0, int(settings.get("attribute_points_per_level", 0)))
	skill_points += count * maxi(0, int(settings.get("skill_points_per_level", 0)))


func allocate_attribute(attribute_id: String) -> bool:
	if attribute_points <= 0 or not allocated.has(attribute_id):
		return false
	var current: int = int(allocated[attribute_id])
	var limit: int = ProgressionCatalog.attribute_max_points(balance, attribute_id)
	if current >= limit:
		return false
	allocated[attribute_id] = current + 1
	attribute_points -= 1
	return true


func get_attribute_points(attribute_id: String) -> int:
	return int(allocated.get(attribute_id, 0))


func get_bonuses() -> Dictionary:
	return ProgressionCatalog.total_bonuses(balance, allocated, passive_levels, selected_pet_id, pet_levels)


func get_effective_skill_map() -> Dictionary:
	return ProgressionCatalog.effective_skill_map(balance, level, skill_levels, skill_variants, skill_auto_use)


func get_auto_skill_ids() -> Array:
	var result: Array = []
	var effective: Dictionary = get_effective_skill_map()
	for skill_id in ProgressionCatalog.skill_ids(balance):
		var id: String = str(skill_id)
		if effective.has(id) and bool((effective[id] as Dictionary).get("auto_use", false)):
			result.append(id)
	return result


func get_skill_level(skill_id: String) -> int:
	return int(skill_levels.get(skill_id, 1))


func get_skill_variant(skill_id: String) -> String:
	return str(skill_variants.get(skill_id, "power"))


func is_skill_auto(skill_id: String) -> bool:
	return bool(skill_auto_use.get(skill_id, false))


func get_skill_upgrade_cost(skill_id: String) -> Dictionary:
	return ProgressionCatalog.skill_upgrade_cost(balance, skill_id, get_skill_level(skill_id), level)


func spend_skill_points(amount: int) -> bool:
	if amount <= 0:
		return true
	if skill_points < amount:
		return false
	skill_points -= amount
	return true


func increase_skill_level(skill_id: String) -> bool:
	if not skill_levels.has(skill_id):
		return false
	var skill: Dictionary = ProgressionCatalog.skill_by_id(balance, skill_id)
	var limit: int = maxi(1, int(skill.get("max_level", 5)))
	if int(skill_levels[skill_id]) >= limit:
		return false
	skill_levels[skill_id] = int(skill_levels[skill_id]) + 1
	return true


func toggle_skill_auto(skill_id: String) -> bool:
	if not skill_auto_use.has(skill_id):
		return false
	var value: bool = not bool(skill_auto_use[skill_id])
	skill_auto_use[skill_id] = value
	return value


func cycle_skill_variant(skill_id: String) -> String:
	if not skill_variants.has(skill_id):
		return ""
	var available: Dictionary = ProgressionCatalog.skill_variants(balance)
	var order: Array = []
	for candidate in ["power", "haste"]:
		if available.has(candidate):
			order.append(candidate)
	if order.is_empty():
		return str(skill_variants[skill_id])
	var current: String = str(skill_variants[skill_id])
	var index: int = order.find(current)
	if index < 0:
		index = 0
	var next: String = str(order[(index + 1) % order.size()])
	skill_variants[skill_id] = next
	return next


func get_passive_level(passive_id: String) -> int:
	return int(passive_levels.get(passive_id, 0))


func get_passive_upgrade_cost(passive_id: String) -> Dictionary:
	return ProgressionCatalog.passive_upgrade_cost(balance, passive_id, get_passive_level(passive_id), level)


func increase_passive_level(passive_id: String) -> bool:
	if not passive_levels.has(passive_id):
		return false
	var passive: Dictionary = ProgressionCatalog.passive_by_id(balance, passive_id)
	var limit: int = maxi(1, int(passive.get("max_level", 5)))
	if int(passive_levels[passive_id]) >= limit:
		return false
	passive_levels[passive_id] = int(passive_levels[passive_id]) + 1
	return true


func is_pet_unlocked(pet_id: String, stage_number: int) -> bool:
	return ProgressionCatalog.is_pet_unlocked(balance, pet_id, stage_number)


func select_pet(pet_id: String, stage_number: int) -> bool:
	if not ProgressionCatalog.is_pet_unlocked(balance, pet_id, stage_number):
		return false
	var pet: Dictionary = ProgressionCatalog.pet_by_id(balance, pet_id)
	if pet.is_empty():
		return false
	selected_pet_id = pet_id
	if int(pet_levels.get(pet_id, 0)) <= 0:
		pet_levels[pet_id] = 1
	return true


func get_pet_level(pet_id: String) -> int:
	return int(pet_levels.get(pet_id, 0))


func get_pet_upgrade_cost(pet_id: String, stage_number: int) -> Dictionary:
	return ProgressionCatalog.pet_upgrade_cost(balance, pet_id, get_pet_level(pet_id), stage_number)


func increase_pet_level(pet_id: String) -> bool:
	if not pet_levels.has(pet_id):
		return false
	var pet: Dictionary = ProgressionCatalog.pet_by_id(balance, pet_id)
	var limit: int = maxi(1, int(pet.get("max_level", 5)))
	if int(pet_levels[pet_id]) >= limit:
		return false
	pet_levels[pet_id] = int(pet_levels[pet_id]) + 1
	return true


func get_pet_combat_data() -> Dictionary:
	return ProgressionCatalog.pet_combat_data(balance, selected_pet_id, pet_levels)


static func _as_dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func export_state() -> Dictionary:
	return {
		"level": level,
		"attribute_points": attribute_points,
		"skill_points": skill_points,
		"allocated": allocated.duplicate(true),
		"skill_levels": skill_levels.duplicate(true),
		"skill_variants": skill_variants.duplicate(true),
		"skill_auto_use": skill_auto_use.duplicate(true),
		"passive_levels": passive_levels.duplicate(true),
		"pet_levels": pet_levels.duplicate(true),
		"selected_pet_id": selected_pet_id,
	}


func import_state(snapshot: Dictionary) -> void:
	reset()
	level = maxi(1, int(snapshot.get("level", 1)))
	attribute_points = maxi(0, int(snapshot.get("attribute_points", 0)))
	skill_points = maxi(0, int(snapshot.get("skill_points", 0)))
	var source_allocated: Dictionary = _as_dictionary(snapshot.get("allocated", {}))
	for attribute_id in ProgressionCatalog.attribute_ids(balance):
		var id: String = str(attribute_id)
		var limit: int = ProgressionCatalog.attribute_max_points(balance, id)
		allocated[id] = clampi(int(source_allocated.get(id, 0)), 0, limit)
	var source_levels: Dictionary = _as_dictionary(snapshot.get("skill_levels", {}))
	var source_variants: Dictionary = _as_dictionary(snapshot.get("skill_variants", {}))
	var source_auto: Dictionary = _as_dictionary(snapshot.get("skill_auto_use", {}))
	var variants: Dictionary = ProgressionCatalog.skill_variants(balance)
	for skill_id in ProgressionCatalog.skill_ids(balance):
		var id: String = str(skill_id)
		var skill: Dictionary = ProgressionCatalog.skill_by_id(balance, id)
		var limit: int = maxi(1, int(skill.get("max_level", 5)))
		skill_levels[id] = clampi(int(source_levels.get(id, 1)), 1, limit)
		var variant: String = str(source_variants.get(id, "power"))
		if not variants.has(variant):
			variant = "power"
		skill_variants[id] = variant
		skill_auto_use[id] = bool(source_auto.get(id, skill.get("auto_use", false)))
	var source_passives: Dictionary = _as_dictionary(snapshot.get("passive_levels", {}))
	for passive_id in ProgressionCatalog.passive_ids(balance):
		var id: String = str(passive_id)
		var passive: Dictionary = ProgressionCatalog.passive_by_id(balance, id)
		var limit: int = maxi(1, int(passive.get("max_level", 5)))
		passive_levels[id] = clampi(int(source_passives.get(id, 0)), 0, limit)
	var source_pets: Dictionary = _as_dictionary(snapshot.get("pet_levels", {}))
	for pet_id in ProgressionCatalog.pet_ids(balance):
		var id: String = str(pet_id)
		var pet: Dictionary = ProgressionCatalog.pet_by_id(balance, id)
		var limit: int = maxi(1, int(pet.get("max_level", 5)))
		pet_levels[id] = clampi(int(source_pets.get(id, 0)), 0, limit)
	var selected: String = str(snapshot.get("selected_pet_id", ""))
	if pet_levels.has(selected) and int(pet_levels[selected]) > 0:
		selected_pet_id = selected
	else:
		selected_pet_id = ""


func get_summary() -> Dictionary:
	var bonuses: Dictionary = get_bonuses()
	var weights: Dictionary = ProgressionCatalog.power_weights(balance)
	var bonus_score: float = 0.0
	for key in weights.keys():
		bonus_score += float(bonuses.get(str(key), 0.0)) * float(weights[str(key)])
	var pet: Dictionary = ProgressionCatalog.pet_by_id(balance, selected_pet_id)
	return {
		"level": level,
		"attribute_points": attribute_points,
		"skill_points": skill_points,
		"allocated": allocated.duplicate(),
		"skill_levels": skill_levels.duplicate(),
		"skill_variants": skill_variants.duplicate(),
		"skill_auto_use": skill_auto_use.duplicate(),
		"passive_levels": passive_levels.duplicate(),
		"pet_levels": pet_levels.duplicate(),
		"selected_pet_id": selected_pet_id,
		"selected_pet_name": str(pet.get("name", "Не выбран")),
		"bonuses": bonuses,
		"bonus_score": maxf(0.0, bonus_score),
		"auto_skill_count": get_auto_skill_ids().size(),
	}
