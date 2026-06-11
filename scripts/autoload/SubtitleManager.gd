extends CanvasLayer

## HL2-style subtitle singleton. Bottom-center subtitle box with an optional
## orange speaker prefix, plus a queue so overlapping lines play in order.

const SPEAKER_COLOR := "#ffa01e"
const PANEL_BG := Color(0.0, 0.0, 0.0, 0.55)

var _panel: PanelContainer = null
var _label: RichTextLabel = null
var _queue: Array[Dictionary] = []
var _running: bool = false
var _subtitle_data: Dictionary = {}


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "SubtitlePanel"

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override("panel", style)

	# Max width 70% of screen, centered horizontally, anchored ~80% down.
	_panel.anchor_left = 0.15
	_panel.anchor_right = 0.85
	_panel.anchor_top = 0.8
	_panel.anchor_bottom = 0.8
	_panel.offset_left = 0.0
	_panel.offset_right = 0.0
	_panel.offset_top = 0.0
	_panel.offset_bottom = 0.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)

	_label = RichTextLabel.new()
	_label.name = "SubtitleLabel"
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("normal_font_size", 20)
	_label.add_theme_font_size_override("bold_font_size", 20)
	_label.add_theme_color_override("default_color", Color.WHITE)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_panel.add_child(_label)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func show_subtitle_direct(text: String, duration: float, speaker: String = "") -> void:
	if text.is_empty():
		return
	_queue.append({
		"text": text,
		"duration": maxf(duration, 0.5),
		"speaker": speaker,
	})
	if not _running:
		_process_queue()


func load_subtitles(json_path: String) -> void:
	if not FileAccess.file_exists(json_path):
		return
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return
	var raw := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		_subtitle_data.merge(parsed, true)


func show_subtitle(key: String) -> void:
	if not _subtitle_data.has(key):
		return
	var entry: Variant = _subtitle_data[key]
	if not (entry is Dictionary):
		return
	var text: String = str(entry.get("text", ""))
	var speaker: String = str(entry.get("speaker", ""))
	var duration: float = float(entry.get("duration", 3.0))
	show_subtitle_direct(text, duration, speaker)


# ---------------------------------------------------------------------------
# Queue worker
# ---------------------------------------------------------------------------

func _process_queue() -> void:
	_running = true
	while _queue.size() > 0:
		var entry: Dictionary = _queue.pop_front()
		_display(entry)
		await get_tree().create_timer(float(entry["duration"])).timeout
	_panel.visible = false
	_running = false


func _display(entry: Dictionary) -> void:
	var speaker: String = entry["speaker"]
	var text: String = entry["text"]
	var bbcode := ""
	if not speaker.is_empty():
		bbcode = "[color=%s]%s:[/color] " % [SPEAKER_COLOR, speaker]
	bbcode += text
	_label.text = "[center]%s[/center]" % bbcode
	_panel.visible = true
