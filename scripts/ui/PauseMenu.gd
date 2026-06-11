extends CanvasLayer

## In-game pause overlay (instanced by GameManager on Esc).
## Process mode ALWAYS so it works while the tree is paused.

const BTN_NORMAL := Color(0.92, 0.92, 0.92)
const BTN_HOVER := Color(1.0, 0.63, 0.12)
const TITLE_COLOR := Color(1.0, 0.63, 0.12)
const HOVER_SOUND := "res://sounds/ui/buttonrollover.wav"
const CLICK_SOUND := "res://sounds/ui/buttonclick.wav"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var _buttons_box: VBoxContainer = null
var _options_box: VBoxContainer = null


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_resume()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	add_child(overlay)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.position = Vector2(64, 64)
	add_child(title)

	_buttons_box = VBoxContainer.new()
	_buttons_box.name = "Buttons"
	_buttons_box.add_theme_constant_override("separation", 14)
	_buttons_box.anchor_top = 0.38
	_buttons_box.anchor_bottom = 0.38
	_buttons_box.offset_left = 66.0
	_buttons_box.offset_right = 420.0
	add_child(_buttons_box)

	_add_button(_buttons_box, "RESUME", 28, _resume)
	_add_button(_buttons_box, "OPTIONS", 28, _toggle_options)
	_add_button(_buttons_box, "QUIT TO MENU", 28, _quit_to_menu)
	_add_button(_buttons_box, "QUIT GAME", 28, func() -> void: get_tree().quit())

	_build_options()


func _add_button(parent: Control, text: String, font_size: int, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", BTN_NORMAL)
	btn.add_theme_color_override("font_hover_color", BTN_HOVER)
	btn.add_theme_color_override("font_pressed_color", BTN_HOVER)
	btn.add_theme_color_override("font_hover_pressed_color", BTN_HOVER)
	btn.add_theme_color_override("font_focus_color", BTN_NORMAL)
	btn.mouse_entered.connect(func() -> void:
		AudioManager.play_sfx(HOVER_SOUND, -6.0)
	)
	btn.pressed.connect(func() -> void:
		AudioManager.play_sfx(CLICK_SOUND)
		callback.call()
	)
	parent.add_child(btn)
	return btn


func _build_options() -> void:
	_options_box = VBoxContainer.new()
	_options_box.name = "Options"
	_options_box.add_theme_constant_override("separation", 8)
	_options_box.anchor_top = 0.38
	_options_box.anchor_bottom = 0.38
	_options_box.offset_left = 460.0
	_options_box.offset_right = 820.0
	_options_box.visible = false
	add_child(_options_box)

	_options_box.add_child(_make_option_label("MOUSE SENSITIVITY"))
	var sens := HSlider.new()
	sens.min_value = 0.0005
	sens.max_value = 0.01
	sens.step = 0.0005
	sens.value = GameManager.mouse_sensitivity
	sens.custom_minimum_size = Vector2(0, 24)
	sens.value_changed.connect(func(v: float) -> void:
		GameManager.mouse_sensitivity = v
	)
	_options_box.add_child(sens)

	_options_box.add_child(_make_option_label("FIELD OF VIEW"))
	var fov := HSlider.new()
	fov.min_value = 60.0
	fov.max_value = 100.0
	fov.step = 1.0
	fov.value = GameManager.base_fov
	fov.custom_minimum_size = Vector2(0, 24)
	fov.value_changed.connect(func(v: float) -> void:
		GameManager.base_fov = v
	)
	_options_box.add_child(fov)

	_options_box.add_child(_make_option_label("MASTER VOLUME"))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	vol.custom_minimum_size = Vector2(0, 24)
	vol.value_changed.connect(func(v: float) -> void:
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001)))
		AudioServer.set_bus_mute(0, v <= 0.001)
	)
	_options_box.add_child(vol)


func _make_option_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	return label


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _toggle_options() -> void:
	_options_box.visible = not _options_box.visible


func _resume() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()


func _quit_to_menu() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if ResourceLoader.exists(MAIN_MENU_SCENE):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	queue_free()
