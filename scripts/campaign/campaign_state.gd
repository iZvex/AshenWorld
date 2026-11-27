extends RefCounted

# Состояние игрового цикла: этапы, победы, опыт, валюта и экипировка.
# Сохранения появятся позже, поэтому прогресс живёт в течение запуска игры.

const CombatSystem = preload("res://scripts/combat/combat_system.gd")
const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const CampaignCatalog = preload("res://scripts/campaign/campaign_catalog.gd")
const EquipmentState = preload("res://scripts/equipment/equipment_state.gd")

const STATUS_BATTLE: int = 0
const STATUS_VICTORY: int = 1
const STATUS_DEFEAT: int = 2
const STATUS_COMPLETE: int = 3

signal boss_phase_started(enemy_name: String, phase_name: String)

var balance: Dictionary = {}
var stages: Array = []
var progression: Dictionary = {}
var economy: Dictionary = {}
var campaign: Dictionary = {}
var equipment
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
var seed_value: int = 12345


func _init(data: Dictionary, initial_seed: int = 12345) -> void:
	balance = data
	stages = CampaignCatalog.stages(data)
	progression = data.get("progression", {}) as Dictionary
	economy = data.get("economy", {}) as Dictionary
	campaign = CampaignCatalog.campaign(data)
	seed_value = initial_seed
	equipment = EquipmentState.new(data, seed_value + 777)
	start_stage()


func start_stage() -> void:
	current_boss_phase_active = false
	current_boss_phase_name = ""
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
		CombatCatalog.skill_map(balance),
		CombatCatalog.combat_balance(balance),
		seed_value + stage_index * 101,
	)
	observed_phase_counts[int(system.get_instance_id())] = 0
	status = STATUS_BATTLE


func advance(delta: float) -> void:
	if status != STATUS_BATTLE or system == null:
		return
	system.advance(delta)
	_sync_boss_phases()
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
	observed_phase_counts = {}
	last_reward = {}
	equipment.reset()
	start_stage()
	return true


func current_stage() -> Dictionary:
	return CampaignCatalog.stage_at(balance, stage_index)


func stage_number() -> int:
	return stage_index + 1


func stage_count() -> int:
	return stages.size()


func hero_data() -> Dictionary:
	var hero: Dictionary = (CombatCatalog.hero_data(balance)).duplicate()
	var bonus: int = maxi(0, level - 1)
	var equipped_bonuses: Dictionary = equipment.get_total_bonuses()
	hero["max_health"] = float(hero.get("max_health", 1.0)) + bonus * float(progression.get("max_health_per_level", 0.0)) + float(equipped_bonuses.get("max_health", 0.0))
	hero["attack"] = float(hero.get("attack", 0.0)) + bonus * float(progression.get("attack_per_level", 0.0)) + float(equipped_bonuses.get("attack", 0.0))
	hero["defense"] = float(hero.get("defense", 0.0)) + bonus * float(progression.get("defense_per_level", 0.0)) + float(equipped_bonuses.get("defense", 0.0))
	return hero


func experience_to_next() -> int:
	var base: float = maxf(1.0, float(progression.get("base_experience", 100.0)))
	var growth: float = maxf(1.01, float(progression.get("experience_growth", 1.18)))
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


func get_summary() -> Dictionary:
	var stage: Dictionary = current_stage()
	var equipment_summary: Dictionary = equipment.get_summary()
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
	last_reward = {
		"experience": experience_gain,
		"gold": gold_gain,
		"materials": materials_gain,
		"levels": levels_gained,
	}
	if stage_index >= stages.size() - 1:
		status = STATUS_COMPLETE
	else:
		status = STATUS_VICTORY


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
