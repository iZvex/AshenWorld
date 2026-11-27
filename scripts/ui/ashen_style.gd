extends RefCounted

# Единая палитра и стили тёмного фэнтези. Цвета, рамки и скругления задаются
# здесь, чтобы узлы сцены не дублировали настройки оформления.

const BACKGROUND: Color = Color("#0B0910")
const PANEL: Color = Color("#17121F")
const PANEL_BORDER: Color = Color("#4A3A58")
const EMBER: Color = Color("#E08A3C")
const GOLD: Color = Color("#F4C98A")
const RUNE: Color = Color("#B49AC6")
const PARCHMENT: Color = Color("#E6DCCB")
const MUTED: Color = Color("#9A8CA3")
const CRIMSON: Color = Color("#A63D40")
const STEEL: Color = Color("#6E8CA8")
const SHIELD_COLOR: Color = Color("#B49AC6")
const HERO_COLOR: Color = Color("#6E8CA8")
const ENEMY_COLOR: Color = Color("#A63D40")


static func panel_style(background: Color = PANEL, border: Color = PANEL_BORDER) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = background
	box.set_border_width_all(2)
	box.border_color = border
	box.set_corner_radius_all(14)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	return box


static func button_style(background: Color, border: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = background
	box.set_border_width_all(2)
	box.border_color = border
	box.set_corner_radius_all(16)
	box.content_margin_top = 20
	box.content_margin_bottom = 20
	return box


static func bar_background() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color("#0D0A14")
	box.set_border_width_all(1)
	box.border_color = Color("#3A2A46")
	box.set_corner_radius_all(9)
	return box


static func bar_fill(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(9)
	return box


static func build_theme() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 24
	theme.set_color("font_color", "Label", PARCHMENT)
	theme.set_color("font_color", "Button", PARCHMENT)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("normal", "Button", button_style(Color("#241A30"), EMBER))
	theme.set_stylebox("hover", "Button", button_style(Color("#33203A"), GOLD))
	theme.set_stylebox("pressed", "Button", button_style(Color("#4A2718"), GOLD))
	theme.set_stylebox("disabled", "Button", button_style(Color("#191321"), PANEL_BORDER))
	theme.set_stylebox("background", "ProgressBar", bar_background())
	theme.set_stylebox("fill", "ProgressBar", bar_fill(HERO_COLOR))
	return theme
