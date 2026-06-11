extends CanvasLayer

## HL2-style HUD: health/suit panels bottom-left, ammo bottom-right,
## dot crosshair, damage vignette, low-health blink, objective fade label.

const HUD_ORANGE := Color(1.0, 0.63, 0.12)
const HUD_RED := Color(1.0, 0.15, 0.1)
const PANEL_BG := Color(0.05, 0.07, 0.05, 0.45)
const LOW_HEALTH_THRESHOLD: float = 25.0

var _health_value: Label = null
var _armor_value: Label = null
var _ammo_value: Label = null
var _ammo_reserve: Label = null
var _weapon_label: Label = null
var _vignette: ColorRect = null
var _objective_label: Label = null
var _crosshair: Control = null

var _last_health: float = 100.0
var _blink_tween: Tween = null
var _vignette_tween: Tween = null
var _objective_tween: Tween = null
var _weapon_manager: Node = null


func _ready() -> void:
	layer = 10
	_build_vignette()
	_build_health_panels()
	_build_ammo_panel()
	_build_crosshair()
	_build_objective_label()
	call_deferred("_connect_signals")


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _make_panel_style() -> StyleBoxFlat:
	return UiTheme.panel_style(UiTheme.PANEL_BG, 5, 20.0, 8.0)


func _make_stat_panel(title: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	var title_label := Label.new()
	title_label.text = title
	UiTheme.style_small_caps(title_label, 12)
	title_label.size_flags_vertical = Control.SIZE_SHRINK_END
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(title_label)

	var value_label := Label.new()
	value_label.text = "100"
	UiTheme.style_value_label(value_label, 40)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(value_label)

	return {"panel": panel, "value": value_label}


func _build_health_panels() -> void:
	var container := HBoxContainer.new()
	container.name = "BottomLeft"
	container.add_theme_constant_override("separation", 12)
	container.anchor_left = 0.0
	container.anchor_right = 0.0
	container.anchor_top = 1.0
	container.anchor_bottom = 1.0
	container.offset_left = 24.0
	container.offset_top = -78.0
	container.offset_bottom = -20.0
	container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	var health := _make_stat_panel("HEALTH")
	container.add_child(health["panel"])
	_health_value = health["value"]

	var armor := _make_stat_panel("SUIT")
	container.add_child(armor["panel"])
	_armor_value = armor["value"]
	_armor_value.text = "0"


func _build_ammo_panel() -> void:
	var container := HBoxContainer.new()
	container.name = "BottomRight"
	container.anchor_left = 1.0
	container.anchor_right = 1.0
	container.anchor_top = 1.0
	container.anchor_bottom = 1.0
	container.offset_left = -320.0
	container.offset_right = -24.0
	container.offset_top = -78.0
	container.offset_bottom = -20.0
	container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	container.alignment = BoxContainer.ALIGNMENT_END
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	_weapon_label = Label.new()
	_weapon_label.text = "PISTOL"
	UiTheme.style_small_caps(_weapon_label, 12)
	_weapon_label.size_flags_vertical = Control.SIZE_SHRINK_END
	_weapon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_weapon_label)

	_ammo_value = Label.new()
	_ammo_value.text = "18"
	UiTheme.style_value_label(_ammo_value, 40)
	_ammo_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_ammo_value)

	# Styled divider between mag and reserve, HL2-style
	var divider := ColorRect.new()
	divider.color = Color(UiTheme.ORANGE.r, UiTheme.ORANGE.g, UiTheme.ORANGE.b, 0.35)
	divider.custom_minimum_size = Vector2(2, 34)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(divider)

	_ammo_reserve = Label.new()
	_ammo_reserve.text = "90"
	UiTheme.style_value_label(_ammo_reserve, 22, UiTheme.ORANGE_DIM)
	_ammo_reserve.size_flags_vertical = Control.SIZE_SHRINK_END
	_ammo_reserve.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_ammo_reserve)


func _build_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.name = "Crosshair"
	_crosshair.anchor_left = 0.5
	_crosshair.anchor_right = 0.5
	_crosshair.anchor_top = 0.5
	_crosshair.anchor_bottom = 0.5
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(_on_crosshair_draw)
	add_child(_crosshair)


func _on_crosshair_draw() -> void:
	# Crisp HL2-ish crosshair: 4 short 1 px ticks + center dot, with a faint
	# dark under-layer so it stays readable on bright surfaces.
	var shadow := Color(0, 0, 0, 0.55)
	var c := Color(HUD_ORANGE.r, HUD_ORANGE.g, HUD_ORANGE.b, 0.95)
	var gap := 5.0
	var tick := 4.0
	for off in [Vector2(1, 1), Vector2.ZERO]:
		var col := shadow if off != Vector2.ZERO else c
		_crosshair.draw_rect(Rect2(Vector2(-1, -1) + off, Vector2(2, 2)), col)
		_crosshair.draw_rect(Rect2(Vector2(gap, -0.5) + off, Vector2(tick, 1)), col)
		_crosshair.draw_rect(Rect2(Vector2(-gap - tick, -0.5) + off, Vector2(tick, 1)), col)
		_crosshair.draw_rect(Rect2(Vector2(-0.5, gap) + off, Vector2(1, tick)), col)
		_crosshair.draw_rect(Rect2(Vector2(-0.5, -gap - tick) + off, Vector2(1, tick)), col)


func _build_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.name = "DamageVignette"
	_vignette.color = Color(0.8, 0.0, 0.0, 0.0)
	_vignette.anchor_right = 1.0
	_vignette.anchor_bottom = 1.0
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)


func _build_objective_label() -> void:
	_objective_label = Label.new()
	_objective_label.name = "ObjectiveLabel"
	_objective_label.text = ""
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_value_label(_objective_label, 19)
	_objective_label.add_theme_constant_override("outline_size", 4)
	_objective_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_objective_label.anchor_left = 0.2
	_objective_label.anchor_right = 0.8
	_objective_label.anchor_top = 0.06
	_objective_label.anchor_bottom = 0.06
	_objective_label.grow_vertical = Control.GROW_DIRECTION_END
	_objective_label.modulate = Color(1, 1, 1, 0)
	_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_objective_label)


# ---------------------------------------------------------------------------
# Signal wiring
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.armor_changed.connect(_on_armor_changed)

	_last_health = GameManager.player_health
	_set_health_text(GameManager.player_health)
	_armor_value.text = str(int(GameManager.player_armor))

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player: Node = players[0]
		_weapon_manager = player.get_node_or_null("Head/WeaponManager")
		if _weapon_manager != null:
			if _weapon_manager.has_signal("ammo_changed"):
				_weapon_manager.ammo_changed.connect(_on_ammo_changed)
			if _weapon_manager.has_signal("weapon_changed"):
				_weapon_manager.weapon_changed.connect(_on_weapon_changed)
			if _weapon_manager.has_method("get_ammo"):
				var a: Dictionary = _weapon_manager.get_ammo()
				_on_ammo_changed(int(a["current"]), int(a["reserve"]))
			if "current_weapon_name" in _weapon_manager:
				_on_weapon_changed(_weapon_manager.current_weapon_name)


func _exit_tree() -> void:
	if GameManager.health_changed.is_connected(_on_health_changed):
		GameManager.health_changed.disconnect(_on_health_changed)
	if GameManager.armor_changed.is_connected(_on_armor_changed):
		GameManager.armor_changed.disconnect(_on_armor_changed)


# ---------------------------------------------------------------------------
# Updates
# ---------------------------------------------------------------------------

func _on_health_changed(new_health: float) -> void:
	if new_health < _last_health:
		_flash_vignette()
	_last_health = new_health
	_set_health_text(new_health)


func _set_health_text(health: float) -> void:
	_health_value.text = str(int(maxf(health, 0.0)))
	if health < LOW_HEALTH_THRESHOLD:
		_start_low_health_blink()
	else:
		_stop_low_health_blink()


func _start_low_health_blink() -> void:
	if _blink_tween != null and _blink_tween.is_valid():
		return
	# Modulating the label red-flashes the orange digits.
	_blink_tween = create_tween()
	_blink_tween.set_loops()
	_blink_tween.tween_property(_health_value, "self_modulate", Color(1.0, 0.15, 0.15), 0.3)
	_blink_tween.tween_property(_health_value, "self_modulate", Color.WHITE, 0.3)


func _stop_low_health_blink() -> void:
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = null
	_health_value.self_modulate = Color.WHITE


func _flash_vignette() -> void:
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_vignette, "color:a", 0.35, 0.06)
	_vignette_tween.tween_property(_vignette, "color:a", 0.0, 0.5)


func _on_armor_changed(new_armor: float) -> void:
	_armor_value.text = str(int(maxf(new_armor, 0.0)))


func _on_ammo_changed(current: int, reserve: int) -> void:
	_ammo_value.text = str(current)
	if _ammo_reserve != null:
		_ammo_reserve.text = str(reserve)


func _on_weapon_changed(weapon_name: String) -> void:
	_weapon_label.text = weapon_name.to_upper()


# ---------------------------------------------------------------------------
# Objective
# ---------------------------------------------------------------------------

func show_objective(text: String) -> void:
	_objective_label.text = text
	if _objective_tween != null and _objective_tween.is_valid():
		_objective_tween.kill()
	_objective_tween = create_tween()
	_objective_tween.tween_property(_objective_label, "modulate:a", 1.0, 0.4)
	_objective_tween.tween_interval(4.0)
	_objective_tween.tween_property(_objective_label, "modulate:a", 0.0, 0.8)
