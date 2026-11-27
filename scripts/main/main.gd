extends Control

# Компактный экран кампании и экипировки: здоровье героя и противника
# в одной строке, этапы, награды, Алтарь призыва и инвентарь. Все кнопки
# связаны с рабочим состоянием CampaignState и EquipmentState.

const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const CampaignState = preload("res://scripts/campaign/campaign_state.gd")
const EquipmentCatalog = preload("res://scripts/equipment/equipment_catalog.gd")
const AshenStyle = preload("res://scripts/ui/ashen_style.gd")

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
var strike_button: Button
var guard_button: Button
var action_button: Button
var log_card: PanelContainer
var battle_log: Label
var hint_label: Label

var campaign
var balance: Dictionary = {}
var log_lines: PackedStringArray = PackedStringArray()
var initialized: bool = false
var equipment_visible: bool = false
var selected_summon_id: String = "ash"
var selected_item_id: String = ""
var force_dismantle_item_id: String = ""
var force_dismantle_deadline_ms: int = 0

const FORCE_DISMANTLE_WINDOW_MS: int = 5000


func _ready() -> void:
	setup(_load_data())


func setup(data: Dictionary) -> void:
	# Явный вызов нужен точечному тесту: при запуске через --script узел
	# входит в дерево раньше, чем движок успевает вызвать _ready().
	if initialized:
		return
	initialized = true
	balance = data
	_bind_nodes()
	theme = AshenStyle.build_theme()
	_apply_styles()
	campaign = CampaignState.new(data)
	campaign.boss_phase_started.connect(_on_boss_phase_started)
	_connect_battle_signals()
	_connect_ui_signals()
	_populate_filters()
	var summon_ids: Array = campaign.equipment.get_summon_ids()
	if summon_ids.size() > 0:
		selected_summon_id = str(summon_ids[0])
	_add_log("Этап %d: %s" % [campaign.stage_number(), str(campaign.current_stage().get("name", ""))])
	_update_view()
	print("Игровой цикл и экипировка запущены: этапов %d, текущий этап %d" % [campaign.stage_count(), campaign.stage_number()])


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
	equipment_panel.add_theme_stylebox_override("panel", AshenStyle.compact_panel_style())
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


func _connect_ui_signals() -> void:
	strike_button.pressed.connect(_on_strike_pressed)
	guard_button.pressed.connect(_on_guard_pressed)
	action_button.pressed.connect(_on_action_pressed)
	equipment_button.pressed.connect(_on_equipment_toggle_pressed)
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
	materials_label.text = "ПЕПЕЛ %d" % int(summary["materials"])
	equipment_power_label.text = "СИЛА ЭКИПИРОВКИ %.0f" % float(summary["equipment_power"])
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
	if equipment_visible:
		_refresh_equipment_ui()


func _on_equipment_toggle_pressed() -> void:
	equipment_visible = not equipment_visible
	equipment_panel.visible = equipment_visible
	_clear_force_dismantle()
	if equipment_visible:
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
	_update_view()


func _on_filters_changed(_index: int) -> void:
	campaign.set_equipment_filters(slot_filter.selected, rarity_filter.selected, affix_filter.selected)
	_refresh_equipment_ui()


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
	_update_view()


func _on_upgrade_pressed() -> void:
	var result: Dictionary = campaign.upgrade_item(selected_item_id)
	if bool(result.get("success", false)):
		_add_log("Улучшение: −%d золота, −%d пепла" % [int(result.get("gold", 0)), int(result.get("materials", 0))])
	else:
		_add_log("Улучшение недоступно: %s" % str(result.get("reason", "")))
	_update_view()


func _on_lock_pressed() -> void:
	var locked: bool = campaign.toggle_item_lock(selected_item_id)
	if locked:
		_add_log("Предмет заблокирован")
	else:
		_add_log("Замок снят")
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
	_update_view()


func _is_force_dismantle_armed(item_id: String) -> bool:
	return item_id != "" and item_id == force_dismantle_item_id and Time.get_ticks_msec() <= force_dismantle_deadline_ms


func _clear_force_dismantle() -> void:
	force_dismantle_item_id = ""
	force_dismantle_deadline_ms = 0


func _on_auto_equip_pressed() -> void:
	var changed: int = campaign.auto_equip_items()
	_add_log("Автонадевание: обновлено слотов %d" % changed)
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
			_add_log("Победа: +%d опыта, +%d золота, +%d пепла" % [
				int(reward.get("experience", 0)),
				int(reward.get("gold", 0)),
				int(reward.get("materials", 0)),
			])
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
