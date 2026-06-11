extends Node3D

## Level 01 root script: capture input, start ambient music, load the
## subtitle bank and show the opening objective.

const OBJECTIVE_TEXT := "OBJECTIVE: Locate and eliminate Joe Biden"


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false

	SubtitleManager.load_subtitles("res://data/subtitles/level_01.json")
	AudioManager.play_music("res://music/level_01_ambient.mp3", 2.0)
	_start_city_ambience()

	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	var hud := get_node_or_null("HUD")
	if hud != null and hud.has_method("show_objective"):
		hud.show_objective(OBJECTIVE_TEXT)


## Constant distant-city bed under everything so the level never goes silent.
func _start_city_ambience() -> void:
	var path := "res://sounds/ambient/levels/city/citadel_winds_loop1.wav"
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	SourceMaterials.make_wav_loop(stream)
	var bed := AudioStreamPlayer.new()
	bed.name = "CityAmbienceBed"
	bed.stream = stream
	bed.volume_db = -22.0
	bed.autoplay = true
	bed.bus = "SFX"
	add_child(bed)
