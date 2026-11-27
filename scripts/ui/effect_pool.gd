extends Node

# Переиспользуемые всплывающие подписи и короткие подсветки интерфейса.
# Вместо отдельного Label и Tween на каждый удар используется пул фиксированного
# размера; _process() активен только во время анимации и не нагружает простой кадр.

var canvas: Control
var config: Dictionary = {}
var labels: Array = []
var slots: Array = []
var flashes: Dictionary = {}
var full_effects: bool = true


func configure(target: Control, data: Dictionary) -> void:
	canvas = target
	config = data.duplicate(true)
	set_process(false)
	var capacity: int = clampi(int(config.get("capacity", 8)), 1, 32)
	for _index in range(capacity):
		var label: Label = Label.new()
		label.visible = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 10
		canvas.add_child(label)
		labels.append(label)
		slots.append({"active": false, "elapsed": 0.0, "start_y": 0.0, "color": Color.WHITE})


func set_full_effects(value: bool) -> void:
	full_effects = bool(value)
	if not full_effects:
		reset()


func spawn_text(text: String, near: Control, color: Color, font_size: int) -> void:
	if not full_effects or canvas == null or near == null or labels.is_empty():
		return
	var index: int = _take_slot()
	var label: Label = labels[index] as Label
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = Color(color.r, color.g, color.b, 1.0)
	var center: Vector2 = near.get_global_rect().get_center()
	var width: float = label.get_combined_minimum_size().x
	label.position = center - Vector2(width * 0.5, 18.0)
	label.visible = true
	var slot: Dictionary = {
		"active": true,
		"elapsed": 0.0,
		"start_y": label.position.y,
		"color": Color(color.r, color.g, color.b, 1.0),
	}
	slots[index] = slot
	set_process(true)


func flash(control: Control, color: Color) -> void:
	if not full_effects or control == null:
		return
	var tint: Color = Color(color.r, color.g, color.b, 1.0)
	flashes[control.get_instance_id()] = {
		"control": control,
		"color": tint,
		"elapsed": 0.0,
	}
	control.modulate = tint
	set_process(true)


func pulse(control: Control, color: Color) -> void:
	flash(control, color)


func _take_slot() -> int:
	for index in range(slots.size()):
		var slot: Dictionary = slots[index] as Dictionary
		if not bool(slot.get("active", false)):
			return index
	var oldest: int = 0
	var oldest_progress: float = -1.0
	for index in range(slots.size()):
		var slot: Dictionary = slots[index] as Dictionary
		var duration: float = maxf(0.01, float(config.get("label_duration_seconds", 0.55)))
		var progress: float = float(slot.get("elapsed", 0.0)) / duration
		if progress > oldest_progress:
			oldest = index
			oldest_progress = progress
	return oldest


func _process(delta: float) -> void:
	var active: bool = false
	var label_duration: float = maxf(0.01, float(config.get("label_duration_seconds", 0.55)))
	var rise: float = float(config.get("label_rise_pixels", 52.0))
	for index in range(slots.size()):
		var slot: Dictionary = slots[index] as Dictionary
		if not bool(slot.get("active", false)):
			continue
		var elapsed: float = float(slot.get("elapsed", 0.0)) + delta
		var progress: float = clampf(elapsed / label_duration, 0.0, 1.0)
		var label: Label = labels[index] as Label
		var tint: Color = slot.get("color", Color.WHITE) as Color
		label.position.y = float(slot.get("start_y", 0.0)) - rise * progress
		label.modulate = Color(tint.r, tint.g, tint.b, 1.0 - progress)
		slot["elapsed"] = elapsed
		if progress >= 1.0:
			slot["active"] = false
			label.visible = false
			label.modulate = Color.WHITE
		else:
			active = true
		slots[index] = slot
	var flash_duration: float = maxf(0.01, float(config.get("flash_duration_seconds", 0.28)))
	for key in flashes.keys():
		var state: Dictionary = flashes[key] as Dictionary
		var control: Control = state.get("control") as Control
		if not is_instance_valid(control):
			flashes.erase(key)
			continue
		var elapsed: float = float(state.get("elapsed", 0.0)) + delta
		var progress: float = clampf(elapsed / flash_duration, 0.0, 1.0)
		var tint: Color = state.get("color", Color.WHITE) as Color
		control.modulate = tint.lerp(Color.WHITE, progress)
		if progress >= 1.0:
			control.modulate = Color.WHITE
			flashes.erase(key)
		else:
			state["elapsed"] = elapsed
			flashes[key] = state
			active = true
	if not active:
		set_process(false)


func reset() -> void:
	for index in range(slots.size()):
		var slot: Dictionary = slots[index] as Dictionary
		slot["active"] = false
		slots[index] = slot
		var label: Label = labels[index] as Label
		label.visible = false
		label.modulate = Color.WHITE
	for key in flashes.keys():
		var state: Dictionary = flashes[key] as Dictionary
		var control: Control = state.get("control") as Control
		if is_instance_valid(control):
			control.modulate = Color.WHITE
	flashes.clear()
	set_process(false)


func active_count() -> int:
	var count: int = 0
	for item in slots:
		if bool((item as Dictionary).get("active", false)):
			count += 1
	return count


func active_flash_count() -> int:
	return flashes.size()


func pool_size() -> int:
	return labels.size()
