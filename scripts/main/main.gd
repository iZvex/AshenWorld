extends Control

# Компактный экран кампании, экипировки, прогрессии, сохранений и трёх режимов:
# здоровье героя и противника в одной строке, 30 этапов, Башня испытаний,
# Подземелья ресурсов, награды, Алтарь призыва, инвентарь, характеристики,
# навыки и питомцы. Восьмой этап добавляет процедурные звуки, пул эффектов,
# упрощённый режим и обновление интерфейса по таймеру. Все кнопки связаны с состоянием.

const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const CampaignState = preload("res://scripts/campaign/campaign_state.gd")
const ModeCatalog = preload("res://scripts/campaign/mode_catalog.gd")
const EquipmentCatalog = preload("res://scripts/equipment/equipment_catalog.gd")
const ProgressionCatalog = preload("res://scripts/progression/progression_catalog.gd")
const SaveCatalog = preload("res://scripts/save/save_catalog.gd")
const ProfileManager = preload("res://scripts/save/profile_manager.gd")
const AshenStyle = preload("res://scripts/ui/ashen_style.gd")
const PresentationCatalog = preload("res://scripts/ui/presentation_catalog.gd")
const AshenAudio = preload("res://scripts/ui/ashen_audio.gd")
const EffectPool = preload("res://scripts/ui/effect_pool.gd")

var title_label: Label
var stage_label: Label
var sigil: TextureRect
var divider: TextureRect
var level_label: Label
var experience_bar: ProgressBar
var gold_label: Label
var materials_label: Label
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
var equipment_button: Button
var equipment_power_label: Label
var equipment_panel: PanelContainer
var wallet_label: Label
var item_power_label: Label
var summon_type_button: Button
var summon_one_button: Button
var summon_ten_button: Button
var summon_info_label: Label
var summon_status_label: Label
var history_label: Label
var slot_filter: OptionButton
var rarity_filter: OptionButton
var affix_filter: OptionButton
var item_list: ItemList
var item_details: Label
var equip_button: Button
var upgrade_button: Button
var lock_button: Button
var dismantle_button: Button
var auto_equip_button: Button
var mass_dismantle_button: Button
var equipment_hint_label: Label
var progression_button: Button
var progression_panel: PanelContainer
var progression_wallet_label: Label
var progression_power_label: Label
var attribute_buttons: Dictionary = {}
var attribute_hint_label: Label
var progression_skill_list: ItemList
var progression_skill_details: Label
var skill_upgrade_button: Button
var skill_auto_button: Button
var skill_variant_button: Button
var passive_buttons: Dictionary = {}
var pet_buttons: Dictionary = {}
var progression_pet_details: Label
var pet_upgrade_button: Button
var progression_hint_label: Label
var strike_button: Button
var guard_button: Button
var action_button: Button
var log_card: PanelContainer
var battle_log: Label
var hint_label: Label
var mode_button: Button
var mode_panel: PanelContainer
var mode_status_label: Label
var mode_stats_label: Label
var mode_hint_label: Label
var mode_buttons: Dictionary = {}
var dungeon_buttons: Dictionary = {}
var particles_effect: CPUParticles2D
var sound_button: Button
var particles_button: Button
var fps_button: Button
var effects_button: Button
var audio_player
var effect_pool
var effect_config: Dictionary = {}
var view_refresh_seconds: float = 0.1
var view_refresh_timer: float = 0.0
var fps_sample_seconds: float = 1.0
var fps_sample_timer: float = 0.0
var measured_fps: float = 0.0

var campaign
var profile_manager
var balance: Dictionary = {}
var log_lines: PackedStringArray = PackedStringArray()
var initialized: bool = false
var equipment_visible: bool = false
var progression_visible: bool = false
var mode_visible: bool = false
var selected_summon_id: String = "ash"
var selected_item_id: String = ""
var selected_skill_id: String = ""
var selected_pet_id: String = ""
var force_dismantle_item_id: String = ""
var force_dismantle_deadline_ms: int = 0

const FORCE_DISMANTLE_WINDOW_MS: int = 5000


func _ready() -> void:
	setup(_load_data())


func setup(data: Dictionary, profile_path: String = "", now_unix: int = -1) -> void:
	# Явный вызов нужен точечному тесту: при запуске через --script узел
	# входит в дерево раньше, чем движок успевает вызвать _ready().
	if initialized:
		return
	initialized = true
	balance = data
	_bind_nodes()
	theme = AshenStyle.build_theme()
	_apply_styles()
	effect_config = PresentationCatalog.effect_pool_config(balance)
	var performance: Dictionary = PresentationCatalog.performance_config(balance)
	view_refresh_seconds = PresentationCatalog.ui_refresh_seconds(balance)
	fps_sample_seconds = float(performance.get("sample_seconds", 1.0))
	audio_player = AshenAudio.new()
	add_child(audio_player)
	audio_player.configure(balance, bool(SaveCatalog.default_settings(balance).get("sound_enabled", true)))
	effect_pool = EffectPool.new()
	add_child(effect_pool)
	effect_pool.configure(self, effect_config)
	_configure_particles()
	if not resized.is_connected(_on_viewport_resized):
		resized.connect(_on_viewport_resized)
	campaign = CampaignState.new(data)
	profile_manager = ProfileManager.new(balance, profile_path, now_unix)
	var startup_report: Dictionary = profile_manager.bootstrap(campaign)
	campaign.boss_phase_started.connect(_on_boss_phase_started)
	_connect_battle_signals()
	_connect_ui_signals()
	_populate_filters()
	_populate_progression()
	var summon_ids: Array = campaign.equipment.get_summon_ids()
	if summon_ids.size() > 0:
		selected_summon_id = str(summon_ids[0])
	var skill_ids: Array = campaign.get_skill_ids()
	if skill_ids.size() > 0:
		selected_skill_id = str(skill_ids[0])
	selected_item_id = ""
	selected_pet_id = str(campaign.development.selected_pet_id)
	_apply_settings()
	_add_log("Этап %d: %s" % [campaign.stage_number(), str(campaign.current_stage().get("name", ""))])
	var startup_lines: Array = startup_report.get("log_lines", []) as Array
	for line in startup_lines:
		_add_log(str(line))
	_update_view()
	var startup_summary: Dictionary = campaign.get_summary()
	print("Игровой цикл, режимы, звук и эффекты запущены: %s, профиль %s" % [
		str(startup_summary.get("mode_progress", "")),
		str(startup_report.get("status_text", "")),
	])


func _bind_nodes() -> void:
	title_label = get_node("Margin/Panel/Header/Titles/TitleLabel")
	stage_label = get_node("Margin/Panel/Header/Titles/StageLabel")
	sigil = get_node("Margin/Panel/Header/Sigil")
	divider = get_node("Margin/Panel/Divider")
	level_label = get_node("Margin/Panel/StatusRow/LevelLabel")
	experience_bar = get_node("Margin/Panel/StatusRow/ExperienceBar")
	gold_label = get_node("Margin/Panel/StatusRow/GoldLabel")
	materials_label = get_node("Margin/Panel/StatusRow/MaterialsLabel")
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
	equipment_button = get_node("Margin/Panel/MenuRow/EquipmentButton")
	equipment_power_label = get_node("Margin/Panel/MenuRow/EquipmentPowerLabel")
	equipment_panel = get_node("Margin/Panel/EquipmentPanel")
	wallet_label = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/EquipmentTopRow/WalletLabel")
	item_power_label = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/EquipmentTopRow/ItemPowerLabel")
	summon_type_button = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/SummonTypeRow/SummonTypeButton")
	summon_one_button = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/SummonTypeRow/SummonOneButton")
	summon_ten_button = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/SummonTypeRow/SummonTenButton")
	summon_info_label = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/SummonInfoLabel")
	summon_status_label = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/SummonStatusLabel")
	history_label = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/HistoryLabel")
	slot_filter = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/FilterRow/SlotFilter")
	rarity_filter = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/FilterRow/RarityFilter")
	affix_filter = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/FilterRow/AffixFilter")
	item_list = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/ItemList")
	item_details = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/ItemDetails")
	equip_button = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/ActionsRow1/EquipButton")
	upgrade_button = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/ActionsRow1/UpgradeButton")
	lock_button = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/ActionsRow1/LockButton")
	dismantle_button = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/ActionsRow2/DismantleButton")
	auto_equip_button = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/ActionsRow2/AutoEquipButton")
	mass_dismantle_button = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/ActionsRow2/MassDismantleButton")
	equipment_hint_label = get_node("Margin/Panel/EquipmentPanel/EquipmentBox/EquipmentHintLabel")
	progression_button = get_node("Margin/Panel/MenuRow/ProgressionButton")
	mode_button = get_node("Margin/Panel/MenuRow/ModeButton") as Button
	progression_panel = get_node("Margin/Panel/ProgressionPanel")
	progression_wallet_label = get_node("Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionTopRow/ProgressionWalletLabel")
	progression_power_label = get_node("Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionTopRow/ProgressionPowerLabel")
	attribute_hint_label = get_node("Margin/Panel/ProgressionPanel/ProgressionBox/AttributeHintLabel")
	progression_skill_list = get_node("Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionSkillList")
	progression_skill_details = get_node("Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionSkillDetails")
	skill_upgrade_button = get_node("Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionSkillActionsRow/SkillUpgradeButton")
	skill_auto_button = get_node("Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionSkillActionsRow/SkillAutoButton")
	skill_variant_button = get_node("Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionSkillActionsRow/SkillVariantButton")
	progression_pet_details = get_node("Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionPetDetails")
	pet_upgrade_button = get_node("Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionPetActionsRow/PetUpgradeButton")
	progression_hint_label = get_node("Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionPetActionsRow/ProgressionHintLabel")
	strike_button = get_node("Margin/Panel/SkillRow/StrikeButton")
	guard_button = get_node("Margin/Panel/SkillRow/GuardButton")
	action_button = get_node("Margin/Panel/ActionButton")
	log_card = get_node("Margin/Panel/LogCard")
	battle_log = get_node("Margin/Panel/LogCard/BattleLog")
	hint_label = get_node("Margin/Panel/HintLabel")
	mode_panel = get_node("Margin/Panel/ModePanel") as PanelContainer
	mode_status_label = get_node("Margin/Panel/ModePanel/ModeBox/ModeTopRow/ModeStatusLabel") as Label
	mode_stats_label = get_node("Margin/Panel/ModePanel/ModeBox/ModeTopRow/ModeStatsLabel") as Label
	mode_hint_label = get_node("Margin/Panel/ModePanel/ModeBox/ModeHintLabel") as Label
	particles_effect = get_node("Particles") as CPUParticles2D
	sound_button = get_node("Margin/Panel/SettingsRow/SoundButton") as Button
	particles_button = get_node("Margin/Panel/SettingsRow/ParticlesButton") as Button
	fps_button = get_node("Margin/Panel/SettingsRow/FpsButton") as Button
	effects_button = get_node("Margin/Panel/SettingsRow/EffectsButton") as Button


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
	equipment_panel.add_theme_stylebox_override("panel", AshenStyle.compact_panel_style())
	progression_panel.add_theme_stylebox_override("panel", AshenStyle.compact_panel_style())
	mode_panel.add_theme_stylebox_override("panel", AshenStyle.compact_panel_style())
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
	materials_label.add_theme_color_override("font_color", AshenStyle.EMBER)
	hero_label.add_theme_color_override("font_color", AshenStyle.STEEL)
	enemy_label.add_theme_color_override("font_color", AshenStyle.CRIMSON)
	separator_label.add_theme_color_override("font_color", AshenStyle.RUNE)
	enemy_hint_label.add_theme_color_override("font_color", AshenStyle.EMBER)
	stage_notice.add_theme_color_override("font_color", AshenStyle.GOLD)
	equipment_power_label.add_theme_color_override("font_color", AshenStyle.GOLD)
	wallet_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	item_power_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	summon_info_label.add_theme_color_override("font_color", AshenStyle.RUNE)
	summon_status_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	history_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	item_details.add_theme_color_override("font_color", AshenStyle.PARCHMENT)
	equipment_hint_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	progression_wallet_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	progression_power_label.add_theme_color_override("font_color", AshenStyle.GOLD)
	attribute_hint_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	progression_skill_details.add_theme_color_override("font_color", AshenStyle.PARCHMENT)
	progression_pet_details.add_theme_color_override("font_color", AshenStyle.PARCHMENT)
	progression_hint_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	battle_log.add_theme_color_override("font_color", AshenStyle.PARCHMENT)
	hint_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	mode_status_label.add_theme_color_override("font_color", AshenStyle.GOLD)
	mode_stats_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	mode_hint_label.add_theme_color_override("font_color", AshenStyle.MUTED)


func _configure_particles() -> void:
	if particles_effect == null:
		return
	var settings: Dictionary = PresentationCatalog.particle_config(balance)
	particles_effect.amount = int(settings.get("amount", 12))
	particles_effect.lifetime = float(settings.get("lifetime_seconds", 4.0))
	particles_effect.direction = Vector2(0.0, -1.0)
	particles_effect.spread = float(settings.get("spread_degrees", 28.0))
	particles_effect.gravity = Vector2(0.0, float(settings.get("gravity_y", -14.0)))
	particles_effect.initial_velocity_min = float(settings.get("velocity_min", 18.0))
	particles_effect.initial_velocity_max = float(settings.get("velocity_max", 56.0))
	particles_effect.scale_amount_min = float(settings.get("scale_min", 0.3))
	particles_effect.scale_amount_max = float(settings.get("scale_max", 0.9))
	particles_effect.color = settings.get("color", AshenStyle.EMBER) as Color
	particles_effect.position = size * 0.5


func _on_viewport_resized() -> void:
	if particles_effect != null:
		particles_effect.position = size * 0.5


func _connect_battle_signals() -> void:
	var battle = campaign.system
	if battle == null:
		return
	battle.damage_dealt.connect(_on_damage_dealt)
	battle.enemy_defeated.connect(_on_enemy_defeated)
	battle.hero_defeated.connect(_on_hero_defeated)
	battle.skill_used.connect(_on_skill_used)
	battle.shield_changed.connect(_on_shield_changed)
	battle.pet_attack.connect(_on_pet_attack)
	battle.hero_healed.connect(_on_hero_healed)
	battle.attack_dodged.connect(_on_attack_dodged)


func _connect_ui_signals() -> void:
	strike_button.pressed.connect(_on_strike_pressed)
	guard_button.pressed.connect(_on_guard_pressed)
	action_button.pressed.connect(_on_action_pressed)
	equipment_button.pressed.connect(_on_equipment_toggle_pressed)
	progression_button.pressed.connect(_on_progression_toggle_pressed)
	mode_button.pressed.connect(_on_mode_toggle_pressed)
	_populate_modes()
	progression_skill_list.item_selected.connect(_on_skill_selected)
	skill_upgrade_button.pressed.connect(_on_skill_upgrade_pressed)
	skill_auto_button.pressed.connect(_on_skill_auto_pressed)
	skill_variant_button.pressed.connect(_on_skill_variant_pressed)
	pet_upgrade_button.pressed.connect(_on_pet_upgrade_pressed)
	summon_type_button.pressed.connect(_on_summon_type_pressed)
	summon_one_button.pressed.connect(_on_summon_one_pressed)
	summon_ten_button.pressed.connect(_on_summon_ten_pressed)
	slot_filter.item_selected.connect(_on_filters_changed)
	rarity_filter.item_selected.connect(_on_filters_changed)
	affix_filter.item_selected.connect(_on_filters_changed)
	item_list.item_selected.connect(_on_item_selected)
	equip_button.pressed.connect(_on_equip_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	lock_button.pressed.connect(_on_lock_pressed)
	dismantle_button.pressed.connect(_on_dismantle_pressed)
	auto_equip_button.pressed.connect(_on_auto_equip_pressed)
	mass_dismantle_button.pressed.connect(_on_mass_dismantle_pressed)
	sound_button.pressed.connect(_on_sound_pressed)
	particles_button.pressed.connect(_on_particles_pressed)
	fps_button.pressed.connect(_on_fps_pressed)
	effects_button.pressed.connect(_on_effects_pressed)


func _populate_filters() -> void:
	slot_filter.clear()
	rarity_filter.clear()
	affix_filter.clear()
	slot_filter.add_item("Все слоты")
	for slot in EquipmentCatalog.slots(balance):
		if slot is Dictionary:
			slot_filter.add_item(str((slot as Dictionary).get("name", "")))
	rarity_filter.add_item("Все редкости")
	for rarity in EquipmentCatalog.rarities(balance):
		if rarity is Dictionary:
			rarity_filter.add_item(str((rarity as Dictionary).get("name", "")))
	affix_filter.add_item("Любой параметр")
	for affix in EquipmentCatalog.affixes(balance):
		if affix is Dictionary:
			affix_filter.add_item(str((affix as Dictionary).get("name", "")).capitalize())
	slot_filter.select(0)
	rarity_filter.select(0)
	affix_filter.select(0)


func _populate_progression() -> void:
	attribute_buttons.clear()
	passive_buttons.clear()
	pet_buttons.clear()
	var attribute_ids: Array = ProgressionCatalog.attribute_ids(balance)
	var attribute_paths: Array = [
		"Margin/Panel/ProgressionPanel/ProgressionBox/AttributeRow/StrengthButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/AttributeRow/AgilityButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/AttributeRow/IntellectButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/AttributeRow/StaminaButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/AttributeRow/SpiritButton",
	]
	for index in range(mini(attribute_ids.size(), attribute_paths.size())):
		var attribute_id: String = str(attribute_ids[index])
		var attribute_button: Button = get_node(str(attribute_paths[index])) as Button
		attribute_buttons[attribute_id] = attribute_button
		attribute_button.pressed.connect(_on_attribute_pressed.bind(attribute_id))
	var passive_paths: Array = [
		"Margin/Panel/ProgressionPanel/ProgressionBox/PassiveRow/PassiveEnduranceButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/PassiveRow/PassivePrecisionButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/PassiveRow/PassiveSpiritButton",
	]
	var passive_ids: Array = campaign.get_passive_ids()
	for index in range(mini(passive_ids.size(), passive_paths.size())):
		var passive_id: String = str(passive_ids[index])
		var passive_button: Button = get_node(str(passive_paths[index])) as Button
		passive_buttons[passive_id] = passive_button
		passive_button.pressed.connect(_on_passive_pressed.bind(passive_id))
	var pet_paths: Array = [
		"Margin/Panel/ProgressionPanel/ProgressionBox/PetRow/PetFoxButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/PetRow/PetHoundButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/PetRow/PetOwlButton",
	]
	var pet_ids: Array = campaign.get_pet_ids()
	for index in range(mini(pet_ids.size(), pet_paths.size())):
		var pet_id: String = str(pet_ids[index])
		var pet_button: Button = get_node(str(pet_paths[index])) as Button
		pet_buttons[pet_id] = pet_button
		pet_button.pressed.connect(_on_pet_selected.bind(pet_id))


func _process(delta: float) -> void:
	if not initialized:
		return
	var previous_status: int = campaign.status
	campaign.advance(delta)
	fps_sample_timer += delta
	if fps_sample_timer >= fps_sample_seconds:
		fps_sample_timer = 0.0
		measured_fps = Engine.get_frames_per_second()
	if profile_manager != null:
		profile_manager.tick(delta)
	# Перерисовка всех панелей выполняется не каждый кадр; смена статуса боя
	# и нажатия кнопок обновляют экран сразу.
	if previous_status == CampaignState.STATUS_BATTLE and campaign.status != CampaignState.STATUS_BATTLE:
		_on_stage_finished()
		_update_view()
		view_refresh_timer = 0.0
		return
	view_refresh_timer += delta
	if view_refresh_timer >= view_refresh_seconds:
		_update_view()
		view_refresh_timer = 0.0


func _update_view() -> void:
	var summary: Dictionary = campaign.get_summary()
	var battle = campaign.system
	stage_label.text = str(summary["mode_progress"])
	level_label.text = "УР. %d" % int(summary["level"])
	experience_bar.max_value = float(summary["experience_to_next"])
	experience_bar.value = float(summary["experience"])
	gold_label.text = "ЗОЛОТО %d" % int(summary["gold"])
	materials_label.text = "ПЕПЕЛ %d" % int(summary["materials"])
	equipment_power_label.text = "СИЛА %.0f" % float(summary["equipment_power"])
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
			stage_notice.text = "ПОБЕДА · +%d ОПЫТА · +%d ЗОЛОТА · +%d ПЕПЛА" % [
				int(reward.get("experience", 0)),
				int(reward.get("gold", 0)),
				int(reward.get("materials", 0)),
			]
		CampaignState.STATUS_DEFEAT:
			stage_notice.text = "ПОРАЖЕНИЕ · ЭТАП МОЖНО ПОВТОРИТЬ"
		CampaignState.STATUS_COMPLETE:
			stage_notice.text = "%s · УР. %d" % [str(summary["status_name"]).to_upper(), int(summary["level"])]
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
	action_button.disabled = false
	if action_button.visible:
		action_button.text = ModeCatalog.action_text(
			balance,
			campaign.mode_id(),
			campaign.mode_status_key(),
			campaign.mode_number(),
			campaign.mode_state_view(),
		)
		if campaign.mode_id() == "dungeon" and campaign.status == CampaignState.STATUS_VICTORY:
			var dungeon_state: Dictionary = campaign.mode_state_view()
			if campaign.dungeon_block_reason(str(dungeon_state.get("dungeon_id", ""))) != "":
				action_button.disabled = true
				action_button.text = "НУЖНЫ РЕСУРСЫ ДЛЯ ВХОДА"
	if equipment_visible:
		_refresh_equipment_ui()
	if progression_visible:
		_refresh_progression_ui()
	if mode_visible:
		_refresh_mode_ui()
	if profile_manager != null:
		var fps_text: String = "—" if measured_fps <= 0.0 else "%.0f" % measured_fps
		hint_label.text = "%s · %s · КАДРЫ %s" % [
			profile_manager.hint_text(),
			str(summary["mode_short"]),
			fps_text,
		]
	_refresh_settings_ui()


func _on_equipment_toggle_pressed() -> void:
	equipment_visible = not equipment_visible
	equipment_panel.visible = equipment_visible
	_clear_force_dismantle()
	if equipment_visible:
		progression_visible = false
		progression_panel.visible = false
		progression_button.text = "ПРОГРЕССИЯ"
		mode_visible = false
		mode_panel.visible = false
		mode_button.text = "РЕЖИМЫ"
		equipment_button.text = "СКРЫТЬ ЭКИПИРОВКУ"
		_refresh_equipment_ui()
	else:
		equipment_button.text = "ЭКИПИРОВКА"


func _on_summon_type_pressed() -> void:
	var ids: Array = campaign.equipment.get_summon_ids()
	if ids.size() < 2:
		return
	var index: int = ids.find(selected_summon_id)
	selected_summon_id = str(ids[(index + 1) % ids.size()])
	_refresh_equipment_ui()


func _on_summon_one_pressed() -> void:
	_run_summon(1)


func _on_summon_ten_pressed() -> void:
	_run_summon(10)


func _run_summon(count: int) -> void:
	var result: Dictionary = campaign.summon_equipment(selected_summon_id, count)
	if not bool(result.get("success", false)):
		_add_log("Призыв недоступен: %s" % str(result.get("reason", "")))
		_update_view()
		return
	var items_value: Variant = result.get("items", [])
	var items: Array = items_value as Array
	_clear_force_dismantle()
	if items.size() > 0 and items[0] is Dictionary:
		selected_item_id = str((items[0] as Dictionary).get("id", ""))
	_add_log("Призыв ×%d: предметов %d, гарантий %d" % [count, items.size(), int(result.get("guaranteed_count", 0))])
	if items.size() > 0 and items[0] is Dictionary:
		var first: Dictionary = items[0] as Dictionary
		_add_log("%s · %s" % [str(first.get("name", "")), str(first.get("rarity_name", ""))])
	_save("призыв экипировки")
	_update_view()


func _on_filters_changed(_index: int) -> void:
	campaign.set_equipment_filters(slot_filter.selected, rarity_filter.selected, affix_filter.selected)
	_refresh_equipment_ui()
	_save("фильтры инвентаря")


func _on_item_selected(index: int) -> void:
	var item_id: String = str(item_list.get_item_metadata(index))
	if item_id != force_dismantle_item_id:
		_clear_force_dismantle()
	selected_item_id = item_id
	_refresh_item_details()


func _on_equip_pressed() -> void:
	if campaign.equip_item(selected_item_id):
		_add_log("Предмет надет")
	else:
		_add_log("Надеть предмет не удалось")
	_save("надевание предмета")
	_update_view()


func _on_upgrade_pressed() -> void:
	var result: Dictionary = campaign.upgrade_item(selected_item_id)
	if bool(result.get("success", false)):
		_add_log("Улучшение: −%d золота, −%d пепла" % [int(result.get("gold", 0)), int(result.get("materials", 0))])
	else:
		_add_log("Улучшение недоступно: %s" % str(result.get("reason", "")))
	_save("улучшение предмета")
	_update_view()


func _on_lock_pressed() -> void:
	var locked: bool = campaign.toggle_item_lock(selected_item_id)
	if locked:
		_add_log("Предмет заблокирован")
	else:
		_add_log("Замок снят")
	_save("блокировка предмета")
	_update_view()


func _on_dismantle_pressed() -> void:
	var item_id: String = selected_item_id
	if item_id == "":
		return
	var confirm: bool = _is_force_dismantle_armed(item_id)
	var result: Dictionary = campaign.dismantle_item(item_id, confirm)
	if not bool(result.get("success", false)) and confirm:
		_clear_force_dismantle()
		_add_log("Разбор недоступен: %s" % str(result.get("reason", "")))
	elif not bool(result.get("success", false)) and campaign.equipment.can_dismantle(item_id, true):
		force_dismantle_item_id = item_id
		force_dismantle_deadline_ms = Time.get_ticks_msec() + FORCE_DISMANTLE_WINDOW_MS
		_add_log("Ценный предмет защищён. Нажмите подтверждение повторно")
	elif bool(result.get("success", false)):
		_clear_force_dismantle()
		selected_item_id = ""
		_add_log("Разбор: +%d золота, +%d пепла" % [int(result.get("gold", 0)), int(result.get("materials", 0))])
	else:
		_clear_force_dismantle()
		_add_log("Разбор недоступен: %s" % str(result.get("reason", "")))
	_save("разбор предмета")
	_update_view()


func _is_force_dismantle_armed(item_id: String) -> bool:
	return item_id != "" and item_id == force_dismantle_item_id and Time.get_ticks_msec() <= force_dismantle_deadline_ms


func _clear_force_dismantle() -> void:
	force_dismantle_item_id = ""
	force_dismantle_deadline_ms = 0


func _on_auto_equip_pressed() -> void:
	var changed: int = campaign.auto_equip_items()
	_add_log("Автонадевание: обновлено слотов %d" % changed)
	_save("автонадевание")
	_update_view()


func _on_mass_dismantle_pressed() -> void:
	_clear_force_dismantle()
	var result: Dictionary = campaign.mass_dismantle_items()
	_add_log("Массовый разбор: предметов %d, +%d золота, +%d пепла" % [
		int(result.get("count", 0)),
		int(result.get("gold", 0)),
		int(result.get("materials", 0)),
	])
	selected_item_id = ""
	_save("массовый разбор")
	_update_view()


func _refresh_equipment_ui() -> void:
	if not equipment_visible:
		return
	var summary: Dictionary = campaign.get_summary()
	wallet_label.text = "ЗОЛОТО %d · ПЕПЕЛ %d" % [int(summary["gold"]), int(summary["materials"])]
	item_power_label.text = "ПРЕДМЕТОВ %d · НАДЕТО %d" % [int(summary["inventory_count"]), int(summary["equipped_count"])]
	var summon: Dictionary = EquipmentCatalog.summon_by_id(balance, selected_summon_id)
	summon_type_button.text = str(summon.get("name", "")).to_upper()
	summon_info_label.text = EquipmentCatalog.summon_info(balance, selected_summon_id)
	var reason_one: String = campaign.equipment.summon_block_reason(selected_summon_id, 1, campaign.stage_number(), campaign.gold, campaign.materials)
	var reason_ten: String = campaign.equipment.summon_block_reason(selected_summon_id, 10, campaign.stage_number(), campaign.gold, campaign.materials)
	summon_one_button.disabled = reason_one != ""
	summon_ten_button.disabled = reason_ten != ""
	if reason_one != "":
		summon_status_label.text = reason_one
		summon_status_label.add_theme_color_override("font_color", AshenStyle.CRIMSON)
	elif reason_ten != "":
		summon_status_label.text = "×10: " + reason_ten
		summon_status_label.add_theme_color_override("font_color", AshenStyle.EMBER)
	else:
		summon_status_label.text = "Оба призыва доступны"
		summon_status_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	history_label.text = campaign.equipment.history_text(3)
	_refresh_inventory_list()
	_refresh_item_details()


func _refresh_inventory_list() -> void:
	item_list.clear()
	var items: Array = campaign.equipment.get_filtered_inventory()
	var selected_index: int = -1
	for entry in items:
		if not entry is Dictionary:
			continue
		var item: Dictionary = entry as Dictionary
		var item_id: String = str(item.get("id", ""))
		var equipped_mark: String = "[Э] " if campaign.equipment.is_equipped(item_id) else ""
		var locked_mark: String = " [З]" if bool(item.get("locked", false)) else ""
		var marks: String = EquipmentCatalog.rarity_marks(balance, str(item.get("rarity", "")))
		var line: String = "%s%s %s · %s · %.0f%s" % [
			equipped_mark,
			marks,
			str(item.get("name", "")),
			str(item.get("slot_name", "")),
			float(item.get("power", 0.0)),
			locked_mark,
		]
		var index: int = item_list.add_item(line)
		item_list.set_item_metadata(index, item_id)
		item_list.set_item_custom_fg_color(index, EquipmentCatalog.rarity_color(balance, str(item.get("rarity", ""))))
		if item_id == selected_item_id:
			selected_index = index
	if selected_index >= 0:
		item_list.select(selected_index)


func _refresh_item_details() -> void:
	var item: Dictionary = campaign.equipment.get_item(selected_item_id)
	if item.is_empty():
		item_details.text = "Выберите предмет в списке"
		equip_button.disabled = true
		upgrade_button.disabled = true
		lock_button.disabled = true
		dismantle_button.text = "РАЗОБРАТЬ"
		dismantle_button.disabled = true
		auto_equip_button.disabled = campaign.equipment.inventory.size() == 0
		mass_dismantle_button.disabled = campaign.equipment.inventory.size() == 0
		return
	var comparison: Dictionary = campaign.equipment.compare(selected_item_id)
	var equipped_value: Variant = comparison.get("equipped", {})
	var equipped_item: Dictionary = equipped_value as Dictionary
	var equipped_name: String = "слот пуст"
	if not equipped_item.is_empty():
		equipped_name = str(equipped_item.get("name", ""))
	var difference: float = float(comparison.get("difference", 0.0))
	var difference_text: String
	if difference >= 0.0:
		difference_text = "+%.1f" % difference
	else:
		difference_text = "%.1f" % difference
	var stats: Dictionary = item.get("stats", {}) as Dictionary
	var upgrade_cost: Dictionary = campaign.equipment.get_upgrade_cost(selected_item_id)
	var protection: String = campaign.equipment.dismantle_block_reason(selected_item_id, false)
	var protection_text: String
	if protection != "":
		protection_text = "Защита: " + protection
	else:
		protection_text = "Разбор доступен"
	item_details.text = "%s %s · %s · ур. %d\n%s · сила %.1f\nСравнение: %s (%s)\n%s" % [
		EquipmentCatalog.rarity_marks(balance, str(item.get("rarity", ""))),
		str(item.get("name", "")),
		str(item.get("rarity_name", "")),
		int(item.get("level", 0)),
		EquipmentCatalog.stats_text(stats),
		float(item.get("power", 0.0)),
		equipped_name,
		difference_text,
		protection_text,
	]
	var already_equipped: bool = bool(comparison.get("already_equipped", false))
	equip_button.disabled = already_equipped
	equip_button.text = "НАДЕТО" if already_equipped else "НАДЕТЬ"
	var cost_valid: bool = bool(upgrade_cost.get("valid", false))
	if cost_valid:
		upgrade_button.text = "УЛУЧШИТЬ %d/%d" % [int(upgrade_cost.get("gold", 0)), int(upgrade_cost.get("materials", 0))]
	else:
		upgrade_button.text = "ПРЕДЕЛ"
	upgrade_button.disabled = not cost_valid or campaign.gold < int(upgrade_cost.get("gold", 0)) or campaign.materials < int(upgrade_cost.get("materials", 0))
	lock_button.disabled = false
	lock_button.text = "СНЯТЬ" if bool(item.get("locked", false)) else "ЗАБЛОК."
	if _is_force_dismantle_armed(selected_item_id):
		dismantle_button.text = "ПОДТВЕРДИТЬ РАЗБОР"
		dismantle_button.disabled = false
	elif campaign.equipment.can_dismantle(selected_item_id, false):
		dismantle_button.text = "РАЗОБРАТЬ"
		dismantle_button.disabled = false
	elif campaign.equipment.can_dismantle(selected_item_id, true):
		dismantle_button.text = "РАЗОБРАТЬ ЦЕННОЕ"
		dismantle_button.disabled = false
	else:
		dismantle_button.text = "НЕДОСТУПНО"
		dismantle_button.disabled = true
	auto_equip_button.disabled = false
	mass_dismantle_button.disabled = false


func _on_progression_toggle_pressed() -> void:
	progression_visible = not progression_visible
	progression_panel.visible = progression_visible
	if progression_visible:
		equipment_visible = false
		equipment_panel.visible = false
		equipment_button.text = "ЭКИПИРОВКА"
		mode_visible = false
		mode_panel.visible = false
		mode_button.text = "РЕЖИМЫ"
		_clear_force_dismantle()
		progression_button.text = "СКРЫТЬ ПРОГРЕССИЮ"
		_refresh_progression_ui()
	else:
		progression_button.text = "ПРОГРЕССИЯ"


func _on_mode_toggle_pressed() -> void:
	mode_visible = not mode_visible
	mode_panel.visible = mode_visible
	if mode_visible:
		equipment_visible = false
		equipment_panel.visible = false
		equipment_button.text = "ЭКИПИРОВКА"
		progression_visible = false
		progression_panel.visible = false
		progression_button.text = "ПРОГРЕССИЯ"
		_clear_force_dismantle()
		mode_button.text = "СКРЫТЬ РЕЖИМЫ"
		_refresh_mode_ui()
	else:
		mode_button.text = "РЕЖИМЫ"


func _populate_modes() -> void:
	mode_buttons.clear()
	dungeon_buttons.clear()
	var mode_paths: Array = [
		"Margin/Panel/ModePanel/ModeBox/ModeSwitchRow/CampaignModeButton",
		"Margin/Panel/ModePanel/ModeBox/ModeSwitchRow/TowerModeButton",
		"Margin/Panel/ModePanel/ModeBox/ModeSwitchRow/DungeonModeButton",
	]
	var mode_ids: Array = ModeCatalog.mode_ids(balance)
	for index in range(mini(mode_ids.size(), mode_paths.size())):
		var mode_id: String = str(mode_ids[index])
		var button: Button = get_node(str(mode_paths[index])) as Button
		mode_buttons[mode_id] = button
		button.pressed.connect(_on_mode_button_pressed.bind(mode_id))
	var dungeon_paths: Array = [
		"Margin/Panel/ModePanel/ModeBox/DungeonRow/GoldDungeonButton",
		"Margin/Panel/ModePanel/ModeBox/DungeonRow/MaterialsDungeonButton",
		"Margin/Panel/ModePanel/ModeBox/DungeonRow/ExperienceDungeonButton",
	]
	var dungeon_ids: Array = ModeCatalog.dungeon_ids(balance)
	for index in range(mini(dungeon_ids.size(), dungeon_paths.size())):
		var dungeon_id: String = str(dungeon_ids[index])
		var button: Button = get_node(str(dungeon_paths[index])) as Button
		dungeon_buttons[dungeon_id] = button
		button.pressed.connect(_on_dungeon_button_pressed.bind(dungeon_id))


func _refresh_mode_ui() -> void:
	if not mode_visible:
		return
	var summary: Dictionary = campaign.get_summary()
	mode_status_label.text = "%s · %s" % [str(summary["mode_name"]), str(summary["mode_progress"])]
	mode_stats_label.text = str(summary["mode_stats"])
	var hints: PackedStringArray = PackedStringArray()
	for mode_id in mode_buttons.keys():
		var mode_button_value: Button = mode_buttons[mode_id] as Button
		var unlocked: bool = campaign.mode_is_unlocked(str(mode_id))
		mode_button_value.disabled = not unlocked
		if unlocked:
			mode_button_value.text = ModeCatalog.mode_short(balance, str(mode_id))
		else:
			mode_button_value.text = "%s · ЭТАП %d" % [
				ModeCatalog.mode_short(balance, str(mode_id)),
				ModeCatalog.mode_unlock_stage(balance, str(mode_id)),
			]
			hints.append("Режим %s: этап %d" % [
				ModeCatalog.mode_short(balance, str(mode_id)),
				ModeCatalog.mode_unlock_stage(balance, str(mode_id)),
			])
	for dungeon_id in dungeon_buttons.keys():
		var dungeon_button_value: Button = dungeon_buttons[dungeon_id] as Button
		var reason: String = campaign.dungeon_block_reason(str(dungeon_id))
		var cost: Dictionary = ModeCatalog.dungeon_entry_cost(balance, str(dungeon_id))
		dungeon_button_value.disabled = reason != ""
		dungeon_button_value.text = "%s · %dЗ/%dП" % [
			ModeCatalog.dungeon_short(balance, str(dungeon_id)),
			int(cost.get("gold", 0)),
			int(cost.get("materials", 0)),
		]
		if reason != "":
			hints.append("%s: %s" % [ModeCatalog.dungeon_short(balance, str(dungeon_id)), reason])
	mode_hint_label.text = str(summary["mode_description"])
	if not hints.is_empty():
		mode_hint_label.text += " · " + "; ".join(hints)


func _on_mode_button_pressed(mode_id: String) -> void:
	var result: Dictionary = campaign.select_mode(mode_id)
	if not bool(result.get("success", false)):
		_add_log("Режим недоступен: %s" % str(result.get("reason", "")))
		_update_view()
		return
	_connect_battle_signals()
	_add_log("Режим: %s · %s" % [
		str(result.get("mode_name", ModeCatalog.mode_name(balance, mode_id))),
		str(campaign.current_stage().get("name", "")),
	])
	_save("смена режима")
	_update_view()


func _on_dungeon_button_pressed(dungeon_id: String) -> void:
	var result: Dictionary = campaign.select_dungeon(dungeon_id)
	if not bool(result.get("success", false)):
		_add_log("Подземелье недоступно: %s" % str(result.get("reason", "")))
		_update_view()
		return
	_connect_battle_signals()
	_add_log("Подземелье: %s · −%d золота, −%d пепла" % [
		str(result.get("dungeon_name", "")),
		int(result.get("gold", 0)),
		int(result.get("materials", 0)),
	])
	_save("вход в подземелье")
	_update_view()


func _refresh_progression_ui() -> void:
	if not progression_visible:
		return
	if selected_pet_id == "":
		selected_pet_id = str(campaign.development.selected_pet_id)
	var summary: Dictionary = campaign.get_summary()
	var report: Dictionary = campaign.get_balance_report()
	var auto_report: Dictionary = campaign.get_auto_battle_report()
	progression_wallet_label.text = "%s · Х %d · Н %d" % [
		str(summary.get("class_name", "")),
		int(summary.get("attribute_points", 0)),
		int(summary.get("skill_points", 0)),
	]
	progression_power_label.text = "БАЛАНС %.2f · АВТО %d/%d · %.0f/%.0fС" % [
		float(report.get("ratio", 0.0)),
		int(auto_report.get("auto_skill_count", 0)),
		int(auto_report.get("total_skill_count", 0)),
		float(auto_report.get("stage_duration", 0.0)),
		float(auto_report.get("min_stage_duration", 0.0)),
	]
	for attribute_id in ProgressionCatalog.attribute_ids(balance):
		var id: String = str(attribute_id)
		if not attribute_buttons.has(id):
			continue
		var button: Button = attribute_buttons[id] as Button
		var points: int = campaign.development.get_attribute_points(id)
		button.text = ProgressionCatalog.attribute_button_text(balance, id, points)
		button.disabled = campaign.development.attribute_points <= 0 or points >= ProgressionCatalog.attribute_max_points(balance, id)
	_refresh_skill_list()
	_refresh_skill_details()
	_refresh_passive_buttons()
	_refresh_pet_buttons()
	_refresh_pet_details()
	progression_hint_label.text = "%s. Характеристики и бонусы питомца — со следующего этапа" % str(auto_report.get("status", ""))


func _refresh_skill_list() -> void:
	progression_skill_list.clear()
	var selected_index: int = -1
	for skill_id in campaign.get_skill_ids():
		var id: String = str(skill_id)
		var view: Dictionary = campaign.get_skill_view(id)
		var locked_mark: String = "" if bool(view.get("unlocked", false)) else " [УР.%d]" % int(view.get("unlock_level", 1))
		var auto_mark: String = " [А]" if bool(view.get("auto_use", false)) else ""
		var line: String = "%s · ур.%d/%d · %s%s%s" % [
			str(view.get("name", id)),
			int(view.get("level", 1)),
			int(view.get("max_level", 5)),
			str(view.get("variant_name", "")),
			auto_mark,
			locked_mark,
		]
		var index: int = progression_skill_list.add_item(line)
		progression_skill_list.set_item_metadata(index, id)
		progression_skill_list.set_item_custom_fg_color(index, AshenStyle.PARCHMENT if bool(view.get("unlocked", false)) else AshenStyle.MUTED)
		if id == selected_skill_id:
			selected_index = index
	if selected_index >= 0:
		progression_skill_list.select(selected_index)


func _refresh_skill_details() -> void:
	var view: Dictionary = campaign.get_skill_view(selected_skill_id)
	if view.is_empty() or not bool(view.get("unlocked", false)):
		progression_skill_details.text = "%s · откроется на ур. %d" % [
			str(view.get("name", "Навык")),
			int(view.get("unlock_level", 1)),
		]
		skill_upgrade_button.text = "ЗАКРЫТ"
		skill_upgrade_button.disabled = true
		skill_auto_button.text = "АВТО"
		skill_auto_button.disabled = true
		skill_variant_button.text = "ВАРИАНТ"
		skill_variant_button.disabled = true
		return
	var cost: Dictionary = view.get("cost", {}) as Dictionary
	var cost_valid: bool = bool(cost.get("valid", false))
	var cost_gold: int = int(cost.get("gold", 0))
	var cost_materials: int = int(cost.get("materials", 0))
	var cost_points: int = int(cost.get("skill_points", 0))
	progression_skill_details.text = "%s · ур. %d/%d · %s · КД %.1f\n%s\nАвто: %s" % [
		str(view.get("name", "Навык")),
		int(view.get("level", 1)),
		int(view.get("max_level", 5)),
		str(view.get("variant_name", "")),
		float(view.get("cooldown_seconds", 0.0)),
		str(view.get("description", "")),
		"вкл" if bool(view.get("auto_use", false)) else "выкл",
	]
	skill_upgrade_button.text = "УЛУЧШИТЬ %d/%d" % [cost_gold, cost_materials] if cost_valid else "ПРЕДЕЛ"
	skill_upgrade_button.disabled = not cost_valid or campaign.development.skill_points < cost_points or campaign.gold < cost_gold or campaign.materials < cost_materials
	skill_auto_button.text = "АВТО ВКЛ" if bool(view.get("auto_use", false)) else "АВТО ВЫКЛ"
	skill_auto_button.disabled = false
	skill_variant_button.text = "ВАРИАНТ: " + str(view.get("variant_name", "")).to_upper()
	skill_variant_button.disabled = false


func _refresh_passive_buttons() -> void:
	for passive_id in campaign.get_passive_ids():
		var id: String = str(passive_id)
		if not passive_buttons.has(id):
			continue
		var view: Dictionary = campaign.get_passive_view(id)
		var passive: Dictionary = ProgressionCatalog.passive_by_id(balance, id)
		var short: String = str(passive.get("short", str(view.get("name", id))))
		var button: Button = passive_buttons[id] as Button
		var cost: Dictionary = view.get("cost", {}) as Dictionary
		if not bool(view.get("unlocked", false)):
			button.text = "[УР.%d] %s" % [int(view.get("unlock_level", 1)), short]
			button.disabled = true
			continue
		button.text = "%s %d/%d" % [short, int(view.get("level", 0)), int(view.get("max_level", 5))]
		button.disabled = not bool(cost.get("valid", false)) or campaign.development.skill_points < int(cost.get("skill_points", 0)) or campaign.gold < int(cost.get("gold", 0)) or campaign.materials < int(cost.get("materials", 0))


func _refresh_pet_buttons() -> void:
	for pet_id in campaign.get_pet_ids():
		var id: String = str(pet_id)
		if not pet_buttons.has(id):
			continue
		var view: Dictionary = campaign.get_pet_view(id)
		var pet: Dictionary = ProgressionCatalog.pet_by_id(balance, id)
		var short: String = str(pet.get("short", str(view.get("name", id))))
		var button: Button = pet_buttons[id] as Button
		if not bool(view.get("unlocked", false)):
			button.text = "[ЭТАП %d] %s" % [int(view.get("unlock_stage", 1)), short]
			button.disabled = true
			continue
		var mark: String = "[В] " if bool(view.get("selected", false)) else ""
		button.text = "%s%s %d" % [mark, short, int(view.get("level", 0))]
		button.disabled = false


func _refresh_pet_details() -> void:
	if selected_pet_id == "":
		progression_pet_details.text = "Питомец не выбран"
		pet_upgrade_button.text = "УЛУЧШИТЬ"
		pet_upgrade_button.disabled = true
		return
	var view: Dictionary = campaign.get_pet_view(selected_pet_id)
	var cost: Dictionary = view.get("cost", {}) as Dictionary
	var cost_valid: bool = bool(cost.get("valid", false))
	var cost_gold: int = int(cost.get("gold", 0))
	var cost_materials: int = int(cost.get("materials", 0))
	progression_pet_details.text = "%s · ур. %d/%d · %s" % [
		str(view.get("name", "Питомец")),
		int(view.get("level", 0)),
		int(view.get("max_level", 5)),
		str(view.get("description", "")),
	]
	pet_upgrade_button.text = "УЛУЧШИТЬ %d/%d" % [cost_gold, cost_materials] if cost_valid else "ПРЕДЕЛ"
	pet_upgrade_button.disabled = not cost_valid or campaign.gold < cost_gold or campaign.materials < cost_materials


func _on_attribute_pressed(attribute_id: String) -> void:
	var id: String = str(attribute_id)
	if campaign.allocate_attribute(id):
		var attribute: Dictionary = ProgressionCatalog.attribute_by_id(balance, id)
		_add_log("Характеристика: %s" % str(attribute.get("name", id)))
	else:
		_add_log("Очко характеристики недоступно")
	_save("характеристика")
	_update_view()


func _on_skill_selected(index: int) -> void:
	selected_skill_id = str(progression_skill_list.get_item_metadata(index))
	_refresh_skill_details()


func _on_skill_upgrade_pressed() -> void:
	var result: Dictionary = campaign.upgrade_skill(selected_skill_id)
	if bool(result.get("success", false)):
		_add_log("Навык улучшен: −%d золота, −%d пепла" % [int(result.get("gold", 0)), int(result.get("materials", 0))])
	else:
		_add_log("Навык не улучшен: %s" % str(result.get("reason", "")))
	_save("улучшение навыка")
	_update_view()


func _on_skill_auto_pressed() -> void:
	var enabled: bool = campaign.toggle_skill_auto(selected_skill_id)
	_add_log("Авто-навык: %s" % ("вкл" if enabled else "выкл"))
	_save("авто-режим навыка")
	_update_view()


func _on_skill_variant_pressed() -> void:
	var variant: String = campaign.cycle_skill_variant(selected_skill_id)
	if variant != "":
		_add_log("Вариант навыка изменён")
	_save("вариант навыка")
	_update_view()


func _on_passive_pressed(passive_id: String) -> void:
	var result: Dictionary = campaign.upgrade_passive(str(passive_id))
	if bool(result.get("success", false)):
		_add_log("Пассивная способность улучшена")
	else:
		_add_log("Способность не улучшена: %s" % str(result.get("reason", "")))
	_save("пассивная способность")
	_update_view()


func _on_pet_selected(pet_id: String) -> void:
	var id: String = str(pet_id)
	if campaign.select_pet(id):
		selected_pet_id = id
		var pet: Dictionary = ProgressionCatalog.pet_by_id(balance, id)
		_add_log("Питомец выбран: %s" % str(pet.get("name", id)))
	else:
		_add_log("Питомец ещё не открыт")
	_save("выбор питомца")
	_update_view()


func _on_pet_upgrade_pressed() -> void:
	if selected_pet_id == "":
		_add_log("Сначала выберите питомца")
		return
	var result: Dictionary = campaign.upgrade_pet(selected_pet_id)
	if bool(result.get("success", false)):
		_add_log("Питомец улучшен: −%d золота, −%d пепла" % [int(result.get("gold", 0)), int(result.get("materials", 0))])
	else:
		_add_log("Питомец не улучшен: %s" % str(result.get("reason", "")))
	_save("улучшение питомца")
	_update_view()


func _on_strike_pressed() -> void:
	_pulse_button(strike_button)
	campaign.use_skill("heavy_strike")


func _on_guard_pressed() -> void:
	_pulse_button(guard_button)
	campaign.use_skill("ash_guard")


func _on_action_pressed() -> void:
	_pulse_button(action_button)
	var changed: bool = false
	match campaign.status:
		CampaignState.STATUS_VICTORY:
			changed = campaign.next_stage()
			if not changed and campaign.mode_id() == "dungeon":
				var state: Dictionary = campaign.mode_state_view()
				_add_log("Подземелье недоступно: %s" % campaign.dungeon_block_reason(str(state.get("dungeon_id", ""))))
		CampaignState.STATUS_DEFEAT:
			changed = campaign.retry_stage()
		CampaignState.STATUS_COMPLETE:
			if campaign.mode_id() == "campaign":
				changed = campaign.restart_campaign()
			else:
				changed = campaign.restart_mode()
	if changed:
		_connect_battle_signals()
		selected_pet_id = str(campaign.development.selected_pet_id)
		_add_log("%s · %s" % [
			ModeCatalog.mode_short(balance, campaign.mode_id()),
			str(campaign.current_stage().get("name", "")),
		])
	_save("переход этапа")
	_update_view()


func _on_stage_finished() -> void:
	var reward: Dictionary = campaign.last_reward
	if campaign.status == CampaignState.STATUS_DEFEAT and audio_player != null:
		audio_player.play("defeat")
	elif campaign.status != CampaignState.STATUS_BATTLE and audio_player != null:
		audio_player.play("victory")
	match campaign.status:
		CampaignState.STATUS_VICTORY:
			_add_log("Победа: +%d опыта, +%d золота, +%d пепла" % [
				int(reward.get("experience", 0)),
				int(reward.get("gold", 0)),
				int(reward.get("materials", 0)),
			])
			if int(reward.get("levels", 0)) > 0:
				_add_log("Новый уровень: %d · +%d Х, +%d Н" % [
					campaign.level,
					int(reward.get("attribute_points", 0)),
					int(reward.get("skill_points", 0)),
				])
		CampaignState.STATUS_DEFEAT:
			_add_log("Герой пал. %s?" % str(ModeCatalog.modes_data(balance).get("defeat_action", "ПОВТОРИТЬ БОЙ")))
		CampaignState.STATUS_COMPLETE:
			_add_log("%s. Уровень %d" % [str(campaign.get_summary().get("status_name", "")), campaign.level])
	_save("итог этапа")


func _on_damage_dealt(target_name: String, amount: float, is_critical: bool) -> void:
	var suffix: String = " · крит" if is_critical else ""
	_add_log("%s: −%.0f%s" % [target_name, amount, suffix])
	var hit_hero: bool = target_name == campaign.system.hero.display_name
	var side: Control = hero_side if hit_hero else enemy_side
	var color: Color = AshenStyle.CRIMSON if hit_hero else AshenStyle.GOLD
	if is_critical and not hit_hero:
		color = AshenStyle.EMBER
	var damage_text: String = "КРИТ %.0f" % amount if is_critical else "%.0f" % amount
	_flash(side, color)
	_spawn_floating_number(damage_text, side, color)
	if audio_player != null:
		audio_player.play("critical" if is_critical else "attack")


func _on_enemy_defeated(enemy_name: String) -> void:
	_add_log("%s повержен" % enemy_name)


func _on_hero_defeated() -> void:
	_add_log("Герой пал")
	if audio_player != null:
		audio_player.play("defeat")


func _on_skill_used(skill_name: String) -> void:
	_add_log("Навык: %s" % skill_name)
	_spawn_floating_number(str(skill_name).to_upper(), stage_notice, AshenStyle.RUNE, int(effect_config.get("skill_font_size", 15)))
	if audio_player != null:
		audio_player.play("skill")


func _on_shield_changed(amount: float) -> void:
	_add_log("Щит: +%.0f" % amount)
	_spawn_floating_number("ЩИТ", hero_side, AshenStyle.SHIELD_COLOR, int(effect_config.get("skill_font_size", 15)))
	if audio_player != null:
		audio_player.play("shield")


func _on_boss_phase_started(enemy_name: String, phase_name: String) -> void:
	_add_log("%s: %s" % [enemy_name, phase_name])
	_spawn_floating_number(str(phase_name).to_upper(), stage_notice, AshenStyle.EMBER, int(effect_config.get("skill_font_size", 15)))
	if audio_player != null:
		audio_player.play("boss")


func _on_pet_attack(pet_name: String, assist_name: String, amount: float) -> void:
	_add_log("%s: %s −%.0f" % [pet_name, assist_name, amount])


func _on_hero_healed(amount: float) -> void:
	if amount >= 1.0:
		_add_log("Восстановление: +%.0f" % amount)


func _on_attack_dodged(target_name: String) -> void:
	_add_log("Уклонение: %s" % target_name)


func _apply_settings() -> void:
	if profile_manager == null:
		return
	var current: Dictionary = profile_manager.settings()
	var sound_on: bool = bool(current.get("sound_enabled", true))
	var particles_on: bool = bool(current.get("particles_enabled", true))
	var effects_on: bool = bool(current.get("effects_enabled", true))
	var target_fps: int = maxi(1, int(current.get("target_fps", 60)))
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_mute(0, not sound_on)
	if audio_player != null:
		audio_player.set_enabled(sound_on)
	if effect_pool != null:
		effect_pool.set_full_effects(effects_on)
	if particles_effect != null:
		particles_effect.visible = particles_on and effects_on
		particles_effect.emitting = particles_on and effects_on
	Engine.max_fps = target_fps
	_refresh_settings_ui(current)


func _refresh_settings_ui(current: Dictionary = {}) -> void:
	if profile_manager == null:
		return
	var settings: Dictionary = current if not current.is_empty() else profile_manager.settings()
	sound_button.text = "ЗВУК ВКЛ" if bool(settings.get("sound_enabled", true)) else "ЗВУК ВЫКЛ"
	particles_button.text = "ЧАСТИЦЫ ВКЛ" if bool(settings.get("particles_enabled", true)) else "ЧАСТИЦЫ ВЫКЛ"
	fps_button.text = "%d КАДРОВ/С" % int(settings.get("target_fps", 60))
	effects_button.text = "ЭФФЕКТЫ ПОЛНЫЕ" if bool(settings.get("effects_enabled", true)) else "ЭФФЕКТЫ ПРОСТЫЕ"


func _on_sound_pressed() -> void:
	_pulse_button(sound_button)
	var enabled: bool = not bool(profile_manager.settings().get("sound_enabled", true))
	profile_manager.set_setting("sound_enabled", enabled)
	_apply_settings()
	_add_log("Звук %s" % ("включён" if enabled else "выключен"))
	_save("настройка звука")


func _on_particles_pressed() -> void:
	_pulse_button(particles_button)
	var enabled: bool = not bool(profile_manager.settings().get("particles_enabled", true))
	profile_manager.set_setting("particles_enabled", enabled)
	_apply_settings()
	_add_log("Частицы %s" % ("включены" if enabled else "выключены"))
	_save("настройка частиц")


func _on_fps_pressed() -> void:
	_pulse_button(fps_button)
	var current_fps: int = int(profile_manager.settings().get("target_fps", 60))
	var next_fps: int = SaveCatalog.next_target_fps(balance, current_fps)
	profile_manager.set_setting("target_fps", next_fps)
	_apply_settings()
	_add_log("Частота кадров: %d" % next_fps)
	_save("настройка частоты кадров")


func _on_effects_pressed() -> void:
	_pulse_button(effects_button)
	var enabled: bool = not bool(profile_manager.settings().get("effects_enabled", true))
	profile_manager.set_setting("effects_enabled", enabled)
	_apply_settings()
	_add_log("Эффекты %s" % ("полные" if enabled else "упрощены"))
	_save("настройка эффектов")


func _pulse_button(button: Button) -> void:
	if effect_pool != null and button != null:
		effect_pool.pulse(button, AshenStyle.RUNE)
	if audio_player != null:
		audio_player.play("click")


func _save(reason: String) -> Dictionary:
	if profile_manager == null:
		return {"success": false, "reason": "Профиль не подключён"}
	var result: Dictionary = profile_manager.save(reason)
	if not bool(result.get("success", false)):
		_add_log("Сохранение недоступно: %s" % str(result.get("reason", "")))
	return result


func _notification(what: int) -> void:
	if not initialized or profile_manager == null:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE:
			profile_manager.on_pause()
			if audio_player != null:
				audio_player.set_enabled(false)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if audio_player != null:
				audio_player.set_enabled(bool(profile_manager.settings().get("sound_enabled", true)))
			var report: Dictionary = profile_manager.on_resume()
			if bool(report.get("eligible", false)):
				_add_log(SaveCatalog.reward_text(report))
			_update_view()


func _add_log(line: String) -> void:
	log_lines.insert(0, line)
	if log_lines.size() > 5:
		log_lines.resize(5)
	battle_log.text = "\n".join(log_lines)


func _flash(side: Control, color: Color) -> void:
	if effect_pool != null:
		effect_pool.flash(side, color)


func _spawn_floating_number(text: String, near: Control, color: Color, font_size: int = 0) -> void:
	if effect_pool == null:
		return
	var size: int = font_size if font_size > 0 else int(effect_config.get("label_font_size", 24))
	effect_pool.spawn_text(text, near, color, size)
