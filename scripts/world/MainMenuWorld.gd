extends Node3D

## Main menu 3D backdrop: a foggy City-17 street corner built from real HL2
## materials and props — flickering street lamp, wrecked car, drifting dust,
## distant lit windows — with a slow camera drift.

var _camera: Camera3D = null
var _cam_base_y: float = 0.0
var _cam_timer: float = 0.0
var _ambient_audio: AudioStreamPlayer = null


func _ready() -> void:
	_build_environment()
	_build_scene()
	_build_camera()
	_start_ambient()


func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()

	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.055, 0.075)

	env.fog_enabled = true
	env.fog_light_color = Color(0.09, 0.1, 0.13)
	env.fog_light_energy = 0.5
	env.fog_density = 0.05

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.14, 0.15, 0.2)
	env.ambient_light_energy = 0.6

	world_env.environment = env
	add_child(world_env)

	var dir_light := DirectionalLight3D.new()
	dir_light.light_color = Color(0.5, 0.56, 0.75)
	dir_light.light_energy = 0.35
	dir_light.rotation_degrees = Vector3(-38.0, -25.0, 0.0)
	add_child(dir_light)


func _deco(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	if mat != null:
		mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _build_scene() -> void:
	# Street ground: road strip + sidewalk, world-triplanar tiled.
	_deco(Vector3(0.0, -0.2, -6.0), Vector3(40.0, 0.4, 40.0), SourceMaterials.mat("road"))
	_deco(Vector3(-6.5, -0.08, -6.0), Vector3(7.0, 0.4, 40.0), SourceMaterials.mat("sidewalk"))
	_deco(Vector3(8.5, -0.08, -6.0), Vector3(9.0, 0.4, 40.0), SourceMaterials.mat("sidewalk"))

	# Near building flank (left of camera) with windows
	_deco(Vector3(-12.0, 4.5, -8.0), Vector3(6.0, 9.0, 26.0), SourceMaterials.mat("brick_inn"))
	_deco(Vector3(-12.0, 8.6, -8.0), Vector3(6.2, 0.4, 26.2), SourceMaterials.mat("trim"))
	var glass := SourceMaterials.glass_mat()
	var lit := SourceMaterials.lit_window_mat()
	for i in range(5):
		var z := -16.0 + i * 4.0
		_deco(Vector3(-8.92, 2.4, z), Vector3(0.14, 1.35, 0.95), glass if i % 3 != 1 else lit)
		_deco(Vector3(-8.92, 5.4, z), Vector3(0.14, 1.35, 0.95), glass if i % 3 != 2 else lit)

	# Right-hand building further back
	_deco(Vector3(11.0, 4.0, -14.0), Vector3(7.0, 8.0, 14.0), SourceMaterials.mat("plaster_worn"))
	_deco(Vector3(11.0, 7.62, -14.0), Vector3(7.2, 0.36, 14.2), SourceMaterials.mat("trim"))
	for i in range(3):
		var z := -18.0 + i * 4.0
		_deco(Vector3(7.42, 2.2, z), Vector3(0.14, 1.3, 0.95), glass if i != 1 else lit)

	# Distant silhouettes in the fog
	var sil := StandardMaterial3D.new()
	sil.albedo_color = Color(0.05, 0.055, 0.07)
	sil.roughness = 1.0
	var building_data: Array = [
		[Vector3(-5.0, 6.0, -30.0), Vector3(10.0, 12.0, 7.0)],
		[Vector3(7.0, 8.0, -36.0), Vector3(12.0, 16.0, 8.0)],
		[Vector3(20.0, 4.5, -28.0), Vector3(7.0, 9.0, 6.0)],
		[Vector3(-18.0, 7.0, -34.0), Vector3(9.0, 14.0, 7.0)],
		[Vector3(0.0, 9.0, -44.0), Vector3(16.0, 18.0, 9.0)],
	]
	for bd in building_data:
		_deco(bd[0], bd[1], sil)
	# A few lit windows glowing through the murk
	for p in [Vector3(-4.0, 5.5, -26.4), Vector3(8.5, 7.0, -31.9), Vector3(-16.0, 8.0, -30.4)]:
		_deco(p, Vector3(0.5, 0.7, 0.12), lit)

	# Street props
	SourceMaterials.spawn_model(self, "res://models/props_vehicles/van001a_nodoor.mdl",
		Vector3(4.2, 0.94, -12.0), -140.0)
	SourceMaterials.spawn_model(self, "res://models/props_c17/oildrum_crush.mdl",
		Vector3(-5.0, 0.49, -7.5), 35.0)
	SourceMaterials.spawn_model(self, "res://models/props_wasteland/barricade002a.mdl",
		Vector3(2.0, 0.87, -7.0), 25.0)
	SourceMaterials.spawn_model(self, "res://models/props_lab/scrapyarddumpster_static.mdl",
		Vector3(-6.8, 0.06, -14.5), 12.0, 0.78)
	SourceMaterials.spawn_model(self, "res://models/props_junk/wood_spool01.mdl",
		Vector3(6.5, 0.43, -8.0), 0.0)

	# Street lamp with flicker — the centerpiece
	var metal := SourceMaterials.mat("metal")
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.07
	pole_mesh.height = 4.8
	pole.mesh = pole_mesh
	pole.material_override = metal
	pole.position = Vector3(3.6, 2.4, -8.5)
	add_child(pole)
	SourceMaterials.spawn_model(self, "res://models/props_c17/light_industrialbell01_on.mdl",
		Vector3(3.6, 4.85, -8.5), 0.0, 1.0)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(3.6, 4.4, -8.5)
	lamp.light_color = Color(1.0, 0.85, 0.55)
	lamp.light_energy = 1.1
	lamp.omni_range = 9.0
	lamp.omni_attenuation = 2.0
	lamp.shadow_enabled = true
	add_child(lamp)

	var flicker_script: GDScript = load("res://scripts/world/Flicker.gd")
	if flicker_script != null:
		var flicker: Node = flicker_script.new()
		lamp.add_child(flicker)

	# Drifting fog dust across the whole frame
	SourceMaterials.add_dust_motes(self, Vector3(0.0, 2.0, -8.0), Vector3(8.0, 2.5, 8.0), 24)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 1.9, 2.0)
	_camera.rotation_degrees = Vector3(-3.0, 6.0, 0.0)
	_cam_base_y = _camera.position.y
	add_child(_camera)


func _start_ambient() -> void:
	_ambient_audio = AudioStreamPlayer.new()
	_ambient_audio.volume_db = -14.0
	add_child(_ambient_audio)

	var ambient_path := "res://sounds/ambient/levels/city/citadel_winds_loop1.wav"
	if ResourceLoader.exists(ambient_path):
		var stream := ResourceLoader.load(ambient_path) as AudioStream
		if stream != null:
			SourceMaterials.make_wav_loop(stream)
			_ambient_audio.stream = stream
			_ambient_audio.autoplay = true
			_ambient_audio.play()


func _process(delta: float) -> void:
	if _camera == null:
		return
	_cam_timer += delta
	# Gentle drift
	_camera.position.y = _cam_base_y + sin(_cam_timer * 0.3) * 0.07
	_camera.rotation.y = deg_to_rad(6.0) + sin(_cam_timer * 0.13) * 0.05
	_camera.position.x = sin(_cam_timer * 0.09) * 0.4
