extends Node3D

## Level 01 root script: capture input, start ambient music, load the
## subtitle bank and show the opening objective.

const OBJECTIVE_TEXT := "OBJECTIVE: Locate and eliminate Joe Biden"


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false

	SubtitleManager.load_subtitles("res://data/subtitles/level_01.json")
	AudioManager.play_music("res://music/level_01_ambient.mp3", 2.0)

	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	var hud := get_node_or_null("HUD")
	if hud != null and hud.has_method("show_objective"):
		hud.show_objective(OBJECTIVE_TEXT)
