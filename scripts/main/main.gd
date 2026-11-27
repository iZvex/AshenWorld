extends Control

# Стартовая сцена с рабочим прототипом боя и тематическим оформлением.
# Каждый элемент показывает реальное состояние CombatSystem, заглушек нет.

const CombatSystem = preload("res://scripts/combat/combat_system.gd")
const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const AshenStyle = preload("res://scripts/ui/ashen_style.gd")

var title_label: Label
var subtitle_label: Label
var enemy_card: PanelContainer
var enemy_name_label: Label
var enemy_health_bar: ProgressBar
var hero_card: PanelContainer
var hero_name_label: Label
var hero_health_bar: ProgressBar
var shield_bar: ProgressBar
var skill_button: Button
var battle_log: Label
var balance_label: Label

var system
var log_lines: PackedStringArray = PackedStringArray()
var initialized: bool = false


func _ready() -> void:
	setup(_load_data())


func setup(data: Dictionary) -> void:
	# Явный вызов нужен точечному тесту: при запуске через --script узел
	# входит в дерево раньше, чем движок успевает вызвать _ready().
	if initialized:
		return
	initialized = true
	_bind_nodes()
	theme = AshenStyle.build_theme()
	_apply_custom_styles()
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
	_add_log("Пепел поднимается — бой начинается")
	_update_view()
	print("Оформление и прототип боя запущены, противников: %d" % CombatCatalog.enemy_list(data).size())


func _bind_nodes() -> void:
	title_label = get_node("Margin/Panel/TitleBlock/TitleLabel")
	subtitle_label = get_node("Margin/Panel/TitleBlock/SubtitleLabel")
	enemy_card = get_node("Margin/Panel/EnemyCard")
	enemy_name_label = get_node("Margin/Panel/EnemyCard/EnemyBox/EnemyName")
	enemy_health_bar = get_node("Margin/Panel/EnemyCard/EnemyBox/EnemyHealthBar")
	hero_card = get_node("Margin/Panel/HeroCard")
	hero_name_label = get_node("Margin/Panel/HeroCard/HeroBox/HeroName")
	hero_health_bar = get_node("Margin/Panel/HeroCard/HeroBox/HeroHealthBar")
	shield_bar = get_node("Margin/Panel/HeroCard/HeroBox/ShieldBar")
	skill_button = get_node("Margin/Panel/SkillButton")
	battle_log = get_node("Margin/Panel/LogCard/BattleLog")
	balance_label = get_node("Margin/Panel/BalanceLabel")


func _load_data() -> Dictionary:
	# В игре данные приходят из автозагрузки, а в точечном тесте сцены
	# читаются напрямую из того же файла баланса.
	var config_node: Node = get_node_or_null("/root/GameConfig")
	if config_node != null:
		var from_autoload: Dictionary = config_node.get("values") as Dictionary
		if not from_autoload.is_empty():
			return from_autoload
	return CombatCatalog.load_balance()


func _apply_custom_styles() -> void:
	enemy_health_bar.add_theme_stylebox_override("background", AshenStyle.bar_background())
	enemy_health_bar.add_theme_stylebox_override("fill", AshenStyle.bar_fill(AshenStyle.ENEMY_COLOR))
	hero_health_bar.add_theme_stylebox_override("background", AshenStyle.bar_background())
	hero_health_bar.add_theme_stylebox_override("fill", AshenStyle.bar_fill(AshenStyle.HERO_COLOR))
	shield_bar.add_theme_stylebox_override("background", AshenStyle.bar_background())
	shield_bar.add_theme_stylebox_override("fill", AshenStyle.bar_fill(AshenStyle.SHIELD_COLOR))
	title_label.add_theme_color_override("font_color", AshenStyle.GOLD)
	subtitle_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	enemy_name_label.add_theme_color_override("font_color", AshenStyle.CRIMSON)
	hero_name_label.add_theme_color_override("font_color", AshenStyle.STEEL)
	balance_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	battle_log.add_theme_color_override("font_color", AshenStyle.PARCHMENT)


func _process(delta: float) -> void:
	if not initialized:
		return
	system.advance(delta)
	_update_view()


func _update_view() -> void:
	hero_name_label.text = system.hero.display_name
	hero_health_bar.max_value = system.hero.max_health
	hero_health_bar.value = system.hero.health
	shield_bar.max_value = system.hero.max_health
	shield_bar.value = system.hero.shield
	if system.enemy != null:
		enemy_name_label.text = system.enemy.display_name
		enemy_health_bar.max_value = system.enemy.max_health
		enemy_health_bar.value = system.enemy.health
	else:
		enemy_name_label.text = "Противники повержены"
		enemy_health_bar.value = 0.0
	var remaining: float = system.get_cooldown_remaining("heavy_strike")
	skill_button.disabled = not system.running or remaining > 0.0
	if remaining > 0.0:
		skill_button.text = "ТЯЖЁЛЫЙ УДАР · %.1f с" % remaining
	else:
		skill_button.text = "ТЯЖЁЛЫЙ УДАР"


func _on_skill_pressed() -> void:
	system.use_skill("heavy_strike")


func _on_damage_dealt(target_name: String, amount: float, is_critical: bool) -> void:
	var suffix: String = " — критический удар!" if is_critical else ""
	_add_log("%s получает %.0f урона%s" % [target_name, amount, suffix])
	var hit_hero: bool = target_name == system.hero.display_name
	var card: Control = hero_card if hit_hero else enemy_card
	var color: Color = AshenStyle.CRIMSON if hit_hero else AshenStyle.GOLD
	_flash(card, color)
	_spawn_floating_number("%.0f" % amount, card, color)


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
	battle_log.text = "\n".join(log_lines)


func _flash(card: Control, color: Color) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(card, "modulate", color, 0.08)
	tween.tween_property(card, "modulate", Color.WHITE, 0.28)


func _spawn_floating_number(text: String, near: Control, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 32)
	var center: Vector2 = near.get_global_rect().get_center()
	label.position = center - Vector2(18, 20)
	add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 90.0, 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)
