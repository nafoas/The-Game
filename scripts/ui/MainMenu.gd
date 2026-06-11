extends Node3D

## HL2-style main menu: foggy 3D background world (MenuWorld child) with a
## left-aligned text-button list built in code into the UI CanvasLayer.

const TITLE_COLOR := Color(1.0, 0.63, 0.12)
const BTN_NORMAL := Color(0.92, 0.92, 0.92)
const BTN_HOVER := Color(1.0, 0.63, 0.12)
const HOVER_SOUND := "res://sounds/ui/buttonrollover.wav"
const CLICK_SOUND := "res://sounds/ui/buttonclick.wav"

var _ui: CanvasLayer = null
var _options_panel: PanelContainer = null
var _buttons_box: VBoxContainer = null
var _starting: bool = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	AudioManager.play_music("res://music/menu_theme.mp3", 1.5)

	_ui = get_node_or_null("UI")
	if _ui == null:
		_ui = CanvasLayer.new()
		_ui.name = "UI"
		add_child(_ui)

	UiTheme.add_menu_backplate(_ui)
	_build_title()
	_build_buttons()
	_build_version_label()
	_build_options_panel()


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_title() -> void:
	var title := Label.new()
	title.name = "Title"
	title.text = "HUNT DOWN"
	UiTheme.style_title(title, 54)
	title.position = Vector2(64, 56)
	_ui.add_child(title)

	# Second line bigger, HL2 "orange box" hierarchy
	var title2 := Label.new()
	title2.name = "Title2"
	title2.text = "JOE BIDEN"
	UiTheme.style_title(title2, 68, Color(0.95, 0.95, 0.95))
	title2.position = Vector2(64, 110)
	_ui.add_child(title2)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "A SOURCE-STYLE PARODY"
	UiTheme.style_small_caps(subtitle, 15)
	subtitle.position = Vector2(67, 188)
	_ui.add_child(subtitle)


func _build_buttons() -> void:
	_buttons_box = VBoxContainer.new()
	_buttons_box.name = "MenuButtons"
	_buttons_box.add_theme_constant_override("separation", 10)
	_buttons_box.anchor_top = 0.46
	_buttons_box.anchor_bottom = 0.46
	_buttons_box.offset_left = 66.0
	_buttons_box.offset_right = 380.0
	_ui.add_child(_buttons_box)

	_add_menu_button("NEW GAME", _on_new_game)
	_add_menu_button("OPTIONS", _on_options)
	_add_menu_button("QUIT", _on_quit)


func _build_version_label() -> void:
	var version := Label.new()
	version.name = "VersionLabel"
	version.text = "Demo build 0.1 — Godot 4 / Source asset parody"
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 0.8))
	version.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	version.add_theme_constant_override("shadow_offset_x", 1)
	version.add_theme_constant_override("shadow_offset_y", 1)
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = 18.0
	version.offset_top = -28.0
	_ui.add_child(version)


func _add_menu_button(text: String, callback: Callable) -> Button:
	var parts := UiTheme.make_menu_button(text, 28,
		func() -> void: AudioManager.play_sfx(HOVER_SOUND, -16.0),
		func() -> void:
			AudioManager.play_sfx(CLICK_SOUND, -8.0)
			callback.call()
	)
	_buttons_box.add_child(parts["wrap"])
	return parts["button"]


func _build_options_panel() -> void:
	_options_panel = PanelContainer.new()
	_options_panel.name = "OptionsPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.05, 0.92)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	_options_panel.add_theme_stylebox_override("panel", style)
	_options_panel.anchor_left = 0.5
	_options_panel.anchor_right = 0.5
	_options_panel.anchor_top = 0.5
	_options_panel.anchor_bottom = 0.5
	_options_panel.offset_left = -240.0
	_options_panel.offset_right = 240.0
	_options_panel.offset_top = -170.0
	_options_panel.offset_bottom = 170.0
	_options_panel.visible = false
	_ui.add_child(_options_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_options_panel.add_child(vbox)

	var header := Label.new()
	header.text = "OPTIONS"
	header.add_theme_font_size_override("font_size", 26)
	header.add_theme_color_override("font_color", TITLE_COLOR)
	vbox.add_child(header)

	# Mouse sensitivity
	vbox.add_child(_make_option_label("MOUSE SENSITIVITY"))
	var sens := HSlider.new()
	sens.min_value = 0.0005
	sens.max_value = 0.01
	sens.step = 0.0005
	sens.value = GameManager.mouse_sensitivity
	sens.custom_minimum_size = Vector2(0, 24)
	sens.value_changed.connect(func(v: float) -> void:
		GameManager.mouse_sensitivity = v
	)
	vbox.add_child(sens)

	# FOV
	vbox.add_child(_make_option_label("FIELD OF VIEW"))
	var fov := HSlider.new()
	fov.min_value = 60.0
	fov.max_value = 100.0
	fov.step = 1.0
	fov.value = GameManager.base_fov
	fov.custom_minimum_size = Vector2(0, 24)
	fov.value_changed.connect(func(v: float) -> void:
		GameManager.base_fov = v
	)
	vbox.add_child(fov)

	# Master volume
	vbox.add_child(_make_option_label("MASTER VOLUME"))
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
	vbox.add_child(vol)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var back := Button.new()
	back.text = "BACK"
	back.flat = true
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 22)
	back.add_theme_color_override("font_color", BTN_NORMAL)
	back.add_theme_color_override("font_hover_color", BTN_HOVER)
	back.pressed.connect(func() -> void:
		AudioManager.play_sfx(CLICK_SOUND)
		_options_panel.visible = false
		_buttons_box.visible = true
	)
	back.mouse_entered.connect(func() -> void:
		AudioManager.play_sfx(HOVER_SOUND, -6.0)
	)
	vbox.add_child(back)


func _make_option_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	return label


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _on_new_game() -> void:
	if _starting:
		return
	_starting = true
	AudioManager.stop_music(1.0)
	GameManager.new_game()


func _on_options() -> void:
	_options_panel.visible = true
	_buttons_box.visible = false


func _on_quit() -> void:
	get_tree().quit()
