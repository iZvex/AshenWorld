extends RefCounted

# Состояние игрового цикла: этапы, победы, опыт, валюта, экипировка
# и прогрессия пятого этапа. Сохранения появятся позже, поэтому прогресс
# живёт в течение запуска игры.

const CombatSystem = preload("res://scripts/combat/combat_system.gd")
const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const CampaignCatalog = preload("res://scripts/campaign/campaign_catalog.gd")
const EquipmentState = preload("res://scripts/equipment/equipment_state.gd")
const ProgressionCatalog = preload("res://scripts/progression/progression_catalog.gd")
const ProgressionState = preload("res://scripts/progression/progression_state.gd")

const STATUS_BATTLE: int = 0
const STATUS_VICTORY: int = 1
const STATUS_DEFEAT: int = 2
const STATUS_COMPLETE: int = 3

signal boss_phase_started(enemy_name: String, phase_name: String)

var balance: Dictionary = {}
var stages: Array = []
var leveling: Dictionary = {}
var economy: Dictionary = {}
var campaign: Dictionary = {}
var equipment
var development
var stage_index: int = 0
var level: int = 1
var experience: int = 0
var gold: int = 0
var materials: int = 0
var victories: int = 0
var defeats: int = 0
var status: int = STATUS_BATTLE
var system
var last_reward: Dictionary = {}
var boss_phase_count: int = 0
var current_boss_phase_active: bool = false
var current_boss_phase_name: String = ""
var observed_phase_counts: Dictionary = {}
var pet_attack_count: int = 0
var observed_pet_counts: Dictionary = {}
var auto_skill_timer: float = 0.0
var stage_elapsed: float = 0.0
var seed_value: int = 12345


func _init(data: Dictionary, initial_seed: int = 12345) -> void:
	balance = data
	stages = CampaignCatalog.stages(data)
	leveling = data.get("progression", {}) as Dictionary
	economy = data.get("economy", {}) as Dictionary
	campaign = CampaignCatalog.campaign(data)
	seed_value = initial_seed
	equipment = EquipmentState.new(data, seed_value + 777)
	development = ProgressionState.new(data, level)
	start_stage()


func start_stage() -> void:
	current_boss_phase_active = false
	current_boss_phase_name = ""
	auto_skill_timer = 0.0
	stage_elapsed = 0.0
	development.set_level(level, false)
	var stage: Dictionary = current_stage()
	if stage.is_empty():
		status = STATUS_COMPLETE
		system = null
		return
	var enemies: Array = CampaignCatalog.build_enemy_list(stage, balance)
	if enemies.is_empty():
		push_error("На этапе «%s» нет противников" % str(stage.get("name", "")))
		status = STATUS_DEFEAT
		system = null
		return
	system = CombatSystem.new(
		hero_data(),
		enemies,
		development.get_effective_skill_map(),
		CombatCatalog.combat_balance(balance),
		seed_value + stage_index * 101,
		development.get_pet_combat_data(),
	)
	var battle_id: int = int(system.get_instance_id())
	observed_phase_counts[battle_id] = 0
	observed_pet_counts[battle_id] = 0
	status = STATUS_BATTLE


func advance(delta: float) -> void:
	if status != STATUS_BATTLE or system == null:
		return
	stage_elapsed += maxf(0.0, delta)
	_auto_use_skills(delta)
	system.advance(delta)
	_sync_boss_phases()
	_sync_pet_attacks()
	if system.running:
		return
	if system.hero.alive:
		_register_victory()
	else:
		defeats += 1
		status = STATUS_DEFEAT


func use_skill(skill_id: String) -> bool:
	if status != STATUS_BATTLE or system == null:
		return false
	var applied: bool = system.use_skill(skill_id)
	_sync_boss_phases()
	_sync_pet_attacks()
	return applied


func get_cooldown_remaining(skill_id: String) -> float:
	if system == null:
		return 0.0
	return system.get_cooldown_remaining(skill_id)


func next_stage() -> bool:
	if status != STATUS_VICTORY or stage_index >= stages.size() - 1:
		return false
	stage_index += 1
	start_stage()
	return true


func retry_stage() -> bool:
	if status != STATUS_DEFEAT:
		return false
	start_stage()
	return true


func restart_campaign() -> bool:
	if status != STATUS_COMPLETE:
		return false
	stage_index = 0
	level = 1
	experience = 0
	gold = 0
	materials = 0
	victories = 0
	defeats = 0
	boss_phase_count = 0
	pet_attack_count = 0
	observed_phase_counts = {}
	observed_pet_counts = {}
	last_reward = {}
	auto_skill_timer = 0.0
	stage_elapsed = 0.0
	equipment.reset()
	development.reset()
	start_stage()
	return true


func current_stage() -> Dictionary:
	return CampaignCatalog.stage_at(balance, stage_index)


func stage_number() -> int:
	return stage_index + 1


func stage_count() -> int:
	return stages.size()


func hero_data() -> Dictionary:
	return ProgressionCatalog.build_hero_data(
		balance,
		CombatCatalog.hero_data(balance),
		level,
		equipment.get_total_bonuses(),
		development.get_bonuses(),
	)


func experience_to_next() -> int:
	var base: float = maxf(1.0, float(leveling.get("base_experience", 100.0)))
	var growth: float = maxf(1.01, float(leveling.get("experience_growth", 1.18)))
	return maxi(1, int(ceil(base * pow(growth, float(level - 1)))))


func summon_equipment(summon_id: String, count: int = 1) -> Dictionary:
	var reason: String = equipment.summon_block_reason(summon_id, count, stage_number(), gold, materials)
	if reason != "":
		return {"success": false, "reason": reason, "items": [], "guaranteed_count": 0}
	var cost: Dictionary = equipment.get_summon_cost(summon_id, count)
	var result: Dictionary = equipment.roll_summons(summon_id, count, stage_number())
	if not bool(result.get("success", false)):
		return result
	gold -= int(cost.get("gold", 0))
	materials -= int(cost.get("materials", 0))
	return result


func equip_item(item_id: String) -> bool:
	return equipment.equip(item_id)


func auto_equip_items() -> int:
	return equipment.auto_equip()


func upgrade_item(item_id: String) -> Dictionary:
	var cost: Dictionary = equipment.get_upgrade_cost(item_id)
	if not bool(cost.get("valid", false)):
		return {"success": false, "reason": str(cost.get("reason", "Улучшение недоступно"))}
	var gold_cost: int = int(cost.get("gold", 0))
	var materials_cost: int = int(cost.get("materials", 0))
	if gold < gold_cost or materials < materials_cost:
		return {"success": false, "reason": "Недостаточно золота или пепла"}
	if not equipment.upgrade(item_id):
		return {"success": false, "reason": "Улучшение не выполнено"}
	gold -= gold_cost
	materials -= materials_cost
	return {"success": true, "reason": "", "gold": gold_cost, "materials": materials_cost}


func dismantle_item(item_id: String, force: bool = false) -> Dictionary:
	var result: Dictionary = equipment.dismantle(item_id, force)
	if bool(result.get("success", false)):
		gold += int(result.get("gold", 0))
		materials += int(result.get("materials", 0))
	return result


func mass_dismantle_items() -> Dictionary:
	var result: Dictionary = equipment.mass_dismantle()
	gold += int(result.get("gold", 0))
	materials += int(result.get("materials", 0))
	return result


func toggle_item_lock(item_id: String) -> bool:
	return equipment.toggle_lock(item_id)


func set_equipment_filters(slot_index: int, rarity_index: int, affix_index: int) -> void:
	equipment.set_filters(slot_index, rarity_index, affix_index)


func allocate_attribute(attribute_id: String) -> bool:
	return development.allocate_attribute(attribute_id)


func upgrade_skill(skill_id: String) -> Dictionary:
	var cost: Dictionary = development.get_skill_upgrade_cost(skill_id)
	if not bool(cost.get("valid", false)):
		return {"success": false, "reason": str(cost.get("reason", "Улучшение недоступно"))}
	var points: int = int(cost.get("skill_points", 0))
	var gold_cost: int = int(cost.get("gold", 0))
	var materials_cost: int = int(cost.get("materials", 0))
	if development.skill_points < points:
		return {"success": false, "reason": "Недостаточно очков навыков"}
	if gold < gold_cost or materials < materials_cost:
		return {"success": false, "reason": "Недостаточно золота или пепла"}
	if not development.spend_skill_points(points):
		return {"success": false, "reason": "Не удалось списать очки навыков"}
	if not development.increase_skill_level(skill_id):
		return {"success": false, "reason": "Навык достиг предела"}
	gold -= gold_cost
	materials -= materials_cost
	_refresh_system_skills()
	return {"success": true, "reason": "", "skill_points": points, "gold": gold_cost, "materials": materials_cost}


func toggle_skill_auto(skill_id: String) -> bool:
	if not ProgressionCatalog.is_skill_unlocked(balance, skill_id, level):
		return development.is_skill_auto(skill_id)
	var value: bool = development.toggle_skill_auto(skill_id)
	_refresh_system_skills()
	return value


func cycle_skill_variant(skill_id: String) -> String:
	if not ProgressionCatalog.is_skill_unlocked(balance, skill_id, level):
		return ""
	var variant: String = development.cycle_skill_variant(skill_id)
	_refresh_system_skills()
	return variant


func upgrade_passive(passive_id: String) -> Dictionary:
	var cost: Dictionary = development.get_passive_upgrade_cost(passive_id)
	if not bool(cost.get("valid", false)):
		return {"success": false, "reason": str(cost.get("reason", "Улучшение недоступно"))}
	var points: int = int(cost.get("skill_points", 0))
	var gold_cost: int = int(cost.get("gold", 0))
	var materials_cost: int = int(cost.get("materials", 0))
	if development.skill_points < points:
		return {"success": false, "reason": "Недостаточно очков навыков"}
	if gold < gold_cost or materials < materials_cost:
		return {"success": false, "reason": "Недостаточно золота или пепла"}
	if not development.spend_skill_points(points):
		return {"success": false, "reason": "Не удалось списать очки навыков"}
	if not development.increase_passive_level(passive_id):
		return {"success": false, "reason": "Предел способности"}
	gold -= gold_cost
	materials -= materials_cost
	return {"success": true, "reason": "", "skill_points": points, "gold": gold_cost, "materials": materials_cost}


func select_pet(pet_id: String) -> bool:
	var selected: bool = development.select_pet(pet_id, stage_number())
	if selected:
		_refresh_system_pet()
	return selected


func upgrade_pet(pet_id: String) -> Dictionary:
	var cost: Dictionary = development.get_pet_upgrade_cost(pet_id, stage_number())
	if not bool(cost.get("valid", false)):
		return {"success": false, "reason": str(cost.get("reason", "Улучшение недоступно"))}
	var gold_cost: int = int(cost.get("gold", 0))
	var materials_cost: int = int(cost.get("materials", 0))
	if gold < gold_cost or materials < materials_cost:
		return {"success": false, "reason": "Недостаточно золота или пепла"}
	if not development.increase_pet_level(pet_id):
		return {"success": false, "reason": "Предел питомца"}
	gold -= gold_cost
	materials -= materials_cost
	_refresh_system_pet()
	return {"success": true, "reason": "", "gold": gold_cost, "materials": materials_cost}


func get_skill_ids() -> Array:
	return ProgressionCatalog.skill_ids(balance)


func get_passive_ids() -> Array:
	return ProgressionCatalog.passive_ids(balance)


func get_pet_ids() -> Array:
	return ProgressionCatalog.pet_ids(balance)


func get_skill_view(skill_id: String) -> Dictionary:
	var base: Dictionary = ProgressionCatalog.skill_by_id(balance, skill_id)
	var unlocked: bool = ProgressionCatalog.is_skill_unlocked(balance, skill_id, level)
	var effective: Dictionary = development.get_effective_skill_map()
	var active: Dictionary = effective.get(skill_id, {}) as Dictionary
	var variants: Dictionary = ProgressionCatalog.skill_variants(balance)
	var variant_id: String = development.get_skill_variant(skill_id)
	var variant: Dictionary = variants.get(variant_id, {}) as Dictionary
	return {
		"id": skill_id,
		"name": str(base.get("name", skill_id)),
		"description": str(base.get("description", "")),
		"kind": str(base.get("kind", "")),
		"unlocked": unlocked,
		"unlock_level": int(base.get("unlock_level", 1)),
		"level": development.get_skill_level(skill_id),
		"max_level": int(base.get("max_level", 5)),
		"variant": variant_id,
		"variant_name": str(variant.get("name", "Мощь")),
		"auto_use": development.is_skill_auto(skill_id),
		"cooldown_seconds": float(active.get("cooldown_seconds", base.get("cooldown_seconds", 0.0))),
		"cost": development.get_skill_upgrade_cost(skill_id),
	}


func get_passive_view(passive_id: String) -> Dictionary:
	var passive: Dictionary = ProgressionCatalog.passive_by_id(balance, passive_id)
	return {
		"id": passive_id,
		"name": str(passive.get("name", passive_id)),
		"description": str(passive.get("description", "")),
		"unlocked": ProgressionCatalog.is_passive_unlocked(balance, passive_id, level),
		"unlock_level": int(passive.get("unlock_level", 1)),
		"level": development.get_passive_level(passive_id),
		"max_level": int(passive.get("max_level", 5)),
		"cost": development.get_passive_upgrade_cost(passive_id),
	}


func get_pet_view(pet_id: String) -> Dictionary:
	var pet: Dictionary = ProgressionCatalog.pet_by_id(balance, pet_id)
	return {
		"id": pet_id,
		"name": str(pet.get("name", pet_id)),
		"description": str(pet.get("description", "")),
		"unlocked": ProgressionCatalog.is_pet_unlocked(balance, pet_id, stage_number()),
		"unlock_stage": int(pet.get("unlock_stage", 1)),
		"level": development.get_pet_level(pet_id),
		"max_level": int(pet.get("max_level", 5)),
		"selected": development.selected_pet_id == pet_id,
		"cost": development.get_pet_upgrade_cost(pet_id, stage_number()),
	}


func get_balance_report() -> Dictionary:
	return ProgressionCatalog.balance_report(balance, hero_data(), stage_number())


func get_auto_battle_report() -> Dictionary:
	return ProgressionCatalog.auto_battle_report(balance, development.get_auto_skill_ids().size(), stage_elapsed)


func get_summary() -> Dictionary:
	var stage: Dictionary = current_stage()
	var equipment_summary: Dictionary = equipment.get_summary()
	var development_summary: Dictionary = development.get_summary()
	var balance_report: Dictionary = get_balance_report()
	var auto_battle_report: Dictionary = get_auto_battle_report()
	return {
		"stage": stage_number(),
		"stages": stage_count(),
		"stage_name": str(stage.get("name", "")),
		"region": str(campaign.get("region", "")),
		"kind": CampaignCatalog.stage_kind(stage),
		"boss": CampaignCatalog.stage_is_boss(stage),
		"status": status,
		"status_name": status_name(status),
		"level": level,
		"experience": experience,
		"experience_to_next": experience_to_next(),
		"gold": gold,
		"materials": materials,
		"victories": victories,
		"defeats": defeats,
		"last_reward": last_reward.duplicate(),
		"boss_phase_count": boss_phase_count,
		"boss_phase_active": current_boss_phase_active,
		"boss_phase_name": current_boss_phase_name,
		"equipment_power": float(equipment_summary.get("power", 0.0)),
		"inventory_count": int(equipment_summary.get("inventory_count", 0)),
		"equipped_count": int(equipment_summary.get("equipped_count", 0)),
		"total_summons": int(equipment_summary.get("total_summons", 0)),
		"class_name": str(CombatCatalog.hero_data(balance).get("class_name", "Пепельный странник")),
		"attribute_points": int(development_summary.get("attribute_points", 0)),
		"skill_points": int(development_summary.get("skill_points", 0)),
		"development_bonus_score": float(development_summary.get("bonus_score", 0.0)),
		"selected_pet_name": str(development_summary.get("selected_pet_name", "Не выбран")),
		"pet_attack_count": pet_attack_count,
		"balance_ratio": float(balance_report.get("ratio", 0.0)),
		"balance_status": str(balance_report.get("status", "")),
		"auto_skill_count": int(auto_battle_report.get("auto_skill_count", 0)),
		"total_skill_count": int(auto_battle_report.get("total_skill_count", 0)),
		"auto_skill_share": float(auto_battle_report.get("auto_skill_share", 0.0)),
		"auto_battle_status": str(auto_battle_report.get("status", "")),
		"stage_duration": float(auto_battle_report.get("stage_duration", 0.0)),
		"min_stage_duration": float(auto_battle_report.get("min_stage_duration", 0.0)),
	}


static func status_name(value: int) -> String:
	match value:
		STATUS_BATTLE:
			return "Бой"
		STATUS_VICTORY:
			return "Победа"
		STATUS_DEFEAT:
			return "Поражение"
		STATUS_COMPLETE:
			return "Кампания пройдена"
	return "Неизвестно"


func _register_victory() -> void:
	var stage: Dictionary = current_stage()
	var reward: Dictionary = stage.get("reward", {}) as Dictionary
	var experience_gain: int = maxi(0, int(reward.get("experience", 0)))
	var gold_gain: int = maxi(0, int(reward.get("gold", economy.get("gold_per_victory", 0))))
	var materials_gain: int = maxi(0, int(reward.get("materials", 0)))
	var levels_gained: int = 0
	experience += experience_gain
	gold += gold_gain
	materials += materials_gain
	victories += 1
	while experience >= experience_to_next():
		experience -= experience_to_next()
		level += 1
		levels_gained += 1
	development.set_level(level, false)
	development.grant_level_rewards(levels_gained)
	var attribute_gain: int = levels_gained * maxi(0, int(leveling.get("attribute_points_per_level", 0)))
	var skill_gain: int = levels_gained * maxi(0, int(leveling.get("skill_points_per_level", 0)))
	last_reward = {
		"experience": experience_gain,
		"gold": gold_gain,
		"materials": materials_gain,
		"levels": levels_gained,
		"attribute_points": attribute_gain,
		"skill_points": skill_gain,
	}
	if stage_index >= stages.size() - 1:
		status = STATUS_COMPLETE
	else:
		status = STATUS_VICTORY


func _auto_use_skills(delta: float) -> void:
	var interval: float = maxf(0.1, float(leveling.get("auto_skill_interval_seconds", 1.0)))
	auto_skill_timer += delta
	if auto_skill_timer < interval:
		return
	auto_skill_timer = 0.0
	for skill_id in development.get_auto_skill_ids():
		if system.get_cooldown_remaining(str(skill_id)) <= 0.0:
			use_skill(str(skill_id))
			return


func _refresh_system_skills() -> void:
	if system != null:
		system.skills = development.get_effective_skill_map()


func _refresh_system_pet() -> void:
	if system != null:
		system.set_pet_data(development.get_pet_combat_data())


func _sync_boss_phases() -> void:
	# Состояние фазы считывается из текущего боя без обратной ссылки сигнала
	# на CampaignState: так не возникает цикл между RefCounted-объектами.
	if system == null:
		return
	var battle_id: int = int(system.get_instance_id())
	var seen: int = int(observed_phase_counts.get(battle_id, 0))
	var total: int = int(system.boss_phase_count)
	if total <= seen:
		return
	observed_phase_counts[battle_id] = total
	for phase_number in range(total - seen):
		boss_phase_count += 1
		current_boss_phase_active = true
		current_boss_phase_name = str(system.last_boss_phase_name)
		boss_phase_started.emit(str(system.last_boss_phase_enemy), current_boss_phase_name)


func _sync_pet_attacks() -> void:
	if system == null:
		return
	var battle_id: int = int(system.get_instance_id())
	var seen: int = int(observed_pet_counts.get(battle_id, 0))
	var total: int = int(system.pet_attack_count)
	if total <= seen:
		return
	observed_pet_counts[battle_id] = total
	pet_attack_count += total - seen
