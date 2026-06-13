extends "res://scripts/npc/NPCBase.gd"

const SOLDIER_BULLET_DAMAGE: float = 8.0

var _combat_line_timer: float = 0.0
var _combat_lines: Array[String] = ["Biden will prevail!", "For the resistance!", "HECU scum!"]


func _ready() -> void:
	npc_name = "Resistance Fighter"
	faction = "resistance"
	voice_file_prefix = "resistance"
	is_friendly = false

	super._ready()

	# Override mesh color for resistance
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 0.2)
	if _mesh_instance != null:
		_mesh_instance.material_override = mat

	# Enable patrol if waypoints are set
	if waypoints.size() > 0:
		current_state = State.PATROL


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if current_state == State.COMBAT:
		_combat_line_timer += delta
		if _combat_line_timer >= 8.0:
			_combat_line_timer = 0.0
			var idx := randi() % _combat_lines.size()
			SubtitleManager.show_subtitle_direct(_combat_lines[idx], 2.5, "Resistance Fighter")
			_play_voice("taunt_0%d" % (idx + 1))


func _play_voice(line_key: String) -> void:
	match line_key:
		"alert_01":
			SubtitleManager.show_subtitle_direct("Soldiers! You'll never take him alive!", 2.5, "Resistance Fighter")
		"pain_01":
			SubtitleManager.show_subtitle_direct("Augh!", 1.0, "Resistance Fighter")
		"search_01":
			SubtitleManager.show_subtitle_direct("Hey — over here! Something's out there.", 2.0, "Resistance Fighter")
		_:
			pass
	super._play_voice(line_key)
