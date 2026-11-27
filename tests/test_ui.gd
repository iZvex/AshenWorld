extends SceneTree

# Точечная проверка ТОЛЬКО компактного интерфейса, экрана экипировки
# и рабочих настроек шестого этапа.
# Запуск: godot --headless --path . --script tests/test_ui.gd
# Полная сборка APK для этой проверки не требуется.

const MainScene = preload("res://scenes/main/main.tscn")
const AshenStyle = preload("res://scripts/ui/ashen_style.gd")
const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const CampaignState = preload("res://scripts/campaign/campaign_state.gd")
const SaveManager = preload("res://scripts/save/save_manager.gd")

const TEST_PROFILE_PATH: String = "user://test_ui_profile.json"
const TEST_TIME: int = 1800000000

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	print("Проверка компактного интерфейса и экипировки")
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
	_check("Ряд рабочих настроек добавлен", scene.sound_button != null and scene.particles_button != null and scene.fps_button != null)
	_check("Настройки игрока доступны", not scene.sound_button.disabled and not scene.particles_button.disabled and not scene.fps_button.disabled)
	_check("Звук и частицы включены по умолчанию", "ВКЛ" in scene.sound_button.text and "ВКЛ" in scene.particles_button.text)
	_check("Частота кадров показана", "КАДРОВ/С" in scene.fps_button.text and Engine.max_fps == 60)
	_check("Компактная строка здоровья сохранена", "ГЕРОЙ" in scene.hero_label.text and "×" in scene.separator_label.text and "ВРАГ" in scene.enemy_label.text)
	_check("Игровой цикл подключён", scene.campaign != null)
	if scene.campaign == null:
		print("Итого: %d проверок пройдено, %d провалено" % [passed, failed])
		quit(1)
		return
	_check("Экипировка подключена", scene.campaign.equipment != null)
	_check("Первый бой запущен", scene.campaign.system != null and scene.campaign.system.running)
	_check("Тема применена к корню", scene.theme != null)
	_check("Тема компактная", scene.theme != null and scene.theme.default_font_size <= 18)
	_check("Тема содержит стиль кнопки", scene.theme != null and scene.theme.has_stylebox("normal", "Button"))
	_check("Тема содержит стиль панели", scene.theme != null and scene.theme.has_stylebox("panel", "PanelContainer"))
	_check("Палитра содержит цвет угля", AshenStyle.EMBER != Color.WHITE and AshenStyle.EMBER.a > 0.9)

	var paths: Array = [
		"Background",
		"Particles",
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
	]
	for path in paths:
		_check("Узел %s" % path, scene.get_node_or_null(path) != null)
	_check("Все графические ассеты на месте", _assets_exist())
	_check("Фон использует текстуру", scene.get_node("Background").texture != null)
	_check("Разделитель использует текстуру", scene.divider.texture != null)
	_check("Малый символ использует текстуру", scene.sigil.texture != null)
	_check("Частицы углей активны", scene.get_node("Particles").emitting)

	_test_compact_layout(scene)
	_test_health_row(scene)
	_test_battle_controls(scene)
	_test_stage_transition(scene)
	_test_equipment_ui(scene, data)
	_test_progression_ui(scene, data)

	root.remove_child(scene)
	scene.free()
	SaveManager.new(data, TEST_PROFILE_PATH).clear_files()
	print("Итого: %d проверок пройдено, %d провалено" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_compact_layout(scene) -> void:
	_check("Панель не растягивается на весь экран", scene.get_node("Margin/Panel").size_flags_vertical == 0)
	_check("Заголовок уменьшен", scene.title_label.get_theme_font_size("font_size") <= 28)
	_check("Символ уменьшен", scene.sigil.custom_minimum_size.x <= 56.0)
	_check("Разделитель уменьшен", scene.divider.custom_minimum_size.y <= 24.0)
	_check("Полоса здоровья героя тонкая", scene.hero_health_bar.custom_minimum_size.y <= 20.0)
	_check("Полоса здоровья врага тонкая", scene.enemy_health_bar.custom_minimum_size.y <= 20.0)
	_check("Кнопки навыков компактные", scene.strike_button.custom_minimum_size.y <= 60.0 and scene.guard_button.custom_minimum_size.y <= 60.0)
	_check("Лог компактный", scene.log_card.custom_minimum_size.y <= 160.0)
	_check("Панель экипировки компактная", scene.equipment_panel.custom_minimum_size.y <= 380.0)
	_check("Панель экипировки скрыта по умолчанию", not scene.equipment_panel.visible)
	_check("Панель прогрессии компактная", scene.progression_panel.custom_minimum_size.y <= 460.0)
	_check("Панель прогрессии скрыта по умолчанию", not scene.progression_panel.visible)
	_check("Старых крупных карточек нет", scene.get_node_or_null("Margin/Panel/EnemyCard") == null and scene.get_node_or_null("Margin/Panel/HeroCard") == null)
	_check("Старой строки баланса нет", scene.get_node_or_null("Margin/Panel/BalanceLabel") == null)


func _test_health_row(scene) -> void:
	_check("Строка здоровья горизонтальная", scene.health_row is HBoxContainer)
	_check("Герой и противник в одной строке", scene.hero_side.get_parent() == scene.health_row and scene.enemy_side.get_parent() == scene.health_row)
	_check("Между полосами компактный разделитель", scene.separator_label.text == "×")
	_check("Подпись героя показывает здоровье", "ГЕРОЙ" in scene.hero_label.text and "/" in scene.hero_label.text)
	_check("Подпись врага показывает здоровье", "ВРАГ" in scene.enemy_label.text and "/" in scene.enemy_label.text)
	_check("Полосы одинаковой высоты", is_equal_approx(scene.hero_health_bar.custom_minimum_size.y, scene.enemy_health_bar.custom_minimum_size.y))
	_check("Шкалы здоровья без процентов", not scene.hero_health_bar.show_percentage and not scene.enemy_health_bar.show_percentage)
	_check("Шкалы инициализированы", scene.hero_health_bar.max_value > 0.0 and scene.enemy_health_bar.max_value > 0.0)
	_check("Щит имеет отдельную тонкую шкалу", scene.shield_bar.custom_minimum_size.y <= 8.0 and scene.shield_bar.max_value > 0.0)
	_check("Этап показан в заголовке", "Этап 1/5" in scene.stage_label.text)
	_check("Уровень, золото и пепел в одной строке", "УР." in scene.level_label.text and "ЗОЛОТО" in scene.gold_label.text and "ПЕПЕЛ" in scene.materials_label.text)
	_check("Лог заполнен сразу", not scene.battle_log.text.is_empty())


func _test_battle_controls(scene) -> void:
	_check("Кнопка перехода скрыта в бою", not scene.action_button.visible)
	_check("Оба навыка доступны", not scene.strike_button.disabled and not scene.guard_button.disabled)
	scene.strike_button.emit_signal("pressed")
	scene._update_view()
	_check("Нажатие кнопки применяет удар", scene.campaign.get_cooldown_remaining("heavy_strike") > 0.0)
	_check("Кнопка удара блокируется на откате", scene.strike_button.disabled)
	_check("Время отката видно на кнопке", "УДАР ·" in scene.strike_button.text)
	_check("Навык записан в лог", "Навык" in scene.battle_log.text)
	var hero_before: float = scene.hero_health_bar.value
	var enemy_before: float = scene.enemy_health_bar.value
	var shield_before: float = scene.shield_bar.value
	scene._process(1.0)
	_check("После автоатаки урон принят щитом или здоровьем", scene.hero_health_bar.value < hero_before or scene.shield_bar.value > shield_before or scene.shield_bar.value < shield_before)
	_check("После автоатаки здоровье врага уменьшилось", scene.enemy_health_bar.value < enemy_before)
	_check("Всплывающие числа урона созданы", scene.get_child_count() > 3)
	_check("Лог ограничен пятью строками", scene.log_lines.size() <= 5)


func _test_stage_transition(scene) -> void:
	_check("Первый этап завершён", _win_stage(scene))
	_check("Статус победы показан", scene.campaign.status == CampaignState.STATUS_VICTORY)
	_check("Кнопка перехода появилась", scene.action_button.visible)
	_check("Кнопка ведёт на следующий этап", "ЭТАП 2" in scene.action_button.text)
	_check("Награда показана в строке состояния", "ПОБЕДА" in scene.stage_notice.text and "+45 ОПЫТА" in scene.stage_notice.text)
	_check("Награда показывает пепел", "+5 ПЕПЛА" in scene.stage_notice.text)
	_check("Золото обновилось", "12" in scene.gold_label.text)
	_check("Пепел обновился", "5" in scene.materials_label.text)
	_check("Опыт обновился", scene.experience_bar.value > 0.0)
	scene.action_button.emit_signal("pressed")
	_check("Переход на второй этап выполнен", scene.campaign.stage_number() == 2)
	_check("Заголовок показывает второй этап", "Этап 2/5" in scene.stage_label.text)
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
		"res://assets/ui/divider.svg",
		"res://assets/ui/sigil.svg",
		"res://assets/ui/ember.svg",
	]:
		if not FileAccess.file_exists(path):
			return false
	return true
