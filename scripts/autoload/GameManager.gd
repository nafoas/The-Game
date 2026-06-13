extends Node

## Global game state singleton.
## Handles player health/armor, checkpoints, level flow, death/respawn,
## global settings, and the pause menu toggle.

signal health_changed(new_health: float)
signal armor_changed(new_armor: float)
signal player_died
signal level_completed

const MAX_HEALTH: float = 100.0
const MAX_ARMOR: float = 100.0
const PAUSE_MENU_SCENE: String     = "res://scenes/ui/pause_menu.tscn"
const END_OF_DEMO_SCENE: String    = "res://scenes/ui/end_of_demo.tscn"
const OPENING_CUTSCENE_SCENE: String = "res://scenes/cutscene/opening_cutscene.tscn"
const LOADING_SCREEN_SCENE: String = "res://scenes/ui/loading_screen.tscn"

# Set this before changing to LOADING_SCREEN_SCENE so LoadingScreen knows
# which scene to load in the background.
var pending_scene: String = ""

var player_health: float = 100.0
var player_armor: float = 0.0
var checkpoint_position: Vector3 = Vector3.ZERO

# Global settings (read by Player / menus)
var mouse_sensitivity: float = 0.0025
var base_fov: float = 75.0

var _dying: bool = false
var _level_complete: bool = false
var _pause_menu: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ---------------------------------------------------------------------------
# Damage / death
# ---------------------------------------------------------------------------

func apply_damage(amount: float) -> void:
	if _dying or amount <= 0.0:
		return

	# Source-style: armor absorbs 50% of incoming damage while available.
	var health_damage := amount
	if player_armor > 0.0:
		var absorbed: float = minf(player_armor, amount * 0.5)
		player_armor = maxf(player_armor - absorbed, 0.0)
		health_damage = amount - absorbed
		armor_changed.emit(player_armor)

	player_health = maxf(player_health - health_damage, 0.0)
	health_changed.emit(player_health)

	if player_health <= 0.0:
		_dying = true
		player_died.emit()
		_on_player_died()


func heal(amount: float) -> void:
	player_health = minf(player_health + amount, MAX_HEALTH)
	health_changed.emit(player_health)


func add_armor(amount: float) -> void:
	player_armor = minf(player_armor + amount, MAX_ARMOR)
	armor_changed.emit(player_armor)


func _on_player_died() -> void:
	# Brief pause so the death registers, then reload from last checkpoint.
	await get_tree().create_timer(2.0).timeout

	var saved_checkpoint := checkpoint_position

	player_health = MAX_HEALTH
	player_armor = 0.0
	health_changed.emit(player_health)
	armor_changed.emit(player_armor)
	_dying = false

	get_tree().paused = false
	get_tree().reload_current_scene()

	# Wait for the reloaded scene to be fully ready (its _ready may reset
	# checkpoint_position to the level start), then restore our checkpoint.
	await get_tree().process_frame
	await get_tree().process_frame

	if saved_checkpoint != Vector3.ZERO:
		checkpoint_position = saved_checkpoint

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and checkpoint_position != Vector3.ZERO:
		var player := players[0] as Node3D
		if player != null:
			player.global_position = checkpoint_position


# ---------------------------------------------------------------------------
# Level flow
# ---------------------------------------------------------------------------

func complete_level() -> void:
	if _level_complete:
		return
	_level_complete = true
	level_completed.emit()
	get_tree().paused = false
	if ResourceLoader.exists(END_OF_DEMO_SCENE):
		pending_scene = END_OF_DEMO_SCENE
		get_tree().change_scene_to_file(LOADING_SCREEN_SCENE)


func new_game() -> void:
	player_health = MAX_HEALTH
	player_armor = 0.0
	checkpoint_position = Vector3.ZERO
	_dying = false
	_level_complete = false
	health_changed.emit(player_health)
	armor_changed.emit(player_armor)
	get_tree().paused = false
	if ResourceLoader.exists(OPENING_CUTSCENE_SCENE):
		pending_scene = OPENING_CUTSCENE_SCENE
		get_tree().change_scene_to_file(LOADING_SCREEN_SCENE)


# ---------------------------------------------------------------------------
# Pause handling (gameplay scenes only)
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if get_tree().paused:
		return  # PauseMenu handles its own close.
	var current := get_tree().current_scene
	if current == null or not current.is_in_group("gameplay"):
		return
	_open_pause_menu(current)
	get_viewport().set_input_as_handled()


func _open_pause_menu(scene_root: Node) -> void:
	if is_instance_valid(_pause_menu):
		return
	if not ResourceLoader.exists(PAUSE_MENU_SCENE):
		return
	var packed := ResourceLoader.load(PAUSE_MENU_SCENE) as PackedScene
	if packed == null:
		return
	_pause_menu = packed.instantiate()
	scene_root.add_child(_pause_menu)
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
