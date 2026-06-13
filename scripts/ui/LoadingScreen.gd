extends CanvasLayer

## Source-style loading screen shown while the next scene loads in background.
## Usage: LoadingScreen.load_scene("res://scenes/...") from any script.

const TIPS := [
	"Look for ammo crates — they respawn on reloading a checkpoint.",
	"Citizens will follow you into cover if you lead them there.",
	"Combine soldiers communicate — a flanker means suppression is coming.",
	"Grenades bounce off walls. Use corners to your advantage.",
	"Your HEV suit absorbs 50% of incoming damage while armor holds.",
]

var _target_path: String = ""
var _load_start: float   = 0.0
var _tip_timer: float    = 0.0
var _tip_index: int      = 0
var _bar: ProgressBar    = null
var _status: Label       = null
var _tip: Label          = null
var _pct: Label          = null


func _ready() -> void:
	layer = 100
	_build_ui()
	_tip_index = randi() % TIPS.size()
	_tip.text  = TIPS[_tip_index]


func _build_ui() -> void:
	# Full black background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Map name / title
	var title := Label.new()
	title.text = "HUNT DOWN JOE BIDEN"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	title.anchor_left   = 0.0
	title.anchor_right  = 1.0
	title.anchor_top    = 0.0
	title.anchor_bottom = 0.0
	title.offset_left   = 32.0
	title.offset_top    = 24.0
	title.offset_right  = -32.0
	title.offset_bottom = 50.0
	add_child(title)

	var map_name := Label.new()
	map_name.text = "c17_outskirts_01"
	map_name.add_theme_font_size_override("font_size", 11)
	map_name.add_theme_color_override("font_color", Color(0.38, 0.38, 0.38))
	map_name.anchor_left   = 0.0
	map_name.anchor_right  = 1.0
	map_name.anchor_top    = 0.0
	map_name.anchor_bottom = 0.0
	map_name.offset_left   = 32.0
	map_name.offset_top    = 42.0
	map_name.offset_right  = -32.0
	map_name.offset_bottom = 62.0
	add_child(map_name)

	# LOADING label (top-right)
	_status = Label.new()
	_status.text = "LOADING"
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color(1.0, 0.62, 0.11))
	_status.anchor_left   = 1.0
	_status.anchor_right  = 1.0
	_status.anchor_top    = 0.0
	_status.anchor_bottom = 0.0
	_status.offset_left   = -160.0
	_status.offset_top    = 24.0
	_status.offset_right  = -32.0
	_status.offset_bottom = 44.0
	add_child(_status)

	# Tip label (bottom-left, above bar)
	_tip = Label.new()
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.add_theme_font_size_override("font_size", 13)
	_tip.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_tip.anchor_left   = 0.0
	_tip.anchor_right  = 0.8
	_tip.anchor_top    = 1.0
	_tip.anchor_bottom = 1.0
	_tip.offset_left   = 32.0
	_tip.offset_top    = -90.0
	_tip.offset_right  = 0.0
	_tip.offset_bottom = -46.0
	add_child(_tip)

	var tip_header := Label.new()
	tip_header.text = "TIP:"
	tip_header.add_theme_font_size_override("font_size", 10)
	tip_header.add_theme_color_override("font_color", Color(1.0, 0.62, 0.11))
	tip_header.anchor_left   = 0.0
	tip_header.anchor_right  = 1.0
	tip_header.anchor_top    = 1.0
	tip_header.anchor_bottom = 1.0
	tip_header.offset_left   = 32.0
	tip_header.offset_top    = -108.0
	tip_header.offset_right  = -32.0
	tip_header.offset_bottom = -90.0
	add_child(tip_header)

	# Percentage label
	_pct = Label.new()
	_pct.text = "0%"
	_pct.add_theme_font_size_override("font_size", 11)
	_pct.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	_pct.anchor_left   = 1.0
	_pct.anchor_right  = 1.0
	_pct.anchor_top    = 1.0
	_pct.anchor_bottom = 1.0
	_pct.offset_left   = -80.0
	_pct.offset_top    = -44.0
	_pct.offset_right  = -32.0
	_pct.offset_bottom = -24.0
	add_child(_pct)

	# Progress bar (bottom, Source-style thin orange strip)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value     = 0.0
	_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.12, 0.12)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(1.0, 0.62, 0.11)
	_bar.add_theme_stylebox_override("background", bar_bg)
	_bar.add_theme_stylebox_override("fill", bar_fill)
	_bar.anchor_left   = 0.0
	_bar.anchor_right  = 1.0
	_bar.anchor_top    = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left   = 0.0
	_bar.offset_top    = -22.0
	_bar.offset_right  = 0.0
	_bar.offset_bottom = 0.0
	add_child(_bar)


func _process(delta: float) -> void:
	if _target_path.is_empty():
		return

	var status := ResourceLoader.load_threaded_get_status(_target_path)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var progress := []
			ResourceLoader.load_threaded_get_status(_target_path, progress)
			var pct: float = progress[0] if progress.size() > 0 else 0.0
			_bar.value = pct
			_pct.text  = "%d%%" % int(pct * 100)

		ResourceLoader.THREAD_LOAD_LOADED:
			_bar.value  = 1.0
			_pct.text   = "100%"
			_status.text = "DONE"
			var packed := ResourceLoader.load_threaded_get(_target_path) as PackedScene
			if packed:
				get_tree().change_scene_to_packed(packed)
			queue_free()

		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("LoadingScreen: failed to load %s" % _target_path)
			get_tree().change_scene_to_file(_target_path)
			queue_free()

	# Cycle tips every 8 seconds
	_tip_timer += delta
	if _tip_timer >= 8.0:
		_tip_timer = 0.0
		_tip_index = (_tip_index + 1) % TIPS.size()
		_tip.text  = TIPS[_tip_index]


# Call this instead of change_scene_to_file() to get the loading screen.
static func load_scene(path: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	ResourceLoader.load_threaded_request(path)
	var screen := load("res://scripts/ui/LoadingScreen.gd")
	if screen == null:
		tree.change_scene_to_file(path)
		return
	var node: Node = ClassDB.instantiate("CanvasLayer")
	node.set_script(screen)
	node.name = "LoadingScreen"
	tree.root.add_child(node)
	# Delay setting path so _ready() runs first and builds the UI
	node.set_meta("_pending_path", path)
	node.set_process(false)
	tree.create_timer(0.05).timeout.connect(func():
		node._target_path  = path
		node._load_start   = Time.get_ticks_msec() / 1000.0
		node.set_process(true)
	)
