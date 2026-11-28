extends SceneTree

var vp: SubViewport

func _initialize() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(720, 1280)
	vp.gui_disable_input = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	vp.add_child(scene)
	for i in range(4):
		await process_frame
	var btn: Button = scene.action_button
	btn.pressed.connect(func(): print("СИГНАЛ pressed от кнопки этапа"))
	print("кнопка этапа rect=", btn.get_global_rect(), " filter=", btn.mouse_filter, " overlay visible=", scene.battle_overlay.visible)
	_click(vp, btn.get_global_rect().get_center())
	var motion := InputEventMouseMotion.new()
	motion.position = btn.get_global_rect().get_center()
	motion.global_position = motion.position
	vp.push_input(motion, true)
	await process_frame
	print("наведение=", vp.gui_get_hovered_control())
	await process_frame
	print("после клика этап=", scene.campaign.stage_index, " статус=", scene.campaign.status)
	var strike: Button = scene.strike_button
	_click(vp, strike.get_global_rect().get_center())
	await process_frame
	print("после клика по УДАР откат=", scene.campaign.get_cooldown_remaining("heavy_strike"))
	var tab: Button = scene.equipment_button
	_click(vp, tab.get_global_rect().get_center())
	await process_frame
	print("после клика по вкладке active_tab=", scene.active_tab)
	var inventory_target: Button = scene.find_child("EquipButton", true, false) as Button
	if inventory_target != null:
		var motion2 := InputEventMouseMotion.new()
		motion2.position = inventory_target.get_global_rect().get_center()
		motion2.global_position = motion2.position
		vp.push_input(motion2, true)
		await process_frame
		print("наведение в инвентаре=", vp.gui_get_hovered_control(), " ожидалось ", inventory_target.name)
	quit()

func _click(target: SubViewport, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	target.push_input(motion, true)
	for press in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = press
		ev.position = point
		ev.global_position = point
		target.push_input(ev, true)
