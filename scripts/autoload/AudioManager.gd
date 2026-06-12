extends Node

## Audio singleton: pooled 2D SFX players, one-shot positional 3D players,
## and a dedicated looping music player with fades.
## All loads are guarded — placeholder/0-byte audio files must never crash.

const SFX_POOL_SIZE: int = 10
const MUSIC_SILENCE_DB: float = -50.0
const MUSIC_TARGET_DB: float = -6.0

## Placeholder asset paths -> real HL2/EP2 files that actually exist in the
## repo. Several referenced files are 0-byte stand-ins; this keeps every
## existing call site working while playing real audio.
const REMAPS: Dictionary = {
	"res://music/menu_theme.mp3": "res://sounds/music/vlvx_song0.mp3",
	"res://music/cutscene_01.mp3": "res://sounds/music/vlvx_song12.mp3",
	"res://music/level_01_ambient.mp3": "res://sounds/music/vlvx_song23ambient.mp3",
	"res://sounds/ui/buttonrollover.wav": "res://sounds/npc/zombine/gear2.wav",
	"res://sounds/ui/buttonclick.wav": "res://sounds/weapons/alyx_gun/alyx_shotgun_cock1.wav",
	"res://sounds/items/item_battery_pickup.wav": "res://sounds/weapons/alyx_gun/alyx_shotgun_cock1.wav",
	"res://sounds/items/medshot4.wav": "res://sounds/npc/combine_soldier/zipline_clothing2.wav",
	"res://sounds/misc/radio_beep.wav": "res://sounds/ambient/levels/citadel/datatransrandom01.wav",
}

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

## Public guarded loader for other systems (NPC voice lines, etc.) so that
## 0-byte placeholder assets silently no-op instead of spamming load errors.
func load_stream(path: String) -> AudioStream:
	return _load_stream(path)


func _load_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	var stream: AudioStream = null
	if ResourceLoader.exists(path) and not _is_placeholder_file(path):
		stream = load(path) as AudioStream
	if stream == null and REMAPS.has(path):
		var remapped: String = REMAPS[path]
		if ResourceLoader.exists(remapped):
			stream = load(remapped) as AudioStream
	return stream


## 0-byte stand-in assets fail to load with a noisy engine ERROR; detect them
## up front so we fall straight through to the REMAPS table silently.
func _is_placeholder_file(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	return f.get_length() == 0


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
	_music_tween.tween_property(_music_player, "volume_db", MUSIC_TARGET_DB, maxf(fade_in, 0.01))


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
		var bytes_per_sample := 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
		var channels := 2 if wav.stereo else 1
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.data.size() / float(bytes_per_sample * channels))
	else:
		# AudioStreamMP3 / AudioStreamOggVorbis both expose a `loop` bool;
		# set() is a safe no-op for stream types that lack it.
		stream.set("loop", true)
