extends SceneTree

# Точечная проверка HUD по наброску, реального нижнего меню, экрана экипировки,
# трёх режимов и рабочих настроек офлайн-MVP.
# Запуск: godot --headless --path . --script tests/test_ui.gd
# Полная сборка APK для этой проверки не требуется.

const MainScene = preload("res://scenes/main/main.tscn")
const AshenStyle = preload("res://scripts/ui/ashen_style.gd")
const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const CampaignState = preload("res://scripts/campaign/campaign_state.gd")
const ModeCatalog = preload("res://scripts/campaign/mode_catalog.gd")
const SaveManager = preload("res://scripts/save/save_manager.gd")
const PresentationCatalog = preload("res://scripts/ui/presentation_catalog.gd")

const TEST_PROFILE_PATH: String = "user://test_ui_profile.json"
const TEST_TIME: int = 1800000000

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	print("Проверка игрового HUD, нижнего меню и экипировки")
	var data: Dictionary = CombatCatalog.load_balance()
	SaveManager.new(data, TEST_PROFILE_PATH).clear_files()
	var scene = MainScene.instantiate()
	root.add_child(scene)
	# В режиме --script движок вызывает _ready() только на следующем кадре,
	# поэтому инициализируем сцену явно и отключаем автоматическую обработку.
	scene.set_process(false)
	scene.setup(data, TEST_PROFILE_PATH, TEST_TIME)
	_check("Сцена создана", scene != null)
	_check("Локальный профиль подключён", scene.profile_manager != null)
	_check("Профиль создан при первом запуске", str(scene.profile_manager.get_report().get("status", "")) == "new")
	_check("Нижняя строка сообщает о локальном сохранении", "локальное сохранение" in scene.hint_label.text)
	_check("Офлайн-лимит показан", "12 ч" in scene.hint_label.text)
	_check("Ряд рабочих настроек добавлен", scene.sound_button != null and scene.particles_button != null and scene.fps_button != null and scene.effects_button != null)
	_check("Настройки игрока доступны", not scene.sound_button.disabled and not scene.particles_button.disabled and not scene.fps_button.disabled and not scene.effects_button.disabled)
	_check("Звук и частицы включены по умолчанию", "ВКЛ" in scene.sound_button.text and "ВКЛ" in scene.particles_button.text)
	_check("Частота кадров показана", "КАДРОВ/С" in scene.fps_button.text and Engine.max_fps == 60)
	_check("Режим эффектов показан", "ПОЛНЫЕ" in scene.effects_button.text)
	_check("Процедурные звуки подготовлены", scene.audio_player.stream_count() == 8 and scene.audio_player.voice_count() == 6)
	_check("Портрет и две крупные шкалы заменили компактную строку", scene.hero_portrait.texture != null and scene.hero_health_bar.custom_minimum_size.y >= 26.0 and scene.enemy_health_bar.custom_minimum_size.y >= 26.0 and not scene.separator_label.visible)
	_check("Игровой цикл подключён", scene.campaign != null)
	if scene.campaign == null:
		print("Итого: %d проверок пройдено, %d провалено" % [passed, failed])
		quit(1)
		return
	_check("Экипировка подключена", scene.campaign.equipment != null)
	_check("Первый бой запущен", scene.campaign.system != null and scene.campaign.system.running)
	_check("Тема применена к корню", scene.theme != null)
	_check("Базовый шрифт увеличен для читаемости", scene.theme != null and scene.theme.default_font_size >= 20 and scene.theme.default_font_size <= 24)
	_check("Тема содержит стиль кнопки", scene.theme != null and scene.theme.has_stylebox("normal", "Button"))
	_check("Тема содержит стиль панели", scene.theme != null and scene.theme.has_stylebox("panel", "PanelContainer"))
	_check("Палитра содержит цвет угля", AshenStyle.EMBER != Color.WHITE and AshenStyle.EMBER.a > 0.9)

	var paths: Array = [
		"Background",
		"Particles",
		"HeroPortrait",
		"CurrencyBar",
		"QuestStub",
		"FutureRail",
		"ArenaEnemies",
		"QuickRail",
		"Margin/Panel/Header/Sigil",
		"Margin/Panel/Header/Titles/TitleLabel",
		"Margin/Panel/Header/Titles/StageLabel",
		"Margin/Panel/Divider",
		"Margin/Panel/StatusRow/LevelLabel",
		"Margin/Panel/StatusRow/ExperienceBar",
		"Margin/Panel/StatusRow/GoldLabel",
		"Margin/Panel/StatusRow/MaterialsLabel",
		"Margin/Panel/HealthPanel/HealthBox/HealthRow",
		"Margin/Panel/MenuRow/EquipmentButton",
		"Margin/Panel/MenuRow/ProgressionButton",
		"Margin/Panel/MenuRow/ModeButton",
		"Margin/Panel/ModePanel",
		"Margin/Panel/ModePanel/ModeBox/ModeTopRow/ModeStatusLabel",
		"Margin/Panel/ModePanel/ModeBox/ModeTopRow/ModeStatsLabel",
		"Margin/Panel/ModePanel/ModeBox/ModeSwitchRow/CampaignModeButton",
		"Margin/Panel/ModePanel/ModeBox/ModeSwitchRow/TowerModeButton",
		"Margin/Panel/ModePanel/ModeBox/ModeSwitchRow/DungeonModeButton",
		"Margin/Panel/ModePanel/ModeBox/DungeonRow/GoldDungeonButton",
		"Margin/Panel/ModePanel/ModeBox/DungeonRow/MaterialsDungeonButton",
		"Margin/Panel/ModePanel/ModeBox/DungeonRow/ExperienceDungeonButton",
		"Margin/Panel/ModePanel/ModeBox/ModeHintLabel",
		"Margin/Panel/MenuRow/EquipmentPowerLabel",
		"Margin/Panel/ProgressionPanel",
		"Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionTopRow/ProgressionWalletLabel",
		"Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionTopRow/ProgressionPowerLabel",
		"Margin/Panel/ProgressionPanel/ProgressionBox/AttributeRow/StrengthButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/AttributeRow/AgilityButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/AttributeRow/IntellectButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/AttributeRow/StaminaButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/AttributeRow/SpiritButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/AttributeHintLabel",
		"Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionSkillList",
		"Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionSkillDetails",
		"Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionSkillActionsRow/SkillUpgradeButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionSkillActionsRow/SkillAutoButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionSkillActionsRow/SkillVariantButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/PassiveRow/PassiveEnduranceButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/PassiveRow/PassivePrecisionButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/PassiveRow/PassiveSpiritButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/PetRow/PetFoxButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/PetRow/PetHoundButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/PetRow/PetOwlButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionPetDetails",
		"Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionPetActionsRow/PetUpgradeButton",
		"Margin/Panel/ProgressionPanel/ProgressionBox/ProgressionPetActionsRow/ProgressionHintLabel",
		"Margin/Panel/EquipmentPanel/EquipmentBox/EquipmentTopRow/WalletLabel",
		"Margin/Panel/EquipmentPanel/EquipmentBox/SummonTypeRow/SummonTypeButton",
		"Margin/Panel/EquipmentPanel/EquipmentBox/SummonTypeRow/SummonOneButton",
		"Margin/Panel/EquipmentPanel/EquipmentBox/SummonTypeRow/SummonTenButton",
		"Margin/Panel/EquipmentPanel/EquipmentBox/SummonInfoLabel",
		"Margin/Panel/EquipmentPanel/EquipmentBox/SummonStatusLabel",
		"Margin/Panel/EquipmentPanel/EquipmentBox/HistoryLabel",
		"Margin/Panel/EquipmentPanel/EquipmentBox/FilterRow/SlotFilter",
		"Margin/Panel/EquipmentPanel/EquipmentBox/FilterRow/RarityFilter",
		"Margin/Panel/EquipmentPanel/EquipmentBox/FilterRow/AffixFilter",
		"Margin/Panel/EquipmentPanel/EquipmentBox/ItemList",
		"Margin/Panel/EquipmentPanel/EquipmentBox/ItemDetails",
		"Margin/Panel/EquipmentPanel/EquipmentBox/ActionsRow1/EquipButton",
		"Margin/Panel/EquipmentPanel/EquipmentBox/ActionsRow1/UpgradeButton",
		"Margin/Panel/EquipmentPanel/EquipmentBox/ActionsRow1/LockButton",
		"Margin/Panel/EquipmentPanel/EquipmentBox/ActionsRow2/DismantleButton",
		"Margin/Panel/EquipmentPanel/EquipmentBox/ActionsRow2/AutoEquipButton",
		"Margin/Panel/EquipmentPanel/EquipmentBox/ActionsRow2/MassDismantleButton",
		"Margin/Panel/EquipmentPanel/EquipmentBox/EquipmentHintLabel",
		"Margin/Panel/SkillRow/StrikeButton",
		"Margin/Panel/SkillRow/GuardButton",
		"Margin/Panel/ActionButton",
		"Margin/Panel/LogCard/BattleLog",
		"Margin/Panel/HintLabel",
		"Margin/Panel/SettingsRow/EffectsButton",
	]
	for path in paths:
		var node_name: String = path.split("/")[-1]
		_check("Узел %s" % node_name, scene.find_child(node_name, true, false) != null)
	_check("Все графические ассеты на месте", _assets_exist())
	_check("Фон использует текстуру", scene.get_node("Background").texture != null)
	_check("Разделитель использует текстуру", scene.divider.texture != null)
	_check("Малый символ использует текстуру", scene.sigil.texture != null)
	_check("Частицы углей активны", scene.get_node("Particles").emitting)

	_test_sketch_layout(scene)
	_test_health_row(scene)
	_test_battle_controls(scene)
	_test_stage_transition(scene)
	_test_equipment_ui(scene, data)
	_test_progression_ui(scene, data)
	_test_modes_ui(scene, data)
	_test_bottom_navigation(scene, data)
	_test_sketch_hud(scene, data)

	root.remove_child(scene)
	scene.free()
	SaveManager.new(data, TEST_PROFILE_PATH).clear_files()
	print("Итого: %d проверок пройдено, %d провалено" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_sketch_layout(scene) -> void:
	_check("Основная панель заполняет экран до нижнего меню", scene.get_node("Margin/Panel").size_flags_vertical == 3)
	_check("Заголовок остаётся читаемым", scene.title_label.get_theme_font_size("font_size") >= 28 and scene.title_label.get_theme_font_size("font_size") <= 32)
	_check("Символ уменьшен", scene.sigil.custom_minimum_size.x <= 56.0)
	_check("Разделитель уменьшен", scene.divider.custom_minimum_size.y <= 24.0)
	_check("Полоса здоровья героя крупная", scene.hero_health_bar.custom_minimum_size.y >= 26.0)
	_check("Полоса здоровья врага крупная", scene.enemy_health_bar.custom_minimum_size.y >= 26.0)
	_check("Кнопки навыков круглые", scene.strike_button.custom_minimum_size == Vector2(124, 124) and scene.guard_button.custom_minimum_size == Vector2(96, 96))
	_check("Полоса журнала боя компактная", scene.log_card.custom_minimum_size.y <= 130.0)
	_check("Панель экипировки компактная", scene.equipment_panel.custom_minimum_size.y <= 380.0)
	_check("Панель экипировки скрыта по умолчанию", not scene.equipment_panel.visible)
	_check("Панель прогрессии компактная", scene.progression_panel.custom_minimum_size.y <= 460.0)
	_check("Панель прогрессии скрыта по умолчанию", not scene.progression_panel.visible)
	_check("Панель режимов компактная", scene.mode_panel.custom_minimum_size.y <= 280.0)
	_check("Панель режимов скрыта по умолчанию", not scene.mode_panel.visible)
	_check("Старых крупных карточек нет", scene.get_node_or_null("Margin/Panel/EnemyCard") == null and scene.get_node_or_null("Margin/Panel/HeroCard") == null)
	_check("Старой строки баланса нет", scene.get_node_or_null("Margin/Panel/BalanceLabel") == null)


func _test_health_row(scene) -> void:
	_check("Верхняя панель использует горизонтальный ряд", scene.health_row is HBoxContainer)
	_check("Портрет и уровень слева от шкал", scene.portrait_column.get_parent() == scene.health_row and scene.level_label.get_parent() == scene.portrait_column)
	_check("Две шкалы собраны в вертикальный блок", scene.hero_side.get_parent() == scene.vitals_box and scene.enemy_side.get_parent() == scene.vitals_box)
	_check("Компактный разделитель удалён", not scene.separator_label.visible and scene.separator_label.text == "")
	_check("Оригинальный портрет героя загружен", scene.hero_portrait.texture != null and str(scene.hero_portrait.texture.resource_path).ends_with("hero_portrait.png"))
	_check("Подпись героя показывает здоровье", "ГЕРОЙ" in scene.hero_label.text and "/" in scene.hero_label.text)
	_check("Подпись врага показывает здоровье", "ВРАГ" in scene.enemy_label.text and "/" in scene.enemy_label.text)
	_check("Полосы одинаковой крупной высоты", is_equal_approx(scene.hero_health_bar.custom_minimum_size.y, scene.enemy_health_bar.custom_minimum_size.y) and scene.hero_health_bar.custom_minimum_size.y >= 26.0)
	_check("Шкалы здоровья без процентов", not scene.hero_health_bar.show_percentage and not scene.enemy_health_bar.show_percentage)
	_check("Шкалы инициализированы", scene.hero_health_bar.max_value > 0.0 and scene.enemy_health_bar.max_value > 0.0)
	_check("Щит имеет отдельную тонкую шкалу", scene.shield_bar.custom_minimum_size.y <= 10.0 and scene.shield_bar.max_value > 0.0)
	_check("Боевая мощь и опыт показаны под портретом", "БМ" in scene.battle_power_label.text and scene.experience_bar.get_parent() == scene.portrait_column)
	_check("Этап показан в заголовке", "Пепельные земли" in scene.stage_label.text and "Этап 1/30" in scene.stage_label.text)
	_check("Уровень, золото и пепел показаны в HUD", "УР." in scene.level_label.text and scene.gold_label.text.is_valid_int() and scene.materials_label.text.is_valid_int() and scene.gold_label.tooltip_text == "Золото" and scene.materials_label.tooltip_text == "Пепел" and scene.gold_label.get_parent() == scene.currency_row)
	_check("Лог заполнен сразу", not scene.battle_log.text.is_empty())


func _test_modes_ui(scene, data: Dictionary) -> void:
	_check("Кнопка режимов подключена", scene.mode_button != null)
	_check("Три кнопки режимов и три подземелья", scene.mode_buttons.size() == 3 and scene.dungeon_buttons.size() == 3)
	scene.campaign.highest_stage = 1
	scene.campaign.gold = 0
	scene.campaign.materials = 0
	scene.mode_button.emit_signal("pressed")
	_check("Панель режимов открылась", scene.mode_panel.visible)
	_check("Панель прогрессии скрыта при открытии режимов", not scene.progression_panel.visible)
	_check("Кнопка режимов изменила подпись", "СКРЫТЬ" in scene.mode_button.text)
	var campaign_button: Button = scene.mode_buttons["campaign"] as Button
	var tower_button: Button = scene.mode_buttons["tower"] as Button
	var dungeon_button: Button = scene.mode_buttons["dungeon"] as Button
	_check("Кампания доступна с первого этапа", not campaign_button.disabled)
	_check("Башня закрыта до пятого этапа", tower_button.disabled and "ЭТАП 5" in tower_button.text)
	_check("Подземелья закрыты до восьмого этапа", dungeon_button.disabled and "ЭТАП 8" in dungeon_button.text)

	scene.campaign.highest_stage = 8
	scene.campaign.gold = 100
	scene.campaign.materials = 100
	scene._refresh_mode_ui()
	_check("Башня открыта на восьмом этапе", not tower_button.disabled)
	_check("Режим подземелий открыт на восьмом этапе", not dungeon_button.disabled)
	_check("Золотое подземелье доступно", not (scene.dungeon_buttons["gold"] as Button).disabled)
	_check("Пепельное подземелье закрыто до двенадцатого этапа", (scene.dungeon_buttons["materials"] as Button).disabled)
	_check("Подземелье опыта закрыто до восемнадцатого этапа", (scene.dungeon_buttons["experience"] as Button).disabled)
	_check("Подсказка объясняет блокировки", "Откроется на этапе" in scene.mode_hint_label.text)

	tower_button.emit_signal("pressed")
	_check("Башня выбрана работающей кнопкой", scene.campaign.mode_id() == "tower")
	_check("Заголовок показывает ярус башни", "Ярус 1/30" in scene.stage_label.text)
	_check("Статус режимов обновлён", "Башня" in scene.mode_status_label.text)
	var gold_before: int = scene.campaign.gold
	var materials_before: int = scene.campaign.materials
	var cost: Dictionary = ModeCatalog.dungeon_entry_cost(data, "gold")
	(scene.dungeon_buttons["gold"] as Button).emit_signal("pressed")
	_check("Золотое подземелье выбрано работающей кнопкой", scene.campaign.mode_id() == "dungeon")
	_check("Цена входа списана из баланса", scene.campaign.gold == gold_before - int(cost.get("gold", 0)) and scene.campaign.materials == materials_before - int(cost.get("materials", 0)))
	_check("Заголовок показывает подземелье", "ЗОЛОТО" in scene.stage_label.text and "бой 1" in scene.stage_label.text)
	_check("Заход в подземелье учтён", int(scene.campaign.mode_state_view().get("dungeon_runs", 0)) == 1)
	_check("Портретный HUD сохранён при смене режимов", scene.hero_portrait.texture != null and "ГЕРОЙ" in scene.hero_label.text and "ВРАГ" in scene.enemy_label.text and not scene.separator_label.visible)
	campaign_button.emit_signal("pressed")
	_check("Возврат в кампанию работает", scene.campaign.mode_id() == "campaign")
	scene.mode_button.emit_signal("pressed")
	_check("Панель режимов закрылась", not scene.mode_panel.visible)


func _test_battle_controls(scene) -> void:
	_check("Кнопка перехода скрыта в бою", not scene.action_button.visible)
	_check("Оба навыка доступны", not scene.strike_button.disabled and not scene.guard_button.disabled)
	scene.strike_button.emit_signal("pressed")
	scene._update_view()
	_check("Нажатие кнопки применяет удар", scene.campaign.get_cooldown_remaining("heavy_strike") > 0.0)
	_check("Кнопка удара блокируется на откате", scene.strike_button.disabled)
	_check("Время отката видно на кнопке", "УДАР" in scene.strike_button.text and "\n" in scene.strike_button.text)
	_check("Навык записан в лог", "Навык" in scene.battle_log.text)
	var hero_before: float = scene.hero_health_bar.value
	var enemy_before: float = scene.enemy_health_bar.value
	var shield_before: float = scene.shield_bar.value
	scene._process(1.0)
	_check("После автоатаки урон принят щитом или здоровьем", scene.hero_health_bar.value < hero_before or scene.shield_bar.value > shield_before or scene.shield_bar.value < shield_before)
	_check("После автоатаки здоровье врага уменьшилось", scene.enemy_health_bar.value < enemy_before)
	_check("Всплывающие числа урона созданы", scene.effect_pool.active_count() > 0 and scene.effect_pool.pool_size() == 8)
	_check("Лог ограничен пятью строками", scene.log_lines.size() <= 5)


func _test_stage_transition(scene) -> void:
	_check("Первый этап завершён", _win_stage(scene))
	_check("Статус победы показан", scene.campaign.status == CampaignState.STATUS_VICTORY)
	_check("Кнопка перехода появилась", scene.action_button.visible)
	_check("Кнопка ведёт на следующий этап", "ЭТАП 2" in scene.action_button.text)
	_check("Награда записана в служебной подписи", "ПОБЕДА" in scene.stage_notice.text and "+45 ОПЫТА" in scene.stage_notice.text)
	_check("Награда показывает пепел", "+5 ПЕПЛА" in scene.stage_notice.text)
	_check("Золото обновилось", "12" in scene.gold_label.text)
	_check("Пепел обновился", "5" in scene.materials_label.text)
	_check("Опыт обновился", scene.experience_bar.value > 0.0)
	scene.action_button.emit_signal("pressed")
	_check("Переход на второй этап выполнен", scene.campaign.stage_number() == 2)
	_check("Заголовок показывает второй этап", "Этап 2/30" in scene.stage_label.text)
	_check("Кнопка перехода снова скрыта", not scene.action_button.visible)
	_check("Герой восстановлен", is_equal_approx(scene.campaign.system.hero.health, scene.campaign.system.hero.max_health))
	_check("Второй этап завершён", _win_stage(scene))
	scene.action_button.emit_signal("pressed")
	_check("Переход на этап босса выполнен", scene.campaign.stage_number() == 3)
	_check("Подпись противника помечает босса", scene.enemy_label.text.begins_with("БОСС"))
	_check("Подсказка о фазе босса видна", not scene.enemy_hint_label.text.is_empty())


func _test_equipment_ui(scene, data: Dictionary) -> void:
	scene.equipment_button.emit_signal("pressed")
	_check("Панель экипировки открылась", scene.equipment_panel.visible)
	_check("Кнопка переключения изменила подпись", "СКРЫТЬ" in scene.equipment_button.text)
	_check("Раскрытая панель остаётся компактной", scene.equipment_panel.get_combined_minimum_size().y <= 620.0)
	_check("Экран помещается в портретное окно", scene.get_node("Margin/Panel").get_combined_minimum_size().y <= 1100.0)
	_check("Фильтр слотов содержит все девять слотов", scene.slot_filter.get_item_count() == 10)
	_check("Фильтр редкостей содержит все шесть редкостей", scene.rarity_filter.get_item_count() == 7)
	_check("Фильтр параметров содержит все три свойства", scene.affix_filter.get_item_count() == 4)
	_check("Вероятности призыва показаны", "Шансы" in scene.summon_info_label.text)
	_check("Гарантия призыва показана", "гарантия" in scene.summon_info_label.text)
	_check("История призывов показана", "История" in scene.history_label.text)
	_check("Одиночный призыв доступен после побед", not scene.summon_one_button.disabled)
	_check("Пакетный призыв заблокирован при нехватке золота", scene.summon_ten_button.disabled)
	_check("Подсказка экипировки объясняет применение бонусов", "следующего этапа" in scene.equipment_hint_label.text)

	var gold_before: int = scene.campaign.gold
	var hero_before: Dictionary = scene.campaign.hero_data().duplicate()
	scene.summon_one_button.emit_signal("pressed")
	_check("Призыв создал предмет", int(scene.campaign.get_summary()["inventory_count"]) >= 1)
	_check("Золото списано за призыв", scene.campaign.gold < gold_before)
	_check("Список предметов заполнен", scene.item_list.get_item_count() >= 1)
	_check("История пополнилась", "История:" in scene.history_label.text)
	_check("Выбранный предмет описан", "сила" in scene.item_details.text)
	_check("Кнопка надевания доступна", not scene.equip_button.disabled)
	_check("Кнопка улучшения доступна", not scene.upgrade_button.disabled)

	var item_id: String = scene.selected_item_id
	var item_before: Dictionary = scene.campaign.equipment.get_item(item_id).duplicate()
	scene.equip_button.emit_signal("pressed")
	_check("Предмет надет", int(scene.campaign.get_summary()["equipped_count"]) >= 1)
	_check("Сила экипировки выросла", float(scene.campaign.get_summary()["equipment_power"]) > 0.0)
	var hero_after: Dictionary = scene.campaign.hero_data()
	var before_total: float = float(hero_before.get("max_health", 0.0)) + float(hero_before.get("attack", 0.0)) + float(hero_before.get("defense", 0.0))
	var after_total: float = float(hero_after.get("max_health", 0.0)) + float(hero_after.get("attack", 0.0)) + float(hero_after.get("defense", 0.0))
	_check("Бонусы предметов вошли в параметры героя", after_total > before_total)
	_check("Кнопка надевания показывает состояние", scene.equip_button.text == "НАДЕТО")

	var gold_before_upgrade: int = scene.campaign.gold
	var materials_before_upgrade: int = scene.campaign.materials
	scene.upgrade_button.emit_signal("pressed")
	_check("Уровень предмета вырос", int(scene.campaign.equipment.get_item(item_id).get("level", 0)) > int(item_before.get("level", 0)))
	_check("Золото списано за улучшение", scene.campaign.gold < gold_before_upgrade)
	_check("Пепел списан за улучшение", scene.campaign.materials < materials_before_upgrade)

	scene.lock_button.emit_signal("pressed")
	_check("Предмет заблокирован", bool(scene.campaign.equipment.get_item(item_id).get("locked", false)))
	_check("Разбор заблокированного предмета недоступен", scene.dismantle_button.disabled)
	scene.lock_button.emit_signal("pressed")
	_check("Замок снят", not bool(scene.campaign.equipment.get_item(item_id).get("locked", false)))

	scene.auto_equip_button.emit_signal("pressed")
	_check("Автонадевание не обнулило экипировку", int(scene.campaign.get_summary()["equipped_count"]) >= 1)
	scene.mass_dismantle_button.emit_signal("pressed")
	_check("Массовый разбор не удалил надетый предмет", int(scene.campaign.get_summary()["inventory_count"]) >= 1)

	scene.campaign.gold = 100
	scene.campaign.materials = 100
	scene.summon_one_button.emit_signal("pressed")
	var force_id: String = scene.selected_item_id
	var force_item: Dictionary = scene.campaign.equipment.get_item(force_id)
	force_item["rarity"] = "rare"
	force_item["rarity_score"] = 3
	force_item["locked"] = false
	scene._refresh_item_details()
	var inventory_before_force: int = int(scene.campaign.get_summary()["inventory_count"])
	_check("Ценный предмет требует отдельного действия", scene.dismantle_button.text == "РАЗОБРАТЬ ЦЕННОЕ")
	scene.dismantle_button.emit_signal("pressed")
	_check("Первое нажатие не удалило ценный предмет", int(scene.campaign.get_summary()["inventory_count"]) == inventory_before_force)
	_check("Появилось подтверждение разбора", scene.dismantle_button.text == "ПОДТВЕРДИТЬ РАЗБОР")
	scene.dismantle_button.emit_signal("pressed")
	_check("Второе нажатие разобрало ценный предмет", scene.campaign.equipment.get_item(force_id).is_empty())
	_check("Подтверждение сброшено после разбора", scene.dismantle_button.text == "РАЗОБРАТЬ")

	var equipment_data: Dictionary = data.get("equipment", {}) as Dictionary
	var slots: Array = equipment_data.get("slots", []) as Array
	scene.slot_filter.select(1)
	scene._on_filters_changed(1)
	_check("Фильтр слота применён", int(scene.campaign.equipment.get_filter_values().get("slot", 0)) == 1)
	_check("Фильтров достаточно для всех слотов", slots.size() == 9)
	scene.slot_filter.select(0)
	scene._on_filters_changed(0)

	scene.campaign.gold = 0
	scene.campaign.materials = 0
	scene.summon_type_button.emit_signal("pressed")
	_check("Категория призыва переключена", scene.selected_summon_id != "ash")
	_check("Показаны данные рунного призыва", "Рунный" in scene.summon_info_label.text)
	_check("Недоступный призыв заблокирован", scene.summon_one_button.disabled)
	_check("Причина блокировки показана", "Недостаточно" in scene.summon_status_label.text or "этапе" in scene.summon_status_label.text)

	scene.equipment_button.emit_signal("pressed")
	_check("Панель экипировки закрылась", not scene.equipment_panel.visible)


func _test_progression_ui(scene, data: Dictionary) -> void:
	scene.campaign.gold = 500
	scene.campaign.materials = 500
	scene.campaign.level = 4
	scene.campaign.development.set_level(4, false)
	scene.campaign.development.attribute_points = 10
	scene.campaign.development.skill_points = 10
	scene.progression_button.emit_signal("pressed")
	_check("Панель прогрессии открылась", scene.progression_panel.visible)
	_check("Панель экипировки скрыта при открытии прогрессии", not scene.equipment_panel.visible)
	_check("Кнопка прогрессии изменила подпись", "СКРЫТЬ" in scene.progression_button.text)
	_check("Раскрытая панель прогрессии компактна", scene.progression_panel.get_combined_minimum_size().y <= 620.0)
	_check("Экран с прогрессией помещается в портретное окно", scene.get_node("Margin/Panel").get_combined_minimum_size().y <= 1100.0)
	_check("Базовый класс показан", "Пепельный" in scene.progression_wallet_label.text)
	_check("Оценка баланса показана", "БАЛАНС" in scene.progression_power_label.text)
	_check("Диагностика автобоя показана", "АВТО" in scene.progression_power_label.text)
	_check("Кнопок характеристик пять", scene.attribute_buttons.size() == 5)
	_check("Список активных навыков содержит шесть записей", scene.progression_skill_list.get_item_count() == 6)
	_check("Кнопок пассивных способностей три", scene.passive_buttons.size() == 3)
	_check("Кнопок питомцев три", scene.pet_buttons.size() == 3)
	_check("Подсказка объясняет мягкий предел", "замедляется" in scene.attribute_hint_label.text)
	_check("Подсказка объясняет применение бонусов", "следующего этапа" in scene.progression_hint_label.text)

	var points_before: int = scene.campaign.development.attribute_points
	scene.attribute_buttons["strength"].emit_signal("pressed")
	_check("Нажатие характеристики распределяет очко", scene.campaign.development.get_attribute_points("strength") == 1 and scene.campaign.development.attribute_points == points_before - 1)

	scene.progression_skill_list.select(0)
	scene._on_skill_selected(0)
	_check("Выбранный навык описан", "ур." in scene.progression_skill_details.text)
	var skill_id: String = scene.selected_skill_id
	var skill_level_before: int = scene.campaign.development.get_skill_level(skill_id)
	scene.skill_upgrade_button.emit_signal("pressed")
	_check("Навык улучшается из интерфейса", scene.campaign.development.get_skill_level(skill_id) == skill_level_before + 1)
	var auto_before: bool = scene.campaign.development.is_skill_auto(skill_id)
	scene.skill_auto_button.emit_signal("pressed")
	_check("Авто-режим навыка переключается из интерфейса", scene.campaign.development.is_skill_auto(skill_id) != auto_before)
	var variant_before: String = scene.campaign.development.get_skill_variant(skill_id)
	scene.skill_variant_button.emit_signal("pressed")
	_check("Вариант навыка меняется из интерфейса", scene.campaign.development.get_skill_variant(skill_id) != variant_before)

	scene.passive_buttons["ashen_endurance"].emit_signal("pressed")
	_check("Пассивная способность улучшается из интерфейса", scene.campaign.development.get_passive_level("ashen_endurance") > 0)

	scene.pet_buttons["ash_fox"].emit_signal("pressed")
	_check("Питомец выбирается из интерфейса", scene.selected_pet_id == "ash_fox")
	scene.pet_upgrade_button.emit_signal("pressed")
	_check("Питомец улучшается из интерфейса", scene.campaign.development.get_pet_level("ash_fox") == 2)
	_check("Третий питомец закрыт на третьем этапе", scene.pet_buttons["rune_owl"].disabled)
	scene.campaign.stage_index = 4
	scene._refresh_progression_ui()
	_check("Третий питомец открыт на пятом этапе", not scene.pet_buttons["rune_owl"].disabled)

	scene.progression_button.emit_signal("pressed")
	_check("Панель прогрессии закрылась", not scene.progression_panel.visible)


func _win_stage(scene, max_steps: int = 240) -> bool:
	for step in range(max_steps):
		if scene.campaign.status != CampaignState.STATUS_BATTLE:
			return true
		if scene.campaign.get_cooldown_remaining("heavy_strike") <= 0.0:
			scene.campaign.use_skill("heavy_strike")
		if scene.campaign.system.hero.health < scene.campaign.system.hero.max_health * 0.75 and scene.campaign.get_cooldown_remaining("ash_guard") <= 0.0:
			scene.campaign.use_skill("ash_guard")
		scene._process(1.0)
	return scene.campaign.status != CampaignState.STATUS_BATTLE


func _check(name: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("  ✓ ", name)
	else:
		failed += 1
		printerr("  ✗ ", name)


func _assets_exist() -> bool:
	for path in [
		"res://assets/ui/background.svg",
		"res://assets/ui/background_sketch.png",
		"res://assets/ui/hero_portrait.png",
		"res://assets/ui/divider.svg",
		"res://assets/ui/sigil.svg",
		"res://assets/ui/ember.svg",
		"res://assets/ui/icons/enemy_wraith.svg",
		"res://assets/ui/icons/sword.svg",
		"res://assets/ui/icons/bag.svg",
		"res://assets/ui/icons/star.svg",
		"res://assets/ui/icons/runes.svg",
		"res://assets/ui/icons/tower.svg",
		"res://assets/ui/icons/gear.svg",
		"res://assets/ui/icons/quest.svg",
		"res://assets/ui/icons/gift.svg",
		"res://assets/ui/icons/scroll.svg",
		"res://assets/ui/icons/trophy.svg",
		"res://assets/ui/icons/coin.svg",
		"res://assets/ui/icons/ash.svg",
		"res://assets/ui/icons/potion.svg",
	]:
		if not FileAccess.file_exists(path):
			return false
	return true


func _test_bottom_navigation(scene, data: Dictionary) -> void:
	var config: Dictionary = PresentationCatalog.interface_config(data)
	var nav_value: Variant = config.get("navigation", {})
	var nav: Dictionary = nav_value as Dictionary if nav_value is Dictionary else {}
	var tab_info_value: Variant = nav.get("tabs", {})
	var tab_info: Dictionary = tab_info_value as Dictionary if tab_info_value is Dictionary else {}
	var order_value: Variant = nav.get("tab_order", [])
	var order: Array = order_value as Array if order_value is Array else []
	_check("Все шесть разделов описаны в balance.json", order.size() == 6 and tab_info.size() == 6)
	_check("Нижнее меню закреплено последним элементом экрана", scene.bottom_bar.get_parent() == scene.get_node("Margin/Panel") and scene.bottom_bar.get_index() == scene.get_node("Margin/Panel").get_child_count() - 1)
	_check("Вкладки образуют сетку три на две", scene.bottom_tabs is GridContainer and scene.bottom_tabs.columns == 3)
	_check("Карта разделов заполнена", scene.tabs.size() == 6 and scene.content_panels.size() == 6)
	_check("Все рабочие подписи увеличены", _min_font_size(scene) >= 18)
	for raw_id in order:
		var tab_id: String = str(raw_id)
		var entry_value: Variant = tab_info.get(tab_id, {})
		var entry: Dictionary = entry_value as Dictionary if entry_value is Dictionary else {}
		var button: Button = scene.tabs.get(tab_id) as Button
		var panel: Control = scene.content_panels.get(tab_id) as Control
		_check("Кнопка раздела %s подключена" % tab_id, button != null and panel != null)
		if button == null or panel == null:
			continue
		button.emit_signal("pressed")
		var visible_panels: int = 0
		for key in scene.content_panels.keys():
			var candidate: Control = scene.content_panels[key] as Control
			if candidate != null and candidate.visible:
				visible_panels += 1
		_check("Раздел %s открыт и подписан" % tab_id, scene.active_tab == tab_id and panel.visible and scene.section_title.text == str(entry.get("section_title", "")))
		_check("Раздел %s показан без наложения" % tab_id, visible_panels == 1)
		if tab_id != scene.default_tab:
			_check("Активная вкладка %s показывает возврат" % tab_id, scene.hide_label in button.text)
	var settings_button: Button = scene.tabs.get("settings") as Button
	if settings_button != null:
		settings_button.emit_signal("pressed")
		_check("Повторное нажатие возвращает на экран боя", scene.active_tab == scene.default_tab and scene.battle_panel.visible)


func _test_sketch_hud(scene, data: Dictionary) -> void:
	var config: Dictionary = PresentationCatalog.interface_config(data)
	var hud_value: Variant = config.get("hud", {})
	var hud: Dictionary = hud_value as Dictionary if hud_value is Dictionary else {}
	var quick_value: Variant = hud.get("quick_rail", {})
	var quick_nav: Dictionary = quick_value as Dictionary if quick_value is Dictionary else {}
	_check("Оригинальный фон наброска задан централизованно", str(scene.background.texture.resource_path).ends_with("background_sketch.png") and not str(scene.background.texture.resource_path).contains("uploads"))
	_check("Шесть быстрых иконок описаны в balance.json", quick_nav.size() == 6 and scene.quick_buttons.size() == 6)
	var quick_ready: bool = scene.quick_rail.get_child_count() == 6
	for raw_id in scene.quick_buttons.keys():
		var button: Button = scene.quick_buttons[raw_id] as Button
		if button == null or button.icon == null or not button.text.is_empty() or button.tooltip_text.is_empty():
			quick_ready = false
	_check("Быстрые иконки содержат реальные кнопки разделов", quick_ready)
	var inventory_quick: Button = scene.quick_buttons.get("inventory") as Button
	if inventory_quick != null:
		inventory_quick.emit_signal("pressed")
		_check("Быстрая иконка открывает настоящий инвентарь", scene.active_tab == "inventory" and scene.inventory_panel.visible)
		var hidden_overlay: Control = scene.find_child("BattleOverlay", true, false) as Control
		_check("Открытый раздел прячет боевой оверлей и арену", hidden_overlay != null and not hidden_overlay.visible and not scene.arena_enemies.visible and scene.inventory_panel.visible)
		inventory_quick.emit_signal("pressed")
		_check("Повторное нажатие возвращает на поле боя", scene.active_tab == scene.default_tab and scene.battle_panel.visible)
		_check("Возврат в бой снова показывает оверлей и арену", hidden_overlay != null and hidden_overlay.visible and scene.arena_enemies.visible)
	var stubs_ok: bool = scene.future_rail.mouse_filter == 2 and not _has_button(scene.future_rail) and not _has_button(scene.quest_stub) and not _has_button(scene.stub_strip) and not _has_button(scene.arena_enemies)
	for label_name in ["QuestSoonLabel", "EventsLabel", "QuestsLabel", "RatingLabel", "StubStripLabel"]:
		var label: Label = scene.find_child(label_name, true, false) as Label
		if label == null or "СКОРО" not in label.text:
			stubs_ok = false
	_check("Остальные элементы оформлены некликабельными подписями СКОРО", stubs_ok)
	var no_controls: bool = true
	for forbidden in ["MiniMap", "Minimap", "Joystick", "VirtualJoystick", "MapFrame"]:
		if scene.find_child(forbidden, true, false) != null:
			no_controls = false
	_check("Мини-карта и джойстик отсутствуют", no_controls)
	var visible_enemies: int = 0
	for item in scene.enemy_cards:
		var card: Control = item as Control
		if card != null and card.visible:
			visible_enemies += 1
	_check("Силуэты врагов показаны на арене", scene.arena_enemies.columns == visible_enemies and scene.arena_enemies.columns <= 3 and scene.enemy_cards.size() == 5 and visible_enemies > 0 and visible_enemies <= 5)
	_check("Нижнее меню 3 × 2 сохранено", scene.bottom_tabs.columns == 3 and scene.tabs.size() == 6)
	var overlay: Control = scene.find_child("BattleOverlay", true, false) as Control
	var strike: Button = scene.find_child("StrikeButton", true, false) as Button
	var guard: Button = scene.find_child("GuardButton", true, false) as Button
	var overlay_ok: bool = overlay != null and overlay.visible and scene.arena_enemies.visible and scene.battle_panel.get_child_count() == 0
	_check("Боевой экран показан оверлеем поверх арены", overlay_ok)
	var orbs_ok: bool = false
	if strike != null and guard != null:
		var strike_style: StyleBox = strike.get_theme_stylebox("normal")
		var guard_style: StyleBox = guard.get_theme_stylebox("normal")
		orbs_ok = strike_style is StyleBoxFlat and guard_style is StyleBoxFlat \
			and (strike_style as StyleBoxFlat).corner_radius_top_left >= int(strike.custom_minimum_size.x / 2) - 1 \
			and (guard_style as StyleBoxFlat).corner_radius_top_left >= int(guard.custom_minimum_size.x / 2) - 1
	_check("Умения оформлены круглыми кнопками", orbs_ok)
	var overlay_nodes: bool = true
	for overlay_name in ["LogCard", "HintLabel", "ActionButton", "BattleLog"]:
		if scene.find_child(overlay_name, true, false) == null:
			overlay_nodes = false
	_check("Журнал, подсказка и кнопка этапа живут в оверлее", overlay_nodes)
	var arena_hero: TextureRect = scene.find_child("ArenaHero", true, false) as TextureRect
	_check("Герой стоит на поле боя", arena_hero != null and arena_hero.texture != null and str(arena_hero.texture.resource_path).ends_with("hero_battle.png"))
	var figure_pool: Array = []
	var figures_value: Variant = hud.get("enemy_figures", {})
	if figures_value is Dictionary:
		var figures_list: Variant = (figures_value as Dictionary).get("figures", [])
		if figures_list is Array:
			figure_pool = figures_list as Array
	var silhouettes_ok: bool = figure_pool.size() >= 3
	for index in range(scene.enemy_cards.size()):
		var card: Control = scene.enemy_cards[index] as Control
		if card == null or not card.visible:
			continue
		var silhouette: TextureRect = scene.find_child("EnemySilhouette%d" % (index + 1), true, false) as TextureRect
		if silhouette == null or silhouette.texture == null or not figure_pool.has(str(silhouette.texture.resource_path)):
			silhouettes_ok = false
	_check("Войска противника используют фигуры врагов", silhouettes_ok)
	var bars_ok: bool = true
	for index in range(scene.enemy_cards.size()):
		var bar: ProgressBar = scene.find_child("EnemyMiniBar%d" % (index + 1), true, false) as ProgressBar
		if bar == null:
			bars_ok = false
	_check("У войск противника остались мини-шкалы здоровья", bars_ok)
	var currency_row: HBoxContainer = scene.currency_bar.get_node_or_null("CurrencyRow") as HBoxContainer
	var order_ok: bool = false
	if currency_row != null:
		var names: Array = []
		for child in currency_row.get_children():
			names.append(str(child.name))
		order_ok = names == ["CoinIcon", "GoldLabel", "AshIcon", "MaterialsLabel"]
	_check("Валюта идёт парами иконка-значение", order_ok)
	var rail_ok: bool = true
	for label_name in ["EventsLabel", "QuestsLabel", "RatingLabel"]:
		var rail_label: Label = scene.find_child(label_name, true, false) as Label
		if rail_label == null or not rail_label.text.contains("\n") or "СКОРО" not in rail_label.text:
			rail_ok = false
			continue
		var rail_font: Font = rail_label.get_theme_font("font")
		var rail_size: int = rail_label.get_theme_font_size("font_size")
		for line_text in rail_label.text.split("\n"):
			if rail_font.get_string_size(line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, rail_size).x > 96.0:
				rail_ok = false
	_check("Подписи правой колонки не обрезаются", rail_ok)


func _has_button(node: Node) -> bool:
	if node is Button:
		return true
	for child in node.get_children():
		if _has_button(child):
			return true
	return false


func _min_font_size(node: Node) -> int:
	var result: int = 999
	if node is Label or node is Button or node is ItemList:
		var control: Control = node as Control
		result = mini(result, control.get_theme_font_size("font_size"))
	for child in node.get_children():
		result = mini(result, _min_font_size(child))
	return result
