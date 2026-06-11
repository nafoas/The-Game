extends Node3D

## Skippable in-engine intro cutscene: dark military transport interior,
## window strip with a foggy city skyline rolling past, flickering light,
## slow camera dolly with handheld shake, letterboxed, subtitled.

const LEVEL_SCENE := "res://scenes/level/level_01.tscn"

var _camera: Camera3D = null
var _flicker_light: OmniLight3D = null
var _fade_rect: ColorRect = null
var _skip_label: Label = null
var _time: float = 0.0
var _skipped: bool = false
var _skip_armed: bool = false
var _cam_base := Vector3(0.0, 1.4, 1.6)


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	AudioManager.play_music("res://music/cutscene_01.mp3", 2.0)
	_build_environment()
	_build_transport_interior()
	_build_skyline()
	_build_camera()
	_build_overlay()
	_run_sequence()


# ---------------------------------------------------------------------------
# Scene construction
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.09)
	env.fog_enabled = true
	env.fog_light_color = Color(0.25, 0.27, 0.33)
	env.fog_density = 0.04
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.25, 0.3)
	env.ambient_light_energy = 0.4
	world_env.environment = env
	add_child(world_env)


func _add_box(pos: Vector3, size: Vector3, color: Color, emissive: bool = false) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.size = size
	box.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.2
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = mat
	add_child(box)
	return box


func _build_transport_interior() -> void:
	var hull := Color(0.12, 0.13, 0.14)
	var dark := Color(0.08, 0.08, 0.09)

	# Floor / ceiling / walls of the transport bay (about 3 x 2.4 x 6 m)
	_add_box(Vector3(0, 0, 0), Vector3(3.0, 0.1, 6.0), dark)            # floor
	_add_box(Vector3(0, 2.4, 0), Vector3(3.0, 0.1, 6.0), hull)          # ceiling
	_add_box(Vector3(0, 1.2, -3.0), Vector3(3.0, 2.4, 0.1), hull)       # front bulkhead
	_add_box(Vector3(0, 1.2, 3.0), Vector3(3.0, 2.4, 0.1), hull)        # rear ramp
	_add_box(Vector3(1.5, 0.5, 0), Vector3(0.1, 1.0, 6.0), hull)        # right wall lower
	_add_box(Vector3(1.5, 2.1, 0), Vector3(0.1, 0.8, 6.0), hull)        # right wall upper
	_add_box(Vector3(-1.5, 1.2, 0), Vector3(0.1, 2.4, 6.0), hull)       # left wall (solid)

	# Window strip on the right wall (between the lower and upper sections),
	# emissive haze-gray so the skyline silhouettes read against it.
	_add_box(Vector3(1.5, 1.35, 0), Vector3(0.04, 0.7, 5.6), Color(0.35, 0.38, 0.45), true)

	# Bench seats along both walls
	_add_box(Vector3(-1.1, 0.45, 0), Vector3(0.7, 0.08, 5.2), Color(0.18, 0.2, 0.18))
	_add_box(Vector3(1.1, 0.45, 0), Vector3(0.7, 0.08, 5.2), Color(0.18, 0.2, 0.18))

	# Crates strapped at the front
	_add_box(Vector3(-0.6, 0.35, -2.4), Vector3(0.6, 0.6, 0.6), Color(0.25, 0.22, 0.15))
	_add_box(Vector3(0.2, 0.3, -2.5), Vector3(0.5, 0.5, 0.5), Color(0.22, 0.2, 0.14))

	# Seated silhouette marines (capsule stand-ins)
	for z in [-1.6, -0.4, 0.8]:
		var marine := CSGCylinder3D.new()
		marine.radius = 0.22
		marine.height = 1.0
		marine.position = Vector3(-1.1, 0.95, z)
		var mmat := StandardMaterial3D.new()
		mmat.albedo_color = Color(0.1, 0.11, 0.1)
		marine.material = mmat
		add_child(marine)

	# Dim flickering interior light
	_flicker_light = OmniLight3D.new()
	_flicker_light.position = Vector3(0, 2.2, -0.5)
	_flicker_light.light_color = Color(1.0, 0.85, 0.6)
	_flicker_light.light_energy = 0.9
	_flicker_light.omni_range = 6.0
	add_child(_flicker_light)


func _build_skyline() -> void:
	# Foggy city silhouettes outside the right-hand window strip.
	var sil := Color(0.05, 0.06, 0.08)
	var positions := [
		[Vector3(8.0, 2.0, -6.0), Vector3(3.0, 5.0, 2.0)],
		[Vector3(10.0, 3.0, -2.0), Vector3(2.5, 7.0, 2.5)],
		[Vector3(9.0, 1.5, 2.0), Vector3(3.5, 4.0, 2.0)],
		[Vector3(12.0, 4.0, 5.0), Vector3(3.0, 9.0, 3.0)],
		[Vector3(11.0, 2.5, 9.0), Vector3(2.0, 6.0, 2.0)],
		[Vector3(14.0, 3.5, -8.0), Vector3(4.0, 8.0, 3.0)],
	]
	for bd in positions:
		_add_box(bd[0], bd[1], sil)

	# A couple of lit windows in the skyline
	for p in [Vector3(9.55, 2.8, -2.0), Vector3(7.45, 1.8, 2.0), Vector3(10.45, 4.5, 5.0)]:
		_add_box(p, Vector3(0.1, 0.3, 0.3), Color(0.9, 0.7, 0.3), true)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.position = _cam_base
	_camera.rotation_degrees = Vector3(-2.0, 15.0, 0.0)
	_camera.fov = 70.0
	_camera.near = 0.05
	_camera.current = true
	add_child(_camera)


func _build_overlay() -> void:
	var ui := CanvasLayer.new()
	ui.name = "CutsceneUI"
	ui.layer = 80
	add_child(ui)

	# Letterbox bars
	var top_bar := ColorRect.new()
	top_bar.color = Color.BLACK
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.1
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(top_bar)

	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color.BLACK
	bottom_bar.anchor_top = 0.9
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bottom_bar)

	# Full-screen fade (starts black)
	_fade_rect = ColorRect.new()
	_fade_rect.name = "Fade"
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade_rect)

	# Skip hint (hidden until Esc/Space pressed once)
	_skip_label = Label.new()
	_skip_label.text = "Press SPACE to skip"
	_skip_label.add_theme_font_size_override("font_size", 16)
	_skip_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.9))
	_skip_label.anchor_left = 1.0
	_skip_label.anchor_right = 1.0
	_skip_label.anchor_top = 1.0
	_skip_label.anchor_bottom = 1.0
	_skip_label.offset_left = -260.0
	_skip_label.offset_top = -48.0
	_skip_label.offset_right = -24.0
	_skip_label.offset_bottom = -20.0
	_skip_label.visible = false
	_skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_skip_label)


# ---------------------------------------------------------------------------
# Skipping
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var pressed_space := event.is_action_pressed("ui_accept") or event.is_action_pressed("jump")
	var pressed_esc := event.is_action_pressed("ui_cancel")
	if not (pressed_space or pressed_esc):
		return
	get_viewport().set_input_as_handled()

	if not _skip_armed:
		# First press of Space/Esc: reveal the skip hint.
		_skip_armed = true
		_skip_label.visible = true
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(_skip_label) and not _skipped:
				_skip_label.visible = false
			_skip_armed = false
		)
		return

	if pressed_space:
		_skip()


func _skip() -> void:
	if _skipped:
		return
	_skipped = true
	_go_to_level()


func _go_to_level() -> void:
	if not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, 0.6)
	await tween.finished
	AudioManager.stop_music(0.5)
	if ResourceLoader.exists(LEVEL_SCENE):
		get_tree().change_scene_to_file(LEVEL_SCENE)


# ---------------------------------------------------------------------------
# Camera motion + light flicker
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta

	if _camera != null:
		# Slow dolly forward along the bay plus handheld wobble.
		var dolly_z := _cam_base.z - minf(_time * 0.06, 1.6)
		var wobble := Vector3(
			sin(_time * 1.7) * 0.015 + sin(_time * 4.3) * 0.006,
			sin(_time * 2.3) * 0.012 + sin(_time * 5.1) * 0.005,
			0.0
		)
		_camera.position = Vector3(_cam_base.x, _cam_base.y, dolly_z) + wobble
		_camera.rotation_degrees.z = sin(_time * 0.9) * 0.4

	if _flicker_light != null:
		var flicker := 0.9 + sin(_time * 13.0) * 0.1 + randf_range(-0.15, 0.1)
		if randf() < 0.01:
			flicker *= 0.3  # occasional hard drop
		_flicker_light.light_energy = clampf(flicker, 0.2, 1.2)


# ---------------------------------------------------------------------------
# Scripted sequence
# ---------------------------------------------------------------------------

func _say(text: String, duration: float, speaker: String = "") -> void:
	SubtitleManager.show_subtitle_direct(text, duration, speaker)


func _wait(seconds: float) -> bool:
	# Returns false if the cutscene was skipped while waiting.
	await get_tree().create_timer(seconds).timeout
	return not _skipped and is_inside_tree()


func _run_sequence() -> void:
	# 1. Fade in from black over 2s.
	var fade := create_tween()
	fade.tween_property(_fade_rect, "color:a", 0.0, 2.0)

	if not await _wait(2.2):
		return
	_say("BLACK MESA EAST — 2027", 3.0)

	if not await _wait(3.2):
		return
	_say("Three weeks after the election results were... contested.", 3.5)

	if not await _wait(3.9):
		return
	_say("Listen up, marine. Intel says the so-called 'Big Guy' is holed up in this sector.", 4.0, "Sgt. Dornan")

	if not await _wait(4.2):
		return
	_say("Joe Biden. Former president. Current leader of the resistance. Public enemy number one.", 4.0, "Sgt. Dornan")

	if not await _wait(4.2):
		return
	_say("I've been waiting a long time for this... My face is finally healed.", 3.5, "You")

	if not await _wait(3.9):
		return
	_say("Rise and shine, soldier. Rise... and... shine.", 3.5, "Sgt. Dornan")

	if not await _wait(3.9):
		return
	_say("Wake up. Smell the ashes. And hunt down Joe Biden.", 4.0, "Sgt. Dornan")

	if not await _wait(4.5):
		return

	# 7. Fade to black, then load the level.
	_skipped = true  # block further skip input during the outro
	_go_to_level()
