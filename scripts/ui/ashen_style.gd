extends RefCounted

# Единая палитра и компактные стили тёмного фэнтези. Крупные карточки и
# высокие полосы заменены одной строкой здоровья и небольшими панелями.

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


static func build_theme() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", PARCHMENT)
	theme.set_color("font_color", "Button", PARCHMENT)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_stylebox("panel", "PanelContainer", compact_panel_style())
	theme.set_stylebox("normal", "Button", button_style(Color("#241A30"), EMBER))
	theme.set_stylebox("hover", "Button", button_style(Color("#33203A"), GOLD))
	theme.set_stylebox("pressed", "Button", button_style(Color("#4A2718"), GOLD))
	theme.set_stylebox("disabled", "Button", button_style(Color("#191321"), PANEL_BORDER))
	theme.set_stylebox("background", "ProgressBar", bar_background())
	theme.set_stylebox("fill", "ProgressBar", bar_fill(HERO_COLOR))
	return theme
