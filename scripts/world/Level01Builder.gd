extends Node3D

# Scene paths
const HECU_SOLDIER_SCENE := "res://scenes/npc/HECUSoldier.tscn"
const RESISTANCE_SOLDIER_SCENE := "res://scenes/npc/ResistanceSoldier.tscn"
const WEAPON_PICKUP_SCENE := "res://scenes/world/WeaponPickup.tscn"
const HEALTH_PICKUP_SCENE := "res://scenes/world/HealthPickup.tscn"

# Material texture paths
const MAT_CONCRETE := "res://materials/concrete/concretefloor033a.vmt"
const MAT_STONE    := "res://materials/stone/stonefloor006a.vmt"
const MAT_TILEWALL := "res://materials/tile/tilewall009e.vmt"
const MAT_WOOD     := "res://materials/wood/woodfloor007a.vmt"

var _level_complete_triggered: bool = false


func _ready() -> void:
	GameManager.checkpoint_position = Vector3(0, 1, 0)

	_build_world_environment()
	_build_ground_plane()
	_build_staging_area()
	_build_street_a()
	_build_side_alley()
	_build_plaza()
	_build_interior()
	_build_end_area()
	_spawn_npcs()
	_spawn_pickups()
	_add_ambient_sound()


# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

func _build_world_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()

	# Overcast sky — dim, slightly cold gray for that Source-era gloom
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.33, 0.36, 0.41)

	# Distance fog — thicker and darker so the street ends dissolve into murk
	env.fog_enabled = true
	env.fog_light_color = Color(0.36, 0.39, 0.44)
	env.fog_light_energy = 1.0
	env.fog_density = 0.018

	# SSAO
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.5

	# Subtle bloom
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.1

	# Ambient — low and cool; street lamps carry the warm accents
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.40, 0.47)
	env.ambient_light_energy = 0.45

	world_env.environment = env
	add_child(world_env)

	# Directional light with shadows
	var dir_light := DirectionalLight3D.new()
	dir_light.name = "SunLight"
	dir_light.light_color = Color(0.72, 0.76, 0.85)
	dir_light.light_energy = 0.7
	dir_light.shadow_enabled = true
	dir_light.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	add_child(dir_light)


# ---------------------------------------------------------------------------
# Ground plane
# ---------------------------------------------------------------------------

func _build_ground_plane() -> void:
	var ground := StaticBody3D.new()
	ground.name = "GroundPlane"
	var cshape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(80.0, 0.4, 120.0)
	cshape.shape = box_shape
	ground.add_child(cshape)
	var mesh := MeshInstance3D.new()
	var plane_mesh := BoxMesh.new()
	plane_mesh.size = Vector3(80.0, 0.4, 120.0)
	mesh.mesh = plane_mesh
	mesh.material_override = _make_material(MAT_CONCRETE, Color(0.45, 0.45, 0.45))
	ground.add_child(mesh)
	ground.position = Vector3(0.0, -0.2, 30.0)
	add_child(ground)


# ---------------------------------------------------------------------------
# Helper: material loader
# ---------------------------------------------------------------------------

func _make_material(vmt_path: String, fallback_color: Color) -> Material:
	if ResourceLoader.exists(vmt_path):
		var mat := ResourceLoader.load(vmt_path)
		if mat is Material:
			return mat
	var mat := StandardMaterial3D.new()
	mat.albedo_color = fallback_color
	return mat


# ---------------------------------------------------------------------------
# Helper: add a CSGBox3D
# ---------------------------------------------------------------------------

func _add_csg_box(parent: Node, pos: Vector3, size: Vector3, mat: Material, name_str: String = "") -> CSGBox3D:
	var box := CSGBox3D.new()
	if name_str != "":
		box.name = name_str
	box.size = size
	box.position = pos
	box.use_collision = true
	if mat != null:
		box.material = mat
	parent.add_child(box)
	return box


# ---------------------------------------------------------------------------
# Helper: street light
# ---------------------------------------------------------------------------

func _add_street_light(parent: Node, pos: Vector3) -> void:
	var pole := CSGCylinder3D.new()
	pole.radius = 0.06
	pole.height = 5.0
	pole.position = pos + Vector3(0.0, 2.5, 0.0)
	pole.use_collision = true
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.25, 0.25, 0.25)
	pole.material = pmat
	parent.add_child(pole)

	var arm := CSGBox3D.new()
	arm.size = Vector3(0.06, 0.06, 0.8)
	arm.position = pos + Vector3(0.4, 4.7, 0.0)
	arm.use_collision = true
	arm.material = pmat
	parent.add_child(arm)

	var lamp := OmniLight3D.new()
	lamp.position = pos + Vector3(0.8, 4.6, 0.0)
	lamp.light_color = Color(1.0, 0.95, 0.8)
	lamp.light_energy = 1.8
	lamp.omni_range = 12.0
	lamp.shadow_enabled = true
	parent.add_child(lamp)


# ---------------------------------------------------------------------------
# Helper: overturned car
# ---------------------------------------------------------------------------

func _add_car(parent: Node, pos: Vector3, angle_y: float = 0.0) -> void:
	var car_mat := StandardMaterial3D.new()
	car_mat.albedo_color = Color(0.18, 0.18, 0.2)

	var body := CSGBox3D.new()
	body.size = Vector3(2.0, 0.8, 4.2)
	body.position = pos + Vector3(0.0, 0.4, 0.0)
	body.rotation_degrees.y = angle_y
	body.use_collision = true
	body.material = car_mat
	parent.add_child(body)

	var roof := CSGBox3D.new()
	roof.size = Vector3(1.8, 0.6, 2.2)
	roof.position = pos + Vector3(0.0, 1.1, 0.0)
	roof.rotation_degrees.y = angle_y
	roof.use_collision = true
	roof.material = car_mat
	parent.add_child(roof)


# ---------------------------------------------------------------------------
# Helper: dumpster
# ---------------------------------------------------------------------------

func _add_dumpster(parent: Node, pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.35, 0.1)
	var d := CSGBox3D.new()
	d.size = Vector3(1.2, 1.0, 2.0)
	d.position = pos + Vector3(0.0, 0.5, 0.0)
	d.use_collision = true
	d.material = mat
	parent.add_child(d)


# ---------------------------------------------------------------------------
# Helper: crate stack
# ---------------------------------------------------------------------------

func _add_crate_stack(parent: Node, pos: Vector3, count: int = 3) -> void:
	var mat := _make_material(MAT_WOOD, Color(0.45, 0.3, 0.15))
	for i in range(count):
		var sz := Vector3(0.8, 0.8, 0.8)
		var p := pos + Vector3(0.0, sz.y * 0.5 + sz.y * i, 0.0)
		_add_csg_box(parent, p, sz, mat)


# ---------------------------------------------------------------------------
# Helper: sandbag row
# ---------------------------------------------------------------------------

func _add_sandbag_row(parent: Node, start: Vector3, count: int, axis: String = "x") -> void:
	var mat := _make_material(MAT_STONE, Color(0.55, 0.50, 0.38))
	for i in range(count):
		var pos := start
		if axis == "x":
			pos.x += i * 0.55
		else:
			pos.z += i * 0.55
		var bag := CSGBox3D.new()
		bag.size = Vector3(0.5, 0.4, 0.3)
		bag.position = pos + Vector3(0.0, 0.2, 0.0)
		bag.use_collision = true
		bag.material = mat
		parent.add_child(bag)


# ---------------------------------------------------------------------------
# SECTION 1: Staging area
# ---------------------------------------------------------------------------

func _build_staging_area() -> void:
	var root := Node3D.new()
	root.name = "StagingArea"
	add_child(root)

	var concrete := _make_material(MAT_CONCRETE, Color(0.5, 0.5, 0.5))
	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.3, 0.3, 0.35)

	# Floor pad
	_add_csg_box(root, Vector3(0, 0, 0), Vector3(20.0, 0.1, 15.0), concrete, "StagingFloor")

	# Tent roof (flat canopy)
	var tent_mat := StandardMaterial3D.new()
	tent_mat.albedo_color = Color(0.3, 0.35, 0.25)
	_add_csg_box(root, Vector3(0, 3.5, 2), Vector3(8.0, 0.15, 6.0), tent_mat, "TentRoof")

	# Tent poles
	for px in [-3.5, 3.5]:
		for pz in [-0.5, 4.5]:
			var pole := CSGCylinder3D.new()
			pole.radius = 0.05
			pole.height = 3.5
			pole.position = Vector3(px, 1.75, pz)
			pole.use_collision = true
			pole.material = metal_mat
			root.add_child(pole)

	# Sandbag barriers — perimeter
	_add_sandbag_row(root, Vector3(-8.0, 0.0, -6.0), 12, "x")
	_add_sandbag_row(root, Vector3(-8.0, 0.0, 6.0), 12, "x")
	_add_sandbag_row(root, Vector3(-8.0, 0.0, -6.0), 8, "z")
	_add_sandbag_row(root, Vector3(8.0, 0.0, -6.0), 8, "z")

	# Armory — crate stack near tent
	_add_crate_stack(root, Vector3(-5.0, 0.0, -3.0), 3)
	_add_crate_stack(root, Vector3(-4.0, 0.0, -3.0), 2)
	_add_crate_stack(root, Vector3(-5.0, 0.0, -2.0), 1)

	# Concrete barriers
	_add_csg_box(root, Vector3(5.0, 0.4, -4.0), Vector3(2.5, 0.8, 0.4), concrete)
	_add_csg_box(root, Vector3(5.0, 0.4, 4.0), Vector3(2.5, 0.8, 0.4), concrete)


# ---------------------------------------------------------------------------
# SECTION 2: Street A
# ---------------------------------------------------------------------------

func _build_street_a() -> void:
	var root := Node3D.new()
	root.name = "StreetA"
	add_child(root)

	var concrete := _make_material(MAT_CONCRETE, Color(0.48, 0.48, 0.48))
	var wall_mat := _make_material(MAT_TILEWALL, Color(0.70, 0.70, 0.72))
	var road_mat := _make_material(MAT_STONE, Color(0.28, 0.28, 0.30))

	# Road surface
	_add_csg_box(root, Vector3(0.0, 0.01, 35.0), Vector3(8.0, 0.08, 40.0), road_mat, "Road")

	# Sidewalks
	_add_csg_box(root, Vector3(-5.5, 0.1, 35.0), Vector3(3.0, 0.1, 40.0), concrete, "SidewalkLeft")
	_add_csg_box(root, Vector3(5.5, 0.1, 35.0), Vector3(3.0, 0.1, 40.0), concrete, "SidewalkRight")

	# Buildings — left side (z: 15 to 55)
	var building_positions_left := [
		[Vector3(-10.0, 4.0, 22.0), Vector3(6.0, 8.0, 12.0)],
		[Vector3(-10.0, 4.0, 36.0), Vector3(6.0, 8.0, 14.0)],
		[Vector3(-10.0, 4.0, 50.0), Vector3(6.0, 8.0, 10.0)],
	]
	for bd in building_positions_left:
		var pos: Vector3 = bd[0]
		var sz: Vector3 = bd[1]
		_add_csg_box(root, pos, sz, wall_mat)
		_add_windows(root, pos, sz, wall_mat, "left")

	# Buildings — right side
	var building_positions_right := [
		[Vector3(10.0, 4.0, 22.0), Vector3(6.0, 8.0, 12.0)],
		[Vector3(10.0, 4.0, 36.0), Vector3(6.0, 8.0, 14.0)],
		[Vector3(10.0, 4.0, 50.0), Vector3(6.0, 8.0, 10.0)],
	]
	for bd in building_positions_right:
		var pos: Vector3 = bd[0]
		var sz: Vector3 = bd[1]
		_add_csg_box(root, pos, sz, wall_mat)
		_add_windows(root, pos, sz, wall_mat, "right")

	# Overturned cars
	_add_car(root, Vector3(-2.0, 0.0, 24.0), 15.0)
	_add_car(root, Vector3(2.5, 0.0, 38.0), -10.0)
	_add_car(root, Vector3(-1.0, 0.0, 50.0), 5.0)

	# Dumpsters
	_add_dumpster(root, Vector3(-4.5, 0.0, 28.0))
	_add_dumpster(root, Vector3(4.0, 0.0, 42.0))

	# Street lights
	_add_street_light(root, Vector3(-3.5, 0.0, 20.0))
	_add_street_light(root, Vector3(3.5, 0.0, 30.0))
	_add_street_light(root, Vector3(-3.5, 0.0, 42.0))
	_add_street_light(root, Vector3(3.5, 0.0, 52.0))


func _add_windows(parent: Node, building_pos: Vector3, building_size: Vector3, _wall_mat: Material, side: String) -> void:
	# Simple window holes using CSGBox3D with operation = SUBTRACT would require CSGCombiner
	# We represent windows as dark recessed boxes (inset) since CSGBox subtraction works best with CSGCombiner
	var win_mat := StandardMaterial3D.new()
	win_mat.albedo_color = Color(0.05, 0.07, 0.12)
	# Place window-sized dark boxes slightly inset into walls
	var floors := 2
	var windows_per_floor := 2
	for fl in range(floors):
		for w in range(windows_per_floor):
			var win := CSGBox3D.new()
			win.size = Vector3(0.8, 1.0, 0.15)
			var offset_x := -0.8 + w * 1.8
			var offset_y := 1.5 + fl * 3.5
			var offset_z: float
			if side == "left":
				offset_z = building_size.z * 0.5 + 0.05
			else:
				offset_z = -building_size.z * 0.5 - 0.05
			win.position = building_pos + Vector3(offset_x, offset_y - building_size.y * 0.5, offset_z)
			win.use_collision = false
			win.material = win_mat
			parent.add_child(win)


# ---------------------------------------------------------------------------
# SECTION 3: Side alley
# ---------------------------------------------------------------------------

func _build_side_alley() -> void:
	var root := Node3D.new()
	root.name = "SideAlley"
	add_child(root)

	var concrete := _make_material(MAT_CONCRETE, Color(0.38, 0.38, 0.38))
	var wall_mat := _make_material(MAT_TILEWALL, Color(0.55, 0.55, 0.58))
	var pipe_mat := StandardMaterial3D.new()
	pipe_mat.albedo_color = Color(0.3, 0.3, 0.35)

	# Alley floor
	_add_csg_box(root, Vector3(-11.0, 0.01, 48.0), Vector3(3.0, 0.08, 16.0), concrete, "AlleyFloor")

	# Alley walls
	_add_csg_box(root, Vector3(-9.0, 3.0, 48.0), Vector3(0.3, 6.0, 16.0), wall_mat)
	_add_csg_box(root, Vector3(-13.0, 3.0, 48.0), Vector3(0.3, 6.0, 16.0), wall_mat)

	# Crates
	_add_crate_stack(root, Vector3(-10.5, 0.0, 44.0), 2)
	_add_crate_stack(root, Vector3(-11.5, 0.0, 52.0), 1)

	# Pipes along wall
	for pz in [42.0, 46.0, 50.0, 54.0]:
		var pipe := CSGCylinder3D.new()
		pipe.radius = 0.06
		pipe.height = 5.5
		pipe.position = Vector3(-12.8, 2.75, pz)
		pipe.rotation_degrees.x = 0.0
		pipe.use_collision = true
		pipe.material = pipe_mat
		root.add_child(pipe)

	# Dead body prop (simple box stand-in)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.25, 0.15, 0.10)
	var body_mesh := CSGBox3D.new()
	body_mesh.size = Vector3(0.4, 0.3, 1.7)
	body_mesh.position = Vector3(-11.0, 0.15, 56.0)
	body_mesh.rotation_degrees.z = 10.0
	body_mesh.use_collision = true
	body_mesh.material = body_mat
	root.add_child(body_mesh)

	# Dim light at alley entrance
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-11.0, 3.5, 44.0)
	lamp.light_color = Color(0.9, 0.8, 0.6)
	lamp.light_energy = 1.0
	lamp.omni_range = 8.0
	root.add_child(lamp)


# ---------------------------------------------------------------------------
# SECTION 4: Plaza
# ---------------------------------------------------------------------------

func _build_plaza() -> void:
	var root := Node3D.new()
	root.name = "Plaza"
	add_child(root)

	var concrete := _make_material(MAT_CONCRETE, Color(0.52, 0.52, 0.52))
	var wall_mat := _make_material(MAT_TILEWALL, Color(0.68, 0.68, 0.70))

	# Plaza floor
	_add_csg_box(root, Vector3(0.0, 0.01, 70.0), Vector3(20.0, 0.08, 20.0), concrete, "PlazaFloor")

	# Fountain base
	var fountain_base := CSGCylinder3D.new()
	fountain_base.radius = 2.2
	fountain_base.height = 0.5
	fountain_base.position = Vector3(0.0, 0.25, 70.0)
	fountain_base.use_collision = true
	fountain_base.material = concrete
	root.add_child(fountain_base)

	# Fountain rim
	var fountain_rim := CSGCylinder3D.new()
	fountain_rim.radius = 2.2
	fountain_rim.height = 0.4
	fountain_rim.position = Vector3(0.0, 0.5, 70.0)
	fountain_rim.use_collision = true
	fountain_rim.material = concrete
	root.add_child(fountain_rim)

	# Fountain center pillar
	var pillar := CSGCylinder3D.new()
	pillar.radius = 0.3
	pillar.height = 1.5
	pillar.position = Vector3(0.0, 1.0, 70.0)
	pillar.use_collision = true
	pillar.material = concrete
	root.add_child(pillar)

	# Buildings around perimeter
	var plaza_buildings := [
		[Vector3(-12.0, 4.5, 63.0), Vector3(5.0, 9.0, 6.0)],
		[Vector3(12.0, 4.5, 63.0), Vector3(5.0, 9.0, 6.0)],
		[Vector3(-12.0, 4.5, 77.0), Vector3(5.0, 9.0, 6.0)],
		[Vector3(12.0, 4.5, 77.0), Vector3(5.0, 9.0, 6.0)],
		[Vector3(0.0, 4.5, 82.0), Vector3(12.0, 9.0, 4.0)],
	]
	for bd in plaza_buildings:
		var pos: Vector3 = bd[0]
		var sz: Vector3 = bd[1]
		_add_csg_box(root, pos, sz, wall_mat)

	# Concrete cover barriers
	var barrier_positions := [
		Vector3(-5.0, 0.4, 65.0),
		Vector3(5.0, 0.4, 65.0),
		Vector3(-5.0, 0.4, 75.0),
		Vector3(5.0, 0.4, 75.0),
		Vector3(-7.0, 0.4, 70.0),
		Vector3(7.0, 0.4, 70.0),
	]
	for bp in barrier_positions:
		_add_csg_box(root, bp, Vector3(2.5, 0.8, 0.4), concrete)

	# Plaza lamp
	_add_street_light(root, Vector3(-8.0, 0.0, 63.0))
	_add_street_light(root, Vector3(8.0, 0.0, 77.0))


# ---------------------------------------------------------------------------
# SECTION 5: Interior
# ---------------------------------------------------------------------------

func _build_interior() -> void:
	var root := Node3D.new()
	root.name = "Interior"
	add_child(root)

	var concrete := _make_material(MAT_CONCRETE, Color(0.42, 0.42, 0.42))
	var wall_mat := _make_material(MAT_TILEWALL, Color(0.62, 0.60, 0.58))
	var floor_mat := _make_material(MAT_WOOD, Color(0.40, 0.28, 0.18))
	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.3, 0.3, 0.35)

	# Exterior shell — hollow building (walls only, no ceiling for now)
	var bx := 8.0
	var bz := 88.0

	# Walls
	_add_csg_box(root, Vector3(-5.0, 4.0, bz), Vector3(0.4, 8.0, 12.0), wall_mat)   # left wall
	_add_csg_box(root, Vector3(5.0, 4.0, bz), Vector3(0.4, 8.0, 12.0), wall_mat)    # right wall
	_add_csg_box(root, Vector3(0.0, 4.0, bz + 6.0), Vector3(10.4, 8.0, 0.4), wall_mat)  # back wall
	# Front wall with doorway gap
	_add_csg_box(root, Vector3(-3.5, 4.0, bz - 6.0), Vector3(3.4, 8.0, 0.4), wall_mat)
	_add_csg_box(root, Vector3(3.5, 4.0, bz - 6.0), Vector3(3.4, 8.0, 0.4), wall_mat)
	_add_csg_box(root, Vector3(0.0, 7.0, bz - 6.0), Vector3(3.0, 2.0, 0.4), wall_mat)  # above doorway

	# Floor
	_add_csg_box(root, Vector3(0.0, 0.05, bz), Vector3(10.0, 0.1, 12.0), floor_mat)

	# Second floor slab
	_add_csg_box(root, Vector3(0.0, 4.2, bz), Vector3(10.0, 0.2, 12.0), concrete, "SecondFloor")

	# Interior ceiling
	_add_csg_box(root, Vector3(0.0, 8.25, bz), Vector3(10.4, 0.3, 12.4), concrete, "Ceiling")

	# Staircase — simple ramp CSGBox
	_add_csg_box(root, Vector3(-3.5, 2.1, bz + 1.0), Vector3(2.0, 4.2, 6.0), concrete, "Stair")

	# Radio equipment (CSGBox3D stand-ins)
	_add_csg_box(root, Vector3(2.0, 0.7, bz + 4.5), Vector3(1.5, 1.2, 0.6), metal_mat, "RadioDesk")
	_add_csg_box(root, Vector3(2.0, 1.6, bz + 4.5), Vector3(1.2, 0.5, 0.4), metal_mat, "RadioStack")
	_add_csg_box(root, Vector3(3.0, 0.7, bz + 4.5), Vector3(0.6, 1.2, 0.6), metal_mat, "RadioUnit2")

	# Crates on second floor
	_add_crate_stack(root, Vector3(3.0, 4.4, bz + 3.0), 2)

	# Warm yellow interior lighting
	var lamp1 := OmniLight3D.new()
	lamp1.position = Vector3(0.0, 3.5, bz)
	lamp1.light_color = Color(1.0, 0.9, 0.6)
	lamp1.light_energy = 1.5
	lamp1.omni_range = 8.0
	root.add_child(lamp1)

	var lamp2 := OmniLight3D.new()
	lamp2.position = Vector3(0.0, 7.5, bz)
	lamp2.light_color = Color(1.0, 0.88, 0.55)
	lamp2.light_energy = 1.2
	lamp2.omni_range = 8.0
	root.add_child(lamp2)


# ---------------------------------------------------------------------------
# SECTION 6: End area (Biden's safehouse)
# ---------------------------------------------------------------------------

func _build_end_area() -> void:
	var root := Node3D.new()
	root.name = "EndArea"
	add_child(root)

	var concrete := _make_material(MAT_CONCRETE, Color(0.44, 0.42, 0.40))
	var wall_mat := _make_material(MAT_TILEWALL, Color(0.55, 0.52, 0.50))
	var wood_mat := _make_material(MAT_WOOD, Color(0.35, 0.22, 0.12))

	var bz := 105.0

	# Safehouse exterior walls
	_add_csg_box(root, Vector3(-5.5, 4.0, bz), Vector3(0.4, 8.0, 10.0), wall_mat)
	_add_csg_box(root, Vector3(5.5, 4.0, bz), Vector3(0.4, 8.0, 10.0), wall_mat)
	_add_csg_box(root, Vector3(0.0, 4.0, bz + 5.0), Vector3(11.4, 8.0, 0.4), wall_mat)
	# Front with door gap
	_add_csg_box(root, Vector3(-3.8, 4.0, bz - 5.0), Vector3(3.8, 8.0, 0.4), wall_mat)
	_add_csg_box(root, Vector3(3.8, 4.0, bz - 5.0), Vector3(3.8, 8.0, 0.4), wall_mat)
	_add_csg_box(root, Vector3(0.0, 6.8, bz - 5.0), Vector3(3.8, 2.4, 0.4), wall_mat)

	# Roof
	_add_csg_box(root, Vector3(0.0, 8.25, bz), Vector3(11.4, 0.4, 10.4), concrete, "SafehouseRoof")

	# Floor
	_add_csg_box(root, Vector3(0.0, 0.05, bz), Vector3(11.0, 0.1, 10.0), concrete)

	# Boarded windows — dark wood boards over window openings
	var board_positions := [
		Vector3(-5.4, 3.5, bz - 1.0),
		Vector3(-5.4, 3.5, bz + 1.5),
		Vector3(5.4, 3.5, bz - 1.0),
		Vector3(5.4, 3.5, bz + 1.5),
	]
	for bp in board_positions:
		_add_csg_box(root, bp, Vector3(0.1, 1.0, 1.0), wood_mat)

	# Cover outside
	_add_csg_box(root, Vector3(-3.0, 0.4, bz - 7.5), Vector3(2.5, 0.8, 0.4), concrete)
	_add_csg_box(root, Vector3(3.0, 0.4, bz - 7.5), Vector3(2.5, 0.8, 0.4), concrete)

	# Level complete trigger
	var trigger := Area3D.new()
	trigger.name = "LevelCompleteTrigger"

	var cshape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(6.0, 3.0, 4.0)
	cshape.shape = box_shape
	trigger.add_child(cshape)

	trigger.position = Vector3(0.0, 1.5, bz + 1.0)
	root.add_child(trigger)

	trigger.body_entered.connect(_on_level_complete)


# ---------------------------------------------------------------------------
# Level complete handler
# ---------------------------------------------------------------------------

func _on_level_complete(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _level_complete_triggered:
		return
	_level_complete_triggered = true

	SubtitleManager.show_subtitle_direct("Target located. Mission complete.", 4.0, "Commander")

	var radio_path := "res://sounds/misc/radio_beep.wav"
	if ResourceLoader.exists(radio_path):
		AudioManager.play_sfx(radio_path)

	await get_tree().create_timer(3.0).timeout
	GameManager.complete_level()


# ---------------------------------------------------------------------------
# NPC spawning
# ---------------------------------------------------------------------------

func _spawn_npcs() -> void:
	# HECU Soldier at staging area
	if ResourceLoader.exists(HECU_SOLDIER_SCENE):
		var hecu_scene := ResourceLoader.load(HECU_SOLDIER_SCENE) as PackedScene
		if hecu_scene != null:
			var hecu := hecu_scene.instantiate()
			hecu.position = Vector3(3.0, 0.5, 2.0)
			add_child(hecu)

	# Resistance soldiers
	if ResourceLoader.exists(RESISTANCE_SOLDIER_SCENE):
		var rs_scene := ResourceLoader.load(RESISTANCE_SOLDIER_SCENE) as PackedScene
		if rs_scene != null:
			# Street A
			# Keep clear of the building footprints at |x| >= 7.
			var street_positions := [
				Vector3(4.0, 0.5, 25.0),
				Vector3(5.0, 0.5, 40.0),
				Vector3(-5.5, 0.5, 35.0),
			]
			for pos in street_positions:
				var rs := rs_scene.instantiate()
				rs.position = pos
				add_child(rs)

			# Alley
			var alley_positions := [
				Vector3(-8.0, 0.5, 48.0),
				Vector3(-8.0, 0.5, 55.0),
			]
			for pos in alley_positions:
				var rs := rs_scene.instantiate()
				rs.position = pos
				add_child(rs)

			# Plaza
			var plaza_positions := [
				Vector3(-3.0, 0.5, 65.0),
				Vector3(3.0, 0.5, 65.0),
				Vector3(-6.0, 0.5, 70.0),
				Vector3(6.0, 0.5, 70.0),
				Vector3(0.0, 0.5, 74.0),
			]
			for pos in plaza_positions:
				var rs := rs_scene.instantiate()
				rs.position = pos
				add_child(rs)

			# Interior
			var interior_positions := [
				Vector3(-2.0, 0.5, 87.0),
				Vector3(2.5, 0.5, 89.0),
				Vector3(0.0, 4.7, 88.0),
			]
			for pos in interior_positions:
				var rs := rs_scene.instantiate()
				rs.position = pos
				add_child(rs)


# ---------------------------------------------------------------------------
# Pickup spawning
# ---------------------------------------------------------------------------

func _spawn_pickups() -> void:
	# Weapon pickup in armory
	if ResourceLoader.exists(WEAPON_PICKUP_SCENE):
		var wp_scene := ResourceLoader.load(WEAPON_PICKUP_SCENE) as PackedScene
		if wp_scene != null:
			var wp := wp_scene.instantiate()
			wp.position = Vector3(-5.0, 1.5, -3.0)
			if wp.has_method("set") and "weapon_type" in wp:
				wp.weapon_type = "mp5"
				wp.ammo_count = 45
			add_child(wp)

			var wp2 := wp_scene.instantiate()
			wp2.position = Vector3(-4.0, 0.6, -2.0)
			if "weapon_type" in wp2:
				wp2.weapon_type = "pistol"
				wp2.ammo_count = 20
			add_child(wp2)

	# Health pickups in alley
	if ResourceLoader.exists(HEALTH_PICKUP_SCENE):
		var hp_scene := ResourceLoader.load(HEALTH_PICKUP_SCENE) as PackedScene
		if hp_scene != null:
			var hp_positions := [
				Vector3(-11.0, 0.3, 46.0),
				Vector3(-11.0, 0.3, 53.0),
			]
			for pos in hp_positions:
				var hp := hp_scene.instantiate()
				hp.position = pos
				add_child(hp)


# ---------------------------------------------------------------------------
# Ambient sound zone at staging area
# ---------------------------------------------------------------------------

func _add_ambient_sound() -> void:
	var ambient_path := "res://sounds/ambient/ambience_base_hum.wav"
	var audio := AudioStreamPlayer3D.new()
	audio.name = "StagingAreaAmbient"
	audio.position = Vector3(0.0, 1.0, 0.0)
	audio.max_distance = 25.0
	audio.volume_db = -8.0

	if ResourceLoader.exists(ambient_path):
		var stream := ResourceLoader.load(ambient_path) as AudioStream
		if stream != null:
			audio.stream = stream
			audio.autoplay = true

	add_child(audio)
