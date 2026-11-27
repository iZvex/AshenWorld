extends RefCounted

# Состояние одного участника боя. Формулы урона сюда не входят:
# они собраны в combat_formulas.gd и не дублируются.

var display_name: String = ""
var max_health: float = 0.0
var health: float = 0.0
var attack: float = 0.0
var base_attack: float = 0.0
var defense: float = 0.0
var crit_chance: float = 0.0
var shield: float = 0.0
var alive: bool = true
var is_boss: bool = false
var phase_threshold: float = 0.0
var phase_attack_multiplier: float = 1.0
var phase_name: String = ""
var phase_activated: bool = false


func _init(data: Dictionary) -> void:
	display_name = str(data.get("name", "Безымянный"))
	max_health = maxf(1.0, float(data.get("max_health", 1.0)))
	health = max_health
	attack = maxf(0.0, float(data.get("attack", 0.0)))
	base_attack = attack
	defense = maxf(0.0, float(data.get("defense", 0.0)))
	crit_chance = clampf(float(data.get("crit_chance", 0.0)), 0.0, 1.0)
	is_boss = bool(data.get("is_boss", false))
	if is_boss:
		phase_threshold = clampf(float(data.get("phase_threshold", 0.0)), 0.0, 0.99)
		phase_attack_multiplier = maxf(1.0, float(data.get("phase_attack_multiplier", 1.0)))
		phase_name = str(data.get("phase_name", "Ярость"))


func receive_damage(amount: float) -> float:
	if not alive or amount <= 0.0:
		return 0.0
	var absorbed: float = minf(shield, amount)
	shield -= absorbed
	var to_health: float = minf(health, amount - absorbed)
	health = maxf(0.0, health - to_health)
	if health <= 0.0:
		alive = false
	return to_health


func add_shield(amount: float) -> void:
	shield = maxf(0.0, shield + amount)


func restore() -> void:
	health = max_health
	shield = 0.0
	alive = true
	attack = base_attack
	phase_activated = false
