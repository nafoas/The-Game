extends Node

## Audio singleton: pooled 2D SFX players, one-shot positional 3D players,
## and a dedicated looping music player with fades.
## All loads are guarded — placeholder/0-byte audio files must never crash.

const SFX_POOL_SIZE: int = 10
const MUSIC_SILENCE_DB: float = -50.0

var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer = null
var _music_tween: Tween = null
var _current_music_path: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_build_pool()
	_build_music_player()


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _build_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFX%d" % i
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)


func _build_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	add_child(_music_player)


# ---------------------------------------------------------------------------
# Guarded loading
# ---------------------------------------------------------------------------

func _load_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	var res: Variant = load(path)
	var stream := res as AudioStream
	return stream


# ---------------------------------------------------------------------------
# SFX
# ---------------------------------------------------------------------------

func play_sfx(path: String, volume_db: float = 0.0) -> void:
	var stream := _load_stream(path)
	if stream == null:
		return
	var player := _get_free_sfx_player()
	if player == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.97, 1.03)
	player.play()


func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	# All busy — steal the first one.
	if _sfx_pool.size() > 0:
		return _sfx_pool[0]
	return null


func play_sfx_at(path: String, position: Vector3, volume_db: float = 0.0) -> void:
	var stream := _load_stream(path)
	if stream == null:
		return

	var player := AudioStreamPlayer3D.new()
	player.bus = "SFX"
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = 6.0
	player.max_distance = 60.0
	player.pitch_scale = randf_range(0.97, 1.03)

	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = self
	parent.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()

	# Safety net in case the stream loops or never finishes.
	get_tree().create_timer(20.0).timeout.connect(func() -> void:
		if is_instance_valid(player):
			player.queue_free()
	)


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

func play_music(path: String, fade_in: float = 1.0) -> void:
	if path == _current_music_path and _music_player.playing:
		return

	var stream := _load_stream(path)
	if stream == null:
		# Placeholder/missing track: fade out whatever is playing and bail.
		stop_music(0.5)
		_current_music_path = ""
		return

	_set_stream_looping(stream)
	_current_music_path = path

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	_music_player.stop()
	_music_player.stream = stream
	_music_player.volume_db = MUSIC_SILENCE_DB
	_music_player.play()

	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", 0.0, maxf(fade_in, 0.01))


func stop_music(fade_out: float = 1.0) -> void:
	if _music_player == null or not _music_player.playing:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_current_music_path = ""
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", MUSIC_SILENCE_DB, maxf(fade_out, 0.01))
	_music_tween.tween_callback(_music_player.stop)


func _set_stream_looping(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size()
	else:
		# AudioStreamMP3 / AudioStreamOggVorbis both expose a `loop` bool;
		# set() is a safe no-op for stream types that lack it.
		stream.set("loop", true)
