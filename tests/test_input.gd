extends SceneTree

# Проверка нажатий на оверлее боя: раньше невидимая панель перехватывала
# клики, и кнопка «ДАЛЬШЕ · ЭТАП» не продолжала бой.
const STATUS_BATTLE: int = 0

var passed: int = 0
var failed: int = 0

var viewport: SubViewport


func _initialize() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.gui_disable_input = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	viewport.add_child(scene)
	for _index in range(4):
		await process_frame

	var battle_panel: Control = scene.find_child("BattlePanel", true, false) as Control
	var margin: Control = scene.find_child("Margin", true, false) as Control
	_check("Невидимая боевая панель не перехватывает нажатия", battle_panel != null and battle_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_check("Контейнер разделов пропускает нажатия к оверлею", margin != null and margin.mouse_filter == Control.MOUSE_FILTER_IGNORE)

	var stage_before: int = scene.campaign.stage_index
	_click(scene.action_button.get_global_rect().get_center())
	await process_frame
	await process_frame
	_check("Кнопка ДАЛЬШЕ продолжает бой", scene.campaign.stage_index == stage_before + 1 and scene.campaign.status == STATUS_BATTLE and scene.campaign.system != null)
	_check("После перехода кнопка этапа скрыта", not scene.action_button.visible)
	var enemy: RefCounted = scene.campaign.system.enemy
	_check("Новый бой получил свежего врага", enemy != null and bool(enemy.get("alive")) and float(enemy.get("health")) > 0.0)

	var hero_hp_before: float = scene.campaign.system.hero.health
	var enemy_hp_before: float = float(enemy.get("health")) if enemy != null else 0.0
	for _step in range(40):
		scene.campaign.advance(0.05)
	var enemy_now: RefCounted = scene.campaign.system.enemy
	var damaged: bool = scene.campaign.system.hero.health < hero_hp_before
	if enemy_now != null and enemy_now != enemy:
		damaged = true
	elif enemy_now != null and float(enemy_now.get("health")) < enemy_hp_before:
		damaged = true
	_check("Бой продолжается после перехода", damaged or scene.campaign.status != STATUS_BATTLE)

	_click(scene.strike_button.get_global_rect().get_center())
	await process_frame
	_check("Круглая кнопка УДАР срабатывает", scene.campaign.get_cooldown_remaining("heavy_strike") > 0.0)

	_click(scene.equipment_button.get_global_rect().get_center())
	await process_frame
	_check("Нижнее меню открывает разделы", scene.active_tab == "inventory" and scene.inventory_panel.visible)
	var overlay: Control = scene.find_child("BattleOverlay", true, false) as Control
	_check("В разделе оверлей боя скрыт", overlay != null and not overlay.visible)

	print("Итого: %d проверок пройдено, %d провалено" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	for press in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = press
		event.position = point
		event.global_position = point
		viewport.push_input(event, true)


func _check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		print("  ✗ ", label)
