extends RefCounted

# Логика автоматического боя: не зависит от сцен и интерфейса, поэтому
# проверяется отдельным точечным тестом без запуска всей игры.
# Новые боевые параметры читаются из hero_data, а помощь питомца — из pet_data.

const Combatant = preload("res://scripts/combat/combatant.gd")
const CombatFormulas = preload("res://scripts/combat/combat_formulas.gd")

signal damage_dealt(target_name: String, amount: float, is_critical: bool)
signal enemy_defeated(enemy_name: String)
signal hero_defeated()
signal skill_used(skill_name: String)
signal shield_changed(amount: float)
signal enemy_phase_started(enemy_name: String, phase_name: String, attack_multiplier: float)
signal pet_attack(pet_name: String, assist_name: String, amount: float)
signal hero_healed(amount: float)
signal attack_dodged(target_name: String)

var balance: Dictionary = {}
var hero
var enemy
var enemies: Array = []
var skills: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var elapsed: float = 0.0
var hero_interval: float = 1.0
var enemy_interval: float = 1.0
var hero_next_attack: float = 0.0
var enemy_next_attack: float = 0.0
var skill_cooldowns: Dictionary = {}
var enemy_index: int = -1
var running: bool = false
var boss_phase_count: int = 0
var current_boss_phase_active: bool = false
var current_boss_phase_name: String = ""
var last_boss_phase_enemy: String = ""
var last_boss_phase_name: String = ""
var pet_name: String = ""
var assist_name: String = ""
var pet_attack_ratio: float = 0.0
var pet_interval: float = 3.0
var pet_next_attack: float = 3.0
var pet_attack_count: int = 0


func _init(
	hero_data: Dictionary,
	enemy_list: Array,
	skill_map: Dictionary,
	combat_balance: Dictionary,
	seed_value: int = 12345,
	pet_data: Dictionary = {},
) -> void:
	balance = combat_balance
	enemies = enemy_list.duplicate()
	skills = skill_map
	rng.seed = seed_value
	hero = Combatant.new(hero_data)
	var minimum_interval: float = maxf(0.1, float(balance.get("min_attack_interval", 0.45)))
	hero_interval = maxf(minimum_interval, float(hero_data.get("attack_interval_seconds", balance.get("attack_interval_seconds", 1.0))))
	enemy_interval = maxf(minimum_interval, float(balance.get("attack_interval_seconds", 1.0)))
	hero_next_attack = hero_interval
	pet_name = str(pet_data.get("pet_name", ""))
	assist_name = str(pet_data.get("assist_name", ""))
	pet_attack_ratio = maxf(0.0, float(pet_data.get("attack_ratio", 0.0)))
	pet_interval = maxf(0.5, float(pet_data.get("interval_seconds", 3.0)))
	pet_next_attack = pet_interval
	running = true
	spawn_next_enemy(enemy_interval)


func set_pet_data(pet_data: Dictionary) -> void:
	pet_name = str(pet_data.get("pet_name", ""))
	assist_name = str(pet_data.get("assist_name", ""))
	pet_attack_ratio = maxf(0.0, float(pet_data.get("attack_ratio", 0.0)))
	pet_interval = maxf(0.5, float(pet_data.get("interval_seconds", 3.0)))
	pet_next_attack = elapsed + pet_interval


func spawn_next_enemy(interval: float = -1.0) -> void:
	enemy_index += 1
	current_boss_phase_active = false
	current_boss_phase_name = ""
	if enemy_index >= enemies.size():
		enemy = null
		running = false
		return
	enemy = Combatant.new(enemies[enemy_index])
	if interval < 0.0:
		interval = enemy_interval
	enemy_next_attack = elapsed + interval


func advance(delta: float) -> void:
	if not running or delta <= 0.0:
		return
	elapsed += delta
	# Враг мог погибнуть вне обычной атаки: от эффекта, навыка или прямого урона.
	# Без этой проверки бой останавливался навсегда, потому что смена врага
	# выполнялась только внутри perform_attack.
	if enemy != null and not enemy.alive:
		enemy_defeated.emit(enemy.display_name)
		spawn_next_enemy()
	if hero.alive and hero.health_regen > 0.0:
		var restored: float = hero.heal(hero.health_regen * delta)
		if restored > 0.0:
			hero_healed.emit(restored)
	if hero_next_attack <= elapsed and hero.alive:
		perform_attack(hero, enemy, 1.0, 0.0)
		hero_next_attack = elapsed + hero_interval
	if enemy != null and enemy.alive and enemy_next_attack <= elapsed:
		perform_attack(enemy, hero, 1.0, 0.0)
		enemy_next_attack = elapsed + enemy_interval
	if pet_attack_ratio > 0.0 and pet_next_attack <= elapsed and hero.alive and enemy != null and enemy.alive:
		_pet_strike()
		pet_next_attack = elapsed + pet_interval


func perform_attack(attacker, target, multiplier: float, crit_chance_bonus: float = 0.0) -> void:
	if target == null or not target.alive or not attacker.alive:
		return
	if target.dodge > 0.0 and CombatFormulas.roll_dodge(target.dodge, rng):
		attack_dodged.emit(target.display_name)
		return
	var critical: bool = CombatFormulas.roll_critical(attacker.crit_chance + crit_chance_bonus, rng)
	var amount: float = CombatFormulas.calculate_damage(
		attacker.attack,
		target.defense,
		multiplier,
		critical,
		balance,
		attacker.critical_multiplier,
		target.resistance,
	)
	var dealt: float = target.receive_damage(amount)
	damage_dealt.emit(target.display_name, dealt, critical)
	if attacker == hero and dealt > 0.0 and hero.lifesteal > 0.0:
		var restored: float = hero.heal(dealt * hero.lifesteal)
		if restored > 0.0:
			hero_healed.emit(restored)
	if not target.alive:
		if target == hero:
			hero_defeated.emit()
			running = false
		elif enemy != null and target == enemy:
			enemy_defeated.emit(target.display_name)
			spawn_next_enemy()
	elif target == enemy:
		_check_enemy_phase()


func _pet_strike() -> void:
	if enemy == null or not enemy.alive or pet_attack_ratio <= 0.0:
		return
	var critical: bool = CombatFormulas.roll_critical(hero.crit_chance, rng)
	var amount: float = CombatFormulas.calculate_damage(
		hero.attack * pet_attack_ratio,
		enemy.defense,
		1.0,
		critical,
		balance,
		hero.critical_multiplier,
		enemy.resistance,
	)
	var dealt: float = enemy.receive_damage(amount)
	pet_attack_count += 1
	damage_dealt.emit(enemy.display_name, dealt, critical)
	pet_attack.emit(pet_name, assist_name, dealt)
	if not enemy.alive:
		enemy_defeated.emit(enemy.display_name)
		spawn_next_enemy()
	else:
		_check_enemy_phase()


func _check_enemy_phase() -> void:
	# Босс однократно усиливает атаку, когда его здоровье опускается до порога.
	if enemy == null or not enemy.alive or not enemy.is_boss:
		return
	if enemy.phase_activated or enemy.phase_threshold <= 0.0:
		return
	if enemy.health / enemy.max_health > enemy.phase_threshold:
		return
	enemy.phase_activated = true
	var multiplier: float = maxf(1.0, enemy.phase_attack_multiplier)
	enemy.attack *= multiplier
	boss_phase_count += 1
	current_boss_phase_active = true
	current_boss_phase_name = enemy.phase_name
	last_boss_phase_enemy = enemy.display_name
	last_boss_phase_name = enemy.phase_name
	enemy_phase_started.emit(enemy.display_name, enemy.phase_name, multiplier)


func use_skill(skill_id: String) -> bool:
	if not running or not hero.alive or not skills.has(skill_id):
		return false
	if get_cooldown_remaining(skill_id) > 0.0:
		return false
	var skill: Dictionary = skills[skill_id] as Dictionary
	skill_cooldowns[skill_id] = elapsed + float(skill.get("cooldown_seconds", 1.0))
	var multiplier: float = float(skill.get("damage_multiplier", 0.0))
	if multiplier > 0.0 and enemy != null:
		perform_attack(hero, enemy, multiplier, float(skill.get("critical_chance_bonus", 0.0)))
	var shield_ratio: float = float(skill.get("shield_ratio", 0.0))
	if shield_ratio > 0.0:
		var shield_amount: float = hero.max_health * shield_ratio
		hero.add_shield(shield_amount)
		shield_changed.emit(shield_amount)
	var heal_ratio: float = float(skill.get("heal_ratio", 0.0))
	if heal_ratio > 0.0:
		var restored: float = hero.heal(hero.max_health * heal_ratio)
		if restored > 0.0:
			hero_healed.emit(restored)
	skill_used.emit(str(skill.get("name", skill_id)))
	return true


func get_cooldown_remaining(skill_id: String) -> float:
	return maxf(0.0, float(skill_cooldowns.get(skill_id, 0.0)) - elapsed)


func get_state() -> Dictionary:
	return {
		"hero_health": hero.health,
		"hero_max_health": hero.max_health,
		"hero_shield": hero.shield,
		"hero_physical_attack": hero.physical_attack,
		"hero_magic_attack": hero.magic_attack,
		"hero_crit_chance": hero.crit_chance,
		"hero_critical_multiplier": hero.critical_multiplier,
		"hero_attack_interval": hero.attack_interval_seconds,
		"hero_lifesteal": hero.lifesteal,
		"hero_dodge": hero.dodge,
		"hero_resistance": hero.resistance,
		"hero_health_regen": hero.health_regen,
		"enemy_name": enemy.display_name if enemy != null else "",
		"enemy_health": enemy.health if enemy != null else 0.0,
		"enemy_max_health": enemy.max_health if enemy != null else 0.0,
		"pet_name": pet_name,
		"pet_attack_count": pet_attack_count,
		"running": running,
		"defeated": maxi(0, enemy_index),
	}
