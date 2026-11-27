extends Control

# Компактный экран кампании: здоровье героя и противника в одной строке,
# продвижение по этапам, награды и навыки. Декоративных заглушек нет:
# все значения берутся из CampaignState и CombatSystem.

const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const CampaignState = preload("res://scripts/campaign/campaign_state.gd")
const AshenStyle = preload("res://scripts/ui/ashen_style.gd")

var title_label: Label
var stage_label: Label
var sigil: TextureRect
var divider: TextureRect
var level_label: Label
var experience_bar: ProgressBar
var gold_label: Label
var health_panel: PanelContainer
var health_row: HBoxContainer
var hero_side: VBoxContainer
var enemy_side: VBoxContainer
var hero_label: Label
var enemy_label: Label
var hero_health_bar: ProgressBar
var enemy_health_bar: ProgressBar
var shield_bar: ProgressBar
var separator_label: Label
var enemy_hint_label: Label
var stage_notice: Label
var strike_button: Button
var guard_button: Button
var action_button: Button
var log_card: PanelContainer
var battle_log: Label
var hint_label: Label

var campaign
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
	_apply_styles()
	campaign = CampaignState.new(data)
	campaign.boss_phase_started.connect(_on_boss_phase_started)
	_connect_battle_signals()
	strike_button.pressed.connect(_on_strike_pressed)
	guard_button.pressed.connect(_on_guard_pressed)
	action_button.pressed.connect(_on_action_pressed)
	_add_log("Этап %d: %s" % [campaign.stage_number(), str(campaign.current_stage().get("name", ""))])
	_update_view()
	print("Игровой цикл запущен: этапов %d, текущий этап %d" % [campaign.stage_count(), campaign.stage_number()])


func _bind_nodes() -> void:
	title_label = get_node("Margin/Panel/Header/Titles/TitleLabel")
	stage_label = get_node("Margin/Panel/Header/Titles/StageLabel")
	sigil = get_node("Margin/Panel/Header/Sigil")
	divider = get_node("Margin/Panel/Divider")
	level_label = get_node("Margin/Panel/StatusRow/LevelLabel")
	experience_bar = get_node("Margin/Panel/StatusRow/ExperienceBar")
	gold_label = get_node("Margin/Panel/StatusRow/GoldLabel")
	health_panel = get_node("Margin/Panel/HealthPanel")
	health_row = get_node("Margin/Panel/HealthPanel/HealthBox/HealthRow")
	hero_side = get_node("Margin/Panel/HealthPanel/HealthBox/HealthRow/HeroSide")
	enemy_side = get_node("Margin/Panel/HealthPanel/HealthBox/HealthRow/EnemySide")
	hero_label = get_node("Margin/Panel/HealthPanel/HealthBox/HealthRow/HeroSide/HeroLabel")
	enemy_label = get_node("Margin/Panel/HealthPanel/HealthBox/HealthRow/EnemySide/EnemyLabel")
	hero_health_bar = get_node("Margin/Panel/HealthPanel/HealthBox/HealthRow/HeroSide/HeroHealthBar")
	enemy_health_bar = get_node("Margin/Panel/HealthPanel/HealthBox/HealthRow/EnemySide/EnemyHealthBar")
	shield_bar = get_node("Margin/Panel/HealthPanel/HealthBox/HealthRow/HeroSide/ShieldBar")
	separator_label = get_node("Margin/Panel/HealthPanel/HealthBox/HealthRow/SeparatorLabel")
	enemy_hint_label = get_node("Margin/Panel/HealthPanel/HealthBox/HealthRow/EnemySide/EnemyHintLabel")
	stage_notice = get_node("Margin/Panel/HealthPanel/HealthBox/StageNotice")
	strike_button = get_node("Margin/Panel/SkillRow/StrikeButton")
	guard_button = get_node("Margin/Panel/SkillRow/GuardButton")
	action_button = get_node("Margin/Panel/ActionButton")
	log_card = get_node("Margin/Panel/LogCard")
	battle_log = get_node("Margin/Panel/LogCard/BattleLog")
	hint_label = get_node("Margin/Panel/HintLabel")


func _load_data() -> Dictionary:
	# В игре данные приходят из автозагрузки, а в точечном тесте сцены
	# читаются напрямую из того же файла баланса.
	var config_node: Node = get_node_or_null("/root/GameConfig")
	if config_node != null:
		var from_autoload: Dictionary = config_node.get("values") as Dictionary
		if not from_autoload.is_empty():
			return from_autoload
	return CombatCatalog.load_balance()


func _apply_styles() -> void:
	health_panel.add_theme_stylebox_override("panel", AshenStyle.compact_panel_style())
	log_card.add_theme_stylebox_override("panel", AshenStyle.compact_panel_style())
	action_button.add_theme_stylebox_override("normal", AshenStyle.action_button_style())
	for bar in [hero_health_bar, enemy_health_bar, shield_bar, experience_bar]:
		bar.add_theme_stylebox_override("background", AshenStyle.bar_background())
	hero_health_bar.add_theme_stylebox_override("fill", AshenStyle.bar_fill(AshenStyle.HERO_COLOR))
	enemy_health_bar.add_theme_stylebox_override("fill", AshenStyle.bar_fill(AshenStyle.ENEMY_COLOR))
	shield_bar.add_theme_stylebox_override("fill", AshenStyle.bar_fill(AshenStyle.SHIELD_COLOR))
	experience_bar.add_theme_stylebox_override("fill", AshenStyle.bar_fill(AshenStyle.GOLD))
	title_label.add_theme_color_override("font_color", AshenStyle.GOLD)
	stage_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	level_label.add_theme_color_override("font_color", AshenStyle.STEEL)
	gold_label.add_theme_color_override("font_color", AshenStyle.GOLD)
	hero_label.add_theme_color_override("font_color", AshenStyle.STEEL)
	enemy_label.add_theme_color_override("font_color", AshenStyle.CRIMSON)
	separator_label.add_theme_color_override("font_color", AshenStyle.RUNE)
	enemy_hint_label.add_theme_color_override("font_color", AshenStyle.EMBER)
	stage_notice.add_theme_color_override("font_color", AshenStyle.GOLD)
	battle_log.add_theme_color_override("font_color", AshenStyle.PARCHMENT)
	hint_label.add_theme_color_override("font_color", AshenStyle.MUTED)


func _connect_battle_signals() -> void:
	var battle = campaign.system
	if battle == null:
		return
	battle.damage_dealt.connect(_on_damage_dealt)
	battle.enemy_defeated.connect(_on_enemy_defeated)
	battle.hero_defeated.connect(_on_hero_defeated)
	battle.skill_used.connect(_on_skill_used)
	battle.shield_changed.connect(_on_shield_changed)


func _process(delta: float) -> void:
	if not initialized:
		return
	var previous_status: int = campaign.status
	campaign.advance(delta)
	if previous_status == CampaignState.STATUS_BATTLE and campaign.status != CampaignState.STATUS_BATTLE:
		_on_stage_finished()
	_update_view()


func _update_view() -> void:
	var summary: Dictionary = campaign.get_summary()
	var battle = campaign.system
	stage_label.text = "%s · Этап %d/%d" % [str(summary["region"]), int(summary["stage"]), int(summary["stages"])]
	level_label.text = "УР. %d" % int(summary["level"])
	experience_bar.max_value = float(summary["experience_to_next"])
	experience_bar.value = float(summary["experience"])
	gold_label.text = "ЗОЛОТО %d" % int(summary["gold"])
	if battle == null:
		hero_label.text = "ГЕРОЙ —"
		enemy_label.text = "ВРАГ —"
		hero_health_bar.value = 0.0
		enemy_health_bar.value = 0.0
		shield_bar.value = 0.0
	else:
		hero_label.text = "ГЕРОЙ %d/%d" % [int(round(battle.hero.health)), int(round(battle.hero.max_health))]
		hero_health_bar.max_value = battle.hero.max_health
		hero_health_bar.value = battle.hero.health
		shield_bar.max_value = battle.hero.max_health
		shield_bar.value = battle.hero.shield
		if battle.enemy != null:
			var prefix: String = "БОСС" if bool(summary["boss"]) else "ВРАГ"
			enemy_label.text = "%s %d/%d" % [prefix, int(round(battle.enemy.health)), int(round(battle.enemy.max_health))]
			enemy_health_bar.max_value = battle.enemy.max_health
			enemy_health_bar.value = battle.enemy.health
		else:
			enemy_label.text = "ВРАГ —"
			enemy_health_bar.max_value = 1.0
			enemy_health_bar.value = 0.0
	if bool(summary["boss_phase_active"]):
		enemy_hint_label.text = str(summary["boss_phase_name"]).to_upper()
	elif bool(summary["boss"]):
		enemy_hint_label.text = "ФАЗА БОССА"
	else:
		enemy_hint_label.text = ""
	var reward_value: Variant = summary["last_reward"]
	var reward: Dictionary = reward_value as Dictionary
	match campaign.status:
		CampaignState.STATUS_BATTLE:
			stage_notice.text = "%s · %s" % [str(summary["status_name"]).to_upper(), str(summary["kind"])]
		CampaignState.STATUS_VICTORY:
			stage_notice.text = "ПОБЕДА · +%d ОПЫТА · +%d ЗОЛОТА" % [int(reward.get("experience", 0)), int(reward.get("gold", 0))]
		CampaignState.STATUS_DEFEAT:
			stage_notice.text = "ПОРАЖЕНИЕ · ЭТАП МОЖНО ПОВТОРИТЬ"
		CampaignState.STATUS_COMPLETE:
			stage_notice.text = "КАМПАНИЯ ПРОЙДЕНА · УР. %d" % int(summary["level"])
	var strike_cooldown: float = campaign.get_cooldown_remaining("heavy_strike")
	var guard_cooldown: float = campaign.get_cooldown_remaining("ash_guard")
	var skills_blocked: bool = campaign.status != CampaignState.STATUS_BATTLE
	strike_button.disabled = skills_blocked or strike_cooldown > 0.0
	guard_button.disabled = skills_blocked or guard_cooldown > 0.0
	if strike_cooldown > 0.0:
		strike_button.text = "УДАР · %.1f" % strike_cooldown
	else:
		strike_button.text = "УДАР"
	if guard_cooldown > 0.0:
		guard_button.text = "ЩИТ · %.1f" % guard_cooldown
	else:
		guard_button.text = "ЩИТ"
	action_button.visible = campaign.status != CampaignState.STATUS_BATTLE
	match campaign.status:
		CampaignState.STATUS_VICTORY:
			action_button.text = "ДАЛЬШЕ · ЭТАП %d" % (campaign.stage_number() + 1)
		CampaignState.STATUS_DEFEAT:
			action_button.text = "ПОВТОРИТЬ ЭТАП"
		CampaignState.STATUS_COMPLETE:
			action_button.text = "НОВЫЙ ПОХОД"


func _on_strike_pressed() -> void:
	campaign.use_skill("heavy_strike")


func _on_guard_pressed() -> void:
	campaign.use_skill("ash_guard")


func _on_action_pressed() -> void:
	match campaign.status:
		CampaignState.STATUS_VICTORY:
			if campaign.next_stage():
				_connect_battle_signals()
				_add_log("Этап %d: %s" % [campaign.stage_number(), str(campaign.current_stage().get("name", ""))])
		CampaignState.STATUS_DEFEAT:
			if campaign.retry_stage():
				_connect_battle_signals()
				_add_log("Повтор этапа %d" % campaign.stage_number())
		CampaignState.STATUS_COMPLETE:
			if campaign.restart_campaign():
				_connect_battle_signals()
				_add_log("Новый поход: этап 1")
	_update_view()


func _on_stage_finished() -> void:
	var reward: Dictionary = campaign.last_reward
	match campaign.status:
		CampaignState.STATUS_VICTORY:
			_add_log("Победа: +%d опыта, +%d золота" % [int(reward.get("experience", 0)), int(reward.get("gold", 0))])
			if int(reward.get("levels", 0)) > 0:
				_add_log("Новый уровень: %d" % campaign.level)
		CampaignState.STATUS_DEFEAT:
			_add_log("Герой пал. Повторить этап?")
		CampaignState.STATUS_COMPLETE:
			_add_log("Кампания пройдена. Уровень %d" % campaign.level)


func _on_damage_dealt(target_name: String, amount: float, is_critical: bool) -> void:
	var suffix: String = " · крит" if is_critical else ""
	_add_log("%s: −%.0f%s" % [target_name, amount, suffix])
	var hit_hero: bool = target_name == campaign.system.hero.display_name
	var side: Control = hero_side if hit_hero else enemy_side
	var color: Color = AshenStyle.CRIMSON if hit_hero else AshenStyle.GOLD
	_flash(side, color)
	_spawn_floating_number("%.0f" % amount, side, color)


func _on_enemy_defeated(enemy_name: String) -> void:
	_add_log("%s повержен" % enemy_name)


func _on_hero_defeated() -> void:
	_add_log("Герой пал")


func _on_skill_used(skill_name: String) -> void:
	_add_log("Навык: %s" % skill_name)


func _on_shield_changed(amount: float) -> void:
	_add_log("Щит: +%.0f" % amount)


func _on_boss_phase_started(enemy_name: String, phase_name: String) -> void:
	_add_log("%s: %s" % [enemy_name, phase_name])


func _add_log(line: String) -> void:
	log_lines.insert(0, line)
	if log_lines.size() > 5:
		log_lines.resize(5)
	battle_log.text = "\n".join(log_lines)


func _flash(side: Control, color: Color) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(side, "modulate", color, 0.06)
	tween.tween_property(side, "modulate", Color.WHITE, 0.22)


func _spawn_floating_number(text: String, near: Control, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 24)
	var center: Vector2 = near.get_global_rect().get_center()
	label.position = center - Vector2(12, 18)
	add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 52.0, 0.55)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	tween.tween_callback(label.queue_free)
