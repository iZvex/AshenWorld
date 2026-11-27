extends SceneTree

# Точечная проверка ТОЛЬКО тематического интерфейса.
# Запуск: godot --headless --path . --script tests/test_ui.gd
# Полная сборка APK для этой проверки не требуется.

const MainScene = preload("res://scenes/main/main.tscn")
const AshenStyle = preload("res://scripts/ui/ashen_style.gd")
const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	print("Проверка тематического интерфейса")
	var scene = MainScene.instantiate()
	root.add_child(scene)
	# В режиме --script движок вызывает _ready() только на следующем кадре,
	# поэтому инициализируем сцену явно и отключаем автоматическую обработку.
	scene.set_process(false)
	scene.setup(CombatCatalog.load_balance())
	_check("Сцена создана", scene != null)
	_check("Тема применена к корню", scene.theme != null)
	_check("Тема содержит стиль кнопки", scene.theme != null and scene.theme.has_stylebox("normal", "Button"))
	_check("Тема содержит стиль карточки", scene.theme != null and scene.theme.has_stylebox("panel", "PanelContainer"))
	_check("Палитра содержит цвет угля", AshenStyle.EMBER != Color.WHITE and AshenStyle.EMBER.a > 0.9)

	var paths: Array = [
		"Background",
		"Particles",
		"Margin/Panel/TitleBlock/TitleLabel",
		"Margin/Panel/TitleBlock/Divider",
		"Margin/Panel/TitleBlock/SubtitleLabel",
		"Margin/Panel/EnemyCard/EnemyBox/EnemyName",
		"Margin/Panel/EnemyCard/EnemyBox/EnemyHealthBar",
		"Margin/Panel/SigilRow/Sigil",
		"Margin/Panel/HeroCard/HeroBox/HeroName",
		"Margin/Panel/HeroCard/HeroBox/HeroHealthBar",
		"Margin/Panel/HeroCard/HeroBox/ShieldBar",
		"Margin/Panel/SkillButton",
		"Margin/Panel/LogCard/BattleLog",
		"Margin/Panel/BalanceLabel",
	]
	for path in paths:
		_check("Узел %s" % path, scene.get_node_or_null(path) != null)

	_check("Фон использует текстуру", scene.get_node("Background").texture != null)
	_check("Разделитель использует текстуру", scene.get_node("Margin/Panel/TitleBlock/Divider").texture != null)
	_check("Символ использует текстуру", scene.get_node("Margin/Panel/SigilRow/Sigil").texture != null)
	_check("Частицы углей активны", scene.get_node("Particles").emitting)
	_check("Все графические ассеты на месте", _assets_exist())
	if scene.system == null:
		_check("Система боя инициализирована", false)
		print("Итого: %d проверок пройдено, %d провалено" % [passed, failed])
		quit(1)
		return
	_check("Система боя инициализирована", true)

	var hero_bar: ProgressBar = scene.get_node("Margin/Panel/HeroCard/HeroBox/HeroHealthBar")
	var enemy_bar: ProgressBar = scene.get_node("Margin/Panel/EnemyCard/EnemyBox/EnemyHealthBar")
	var shield_bar: ProgressBar = scene.get_node("Margin/Panel/HeroCard/HeroBox/ShieldBar")
	var skill_button: Button = scene.get_node("Margin/Panel/SkillButton")
	var battle_log: Label = scene.get_node("Margin/Panel/LogCard/BattleLog")
	_check("Полосы здоровья без процентов", not hero_bar.show_percentage and not enemy_bar.show_percentage)
	_check("Шкалы инициализированы", hero_bar.max_value > 0.0 and enemy_bar.max_value > 0.0)
	_check("Здоровье героя полное", is_equal_approx(hero_bar.value, hero_bar.max_value))
	_check("Кнопка крупная для одной руки", skill_button.custom_minimum_size.y >= 80.0)
	_check("Лог боя заполнен", not battle_log.text.is_empty())
	_check("Перенос строк в логе включён", battle_log.autowrap_mode != 0)

	var enemy_before: float = enemy_bar.value
	var hero_before: float = hero_bar.value
	scene._process(1.0)
	_check("После автоатаки шкала врага уменьшилась", enemy_bar.value < enemy_before)
	_check("После автоатаки шкала героя уменьшилась", hero_bar.value < hero_before)
	_check("Всплывающие числа урона созданы", scene.get_child_count() > 3)

	_check("Навык применяется", scene.system.use_skill("heavy_strike"))
	scene._process(0.0)
	_check("Кнопка заблокирована на откате", skill_button.disabled)
	_check("Кнопка показывает время отката", "с" in skill_button.text)
	_check("Лог содержит запись о навыке", "Навык" in battle_log.text)
	_check("Щит имеет отдельную шкалу", shield_bar.max_value > 0.0)

	print("Итого: %d проверок пройдено, %d провалено" % [passed, failed])
	quit(1 if failed > 0 else 0)


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
