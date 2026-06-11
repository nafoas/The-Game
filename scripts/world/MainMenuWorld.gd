extends Node3D

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

	# Dark sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.04, 0.06)

	# Heavy fog
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.08, 0.12)
	env.fog_light_energy = 0.3
	env.fog_density = 0.08

	# Ambient light
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.1, 0.15)
	env.ambient_light_energy = 0.5

	world_env.environment = env
	add_child(world_env)

	# Dim directional light — blue-gray
	var dir_light := DirectionalLight3D.new()
	dir_light.light_color = Color(0.6, 0.65, 0.8)
	dir_light.light_energy = 0.4
	dir_light.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	add_child(dir_light)


func _build_scene() -> void:
	# Ground plane
	var ground := CSGBox3D.new()
	ground.size = Vector3(80.0, 0.4, 80.0)
	ground.position = Vector3(0.0, -0.2, 0.0)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.15, 0.15, 0.15)
	ground.material = gmat
	ground.use_collision = true
	add_child(ground)

	# Silhouette buildings in fog
	var building_data: Array = [
		[Vector3(-12.0, 5.0, -20.0), Vector3(8.0, 10.0, 6.0)],
		[Vector3(10.0, 4.0, -18.0), Vector3(6.0, 8.0, 5.0)],
		[Vector3(-5.0, 6.0, -28.0), Vector3(10.0, 12.0, 7.0)],
		[Vector3(18.0, 3.5, -22.0), Vector3(7.0, 7.0, 6.0)],
		[Vector3(-20.0, 3.0, -15.0), Vector3(5.0, 6.0, 4.0)],
		[Vector3(0.0, 7.0, -35.0), Vector3(14.0, 14.0, 8.0)],
	]

	for bd in building_data:
		var pos: Vector3 = bd[0]
		var sz: Vector3 = bd[1]
		var b := CSGBox3D.new()
		b.size = sz
		b.position = pos
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.08, 0.1)
		b.material = mat
		add_child(b)

	# Street light pole
	var pole := CSGCylinder3D.new()
	pole.radius = 0.05
	pole.height = 3.5
	pole.position = Vector3(4.0, 1.75, -8.0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.2, 0.2, 0.2)
	pole.material = pmat
	add_child(pole)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(4.0, 3.6, -8.0)
	lamp.light_color = Color(0.8, 0.8, 0.6)
	lamp.light_energy = 0.8
	lamp.omni_range = 6.0
	add_child(lamp)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 2.5, 5.0)
	_camera.rotation_degrees = Vector3(-5.0, 0.0, 0.0)
	_cam_base_y = _camera.position.y
	add_child(_camera)


func _start_ambient() -> void:
	_ambient_audio = AudioStreamPlayer.new()
	_ambient_audio.volume_db = -12.0
	add_child(_ambient_audio)

	var ambient_path := "res://sounds/ambient/underground_base_01.wav"
	if ResourceLoader.exists(ambient_path):
		var stream := ResourceLoader.load(ambient_path) as AudioStream
		if stream != null:
			_ambient_audio.stream = stream
			_ambient_audio.autoplay = true
			_ambient_audio.play()


func _process(delta: float) -> void:
	if _camera == null:
		return
	_cam_timer += delta
	# Gentle oscillation on Y axis
	_camera.position.y = _cam_base_y + sin(_cam_timer * 0.3) * 0.08
	_camera.rotation.y = sin(_cam_timer * 0.15) * 0.04
