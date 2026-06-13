extends CharacterBody3D

## HL2-style NPC brain. Modeled on Source's schedule/task AI:
##  - Senses: forward vision cone (120° h / 80° v, 20 m) + hearing (12 m)
##  - Memory: remembers the enemy's last known position for 5 s and goes
##    there to SEARCH before disengaging
##  - Idle "actbusy": random look-arounds, short wanders, wall leaning
##  - Combat: burst fire, cover seeking when shot, occasional flanking,
##    squad coordination (closer NPC advances, farther one suppresses)

const GRAVITY: float = 20.0
const MOVE_SPEED: float = 3.5
const WANDER_SPEED: float = 1.7
const DETECTION_RANGE: float = 20.0
const ATTACK_RANGE: float = 15.0
const BULLET_DAMAGE: float = 10.0

# --- Senses ---
const VISION_HALF_ANGLE_H: float = 60.0   # deg; 120° total horizontal cone
const VISION_HALF_ANGLE_V: float = 40.0   # deg; 80° total vertical cone
const POINT_BLANK_RANGE: float = 2.5      # inside this, the cone is ignored
const HEARING_RANGE: float = 12.0         # gunfire / sprinting player
const MEMORY_TIME: float = 5.0            # how long the last-seen pos persists
const SEARCH_LOOK_TIME: float = 3.0       # look-around time at the search spot

# HL2-style burst fire: 2-4 aimed shots, then a 1-2 s pause (often spent
# repositioning), instead of a metronomic shot every 1.5 s.
const BURST_SHOT_INTERVAL: float = 0.22
const BURST_PAUSE_MIN: float = 1.0
const BURST_PAUSE_MAX: float = 2.0
const FACING_DOT_MIN: float = 0.9       # only fire within ~25 deg of target
const COMBAT_GIVE_UP_RANGE: float = 30.0
const STRAFE_TIME: float = 0.8          # reposition burst length between volleys

# --- Combat maneuvers ---
const COVER_SEARCH_RADIUS: float = 6.0
const FLANK_CHANCE: float = 0.2
const SQUAD_RANGE: float = 15.0
const STAGGER_TIME: float = 0.3         # stumble backward when hit
const LEAN_CHANCE: float = 0.3

## Real HL2 character models per faction (round-robin for variety).
## Imported MDLs come in at 0.02 scale; 1.27 restores true HL2 size (~1.83 m).
## Only models whose materials actually ship in EP1/EP2 are cast here —
## eli/kleiner/gman are missing face or body textures and render white.
const FACTION_MODELS: Dictionary = {
	"resistance": ["res://models/alyx.mdl", "res://models/mossman.mdl", "res://models/magnusson.mdl"],
	"hecu": ["res://models/barney.mdl"],
}
const MODEL_SCALE: float = 1.27
static var _model_round_robin: Dictionary = {}

## NPC-held weapon (same w_ model the player uses, child of the R hand bone).
const NPC_GUN_MDL := "res://models/weapons/w_alyx_gun.mdl"

## Real HL2 EP1 citizen voice cues (scripts/npc_sounds_citizen_ep1.txt maps
## ep1_citizen.* entries to vo/episode_1/npc/$gender01/*.wav — those wavs
## shipped and live under res://sounds/vo/episode_1/npc/<gender>/).
const VOICE_DIR := "res://sounds/vo/episode_1/npc/%s/%s.wav"
const VOICE_LINES: Dictionary = {
	"alert": ["cit_alert_soldier01", "cit_alert_soldier02", "cit_alert_soldier03",
		"cit_alert_soldier04", "cit_alert_soldier05"],
	"pain": ["cit_pain01", "cit_pain02", "cit_pain03", "cit_pain04",
		"cit_pain05", "cit_pain06"],
	"death": ["cit_pain07", "cit_pain08", "cit_pain09", "cit_pain10"],
	"taunt": ["cit_kill01", "cit_kill02", "cit_kill03", "cit_kill04",
		"cit_kill05", "cit_kill06", "cit_kill07", "cit_kill08"],
	"search": ["cit_heyoverhere", "cit_theyfoundus", "cit_itsaraid"],
}

@export var waypoints: Array[Vector3] = []
@export var npc_name: String = "NPC"
@export var faction: String = "neutral"
@export var voice_file_prefix: String = ""
@export var is_friendly: bool = false
## When true the NPC ignores player detection and just follows its waypoints.
## Used by cinematics / the movie capture harness to stage clean walk cycles.
@export var scripted_patrol: bool = false

enum State { IDLE, PATROL, ALERT, COMBAT, DEAD, SEARCH }
enum IdleMode { STAND, TURN, WANDER, GO_LEAN, LEAN }
enum CombatMode { NORMAL, FLANK, GO_COVER, DUCK, POPUP }

var health: float = 100.0
var current_state: State = State.IDLE
var player_ref: CharacterBody3D = null
var current_waypoint: int = 0
var waypoint_timer: float = 0.0

# Burst-fire bookkeeping
var _burst_shots_left: int = 0
var _burst_cooldown: float = 0.5
var _shot_timer: float = 0.0
var _strafe_dir: float = 1.0
var _strafe_timer: float = 0.0

# Senses / memory
var _last_known_pos: Vector3 = Vector3.ZERO
var _memory_timer: float = 0.0
var _stimulus_pos: Vector3 = Vector3.ZERO

# Idle actbusy
var _idle_mode: IdleMode = IdleMode.STAND
var _idle_timer: float = 0.0
var _idle_target: Vector3 = Vector3.ZERO
var _turn_dir: Vector3 = Vector3.ZERO
var _lean_normal: Vector3 = Vector3.ZERO

# Combat maneuvers
var _combat_mode: CombatMode = CombatMode.NORMAL
var _cover_point: Vector3 = Vector3.ZERO
var _cover_timer: float = 0.0
var _cover_cooldown: float = 0.0
var _flank_point: Vector3 = Vector3.ZERO
var _flank_timer: float = 0.0
var _stagger_timer: float = 0.0
var _stagger_dir: Vector3 = Vector3.ZERO
var _squad_role_timer: float = 0.0
var _squad_suppress: bool = false   # true: hold position, covering fire

var _alert_timer: float = 0.0
var _alert_voice_played: bool = false
var _search_timer: float = 0.0
var _search_arrived: bool = false
var _nav_agent: NavigationAgent3D = null
var _los_ray: RayCast3D = null
var _audio: AudioStreamPlayer3D = null
var _mesh_instance: MeshInstance3D = null
var _model_node: Node3D = null
var _collision_shape: CollisionShape3D = null
var _combat_taunt_timer: float = 0.0
var _animator: NPCAnimator = null
var _voice_gender: String = "male01"
var _gun_node: Node3D = null

# Talking animation state
var _talk_tween: Tween = null
var _talk_skeleton: Skeleton3D = null
var _jaw_bone_idx: int = -1
var _jaw_rest_pose: Transform3D = Transform3D.IDENTITY
var _talk_node: Node3D = null
var _talk_base_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	_setup_nodes()
	_find_player()
	_idle_timer = randf_range(1.0, 4.0)


func _setup_nodes() -> void:
	# NavigationAgent3D
	_nav_agent = get_node_or_null("NavigationAgent3D")
	if _nav_agent == null:
		_nav_agent = NavigationAgent3D.new()
		_nav_agent.name = "NavigationAgent3D"
		add_child(_nav_agent)

	# RayCast3D for line of sight
	_los_ray = get_node_or_null("LOSRay")
	if _los_ray == null:
		_los_ray = RayCast3D.new()
		_los_ray.name = "LOSRay"
		_los_ray.target_position = Vector3(0, 0, -20)
		_los_ray.collision_mask = 1
		add_child(_los_ray)

	# AudioStreamPlayer3D
	_audio = get_node_or_null("AudioStreamPlayer3D")
	if _audio == null:
		_audio = AudioStreamPlayer3D.new()
		_audio.name = "AudioStreamPlayer3D"
		_audio.unit_size = 6.0
		_audio.max_distance = 30.0
		add_child(_audio)

	# Visuals: real HL2 character model when available, capsule fallback.
	_build_visuals()
	_setup_talk_targets()

	# CollisionShape3D
	_collision_shape = get_node_or_null("CollisionShape3D")
	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "CollisionShape3D"
		var capsule_shape := CapsuleShape3D.new()
		capsule_shape.height = 1.8
		capsule_shape.radius = 0.4
		_collision_shape.shape = capsule_shape
		_collision_shape.position = Vector3(0, 0.9, 0)
		add_child(_collision_shape)


func _build_visuals() -> void:
	# Try a real character model for this faction. Collision is stripped from
	# the imported scene so the gameplay capsule keeps handling bullets/movement.
	var paths: Array = FACTION_MODELS.get(faction, [])
	if paths.size() > 0:
		var idx: int = _model_round_robin.get(faction, 0)
		_model_round_robin[faction] = idx + 1
		var path: String = paths[idx % paths.size()]
		_voice_gender = "female01" if (path.contains("alyx") or path.contains("mossman")) else "male01"
		_model_node = SourceMaterials.spawn_model(self, path, Vector3.ZERO, 180.0, MODEL_SCALE, true)

	if _model_node != null:
		_animator = NPCAnimator.attach(_model_node)
		_attach_weapon()
		return

	# Fallback: legacy capsule
	_mesh_instance = get_node_or_null("MeshInstance3D")
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "MeshInstance3D"
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.4
		capsule.height = 1.8
		_mesh_instance.mesh = capsule
		_mesh_instance.position = Vector3(0, 0.9, 0)
		add_child(_mesh_instance)

	var mat := StandardMaterial3D.new()
	if faction == "resistance":
		mat.albedo_color = Color(0.2, 0.5, 0.2)
	else:
		mat.albedo_color = Color(0.5, 0.5, 0.5)
	_mesh_instance.material_override = mat


## Put the real w_alyx_gun model in the right hand via a BoneAttachment3D so
## it follows every animated pose (instead of a gun that just "appears").
func _attach_weapon() -> void:
	if is_friendly or _animator == null:
		return
	var skel := _animator.get_skeleton()
	var hand_idx := _animator.get_bone_idx("r_hand")
	if skel == null or hand_idx < 0:
		return
	var att := BoneAttachment3D.new()
	att.name = "GunAttachment"
	skel.add_child(att)
	att.bone_name = skel.get_bone_name(hand_idx)
	# Model scale: the attachment already inherits the character's 1.27, so the
	# gun spawns at ~1.0. Offset/rotation tuned against the ValveBiped R_Hand
	# bone axes (verified visually via probe renders).
	_gun_node = SourceMaterials.spawn_model(att, NPC_GUN_MDL, Vector3.ZERO, 0.0, 1.0, true)
	if _gun_node != null:
		_gun_node.position = Vector3(0.045, 0.03, 0.0)
		_gun_node.rotation_degrees = Vector3(-90.0, 0.0, 90.0)


# ---------------------------------------------------------------------------
# Talking animation — jaw bone when the model has one, head/body bob otherwise
# ---------------------------------------------------------------------------

func _setup_talk_targets() -> void:
	_talk_node = _model_node if _model_node != null else _mesh_instance
	if _talk_node != null:
		_talk_base_scale = _talk_node.scale
	if _model_node == null:
		return
	var skel := _model_node.find_children("*", "Skeleton3D", true, false)
	for s in skel:
		var skeleton := s as Skeleton3D
		for i in skeleton.get_bone_count():
			var bone_name := skeleton.get_bone_name(i).to_lower()
			if bone_name.contains("jaw") or bone_name.contains("mouth"):
				_talk_skeleton = skeleton
				_jaw_bone_idx = i
				_jaw_rest_pose = skeleton.get_bone_pose(i)
				return


## Animate speech for `duration` seconds: drive the jaw bone if the imported
## MDL skeleton has one, else do a subtle ~6 Hz scale bob on the visual node.
func _start_talking(duration: float) -> void:
	_stop_talking()
	if _talk_node == null and _jaw_bone_idx < 0:
		_setup_talk_targets()
	duration = maxf(duration, 0.25)
	var cycle := 1.0 / 6.0
	var cycles := maxi(1, int(round(duration / cycle)))

	_talk_tween = create_tween()
	_talk_tween.set_loops(cycles)
	if _talk_skeleton != null and _jaw_bone_idx >= 0:
		_talk_tween.tween_method(_set_jaw_open, 0.0, 1.0, cycle * 0.5)
		_talk_tween.tween_method(_set_jaw_open, 1.0, 0.0, cycle * 0.5)
	elif _talk_node != null:
		var open_scale := _talk_base_scale * Vector3(1.0, 1.05, 1.0)
		_talk_tween.tween_property(_talk_node, "scale", open_scale, cycle * 0.5)
		_talk_tween.tween_property(_talk_node, "scale", _talk_base_scale, cycle * 0.5)
	else:
		_talk_tween.kill()
		_talk_tween = null
		return
	_talk_tween.finished.connect(_stop_talking)


func _stop_talking() -> void:
	if _talk_tween != null:
		_talk_tween.kill()
		_talk_tween = null
	if _talk_skeleton != null and _jaw_bone_idx >= 0:
		_talk_skeleton.set_bone_pose(_jaw_bone_idx, _jaw_rest_pose)
	if _talk_node != null and is_instance_valid(_talk_node):
		_talk_node.scale = _talk_base_scale


func _set_jaw_open(amount: float) -> void:
	if _talk_skeleton == null or _jaw_bone_idx < 0:
		return
	var pose := _jaw_rest_pose
	pose.basis = pose.basis * Basis(Vector3.RIGHT, deg_to_rad(18.0) * amount)
	_talk_skeleton.set_bone_pose(_jaw_bone_idx, pose)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0] as CharacterBody3D


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	_cover_cooldown = maxf(0.0, _cover_cooldown - delta)

	# Damage stagger overrides everything: 0.3 s stumble backward.
	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		velocity.x = _stagger_dir.x * 2.6
		velocity.z = _stagger_dir.z * 2.6
	else:
		_run_state_machine(delta)
	move_and_slide()
	_update_animation()


func _update_animation() -> void:
	if _animator == null:
		return
	var hspeed := Vector2(velocity.x, velocity.z).length()
	_animator.set_speed(hspeed)
	match current_state:
		State.DEAD:
			_animator.set_pose(NPCAnimator.Pose.DEAD)
		State.COMBAT:
			if _combat_mode == CombatMode.DUCK:
				_animator.set_pose(NPCAnimator.Pose.CROUCH)
			elif _combat_mode == CombatMode.FLANK or _combat_mode == CombatMode.GO_COVER:
				# Running a maneuver: gun at low-ready, legs driving
				_animator.set_pose(NPCAnimator.Pose.WALK if hspeed > 0.3 else NPCAnimator.Pose.COMBAT)
			else:
				# Default combat stance: gun raised in a two-handed aim
				_animator.set_pose(NPCAnimator.Pose.COMBAT_AIM)
				_animator.set_aim_pitch(_aim_pitch_to_target())
		State.ALERT, State.SEARCH:
			if hspeed > 0.3:
				_animator.set_pose(NPCAnimator.Pose.COMBAT)  # low-ready advance
			else:
				_animator.set_pose(NPCAnimator.Pose.COMBAT)
		_:
			if current_state == State.IDLE and _idle_mode == IdleMode.LEAN and hspeed <= 0.3:
				_animator.set_pose(NPCAnimator.Pose.LEAN)
			elif hspeed > 0.3:
				_animator.set_pose(NPCAnimator.Pose.WALK)
			else:
				_animator.set_pose(NPCAnimator.Pose.IDLE)


## Vertical angle from the chest to the enemy, for the aiming-arms pitch.
func _aim_pitch_to_target() -> float:
	if player_ref == null:
		return 0.0
	var to := (player_ref.global_position + Vector3(0, 0.9, 0)) - (global_position + Vector3(0, 1.3, 0))
	var flat := Vector2(to.x, to.z).length()
	if flat < 0.1:
		return 0.0
	return atan2(to.y, flat)


func _run_state_machine(delta: float) -> void:
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.PATROL:
			_state_patrol(delta)
		State.ALERT:
			_state_alert(delta)
		State.COMBAT:
			_state_combat(delta)
		State.SEARCH:
			_state_search(delta)


# ---------------------------------------------------------------------------
# Senses
# ---------------------------------------------------------------------------

## Real HL2-style sight: range + forward vision cone + line of sight.
## No detection behind the NPC's back or through walls.
func _can_see_player() -> bool:
	if player_ref == null:
		_find_player()
		if player_ref == null:
			return false
	var eye := global_position + Vector3(0, 1.6, 0)
	var target := player_ref.global_position + Vector3(0, 0.8, 0)
	var to := target - eye
	var dist := to.length()
	if dist > DETECTION_RANGE:
		return false
	if dist > POINT_BLANK_RANGE:
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length() > 0.01:
			if _facing_forward().angle_to(flat.normalized()) > deg_to_rad(VISION_HALF_ANGLE_H):
				return false
			if absf(atan2(to.y, flat.length())) > deg_to_rad(VISION_HALF_ANGLE_V):
				return false
	return _los_clear_to(target)


## Hearing: gunshots and sprinting feet pull idle NPCs into ALERT even with
## no visual. Broadcast via get_tree().call_group("npc", "hear_sound", ...).
func hear_sound(pos: Vector3, loudness_range: float = HEARING_RANGE) -> void:
	if current_state == State.DEAD or is_friendly or scripted_patrol:
		return
	if global_position.distance_to(pos) > loudness_range:
		return
	_last_known_pos = pos
	_memory_timer = MEMORY_TIME
	if current_state == State.IDLE or current_state == State.PATROL:
		_stimulus_pos = pos
		_go_alert()
	elif current_state == State.SEARCH:
		_search_arrived = false  # re-route to the newest noise


func _go_alert() -> void:
	current_state = State.ALERT
	_alert_timer = 0.0
	_alert_voice_played = false
	_idle_mode = IdleMode.STAND


## Pure LOS check toward the player (no distance/cone gate) for combat logic.
func _has_line_of_sight() -> bool:
	if player_ref == null:
		return false
	return _los_clear_to(player_ref.global_position + Vector3(0, 0.9, 0))


func _los_clear_to(world_point: Vector3) -> bool:
	_los_ray.target_position = to_local(world_point)
	_los_ray.force_raycast_update()
	if _los_ray.is_colliding():
		var collider := _los_ray.get_collider()
		return collider != null and collider.is_in_group("player")
	return true


## Poll-based hearing for the sprinting player (no event hook needed).
func _check_player_noise() -> void:
	if player_ref == null or scripted_patrol:
		return
	var hvel := Vector2(player_ref.velocity.x, player_ref.velocity.z).length()
	if hvel > 5.0 and global_position.distance_to(player_ref.global_position) <= HEARING_RANGE:
		hear_sound(player_ref.global_position)


# ---------------------------------------------------------------------------
# IDLE — actbusy-style life: look around, wander, lean on walls
# ---------------------------------------------------------------------------

func _state_idle(delta: float) -> void:
	if not scripted_patrol and _can_see_player():
		_stimulus_pos = player_ref.global_position
		_go_alert()
		return
	_check_player_noise()

	if waypoints.size() > 0:
		velocity.x = 0.0
		velocity.z = 0.0
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			current_state = State.PATROL
		return

	match _idle_mode:
		IdleMode.STAND:
			velocity.x = lerp(velocity.x, 0.0, 0.3)
			velocity.z = lerp(velocity.z, 0.0, 0.3)
			_idle_timer -= delta
			if _idle_timer <= 0.0:
				_pick_idle_activity()
		IdleMode.TURN:
			velocity.x = 0.0
			velocity.z = 0.0
			_face_direction(_turn_dir, delta)
			_idle_timer -= delta
			if _idle_timer <= 0.0:
				_idle_mode = IdleMode.STAND
				_idle_timer = randf_range(2.0, 5.0)
		IdleMode.WANDER, IdleMode.GO_LEAN:
			var to := _idle_target - global_position
			to.y = 0.0
			if to.length() < 0.5 or _idle_timer <= 0.0:
				if _idle_mode == IdleMode.GO_LEAN:
					_idle_mode = IdleMode.LEAN
					_idle_timer = randf_range(6.0, 12.0)
					# Face along the wall (perpendicular to its normal)
					_turn_dir = _lean_normal.cross(Vector3.UP)
					if randf() < 0.5:
						_turn_dir = -_turn_dir
					if _animator != null:
						# Tip the shoulder INTO the wall: +1 tilts toward the
						# character's right (probe-verified), so pick the sign
						# from which side the wall ends up on.
						var char_right := _turn_dir.cross(Vector3.UP)
						var wall_dir := -_lean_normal
						_animator.set_lean_side(1.0 if wall_dir.dot(char_right) > 0.0 else -1.0)
				else:
					_idle_mode = IdleMode.STAND
					_idle_timer = randf_range(2.0, 5.0)
				return
			_idle_timer -= delta
			var dir := to.normalized()
			# Steer off obstacles: if the path ahead is blocked, abandon
			if _path_blocked(dir):
				_idle_mode = IdleMode.STAND
				_idle_timer = randf_range(1.0, 3.0)
				return
			velocity.x = dir.x * WANDER_SPEED
			velocity.z = dir.z * WANDER_SPEED
			_face_direction(dir, delta)
		IdleMode.LEAN:
			velocity.x = 0.0
			velocity.z = 0.0
			_face_direction(_turn_dir, delta)
			_idle_timer -= delta
			if _idle_timer <= 0.0:
				_idle_mode = IdleMode.STAND
				_idle_timer = randf_range(2.0, 5.0)


func _pick_idle_activity() -> void:
	var roll := randf()
	if roll < LEAN_CHANCE and _find_lean_wall():
		_idle_mode = IdleMode.GO_LEAN
		_idle_timer = 6.0  # travel budget
		return
	if roll < 0.65:
		# Walk to a random nearby point (3-8 m), pause there
		var found := false
		for attempt in 5:
			var ang := randf() * TAU
			var d := randf_range(3.0, 8.0)
			var candidate := global_position + Vector3(sin(ang), 0.0, cos(ang)) * d
			if _wander_point_clear(candidate):
				_idle_target = candidate
				found = true
				break
		if found:
			_idle_mode = IdleMode.WANDER
			_idle_timer = 8.0  # travel budget
			return
	# Otherwise just turn to face a random direction for a while
	var a := randf() * TAU
	_turn_dir = Vector3(sin(a), 0.0, cos(a))
	_idle_mode = IdleMode.TURN
	_idle_timer = randf_range(2.0, 5.0)


## Cast rays around to find a nearby wall to lean on (actbusy LEAN_BACK).
func _find_lean_wall() -> bool:
	var space := get_world_3d().direct_space_state
	var eye := global_position + Vector3(0, 1.2, 0)
	for i in 8:
		var ang := TAU * i / 8.0
		var dir := Vector3(sin(ang), 0.0, cos(ang))
		var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * 2.5, 1, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var n: Vector3 = hit["normal"]
		if absf(n.y) > 0.3:
			continue  # floor/ramp, not a wall
		var pos: Vector3 = hit["position"]
		_lean_normal = Vector3(n.x, 0.0, n.z).normalized()
		_idle_target = Vector3(pos.x, global_position.y, pos.z) + _lean_normal * 0.42
		return true
	return false


func _wander_point_clear(point: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.0, 0)
	var to := Vector3(point.x, global_position.y + 1.0, point.z)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return space.intersect_ray(q).is_empty()


func _path_blocked(dir: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 1.0, 1, [get_rid()])
	return not space.intersect_ray(q).is_empty()


# ---------------------------------------------------------------------------
# PATROL
# ---------------------------------------------------------------------------

func _state_patrol(delta: float) -> void:
	if waypoints.size() == 0:
		current_state = State.IDLE
		return

	if not scripted_patrol and _can_see_player():
		_stimulus_pos = player_ref.global_position
		_go_alert()
		return
	_check_player_noise()

	var target := waypoints[current_waypoint]
	var dir := (target - global_position)
	dir.y = 0.0
	if dir.length() < 1.0:
		velocity.x = 0.0
		velocity.z = 0.0
		waypoint_timer += delta
		if waypoint_timer >= 1.5:
			waypoint_timer = 0.0
			current_waypoint = (current_waypoint + 1) % waypoints.size()
	else:
		if _nav_agent != null and _nav_agent.is_navigation_finished() == false:
			_nav_agent.target_position = target
			var next := _nav_agent.get_next_path_position()
			var move_dir := (next - global_position)
			move_dir.y = 0.0
			if move_dir.length() > 0.1:
				move_dir = move_dir.normalized()
				velocity.x = move_dir.x * MOVE_SPEED
				velocity.z = move_dir.z * MOVE_SPEED
				_face_direction(move_dir, delta)
		else:
			dir = dir.normalized()
			velocity.x = dir.x * MOVE_SPEED
			velocity.z = dir.z * MOVE_SPEED
			_face_direction(dir, delta)


# ---------------------------------------------------------------------------
# ALERT — reaction beat: face the stimulus, call out, then commit
# ---------------------------------------------------------------------------

func _state_alert(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_face_target(_stimulus_pos, delta)
	if not _alert_voice_played:
		_alert_voice_played = true
		_play_voice("alert_01")
	_alert_timer += delta
	if _alert_timer >= 0.5:
		if _can_see_player():
			_enter_combat()
		else:
			# Heard something / saw something that vanished: go look.
			_start_search(_last_known_pos if _memory_timer > 0.0 else _stimulus_pos)


func _enter_combat() -> void:
	current_state = State.COMBAT
	_combat_mode = CombatMode.NORMAL
	_burst_shots_left = 0
	_burst_cooldown = randf_range(0.3, 0.7)
	if player_ref != null:
		_last_known_pos = player_ref.global_position
		_memory_timer = MEMORY_TIME
	# Occasionally open the engagement by flanking to a side angle.
	if randf() < FLANK_CHANCE and player_ref != null:
		var to_npc := (global_position - player_ref.global_position)
		to_npc.y = 0.0
		var side := to_npc.normalized().cross(Vector3.UP) * (7.0 if randf() < 0.5 else -7.0)
		var candidate := player_ref.global_position + side
		if _wander_point_clear(candidate):
			_flank_point = candidate
			_flank_timer = 5.0
			_combat_mode = CombatMode.FLANK
	# Squads hear their own side opening fire.
	get_tree().call_group("npc", "hear_sound", global_position, HEARING_RANGE)


# ---------------------------------------------------------------------------
# SEARCH — investigate the last known / heard position, then give up
# ---------------------------------------------------------------------------

func _start_search(pos: Vector3) -> void:
	current_state = State.SEARCH
	_stimulus_pos = pos
	_search_arrived = false
	_search_timer = SEARCH_LOOK_TIME
	_play_voice("search_01")


func _state_search(delta: float) -> void:
	if _can_see_player():
		_stimulus_pos = player_ref.global_position
		_enter_combat()
		return

	var to := _stimulus_pos - global_position
	to.y = 0.0
	if not _search_arrived and to.length() > 1.2:
		var dir := to.normalized()
		if _path_blocked(dir):
			_search_arrived = true  # can't get closer; look from here
		else:
			velocity.x = dir.x * MOVE_SPEED
			velocity.z = dir.z * MOVE_SPEED
			_face_direction(dir, delta)
			return
	_search_arrived = true
	velocity.x = 0.0
	velocity.z = 0.0
	# Sweep left/right looking for the target
	_search_timer -= delta
	var sweep := sin(Time.get_ticks_msec() / 1000.0 * 1.6) * deg_to_rad(70.0)
	var base := atan2(-to.x, -to.z) if to.length() > 0.3 else rotation.y
	rotation.y = lerp_angle(rotation.y, base + sweep, 3.0 * delta)
	if _search_timer <= 0.0:
		_memory_timer = 0.0
		current_state = State.PATROL if waypoints.size() > 0 else State.IDLE
		_idle_mode = IdleMode.STAND
		_idle_timer = randf_range(2.0, 4.0)


# ---------------------------------------------------------------------------
# COMBAT
# ---------------------------------------------------------------------------

## HL2-style engagement: track the enemy, fire 2-4 shot bursts with pauses,
## seek cover when shot, occasionally flank, and coordinate with squadmates
## (the closer one advances while the farther one provides covering fire).
func _state_combat(delta: float) -> void:
	if player_ref == null:
		current_state = State.IDLE
		return

	if is_friendly:
		velocity.x = 0.0
		velocity.z = 0.0
		_face_target(player_ref.global_position, delta)
		return

	_combat_taunt_timer += delta

	var target := player_ref.global_position
	var dist := global_position.distance_to(target)
	var has_los := _has_line_of_sight()

	# --- Memory of the enemy position ---
	if has_los and _can_see_player():
		_last_known_pos = target
		_memory_timer = MEMORY_TIME
	else:
		_memory_timer -= delta
		if _memory_timer <= 0.0:
			# Lost them: go search the last place we saw them.
			_start_search(_last_known_pos)
			return

	if dist > COMBAT_GIVE_UP_RANGE:
		current_state = State.PATROL if waypoints.size() > 0 else State.IDLE
		return

	# --- Squad coordination (re-evaluated every 0.5 s) ---
	_squad_role_timer -= delta
	if _squad_role_timer <= 0.0:
		_squad_role_timer = 0.5
		_update_squad_role(dist)

	# Track the enemy with the body whenever we know where they are.
	var aim_pos := target if has_los else _last_known_pos
	_face_target(aim_pos, delta)

	# --- Maneuver modes ---
	match _combat_mode:
		CombatMode.FLANK:
			_flank_timer -= delta
			var to_flank := _flank_point - global_position
			to_flank.y = 0.0
			if _flank_timer <= 0.0 or to_flank.length() < 1.5 or _path_blocked(to_flank.normalized()):
				_combat_mode = CombatMode.NORMAL
			else:
				var fdir := to_flank.normalized()
				velocity.x = fdir.x * MOVE_SPEED
				velocity.z = fdir.z * MOVE_SPEED
				_face_direction(fdir, delta)
				return
		CombatMode.GO_COVER:
			var to_cover := _cover_point - global_position
			to_cover.y = 0.0
			if to_cover.length() < 0.6:
				_combat_mode = CombatMode.DUCK
				_cover_timer = randf_range(1.0, 1.8)
			elif _path_blocked(to_cover.normalized()) and to_cover.length() > 1.0:
				_combat_mode = CombatMode.NORMAL
			else:
				var cdir := to_cover.normalized()
				velocity.x = cdir.x * MOVE_SPEED * 1.15  # sprint for cover
				velocity.z = cdir.z * MOVE_SPEED * 1.15
				_face_direction(cdir, delta)
				return
		CombatMode.DUCK:
			# Hunkered behind cover: no movement, no fire.
			velocity.x = 0.0
			velocity.z = 0.0
			_cover_timer -= delta
			if _cover_timer <= 0.0 or dist < 4.0:
				_combat_mode = CombatMode.POPUP
				_cover_timer = randf_range(1.5, 2.5)
				_burst_shots_left = 0
				_burst_cooldown = 0.15
			return
		CombatMode.POPUP:
			# Up over the cover, firing; then duck again.
			velocity.x = 0.0
			velocity.z = 0.0
			_cover_timer -= delta
			if _cover_timer <= 0.0:
				if dist < 4.0 or not has_los:
					_combat_mode = CombatMode.NORMAL  # cover compromised
				else:
					_combat_mode = CombatMode.DUCK
					_cover_timer = randf_range(1.0, 1.8)
					return
		_:
			pass

	# --- Movement (NORMAL / POPUP firing) ---
	if _combat_mode == CombatMode.NORMAL:
		if (dist > ATTACK_RANGE or not has_los) and not _squad_suppress:
			# Out of range (or sight blocked): press toward the last known spot.
			var dir := aim_pos - global_position
			dir.y = 0.0
			if dir.length() > 0.5:
				dir = dir.normalized()
				velocity.x = dir.x * MOVE_SPEED
				velocity.z = dir.z * MOVE_SPEED
		elif _strafe_timer > 0.0:
			# Reposition sideways between bursts.
			_strafe_timer -= delta
			var right := global_transform.basis.x * _strafe_dir
			velocity.x = right.x * MOVE_SPEED * 0.7
			velocity.z = right.z * MOVE_SPEED * 0.7
		else:
			# Hold position while shooting (suppressors always end up here).
			velocity.x = lerp(velocity.x, 0.0, 0.25)
			velocity.z = lerp(velocity.z, 0.0, 0.25)

	# --- Firing: bursts, only when in range, visible AND actually aimed ---
	var can_fire := dist <= ATTACK_RANGE and has_los and _is_facing(target)
	if _burst_shots_left > 0:
		if can_fire:
			_shot_timer += delta
			if _shot_timer >= BURST_SHOT_INTERVAL:
				_shot_timer = 0.0
				_shoot()
				_burst_shots_left -= 1
				if _burst_shots_left == 0:
					_burst_cooldown = randf_range(BURST_PAUSE_MIN, BURST_PAUSE_MAX)
					if _combat_mode == CombatMode.NORMAL and not _squad_suppress:
						# Sidestep during part of the pause, alternating sides.
						_strafe_dir = 1.0 if randf() < 0.5 else -1.0
						_strafe_timer = STRAFE_TIME
		# else: hold the rest of the burst until back on target
	else:
		_burst_cooldown -= delta
		if _burst_cooldown <= 0.0 and can_fire:
			_burst_shots_left = randi_range(2, 4)
			_shot_timer = BURST_SHOT_INTERVAL  # first shot fires immediately
			# Suppressors fire longer, tighter-spaced volleys (covering fire).
			if _squad_suppress:
				_burst_shots_left = randi_range(4, 6)


## Squad awareness: among same-faction NPCs in COMBAT within 15 m, the one
## closest to the enemy advances while the others hold and provide covering
## fire (a simple read of Source's SQUAD_SLOT_ATTACK / OVERWATCH split).
func _update_squad_role(my_dist: float) -> void:
	_squad_suppress = false
	if player_ref == null:
		return
	for n in get_tree().get_nodes_in_group("npc"):
		if n == self or not (n is CharacterBody3D):
			continue
		if n.get("faction") != faction:
			continue
		if n.get("current_state") != State.COMBAT:
			continue
		if global_position.distance_to(n.global_position) > SQUAD_RANGE:
			continue
		var ally_dist: float = n.global_position.distance_to(player_ref.global_position)
		if ally_dist < my_dist - 0.25:
			# A squadmate is closer: they advance, we hold and cover them.
			_squad_suppress = true
			return


## Find a large prop/barrier within 6 m to duck behind (box query), and verify
## the spot actually breaks the enemy's line of fire before committing.
func _try_seek_cover() -> bool:
	if player_ref == null or _cover_cooldown > 0.0:
		return false
	if _combat_mode == CombatMode.GO_COVER or _combat_mode == CombatMode.DUCK:
		return false
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = COVER_SEARCH_RADIUS
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 0.7, 0))
	params.collision_mask = 1
	params.exclude = [get_rid()]
	var hits := space.intersect_shape(params, 48)

	var player_chest := player_ref.global_position + Vector3(0, 0.9, 0)
	var best_point := Vector3.ZERO
	var best_dist := INF
	for hit in hits:
		var col: Object = hit["collider"]
		if col == null or not (col is Node3D):
			continue
		var node := col as Node3D
		if node.is_in_group("player") or node.is_in_group("npc"):
			continue
		var nm := node.name.to_lower()
		if node.get_parent() != null:
			nm += "/" + String(node.get_parent().name).to_lower()
		if nm.contains("ground") or nm.contains("road") or nm.contains("sidewalk") \
				or nm.contains("floor") or nm.contains("path") or nm.contains("blocker"):
			continue
		var prop_pos := node.global_position
		if absf(prop_pos.y - global_position.y) > 2.0:
			continue
		var flat := prop_pos - global_position
		flat.y = 0.0
		if flat.length() < 0.4:
			continue
		# Candidate: stand behind the prop relative to the enemy (try two
		# stand-off distances; tight first, then a wider fallback).
		var away := prop_pos - player_ref.global_position
		away.y = 0.0
		if away.length() < 0.3:
			continue
		for stand_off: float in [1.1, 1.7]:
			var candidate: Vector3 = prop_pos + away.normalized() * stand_off
			candidate.y = global_position.y
			# Verify: crouching there must break LOS to the enemy chest.
			var q := PhysicsRayQueryParameters3D.create(
				candidate + Vector3(0, 0.6, 0), player_chest, 1, [get_rid()])
			var block := space.intersect_ray(q)
			if block.is_empty() or (block["collider"] != null and (block["collider"] as Node).is_in_group("player")):
				continue  # spot is exposed — not cover
			var d := global_position.distance_to(candidate)
			if d < best_dist:
				best_dist = d
				best_point = candidate
			break
	if best_dist == INF:
		return false
	_cover_point = best_point
	_combat_mode = CombatMode.GO_COVER
	_cover_cooldown = 6.0
	return true


# ---------------------------------------------------------------------------
# Damage / death
# ---------------------------------------------------------------------------

func take_damage(amount: float, from_direction: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DEAD:
		return
	health -= amount
	_play_voice("pain_01")
	_spawn_blood_puff()
	if health <= 0.0:
		_die(from_direction)
		return

	# Flinch: 0.3 s stumble backward + torso/head stagger, whip toward shooter.
	if _animator != null:
		_animator.flinch()
	var shooter_pos := global_position - from_direction
	if from_direction.length_squared() <= 0.0001 and player_ref != null:
		shooter_pos = player_ref.global_position
	_snap_face_target(shooter_pos)
	_stagger_timer = STAGGER_TIME
	_stagger_dir = -_facing_forward()
	_stagger_dir.y = 0.0

	_last_known_pos = shooter_pos
	_memory_timer = MEMORY_TIME
	if current_state != State.COMBAT:
		_enter_combat()
		_burst_cooldown = 0.5  # short reaction beat before returning fire
	else:
		# Already fighting and still being hit: break for the nearest cover.
		_try_seek_cover()
	# Gunfire on our position: squadmates react too.
	get_tree().call_group("npc", "hear_sound", global_position, HEARING_RANGE)


func _spawn_blood_puff() -> void:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.one_shot = true
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector3(0, 0.4, 0)
	p.spread = 60.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -8.0, 0)
	p.scale_amount_min = 0.025
	p.scale_amount_max = 0.06
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.45, 0.05, 0.04)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = m
	p.mesh = mesh
	p.position = Vector3(0, 1.2, 0)
	p.emitting = true
	add_child(p)
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)


func _die(hit_dir: Vector3 = Vector3.ZERO) -> void:
	current_state = State.DEAD
	velocity = Vector3.ZERO
	_play_voice("death_01")
	SubtitleManager.show_subtitle_direct(npc_name + " is down.", 2.0, npc_name)

	# Drop the held weapon so the ragdoll doesn't wave a glued gun around.
	if _gun_node != null and is_instance_valid(_gun_node):
		_gun_node.visible = false

	# Source-style ragdoll: the skeleton hands over to jointed rigid bodies and
	# the corpse crumples under gravity (with knockback from the killing shot).
	var ragdoll := NPCRagdoll.create(self, _model_node, hit_dir)
	if ragdoll != null:
		if _animator != null:
			_animator.set_process(false)  # stop fighting the physics bones
		_stop_talking()
		# Gameplay capsule out of the way immediately so the ragdoll owns the
		# space (deferred: we may be inside the physics flush).
		set_deferred("collision_layer", 0)
		if _collision_shape != null:
			_collision_shape.set_deferred("disabled", true)
		# Let the corpse settle and linger, then clean up (frees the ragdoll too).
		await get_tree().create_timer(12.0).timeout
		queue_free()
		return

	# Fallback (capsule placeholder NPCs): limp pose + tip-over tween.
	if _animator != null:
		_animator.set_speed(0.0)
		_animator.set_pose(NPCAnimator.Pose.DEAD)
	var tween := create_tween()
	tween.tween_property(self, "rotation:x", deg_to_rad(80.0), 0.5)

	# Disable collision after 1s
	await get_tree().create_timer(1.0).timeout
	if _collision_shape != null:
		_collision_shape.disabled = true

	# Queue free after 5s
	await get_tree().create_timer(4.0).timeout
	queue_free()


func _shoot() -> void:
	if player_ref == null:
		return

	# Play shoot sound (alyx gun set — pistol_fire files don't ship in EP2)
	var shoot_path := "res://sounds/weapons/alyx_gun/alyx_gun_fire4.wav"
	AudioManager.play_sfx_at(shoot_path, global_position, -4.0)

	# Muzzle flash at the held gun (falls back to chest height).
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.75, 0.4)
	flash.light_energy = 1.4
	flash.omni_range = 3.5
	if _gun_node != null and is_instance_valid(_gun_node):
		add_child(flash)
		flash.global_position = _gun_node.global_position + _facing_forward() * 0.3
	else:
		flash.position = Vector3(0, 1.35, -0.45)  # character faces local -Z
		add_child(flash)
	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		if is_instance_valid(flash):
			flash.queue_free()
	)

	# Other NPCs hear the shot.
	get_tree().call_group("npc", "hear_sound", global_position, HEARING_RANGE)

	# HL2 NPC fire is inaccurate by design: shots whiff around the player so
	# bursts feel dangerous without being a laser. Hit chance falls with range.
	var dist := global_position.distance_to(player_ref.global_position)
	var hit_chance := clampf(0.8 - dist * 0.03, 0.25, 0.8)
	var aim_point := player_ref.global_position + Vector3(0, 0.9, 0)
	if randf() > hit_chance:
		aim_point += Vector3(
			randf_range(-0.8, 0.8), randf_range(-0.5, 0.7), randf_range(-0.8, 0.8))

	# Raycast check toward player
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.9, 0),
		aim_point,
		0xFFFFFFFF,
		[get_rid()]
	)
	var result := space_state.intersect_ray(query)
	if result.size() > 0:
		var collider = result["collider"]
		if collider != null and collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(BULLET_DAMAGE)


# ---------------------------------------------------------------------------
# Voice — real HL2 EP1 citizen cues (see npc_sounds_citizen_ep1.txt)
# ---------------------------------------------------------------------------

func _play_voice(line_key: String) -> void:
	# Mouth/talk animation timed roughly to the line's subtitle length.
	if current_state != State.DEAD or line_key.begins_with("death"):
		_start_talking(_line_duration(line_key))
	var stream := _resolve_voice_stream(line_key)
	if stream == null and voice_file_prefix != "":
		# Legacy parody-line fallback (mp3 voice packs, if present).
		var voice_path := "res://voice/%s/%s.mp3" % [voice_file_prefix, line_key]
		stream = AudioManager.load_stream(voice_path)
	if stream != null and _audio != null:
		_audio.stream = stream
		_audio.play()


## Map a line family ("alert_01" -> "alert") to a random real HL2 wav.
func _resolve_voice_stream(line_key: String) -> AudioStream:
	var family := line_key.split("_")[0]
	var lines: Array = VOICE_LINES.get(family, [])
	if lines.is_empty():
		return null
	# Try a few random picks; some files may not exist for this gender.
	for attempt in 4:
		var pick: String = lines[randi() % lines.size()]
		var path := VOICE_DIR % [_voice_gender, pick]
		if ResourceLoader.exists(path):
			var stream := AudioManager.load_stream(path)
			if stream != null:
				return stream
	return null


## Approximate subtitle duration for each voice line family.
func _line_duration(line_key: String) -> float:
	if line_key.begins_with("alert"):
		return 2.5
	if line_key.begins_with("taunt"):
		return 2.5
	if line_key.begins_with("pain"):
		return 1.0
	if line_key.begins_with("death"):
		return 2.0
	return 2.0


# ---------------------------------------------------------------------------
# Facing helpers
# ---------------------------------------------------------------------------

## Rotate so the CHARACTER faces `dir`. The MDL model child is spawned with a
## 180° yaw, so the character's visual forward is the node's local -Z (matching
## Godot convention). atan2(-x, -z) points -Z down `dir`.
func _face_direction(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var target_angle := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)


## Instantly snap to face a world position (damage reactions).
func _snap_face_target(target_pos: Vector3) -> void:
	var dir := target_pos - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	rotation.y = atan2(-dir.x, -dir.z)


## Character's visual forward in world space.
func _facing_forward() -> Vector3:
	return -global_transform.basis.z


## True when the character is aimed within ~25 deg of the target (dot > 0.9).
## HL2 NPCs never fire while pointing elsewhere; neither do we.
func _is_facing(target_pos: Vector3, min_dot: float = FACING_DOT_MIN) -> bool:
	var dir := target_pos - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return true
	return _facing_forward().dot(dir.normalized()) > min_dot


func _face_target(target_pos: Vector3, delta: float) -> void:
	var dir := (target_pos - global_position)
	dir.y = 0.0
	_face_direction(dir.normalized(), delta)
