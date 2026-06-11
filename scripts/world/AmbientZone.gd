extends Area3D

@export var ambient_sound_path: String = ""
@export var volume_db: float = -10.0

var _audio: AudioStreamPlayer3D = null
var _tween: Tween = null


func _ready() -> void:
	_audio = get_node_or_null("AudioStreamPlayer3D")
	if _audio == null:
		_audio = AudioStreamPlayer3D.new()
		_audio.name = "AudioStreamPlayer3D"
		_audio.volume_db = -80.0
		add_child(_audio)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Pre-load sound if available
	if ambient_sound_path != "" and ResourceLoader.exists(ambient_sound_path):
		var stream := ResourceLoader.load(ambient_sound_path) as AudioStream
		if stream != null:
			# Imported WAVs default to no-loop; ambient beds must cycle.
			SourceMaterials.make_wav_loop(stream)
			_audio.stream = stream


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _audio.stream == null:
		return

	if not _audio.playing:
		_audio.play()

	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_audio, "volume_db", volume_db, 1.0)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _audio.stream == null:
		return

	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_audio, "volume_db", -80.0, 2.0)
	_tween.tween_callback(_audio.stop)
