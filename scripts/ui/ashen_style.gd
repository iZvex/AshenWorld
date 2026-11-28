extends RefCounted

# Единая палитра и игровые стили тёмного фэнтези. Крупные карточки и высокие
# полосы заменены одной строкой здоровья; нижняя навигация, рамки и активные
# вкладки выделены так, чтобы структура экрана читалась с первого взгляда.

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
	box.shadow_size = 6
	return box


static func quick_icon_style(active: bool) -> StyleBoxFlat:
	var background: Color = Color("#3B2418") if active else Color("#181120")
	var border: Color = GOLD if active else Color("#6E5538")
	var box: StyleBoxFlat = circle_button_style(background, border)
	box.set_border_width_all(4 if active else 2)
	box.shadow_size = 12 if active else 6
	return box


static func enemy_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.03, 0.09, 0.28)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
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
	theme.set_stylebox("panel", "PanelContainer", hud_panel_style())
	theme.set_stylebox("normal", "Button", button_style(Color("#241A30"), EMBER))
	theme.set_stylebox("hover", "Button", button_style(Color("#33203A"), GOLD))
	theme.set_stylebox("pressed", "Button", button_style(Color("#4A2718"), GOLD))
	theme.set_stylebox("disabled", "Button", button_style(Color("#191321"), PANEL_BORDER))
	theme.set_stylebox("background", "ProgressBar", bar_background())
	theme.set_stylebox("fill", "ProgressBar", bar_fill(HERO_COLOR))
	return theme
