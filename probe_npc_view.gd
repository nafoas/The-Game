extends Node3D
## Temp visual probe: spawn character models in a line, screenshot, quit.

const MODELS := [
	"res://models/barney.mdl",
	"res://models/eli.mdl",
	"res://models/alyx.mdl",
	"res://models/mossman.mdl",
	"res://models/kleiner.mdl",
	"res://models/magnusson.mdl",
	"res://models/gman.mdl",
	"res://models/vortigaunt.mdl",
]

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.3, 0.35)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 1.0
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = false
	add_child(sun)

	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mesh.mesh = pm
	add_child(floor_mesh)

	var x := -7.0
	for path in MODELS:
		var ps: PackedScene = load(path)
		if ps == null:
			print("LOAD FAIL: ", path)
			continue
		var inst := ps.instantiate() as Node3D
		inst.position = Vector3(x, 0, 0)
		inst.rotation_degrees = Vector3(0, 180, 0)
		inst.scale = Vector3.ONE * 1.27
		add_child(inst)
		print("SPAWNED %s" % path)
		_dump(inst, path)
		x += 2.0

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.3, 4.5)
	add_child(cam)
	cam.make_current()

	_shoot()

func _dump(inst: Node3D, path: String) -> void:
	var meshes := inst.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh == null: continue
		var aabb := mi.mesh.get_aabb()
		var mats := []
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			mats.append("null" if mat == null else mat.get_class())
		print("  mesh surfaces=%d aabb=%s mats=%s" % [mi.mesh.get_surface_count(), str(aabb), str(mats)])
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	for s in skels:
		print("  skeleton bones=%d" % (s as Skeleton3D).get_bone_count())

func _shoot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	img.save_png("/tmp/shots/npc_lineup.png")
	print("SCREENSHOT SAVED")
	# Closeup of first three
	var cam := get_viewport().get_camera_3d()
	cam.position = Vector3(-5.0, 1.4, 2.2)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/npc_closeup.png")
	print("SCREENSHOT2 SAVED")
	get_tree().quit(0)
