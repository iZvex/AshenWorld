extends Control

# Портретный HUD в духе наброска: оригинальный фон, портрет героя, крупные шкалы,
# правая быстрая навигация и некликабельные заглушки будущих разделов. Реальная логика
# кампании, экипировки, прогрессии, сохранений, режимов, звука и эффектов сохранена.

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
var hero_side: VBoxContainer
var hero_label: Label
var enemy_label: Label
var hero_health_bar: ProgressBar
var enemy_health_bar: ProgressBar
var shield_bar: ProgressBar
var enemy_hint_label: Label
var stage_notice: Label
var battle_overlay: Control
var arena_hero: TextureRect
var hero_ground: Panel
var enemy_ground: Panel
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
var log_card: Panel
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
var battle_button: Button
var summon_button: Button
var settings_button: Button
var header_frame: PanelContainer
var bottom_bar: PanelContainer
var section_title: Label
var content_area: VBoxContainer
var battle_panel: PanelContainer
var inventory_panel: PanelContainer
var summon_panel: PanelContainer
var settings_panel: PanelContainer
var summon_wallet_label: Label
var battle_title: Label
var battle_hint_label: Label
var inventory_title: Label
var summon_title: Label
var summon_hint_label: Label
var progression_title: Label
var mode_title: Label
var settings_title: Label
var settings_info_label: Label
var performance_label: Label
var away_window: Control
var away_card: PanelContainer
var away_title_label: Label
var away_time_label: Label
var away_rewards_label: Label
var away_hint_label: Label
var away_claim_button: Button
var notice_feed: VBoxContainer
var notice_labels: Array = []
var notice_times: Array = []
var notice_colors: Array = []
var save_indicator: TextureRect
var strike_icon: TextureRect
var guard_icon: TextureRect
var strike_cooldown_ring: TextureProgressBar
var guard_cooldown_ring: TextureProgressBar
var strike_cooldown_label: Label
var guard_cooldown_label: Label
var skill_slot3: PanelContainer
var skill_slot4: PanelContainer
var skills_soon_label: Label
var auto_button: Button
var auto_advance: bool = false
var auto_advance_timer: float = 0.0
var save_flash: float = 0.0
var away_config: Dictionary = {}
var notice_config: Dictionary = {}
var settings_hint_label: Label
var bottom_tabs: BoxContainer
var background: TextureRect
var dim_overlay: ColorRect
var hero_portrait: TextureRect
var portrait_frame: PanelContainer
var portrait_holder: Control
var level_badge: PanelContainer
var power_icon: TextureRect
var gold_pill: PanelContainer
var ash_pill: PanelContainer
var profile_panel: PanelContainer
var profile_lines: VBoxContainer
var stats_row: HBoxContainer
var nickname_label: Label
var rating_label: Label
var hero_vitals: PanelContainer
var battle_power_label: Label
var currency_bar: PanelContainer
var currency_row: HBoxContainer
var quest_stub: PanelContainer
var future_rail: VBoxContainer
var arena_enemies: GridContainer
var stub_strip: HBoxContainer
var enemy_cards: Array = []
var enemy_figure_by_id: Dictionary = {}
var enemy_figure_default: String = ""
var enemy_figure_pool: Array = []
var nav_icons: Dictionary = {}
var nav_icons_nodes: Dictionary = {}
var nav_labels: Dictionary = {}
var enemy_name_labels: Array = []
var enemy_mini_bars: Array = []
var hud_config: Dictionary = {}
var interface_config: Dictionary = {}
var navigation_config: Dictionary = {}
var tab_info: Dictionary = {}
var tab_order: Array = []
var default_tab: String = "battle"
var hide_label: String = "СКРЫТЬ"
var tabs: Dictionary = {}
var content_panels: Dictionary = {}
var active_tab: String = "battle"
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
	interface_config = PresentationCatalog.interface_config(balance)
	var navigation_value: Variant = interface_config.get("navigation", {})
	navigation_config = navigation_value as Dictionary if navigation_value is Dictionary else {}
	var hud_value: Variant = interface_config.get("hud", {})
	hud_config = hud_value as Dictionary if hud_value is Dictionary else {}
	away_config = PresentationCatalog.away_config(balance)
	notice_config = PresentationCatalog.notice_config(balance)
	_bind_nodes()
	theme = AshenStyle.build_theme(interface_config)
	_apply_interface_config()
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
	_setup_navigation()
	_apply_settings()
	_announce_startup(startup_report)
	_update_view()
	_refresh_away_window()
	var startup_summary: Dictionary = campaign.get_summary()
	print("Игровой цикл, режимы, звук и эффекты запущены: %s, профиль %s" % [
		str(startup_summary.get("mode_progress", "")),
		str(startup_report.get("status_text", "")),
	])


func _find(node_name: String) -> Node:
	var node: Node = find_child(node_name, true, false)
	if node == null:
		push_error("Не найден узел интерфейса: " + node_name)
	return node


func _color_from_array(value: Variant, fallback: Color) -> Color:
	var values: Array = []
	if value is Array:
		values = value as Array
	if values.size() < 4:
		return fallback
	return Color(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


func _collect_controls(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child is Control:
			result.append(child)
		_collect_controls(child, result)


func _apply_interface_config() -> void:
	var fonts: Dictionary = {}
	var fonts_value: Variant = interface_config.get("fonts", {})
	if fonts_value is Dictionary:
		fonts = fonts_value as Dictionary
	var node_sizes: Dictionary = {}
	var node_sizes_value: Variant = fonts.get("node_sizes", {})
	if node_sizes_value is Dictionary:
		node_sizes = node_sizes_value as Dictionary
	var minimum_sizes: Dictionary = {}
	var minimum_sizes_value: Variant = interface_config.get("minimum_sizes", {})
	if minimum_sizes_value is Dictionary:
		minimum_sizes = minimum_sizes_value as Dictionary
	var spacing: Dictionary = {}
	var spacing_value: Variant = interface_config.get("spacing", {})
	if spacing_value is Dictionary:
		spacing = spacing_value as Dictionary
	var layout: Dictionary = {}
	var layout_value: Variant = interface_config.get("layout", {})
	if layout_value is Dictionary:
		layout = layout_value as Dictionary
	var grid_columns: Dictionary = {}
	var grid_columns_value: Variant = layout.get("grid_columns", {})
	if grid_columns_value is Dictionary:
		grid_columns = grid_columns_value as Dictionary
	var controls: Array = []
	controls.append(self)
	_collect_controls(self, controls)
	for item in controls:
		var control: Control = item as Control
		if control == null:
			continue
		var node_name: String = str(control.name)
		if minimum_sizes.has(node_name):
			var size_value: Variant = minimum_sizes[node_name]
			if size_value is Array:
				var size_array: Array = size_value as Array
				if size_array.size() >= 2:
					control.custom_minimum_size = Vector2(float(size_array[0]), float(size_array[1]))
		if spacing.has(node_name):
			var constants_value: Variant = spacing[node_name]
			if constants_value is Dictionary:
				var constants: Dictionary = constants_value as Dictionary
				for constant_name in constants.keys():
					control.add_theme_constant_override(str(constant_name), int(constants[constant_name]))
		if control is GridContainer and grid_columns.has(node_name):
			control.columns = clampi(int(grid_columns[node_name]), 1, 6)
		if control is Label or control is Button or control is ItemList:
			var font_size: int = clampi(int(fonts.get("default", 20)), 12, 48)
			if control is OptionButton:
				font_size = clampi(int(fonts.get("option", font_size)), 12, 48)
			elif control is Button:
				font_size = clampi(int(fonts.get("button", font_size)), 12, 48)
			elif control is ItemList:
				font_size = clampi(int(fonts.get("item_list", font_size)), 12, 48)
			elif control is Label:
				font_size = clampi(int(fonts.get("label", font_size)), 12, 48)
			if node_sizes.has(node_name):
				font_size = clampi(int(node_sizes[node_name]), 12, 48)
			control.add_theme_font_size_override("font_size", font_size)
	if background != null:
		var texture_path: String = str(layout.get("background_texture", ""))
		if texture_path != "" and ResourceLoader.exists(texture_path):
			background.texture = load(texture_path)
		background.modulate = _color_from_array(layout.get("background_modulate_rgba", []), background.modulate)
	if dim_overlay != null:
		dim_overlay.color = _color_from_array(layout.get("dim_overlay_color_rgba", []), dim_overlay.color)
	_apply_hud_config()


func _apply_hud_config() -> void:
	var nav_value: Variant = hud_config.get("nav_icons", {})
	nav_icons = nav_value as Dictionary if nav_value is Dictionary else {}
	if nickname_label != null and hud_config.has("nickname"):
		nickname_label.text = str(hud_config.get("nickname", "")).to_upper()
	var portrait_path: String = str(hud_config.get("portrait_texture", ""))
	if hero_portrait != null and portrait_path != "" and ResourceLoader.exists(portrait_path):
		hero_portrait.texture = load(portrait_path)
	var power_icon_path: String = str(hud_config.get("power_icon", ""))
	if power_icon != null and power_icon_path != "" and ResourceLoader.exists(power_icon_path):
		power_icon.texture = load(power_icon_path)
	var icon_value: Variant = hud_config.get("stub_icons", {})
	if icon_value is Dictionary:
		for raw_name in (icon_value as Dictionary).keys():
			var icon_node: TextureRect = find_child(str(raw_name), true, false) as TextureRect
			var icon_path: String = str((icon_value as Dictionary)[raw_name])
			if icon_node != null and icon_path != "" and ResourceLoader.exists(icon_path):
				icon_node.texture = load(icon_path)
	var label_value: Variant = hud_config.get("stub_labels", {})
	if label_value is Dictionary:
		for raw_name in (label_value as Dictionary).keys():
			var label_node: Label = find_child(str(raw_name), true, false) as Label
			if label_node != null:
				label_node.text = str((label_value as Dictionary)[raw_name])
	for raw_id in nav_icons.keys():
		var tab_id: String = str(raw_id)
		var entry_value: Variant = nav_icons.get(tab_id, {})
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value as Dictionary
		var nav_button: Button = find_child(str(entry.get("button", "")), true, false) as Button
		if nav_button == null:
			continue
		var nav_icon: String = str(entry.get("icon", ""))
		var icon_node: TextureRect = nav_icons_nodes.get(tab_id, null) as TextureRect
		if icon_node != null and nav_icon != "" and ResourceLoader.exists(nav_icon):
			icon_node.texture = load(nav_icon)
		nav_button.tooltip_text = str(entry.get("label", tab_id.to_upper()))
		nav_button.add_theme_stylebox_override("normal", AshenStyle.nav_button_style(false))
		nav_button.add_theme_stylebox_override("hover", AshenStyle.nav_button_style(true))
		nav_button.add_theme_stylebox_override("pressed", AshenStyle.nav_button_style(true))
	var hero_figure_path: String = str(hud_config.get("hero_figure", ""))
	if arena_hero != null and hero_figure_path != "" and ResourceLoader.exists(hero_figure_path):
		arena_hero.texture = load(hero_figure_path)
	var figures_value: Variant = hud_config.get("enemy_figures", {})
	if figures_value is Dictionary:
		var figures: Dictionary = figures_value as Dictionary
		var by_id_value: Variant = figures.get("by_id", {})
		if by_id_value is Dictionary:
			enemy_figure_by_id = by_id_value as Dictionary
		enemy_figure_default = str(figures.get("default", ""))
		var list_value: Variant = figures.get("figures", [])
		if list_value is Array:
			enemy_figure_pool.clear()
			for raw_path in list_value as Array:
				enemy_figure_pool.append(str(raw_path))
	enemy_cards.clear()
	enemy_name_labels.clear()
	enemy_mini_bars.clear()
	var enemy_texture_path: String = str(hud_config.get("enemy_texture", ""))
	var count: int = clampi(int(hud_config.get("enemy_cards", 5)), 1, 8)
	for index in range(1, count + 1):
		var card: Control = find_child("EnemyCard%d" % index, true, false) as Control
		if card == null:
			continue
		enemy_cards.append(card)
		card.add_theme_stylebox_override("panel", AshenStyle.battlefield_card_style())
		var silhouette: TextureRect = find_child("EnemySilhouette%d" % index, true, false) as TextureRect
		if silhouette != null and enemy_texture_path != "" and ResourceLoader.exists(enemy_texture_path):
			silhouette.texture = load(enemy_texture_path)
			silhouette.modulate = Color(0.92, 0.78, 0.9, 0.9)
		var name_label: Label = find_child("EnemyNameLabel%d" % index, true, false) as Label
		if name_label != null:
			enemy_name_labels.append(name_label)
			name_label.add_theme_color_override("font_color", AshenStyle.CRIMSON)
		var mini_bar: ProgressBar = find_child("EnemyMiniBar%d" % index, true, false) as ProgressBar
		if mini_bar != null:
			enemy_mini_bars.append(mini_bar)
			mini_bar.add_theme_stylebox_override("background", AshenStyle.enemy_bar_background())
			mini_bar.add_theme_stylebox_override("fill", AshenStyle.enemy_bar_fill())
	for raw_name in ["QuestStub", "FutureRail", "StubStrip", "ArenaEnemies"]:
		var decor: Control = find_child(str(raw_name), true, false) as Control
		if decor != null:
			decor.mouse_filter = 2
	if arena_enemies != null:
		var layout_value: Variant = interface_config.get("layout", {})
		if layout_value is Dictionary:
			var columns_value: Variant = (layout_value as Dictionary).get("grid_columns", {})
			if columns_value is Dictionary:
				arena_enemies.columns = clampi(int((columns_value as Dictionary).get("ArenaEnemies", 3)), 1, 6)


func _bind_nodes() -> void:
	title_label = _find("TitleLabel") as Label
	stage_label = _find("StageLabel") as Label
	sigil = _find("Sigil") as TextureRect
	divider = _find("Divider") as TextureRect
	level_label = _find("LevelLabel") as Label
	experience_bar = _find("ExperienceBar") as ProgressBar
	gold_label = _find("GoldLabel") as Label
	materials_label = _find("MaterialsLabel") as Label
	hero_side = _find("HeroSide") as VBoxContainer
	hero_label = _find("HeroLabel") as Label
	enemy_label = _find("EnemyNameLabel1") as Label
	hero_health_bar = _find("HeroHealthBar") as ProgressBar
	enemy_health_bar = _find("EnemyMiniBar1") as ProgressBar
	shield_bar = _find("ShieldBar") as ProgressBar
	enemy_hint_label = _find("EnemyHintLabel") as Label
	stage_notice = _find("StageNotice") as Label
	header_frame = _find("HeaderFrame") as PanelContainer
	section_title = _find("SectionTitle") as Label
	content_area = _find("ContentArea") as VBoxContainer
	battle_panel = _find("BattlePanel") as PanelContainer
	inventory_panel = _find("InventoryPanel") as PanelContainer
	summon_panel = _find("SummonPanel") as PanelContainer
	settings_panel = _find("SettingsPanel") as PanelContainer
	bottom_bar = _find("BottomBar") as PanelContainer
	bottom_tabs = _find("BottomTabs") as BoxContainer
	background = _find("Background") as TextureRect
	dim_overlay = _find("DimOverlay") as ColorRect
	hero_portrait = _find("HeroPortrait") as TextureRect
	portrait_frame = _find("PortraitFrame") as PanelContainer
	portrait_holder = _find("PortraitHolder") as Control
	level_badge = _find("LevelBadge") as PanelContainer
	power_icon = _find("PowerIcon") as TextureRect
	gold_pill = _find("GoldPill") as PanelContainer
	ash_pill = _find("AshPill") as PanelContainer
	profile_panel = _find("ProfilePanel") as PanelContainer
	profile_lines = _find("ProfileLines") as VBoxContainer
	stats_row = _find("StatsRow") as HBoxContainer
	nickname_label = _find("NicknameLabel") as Label
	rating_label = _find("RatingValueLabel") as Label
	hero_vitals = _find("HeroVitals") as PanelContainer
	battle_power_label = _find("BattlePowerLabel") as Label
	currency_bar = _find("CurrencyBar") as PanelContainer
	currency_row = _find("CurrencyRow") as HBoxContainer
	quest_stub = _find("QuestStub") as PanelContainer
	future_rail = _find("FutureRail") as VBoxContainer
	arena_hero = _find("ArenaHero") as TextureRect
	hero_ground = _find("HeroGround") as Panel
	enemy_ground = _find("EnemyGround") as Panel
	arena_enemies = _find("ArenaEnemies") as GridContainer
	stub_strip = _find("StubStrip") as HBoxContainer
	equipment_panel = inventory_panel
	progression_panel = _find("ProgressionPanel") as PanelContainer
	mode_panel = _find("ModePanel") as PanelContainer
	equipment_button = _find("EquipmentButton") as Button
	progression_button = _find("ProgressionButton") as Button
	mode_button = _find("ModeButton") as Button
	battle_button = _find("BattleButton") as Button
	summon_button = _find("SummonButton") as Button
	settings_button = _find("SettingsButton") as Button
	equipment_power_label = _find("EquipmentPowerLabel") as Label
	wallet_label = _find("WalletLabel") as Label
	item_power_label = _find("ItemPowerLabel") as Label
	summon_type_button = _find("SummonTypeButton") as Button
	summon_one_button = _find("SummonOneButton") as Button
	summon_ten_button = _find("SummonTenButton") as Button
	summon_info_label = _find("SummonInfoLabel") as Label
	summon_status_label = _find("SummonStatusLabel") as Label
	history_label = _find("HistoryLabel") as Label
	summon_wallet_label = _find("SummonWalletLabel") as Label
	slot_filter = _find("SlotFilter") as OptionButton
	rarity_filter = _find("RarityFilter") as OptionButton
	affix_filter = _find("AffixFilter") as OptionButton
	item_list = _find("ItemList") as ItemList
	item_details = _find("ItemDetails") as Label
	equip_button = _find("EquipButton") as Button
	upgrade_button = _find("UpgradeButton") as Button
	lock_button = _find("LockButton") as Button
	dismantle_button = _find("DismantleButton") as Button
	auto_equip_button = _find("AutoEquipButton") as Button
	mass_dismantle_button = _find("MassDismantleButton") as Button
	equipment_hint_label = _find("EquipmentHintLabel") as Label
	progression_wallet_label = _find("ProgressionWalletLabel") as Label
	progression_power_label = _find("ProgressionPowerLabel") as Label
	attribute_hint_label = _find("AttributeHintLabel") as Label
	progression_skill_list = _find("ProgressionSkillList") as ItemList
	progression_skill_details = _find("ProgressionSkillDetails") as Label
	skill_upgrade_button = _find("SkillUpgradeButton") as Button
	skill_auto_button = _find("SkillAutoButton") as Button
	skill_variant_button = _find("SkillVariantButton") as Button
	progression_pet_details = _find("ProgressionPetDetails") as Label
	pet_upgrade_button = _find("PetUpgradeButton") as Button
	progression_hint_label = _find("ProgressionHintLabel") as Label
	battle_overlay = _find("BattleOverlay") as Control
	strike_button = _find("StrikeButton") as Button
	strike_icon = _find("StrikeIcon") as TextureRect
	strike_cooldown_ring = _find("StrikeCooldown") as TextureProgressBar
	strike_cooldown_label = _find("StrikeCooldownLabel") as Label
	guard_icon = _find("GuardIcon") as TextureRect
	guard_cooldown_ring = _find("GuardCooldown") as TextureProgressBar
	guard_cooldown_label = _find("GuardCooldownLabel") as Label
	skill_slot3 = _find("SkillSlot3") as PanelContainer
	skill_slot4 = _find("SkillSlot4") as PanelContainer
	skills_soon_label = _find("SkillsSoonLabel") as Label
	auto_button = _find("AutoButton") as Button
	guard_button = _find("GuardButton") as Button
	action_button = _find("ActionButton") as Button
	log_card = _find("LogCard") as Panel
	battle_log = _find("BattleLog") as Label
	hint_label = _find("HintLabel") as Label
	mode_status_label = _find("ModeStatusLabel") as Label
	mode_stats_label = _find("ModeStatsLabel") as Label
	mode_hint_label = _find("ModeHintLabel") as Label
	particles_effect = _find("Particles") as CPUParticles2D
	sound_button = _find("SoundButton") as Button
	particles_button = _find("ParticlesButton") as Button
	fps_button = _find("FpsButton") as Button
	effects_button = _find("EffectsButton") as Button
	battle_title = _find("BattleTitle") as Label
	battle_hint_label = _find("BattleHintLabel") as Label
	inventory_title = _find("InventoryTitle") as Label
	summon_title = _find("SummonTitle") as Label
	summon_hint_label = _find("SummonHintLabel") as Label
	progression_title = _find("ProgressionTitle") as Label
	mode_title = _find("ModeTitle") as Label
	settings_title = _find("SettingsTitle") as Label
	settings_info_label = _find("SettingsInfoLabel") as Label
	performance_label = _find("PerformanceLabel") as Label
	settings_hint_label = _find("SettingsHintLabel") as Label
	away_window = _find("AwayWindow") as Control
	away_card = _find("AwayCard") as PanelContainer
	away_title_label = _find("AwayTitleLabel") as Label
	away_time_label = _find("AwayTimeLabel") as Label
	away_rewards_label = _find("AwayRewardsLabel") as Label
	away_hint_label = _find("AwayHintLabel") as Label
	away_claim_button = _find("AwayClaimButton") as Button
	notice_feed = _find("NoticeFeed") as VBoxContainer
	save_indicator = _find("SaveIndicator") as TextureRect
	for notice_name in ["Notice1", "Notice2", "Notice3"]:
		var notice_label: Label = _find(str(notice_name)) as Label
		notice_labels.append(notice_label)
		notice_times.append(0.0)
		notice_colors.append(AshenStyle.GOLD)

func _load_data() -> Dictionary:
	# В игре данные приходят из автозагрузки, а в точечном тесте сцены
	# читаются напрямую из того же файла баланса.
	var config_node: Node = get_node_or_null("/root/GameConfig")
	if config_node != null:
		var from_autoload: Dictionary = config_node.get("values") as Dictionary
		if not from_autoload.is_empty():
			return from_autoload
	return CombatCatalog.load_balance()


func _style_skill_cluster(overlay_config: Dictionary) -> void:
	var icons_value: Variant = overlay_config.get("icons", {})
	var icons: Dictionary = icons_value as Dictionary if icons_value is Dictionary else {}
	for pair in [[strike_icon, "StrikeButton"], [guard_icon, "GuardButton"]]:
		var icon_node: TextureRect = pair[0] as TextureRect
		var icon_path: String = str(icons.get(str(pair[1]), ""))
		if icon_node != null and icon_path != "" and ResourceLoader.exists(icon_path):
			icon_node.texture = load(icon_path)
	var ring_value: Variant = overlay_config.get("cooldown_ring", {})
	var ring: Dictionary = ring_value as Dictionary if ring_value is Dictionary else {}
	var thickness: float = maxf(1.0, float(ring.get("thickness", 5)))
	var ready_rgba: Color = _color_from_array(ring.get("ready_rgba", []), AshenStyle.GOLD)
	var waiting_rgba: Color = _color_from_array(ring.get("waiting_rgba", []), AshenStyle.MUTED)
	for pair in [[strike_cooldown_ring, strike_button.custom_minimum_size.x], [guard_cooldown_ring, guard_button.custom_minimum_size.x]]:
		var bar: TextureProgressBar = pair[0] as TextureProgressBar
		# Кольцо садится внутрь золотого обода, не споря с рамкой кнопки.
		var diameter: int = int(maxf(24.0, float(pair[1]) - 12.0))
		if bar == null:
			continue
		bar.texture_under = AshenStyle.ring_texture(diameter, thickness, waiting_rgba)
		bar.texture_progress = AshenStyle.ring_texture(diameter, thickness, ready_rgba)
		bar.fill_mode = TextureProgressBar.FILL_CLOCKWISE
		bar.max_value = 1.0
		bar.step = 0.001
		bar.value = 0.0
		bar.visible = false
	for cooldown_label in [strike_cooldown_label, guard_cooldown_label]:
		var seconds_label: Label = cooldown_label as Label
		if seconds_label == null:
			continue
		# Цифры ложатся поверх приглушённой иконки, поэтому им нужна тёмная обводка.
		seconds_label.add_theme_color_override("font_color", AshenStyle.GOLD)
		seconds_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08, 0.92))
		seconds_label.add_theme_constant_override("outline_size", 4)
		seconds_label.add_theme_stylebox_override("normal", AshenStyle.slot_placeholder_style())
	for slot in [skill_slot3, skill_slot4]:
		var slot_panel: PanelContainer = slot as PanelContainer
		if slot_panel != null:
			slot_panel.add_theme_stylebox_override("panel", AshenStyle.slot_placeholder_style())
			slot_panel.tooltip_text = str(overlay_config.get("slot_tooltip", "СКОРО"))
	if skills_soon_label != null:
		skills_soon_label.add_theme_color_override("font_color", AshenStyle.MUTED)
		skills_soon_label.text = str(overlay_config.get("slot_tooltip", "СКОРО"))
	if auto_button != null:
		auto_button.text = str(overlay_config.get("auto_label", "АВТОБОЙ"))
		auto_button.tooltip_text = "Автоматически продолжать этапы"
		_apply_auto_style()
		auto_button.pressed.connect(_on_auto_pressed)


func _apply_auto_style() -> void:
	if auto_button == null:
		return
	for state_name in ["normal", "hover", "pressed", "focus"]:
		auto_button.add_theme_stylebox_override(state_name, AshenStyle.auto_button_style(auto_advance))
	auto_button.add_theme_color_override("font_color", AshenStyle.BACKGROUND if auto_advance else AshenStyle.GOLD)
	auto_button.text = "%s: %s" % [str(auto_label()), "ВКЛ" if auto_advance else "ВЫКЛ"]


func auto_label() -> String:
	return str((hud_config.get("battle_overlay", {}) as Dictionary).get("auto_label", "АВТОБОЙ"))


func _on_auto_pressed() -> void:
	auto_advance = not auto_advance
	if auto_advance and campaign != null and campaign.status != CampaignState.STATUS_BATTLE:
		auto_advance_timer = _auto_delay()
	_apply_auto_style()
	_pulse_button(auto_button)
	_push_notice("АВТОБОЙ ВКЛЮЧЁН" if auto_advance else "АВТОБОЙ ВЫКЛЮЧЕН", AshenStyle.GOLD)


func _apply_styles() -> void:
	header_frame.add_theme_stylebox_override("panel", AshenStyle.header_style())
	bottom_bar.add_theme_stylebox_override("panel", AshenStyle.bottom_bar_style())
	profile_panel.add_theme_stylebox_override("panel", AshenStyle.hud_panel_style())
	hero_vitals.add_theme_stylebox_override("panel", AshenStyle.vitals_plate_style())
	currency_bar.add_theme_stylebox_override("panel", AshenStyle.muted_panel_style())
	hero_ground.add_theme_stylebox_override("panel", AshenStyle.ground_shadow_style())
	enemy_ground.add_theme_stylebox_override("panel", AshenStyle.ground_shadow_style())
	quest_stub.add_theme_stylebox_override("panel", AshenStyle.muted_panel_style())
	portrait_frame.add_theme_stylebox_override("panel", AshenStyle.portrait_frame_style())
	level_badge.add_theme_stylebox_override("panel", AshenStyle.level_badge_style())
	for pill in [gold_pill, ash_pill]:
		var pill_panel: PanelContainer = pill as PanelContainer
		pill_panel.add_theme_stylebox_override("panel", AshenStyle.currency_pill_style())
	battle_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for panel in [inventory_panel, summon_panel, progression_panel, mode_panel, settings_panel]:
		panel.add_theme_stylebox_override("panel", AshenStyle.content_panel_style())
	log_card.add_theme_stylebox_override("panel", AshenStyle.log_strip_style())
	var overlay_value: Variant = hud_config.get("battle_overlay", {})
	var overlay_config: Dictionary = overlay_value as Dictionary if overlay_value is Dictionary else {}
	var radius_value: Variant = overlay_config.get("orb_radius", {})
	var orb_radii: Dictionary = radius_value as Dictionary if radius_value is Dictionary else {}
	for orb_pair in [[strike_button, int(orb_radii.get("StrikeButton", 62))], [guard_button, int(orb_radii.get("GuardButton", 48))]]:
		var orb: Button = orb_pair[0] as Button
		var orb_radius: int = int(orb_pair[1])
		orb.add_theme_stylebox_override("normal", AshenStyle.orb_style(false, orb_radius))
		orb.add_theme_stylebox_override("hover", AshenStyle.orb_style(true, orb_radius))
		orb.add_theme_stylebox_override("pressed", AshenStyle.orb_style(true, orb_radius))
		orb.add_theme_stylebox_override("disabled", AshenStyle.orb_style(false, orb_radius))
	_style_skill_cluster(overlay_config)
	action_button.add_theme_stylebox_override("normal", AshenStyle.action_button_style())
	for bar in [hero_health_bar, shield_bar, experience_bar]:
		bar.add_theme_stylebox_override("background", AshenStyle.bar_background())
	enemy_health_bar.add_theme_stylebox_override("background", AshenStyle.enemy_bar_background())
	hero_health_bar.add_theme_stylebox_override("fill", AshenStyle.bar_fill(AshenStyle.HERO_COLOR))
	enemy_health_bar.add_theme_stylebox_override("fill", AshenStyle.enemy_bar_fill())
	shield_bar.add_theme_stylebox_override("fill", AshenStyle.bar_fill(AshenStyle.SHIELD_COLOR))
	experience_bar.add_theme_stylebox_override("fill", AshenStyle.bar_fill(AshenStyle.GOLD))
	for label in [section_title, battle_title, inventory_title, summon_title, progression_title, mode_title, settings_title]:
		label.add_theme_color_override("font_color", AshenStyle.GOLD)
	for label in [battle_hint_label, settings_info_label, settings_hint_label, summon_hint_label]:
		label.add_theme_color_override("font_color", AshenStyle.RUNE)
	performance_label.add_theme_color_override("font_color", AshenStyle.GOLD)
	away_card.add_theme_stylebox_override("panel", AshenStyle.content_panel_style())
	away_claim_button.add_theme_stylebox_override("normal", AshenStyle.action_button_style())
	away_title_label.add_theme_color_override("font_color", AshenStyle.GOLD)
	away_time_label.add_theme_color_override("font_color", AshenStyle.RUNE)
	away_rewards_label.add_theme_color_override("font_color", AshenStyle.EMBER)
	away_hint_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	hint_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	for notice_label in notice_labels:
		var notice: Label = notice_label as Label
		notice.add_theme_color_override("font_color", AshenStyle.GOLD)
		notice.add_theme_font_size_override("font_size", int(notice_config.get("font_size", 20)))
	battle_power_label.add_theme_color_override("font_color", AshenStyle.GOLD)
	for raw_name in ["QuestTitleLabel", "QuestSoonLabel", "EventsLabel", "QuestsLabel", "RatingLabel", "StubStripLabel"]:
		var decor_label: Label = find_child(str(raw_name), true, false) as Label
		if decor_label != null:
			decor_label.add_theme_color_override("font_color", AshenStyle.EMBER if str(raw_name).ends_with("SoonLabel") or str(raw_name) == "StubStripLabel" else AshenStyle.GOLD)
	for raw_name in ["EventsIcon", "QuestsIcon", "RatingIcon", "PotionStubIcon", "CoinStubIcon", "TowerStubIcon"]:
		var decor_icon: TextureRect = find_child(str(raw_name), true, false) as TextureRect
		if decor_icon != null:
			decor_icon.modulate = Color(0.72, 0.62, 0.72, 0.78)
	summon_wallet_label.add_theme_color_override("font_color", AshenStyle.MUTED)
	nickname_label.add_theme_color_override("font_color", AshenStyle.GOLD)
	rating_label.add_theme_color_override("font_color", AshenStyle.GOLD)
	nickname_label.add_theme_color_override("font_shadow_color", AshenStyle.EMBER)
	nickname_label.add_theme_constant_override("shadow_offset_x", 0)
	nickname_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.add_theme_color_override("font_color", AshenStyle.GOLD)
	stage_label.add_theme_color_override("font_color", AshenStyle.PARCHMENT)
	level_label.add_theme_color_override("font_color", AshenStyle.STEEL)
	gold_label.add_theme_color_override("font_color", AshenStyle.GOLD)
	materials_label.add_theme_color_override("font_color", AshenStyle.EMBER)
	hero_label.add_theme_color_override("font_color", AshenStyle.STEEL)
	enemy_label.add_theme_color_override("font_color", AshenStyle.CRIMSON)
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
	away_claim_button.pressed.connect(_on_away_claim_pressed)


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
		"StrengthButton",
		"AgilityButton",
		"IntellectButton",
		"StaminaButton",
		"SpiritButton",
	]
	for index in range(mini(attribute_ids.size(), attribute_paths.size())):
		var attribute_id: String = str(attribute_ids[index])
		var attribute_button: Button = find_child(str(attribute_paths[index]), true, false) as Button
		attribute_buttons[attribute_id] = attribute_button
		attribute_button.pressed.connect(_on_attribute_pressed.bind(attribute_id))
	var passive_paths: Array = [
		"PassiveEnduranceButton",
		"PassivePrecisionButton",
		"PassiveSpiritButton",
	]
	var passive_ids: Array = campaign.get_passive_ids()
	for index in range(mini(passive_ids.size(), passive_paths.size())):
		var passive_id: String = str(passive_ids[index])
		var passive_button: Button = find_child(str(passive_paths[index]), true, false) as Button
		passive_buttons[passive_id] = passive_button
		passive_button.pressed.connect(_on_passive_pressed.bind(passive_id))
	var pet_paths: Array = [
		"PetFoxButton",
		"PetHoundButton",
		"PetOwlButton",
	]
	var pet_ids: Array = campaign.get_pet_ids()
	for index in range(mini(pet_ids.size(), pet_paths.size())):
		var pet_id: String = str(pet_ids[index])
		var pet_button: Button = find_child(str(pet_paths[index]), true, false) as Button
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
	_tick_notices(delta)
	_tick_save_indicator(delta)
	_tick_auto_advance(delta)
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


func _format_amount(value: Variant) -> String:
	var number: int = int(value)
	if number >= 100000:
		return "%dК" % int(number / 1000)
	return str(number)


func _refresh_arena_vitals(battle) -> void:
	if battle == null:
		hero_label.text = "ГЕРОЙ —"
		hero_health_bar.max_value = 1.0
		hero_health_bar.value = 0.0
		shield_bar.max_value = 1.0
		shield_bar.value = 0.0
		for index in range(enemy_mini_bars.size()):
			var idle_bar: ProgressBar = enemy_mini_bars[index] as ProgressBar
			if idle_bar != null:
				idle_bar.max_value = 1.0
				idle_bar.value = 0.0
		return
	hero_label.text = "ГЕРОЙ %d/%d" % [int(round(battle.hero.health)), int(round(battle.hero.max_health))]
	hero_health_bar.max_value = maxf(1.0, battle.hero.max_health)
	hero_health_bar.value = clampf(battle.hero.health, 0.0, hero_health_bar.max_value)
	shield_bar.max_value = hero_health_bar.max_value
	shield_bar.value = clampf(battle.hero.shield, 0.0, hero_health_bar.max_value)
	var current_index: int = int(battle.enemy_index)
	for index in range(enemy_mini_bars.size()):
		var bar: ProgressBar = enemy_mini_bars[index] as ProgressBar
		if bar == null:
			continue
		var total: float = 1.0
		var current: float = 0.0
		if index < battle.enemies.size():
			var data: Dictionary = battle.enemies[index] as Dictionary
			total = maxf(1.0, float(data.get("max_health", 1.0)))
			if index < enemy_name_labels.size():
				var name_label: Label = enemy_name_labels[index] as Label
				if name_label != null:
					var enemy_name: String = str(data.get("name", "ВРАГ")).to_upper()
					name_label.text = ("БОСС · " if bool(data.get("is_boss", false)) else "") + enemy_name
			if index > current_index:
				current = total
			elif index == current_index and battle.enemy != null:
				total = maxf(1.0, battle.enemy.max_health)
				current = battle.enemy.health
		bar.max_value = total
		bar.value = clampf(current, 0.0, total)
		var card: Control = enemy_cards[index] as Control if index < enemy_cards.size() else null
		if card != null:
			var active_card: bool = index == current_index and battle.enemy != null
			card.add_theme_stylebox_override("panel", AshenStyle.enemy_card_style(active_card))


func _rating_value(summary: Dictionary) -> int:
	var level: int = maxi(1, int(summary.get("level", 1)))
	var stage: int = maxi(1, int(summary.get("highest_stage", 1)))
	return level * 100 + stage * 10 + int(round(float(summary.get("equipment_power", 0.0))))


func _update_view() -> void:
	var summary: Dictionary = campaign.get_summary()
	var battle = campaign.system
	stage_label.text = str(summary["mode_progress"])
	level_label.text = str(int(summary["level"]))
	battle_power_label.text = "БМ %.0f" % float(summary["equipment_power"])
	rating_label.text = "РЕЙТИНГ %d" % _rating_value(summary)
	if level_label != null and level_label.text.strip_edges() == "":
		level_label.text = str(int(summary["level"]))
	if nickname_label != null and str(nickname_label.text).strip_edges() == "":
		nickname_label.text = str(summary.get("class_name", "Пепельный странник")).to_upper()
	experience_bar.max_value = float(summary["experience_to_next"])
	experience_bar.value = float(summary["experience"])
	gold_label.text = _format_amount(summary["gold"])
	materials_label.text = _format_amount(summary["materials"])
	equipment_power_label.text = "СИЛА %.0f" % float(summary["equipment_power"])
	_refresh_arena_vitals(battle)
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
	var skills_blocked: bool = campaign.status != CampaignState.STATUS_BATTLE
	_refresh_skill_button(strike_button, strike_icon, strike_cooldown_ring, strike_cooldown_label, "heavy_strike", skills_blocked)
	_refresh_skill_button(guard_button, guard_icon, guard_cooldown_ring, guard_cooldown_label, "ash_guard", skills_blocked)
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
	hint_label.text = _battle_hint_text()
	if log_card != null:
		log_card.visible = not log_lines.is_empty()
	if profile_manager != null:
		# Частота кадров живёт только в настройках: в бою технических значений нет.
		var fps_text: String = "—" if measured_fps <= 0.0 else "%.0f" % measured_fps
		performance_label.text = "КАДРЫ %s · ЦЕЛЬ %d" % [fps_text, int(profile_manager.settings().get("target_fps", 60))]
	_refresh_settings_ui()
	_refresh_arena_enemies()


func _refresh_arena_enemies() -> void:
	if campaign == null or enemy_cards.is_empty():
		return
	var stage: Dictionary = campaign.current_stage()
	var enemies_value: Variant = stage.get("enemies", [])
	var count: int = 0
	if enemies_value is Array:
		for entry_value in enemies_value as Array:
			if entry_value is Dictionary:
				count += maxi(0, int((entry_value as Dictionary).get("count", 1)))
			else:
				count += 1
	count = clampi(count, 1, enemy_cards.size())
	if arena_enemies != null:
		arena_enemies.columns = clampi(count, 1, 6)
	var enemy_ids: Array = _arena_enemy_ids(stage)
	for index in range(enemy_cards.size()):
		var card: Control = enemy_cards[index] as Control
		if card != null:
			card.visible = index < count
		if index < count:
			var figure: String = _enemy_figure_for(index, enemy_ids)
			var silhouette: TextureRect = find_child("EnemySilhouette%d" % (index + 1), true, false) as TextureRect
			if silhouette != null and figure != "" and ResourceLoader.exists(figure):
				silhouette.texture = load(figure)


func _arena_enemy_ids(stage: Dictionary) -> Array:
	var ids: Array = []
	var enemies_value: Variant = stage.get("enemies", [])
	if enemies_value is Array:
		for entry_value in enemies_value as Array:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value as Dictionary
				var enemy_id: String = str(entry.get("id", ""))
				var amount: int = maxi(1, int(entry.get("count", 1)))
				for _index in range(amount):
					ids.append(enemy_id)
			else:
				ids.append(str(entry_value))
	return ids


func _enemy_figure_for(index: int, enemy_ids: Array) -> String:
	var figure: String = ""
	if index < enemy_ids.size():
		figure = str(enemy_figure_by_id.get(str(enemy_ids[index]), ""))
	if figure == "" and not enemy_figure_pool.is_empty():
		figure = str(enemy_figure_pool[index % enemy_figure_pool.size()])
	if figure == "":
		figure = enemy_figure_default
	return figure


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
	summon_wallet_label.text = wallet_label.text
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


func _setup_navigation() -> void:
	tabs.clear()
	content_panels.clear()
	tab_order.clear()
	tab_info.clear()
	var order_value: Variant = navigation_config.get("tab_order", [])
	if order_value is Array:
		tab_order = (order_value as Array).duplicate()
	var info_value: Variant = navigation_config.get("tabs", {})
	if info_value is Dictionary:
		tab_info = (info_value as Dictionary).duplicate()
	default_tab = str(navigation_config.get("default_tab", "battle"))
	hide_label = str(navigation_config.get("hide_label", "СКРЫТЬ"))
	for raw_id in tab_order:
		var tab_id: String = str(raw_id)
		var entry: Dictionary = {}
		var entry_value: Variant = tab_info.get(tab_id, {})
		if entry_value is Dictionary:
			entry = entry_value as Dictionary
		var button: Button = _find(str(entry.get("button", ""))) as Button
		var panel: Control = _find(str(entry.get("panel", ""))) as Control
		if button == null or panel == null:
			continue
		tabs[tab_id] = button
		content_panels[tab_id] = panel
		nav_icons_nodes[tab_id] = button.find_child("NavIcon", true, false) as TextureRect
		nav_labels[tab_id] = button.find_child("NavLabel", true, false) as Label
		button.text = ""
		var nav_label_node: Label = nav_labels.get(tab_id, null) as Label
		if nav_label_node != null:
			nav_label_node.text = str(entry.get("label", tab_id.to_upper()))
		var title_node: Label = _find(str(entry.get("panel_title_node", ""))) as Label
		if title_node != null:
			title_node.text = str(entry.get("panel_title", ""))
		button.pressed.connect(_on_tab_pressed.bind(tab_id))
	_apply_nav_icons()
	active_tab = default_tab
	_select_tab(default_tab, false)


func _apply_nav_icons() -> void:
	for raw_id in nav_icons.keys():
		var tab_id: String = str(raw_id)
		var entry_value: Variant = nav_icons.get(tab_id, {})
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value as Dictionary
		var icon_path: String = str(entry.get("icon", ""))
		var icon_node: TextureRect = nav_icons_nodes.get(tab_id, null) as TextureRect
		if icon_node != null and icon_path != "" and ResourceLoader.exists(icon_path):
			icon_node.texture = load(icon_path)
		var button: Button = tabs.get(tab_id, null) as Button
		if button != null:
			button.tooltip_text = str(entry.get("label", tab_id.to_upper()))


func _select_tab(tab_id: String, with_sound: bool = true) -> void:
	var source_id: String = tab_id
	if not tab_info.has(source_id):
		return
	if tab_id == active_tab and tab_id != default_tab:
		tab_id = default_tab
	active_tab = tab_id
	var battle_active: bool = active_tab == default_tab
	if battle_overlay != null:
		battle_overlay.visible = battle_active
	if arena_enemies != null:
		arena_enemies.visible = battle_active
	if arena_hero != null:
		arena_hero.visible = battle_active
	if hero_vitals != null:
		hero_vitals.visible = battle_active
	if enemy_hint_label != null:
		enemy_hint_label.visible = battle_active
	for key in content_panels.keys():
		var panel: Control = content_panels[key] as Control
		if panel != null:
			panel.visible = str(key) == active_tab
	for key in tabs.keys():
		var button: Button = tabs[key] as Button
		if button == null:
			continue
		var key_id: String = str(key)
		var entry: Dictionary = {}
		var entry_value: Variant = tab_info.get(key_id, {})
		if entry_value is Dictionary:
			entry = entry_value as Dictionary
		var active: bool = key_id == active_tab
		var caption: String = hide_label if active and key_id != default_tab else str(entry.get("label", key_id.to_upper()))
		var caption_node: Label = nav_labels.get(key_id, null) as Label
		if caption_node != null:
			caption_node.text = caption
			caption_node.add_theme_color_override("font_color", AshenStyle.BACKGROUND if active else AshenStyle.PARCHMENT)
		var icon_node: TextureRect = nav_icons_nodes.get(key_id, null) as TextureRect
		if icon_node != null:
			icon_node.modulate = Color(1.0, 1.0, 1.0, 1.0) if active else Color(1.0, 1.0, 1.0, 0.86)
		button.add_theme_stylebox_override("normal", AshenStyle.nav_button_style(active))
		button.add_theme_stylebox_override("hover", AshenStyle.nav_button_style(true))
		button.add_theme_stylebox_override("pressed", AshenStyle.nav_button_style(true))
		button.add_theme_color_override("font_color", AshenStyle.BACKGROUND if active else AshenStyle.PARCHMENT)
	var current: Dictionary = {}
	var current_value: Variant = tab_info.get(active_tab, {})
	if current_value is Dictionary:
		current = current_value as Dictionary
	section_title.text = str(current.get("section_title", active_tab.to_upper()))
	equipment_visible = bool(current.get("refresh_equipment", false))
	progression_visible = bool(current.get("refresh_progression", false))
	mode_visible = bool(current.get("refresh_modes", false))
	_clear_force_dismantle()
	if with_sound:
		var source_button: Button = null
		if tabs.has(source_id):
			source_button = tabs[source_id] as Button
		if source_button != null:
			_pulse_button(source_button)
	if equipment_visible:
		_refresh_equipment_ui()
	elif progression_visible:
		_refresh_progression_ui()
	elif mode_visible:
		_refresh_mode_ui()
	_update_view()


func _on_tab_pressed(tab_id: String, with_sound: bool = true) -> void:
	_select_tab(tab_id, with_sound)


func _populate_modes() -> void:
	mode_buttons.clear()
	dungeon_buttons.clear()
	var mode_paths: Array = [
		"CampaignModeButton",
		"TowerModeButton",
		"DungeonModeButton",
	]
	var mode_ids: Array = ModeCatalog.mode_ids(balance)
	for index in range(mini(mode_ids.size(), mode_paths.size())):
		var mode_id: String = str(mode_ids[index])
		var button: Button = find_child(str(mode_paths[index]), true, false) as Button
		mode_buttons[mode_id] = button
		button.pressed.connect(_on_mode_button_pressed.bind(mode_id))
	var dungeon_paths: Array = [
		"GoldDungeonButton",
		"MaterialsDungeonButton",
		"ExperienceDungeonButton",
	]
	var dungeon_ids: Array = ModeCatalog.dungeon_ids(balance)
	for index in range(mini(dungeon_ids.size(), dungeon_paths.size())):
		var dungeon_id: String = str(dungeon_ids[index])
		var button: Button = find_child(str(dungeon_paths[index]), true, false) as Button
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
				_push_notice("НОВЫЙ УРОВЕНЬ %d" % campaign.level, AshenStyle.GOLD)
		CampaignState.STATUS_DEFEAT:
			_add_log("Герой пал. %s?" % str(ModeCatalog.modes_data(balance).get("defeat_action", "ПОВТОРИТЬ БОЙ")))
		CampaignState.STATUS_COMPLETE:
			_add_log("%s. Уровень %d" % [str(campaign.get_summary().get("status_name", "")), campaign.level])
	if auto_advance:
		auto_advance_timer = _auto_delay()
	_save("итог этапа")


func _enemy_anchor() -> Control:
	var index: int = 0
	if campaign != null and campaign.system != null:
		index = clampi(int(campaign.system.enemy_index), 0, maxi(0, enemy_cards.size() - 1))
	if index < enemy_cards.size():
		var card: Control = enemy_cards[index] as Control
		if card != null and card.visible:
			return card
	return arena_enemies


func _on_damage_dealt(target_name: String, amount: float, is_critical: bool) -> void:
	var suffix: String = " · крит" if is_critical else ""
	_add_log("%s: −%.0f%s" % [target_name, amount, suffix])
	var hit_hero: bool = target_name == campaign.system.hero.display_name
	var side: Control = hero_side if hit_hero else _enemy_anchor()
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
	_spawn_floating_number(str(skill_name).to_upper(), _arena_anchor(), AshenStyle.RUNE, int(effect_config.get("skill_font_size", 15)))
	if audio_player != null:
		audio_player.play("skill")


func _on_shield_changed(amount: float) -> void:
	_add_log("Щит: +%.0f" % amount)
	_spawn_floating_number("ЩИТ", hero_side, AshenStyle.SHIELD_COLOR, int(effect_config.get("skill_font_size", 15)))
	if audio_player != null:
		audio_player.play("shield")


func _on_boss_phase_started(enemy_name: String, phase_name: String) -> void:
	_add_log("%s: %s" % [enemy_name, phase_name])
	_push_notice("%s: %s" % [enemy_name, phase_name], AshenStyle.EMBER)
	_spawn_floating_number(str(phase_name).to_upper(), _arena_anchor(), AshenStyle.EMBER, int(effect_config.get("skill_font_size", 15)))
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
	# Состояние профиля живёт в настройках, а не в боевом HUD.
	settings_info_label.text = profile_manager.hint_text()


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
	if bool(result.get("success", false)):
		_flash_save_indicator()
	else:
		_add_log("Сохранение недоступно: %s" % str(result.get("reason", "")))
		_push_notice("СОХРАНЕНИЕ НЕДОСТУПНО", AshenStyle.EMBER)
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
				_refresh_away_window()
			_update_view()


func _announce_startup(report: Dictionary) -> void:
	# Служебные строки профиля остаются в отчёте и настройках, а в бой попадают
	# только короткие игровые сообщения.
	match str(report.get("status", "new")):
		"recovered":
			_push_notice("СОХРАНЕНИЕ ВОССТАНОВЛЕНО ИЗ КОПИИ", AshenStyle.EMBER)
		"corrupted":
			_push_notice("СОХРАНЕНИЕ НЕ ПРОЧИТАНО, НАЧАТ НОВЫЙ ПУТЬ", AshenStyle.EMBER)
		"future":
			_push_notice("СОХРАНЕНИЕ НОВОЙ ВЕРСИИ НЕ ТРОНУТО", AshenStyle.EMBER)
		"migrated":
			_push_notice("СОХРАНЕНИЕ ОБНОВЛЕНО", AshenStyle.GOLD)


func _refresh_skill_button(button: Button, icon: TextureRect, ring: TextureProgressBar, label: Label, skill_id: String, blocked: bool) -> void:
	if button == null:
		return
	button.text = ""
	var remaining: float = maxf(0.0, campaign.get_cooldown_remaining(skill_id))
	var total: float = maxf(0.01, float(campaign.get_skill_view(skill_id).get("cooldown_seconds", 1.0)))
	var waiting: bool = remaining > 0.0
	button.disabled = blocked or waiting
	if ring != null:
		ring.visible = waiting and not blocked
		ring.value = clampf(1.0 - remaining / total, 0.0, 1.0)
	if label != null:
		label.visible = waiting and not blocked
		label.text = "%.1f" % remaining if waiting else ""
	if icon != null:
		icon.modulate = Color(1.0, 1.0, 1.0, 0.45 if (blocked or waiting) else 1.0)


func _auto_delay() -> float:
	var overlay_value: Variant = hud_config.get("battle_overlay", {})
	var overlay: Dictionary = overlay_value as Dictionary if overlay_value is Dictionary else {}
	return maxf(0.2, float(overlay.get("auto_delay_seconds", 1.4)))


func _tick_auto_advance(delta: float) -> void:
	if not auto_advance or campaign == null or action_button == null:
		return
	if action_button == null or not action_button.visible or action_button.disabled:
		return
	if away_window != null and away_window.visible:
		return
	auto_advance_timer = maxf(0.0, auto_advance_timer - delta)
	if auto_advance_timer <= 0.0:
		_on_action_pressed()


func _battle_hint_text() -> String:
	match campaign.status:
		CampaignState.STATUS_VICTORY:
			return "ДАЛЬШЕ — ПРОДОЛЖИТЬ ПУТЬ"
		CampaignState.STATUS_DEFEAT:
			return "ЭТАП МОЖНО ПОВТОРИТЬ"
		CampaignState.STATUS_COMPLETE:
			return "КАМПАНИЯ ПРОЙДЕНА"
	return "НАЖМИТЕ УДАР ИЛИ ЩИТ"


func _refresh_away_window() -> void:
	if away_window == null:
		return
	var offline: Dictionary = {}
	if profile_manager != null:
		var offline_value: Variant = profile_manager.get_report().get("offline", {})
		if offline_value is Dictionary:
			offline = offline_value as Dictionary
	var seconds: int = int(offline.get("credited_seconds", 0))
	var show: bool = bool(offline.get("eligible", false)) and seconds >= int(away_config.get("min_seconds", 60))
	if not show:
		away_window.visible = false
		return
	var suffix: String = " · ЛИМИТ" if bool(offline.get("capped", false)) else ""
	away_title_label.text = str(away_config.get("title", "С ВОЗВРАЩЕНИЕМ"))
	away_time_label.text = "ВЫ ОТСУТСТВОВАЛИ %s%s" % [SaveCatalog.format_duration(seconds).to_upper(), suffix]
	away_rewards_label.text = "+%d ОПЫТА · +%d ЗОЛОТА · +%d ПЕПЛА" % [
		int(offline.get("experience", 0)),
		int(offline.get("gold", 0)),
		int(offline.get("materials", 0)),
	]
	away_hint_label.text = str(away_config.get("hint", ""))
	away_claim_button.text = str(away_config.get("claim_text", "ЗАБРАТЬ"))
	away_window.visible = true


func _on_away_claim_pressed() -> void:
	_pulse_button(away_claim_button)
	if audio_player != null:
		audio_player.play("click")
	if away_window != null:
		away_window.visible = false
	_push_notice("НАГРАДЫ ЗА ОТСУТСТВИЕ ЗАБРАНЫ", AshenStyle.GOLD)


func _push_notice(text: String, color: Color = Color.WHITE) -> void:
	if notice_labels.is_empty():
		return
	for index in range(notice_labels.size() - 1, 0, -1):
		var source: Label = notice_labels[index - 1] as Label
		var target: Label = notice_labels[index] as Label
		target.text = source.text
		target.visible = source.visible
		target.modulate = source.modulate
		notice_times[index] = notice_times[index - 1]
		notice_colors[index] = notice_colors[index - 1]
	var first: Label = notice_labels[0] as Label
	first.text = text
	first.visible = true
	first.modulate = Color(color.r, color.g, color.b, 1.0)
	notice_times[0] = float(notice_config.get("duration_seconds", 3.6))
	notice_colors[0] = color


func _tick_notices(delta: float) -> void:
	if notice_labels.is_empty():
		return
	var fade: float = maxf(0.05, float(notice_config.get("fade_seconds", 0.6)))
	for index in range(notice_labels.size()):
		var label: Label = notice_labels[index] as Label
		if not label.visible:
			continue
		notice_times[index] = maxf(0.0, float(notice_times[index]) - delta)
		var remaining: float = float(notice_times[index])
		var color: Color = AshenStyle.GOLD
		if notice_colors[index] is Color:
			color = notice_colors[index] as Color
		if remaining <= 0.0:
			label.visible = false
			label.text = ""
			continue
		label.modulate = Color(color.r, color.g, color.b, clampf(remaining / fade, 0.0, 1.0))


func _flash_save_indicator() -> void:
	if save_indicator == null:
		return
	save_flash = 1.0
	save_indicator.modulate = Color(1, 1, 1, 0.9)


func _tick_save_indicator(delta: float) -> void:
	if save_indicator == null or save_flash <= 0.0:
		return
	save_flash = maxf(0.0, save_flash - delta)
	save_indicator.modulate = Color(1, 1, 1, 0.9 * clampf(save_flash, 0.0, 1.0))


func _add_log(line: String) -> void:
	log_lines.insert(0, line)
	if log_lines.size() > 5:
		log_lines.resize(5)
	battle_log.text = "\n".join(log_lines)
	# Пустая карточка журнала не висит над ареной: она появляется с первым событием.
	if log_card != null:
		log_card.visible = not log_lines.is_empty()


func _arena_anchor() -> Control:
	if arena_enemies != null and arena_enemies.visible:
		return arena_enemies
	return stage_notice


func _flash(side: Control, color: Color) -> void:
	if effect_pool != null:
		effect_pool.flash(side, color)


func _spawn_floating_number(text: String, near: Control, color: Color, font_size: int = 0) -> void:
	if effect_pool == null:
		return
	var size: int = font_size if font_size > 0 else int(effect_config.get("label_font_size", 24))
	effect_pool.spawn_text(text, near, color, size)
