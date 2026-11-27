extends Control

# Стартовая сцена с работающим прототипом боя. Каждый элемент интерфейса
# показывает реальное состояние CombatSystem, заглушек здесь нет.

const CombatSystem = preload("res://scripts/combat/combat_system.gd")
const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")

@onready var balance_label: Label = $Panel/BalanceLabel
@onready var hero_label: Label = $Panel/HeroLabel
@onready var enemy_label: Label = $Panel/EnemyLabel
@onready var log_label: Label = $Panel/LogLabel
@onready var skill_button: Button = $Panel/SkillButton

var system
var log_lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var data: Dictionary = GameConfig.values
	balance_label.text = "Разделов баланса: %d" % data.size()
	system = CombatSystem.new(
		CombatCatalog.hero_data(data),
		CombatCatalog.enemy_list(data),
		CombatCatalog.skill_map(data),
		CombatCatalog.combat_balance(data),
	)
	system.damage_dealt.connect(_on_damage_dealt)
	system.enemy_defeated.connect(_on_enemy_defeated)
	system.hero_defeated.connect(_on_hero_defeated)
	system.skill_used.connect(_on_skill_used)
	system.shield_changed.connect(_on_shield_changed)
	skill_button.pressed.connect(_on_skill_pressed)
	_add_log("Бой начинается")
	_update_view()
	print("Прототип боя запущен, противников: %d" % CombatCatalog.enemy_list(data).size())


func _process(delta: float) -> void:
	system.advance(delta)
	_update_view()


func _update_view() -> void:
	hero_label.text = "Герой %s: %.0f / %.0f (щит %.0f)" % [
		system.hero.display_name,
		system.hero.health,
		system.hero.max_health,
		system.hero.shield,
	]
	if system.enemy != null:
		enemy_label.text = "%s: %.0f / %.0f" % [
			system.enemy.display_name,
			system.enemy.health,
			system.enemy.max_health,
		]
	else:
		enemy_label.text = "Противники повержены"
	var remaining: float = system.get_cooldown_remaining("heavy_strike")
	skill_button.disabled = not system.running or remaining > 0.0
	if remaining > 0.0:
		skill_button.text = "Тяжёлый удар (%.1f с)" % remaining
	else:
		skill_button.text = "Тяжёлый удар"


func _on_skill_pressed() -> void:
	system.use_skill("heavy_strike")


func _on_damage_dealt(target_name: String, amount: float, is_critical: bool) -> void:
	var suffix: String = " — критический удар!" if is_critical else ""
	_add_log("%s получает %.0f урона%s" % [target_name, amount, suffix])


func _on_enemy_defeated(enemy_name: String) -> void:
	_add_log("%s повержен" % enemy_name)


func _on_hero_defeated() -> void:
	_add_log("Герой пал")


func _on_skill_used(skill_name: String) -> void:
	_add_log("Навык: %s" % skill_name)


func _on_shield_changed(amount: float) -> void:
	_add_log("Щит увеличен на %.0f" % amount)


func _add_log(line: String) -> void:
	log_lines.insert(0, line)
	if log_lines.size() > 7:
		log_lines.resize(7)
	log_label.text = "\n".join(log_lines)
