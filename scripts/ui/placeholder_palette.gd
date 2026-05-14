class_name PlaceholderPalette
extends RefCounted

const COLOR_PAGE_BG := Color("111827")
const COLOR_PANEL_BG := Color("1f2937")
const COLOR_PANEL_BORDER := Color("334155")
const COLOR_TEXT_PRIMARY := Color("f8fafc")
const COLOR_TEXT_MUTED := Color("cbd5e1")
const COLOR_OVERLAY_SHADE := Color(0.02, 0.03, 0.08, 0.72)
const COLOR_SAFE := Color("14b8a6")
const COLOR_WARNING := Color("f59e0b")
const COLOR_DANGER := Color("ef4444")
const COLOR_SUCCESS := Color("22c55e")
const COLOR_BUTTON_PRIMARY := Color("0f766e")
const COLOR_BUTTON_SECONDARY := Color("334155")
const COLOR_ACTIVE_TINT := Color(0.96, 0.62, 0.04, 0.16)
const COLOR_DAMAGE_FLASH := Color(0.94, 0.27, 0.27, 0.28)

const BORDER_WIDTH := 2
const CORNER_RADIUS := 12


static func make_panel_style(
	bg_color: Color = COLOR_PANEL_BG, border_color: Color = COLOR_PANEL_BORDER
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(BORDER_WIDTH)
	style.set_corner_radius_all(CORNER_RADIUS)
	return style


static func make_button_style(
	bg_color: Color, border_color: Color = COLOR_PANEL_BORDER
) -> StyleBoxFlat:
	var style := make_panel_style(bg_color, border_color)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


static func apply_page_background(node: ColorRect) -> void:
	node.color = COLOR_PAGE_BG


static func apply_panel(
	panel: PanelContainer,
	border_color: Color = COLOR_PANEL_BORDER,
	bg_color: Color = COLOR_PANEL_BG
) -> void:
	panel.add_theme_stylebox_override("panel", make_panel_style(bg_color, border_color))


static func apply_card(panel: PanelContainer, border_color: Color = COLOR_PANEL_BORDER) -> void:
	apply_panel(panel, border_color, COLOR_PANEL_BG)


static func apply_primary_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", make_button_style(COLOR_BUTTON_PRIMARY))
	button.add_theme_stylebox_override(
		"hover", make_button_style(COLOR_BUTTON_PRIMARY.lightened(0.08))
	)
	button.add_theme_stylebox_override(
		"pressed", make_button_style(COLOR_BUTTON_PRIMARY.darkened(0.08))
	)
	button.add_theme_stylebox_override("focus", make_button_style(COLOR_BUTTON_PRIMARY, COLOR_SAFE))
	button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)


static func apply_secondary_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", make_button_style(COLOR_BUTTON_SECONDARY))
	button.add_theme_stylebox_override(
		"hover", make_button_style(COLOR_BUTTON_SECONDARY.lightened(0.08))
	)
	button.add_theme_stylebox_override(
		"pressed", make_button_style(COLOR_BUTTON_SECONDARY.darkened(0.08))
	)
	button.add_theme_stylebox_override(
		"focus", make_button_style(COLOR_BUTTON_SECONDARY, COLOR_WARNING)
	)
	button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)


static func apply_input(line_edit: LineEdit) -> void:
	line_edit.add_theme_stylebox_override(
		"normal", make_panel_style(Color("0f172a"), COLOR_PANEL_BORDER)
	)
	line_edit.add_theme_stylebox_override("focus", make_panel_style(Color("0f172a"), COLOR_SAFE))
	line_edit.add_theme_stylebox_override(
		"read_only", make_panel_style(Color("0f172a"), COLOR_PANEL_BORDER)
	)
	line_edit.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	line_edit.add_theme_color_override("font_placeholder_color", COLOR_TEXT_MUTED)


static func apply_title(label: Label, accent_color: Color = COLOR_TEXT_PRIMARY) -> void:
	label.add_theme_color_override("font_color", accent_color)
	label.add_theme_font_size_override("font_size", 30)


static func apply_body(label: Label) -> void:
	label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	label.add_theme_font_size_override("font_size", 18)


static func apply_muted_body(label: Label) -> void:
	label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	label.add_theme_font_size_override("font_size", 16)


static func color_for_state(state_name: String) -> Color:
	match state_name:
		"safe":
			return COLOR_SAFE
		"warning":
			return COLOR_WARNING
		"danger":
			return COLOR_DANGER
		"success":
			return COLOR_SUCCESS
		_:
			return COLOR_TEXT_MUTED
