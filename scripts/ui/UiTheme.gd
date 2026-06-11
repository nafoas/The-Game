class_name UiTheme
extends Object
## Shared HL2-flavored UI styling for menu / pause / HUD / end screens.

const ORANGE := Color(1.0, 0.63, 0.12)
const ORANGE_DIM := Color(1.0, 0.63, 0.12, 0.75)
const TEXT_BRIGHT := Color(0.93, 0.93, 0.93)
const TEXT_DIM := Color(0.62, 0.62, 0.62)
const PANEL_BG := Color(0.02, 0.03, 0.02, 0.55)
const SHADOW := Color(0.0, 0.0, 0.0, 0.75)


static func panel_style(bg := PANEL_BG, radius := 5, margin_h := 18.0, margin_v := 8.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v + 2.0
	return style


## Big HL2-style title text: bold spacing, hard drop shadow.
static func style_title(label: Label, size: int, color := ORANGE) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("shadow_outline_size", 6)
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.spacing_glyph = 4
	fv.variation_embolden = 0.6
	label.add_theme_font_override("font", fv)


static func style_value_label(label: Label, size: int, color := ORANGE) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 4)
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.4
	label.add_theme_font_override("font", fv)


static func style_small_caps(label: Label, size: int = 12) -> void:
	label.text = label.text.to_upper()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", ORANGE_DIM)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.spacing_glyph = 2
	label.add_theme_font_override("font", fv)


## Menu list button with HL2 hover behavior: color shift + 8 px slide-in.
## Returns the wrapping MarginContainer to add to your VBox; the Button itself
## is the single child (use .get_child(0) or the returned dictionary).
static func make_menu_button(text: String, font_size: int, hover_sfx: Callable,
		click_sfx_and_action: Callable) -> Dictionary:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 0)

	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", TEXT_BRIGHT)
	btn.add_theme_color_override("font_hover_color", ORANGE)
	btn.add_theme_color_override("font_pressed_color", ORANGE)
	btn.add_theme_color_override("font_hover_pressed_color", ORANGE)
	btn.add_theme_color_override("font_focus_color", TEXT_BRIGHT)
	btn.add_theme_color_override("font_shadow_color", SHADOW)
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 2)
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.spacing_glyph = 2
	fv.variation_embolden = 0.3
	btn.add_theme_font_override("font", fv)
	wrap.add_child(btn)

	btn.mouse_entered.connect(func() -> void:
		hover_sfx.call()
		var tween := wrap.create_tween()
		tween.tween_method(Callable(UiTheme, "_set_wrap_margin").bind(wrap),
			float(wrap.get_theme_constant("margin_left")), 10.0, 0.12)
	)
	btn.mouse_exited.connect(func() -> void:
		var tween := wrap.create_tween()
		tween.tween_method(Callable(UiTheme, "_set_wrap_margin").bind(wrap),
			float(wrap.get_theme_constant("margin_left")), 0.0, 0.16)
	)
	btn.pressed.connect(func() -> void:
		click_sfx_and_action.call()
	)

	return {"wrap": wrap, "button": btn}


static func _set_wrap_margin(v: float, wrap: MarginContainer) -> void:
	if is_instance_valid(wrap):
		wrap.add_theme_constant_override("margin_left", int(v))


## Dark gradient backplate behind a left-hand menu column for readability.
static func add_menu_backplate(parent: CanvasLayer) -> void:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.82), Color(0, 0, 0, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(1, 0)
	gtex.width = 64
	gtex.height = 8

	var rect := TextureRect.new()
	rect.name = "MenuBackplate"
	rect.texture = gtex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.anchor_left = 0.0
	rect.anchor_right = 0.0
	rect.anchor_top = 0.0
	rect.anchor_bottom = 1.0
	rect.offset_right = 480.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	rect.z_index = -1
