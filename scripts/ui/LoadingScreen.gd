extends CanvasLayer

## Source-style loading screen.
## GameManager sets pending_scene then changes to this scene;
## we threaded-load it and swap once ready.

const TIPS := [
	"Look for ammo crates — they respawn on reloading a checkpoint.",
	"Citizens will follow you into cover if you lead them there.",
	"Combine soldiers communicate — a flanker means suppression is coming.",
	"Grenades bounce off walls. Use corners to your advantage.",
	"Your HEV suit absorbs 50% of incoming damage while armor holds.",
]

var _target: String = ""
var _bar:    ProgressBar
var _status: Label
var _tip:    Label
var _pct:    Label
var _tip_t:  float = 0.0
var _tip_i:  int   = 0


func _ready() -> void:
	layer = 100
	_build_ui()
	_tip_i   = randi() % TIPS.size()
	_tip.text = TIPS[_tip_i]

	_target = GameManager.pending_scene
	if _target.is_empty():
		# No destination stored — go to cutscene directly as fallback
		get_tree().change_scene_to_file(GameManager.OPENING_CUTSCENE_SCENE)
		return

	ResourceLoader.load_threaded_request(_target)


func _process(delta: float) -> void:
	if _target.is_empty():
		return

	var progress := []
	var status := ResourceLoader.load_threaded_get_status(_target, progress)

	var pct: float = progress[0] if progress.size() > 0 else 0.0
	_bar.value = pct
	_pct.text  = "%d%%" % int(pct * 100.0)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_bar.value  = 1.0
			_pct.text   = "100%"
			_status.text = "DONE"
			var packed := ResourceLoader.load_threaded_get(_target) as PackedScene
			GameManager.pending_scene = ""
			if packed:
				get_tree().change_scene_to_packed(packed)
			else:
				get_tree().change_scene_to_file(_target)

		ResourceLoader.THREAD_LOAD_FAILED, \
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			GameManager.pending_scene = ""
			get_tree().change_scene_to_file(_target)

	_tip_t += delta
	if _tip_t >= 8.0:
		_tip_t = 0.0
		_tip_i = (_tip_i + 1) % TIPS.size()
		_tip.text = TIPS[_tip_i]


func _build_ui() -> void:
	# Black background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title (top-left)
	var title := Label.new()
	title.text = "HUNT DOWN JOE BIDEN"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.position = Vector2(32, 24)
	add_child(title)

	# Map label (top-left, under title)
	var map_lbl := Label.new()
	map_lbl.text = "c17_outskirts_01"
	map_lbl.add_theme_font_size_override("font_size", 11)
	map_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	map_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map_lbl.position = Vector2(32, 42)
	add_child(map_lbl)

	# LOADING status (top-right)
	_status = Label.new()
	_status.text = "LOADING"
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color(1.0, 0.62, 0.11))
	_status.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_status.position = Vector2(-160, 24)
	add_child(_status)

	# Tip header
	var tip_hdr := Label.new()
	tip_hdr.text = "TIP:"
	tip_hdr.add_theme_font_size_override("font_size", 10)
	tip_hdr.add_theme_color_override("font_color", Color(1.0, 0.62, 0.11))
	tip_hdr.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	tip_hdr.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tip_hdr.position = Vector2(32, -110)
	add_child(tip_hdr)

	# Tip body
	_tip = Label.new()
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.add_theme_font_size_override("font_size", 13)
	_tip.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	_tip.anchor_left   = 0.0
	_tip.anchor_right  = 0.75
	_tip.anchor_top    = 1.0
	_tip.anchor_bottom = 1.0
	_tip.offset_left   = 32.0
	_tip.offset_right  = 0.0
	_tip.offset_top    = -92.0
	_tip.offset_bottom = -46.0
	add_child(_tip)

	# Percentage (bottom-right)
	_pct = Label.new()
	_pct.text = "0%"
	_pct.add_theme_font_size_override("font_size", 11)
	_pct.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_pct.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_pct.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_pct.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	_pct.position        = Vector2(-80, -40)
	add_child(_pct)

	# Orange progress bar (full-width, bottom)
	_bar = ProgressBar.new()
	_bar.min_value      = 0.0
	_bar.max_value      = 1.0
	_bar.value          = 0.0
	_bar.show_percentage = false
	_bar.anchor_left    = 0.0
	_bar.anchor_right   = 1.0
	_bar.anchor_top     = 1.0
	_bar.anchor_bottom  = 1.0
	_bar.offset_left    = 0.0
	_bar.offset_right   = 0.0
	_bar.offset_top     = -20.0
	_bar.offset_bottom  = 0.0

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.10, 0.10, 0.10)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(1.0, 0.62, 0.11)
	_bar.add_theme_stylebox_override("background", bg_style)
	_bar.add_theme_stylebox_override("fill", fill_style)
	add_child(_bar)
