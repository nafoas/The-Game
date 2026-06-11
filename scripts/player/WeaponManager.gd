extends Node3D

## Hitscan weapon system with a procedural box viewmodel, sway, recoil,
## muzzle flash, impact effects, reload and weapon switching.
## Lives at Player/Head/WeaponManager.

signal ammo_changed(current: int, reserve: int)
signal weapon_changed(name: String)

const RANGE: float = 200.0
const RELOAD_TIME: float = 1.8
const HIT_MASK: int = 5  # world (layer 1) + enemies (layer 3)

const WEAPON_DEFS: Dictionary = {
	"pistol": {
		"damage": 12.0,
		"fire_interval": 0.25,
		"auto": false,
		"max_ammo": 18,
		"reserve": 90,
		"spread": 0.01,
		"sound_candidates": [
			"res://sounds/weapons/pistol/pistol_fire3.wav",
			"res://sounds/weapons/alyx_gun/alyx_gun_fire3.wav",
			"res://sounds/weapons/alyx_gun/alyx_gun_fire4.wav",
		],
	},
	"mp5": {
		"damage": 8.0,
		"fire_interval": 0.09,
		"auto": true,
		"max_ammo": 30,
		"reserve": 120,
		"spread": 0.025,
		"sound_candidates": [
			"res://sounds/weapons/smg1/smg1_fire1.wav",
			"res://sounds/weapons/alyx_gun/alyx_gun_fire5.wav",
			"res://sounds/weapons/alyx_gun/alyx_gun_fire6.wav",
		],
	},
}

const RELOAD_SOUND_CANDIDATES: Array = [
	"res://sounds/weapons/pistol/pistol_reload1.wav",
	"res://sounds/weapons/smg1/smg1_reload.wav",
]

var current_weapon_name: String = "pistol"

var _unlocked: Array[String] = []
var _ammo: Dictionary = {}  # name -> {"mag": int, "reserve": int}
var _fire_sounds: Dictionary = {}  # name -> resolved path ("" if none)
var _reload_sound: String = ""

var _fire_cooldown: float = 0.0
var _reloading: bool = false
var _reload_timer: float = 0.0

var _viewmodel: Node3D = null
var _viewmodel_base_pos := Vector3(0.25, -0.2, -0.5)
var _recoil_z: float = 0.0
var _sway := Vector2.ZERO
var _mouse_accum := Vector2.ZERO

var _muzzle_light: OmniLight3D = null
var _muzzle_quad: MeshInstance3D = null
var _muzzle_timer: float = 0.0

var _camera: Camera3D = null
var _player: CharacterBody3D = null
var _audio: AudioStreamPlayer3D = null


func _ready() -> void:
	_camera = get_parent().get_node_or_null("Camera3D") as Camera3D
	var p := get_parent().get_parent()
	if p is CharacterBody3D:
		_player = p

	_audio = AudioStreamPlayer3D.new()
	_audio.name = "WeaponAudio"
	_audio.bus = "SFX"
	_audio.unit_size = 4.0
	add_child(_audio)

	_resolve_sounds()
	_build_viewmodel()

	# Start with the pistol.
	_unlocked.append("pistol")
	_ammo["pistol"] = {
		"mag": int(WEAPON_DEFS["pistol"]["max_ammo"]),
		"reserve": int(WEAPON_DEFS["pistol"]["reserve"]),
	}
	current_weapon_name = "pistol"
	call_deferred("_emit_state")


func _resolve_sounds() -> void:
	for weapon_name in WEAPON_DEFS:
		_fire_sounds[weapon_name] = ""
		for candidate in WEAPON_DEFS[weapon_name]["sound_candidates"]:
			if ResourceLoader.exists(candidate):
				_fire_sounds[weapon_name] = candidate
				break
	for candidate in RELOAD_SOUND_CANDIDATES:
		if ResourceLoader.exists(candidate):
			_reload_sound = candidate
			break


# ---------------------------------------------------------------------------
# Viewmodel
# ---------------------------------------------------------------------------

func _build_viewmodel() -> void:
	_viewmodel = Node3D.new()
	_viewmodel.name = "ViewModel"
	_viewmodel.position = _viewmodel_base_pos
	add_child(_viewmodel)

	var gun := MeshInstance3D.new()
	gun.name = "GunMesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.08, 0.35)
	gun.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.2)
	mat.metallic = 0.6
	mat.roughness = 0.4
	gun.material_override = mat
	gun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_viewmodel.add_child(gun)

	# Muzzle flash light + quad at the barrel tip.
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.name = "MuzzleLight"
	_muzzle_light.position = Vector3(0.0, 0.0, -0.25)
	_muzzle_light.light_color = Color(1.0, 0.8, 0.4)
	_muzzle_light.light_energy = 3.0
	_muzzle_light.omni_range = 4.0
	_muzzle_light.visible = false
	_viewmodel.add_child(_muzzle_light)

	_muzzle_quad = MeshInstance3D.new()
	_muzzle_quad.name = "MuzzleQuad"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	_muzzle_quad.mesh = quad
	var qmat := StandardMaterial3D.new()
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.albedo_color = Color(1.0, 0.85, 0.4, 0.9)
	qmat.emission_enabled = true
	qmat.emission = Color(1.0, 0.7, 0.2)
	qmat.emission_energy_multiplier = 4.0
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_muzzle_quad.material_override = qmat
	_muzzle_quad.position = Vector3(0.0, 0.0, -0.28)
	_muzzle_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle_quad.visible = false
	_viewmodel.add_child(_muzzle_quad)


# ---------------------------------------------------------------------------
# Public API (used by pickups / HUD)
# ---------------------------------------------------------------------------

func add_weapon(weapon_type: String, ammo_count: int) -> void:
	if not WEAPON_DEFS.has(weapon_type):
		return
	if not _unlocked.has(weapon_type):
		_unlocked.append(weapon_type)
		_ammo[weapon_type] = {
			"mag": int(WEAPON_DEFS[weapon_type]["max_ammo"]),
			"reserve": maxi(ammo_count, 0),
		}
	else:
		_ammo[weapon_type]["reserve"] = int(_ammo[weapon_type]["reserve"]) + maxi(ammo_count, 0)
	_equip(weapon_type)


func get_ammo() -> Dictionary:
	var entry: Dictionary = _ammo.get(current_weapon_name, {"mag": 0, "reserve": 0})
	return {"current": int(entry["mag"]), "reserve": int(entry["reserve"])}


# ---------------------------------------------------------------------------
# Input / per-frame
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_accum += (event as InputEventMouseMotion).relative


func _process(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)

	_handle_switching()
	_handle_reload(delta)
	_handle_fire()
	_update_viewmodel(delta)
	_update_muzzle_flash(delta)


func _handle_switching() -> void:
	if Input.is_action_just_pressed("weapon_1"):
		_try_equip_index(0)
	elif Input.is_action_just_pressed("weapon_2"):
		_try_equip_index(1)
	elif Input.is_action_just_pressed("weapon_next"):
		_cycle(1)
	elif Input.is_action_just_pressed("weapon_prev"):
		_cycle(-1)


func _try_equip_index(idx: int) -> void:
	if idx >= 0 and idx < _unlocked.size():
		_equip(_unlocked[idx])


func _cycle(dir: int) -> void:
	if _unlocked.size() <= 1:
		return
	var idx := _unlocked.find(current_weapon_name)
	idx = wrapi(idx + dir, 0, _unlocked.size())
	_equip(_unlocked[idx])


func _equip(weapon_name: String) -> void:
	if not _unlocked.has(weapon_name):
		return
	var changed := weapon_name != current_weapon_name
	current_weapon_name = weapon_name
	_reloading = false
	_reload_timer = 0.0
	if changed and _viewmodel != null:
		# Quick draw dip.
		_viewmodel.position = _viewmodel_base_pos + Vector3(0.0, -0.15, 0.0)
	weapon_changed.emit(current_weapon_name)
	_emit_ammo()


func _handle_reload(delta: float) -> void:
	if _reloading:
		_reload_timer += delta
		if _reload_timer >= RELOAD_TIME:
			_finish_reload()
		return

	if Input.is_action_just_pressed("reload"):
		_start_reload()


func _start_reload() -> void:
	var entry: Dictionary = _ammo[current_weapon_name]
	var max_mag := int(WEAPON_DEFS[current_weapon_name]["max_ammo"])
	if _reloading or int(entry["mag"]) >= max_mag or int(entry["reserve"]) <= 0:
		return
	_reloading = true
	_reload_timer = 0.0
	if not _reload_sound.is_empty():
		_play_local_sound(_reload_sound)


func _finish_reload() -> void:
	_reloading = false
	_reload_timer = 0.0
	var entry: Dictionary = _ammo[current_weapon_name]
	var max_mag := int(WEAPON_DEFS[current_weapon_name]["max_ammo"])
	var needed := max_mag - int(entry["mag"])
	var taken := mini(needed, int(entry["reserve"]))
	entry["mag"] = int(entry["mag"]) + taken
	entry["reserve"] = int(entry["reserve"]) - taken
	_emit_ammo()


func _handle_fire() -> void:
	if _reloading or _fire_cooldown > 0.0:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	var def: Dictionary = WEAPON_DEFS[current_weapon_name]
	var wants_fire: bool
	if bool(def["auto"]):
		wants_fire = Input.is_action_pressed("fire")
	else:
		wants_fire = Input.is_action_just_pressed("fire")
	if not wants_fire:
		return

	var entry: Dictionary = _ammo[current_weapon_name]
	if int(entry["mag"]) <= 0:
		if Input.is_action_just_pressed("fire"):
			_start_reload()
		return

	_fire_cooldown = float(def["fire_interval"])
	entry["mag"] = int(entry["mag"]) - 1
	_emit_ammo()
	_fire_shot(def)


# ---------------------------------------------------------------------------
# Shooting
# ---------------------------------------------------------------------------

func _fire_shot(def: Dictionary) -> void:
	# Sound
	var snd: String = _fire_sounds.get(current_weapon_name, "")
	if not snd.is_empty():
		_play_local_sound(snd)

	# Muzzle flash
	_muzzle_timer = 0.05
	_muzzle_light.visible = true
	_muzzle_quad.visible = true

	# Recoil
	_recoil_z = minf(_recoil_z + 0.04, 0.12)
	if _camera != null:
		_camera.rotation.x += deg_to_rad(0.4)

	# Hitscan ray with random cone spread
	if _camera == null:
		return
	var spread := float(def["spread"])
	var forward := -_camera.global_transform.basis.z
	var right := _camera.global_transform.basis.x
	var up := _camera.global_transform.basis.y
	var dir := (
		forward
		+ right * randf_range(-spread, spread)
		+ up * randf_range(-spread, spread)
	).normalized()

	var from := _camera.global_position
	var to := from + dir * RANGE

	var exclude: Array[RID] = []
	if _player != null:
		exclude.append(_player.get_rid())

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, exclude)
	var result := space.intersect_ray(query)
	if result.is_empty():
		return

	var collider: Object = result["collider"]
	var hit_pos: Vector3 = result["position"]
	var hit_normal: Vector3 = result["normal"]

	if collider != null and collider.has_method("take_damage"):
		collider.take_damage(float(def["damage"]))
	else:
		_spawn_impact(hit_pos, hit_normal)


func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	var impact := Node3D.new()
	impact.name = "Impact"
	scene_root.add_child(impact)
	impact.global_position = pos

	# Spark/dust particles
	var particles := CPUParticles3D.new()
	particles.amount = 8
	particles.one_shot = true
	particles.lifetime = 0.4
	particles.explosiveness = 1.0
	particles.direction = normal
	particles.spread = 35.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.5
	particles.gravity = Vector3(0, -6.0, 0)
	particles.scale_amount_min = 0.02
	particles.scale_amount_max = 0.05
	var pmesh := BoxMesh.new()
	pmesh.size = Vector3(0.02, 0.02, 0.02)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(0.85, 0.75, 0.5)
	pmesh.material = pmat
	particles.mesh = pmesh
	particles.emitting = true
	impact.add_child(particles)

	# Dark decal-ish quad facing the surface normal
	var decal := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	decal.mesh = quad
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.05, 0.05, 0.05, 0.85)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	decal.material_override = dmat
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	impact.add_child(decal)
	decal.global_position = pos + normal * 0.01

	var up_ref := Vector3.UP
	if absf(normal.dot(Vector3.UP)) > 0.99:
		up_ref = Vector3.RIGHT
	decal.look_at(pos + normal, up_ref)

	# Auto-free after 8s (guarded against scene change).
	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		if is_instance_valid(impact):
			impact.queue_free()
	)


func _play_local_sound(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_audio.stream = stream
	_audio.pitch_scale = randf_range(0.96, 1.04)
	_audio.play()


# ---------------------------------------------------------------------------
# Viewmodel motion (sway + recoil recovery)
# ---------------------------------------------------------------------------

func _update_viewmodel(delta: float) -> void:
	if _viewmodel == null:
		return

	# Sway lags behind mouse movement.
	_sway = _sway.lerp(_mouse_accum.limit_length(40.0), 10.0 * delta)
	_mouse_accum = _mouse_accum.lerp(Vector2.ZERO, 12.0 * delta)

	var sway_offset := Vector3(-_sway.x * 0.0012, _sway.y * 0.0012, 0.0)
	var target := _viewmodel_base_pos + sway_offset + Vector3(0.0, 0.0, _recoil_z)
	_viewmodel.position = _viewmodel.position.lerp(target, 12.0 * delta)

	# Recoil recovery
	_recoil_z = lerpf(_recoil_z, 0.0, 9.0 * delta)
	if _camera != null:
		_camera.rotation.x = lerpf(_camera.rotation.x, 0.0, 9.0 * delta)


func _update_muzzle_flash(delta: float) -> void:
	if _muzzle_timer > 0.0:
		_muzzle_timer -= delta
		if _muzzle_timer <= 0.0:
			_muzzle_light.visible = false
			_muzzle_quad.visible = false


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

func _emit_state() -> void:
	weapon_changed.emit(current_weapon_name)
	_emit_ammo()


func _emit_ammo() -> void:
	var a := get_ammo()
	ammo_changed.emit(a["current"], a["reserve"])
