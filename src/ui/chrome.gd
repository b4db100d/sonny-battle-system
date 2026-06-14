class_name Chrome
extends RefCounted
## Shared UI chrome helpers for gradients, panels, and buttons.


static func gradient_rect(
		colors: Array,
		from: Vector2 = Vector2(0.5, 0.0),
		to: Vector2 = Vector2(0.5, 1.0),
		offsets: Array = []) -> TextureRect:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	if offsets.size() == colors.size():
		gradient.offsets = PackedFloat32Array(offsets)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = from
	texture.fill_to = to

	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func panel_style(
		fill: Color,
		border: Color,
		radius: int = 20,
		border_width: int = 2,
		padding: int = 16,
		shadow_alpha: float = 0.24) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border_width)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	style.shadow_color = Color(0, 0, 0, shadow_alpha)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	return style


static func apply_button(
		button: Button,
		accent: Color,
		font_size: int = 22,
		min_size: Vector2 = Vector2.ZERO,
		subtle: bool = false) -> void:
	var frame := accent.lightened(0.35)
	var base := accent.darkened(0.58).lerp(Color("0c1218"), 0.45 if subtle else 0.22)
	var hover := base.lightened(0.1)
	var pressed := base.darkened(0.12)
	var disabled := base.darkened(0.28)

	button.custom_minimum_size = min_size
	button.add_theme_stylebox_override("normal", panel_style(base, frame, 18, 2, 14, 0.28))
	button.add_theme_stylebox_override("hover", panel_style(hover, frame.lightened(0.18), 18, 2, 14, 0.36))
	button.add_theme_stylebox_override("pressed", panel_style(pressed, frame, 18, 2, 14, 0.18))
	button.add_theme_stylebox_override("disabled", panel_style(disabled, frame.darkened(0.45), 18, 1, 14, 0.12))
	button.add_theme_stylebox_override("focus", panel_style(hover, frame.lightened(0.28), 20, 2, 14, 0.4))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("edf4ff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("8a99aa"))
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	button.add_theme_constant_override("outline_size", 4)


static func apply_label(label: Label, font_size: int, color: Color, outline_size: int = 4) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("outline_size", outline_size)
