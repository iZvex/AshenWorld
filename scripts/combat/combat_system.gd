extends RefCounted

# Логика автоматического боя: не зависит от сцен и интерфейса, поэтому
# проверяется отдельным точечным тестом без запуска всей игры.

const Combatant = preload("res://scripts/combat/combatant.gd")
const CombatFormulas = preload("res://scripts/combat/combat_formulas.gd")

signal damage_dealt(target_name: String, amount: float, is_critical: bool)
signal enemy_defeated(enemy_name: String)
signal hero_defeated()
signal skill_used(skill_name: String)
signal shield_changed(amount: float)

var balance: Dictionary = {}
var hero
var enemy
var enemies: Array = []
var skills: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var elapsed: float = 0.0
var hero_next_attack: float = 0.0
var enemy_next_attack: float = 0.0
var skill_cooldowns: Dictionary = {}
var enemy_index: int = -1
var running: bool = false


func _init(hero_data: Dictionary, enemy_list: Array, skill_map: Dictionary, combat_balance: Dictionary, seed_value: int = 12345) -> void:
	balance = combat_balance
	enemies = enemy_list.duplicate()
	skills = skill_map
	rng.seed = seed_value
	hero = Combatant.new(hero_data)
	hero.crit_chance = float(combat_balance.get("critical_chance", hero.crit_chance))
	var interval: float = float(combat_balance.get("attack_interval_seconds", 1.0))
	hero_next_attack = interval
	running = true
	spawn_next_enemy(interval)


func spawn_next_enemy(interval: float = -1.0) -> void:
	enemy_index += 1
	if enemy_index >= enemies.size():
		enemy = null
		running = false
		return
	enemy = Combatant.new(enemies[enemy_index])
	if interval < 0.0:
		interval = float(balance.get("attack_interval_seconds", 1.0))
	enemy_next_attack = elapsed + interval


func advance(delta: float) -> void:
	if not running or delta <= 0.0:
		return
	elapsed += delta
	var interval: float = float(balance.get("attack_interval_seconds", 1.0))
	if hero_next_attack <= elapsed and hero.alive:
		perform_attack(hero, enemy, 1.0)
		hero_next_attack = elapsed + interval
	if enemy != null and enemy.alive and enemy_next_attack <= elapsed:
		perform_attack(enemy, hero, 1.0)
		enemy_next_attack = elapsed + interval


func perform_attack(attacker, target, multiplier: float) -> void:
	if target == null or not target.alive or not attacker.alive:
		return
	var critical: bool = CombatFormulas.roll_critical(attacker.crit_chance, rng)
	var amount: float = CombatFormulas.calculate_damage(attacker.attack, target.defense, multiplier, critical, balance)
	var dealt: float = target.receive_damage(amount)
	damage_dealt.emit(target.display_name, dealt, critical)
	if not target.alive:
		if target == hero:
			hero_defeated.emit()
			running = false
		elif enemy != null and target == enemy:
			enemy_defeated.emit(target.display_name)
			spawn_next_enemy()


func use_skill(skill_id: String) -> bool:
	if not running or not hero.alive or not skills.has(skill_id):
		return false
	if get_cooldown_remaining(skill_id) > 0.0:
		return false
	var skill: Dictionary = skills[skill_id] as Dictionary
	skill_cooldowns[skill_id] = elapsed + float(skill.get("cooldown_seconds", 1.0))
	var multiplier: float = float(skill.get("damage_multiplier", 0.0))
	if multiplier > 0.0 and enemy != null:
		perform_attack(hero, enemy, multiplier)
	var shield_ratio: float = float(skill.get("shield_ratio", 0.0))
	if shield_ratio > 0.0:
		var shield_amount: float = hero.max_health * shield_ratio
		hero.add_shield(shield_amount)
		shield_changed.emit(shield_amount)
	skill_used.emit(str(skill.get("name", skill_id)))
	return true


func get_cooldown_remaining(skill_id: String) -> float:
	return maxf(0.0, float(skill_cooldowns.get(skill_id, 0.0)) - elapsed)


func get_state() -> Dictionary:
	return {
		"hero_health": hero.health,
		"hero_max_health": hero.max_health,
		"hero_shield": hero.shield,
		"enemy_name": enemy.display_name if enemy != null else "",
		"enemy_health": enemy.health if enemy != null else 0.0,
		"enemy_max_health": enemy.max_health if enemy != null else 0.0,
		"running": running,
		"defeated": maxi(0, enemy_index),
	}
