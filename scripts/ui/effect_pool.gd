extends Node

# Переиспользуемые всплывающие подписи и короткие подсветки интерфейса.
# Вместо отдельного Label и Tween на каждый удар используется пул фиксированного
# размера; _process() активен только во время анимации и не нагружает простой кадр.

const AshenStyle = preload("res://scripts/ui/ashen_style.gd")

var canvas: Control
var config: Dictionary = {}
var labels: Array = []
var slots: Array = []
var flashes: Dictionary = {}
var sparks: Array = []
var slash_nodes: Array = []
var punches: Dictionary = {}
var lunges: Dictionary = {}
var fades: Dictionary = {}
var full_effects: bool = true


func configure(target: Control, data: Dictionary) -> void:
	canvas = target
	config = data.duplicate(true)
	set_process(false)
	var capacity: int = clampi(int(config.get("capacity", 8)), 1, 32)
	var default_font_size: int = clampi(int(config.get("label_font_size", 24)), 12, 48)
	for _index in range(capacity):
		var label: Label = Label.new()
		label.visible = false
		label.add_theme_font_size_override("font_size", default_font_size)
		# Тёмная обводка: числа читаются и поверх тёмной мантии босса, и поверх портала.
		label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.06, 0.92))
		label.add_theme_constant_override("outline_size", 5)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 10
		canvas.add_child(label)
		labels.append(label)
		slots.append({"active": false, "elapsed": 0.0, "start_y": 0.0, "color": Color.WHITE})
	_build_fx_pools()


func _build_fx_pools() -> void:
	var spark_capacity: int = clampi(int(config.get("spark_capacity", 26)), 1, 64)
	var spark_size: float = maxf(2.0, float(config.get("spark_size", 4)))
	for _index in range(spark_capacity):
		var spark: ColorRect = ColorRect.new()
		spark.visible = false
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.z_index = 9
		spark.size = Vector2(spark_size, spark_size)
		spark.pivot_offset = spark.size * 0.5
		canvas.add_child(spark)
		sparks.append({"node": spark, "active": false, "elapsed": 0.0, "velocity": Vector2.ZERO})
	var slash_capacity: int = clampi(int(config.get("slash_capacity", 3)), 1, 8)
	var slash_length: int = int(maxf(24.0, float(config.get("slash_length", 104.0))))
	var slash_height: int = int(maxf(12.0, float(config.get("slash_height", 46.0))))
	var slash_texture: ImageTexture = AshenStyle.slash_texture(slash_length, slash_height, AshenStyle.PARCHMENT)
	for _index in range(slash_capacity):
		var slash: TextureRect = TextureRect.new()
		slash.visible = false
		slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slash.z_index = 9
		slash.texture = slash_texture
		slash.size = Vector2(slash_length, slash_height)
		slash.pivot_offset = slash.size * 0.5
		slash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slash.stretch_mode = TextureRect.STRETCH_SCALE
		canvas.add_child(slash)
		slash_nodes.append({"node": slash, "active": false, "elapsed": 0.0})


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
	var area: Rect2 = near.get_global_rect()
	var span: Vector2 = label.get_combined_minimum_size()
	var width: float = maxf(span.x, 12.0)
	var line_height: float = maxf(span.y, float(font_size) * 1.2) + float(config.get("label_lane_gap", 4.0))
	# У невысоких блоков (карточка врага, шкала героя) подпись встаёт над блоком,
	# чтобы не закрывать имя и полосу здоровья; у большой арены — внутри верхней части.
	var inside_height: float = float(config.get("label_inside_anchor_height", 220.0))
	# Арена и высокие карточки: число всплывает у корпуса фигуры, ниже строки с именем.
	# Невысокие блоки (шкала героя): подпись встаёт над блоком, не закрывая цифры здоровья.
	var base_y: float = area.position.y + area.size.y * 0.62
	if area.size.y < inside_height:
		base_y = area.position.y - line_height * 0.6
	var center_x: float = area.get_center().x
	var placement: Vector2 = _free_spot(center_x, base_y, width, line_height, index)
	label.position = placement
	label.visible = true
	var slot: Dictionary = {
		"active": true,
		"elapsed": 0.0,
		"start_y": label.position.y,
		"start_x": label.position.x,
		"color": Color(color.r, color.g, color.b, 1.0),
	}
	slots[index] = slot
	set_process(true)


func _free_spot(center_x: float, base_y: float, width: float, height: float, skip: int) -> Vector2:
	# Свободное место под подпись: если точка занята другой живой подписью,
	# строка поднимается выше. Так одновременные числа урона, навык и щит
	# видны по отдельности, а не наезжают друг на друга.
	var step: float = height + 2.0
	var best: Vector2 = Vector2(center_x - width * 0.5, base_y)
	var best_overlap: float = 1e12
	for row in range(6):
		var candidate: Vector2 = Vector2(center_x - width * 0.5, base_y - step * row)
		var rect: Rect2 = Rect2(candidate, Vector2(width, height))
		var overlap: float = 0.0
		for index in range(labels.size()):
			if index == skip:
				continue
			var slot: Dictionary = slots[index] as Dictionary
			if not bool(slot.get("active", false)):
				continue
			var other: Label = labels[index] as Label
			var other_span: Vector2 = other.get_combined_minimum_size()
			var other_rect: Rect2 = Rect2(other.position, Vector2(
				maxf(other.size.x, other_span.x), maxf(other.size.y, other_span.y)))
			if rect.intersects(other_rect.grow(2.0)):
				overlap += rect.intersection(other_rect).get_area()
		if overlap <= 0.0:
			return candidate
		if overlap < best_overlap:
			best_overlap = overlap
			best = candidate
	return best


func flash(control: Control, color: Color) -> void:
	if not full_effects or control == null:
		return
	var tint: Color = Color(color.r, color.g, color.b, 1.0)
	flashes[control.get_instance_id()] = {
		"control": control,
		"color": tint,
		"base": control.modulate,
		"elapsed": 0.0,
	}
	control.modulate = tint
	set_process(true)


func pulse(control: Control, _color: Color = Color.WHITE) -> void:
	# Нажатие интерфейсной кнопки — короткое сжатие. Цвет элемента не подменяем,
	# иначе перебивается свечение активной вкладки и состояния кнопок навыков.
	punch(control, float(config.get("press_scale", 0.045)))


func spawn_sparks(center: Vector2, color: Color, count: int = 0, critical: bool = false) -> void:
	if not full_effects or canvas == null or sparks.is_empty():
		return
	var amount: int = count if count > 0 else int(config.get("spark_count_per_hit", 5))
	amount = maxi(1, amount + (2 if critical else 0))
	var speed: float = maxf(20.0, float(config.get("spark_speed", 210.0)))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for _index in range(amount):
		var slot: Dictionary = _take_spark_slot()
		var spark: ColorRect = slot.get("node") as ColorRect
		if spark == null:
			return
		var spread: float = rng.randf_range(-PI, 0.0)
		var length: float = speed * rng.randf_range(0.45, 1.0)
		spark.position = center - spark.size * 0.5
		spark.color = Color(color.r, color.g, color.b, 0.95)
		spark.modulate = Color.WHITE
		spark.visible = true
		spark.scale = Vector2.ONE
		slot["active"] = true
		slot["elapsed"] = 0.0
		slot["velocity"] = Vector2(cos(spread), sin(spread)) * length
	set_process(true)


func spawn_slash(center: Vector2, color: Color, angle: float = -0.6) -> void:
	if not full_effects or canvas == null or slash_nodes.is_empty():
		return
	var slot: Dictionary = _take_slash_slot()
	var slash: TextureRect = slot.get("node") as TextureRect
	if slash == null:
		return
	slash.position = center - slash.size * 0.5
	slash.rotation = angle
	slash.modulate = Color(color.r, color.g, color.b, 1.0)
	slash.scale = Vector2(0.95, 0.95)
	slash.visible = true
	slot["active"] = true
	slot["elapsed"] = 0.0
	set_process(true)


func punch(control: Control, amount: float = 0.0) -> void:
	# Короткое «вздрагивание» фигуры при попадании: масштаб дышит, позиция не меняется,
	# поэтому вёрстка арены не ломается.
	if not full_effects or control == null:
		return
	var strength: float = amount if amount > 0.0 else float(config.get("punch_amount", 0.055))
	control.pivot_offset = control.size * 0.5
	var key: int = control.get_instance_id()
	var state: Dictionary = punches.get(key, {
		"control": control,
		"base": control.scale,
		"elapsed": 0.0,
	})
	state["elapsed"] = 0.0
	punches[key] = state
	control.scale = Vector2(1.0 + strength, 1.0 - strength * 0.5)
	set_process(true)


func lunge(control: Control, offset: Vector2, lean: float = 0.0, duration: float = 0.0) -> void:
	# Шаг атакующего: фигура подаётся вперёд и возвращается на место.
	# Движение плавное (синус), длительность и амплитуда берутся из balance.json.
	if not full_effects or control == null:
		return
	var life: float = duration if duration > 0.0 else float(config.get("lunge_seconds", 0.24))
	var key: int = control.get_instance_id()
	var state: Dictionary = lunges.get(key, {})
	if state.is_empty():
		state = {"control": control, "base": control.position}
	state["offset"] = offset
	state["lean"] = lean
	state["life"] = maxf(0.05, life)
	state["elapsed"] = 0.0
	lunges[key] = state
	# Опора под ногами фигуры: наклон читается как замах, а не как падение.
	control.pivot_offset = Vector2(control.size.x * 0.5, control.size.y)
	set_process(true)


func cancel_lunges() -> void:
	for key in lunges.keys():
		var state: Dictionary = lunges[key] as Dictionary
		var control: Control = state.get("control") as Control
		if is_instance_valid(control):
			control.position = state.get("base", control.position) as Vector2
			control.rotation = 0.0
	lunges.clear()


func lunge_count() -> int:
	return lunges.size()


func fade_to(control: Control, tint: Color) -> void:
	# Спокойное затухание поверженной фигуры: остаётся серый силуэт, а не пустое место.
	if control == null:
		return
	var key: int = control.get_instance_id()
	fades[key] = {
		"control": control,
		"tint": tint,
		"base": control.modulate,
		"elapsed": 0.0,
	}
	if not full_effects:
		control.modulate = tint
		fades.erase(key)
		return
	set_process(true)


func _take_spark_slot() -> Dictionary:
	for slot_value in sparks:
		var slot: Dictionary = slot_value as Dictionary
		if not bool(slot.get("active", false)):
			return slot
	return sparks[0] as Dictionary


func _take_slash_slot() -> Dictionary:
	for slot_value in slash_nodes:
		var slot: Dictionary = slot_value as Dictionary
		if not bool(slot.get("active", false)):
			return slot
	return slash_nodes[0] as Dictionary


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
		var base: Color = state.get("base", Color.WHITE) as Color
		control.modulate = tint.lerp(base, progress)
		if progress >= 1.0:
			control.modulate = base
			flashes.erase(key)
		else:
			state["elapsed"] = elapsed
			flashes[key] = state
			active = true
	active = _tick_sparks(delta) or active
	active = _tick_slashes(delta) or active
	active = _tick_punches(delta) or active
	active = _tick_lunges(delta) or active
	active = _tick_fades(delta) or active
	if not active:
		set_process(false)


func _tick_sparks(delta: float) -> bool:
	var active: bool = false
	var life: float = maxf(0.05, float(config.get("spark_life_seconds", 0.38)))
	var gravity: float = float(config.get("spark_gravity", 360.0))
	for slot_value in sparks:
		var slot: Dictionary = slot_value as Dictionary
		if not bool(slot.get("active", false)):
			continue
		var spark: ColorRect = slot.get("node") as ColorRect
		var elapsed: float = float(slot.get("elapsed", 0.0)) + delta
		var progress: float = clampf(elapsed / life, 0.0, 1.0)
		var velocity: Vector2 = slot.get("velocity", Vector2.ZERO) as Vector2
		velocity.y += gravity * delta
		spark.position += velocity * delta
		spark.modulate = Color(1.0, 1.0, 1.0, 1.0 - progress)
		spark.scale = Vector2(1.0, 1.0) * (1.0 - progress * 0.5)
		slot["elapsed"] = elapsed
		slot["velocity"] = velocity
		if progress >= 1.0:
			slot["active"] = false
			spark.visible = false
			spark.modulate = Color.WHITE
		else:
			active = true
	return active


func _tick_slashes(delta: float) -> bool:
	var active: bool = false
	var life: float = maxf(0.05, float(config.get("slash_life_seconds", 0.18)))
	for slot_value in slash_nodes:
		var slot: Dictionary = slot_value as Dictionary
		if not bool(slot.get("active", false)):
			continue
		var slash: TextureRect = slot.get("node") as TextureRect
		var elapsed: float = float(slot.get("elapsed", 0.0)) + delta
		var progress: float = clampf(elapsed / life, 0.0, 1.0)
		slash.modulate.a = 1.0 - progress
		slash.scale = Vector2.ONE * (0.95 + 0.3 * progress)
		slot["elapsed"] = elapsed
		if progress >= 1.0:
			slot["active"] = false
			slash.visible = false
			slash.modulate = Color.WHITE
		else:
			active = true
	return active


func _tick_punches(delta: float) -> bool:
	var active: bool = false
	var life: float = maxf(0.03, float(config.get("punch_life_seconds", 0.18)))
	for key in punches.keys():
		var state: Dictionary = punches[key] as Dictionary
		var control: Control = state.get("control") as Control
		if not is_instance_valid(control):
			punches.erase(key)
			continue
		var elapsed: float = float(state.get("elapsed", 0.0)) + delta
		var progress: float = clampf(elapsed / life, 0.0, 1.0)
		var base: Vector2 = state.get("base", Vector2.ONE) as Vector2
		var amount: float = float(config.get("punch_amount", 0.055))
		var sway: float = sin(progress * PI) * amount
		control.scale = Vector2(base.x * (1.0 + sway), base.y * (1.0 - sway * 0.5))
		if progress >= 1.0:
			control.scale = base
			punches.erase(key)
		else:
			state["elapsed"] = elapsed
			punches[key] = state
			active = true
	return active


func _tick_lunges(delta: float) -> bool:
	var active: bool = false
	for key in lunges.keys():
		var state: Dictionary = lunges[key] as Dictionary
		var control: Control = state.get("control") as Control
		if not is_instance_valid(control):
			lunges.erase(key)
			continue
		var elapsed: float = float(state.get("elapsed", 0.0)) + delta
		var life: float = maxf(0.05, float(state.get("life", 0.24)))
		var progress: float = clampf(elapsed / life, 0.0, 1.0)
		var base: Vector2 = state.get("base", Vector2.ZERO) as Vector2
		var offset: Vector2 = state.get("offset", Vector2.ZERO) as Vector2
		var lean: float = float(state.get("lean", 0.0))
		var step: float = sin(progress * PI)
		control.position = base + offset * step
		control.rotation = lean * step
		if progress >= 1.0:
			control.position = base
			control.rotation = 0.0
			lunges.erase(key)
			# Карточки врагов стоят в контейнере: просим его пересобрать ряды,
			# чтобы после шага не осталось ручного смещения.
			var parent: Node = control.get_parent()
			if parent is Container:
				(parent as Container).queue_sort()
		else:
			state["elapsed"] = elapsed
			lunges[key] = state
			active = true
	return active


func _tick_fades(delta: float) -> bool:
	var active: bool = false
	var life: float = maxf(0.05, float(config.get("death_fade_seconds", 0.5)))
	for key in fades.keys():
		var state: Dictionary = fades[key] as Dictionary
		var control: Control = state.get("control") as Control
		if not is_instance_valid(control):
			fades.erase(key)
			continue
		var elapsed: float = float(state.get("elapsed", 0.0)) + delta
		var progress: float = clampf(elapsed / life, 0.0, 1.0)
		var base: Color = state.get("base", Color.WHITE) as Color
		var tint: Color = state.get("tint", Color(0.42, 0.35, 0.44, 0.5)) as Color
		control.modulate = base.lerp(tint, progress)
		if progress >= 1.0:
			control.modulate = tint
			fades.erase(key)
		else:
			state["elapsed"] = elapsed
			fades[key] = state
			active = true
	return active


func spark_count() -> int:
	var count: int = 0
	for slot_value in sparks:
		if bool((slot_value as Dictionary).get("active", false)):
			count += 1
	return count


func slash_count() -> int:
	var count: int = 0
	for slot_value in slash_nodes:
		if bool((slot_value as Dictionary).get("active", false)):
			count += 1
	return count


func fade_count() -> int:
	return fades.size()


func spark_pool_size() -> int:
	return sparks.size()


func slash_pool_size() -> int:
	return slash_nodes.size()


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
	for slot_value in sparks:
		var slot: Dictionary = slot_value as Dictionary
		slot["active"] = false
		var spark: ColorRect = slot.get("node") as ColorRect
		if spark != null:
			spark.visible = false
			spark.modulate = Color.WHITE
	for slot_value in slash_nodes:
		var slot: Dictionary = slot_value as Dictionary
		slot["active"] = false
		var slash: TextureRect = slot.get("node") as TextureRect
		if slash != null:
			slash.visible = false
			slash.modulate = Color.WHITE
	for key in punches.keys():
		var state: Dictionary = punches[key] as Dictionary
		var control: Control = state.get("control") as Control
		if is_instance_valid(control):
			control.scale = state.get("base", Vector2.ONE) as Vector2
	punches.clear()
	for key in fades.keys():
		var state: Dictionary = fades[key] as Dictionary
		var control: Control = state.get("control") as Control
		if is_instance_valid(control):
			control.modulate = state.get("base", Color.WHITE) as Color
	fades.clear()
	cancel_lunges()
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
