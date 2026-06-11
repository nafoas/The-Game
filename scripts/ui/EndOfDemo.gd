extends Control

## End-of-demo card: fade in big orange END OF DEMO, credit lines,
## then a CONTINUE button back to the main menu.

const ORANGE := Color(1.0, 0.63, 0.12)
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const CLICK_SOUND := "res://sounds/ui/buttonclick.wav"

var _continue_btn: Button = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	AudioManager.play_music("res://music/menu_theme.mp3", 3.0)
	_build_ui()
	_run_sequence()


func _build_ui() -> void:
	# Black background
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 18)
	vbox.anchor_left = 0.1
	vbox.anchor_right = 0.9
	vbox.anchor_top = 0.2
	vbox.anchor_bottom = 0.85
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	var title := _add_line(vbox, "END OF DEMO", 64, ORANGE)
	title.name = "TitleLabel"

	_add_line(vbox, "Joe Biden remains at large.", 24, Color(0.9, 0.9, 0.9))
	_add_line(vbox, "Thank you for playing — HUNT DOWN JOE BIDEN", 20, Color(0.85, 0.85, 0.85))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	_add_line(vbox, "A Source-Style Parody — built in Godot 4", 14, Color(0.6, 0.6, 0.6))
	_add_line(vbox, "Game Design: The Demo Team", 14, Color(0.6, 0.6, 0.6))
	_add_line(vbox, "Voice of Sgt. Dornan: [placeholder]", 14, Color(0.6, 0.6, 0.6))
	_add_line(vbox, "Special thanks: Black Mesa East Catering", 14, Color(0.6, 0.6, 0.6))
	_add_line(vbox, "No presidents were harmed in the making of this demo.", 14, Color(0.6, 0.6, 0.6))

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer2)

	_continue_btn = Button.new()
	_continue_btn.text = "CONTINUE"
	_continue_btn.flat = true
	_continue_btn.focus_mode = Control.FOCUS_NONE
	_continue_btn.add_theme_font_size_override("font_size", 26)
	_continue_btn.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	_continue_btn.add_theme_color_override("font_hover_color", ORANGE)
	_continue_btn.add_theme_color_override("font_pressed_color", ORANGE)
	_continue_btn.modulate = Color(1, 1, 1, 0)
	_continue_btn.pressed.connect(_on_continue)
	vbox.add_child(_continue_btn)

	# Start everything invisible for the staged fade-in.
	for child in vbox.get_children():
		if child is Label:
			(child as Label).modulate = Color(1, 1, 1, 0)


func _add_line(parent: Control, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _run_sequence() -> void:
	var vbox := get_node("Content") as VBoxContainer
	var delay := 0.8
	for child in vbox.get_children():
		if child is Label or child is Button:
			var tween := create_tween()
			tween.tween_interval(delay)
			tween.tween_property(child, "modulate:a", 1.0, 1.2)
			delay += 0.55


func _on_continue() -> void:
	AudioManager.play_sfx(CLICK_SOUND)
	if ResourceLoader.exists(MAIN_MENU_SCENE):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
