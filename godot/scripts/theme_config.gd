extends Node

const BG_COLOR := Color(0.1, 0.09, 0.15)
const SURFACE_COLOR := Color(0.15, 0.14, 0.21)
const SURFACE_LIGHT := Color(0.19, 0.18, 0.27)
const PRIMARY := Color(0.49, 0.36, 0.99)
const PRIMARY_DARK := Color(0.35, 0.25, 0.75)
const TEXT_COLOR := Color(0.91, 0.9, 0.94)
const TEXT_MUTED := Color(0.6, 0.58, 0.72)
const SUCCESS := Color(0.3, 0.69, 0.31)
const ERROR := Color(1.0, 0.34, 0.34)
const GOLD := Color(1.0, 0.84, 0.0)
const SILVER := Color(0.75, 0.75, 0.75)
const BRONZE := Color(0.8, 0.5, 0.2)

const FONT_TITLE := 64
const FONT_HEADING := 40
const FONT_SUBHEADING := 28
const FONT_BODY := 22
const FONT_SMALL := 18
const FONT_EMOJI := 80
const FONT_CODE := 72


static func style_label(label: Label, size: int, color: Color = TEXT_COLOR, bold: bool = false) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


static func make_panel(parent: Control, color: Color = SURFACE_COLOR) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


static func fade_in(node: Control, duration: float = 0.4, delay: float = 0.0) -> void:
	node.modulate.a = 0.0
	var tween := node.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(node, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT)


static func slide_in_from_bottom(node: Control, duration: float = 0.5, delay: float = 0.0) -> void:
	var target_y := node.position.y
	node.position.y += 60.0
	node.modulate.a = 0.0
	var tween := node.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(node, "position:y", target_y, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "modulate:a", 1.0, duration * 0.6).set_ease(Tween.EASE_OUT)


static func pulse(node: Control, scale: float = 1.08, duration: float = 0.8) -> void:
	var tween := node.create_tween().set_loops()
	tween.tween_property(node, "scale", Vector2(scale, scale), duration / 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "scale", Vector2.ONE, duration / 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
