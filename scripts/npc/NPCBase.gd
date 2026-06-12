extends CharacterBody3D

const GRAVITY: float = 20.0
const MOVE_SPEED: float = 3.5
const DETECTION_RANGE: float = 20.0
const ATTACK_RANGE: float = 15.0
const BULLET_DAMAGE: float = 10.0

# HL2-style burst fire: 2-4 aimed shots, then a 1-2 s pause (often spent
# repositioning), instead of a metronomic shot every 1.5 s.
const BURST_SHOT_INTERVAL: float = 0.22
const BURST_PAUSE_MIN: float = 1.0
const BURST_PAUSE_MAX: float = 2.0
const FACING_DOT_MIN: float = 0.9       # only fire within ~25 deg of target
const COMBAT_GIVE_UP_RANGE: float = 30.0
const LOSE_SIGHT_TIME: float = 3.0      # seconds without LOS before disengaging
const STRAFE_TIME: float = 0.8          # reposition burst length between volleys

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

@export var waypoints: Array[Vector3] = []
@export var npc_name: String = "NPC"
@export var faction: String = "neutral"
@export var voice_file_prefix: String = ""
@export var is_friendly: bool = false
## When true the NPC ignores player detection and just follows its waypoints.
## Used by cinematics / the movie capture harness to stage clean walk cycles.
@export var scripted_patrol: bool = false

enum State { IDLE, PATROL, ALERT, COMBAT, DEAD }

var health: float = 100.0
var current_state: State = State.IDLE
var player_ref: CharacterBody3D = null
var current_waypoint: int = 0
var waypoint_timer: float = 0.0

# Burst-fire bookkeeping
var _burst_shots_left: int = 0
var _burst_cooldown: float = 0.5
var _shot_timer: float = 0.0
var _lost_sight_timer: float = 0.0
var _strafe_dir: float = 1.0
var _strafe_timer: float = 0.0

var _idle_timer: float = 0.0
var _alert_timer: float = 0.0
var _alert_voice_played: bool = false
var _nav_agent: NavigationAgent3D = null
var _los_ray: RayCast3D = null
var _audio: AudioStreamPlayer3D = null
var _mesh_instance: MeshInstance3D = null
var _model_node: Node3D = null
var _collision_shape: CollisionShape3D = null
var _combat_taunt_timer: float = 0.0
var _animator: NPCAnimator = null

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
		_model_node = SourceMaterials.spawn_model(self, path, Vector3.ZERO, 180.0, MODEL_SCALE, true)

	if _model_node != null:
		_animator = NPCAnimator.attach(_model_node)
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
		State.COMBAT, State.ALERT:
			_animator.set_pose(NPCAnimator.Pose.COMBAT)
		_:
			if hspeed > 0.3:
				_animator.set_pose(NPCAnimator.Pose.WALK)
			else:
				_animator.set_pose(NPCAnimator.Pose.IDLE)


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


func _state_idle(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_idle_timer += delta
	if _idle_timer >= 2.0:
		_idle_timer = 0.0
		if waypoints.size() > 0:
			current_state = State.PATROL
	if not scripted_patrol and _detect_player():
		current_state = State.ALERT
		_alert_timer = 0.0
		_alert_voice_played = false


func _state_patrol(delta: float) -> void:
	if waypoints.size() == 0:
		current_state = State.IDLE
		return

	if not scripted_patrol and _detect_player():
		current_state = State.ALERT
		_alert_timer = 0.0
		_alert_voice_played = false
		return

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


func _state_alert(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if player_ref != null:
		_face_target(player_ref.global_position, delta)
	if not _alert_voice_played:
		_alert_voice_played = true
		_play_voice("alert_01")
	_alert_timer += delta
	if _alert_timer >= 0.5:
		current_state = State.COMBAT
		_burst_shots_left = 0
		_burst_cooldown = randf_range(0.3, 0.7)
		_lost_sight_timer = 0.0


## HL2-style engagement: keep facing the enemy at all times, advance when out
## of range, fire 2-4 shot aimed bursts with 1-2 s pauses, sidestep between
## volleys, and only ever pull the trigger with line of sight AND the body
## actually pointed at the target.
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

	# Always track the enemy with the body.
	_face_target(target, delta)

	# Disengage only when the fight is truly over: enemy far away, or no
	# line of sight for a few seconds (not the instant a 20 m circle breaks).
	if has_los:
		_lost_sight_timer = 0.0
	else:
		_lost_sight_timer += delta
	if dist > COMBAT_GIVE_UP_RANGE or _lost_sight_timer > LOSE_SIGHT_TIME:
		_lost_sight_timer = 0.0
		current_state = State.PATROL if waypoints.size() > 0 else State.IDLE
		return

	# --- Movement ---
	if dist > ATTACK_RANGE or not has_los:
		# Out of range (or sight blocked): press toward the enemy.
		var dir := target - global_position
		dir.y = 0.0
		dir = dir.normalized()
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
	elif _strafe_timer > 0.0:
		# Reposition sideways between bursts (reads as ducking for cover).
		_strafe_timer -= delta
		var right := global_transform.basis.x * _strafe_dir
		velocity.x = right.x * MOVE_SPEED * 0.7
		velocity.z = right.z * MOVE_SPEED * 0.7
	else:
		# Hold position while shooting.
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
					# Sidestep during part of the pause, alternating sides.
					_strafe_dir = 1.0 if randf() < 0.5 else -1.0
					_strafe_timer = STRAFE_TIME
		# else: hold the rest of the burst until back on target
	else:
		_burst_cooldown -= delta
		if _burst_cooldown <= 0.0 and can_fire:
			_burst_shots_left = randi_range(2, 4)
			_shot_timer = BURST_SHOT_INTERVAL  # first shot fires immediately


## Pure LOS check toward the player (no distance gate) for combat decisions.
func _has_line_of_sight() -> bool:
	if player_ref == null:
		return false
	_los_ray.target_position = to_local(player_ref.global_position + Vector3(0, 0.9, 0))
	_los_ray.force_raycast_update()
	if _los_ray.is_colliding():
		var collider := _los_ray.get_collider()
		return collider != null and collider.is_in_group("player")
	return true


func _detect_player() -> bool:
	if player_ref == null:
		_find_player()
		if player_ref == null:
			return false
	var dist := global_position.distance_to(player_ref.global_position)
	if dist > DETECTION_RANGE:
		return false
	# Line of sight check
	var dir_to_player := (player_ref.global_position - global_position).normalized()
	_los_ray.target_position = to_local(player_ref.global_position)
	_los_ray.force_raycast_update()
	if _los_ray.is_colliding():
		var collider := _los_ray.get_collider()
		if collider != null and collider.is_in_group("player"):
			return true
		# If something is blocking, no LOS — but allow if close enough
		return dist < 5.0
	return true


func take_damage(amount: float, from_direction: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DEAD:
		return
	health -= amount
	_play_voice("pain_01")
	_spawn_blood_puff()
	if health <= 0.0:
		_die()
		return

	# Flinch (brief stagger) and whip around toward the shooter.
	if _animator != null:
		_animator.flinch()
	if from_direction.length_squared() > 0.0001:
		# from_direction = bullet travel direction; the shooter is behind it.
		_snap_face_target(global_position - from_direction)
	elif player_ref != null:
		# The player is the only damage source in the demo.
		_snap_face_target(player_ref.global_position)
	if current_state != State.COMBAT:
		current_state = State.COMBAT
		_burst_shots_left = 0
		_burst_cooldown = 0.5  # short reaction beat before returning fire
		_lost_sight_timer = 0.0


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


func _die() -> void:
	current_state = State.DEAD
	velocity = Vector3.ZERO
	if _animator != null:
		_animator.set_speed(0.0)
		_animator.set_pose(NPCAnimator.Pose.DEAD)
	_play_voice("death_01")
	SubtitleManager.show_subtitle_direct(npc_name + " is down.", 2.0, npc_name)

	# Tween to fall over
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
	print("DBG shoot t=%.2f pos=%v burst_left=%d facing_dot=%.2f" % [Time.get_ticks_msec() / 1000.0, global_position, _burst_shots_left, _facing_forward().dot((player_ref.global_position - global_position).normalized())])

	# Play shoot sound (alyx gun set — pistol_fire files don't ship in EP2)
	var shoot_path := "res://sounds/weapons/alyx_gun/alyx_gun_fire4.wav"
	AudioManager.play_sfx_at(shoot_path, global_position, -4.0)

	# Brief muzzle blink so enemy fire reads visually
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.75, 0.4)
	flash.light_energy = 1.4
	flash.omni_range = 3.5
	flash.position = Vector3(0, 1.35, -0.45)  # character faces local -Z
	add_child(flash)
	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		if is_instance_valid(flash):
			flash.queue_free()
	)

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
		[self]
	)
	var result := space_state.intersect_ray(query)
	if result.size() > 0:
		var collider = result["collider"]
		if collider != null and collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(BULLET_DAMAGE)


func _play_voice(line_key: String) -> void:
	# Mouth/talk animation timed roughly to the line's subtitle length.
	if current_state != State.DEAD or line_key.begins_with("death"):
		_start_talking(_line_duration(line_key))
	if voice_file_prefix == "":
		return
	var voice_path := "res://voice/%s/%s.mp3" % [voice_file_prefix, line_key]
	if ResourceLoader.exists(voice_path):
		var stream := ResourceLoader.load(voice_path) as AudioStream
		if stream != null and _audio != null:
			_audio.stream = stream
			_audio.play()


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
