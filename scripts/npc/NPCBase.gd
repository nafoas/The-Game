extends CharacterBody3D

const GRAVITY: float = 20.0
const MOVE_SPEED: float = 3.5
const DETECTION_RANGE: float = 20.0
const ATTACK_RANGE: float = 15.0
const ATTACK_INTERVAL: float = 1.5
const BULLET_DAMAGE: float = 10.0

@export var waypoints: Array[Vector3] = []
@export var npc_name: String = "NPC"
@export var faction: String = "neutral"
@export var voice_file_prefix: String = ""
@export var is_friendly: bool = false

enum State { IDLE, PATROL, ALERT, COMBAT, DEAD }

var health: float = 100.0
var current_state: State = State.IDLE
var player_ref: CharacterBody3D = null
var attack_timer: float = 0.0
var current_waypoint: int = 0
var waypoint_timer: float = 0.0

var _idle_timer: float = 0.0
var _alert_timer: float = 0.0
var _alert_voice_played: bool = false
var _nav_agent: NavigationAgent3D = null
var _los_ray: RayCast3D = null
var _audio: AudioStreamPlayer3D = null
var _mesh_instance: MeshInstance3D = null
var _collision_shape: CollisionShape3D = null
var _combat_taunt_timer: float = 0.0


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

	# MeshInstance3D — capsule, colored by faction
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
	if _detect_player():
		current_state = State.ALERT
		_alert_timer = 0.0
		_alert_voice_played = false


func _state_patrol(delta: float) -> void:
	if waypoints.size() == 0:
		current_state = State.IDLE
		return

	if _detect_player():
		current_state = State.ALERT
		_alert_timer = 0.0
		_alert_voice_played = false
		return

	var target := waypoints[current_waypoint]
	var dir := (target - global_position)
	dir.y = 0.0
	if dir.length() < 1.0:
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


func _state_combat(delta: float) -> void:
	if player_ref == null:
		current_state = State.IDLE
		return

	if is_friendly:
		velocity.x = 0.0
		velocity.z = 0.0
		_face_target(player_ref.global_position, delta)
		return

	attack_timer += delta
	_combat_taunt_timer += delta

	var dist := global_position.distance_to(player_ref.global_position)

	_face_target(player_ref.global_position, delta)

	if dist > ATTACK_RANGE:
		# Move toward player
		var dir := (player_ref.global_position - global_position)
		dir.y = 0.0
		dir = dir.normalized()
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
	else:
		# Take cover occasionally — move laterally
		if fmod(_combat_taunt_timer, 5.0) < 0.5:
			var right := global_transform.basis.x
			velocity.x = right.x * MOVE_SPEED
			velocity.z = right.z * MOVE_SPEED
		else:
			velocity.x = lerp(velocity.x, 0.0, 0.2)
			velocity.z = lerp(velocity.z, 0.0, 0.2)
		if attack_timer >= ATTACK_INTERVAL:
			attack_timer = 0.0
			_shoot()

	if not _detect_player():
		current_state = State.PATROL


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
	if health <= 0.0:
		_die()
	else:
		if current_state != State.COMBAT:
			current_state = State.COMBAT


func _die() -> void:
	current_state = State.DEAD
	velocity = Vector3.ZERO
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

	# Play shoot sound
	var shoot_path := "res://sounds/weapons/pistol/pistol_fire3.wav"
	if ResourceLoader.exists(shoot_path):
		AudioManager.play_sfx_at(shoot_path, global_position)
	else:
		AudioManager.play_sfx_at("res://sounds/weapons/pistol/pistol_fire3.wav", global_position)

	# Raycast check toward player
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.9, 0),
		player_ref.global_position + Vector3(0, 0.9, 0),
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
	if voice_file_prefix == "":
		return
	var voice_path := "res://voice/%s/%s.mp3" % [voice_file_prefix, line_key]
	if ResourceLoader.exists(voice_path):
		var stream := ResourceLoader.load(voice_path) as AudioStream
		if stream != null and _audio != null:
			_audio.stream = stream
			_audio.play()


func _face_direction(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var target_angle := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)


func _face_target(target_pos: Vector3, delta: float) -> void:
	var dir := (target_pos - global_position)
	dir.y = 0.0
	_face_direction(dir.normalized(), delta)
