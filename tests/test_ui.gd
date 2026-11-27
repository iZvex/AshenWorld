extends SceneTree

# Точечная проверка ТОЛЬКО компактного интерфейса третьего этапа.
# Запуск: godot --headless --path . --script tests/test_ui.gd
# Полная сборка APK для этой проверки не требуется.

const MainScene = preload("res://scenes/main/main.tscn")
const AshenStyle = preload("res://scripts/ui/ashen_style.gd")
const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const CampaignState = preload("res://scripts/campaign/campaign_state.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	print("Проверка компактного интерфейса")
	var scene = MainScene.instantiate()
	root.add_child(scene)
	# В режиме --script движок вызывает _ready() только на следующем кадре,
	# поэтому инициализируем сцену явно и отключаем автоматическую обработку.
	scene.set_process(false)
	scene.setup(CombatCatalog.load_balance())
	_check("Сцена создана", scene != null)
	_check("Игровой цикл подключён", scene.campaign != null)
	if scene.campaign == null:
		print("Итого: %d проверок пройдено, %d провалено" % [passed, failed])
		quit(1)
		return
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
		"Margin/Panel/HealthPanel/HealthBox/HealthRow",
		"Margin/Panel/HealthPanel/HealthBox/HealthRow/HeroSide/HeroLabel",
		"Margin/Panel/HealthPanel/HealthBox/HealthRow/HeroSide/HeroHealthBar",
		"Margin/Panel/HealthPanel/HealthBox/HealthRow/HeroSide/ShieldBar",
		"Margin/Panel/HealthPanel/HealthBox/HealthRow/SeparatorLabel",
		"Margin/Panel/HealthPanel/HealthBox/HealthRow/EnemySide/EnemyLabel",
		"Margin/Panel/HealthPanel/HealthBox/HealthRow/EnemySide/EnemyHealthBar",
		"Margin/Panel/HealthPanel/HealthBox/StageNotice",
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
	_check("Уровень и золото в одной строке", "УР." in scene.level_label.text and "ЗОЛОТО" in scene.gold_label.text)
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
	scene._process(1.0)
	_check("После автоатаки здоровье героя уменьшилось", scene.hero_health_bar.value < hero_before)
	_check("После автоатаки здоровье врага уменьшилось", scene.enemy_health_bar.value < enemy_before)
	_check("Всплывающие числа урона созданы", scene.get_child_count() > 3)
	_check("Лог ограничен пятью строками", scene.log_lines.size() <= 5)


func _test_stage_transition(scene) -> void:
	_check("Первый этап завершён", _win_stage(scene))
	_check("Статус победы показан", scene.campaign.status == CampaignState.STATUS_VICTORY)
	_check("Кнопка перехода появилась", scene.action_button.visible)
	_check("Кнопка ведёт на следующий этап", "ЭТАП 2" in scene.action_button.text)
	_check("Награда показана в строке состояния", "ПОБЕДА" in scene.stage_notice.text and "+45 ОПЫТА" in scene.stage_notice.text)
	_check("Золото обновилось", "12" in scene.gold_label.text)
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
