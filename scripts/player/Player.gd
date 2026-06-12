extends CharacterBody3D

## Source/HL2-feel first-person controller.
## Walk/sprint/crouch, mouse look, view bob, footsteps, fall landing,
## damage forwarding to GameManager.

const WALK_SPEED: float = 4.3
const SPRINT_SPEED: float = 6.1
const CROUCH_SPEED: float = 2.0
const JUMP_VELOCITY: float = 4.6
const GRAVITY: float = 15.0
# Source engine movement (sv_accelerate=10, sv_friction=4, sv_airaccelerate=10,
# sv_stopspeed=100u). Quake-style accelerate gives instant, snappy direction
# changes on the ground; friction stops the player in ~0.2 s on key release.
const ACCEL: float = 10.0
const FRICTION: float = 4.0
const STOP_SPEED: float = 1.9   # 100 units/s — boosts friction at low speeds
const AIR_ACCEL: float = 10.0
const AIR_SPEED_CAP: float = 0.6  # 30 units/s wishspeed cap while airborne

const STAND_HEAD_Y: float = 1.6
const CROUCH_HEAD_Y: float = 1.0
const STAND_CAPSULE_H: float = 1.8
const CROUCH_CAPSULE_H: float = 1.2

const BASE_FOV: float = 90.0
const SPRINT_FOV: float = 95.0
const BOB_AMPLITUDE_V: float = 0.015
const BOB_AMPLITUDE_H: float = 0.007
const BOB_FREQ_WALK: float = 2.0    # Hz
const BOB_FREQ_SPRINT: float = 2.5  # Hz
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
var _bob_blend: float = 0.0
var _head_base_y: float = STAND_HEAD_Y
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
	# Upgrade the old narrow default to the HL2-style 90° base FOV while
	# still respecting a value the player has changed in the options menu.
	if is_equal_approx(GameManager.base_fov, 75.0):
		GameManager.base_fov = BASE_FOV
	camera.fov = GameManager.base_fov
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
		# Source-style ground move: friction first, then Quake accelerate.
		_apply_friction(delta)
		_accelerate(wish_dir, speed, ACCEL, delta)
		if Input.is_action_just_pressed("jump") and not is_crouching:
			velocity.y = JUMP_VELOCITY
	else:
		# Air: sv_airaccelerate-style — small capped wishspeed, no friction,
		# momentum is preserved (allows HL2-like air control / strafing).
		_accelerate(wish_dir, minf(speed, AIR_SPEED_CAP), AIR_ACCEL, delta)

	move_and_slide()

	_update_fov(delta)
	_update_view_bob(delta)
	_update_footsteps(delta)
	_check_landing()
	_was_on_floor = is_on_floor()


# Quake/Source accelerate: project current velocity onto the wish direction
# and only add the missing speed, capped by accel * wish_speed * delta.
# Turning never costs speed, so direction changes feel instant.
func _accelerate(wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> void:
	if wish_dir == Vector3.ZERO or wish_speed <= 0.0:
		return
	var current := velocity.x * wish_dir.x + velocity.z * wish_dir.z
	var add_speed := wish_speed - current
	if add_speed <= 0.0:
		return
	var accel_speed := minf(accel * wish_speed * delta, add_speed)
	velocity.x += wish_dir.x * accel_speed
	velocity.z += wish_dir.z * accel_speed


# Source friction (sv_friction=4 with stopspeed): exponential decay at speed,
# linear snap to zero below STOP_SPEED — releasing keys stops in ~0.2 s.
func _apply_friction(delta: float) -> void:
	var horizontal := Vector2(velocity.x, velocity.z)
	var speed := horizontal.length()
	if speed < 0.01:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var control := maxf(speed, STOP_SPEED)
	var drop := control * FRICTION * delta
	var new_speed := maxf(speed - drop, 0.0) / speed
	velocity.x *= new_speed
	velocity.z *= new_speed


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
	var target := base + (SPRINT_FOV - BASE_FOV) if is_sprinting else base
	camera.fov = lerpf(camera.fov, target, 8.0 * delta)


func _update_view_bob(delta: float) -> void:
	var target_head_y := CROUCH_HEAD_Y if is_crouching else STAND_HEAD_Y
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()

	# Bob amplitude blends in/out quickly so starting and stopping never pops,
	# but the offset itself is applied directly each frame — no camera lag.
	var moving := is_on_floor() and horizontal_speed > 0.5
	_bob_blend = move_toward(_bob_blend, 1.0 if moving else 0.0, delta * 8.0)
	if moving:
		var freq := BOB_FREQ_SPRINT if is_sprinting else BOB_FREQ_WALK
		_bob_time += delta * TAU * freq
	elif _bob_blend <= 0.0:
		_bob_time = 0.0

	var bob_v := sin(_bob_time) * BOB_AMPLITUDE_V * _bob_blend
	var bob_h := sin(_bob_time * 0.5) * BOB_AMPLITUDE_H * _bob_blend

	# Landing dip recovers toward 0.
	_land_dip = lerpf(_land_dip, 0.0, 8.0 * delta)

	# Smooth only the crouch height transition; bob is unsmoothed.
	_head_base_y = lerpf(_head_base_y, target_head_y, 10.0 * delta)
	head.position.y = _head_base_y + bob_v - _land_dip
	camera.position.x = bob_h


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
