extends CharacterBody3D

## Source/HL2-feel first-person controller.
## Walk/sprint/crouch, mouse look, view bob, footsteps, fall landing,
## damage forwarding to GameManager.

const WALK_SPEED: float = 4.3
const SPRINT_SPEED: float = 6.1
const CROUCH_SPEED: float = 2.0
const JUMP_VELOCITY: float = 4.6
const GRAVITY: float = 15.0
const ACCEL: float = 10.0
const AIR_ACCEL: float = 2.5

const STAND_HEAD_Y: float = 1.6
const CROUCH_HEAD_Y: float = 1.0
const STAND_CAPSULE_H: float = 1.8
const CROUCH_CAPSULE_H: float = 1.2

const SPRINT_FOV_BOOST: float = 7.0
const BOB_AMPLITUDE: float = 0.04
const FOOTSTEP_INTERVAL: float = 0.45
const HARD_LAND_VELOCITY: float = 8.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var footstep_player: AudioStreamPlayer = $FootstepPlayer

var pitch: float = 0.0
var is_crouching: bool = false
var is_sprinting: bool = false

var _bob_time: float = 0.0
var _footstep_timer: float = 0.0
var _footstep_index: int = 0
var _footstep_streams: Array[AudioStream] = []
var _pain_streams: Array[AudioStream] = []
var _land_stream: AudioStream = null
var _was_on_floor: bool = true
var _prev_velocity_y: float = 0.0
var _land_dip: float = 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_load_sounds()


# ---------------------------------------------------------------------------
# Sound loading (all guarded — missing files are skipped silently)
# ---------------------------------------------------------------------------

func _load_sounds() -> void:
	var footstep_candidates: Array[String] = [
		"res://sounds/player/footsteps/concrete1.wav",
		"res://sounds/player/footsteps/concrete2.wav",
		"res://sounds/player/footsteps/concrete3.wav",
		"res://sounds/player/footsteps/concrete4.wav",
		# EP2 repo has no player footstep set — combine gear foley reads as
		# boots + kit at low volume and cycles well.
		"res://sounds/npc/zombine/gear1.wav",
		"res://sounds/npc/zombine/gear2.wav",
		"res://sounds/npc/zombine/gear3.wav",
		"res://sounds/npc/combine_soldier/zipline_clothing1.wav",
	]
	for path in footstep_candidates:
		var s := _try_load(path)
		if s != null:
			_footstep_streams.append(s)

	var pain_candidates: Array[String] = [
		"res://sounds/player/pain1.wav",
		"res://sounds/player/pain2.wav",
		"res://sounds/npc/ministrider/body_medium_impact_hard1.wav",
		"res://sounds/npc/ministrider/body_medium_impact_hard3.wav",
	]
	for path in pain_candidates:
		var s := _try_load(path)
		if s != null:
			_pain_streams.append(s)

	for path in [
		"res://sounds/player/land1.wav",
		"res://sounds/npc/combine_soldier/zipline_hitground1.wav",
	]:
		var s := _try_load(path)
		if s != null:
			_land_stream = s
			break
	if _land_stream == null and _footstep_streams.size() > 0:
		_land_stream = _footstep_streams[0]


func _try_load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens: float = GameManager.mouse_sensitivity
		rotate_y(-motion.relative.x * sens)
		pitch = clampf(pitch - motion.relative.y * sens, deg_to_rad(-89.0), deg_to_rad(89.0))
		head.rotation.x = pitch


# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_prev_velocity_y = velocity.y

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	_update_crouch(delta)

	var moving_forward := input_dir.y < -0.1
	is_sprinting = (
		Input.is_action_pressed("sprint")
		and moving_forward
		and not is_crouching
		and is_on_floor()
	)

	var speed := WALK_SPEED
	if is_crouching:
		speed = CROUCH_SPEED
	elif is_sprinting:
		speed = SPRINT_SPEED

	if is_on_floor():
		# Ground: friction-style lerp toward wish velocity.
		var target := wish_dir * speed
		velocity.x = lerpf(velocity.x, target.x, ACCEL * delta)
		velocity.z = lerpf(velocity.z, target.z, ACCEL * delta)
		if Input.is_action_just_pressed("jump") and not is_crouching:
			velocity.y = JUMP_VELOCITY
	else:
		# Air: weak acceleration, keep momentum.
		velocity.x += wish_dir.x * speed * AIR_ACCEL * delta
		velocity.z += wish_dir.z * speed * AIR_ACCEL * delta
		var horizontal := Vector2(velocity.x, velocity.z)
		if horizontal.length() > SPRINT_SPEED:
			horizontal = horizontal.normalized() * SPRINT_SPEED
			velocity.x = horizontal.x
			velocity.z = horizontal.y

	move_and_slide()

	_update_fov(delta)
	_update_view_bob(delta)
	_update_footsteps(delta)
	_check_landing()
	_was_on_floor = is_on_floor()


func _update_crouch(delta: float) -> void:
	var wants_crouch := Input.is_action_pressed("crouch")
	if wants_crouch:
		is_crouching = true
	elif is_crouching and _can_stand():
		is_crouching = false

	var target_h := CROUCH_CAPSULE_H if is_crouching else STAND_CAPSULE_H
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule != null and absf(capsule.height - target_h) > 0.001:
		capsule.height = lerpf(capsule.height, target_h, 12.0 * delta)
		collision_shape.position.y = capsule.height * 0.5


func _can_stand() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0.0, CROUCH_CAPSULE_H - 0.1, 0.0)
	var to := global_position + Vector3(0.0, STAND_CAPSULE_H + 0.05, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var result := space.intersect_ray(query)
	return result.is_empty()


func _update_fov(delta: float) -> void:
	var base: float = GameManager.base_fov
	var target := base + SPRINT_FOV_BOOST if is_sprinting else base
	camera.fov = lerpf(camera.fov, target, 8.0 * delta)


func _update_view_bob(delta: float) -> void:
	var target_head_y := CROUCH_HEAD_Y if is_crouching else STAND_HEAD_Y
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()

	var bob_offset := 0.0
	if is_on_floor() and horizontal_speed > 0.5:
		_bob_time += delta * horizontal_speed * 2.2
		bob_offset = sin(_bob_time) * BOB_AMPLITUDE
	else:
		_bob_time = 0.0

	# Landing dip recovers toward 0.
	_land_dip = lerpf(_land_dip, 0.0, 8.0 * delta)

	var desired_y := target_head_y + bob_offset - _land_dip
	head.position.y = lerpf(head.position.y, desired_y, 10.0 * delta)


func _update_footsteps(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or horizontal_speed < 1.0:
		_footstep_timer = 0.0
		return

	var interval := FOOTSTEP_INTERVAL
	if is_sprinting:
		interval = 0.34
	elif is_crouching:
		interval = 0.62

	_footstep_timer += delta
	if _footstep_timer >= interval:
		_footstep_timer = 0.0
		_play_footstep()


func _play_footstep() -> void:
	if _footstep_streams.is_empty():
		return
	footstep_player.stream = _footstep_streams[_footstep_index % _footstep_streams.size()]
	_footstep_index += 1
	footstep_player.volume_db = -16.0
	footstep_player.pitch_scale = randf_range(0.92, 1.08)
	footstep_player.play()


func _check_landing() -> void:
	if is_on_floor() and not _was_on_floor and _prev_velocity_y < -HARD_LAND_VELOCITY:
		_land_dip = 0.12
		if _land_stream != null:
			footstep_player.stream = _land_stream
			footstep_player.volume_db = -8.0
			footstep_player.pitch_scale = randf_range(0.9, 1.0)
			footstep_player.play()


# ---------------------------------------------------------------------------
# Damage
# ---------------------------------------------------------------------------

func take_damage(amount: float) -> void:
	GameManager.apply_damage(amount)
	if not _pain_streams.is_empty():
		var stream := _pain_streams[randi() % _pain_streams.size()]
		footstep_player.stream = stream
		footstep_player.volume_db = -6.0
		footstep_player.pitch_scale = 1.0
		footstep_player.play()
