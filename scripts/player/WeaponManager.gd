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
		# Viewmodel: real HL2 model held under the camera.
		# Alyx gun MDL muzzle natively points -Z; slight pitch-up correction.
		"model": "res://models/weapons/w_alyx_gun.mdl",
		"model_pos": Vector3(0.0, 0.08, 0.04),
		"model_rot": Vector3(8.0, -8.0, 0.0),
		"model_scale": 1.25,
		"muzzle_z": -0.32,
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
		# Combine sniper MDL muzzle natively points -X; yaw -90 points it -Z.
		"model": "res://models/weapons/w_combine_sniper.mdl",
		"model_pos": Vector3(-0.03, 0.0, 0.16),
		"model_rot": Vector3(-4.0, -96.0, 0.0),
		"model_scale": 0.45,
		"muzzle_z": -0.55,
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
var _gun_holder: Node3D = null
var _gun_tween: Tween = null
var _viewmodel_base_pos := Vector3(0.27, -0.22, -0.5)
var _recoil_z: float = 0.0
var _sway := Vector2.ZERO
var _mouse_accum := Vector2.ZERO
var _bob_time: float = 0.0
var _bloom: float = 0.0

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

	_gun_holder = Node3D.new()
	_gun_holder.name = "GunHolder"
	_viewmodel.add_child(_gun_holder)

	# Muzzle flash: a SMALL, short-lived additive quad + weak light. Positioned
	# per weapon in _refresh_viewmodel; must never wash out the whole screen.
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.name = "MuzzleLight"
	_muzzle_light.position = Vector3(0.0, 0.0, -0.3)
	_muzzle_light.light_color = Color(1.0, 0.82, 0.5)
	_muzzle_light.light_energy = 0.5
	_muzzle_light.omni_range = 2.0
	_muzzle_light.omni_attenuation = 2.0
	_muzzle_light.visible = false
	_viewmodel.add_child(_muzzle_light)

	_muzzle_quad = MeshInstance3D.new()
	_muzzle_quad.name = "MuzzleQuad"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	_muzzle_quad.mesh = quad
	var qmat := StandardMaterial3D.new()
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.albedo_color = Color(1.0, 0.78, 0.35, 0.55)
	qmat.emission_enabled = true
	qmat.emission = Color(1.0, 0.72, 0.3)
	qmat.emission_energy_multiplier = 1.2
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_muzzle_quad.material_override = qmat
	_muzzle_quad.position = Vector3(0.0, 0.0, -0.32)
	_muzzle_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle_quad.visible = false
	_viewmodel.add_child(_muzzle_quad)

	_refresh_viewmodel()


## Swap the held model to match the current weapon (real MDL, box fallback).
func _refresh_viewmodel() -> void:
	if _gun_holder == null:
		return
	for child in _gun_holder.get_children():
		child.queue_free()

	# Reset any in-flight fire/reload animation on the holder.
	_kill_gun_tween()
	_gun_holder.position = Vector3.ZERO
	_gun_holder.rotation = Vector3.ZERO

	var def: Dictionary = WEAPON_DEFS.get(current_weapon_name, {})
	var model_path: String = def.get("model", "")
	var spawned: Node3D = null
	if model_path != "":
		spawned = SourceMaterials.spawn_model(_gun_holder, model_path,
			def.get("model_pos", Vector3.ZERO), 0.0, def.get("model_scale", 1.27), true)
		if spawned != null:
			spawned.rotation_degrees = def.get("model_rot", Vector3.ZERO)
			_disable_shadows(spawned)

	if spawned == null:
		var gun := MeshInstance3D.new()
		gun.name = "GunMeshFallback"
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.08, 0.35)
		gun.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.18, 0.2)
		mat.metallic = 0.6
		mat.roughness = 0.4
		gun.material_override = mat
		gun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_gun_holder.add_child(gun)

	var muzzle_z: float = def.get("muzzle_z", -0.3)
	if _muzzle_light != null:
		_muzzle_light.position = Vector3(0.0, 0.06, muzzle_z)
	if _muzzle_quad != null:
		_muzzle_quad.position = Vector3(0.0, 0.06, muzzle_z - 0.02)


func _disable_shadows(node: Node) -> void:
	var stack: Array = [node]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for child in n.get_children():
			stack.append(child)


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
	if _reloading:
		# Cancel reload: stop the lowered-gun animation and snap back.
		_kill_gun_tween()
		if _gun_holder != null:
			_gun_holder.position = Vector3.ZERO
			_gun_holder.rotation = Vector3.ZERO
	_reloading = false
	_reload_timer = 0.0
	if changed and _viewmodel != null:
		# Quick draw dip + swap the held model.
		_viewmodel.position = _viewmodel_base_pos + Vector3(0.0, -0.15, 0.0)
		_refresh_viewmodel()
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
	_play_reload_anim()


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

	# Muzzle flash — tiny and brief
	_muzzle_timer = 0.04
	_muzzle_light.visible = true
	_muzzle_quad.visible = true
	_muzzle_quad.rotation.z = randf_range(0.0, TAU)
	_muzzle_quad.scale = Vector3.ONE * randf_range(0.8, 1.25)

	# Recoil + spread bloom
	_recoil_z = minf(_recoil_z + 0.04, 0.12)
	_bloom = minf(_bloom + 0.004, 0.02)
	if _camera != null:
		_camera.rotation.x += deg_to_rad(0.4)
	_play_fire_anim()

	# Hitscan ray with random cone spread
	if _camera == null:
		return
	var spread := float(def["spread"]) + _bloom
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

	# Dust puff
	var dust := CPUParticles3D.new()
	dust.amount = 6
	dust.one_shot = true
	dust.lifetime = 0.55
	dust.explosiveness = 1.0
	dust.direction = normal
	dust.spread = 50.0
	dust.initial_velocity_min = 0.4
	dust.initial_velocity_max = 1.1
	dust.gravity = Vector3(0, -0.6, 0)
	dust.scale_amount_min = 0.05
	dust.scale_amount_max = 0.14
	var dquad := QuadMesh.new()
	dquad.size = Vector2(1.0, 1.0)
	var dustmat := StandardMaterial3D.new()
	dustmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dustmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dustmat.albedo_color = Color(0.55, 0.52, 0.46, 0.4)
	dustmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dquad.material = dustmat
	dust.mesh = dquad
	dust.emitting = true
	impact.add_child(dust)

	# Brief sparks
	var sparks := CPUParticles3D.new()
	sparks.amount = 5
	sparks.one_shot = true
	sparks.lifetime = 0.25
	sparks.explosiveness = 1.0
	sparks.direction = normal
	sparks.spread = 40.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 4.0
	sparks.gravity = Vector3(0, -9.0, 0)
	sparks.scale_amount_min = 0.012
	sparks.scale_amount_max = 0.03
	var smesh := QuadMesh.new()
	smesh.size = Vector2(1.0, 1.0)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.85, 0.45)
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smesh.material = smat
	sparks.mesh = smesh
	sparks.emitting = true
	impact.add_child(sparks)

	# Subtle dark bullet-hole decal facing the surface normal
	var decal := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.11, 0.11)
	decal.mesh = quad
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.04, 0.04, 0.04, 0.6)
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
# Viewmodel animations (fire kick + reload, tweened on the gun holder so they
# never fight the procedural sway/bob applied to _viewmodel)
# ---------------------------------------------------------------------------

func _kill_gun_tween() -> void:
	if _gun_tween != null and _gun_tween.is_valid():
		_gun_tween.kill()
	_gun_tween = null


## Quick kick back + muzzle-up pitch, springing back over ~0.15s.
func _play_fire_anim() -> void:
	if _gun_holder == null:
		return
	_kill_gun_tween()
	_gun_holder.position = Vector3(0.0, 0.01, 0.05)
	_gun_holder.rotation_degrees = Vector3(5.0, 0.0, 0.0)
	_gun_tween = create_tween().set_parallel(true)
	_gun_tween.tween_property(_gun_holder, "position", Vector3.ZERO, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_gun_tween.tween_property(_gun_holder, "rotation_degrees", Vector3.ZERO, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Lower the gun and tilt the muzzle down for the reload, then bring it back
## up just before the reload timer completes (RELOAD_TIME total).
func _play_reload_anim() -> void:
	if _gun_holder == null:
		return
	_kill_gun_tween()
	var down_pos := Vector3(0.03, -0.13, 0.07)
	var down_rot := Vector3(-25.0, 6.0, 10.0)
	var hold := maxf(RELOAD_TIME - 0.35 - 0.3 - 0.05, 0.1)
	_gun_tween = create_tween()
	_gun_tween.tween_property(_gun_holder, "position", down_pos, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_gun_tween.parallel().tween_property(_gun_holder, "rotation_degrees", down_rot, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_gun_tween.tween_interval(hold)
	_gun_tween.tween_property(_gun_holder, "position", Vector3.ZERO, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_gun_tween.parallel().tween_property(_gun_holder, "rotation_degrees", Vector3.ZERO, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# Viewmodel motion (sway + recoil recovery)
# ---------------------------------------------------------------------------

func _update_viewmodel(delta: float) -> void:
	if _viewmodel == null:
		return

	# Sway lags behind mouse movement.
	_sway = _sway.lerp(_mouse_accum.limit_length(40.0), 10.0 * delta)
	_mouse_accum = _mouse_accum.lerp(Vector2.ZERO, 12.0 * delta)

	# Weapon bob synced to player movement (figure-8, HL2 style).
	var bob_offset := Vector3.ZERO
	if _player != null and _player.is_on_floor():
		var hspeed := Vector2(_player.velocity.x, _player.velocity.z).length()
		if hspeed > 0.5:
			_bob_time += delta * hspeed * 1.6
			bob_offset = Vector3(sin(_bob_time * 0.5) * 0.008, -absf(sin(_bob_time)) * 0.009, 0.0)
		else:
			_bob_time = 0.0

	var sway_offset := Vector3(-_sway.x * 0.0012, _sway.y * 0.0012, 0.0)
	var target := _viewmodel_base_pos + sway_offset + bob_offset + Vector3(0.0, 0.0, _recoil_z)
	_viewmodel.position = _viewmodel.position.lerp(target, 12.0 * delta)
	_viewmodel.rotation.z = lerpf(_viewmodel.rotation.z, -_sway.x * 0.0006, 10.0 * delta)

	# Recoil + bloom recovery
	_recoil_z = lerpf(_recoil_z, 0.0, 9.0 * delta)
	_bloom = maxf(_bloom - delta * 0.03, 0.0)
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
