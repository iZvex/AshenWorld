extends RefCounted

# Единая палитра и игровые стили тёмного фэнтези. Крупные карточки и высокие
# полосы заменены одной строкой здоровья; нижняя навигация, рамки и активные
# вкладки выделены так, чтобы структура экрана читалась с первого взгляда.

# Палитра брифа (§8): почти чёрный с фиолетовым оттенком фон, сливовые панели,
# состаренное золото для акцентов и рамок, тёмный красный для опасности и крови,
# фиолетовый для магии и тёплый светло-серый для основного текста.
const BACKGROUND: Color = Color("#100D16")
const PANEL: Color = Color("#211724")
const GOLD: Color = Color("#C58B43")
const CRIMSON: Color = Color("#8C263A")
const RUNE: Color = Color("#7545B8")
const PARCHMENT: Color = Color("#B8A7A0")
# Производные оттенки: вспышка угля для критов, кромка панелей, приглушённый текст,
# яркая заливка мини-шкал и «золото на тёмном» для крупных чисел.
const EMBER: Color = Color("#E08A3C")
const PANEL_BORDER: Color = Color("#4A3A58")
const MUTED: Color = Color("#8A7C86")
const STEEL: Color = Color("#6E8CA8")
const ENEMY_FILL: Color = Color("#C8464E")
const SHIELD_COLOR: Color = Color("#7545B8")
const HERO_COLOR: Color = Color("#C58B43")
const ENEMY_COLOR: Color = Color("#C8464E")


static func panel_style(background: Color = PANEL, border: Color = PANEL_BORDER) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = background
	box.set_border_width_all(1)
	box.border_color = border
	box.set_corner_radius_all(10)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


static func compact_panel_style() -> StyleBoxFlat:
	return panel_style(Color("#14101C"), PANEL_BORDER)


static func ornate_panel_style(background: Color = Color("#17121F"), border: Color = GOLD) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = background
	box.set_border_width_all(2)
	box.border_color = border
	box.set_corner_radius_all(14)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	box.shadow_size = 6
	return box


static func header_style() -> StyleBoxFlat:
	return ornate_panel_style(Color("#100C19"), Color("#8A6B3D"))


static func bottom_bar_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = hud_panel_style()
	box.set_corner_radius_all(12)
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


static func content_panel_style() -> StyleBoxFlat:
	return ornate_panel_style(Color(0.055, 0.04, 0.085, 0.88), Color("#8A6B3D"))


static func hud_panel_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = ornate_panel_style(Color(0.03, 0.022, 0.05, 0.84), Color("#8A6B3D"))
	box.set_corner_radius_all(12)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	box.shadow_size = 8
	return box


static func muted_panel_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = ornate_panel_style(Color(0.035, 0.028, 0.05, 0.72), PANEL_BORDER)
	box.set_corner_radius_all(10)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box


static func circle_button_style(background: Color = Color("#1B1020"), border: Color = GOLD) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = background
	box.set_border_width_all(3)
	box.border_color = border
	box.set_corner_radius_all(999)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	box.shadow_size = 10
	return box


static func portrait_frame_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = circle_button_style(Color(0.0, 0.0, 0.0, 0.0), GOLD)
	box.set_border_width_all(4)
	box.shadow_size = 8
	# Тёплое свечение вокруг портрета вместо жёсткой тени.
	box.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.28)
	return box


static func ring_texture(diameter: int, thickness: float, color: Color) -> ImageTexture:
	# Кольцо для кругового индикатора перезарядки: рисуется в памяти,
	# внешних картинок и шейдеров не требуется.
	var size: int = clampi(diameter, 8, 256)
	var image: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center: float = float(size - 1) / 2.0
	var outer: float = float(size) / 2.0 - 1.0
	var inner: float = maxf(1.0, outer - maxf(1.0, thickness))
	for y in range(size):
		for x in range(size):
			var dx: float = float(x) - center
			var dy: float = float(y) - center
			var distance: float = sqrt(dx * dx + dy * dy)
			if distance <= outer and distance >= inner:
				var edge: float = minf(outer - distance, distance - inner)
				var alpha: float = clampf(edge / 1.5, 0.0, 1.0)
				image.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))
	return ImageTexture.create_from_image(image)


static func slash_texture(width: int, height: int, color: Color) -> ImageTexture:
	# Дуга следа оружия: тонкий серп с яркой серединой и мягкими краями.
	# Рисуется в памяти, внешних картинок и шейдеров не требуется.
	var w: int = clampi(width, 8, 256)
	var h: int = clampi(height, 8, 128)
	var image: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center_y: float = float(h) / 2.0
	for x in range(w):
		var t: float = float(x) / float(maxi(1, w - 1))
		var bend: float = sin(PI * (t - 0.5))
		var curve_y: float = center_y + bend * float(h) * 0.22
		var taper: float = pow(sin(PI * t), 0.7)
		var half: float = maxf(0.5, taper * float(h) * 0.085)
		var glow: float = maxf(0.5, taper * float(h) * 0.2)
		var start_y: int = clampi(int(round(curve_y - glow)), 0, h - 1)
		var end_y: int = clampi(int(round(curve_y + glow)), 0, h - 1)
		for y in range(start_y, end_y + 1):
			var distance: float = absf(float(y) - curve_y)
			var alpha: float = 1.0
			if distance > half:
				alpha = clampf(1.0 - (distance - half) / maxf(0.6, glow - half), 0.0, 1.0) * 0.3
			else:
				alpha = clampf((half - distance) / 0.9, 0.0, 1.0)
			if alpha <= 0.01:
				continue
			image.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))
	return ImageTexture.create_from_image(image)


static func trail_arc_texture(radius: float, thickness: float, sweep_degrees: float,
		color: Color, resolution: float = 0.5) -> ImageTexture:
	# Росчерк взмаха: полоса по дуге вокруг кисти. Дуга симметрична оси +X,
	# края мягкие, поэтому след читается как движение, а не как заливка.
	var reach: float = maxf(16.0, radius + thickness)
	var step: float = clampf(resolution, 0.25, 1.0)
	var size: int = maxi(16, int(round(reach * 2.0 * step)))
	var image: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var mid: float = float(size) * 0.5
	var arc_radius: float = radius * step
	var half: float = maxf(1.0, thickness * 0.5 * step)
	var sweep: float = deg_to_rad(clampf(sweep_degrees, 8.0, 300.0))
	var taper: float = minf(sweep * 0.22, 0.5)
	for y in range(size):
		var dy: float = float(y) + 0.5 - mid
		for x in range(size):
			var dx: float = float(x) + 0.5 - mid
			var distance: float = sqrt(dx * dx + dy * dy)
			var offset: float = absf(distance - arc_radius)
			if offset >= half:
				continue
			var angle: float = absf(atan2(dy, dx))
			if angle > sweep * 0.5:
				continue
			var alpha: float = 1.0 - offset / half
			alpha = alpha * alpha
			var edge: float = clampf((sweep * 0.5 - angle) / maxf(0.001, taper), 0.0, 1.0)
			alpha *= edge
			if alpha <= 0.01:
				continue
			image.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))
	return ImageTexture.create_from_image(image)


static func slot_placeholder_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.05, 0.1, 0.72)
	box.set_border_width_all(2)
	box.border_color = Color(PANEL_BORDER.r, PANEL_BORDER.g, PANEL_BORDER.b, 0.55)
	box.set_corner_radius_all(999)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box


static func auto_button_style(active: bool) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.78, 0.53, 0.24, 0.92) if active else Color(0.09, 0.06, 0.13, 0.88)
	box.set_border_width_all(1)
	box.border_color = GOLD if active else Color(PANEL_BORDER.r, PANEL_BORDER.g, PANEL_BORDER.b, 0.75)
	box.set_corner_radius_all(12)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


static func ground_shadow_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.01, 0.04, 0.48)
	box.set_border_width_all(2)
	box.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.12)
	box.set_corner_radius_all(999)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	box.shadow_size = 10
	return box


static func battlefield_card_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	box.set_border_width_all(0)
	box.set_corner_radius_all(0)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box


static func enemy_bar_background() -> StyleBoxFlat:
	var box: StyleBoxFlat = bar_background()
	box.set_border_width_all(1)
	box.border_color = Color(0.0, 0.0, 0.0, 0.75)
	return box


static func enemy_bar_fill() -> StyleBoxFlat:
	var box: StyleBoxFlat = bar_fill(ENEMY_FILL)
	box.set_border_width_all(1)
	box.border_color = Color(1.0, 0.72, 0.6, 0.55)
	return box


static func level_badge_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.05, 0.12, 0.96)
	box.set_border_width_all(2)
	box.border_color = GOLD
	box.set_corner_radius_all(999)
	box.content_margin_left = 2
	box.content_margin_right = 2
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	box.shadow_size = 4
	return box


static func currency_pill_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.06, 0.13, 0.88)
	box.set_border_width_all(1)
	box.border_color = Color(PANEL_BORDER.r, PANEL_BORDER.g, PANEL_BORDER.b, 0.8)
	box.set_corner_radius_all(12)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


static func vitals_plate_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.08, 0.72)
	style.border_color = Color(PANEL_BORDER.r, PANEL_BORDER.g, PANEL_BORDER.b, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


static func nav_button_style(active: bool, pressed: bool = false) -> StyleBoxFlat:
	# Активная вкладка заливается золотом и получает мягкое свечение вокруг,
	# неактивная остаётся сливовой панелью с тонкой рамкой.
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if active:
		style.bg_color = GOLD.darkened(0.06) if pressed else GOLD
		style.border_color = Color(1.0, 0.87, 0.68, 0.95)
		style.set_border_width_all(2)
		style.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.42)
		style.shadow_size = 14
		style.shadow_offset = Vector2(0.0, 2.0)
	else:
		style.bg_color = Color(PANEL.r, PANEL.g, PANEL.b, 0.92)
		style.border_color = Color(PANEL_BORDER.r, PANEL_BORDER.g, PANEL_BORDER.b, 0.7)
		style.set_border_width_all(1)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		style.shadow_size = 4
	style.set_corner_radius_all(12)
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


static func nav_disabled_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = nav_button_style(false)
	style.bg_color = Color(PANEL.r, PANEL.g, PANEL.b, 0.55)
	style.border_color = Color(MUTED.r, MUTED.g, MUTED.b, 0.3)
	style.shadow_size = 0
	return style


static func quick_icon_style(active: bool) -> StyleBoxFlat:
	var background: Color = Color("#3B2418") if active else Color("#181120")
	var border: Color = GOLD if active else Color("#6E5538")
	var box: StyleBoxFlat = circle_button_style(background, border)
	box.set_border_width_all(4 if active else 2)
	box.shadow_size = 12 if active else 6
	return box


static func enemy_card_style(active: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.04, 0.07, 0.3) if active else Color(0.06, 0.03, 0.09, 0.12)
	style.border_color = Color(CRIMSON.r, CRIMSON.g, CRIMSON.b, 0.55) if active else Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(1 if active else 0)
	style.set_corner_radius_all(16)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


static func orb_style(active: bool = false, radius: int = 62) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.42, 0.16, 0.09, 0.92) if active else Color(0.10, 0.06, 0.12, 0.82)
	style.border_color = GOLD if active else PANEL_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


static func log_strip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.08, 0.72)
	style.border_color = Color(PANEL_BORDER.r, PANEL_BORDER.g, PANEL_BORDER.b, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


static func active_tab_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = button_style(Color("#C8893C"), GOLD)
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	return box


static func inactive_tab_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = button_style(Color("#241A30"), PANEL_BORDER)
	box.set_corner_radius_all(10)
	return box


static func button_style(background: Color, border: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = background
	box.set_border_width_all(1)
	box.border_color = border
	box.set_corner_radius_all(12)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


static func action_button_style() -> StyleBoxFlat:
	return button_style(Color("#4A2718"), GOLD)


static func bar_background() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color("#0D0A14")
	box.set_border_width_all(1)
	box.border_color = Color("#3A2A46")
	box.set_corner_radius_all(5)
	return box


static func bar_fill(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(5)
	return box


static func build_theme(config: Dictionary = {}) -> Theme:
	var fonts_value: Variant = config.get("fonts", {})
	var fonts: Dictionary = fonts_value as Dictionary if fonts_value is Dictionary else {}
	var default_size: int = clampi(int(fonts.get("default", 20)), 12, 48)
	var theme: Theme = Theme.new()
	theme.default_font_size = default_size
	theme.set_font_size("font_size", "Label", clampi(int(fonts.get("label", default_size)), 12, 48))
	theme.set_font_size("font_size", "Button", clampi(int(fonts.get("button", default_size)), 12, 48))
	theme.set_font_size("font_size", "OptionButton", clampi(int(fonts.get("option", default_size)), 12, 48))
	theme.set_font_size("font_size", "ItemList", clampi(int(fonts.get("item_list", default_size)), 12, 48))
	theme.set_color("font_color", "Label", PARCHMENT)
	theme.set_color("font_color", "Button", PARCHMENT)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", MUTED)
	# Тёмный ореол вокруг букв: подписи читаются и поверх яркой арены, и в тёмных панелях.
	for type_name in ["Label", "Button", "OptionButton"]:
		theme.set_color("font_shadow_color", type_name, Color(0.04, 0.03, 0.06, 0.85))
		theme.set_constant("shadow_offset_x", type_name, 0)
		theme.set_constant("shadow_offset_y", type_name, 0)
		theme.set_constant("shadow_outline_size", type_name, 2)
	theme.set_stylebox("panel", "PanelContainer", hud_panel_style())
	theme.set_stylebox("normal", "Button", button_style(Color("#241A30"), EMBER))
	theme.set_stylebox("hover", "Button", button_style(Color("#33203A"), GOLD))
	theme.set_stylebox("pressed", "Button", button_style(Color("#4A2718"), GOLD))
	theme.set_stylebox("disabled", "Button", button_style(Color("#191321"), PANEL_BORDER))
	theme.set_stylebox("background", "ProgressBar", bar_background())
	theme.set_stylebox("fill", "ProgressBar", bar_fill(HERO_COLOR))
	return theme
