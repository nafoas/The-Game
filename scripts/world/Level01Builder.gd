extends Node3D

## Builds the whole City-17-style level procedurally out of CSG zone geometry
## dressed with real HL2 (EP2) MDL props and VTF triplanar materials via the
## shared SourceMaterials helper. Gameplay anchors (spawn points, pickups,
## trigger volumes, NPC positions) are unchanged from the verified layout.

const HECU_SOLDIER_SCENE := "res://scenes/npc/HECUSoldier.tscn"
const RESISTANCE_SOLDIER_SCENE := "res://scenes/npc/ResistanceSoldier.tscn"
const WEAPON_PICKUP_SCENE := "res://scenes/world/WeaponPickup.tscn"
const HEALTH_PICKUP_SCENE := "res://scenes/world/HealthPickup.tscn"
const FLICKER_SCRIPT := "res://scripts/world/Flicker.gd"

# Model shorthand
const MDL := {
	"hatchback": "res://models/props_vehicles/car001b_hatchback.mdl",
	"van": "res://models/props_vehicles/van001a_nodoor.mdl",
	"truck": "res://models/props_vehicles/truck001a.mdl",
	"dumpster": "res://models/props_lab/scrapyarddumpster_static.mdl",
	"oildrum": "res://models/props_c17/oildrum_crush.mdl",
	"propane": "res://models/props_junk/propane_tank001a.mdl",
	"spool": "res://models/props_junk/wood_spool01.mdl",
	"bicycle": "res://models/props_junk/bicycle01a.mdl",
	"gnome": "res://models/props_junk/gnome.mdl",
	"ibeam": "res://models/props_junk/ibeam01b_cluster01.mdl",
	"barricade_x": "res://models/props_wasteland/barricade002a.mdl",
	"barricade_tri": "res://models/props_wasteland/barricade001a.mdl",
	"fence_chain": "res://models/props_wasteland/interior_fence002d.mdl",
	"fence_gate": "res://models/props_wasteland/interior_fence004b.mdl",
	"rubble_slab": "res://models/props_debris/concrete_section64floor001a.mdl",
	"rebar": "res://models/props_debris/rebar002a_32.mdl",
	"lockers": "res://models/props_c17/lockers001a.mdl",
	"stool": "res://models/props_c17/chair_stool01a.mdl",
	"powerbox": "res://models/props_c17/powerbox.mdl",
	"bell_light": "res://models/props_c17/light_industrialbell01_on.mdl",
	"ladder": "res://models/props_c17/metalladder004.mdl",
	"propane_big": "res://models/props_c17/canister_propane01a.mdl",
	"cooler": "res://models/props_c17/display_cooler01a.mdl",
	"door": "res://models/props_c17/door01_left.mdl",
	"hospital_bed": "res://models/props_c17/hospital_bed01.mdl",
	"clock": "res://models/props_c17/clock01.mdl",
	"sconce": "res://models/props_interiors/lightsconce01.mdl",
	"radiator": "res://models/props_interiors/radiator01a.mdl",
	"footlocker": "res://models/props_forest/footlocker01_closed.mdl",
	"bunkbed": "res://models/props_forest/bunkbed.mdl",
	"shelf": "res://models/props_forest/furniture_shelf01a.mdl",
	"radio": "res://models/props_lab/citizenradio.mdl",
	"receiver_b": "res://models/props_lab/reciever01b.mdl",
	"receiver_d": "res://models/props_lab/reciever01d.mdl",
	"monitor_sm": "res://models/props_lab/monitor01b.mdl",
	"monitor": "res://models/props_lab/monitor02.mdl",
	"frame": "res://models/props_lab/frame002a.mdl",
	"generator": "res://models/props_mining/diesel_generator.mdl",
	"generator_b": "res://models/props_outland/generator_static01a.mdl",
	"butane": "res://models/props_explosive/explosive_butane_can.mdl",
	"ammocrate_p": "res://models/items/ammocrate_pistol.mdl",
	"ammocrate_s": "res://models/items/ammocrate_smg2.mdl",
	"beacon_crate": "res://models/items/item_beacon_crate.mdl",
	"console": "res://models/props_silo/desk_console1.mdl",
	"equipment": "res://models/props_silo/equipment1.mdl",
	"indust_light": "res://models/props_silo/industriallight01.mdl",
	"handtruck": "res://models/props_silo/handtruck.mdl",
	"acunit": "res://models/props_silo/acunit01.mdl",
	"chimney": "res://models/props_silo/chimneycluster01.mdl",
	"bush": "res://models/props_foliage/bush2.mdl",
	"grass": "res://models/props_foliage/grass_cluster01.mdl",
	"antenna": "res://models/props_radiostation/radio_antenna01.mdl",
	"corpse": "res://models/barney.mdl",
	"wall_ruin": "res://models/props_debris/walldestroyed02a.mdl",
}

var _level_complete_triggered: bool = false
var _lit_window_count: int = 0


func _ready() -> void:
	GameManager.checkpoint_position = Vector3(0, 1, 0)

	_build_world_environment()
	_build_ground()
	_build_staging_area()
	_build_street_a()
	_build_side_alley()
	_build_plaza()
	_build_interior()
	_build_end_area()
	_build_skyline()
	_spawn_npcs()
	_spawn_pickups()
	_add_ambient_zones()


# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

func _build_world_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()

	# Overcast dusk — dim, slightly cold gray for that Source-era gloom
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.31, 0.34, 0.39)

	env.fog_enabled = true
	env.fog_light_color = Color(0.34, 0.37, 0.42)
	env.fog_light_energy = 1.0
	env.fog_density = 0.016

	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6

	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.94

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.43, 0.5)
	env.ambient_light_energy = 0.55

	world_env.environment = env
	add_child(world_env)

	var dir_light := DirectionalLight3D.new()
	dir_light.name = "SunLight"
	dir_light.light_color = Color(0.74, 0.77, 0.86)
	dir_light.light_energy = 0.75
	dir_light.shadow_enabled = true
	dir_light.directional_shadow_max_distance = 70.0
	dir_light.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	add_child(dir_light)


# ---------------------------------------------------------------------------
# Small construction helpers
# ---------------------------------------------------------------------------

func _csg(parent: Node, pos: Vector3, size: Vector3, mat: Material, name_str: String = "") -> CSGBox3D:
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


## Non-collidable decorative box (windows, trims, skyline...) — cheaper.
func _deco(parent: Node, pos: Vector3, size: Vector3, mat: Material, name_str: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if name_str != "":
		mi.name = name_str
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	if mat != null:
		mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _prop(parent: Node, key: String, pos: Vector3, rot_y: float = 0.0,
		scale: float = SourceMaterials.MDL_SCALE) -> Node3D:
	return SourceMaterials.spawn_model(parent, MDL.get(key, ""), pos, rot_y, scale)


func _omni(parent: Node, pos: Vector3, color: Color, energy: float, range_m: float,
		shadows: bool = false) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.position = pos
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = range_m
	lamp.shadow_enabled = shadows
	lamp.omni_attenuation = 1.4
	parent.add_child(lamp)
	return lamp


func _add_flicker(light: Light3D, cone: GeometryInstance3D = null) -> void:
	var script: GDScript = load(FLICKER_SCRIPT)
	if script == null:
		return
	var flicker: Node = script.new()
	light.add_child(flicker)
	if cone != null and flicker.has_method("link_cone"):
		flicker.link_cone(cone)


## Building facade: main box + cornice trim + baseboard + window grid with a
## few warm lit panes. `faces` lists which sides get windows: "+x","-x","+z","-z".
func _building(parent: Node, pos: Vector3, size: Vector3, facade_key: String,
		faces: Array = [], name_str: String = "") -> void:
	var facade := SourceMaterials.mat(facade_key)
	_csg(parent, pos, size, facade, name_str)

	var trim := SourceMaterials.mat("trim")
	var base := SourceMaterials.mat("baseboard")
	var top_y := pos.y + size.y * 0.5
	var bot_y := pos.y - size.y * 0.5

	# Cornice band at roofline + baseboard course at street level
	_deco(parent, Vector3(pos.x, top_y - 0.18, pos.z),
		Vector3(size.x + 0.16, 0.36, size.z + 0.16), trim)
	_deco(parent, Vector3(pos.x, bot_y + 0.35, pos.z),
		Vector3(size.x + 0.12, 0.7, size.z + 0.12), base)

	# Rooftop clutter for taller buildings
	if size.y >= 7.0 and randf() < 0.9:
		if randf() < 0.5:
			_prop(parent, "acunit", Vector3(pos.x, top_y + 1.62, pos.z + size.z * 0.15), randf_range(0, 360))
		else:
			_prop(parent, "chimney", Vector3(pos.x, top_y, pos.z - size.z * 0.2), randf_range(0, 360))

	for face in faces:
		_window_grid(parent, pos, size, face)


func _window_grid(parent: Node, bpos: Vector3, bsize: Vector3, face: String) -> void:
	var sill := SourceMaterials.mat("trim")

	var along_z := face == "+x" or face == "-x"
	var length := bsize.z if along_z else bsize.x
	var cols := maxi(int(length / 3.2), 1)
	var floors := maxi(int((bsize.y - 2.0) / 3.0), 1)
	var spacing := length / float(cols)

	for fl in range(floors):
		var wy := bpos.y - bsize.y * 0.5 + 1.9 + fl * 3.0
		for c in range(cols):
			var t := (c + 0.5) / float(cols) - 0.5
			_lit_window_count += 1
			var is_lit := (_lit_window_count % 5) == 2
			var pane := SourceMaterials.window_pane_mat(is_lit)

			var win_pos: Vector3
			var rot_y: float
			var sill_size: Vector3
			if along_z:
				var face_x := bpos.x + (bsize.x * 0.5 + 0.04) * (1.0 if face == "+x" else -1.0)
				win_pos = Vector3(face_x, wy, bpos.z + t * length)
				rot_y = 90.0 if face == "+x" else -90.0
				sill_size = Vector3(0.18, 0.12, 1.15)
			else:
				var face_z := bpos.z + (bsize.z * 0.5 + 0.04) * (1.0 if face == "+z" else -1.0)
				win_pos = Vector3(bpos.x + t * length, wy, face_z)
				rot_y = 0.0 if face == "+z" else 180.0
				sill_size = Vector3(1.15, 0.12, 0.18)

			_window_quad(parent, win_pos, rot_y, Vector2(1.0, 1.4), pane)
			# Sill below + dark inset frame behind
			_deco(parent, win_pos + Vector3(0, -0.78, 0), sill_size, sill)
		# avoid windows colliding with spacing oddities on tiny walls
		if spacing < 2.0:
			break


func _window_quad(parent: Node, pos: Vector3, rot_y: float, size: Vector2,
		mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = Vector3(0.0, rot_y, 0.0)
	parent.add_child(mi)
	return mi


## Street lamp: pole + arm + industrial bell head model + warm light + cone.
func _street_lamp(parent: Node, pos: Vector3, arm_dir: float = 0.0, flicker: bool = false) -> void:
	var metal := SourceMaterials.mat("metal")
	var pole := CSGCylinder3D.new()
	pole.radius = 0.07
	pole.height = 4.8
	pole.sides = 10
	pole.position = pos + Vector3(0.0, 2.4, 0.0)
	pole.use_collision = true
	pole.material = metal
	parent.add_child(pole)

	var arm_offset := Vector3(sin(deg_to_rad(arm_dir)), 0.0, cos(deg_to_rad(arm_dir))) * 0.75
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.08, 0.08, 0.9)
	arm.mesh = arm_mesh
	arm.material_override = metal
	arm.position = pos + Vector3(arm_offset.x * 0.5, 4.65, arm_offset.z * 0.5)
	arm.rotation_degrees.y = arm_dir
	parent.add_child(arm)

	var head_pos := pos + Vector3(arm_offset.x, 4.62, arm_offset.z)
	_prop(parent, "bell_light", head_pos, arm_dir, 1.0)

	var lamp := _omni(parent, head_pos + Vector3(0, -0.35, 0), Color(1.0, 0.86, 0.6), 1.7, 11.0)
	var cone := SourceMaterials.add_light_cone(parent, head_pos + Vector3(0, -0.4, 0), 3.4, 1.5,
		Color(1.0, 0.86, 0.58), 0.045)
	if flicker:
		_add_flicker(lamp, cone)


func _concrete_barrier(parent: Node, pos: Vector3, rot_y: float = 0.0) -> void:
	var mat := SourceMaterials.mat("concrete_pad")
	var b := _csg(parent, pos + Vector3(0, 0.42, 0), Vector3(2.5, 0.84, 0.42), mat)
	b.rotation_degrees.y = rot_y
	var stripe := _deco(parent, pos + Vector3(0, 0.74, 0), Vector3(2.52, 0.2, 0.44),
		SourceMaterials.mat("hazard"))
	stripe.rotation_degrees.y = rot_y


func _sandbag_row(parent: Node, start: Vector3, count: int, axis: String = "x") -> void:
	var mat := SourceMaterials.mat("sandbag")
	for i in range(count):
		var pos := start
		if axis == "x":
			pos.x += i * 0.62
		else:
			pos.z += i * 0.62
		for layer in range(2):
			var bag := _csg(parent, pos + Vector3(0.0, 0.19 + layer * 0.34, 0.0),
				Vector3(0.6, 0.38, 0.42), mat)
			bag.rotation_degrees.y = randf_range(-7.0, 7.0)


func _crate_stack(parent: Node, pos: Vector3, count: int = 2) -> void:
	for i in range(count):
		var key := "beacon_crate" if i % 2 == 0 else "footlocker"
		var y := pos.y + i * 0.78
		if key == "footlocker":
			y += 0.33
		var p := _prop(parent, key, Vector3(pos.x, y, pos.z), randf_range(-20, 20))
		if p == null:
			_csg(parent, Vector3(pos.x, pos.y + 0.4 + i * 0.8, pos.z),
				Vector3(0.8, 0.8, 0.8), SourceMaterials.mat("wood_board"))


func _corpse(parent: Node, pos: Vector3, rot_y: float = 0.0) -> void:
	var body := SourceMaterials.spawn_model(parent, MDL["corpse"], pos + Vector3(0, 0.14, 0), rot_y)
	if body != null:
		body.rotation_degrees = Vector3(-88.0, rot_y, 4.0)
	# Dark pooled stain under the body
	var stain := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.75
	disc.bottom_radius = 0.75
	disc.height = 0.012
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.1, 0.02, 0.02, 0.8)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.roughness = 0.3
	disc.material = smat
	stain.mesh = disc
	stain.position = pos + Vector3(0.2, 0.015, 0.0)
	parent.add_child(stain)


func _smoke_column(parent: Node, pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 3.2
	p.preprocess = 3.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 9.0
	p.gravity = Vector3(0.18, 0.55, 0.0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.scale_amount_curve = _ramp_curve()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.06, 0.06, 0.07, 0.32)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = false
	mesh.material = m
	p.mesh = mesh
	p.position = pos
	parent.add_child(p)

	# Smouldering ember glow
	var ember := _omni(parent, pos + Vector3(0, 0.3, 0), Color(1.0, 0.45, 0.12), 0.9, 4.0)
	_add_flicker(ember)


func _ramp_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.35))
	c.add_point(Vector2(1.0, 1.0))
	return c


func _ambient_zone(pos: Vector3, size: Vector3, sound_path: String, vol_db: float) -> void:
	if not ResourceLoader.exists(sound_path):
		return
	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2  # player layer
	var script: GDScript = load("res://scripts/world/AmbientZone.gd")
	if script != null:
		zone.set_script(script)
		zone.set("ambient_sound_path", sound_path)
		zone.set("volume_db", vol_db)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	zone.add_child(cs)
	zone.position = pos
	add_child(zone)


## Looping positional ambient that always plays (no zone gating).
func _looping_sound(parent: Node, pos: Vector3, path: String, vol_db: float,
		max_dist: float = 18.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	SourceMaterials.make_wav_loop(stream)
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = vol_db
	player.max_distance = max_dist
	player.unit_size = 4.0
	player.autoplay = true
	player.position = pos
	parent.add_child(player)


# ---------------------------------------------------------------------------
# Ground — zoned floors instead of one stretched plane
# ---------------------------------------------------------------------------

func _build_ground() -> void:
	var root := Node3D.new()
	root.name = "Ground"
	add_child(root)

	# Base wasteland dirt slab under everything (collision base).
	var ground := StaticBody3D.new()
	ground.name = "GroundPlane"
	var cshape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(90.0, 0.4, 150.0)
	cshape.shape = box_shape
	ground.add_child(cshape)
	var mesh := MeshInstance3D.new()
	var plane_mesh := BoxMesh.new()
	plane_mesh.size = Vector3(90.0, 0.4, 150.0)
	mesh.mesh = plane_mesh
	mesh.material_override = SourceMaterials.mat("dirt")
	ground.add_child(mesh)
	ground.position = Vector3(0.0, -0.2, 40.0)
	root.add_child(ground)

	# Asphalt-style road strip through the street section (staging -> plaza).
	_csg(root, Vector3(0.0, 0.0, 34.0), Vector3(8.0, 0.12, 52.0),
		SourceMaterials.mat("road"), "Road")

	# Raised sidewalks with visible curbs.
	_csg(root, Vector3(-5.5, 0.0, 34.0), Vector3(3.0, 0.24, 52.0),
		SourceMaterials.mat("sidewalk"), "SidewalkLeft")
	_csg(root, Vector3(5.5, 0.0, 34.0), Vector3(3.0, 0.24, 52.0),
		SourceMaterials.mat("sidewalk"), "SidewalkRight")

	# Path from plaza to the end area.
	_csg(root, Vector3(0.0, 0.0, 90.0), Vector3(7.0, 0.1, 20.0),
		SourceMaterials.mat("concrete_old"), "EndPath")

	# Scattered dirt-edge dressing along the road fringe.
	for i in range(7):
		var z := 12.0 + i * 7.0
		var side: float = -1.0 if i % 2 == 0 else 1.0
		_prop(root, "grass", Vector3(side * randf_range(7.6, 8.4), 0.02, z), randf_range(0, 360))


# ---------------------------------------------------------------------------
# SECTION 1: Staging area (military FOB)
# ---------------------------------------------------------------------------

func _build_staging_area() -> void:
	var root := Node3D.new()
	root.name = "StagingArea"
	add_child(root)

	# Concrete pad
	_csg(root, Vector3(0, 0, 0), Vector3(20.0, 0.12, 15.0),
		SourceMaterials.mat("concrete_pad"), "StagingFloor")

	# Canvas command tent
	var tent_mat := StandardMaterial3D.new()
	tent_mat.albedo_color = Color(0.27, 0.3, 0.22)
	tent_mat.roughness = 1.0
	_csg(root, Vector3(0, 3.5, 2), Vector3(8.0, 0.14, 6.0), tent_mat, "TentRoof")
	# slight sag panels on the tent edges
	_deco(root, Vector3(0, 3.36, -0.9), Vector3(8.2, 0.1, 0.5), tent_mat)
	_deco(root, Vector3(0, 3.36, 4.9), Vector3(8.2, 0.1, 0.5), tent_mat)

	var metal := SourceMaterials.mat("metal")
	for px in [-3.5, 3.5]:
		for pz in [-0.5, 4.5]:
			var pole := CSGCylinder3D.new()
			pole.radius = 0.05
			pole.height = 3.5
			pole.sides = 8
			pole.position = Vector3(px, 1.75, pz)
			pole.use_collision = true
			pole.material = metal
			root.add_child(pole)

	# Hanging work light under the tent
	_prop(root, "bell_light", Vector3(0.0, 3.42, 2.0), 0.0, 1.0)
	var tent_light := _omni(root, Vector3(0.0, 2.9, 2.0), Color(1.0, 0.9, 0.65), 1.5, 8.0)
	tent_light.shadow_enabled = true
	SourceMaterials.add_light_cone(root, Vector3(0.0, 2.95, 2.0), 2.6, 1.6, Color(1.0, 0.9, 0.6), 0.04)

	# Sandbag perimeter
	_sandbag_row(root, Vector3(-8.0, 0.06, -6.0), 12, "x")
	_sandbag_row(root, Vector3(-8.0, 0.06, 6.0), 12, "x")
	_sandbag_row(root, Vector3(-8.6, 0.06, -6.0), 8, "z")
	_sandbag_row(root, Vector3(8.6, 0.06, -6.0), 8, "z")

	# Armory corner: ammo crates under the weapon pickups
	_prop(root, "ammocrate_s", Vector3(-5.0, 0.47, -3.0), 8.0)
	_prop(root, "ammocrate_p", Vector3(-4.0, 0.47, -2.0), -12.0)
	_prop(root, "footlocker", Vector3(-5.9, 0.38, -2.0), 95.0)
	_crate_stack(root, Vector3(-6.2, 0.06, -3.8), 2)

	# Field equipment
	_prop(root, "generator", Vector3(7.2, 0.07, -4.6), 25.0)
	_looping_sound(root, Vector3(7.2, 0.8, -4.6),
		"res://sounds/ambient/levels/caves/rumble3.wav", -16.0, 10.0)
	_prop(root, "equipment", Vector3(-2.6, 0.07, 4.2), 180.0)
	_prop(root, "handtruck", Vector3(6.0, 0.07, 3.6), -120.0)
	_prop(root, "propane_big", Vector3(7.6, 0.07, -2.8), 0.0)
	_prop(root, "oildrum", Vector3(-7.4, 0.43, 3.2), 40.0)

	# Map table with comms gear under the tent
	var table := _csg(root, Vector3(1.5, 0.5, 1.4), Vector3(1.8, 0.08, 0.9),
		SourceMaterials.mat("wood_board"), "MapTable")
	table.rotation_degrees.y = -8.0
	for leg_off in [Vector3(-0.8, 0.25, -0.35), Vector3(0.8, 0.25, -0.35),
			Vector3(-0.8, 0.25, 0.35), Vector3(0.8, 0.25, 0.35)]:
		_deco(root, Vector3(1.5, 0, 1.4) + leg_off, Vector3(0.07, 0.5, 0.07), metal)
	_prop(root, "monitor", Vector3(1.2, 0.55, 1.3), 160.0)
	_prop(root, "receiver_b", Vector3(2.0, 0.63, 1.5), 200.0)
	_prop(root, "stool", Vector3(0.6, 0.07, 0.4), 30.0)

	# Military truck parked at the pad edge
	_prop(root, "truck", Vector3(-7.0, 1.56, -10.5), 80.0)

	# Entry control point onto the street
	_concrete_barrier(root, Vector3(-3.2, 0.06, 8.6), 14.0)
	_concrete_barrier(root, Vector3(3.2, 0.06, 9.4), -10.0)
	_prop(root, "barricade_x", Vector3(0.2, 0.86, 10.6), 18.0)

	# Floodlight pole watching the exit
	_street_lamp(root, Vector3(-8.8, 0.06, 7.4), 140.0, false)


# ---------------------------------------------------------------------------
# SECTION 2: Street A
# ---------------------------------------------------------------------------

func _build_street_a() -> void:
	var root := Node3D.new()
	root.name = "StreetA"
	add_child(root)

	# Left side: two buildings then the alley gap (alley z 44..56), then corner block
	_building(root, Vector3(-10.0, 4.0, 22.5), Vector3(6.0, 8.0, 15.0), "brick_inn", ["+x"], "BldL1")
	_building(root, Vector3(-10.0, 4.0, 37.0), Vector3(6.0, 8.0, 14.0), "plaster_tan", ["+x"], "BldL2")
	_building(root, Vector3(-10.0, 3.25, 58.0), Vector3(6.0, 6.5, 4.0), "plaster_gray", ["+x"], "BldL3")
	# Tall block forming the alley's west wall
	_building(root, Vector3(-15.0, 4.5, 49.0), Vector3(4.0, 9.0, 20.0), "indust_wall", [], "BldLW")

	# Right side
	_building(root, Vector3(10.0, 4.0, 22.0), Vector3(6.0, 8.0, 12.0), "concrete_panels", ["-x"], "BldR1")
	_building(root, Vector3(10.0, 4.0, 36.0), Vector3(6.0, 8.0, 14.0), "concrete_wall_b", ["-x"], "BldR2")
	_building(root, Vector3(10.0, 4.0, 50.0), Vector3(6.0, 8.0, 10.0), "plaster_gray", ["-x"], "BldR3")

	# Chain-link fences closing the right-side gaps between buildings
	var fence_a := _prop(root, "fence_chain", Vector3(8.5, 1.63, 28.5), 0.0)
	if fence_a == null:
		_csg(root, Vector3(8.5, 1.25, 28.5), Vector3(0.15, 2.5, 2.0), SourceMaterials.mat("metal_rusty"))
	var fence_b := _prop(root, "fence_chain", Vector3(8.5, 1.63, 44.0), 0.0)
	if fence_b == null:
		_csg(root, Vector3(8.5, 1.25, 44.0), Vector3(0.15, 2.5, 2.0), SourceMaterials.mat("metal_rusty"))
	# Invisible-ish blockers so players can't slip through fence gaps
	var blocker_mat := StandardMaterial3D.new()
	blocker_mat.albedo_color = Color(0, 0, 0, 0)
	blocker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for bz in [28.5, 44.0]:
		var blk := _csg(root, Vector3(8.5, 1.5, bz), Vector3(0.2, 3.0, 2.2), blocker_mat)
		blk.name = "FenceBlocker"

	# Wrecked vehicles on the road
	_prop(root, "hatchback", Vector3(-2.2, 0.66, 23.0), 205.0)
	_prop(root, "van", Vector3(3.0, 0.94, 44.0), -28.0)
	var burned := _prop(root, "hatchback", Vector3(-1.2, 0.66, 51.5), 160.0)
	if burned != null:
		burned.rotation_degrees.z = 6.0
		_smoke_column(root, Vector3(-1.2, 1.15, 51.5))

	# Dumpsters on the sidewalks
	_prop(root, "dumpster", Vector3(-5.6, 0.13, 29.5), 4.0, 0.78)
	_prop(root, "dumpster", Vector3(5.4, 0.13, 41.5), 182.0, 0.78)

	# Street clutter
	_prop(root, "oildrum", Vector3(-4.6, 0.49, 18.5), 70.0)
	_prop(root, "oildrum", Vector3(4.3, 0.49, 33.0), -25.0)
	_prop(root, "spool", Vector3(6.2, 0.45, 19.0), 12.0)
	_prop(root, "propane", Vector3(-4.2, 0.57, 31.0), 0.0)
	_prop(root, "bicycle", Vector3(-6.6, 0.68, 20.5), 100.0)
	_prop(root, "rubble_slab", Vector3(5.8, 0.28, 47.5), 35.0)
	_prop(root, "rebar", Vector3(5.6, 0.5, 47.4), 60.0)
	_prop(root, "butane", Vector3(-5.2, 0.53, 39.5), 0.0)
	_prop(root, "powerbox", Vector3(-6.85, 1.2, 26.0), 90.0)
	_prop(root, "ladder", Vector3(6.8, 3.2, 51.0), -90.0, 0.8)

	# Mid-street barricade funnel (cover for the firefight)
	_concrete_barrier(root, Vector3(-2.0, 0.06, 33.5), 8.0)
	_prop(root, "barricade_tri", Vector3(1.4, 0.57, 34.2), 40.0)

	# Street lamps — one flickers
	_street_lamp(root, Vector3(-4.4, 0.12, 20.0), 90.0, false)
	_street_lamp(root, Vector3(4.4, 0.12, 30.0), -90.0, true)
	_street_lamp(root, Vector3(-4.4, 0.12, 42.0), 90.0, false)
	_street_lamp(root, Vector3(4.4, 0.12, 52.0), -90.0, false)


# ---------------------------------------------------------------------------
# SECTION 3: Side alley (x -13..-7, z 44..56)
# ---------------------------------------------------------------------------

func _build_side_alley() -> void:
	var root := Node3D.new()
	root.name = "SideAlley"
	add_child(root)

	# Gravel floor with dirt fringe
	_csg(root, Vector3(-10.0, 0.0, 50.0), Vector3(6.0, 0.1, 12.0),
		SourceMaterials.mat("gravel"), "AlleyFloor")

	# Back fence at the west end
	var fence := _prop(root, "fence_gate", Vector3(-12.4, 1.53, 50.0), 0.0)
	if fence == null:
		_csg(root, Vector3(-12.4, 1.5, 50.0), Vector3(0.2, 3.0, 6.0), SourceMaterials.mat("metal_rusty"))
	var blocker_mat := StandardMaterial3D.new()
	blocker_mat.albedo_color = Color(0, 0, 0, 0)
	blocker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_csg(root, Vector3(-12.4, 1.5, 50.0), Vector3(0.2, 3.0, 6.2), blocker_mat, "AlleyBlocker")

	# Dumpster + junk
	_prop(root, "dumpster", Vector3(-11.0, 0.06, 45.6), 95.0, 0.75)
	_prop(root, "oildrum", Vector3(-9.0, 0.43, 46.4), 130.0)
	_crate_stack(root, Vector3(-12.0, 0.06, 53.5), 2)
	_prop(root, "rubble_slab", Vector3(-9.5, 0.22, 52.0), 75.0)
	_prop(root, "ibeam", Vector3(-10.8, 0.38, 55.2), 25.0)
	_prop(root, "bush", Vector3(-12.6, 0.05, 47.0), 0.0)

	# Pipes running up the north building face (z=44 wall of BldL2)
	var pipe_mat := SourceMaterials.mat("metal_rusty")
	for px in [-8.4, -9.6, -11.2]:
		var pipe := CSGCylinder3D.new()
		pipe.radius = 0.07
		pipe.height = 7.6
		pipe.sides = 8
		pipe.position = Vector3(px, 3.8, 44.25)
		pipe.use_collision = false
		pipe.material = pipe_mat
		root.add_child(pipe)

	# Dead resistance fighter
	_corpse(root, Vector3(-10.4, 0.06, 54.4), 70.0)

	# Wall sconce with weak warm light
	_prop(root, "sconce", Vector3(-8.6, 3.1, 44.3), 180.0, 1.0)
	var lamp := _omni(root, Vector3(-8.8, 2.9, 45.2), Color(1.0, 0.78, 0.5), 1.1, 7.0)
	var cone := SourceMaterials.add_light_cone(root, Vector3(-8.8, 2.9, 45.2), 2.6, 1.2,
		Color(1.0, 0.8, 0.5), 0.04)
	_add_flicker(lamp, cone)


# ---------------------------------------------------------------------------
# SECTION 4: Plaza
# ---------------------------------------------------------------------------

func _build_plaza() -> void:
	var root := Node3D.new()
	root.name = "Plaza"
	add_child(root)

	# Cobblestone plaza floor
	_csg(root, Vector3(0.0, 0.0, 70.0), Vector3(20.0, 0.16, 20.0),
		SourceMaterials.mat("cobble"), "PlazaFloor")

	# Fountain
	var fmat := SourceMaterials.mat("concrete_old")
	var base := CSGCylinder3D.new()
	base.radius = 2.4
	base.height = 0.55
	base.sides = 16
	base.position = Vector3(0.0, 0.27, 70.0)
	base.use_collision = true
	base.material = fmat
	root.add_child(base)

	var rim := CSGCylinder3D.new()
	rim.radius = 2.15
	rim.height = 0.45
	rim.sides = 16
	rim.position = Vector3(0.0, 0.6, 70.0)
	rim.use_collision = true
	rim.material = SourceMaterials.mat("trim")
	root.add_child(rim)

	var pillar := CSGCylinder3D.new()
	pillar.radius = 0.32
	pillar.height = 1.6
	pillar.sides = 12
	pillar.position = Vector3(0.0, 1.2, 70.0)
	pillar.use_collision = true
	pillar.material = fmat
	root.add_child(pillar)

	# Murky standing water
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.0
	disc.bottom_radius = 2.0
	disc.height = 0.04
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.08, 0.12, 0.12, 0.86)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.roughness = 0.05
	wmat.metallic = 0.6
	disc.material = wmat
	water.mesh = disc
	water.position = Vector3(0.0, 0.72, 70.0)
	root.add_child(water)
	_looping_sound(root, Vector3(0.0, 0.9, 70.0),
		"res://sounds/ambient/ambience/waterlap_loop.wav", -10.0, 12.0)

	# The lost gnome watches over the plaza
	_prop(root, "gnome", Vector3(0.12, 2.0, 70.0), 200.0)

	# Perimeter buildings with facades
	_building(root, Vector3(-12.0, 4.5, 63.0), Vector3(5.0, 9.0, 6.0), "concrete_wall", ["+x"], "PlazaBldA")
	_building(root, Vector3(12.0, 4.5, 63.0), Vector3(5.0, 9.0, 6.0), "plaster_tan", ["-x"], "PlazaBldB")
	_building(root, Vector3(-12.0, 4.5, 77.0), Vector3(5.0, 9.0, 6.0), "plaster_worn", ["+x"], "PlazaBldC")
	_building(root, Vector3(12.0, 4.5, 77.0), Vector3(5.0, 9.0, 6.0), "brick_inn", ["-x"], "PlazaBldD")
	# North wings flanking the radio building entrance
	_building(root, Vector3(-7.5, 3.5, 82.5), Vector3(5.0, 7.0, 3.0), "plaster_gray", ["-z"], "PlazaWingL")
	_building(root, Vector3(7.5, 3.5, 82.5), Vector3(5.0, 7.0, 3.0), "plaster_gray", ["-z"], "PlazaWingR")

	# Side gaps fenced off
	for fz in [70.0]:
		var f_l := _prop(root, "fence_chain", Vector3(-12.0, 1.63, fz), 90.0)
		if f_l == null:
			_csg(root, Vector3(-12.0, 1.5, fz), Vector3(5.4, 3.0, 0.15), SourceMaterials.mat("metal_rusty"))
		var f_r := _prop(root, "fence_chain", Vector3(12.0, 1.63, fz), 90.0)
		if f_r == null:
			_csg(root, Vector3(12.0, 1.5, fz), Vector3(5.4, 3.0, 0.15), SourceMaterials.mat("metal_rusty"))
	var blocker_mat := StandardMaterial3D.new()
	blocker_mat.albedo_color = Color(0, 0, 0, 0)
	blocker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_csg(root, Vector3(-12.0, 1.5, 70.0), Vector3(5.6, 3.0, 0.2), blocker_mat)
	_csg(root, Vector3(12.0, 1.5, 70.0), Vector3(5.6, 3.0, 0.2), blocker_mat)

	# Combat cover — same tactical layout, real barriers
	var barrier_positions := [
		[Vector3(-5.0, 0.08, 65.0), 5.0],
		[Vector3(5.0, 0.08, 65.0), -8.0],
		[Vector3(-5.0, 0.08, 75.0), -4.0],
		[Vector3(5.0, 0.08, 75.0), 11.0],
		[Vector3(-7.0, 0.08, 70.0), 88.0],
		[Vector3(7.0, 0.08, 70.0), 92.0],
	]
	for bp in barrier_positions:
		_concrete_barrier(root, bp[0], bp[1])

	# Clutter
	_prop(root, "oildrum", Vector3(-8.8, 0.51, 64.0), 30.0)
	_prop(root, "spool", Vector3(8.6, 0.41, 76.4), -15.0)
	_prop(root, "barricade_x", Vector3(-3.0, 0.89, 60.5), 75.0)
	_prop(root, "rubble_slab", Vector3(3.4, 0.3, 78.6), 10.0)

	# Plaza lamps
	_street_lamp(root, Vector3(-8.0, 0.08, 63.0), 45.0, false)
	_street_lamp(root, Vector3(8.0, 0.08, 77.0), 225.0, true)


# ---------------------------------------------------------------------------
# SECTION 5: Interior — resistance radio shack
# ---------------------------------------------------------------------------

func _build_interior() -> void:
	var root := Node3D.new()
	root.name = "Interior"
	add_child(root)

	var bz := 88.0
	var wall := SourceMaterials.mat("brick_inn")
	var int_wall := SourceMaterials.mat("int_wall_b")

	# Shell
	_csg(root, Vector3(-5.0, 4.0, bz), Vector3(0.4, 8.0, 12.0), wall)       # left
	_csg(root, Vector3(5.0, 4.0, bz), Vector3(0.4, 8.0, 12.0), wall)        # right
	_csg(root, Vector3(0.0, 4.0, bz + 6.0), Vector3(10.4, 8.0, 0.4), wall)  # back
	# Front wall with doorway
	_csg(root, Vector3(-3.5, 4.0, bz - 6.0), Vector3(3.4, 8.0, 0.4), wall)
	_csg(root, Vector3(3.5, 4.0, bz - 6.0), Vector3(3.4, 8.0, 0.4), wall)
	_csg(root, Vector3(0.0, 7.0, bz - 6.0), Vector3(3.0, 2.0, 0.4), wall)

	# Open door at the entrance
	var door := _prop(root, "door", Vector3(-1.4, 0.06, bz - 6.0), -55.0)
	if door == null:
		_csg(root, Vector3(-1.2, 1.35, bz - 6.1), Vector3(0.1, 2.7, 1.1), SourceMaterials.mat("wood_door"))

	# Front windows (one lit from inside)
	_window_quad(root, Vector3(-3.5, 2.2, bz - 6.22), 180.0, Vector2(1.5, 1.5),
		SourceMaterials.window_pane_mat(false))
	_window_quad(root, Vector3(3.5, 2.2, bz - 6.22), 180.0, Vector2(1.5, 1.5),
		SourceMaterials.window_pane_mat(true))

	# Floor / ceiling / second floor slab
	_csg(root, Vector3(0.0, 0.05, bz), Vector3(10.0, 0.14, 12.0),
		SourceMaterials.mat("wood_floor"), "ShackFloor")
	_csg(root, Vector3(0.0, 8.25, bz), Vector3(10.4, 0.3, 12.4),
		SourceMaterials.mat("ceiling"), "ShackCeiling")
	_csg(root, Vector3(1.0, 4.2, bz + 2.0), Vector3(8.0, 0.24, 8.0),
		SourceMaterials.mat("concrete_old"), "SecondFloor")
	# Hazard edge strip on the slab lip
	_deco(root, Vector3(1.0, 4.2, bz - 2.1), Vector3(8.0, 0.26, 0.18), SourceMaterials.mat("hazard"))

	# Stairs: solid base with visible steps
	_csg(root, Vector3(-3.7, 2.0, bz + 1.0), Vector3(2.0, 4.0, 6.0),
		SourceMaterials.mat("concrete_old"), "StairBase")
	var step_mat := SourceMaterials.mat("concrete_pad")
	for i in range(8):
		_deco(root, Vector3(-3.7, 4.05 - i * 0.5, bz - 2.05 - i * 0.12),
			Vector3(2.0, 0.1, 0.5), step_mat)

	# --- Radio corner (the objective dressing) ---
	var desk := _csg(root, Vector3(2.4, 0.5, bz + 4.6), Vector3(2.4, 0.07, 0.9),
		SourceMaterials.mat("wood_board"), "RadioDesk")
	desk.rotation_degrees.y = 0.0
	var metal := SourceMaterials.mat("metal")
	for leg in [Vector3(1.3, 0.25, bz + 4.25), Vector3(3.5, 0.25, bz + 4.25),
			Vector3(1.3, 0.25, bz + 4.95), Vector3(3.5, 0.25, bz + 4.95)]:
		_deco(root, leg, Vector3(0.08, 0.5, 0.08), metal)
	_prop(root, "radio", Vector3(2.0, 0.55, bz + 4.7), 175.0)
	_prop(root, "receiver_b", Vector3(2.9, 0.62, bz + 4.6), 190.0)
	_prop(root, "receiver_d", Vector3(3.4, 0.58, bz + 4.7), 160.0)
	_prop(root, "monitor_sm", Vector3(1.3, 0.69, bz + 4.65), 185.0)
	_prop(root, "console", Vector3(2.4, 0.54, bz + 4.4), 180.0)
	_prop(root, "equipment", Vector3(4.5, 0.12, bz + 5.2), 180.0)
	_prop(root, "stool", Vector3(2.4, 0.12, bz + 3.6), 200.0)
	# Glow from the radio gear
	_omni(root, Vector3(2.4, 1.1, bz + 4.4), Color(0.5, 0.85, 0.5), 0.5, 2.5)

	# Furnishing
	_prop(root, "bunkbed", Vector3(-4.2, 0.12, bz + 4.6), 90.0)
	_prop(root, "shelf", Vector3(-4.55, 1.22, bz - 3.0), 90.0)
	_prop(root, "lockers", Vector3(4.55, 1.02, bz - 3.5), -90.0)
	_prop(root, "radiator", Vector3(-4.6, 0.58, bz + 0.5), 90.0)
	_prop(root, "cooler", Vector3(4.3, 0.12, bz - 1.0), -90.0)
	_prop(root, "frame", Vector3(-4.72, 2.2, bz - 1.8), 90.0)
	_prop(root, "clock", Vector3(0.0, 3.2, bz + 5.78), 90.0)
	_prop(root, "butane", Vector3(-3.6, 0.46, bz - 4.4), 0.0)

	# Crates on the second floor
	_crate_stack(root, Vector3(3.0, 4.38, bz + 3.0), 2)
	_prop(root, "oildrum", Vector3(-1.5, 4.75, bz + 4.8), 65.0)

	# Hanging industrial lights + dust
	for lp in [Vector3(0.0, 3.9, bz - 2.0), Vector3(2.0, 3.9, bz + 3.5)]:
		_prop(root, "bell_light", lp, 0.0, 1.0)
		var l := _omni(root, lp + Vector3(0, -0.45, 0), Color(1.0, 0.85, 0.55), 1.3, 7.0)
		if lp.x == 0.0:
			l.shadow_enabled = true
		SourceMaterials.add_light_cone(root, lp + Vector3(0, -0.5, 0), 2.6, 1.4,
			Color(1.0, 0.85, 0.55), 0.045)
	_omni(root, Vector3(0.0, 6.4, bz + 2.0), Color(1.0, 0.85, 0.6), 0.8, 7.0)

	# Light shaft through the lit front window + drifting motes
	var shaft := SpotLight3D.new()
	shaft.position = Vector3(3.5, 2.4, bz - 6.0)
	shaft.rotation_degrees = Vector3(-28.0, 195.0, 0.0)
	shaft.light_color = Color(0.75, 0.8, 0.95)
	shaft.light_energy = 1.4
	shaft.spot_range = 7.0
	shaft.spot_angle = 22.0
	root.add_child(shaft)
	SourceMaterials.add_dust_motes(root, Vector3(2.6, 1.8, bz - 4.0), Vector3(1.6, 1.4, 1.6), 14)
	SourceMaterials.add_dust_motes(root, Vector3(0.0, 2.2, bz + 2.0), Vector3(2.5, 1.8, 2.5), 10)


# ---------------------------------------------------------------------------
# SECTION 6: End area (Biden's safehouse)
# ---------------------------------------------------------------------------

func _build_end_area() -> void:
	var root := Node3D.new()
	root.name = "EndArea"
	add_child(root)

	var wall := SourceMaterials.mat("plaster_worn")
	var bz := 105.0

	# Shell
	_csg(root, Vector3(-5.5, 4.0, bz), Vector3(0.4, 8.0, 10.0), wall)
	_csg(root, Vector3(5.5, 4.0, bz), Vector3(0.4, 8.0, 10.0), wall)
	_csg(root, Vector3(0.0, 4.0, bz + 5.0), Vector3(11.4, 8.0, 0.4), wall)
	_csg(root, Vector3(-3.8, 4.0, bz - 5.0), Vector3(3.8, 8.0, 0.4), wall)
	_csg(root, Vector3(3.8, 4.0, bz - 5.0), Vector3(3.8, 8.0, 0.4), wall)
	_csg(root, Vector3(0.0, 6.8, bz - 5.0), Vector3(3.8, 2.4, 0.4), wall)

	# Trim + roof
	_deco(root, Vector3(0.0, 8.05, bz), Vector3(11.7, 0.36, 10.7), SourceMaterials.mat("trim"))
	_csg(root, Vector3(0.0, 8.35, bz), Vector3(11.4, 0.4, 10.4),
		SourceMaterials.mat("roof"), "SafehouseRoof")
	_prop(root, "chimney", Vector3(2.5, 8.55, bz + 2.0), 15.0)

	# Floor
	_csg(root, Vector3(0.0, 0.05, bz), Vector3(11.0, 0.14, 10.0),
		SourceMaterials.mat("wood_floor"))

	# Boarded windows
	var board := SourceMaterials.mat("wood_board")
	var board_positions := [
		Vector3(-5.62, 3.2, bz - 1.2), Vector3(-5.62, 3.2, bz + 1.6),
		Vector3(5.62, 3.2, bz - 1.2), Vector3(5.62, 3.2, bz + 1.6),
	]
	for bp in board_positions:
		_deco(root, bp, Vector3(0.14, 1.5, 1.1), SourceMaterials.glass_mat())
		for i in range(3):
			var plank := _deco(root, bp + Vector3(0.05 * signf(bp.x), -0.45 + i * 0.45, 0.0),
				Vector3(0.08, 0.28, 1.3), board)
			plank.rotation_degrees.x = randf_range(-9.0, 9.0)

	# Door ajar
	var door := _prop(root, "door", Vector3(-1.5, 0.06, bz - 5.0), -35.0)
	if door == null:
		_csg(root, Vector3(-1.3, 1.35, bz - 5.1), Vector3(0.1, 2.7, 1.1), SourceMaterials.mat("wood_door"))

	# Defensive dressing outside
	_concrete_barrier(root, Vector3(-3.0, 0.05, bz - 7.5), 4.0)
	_concrete_barrier(root, Vector3(3.0, 0.05, bz - 7.5), -7.0)
	_sandbag_row(root, Vector3(-1.6, 0.05, bz - 8.6), 5, "x")
	_prop(root, "barricade_tri", Vector3(-4.6, 0.56, bz - 6.4), 30.0)
	_prop(root, "oildrum", Vector3(4.8, 0.48, bz - 6.2), 110.0)

	# Porch light over the door
	_prop(root, "sconce", Vector3(0.0, 3.4, bz - 5.25), 0.0, 1.0)
	var porch := _omni(root, Vector3(0.0, 3.2, bz - 5.8), Color(1.0, 0.8, 0.5), 1.4, 8.0)
	var cone := SourceMaterials.add_light_cone(root, Vector3(0.0, 3.1, bz - 5.7), 2.8, 1.3,
		Color(1.0, 0.8, 0.5), 0.05)
	_add_flicker(porch, cone)

	# Interior: someone left in a hurry
	_prop(root, "hospital_bed", Vector3(3.4, 0.48, bz + 3.4), 12.0)
	_prop(root, "footlocker", Vector3(1.6, 0.44, bz + 3.8), 80.0)
	_prop(root, "radio", Vector3(-3.8, 0.95, bz + 4.2), 145.0)
	var crate := _prop(root, "beacon_crate", Vector3(-3.8, 0.48, bz + 4.2), 10.0)
	if crate == null:
		_csg(root, Vector3(-3.8, 0.5, bz + 4.2), Vector3(0.8, 0.8, 0.8), board)
	_prop(root, "stool", Vector3(-2.6, 0.12, bz + 3.2), -140.0)
	_prop(root, "shelf", Vector3(5.1, 1.0, bz + 1.0), -90.0)
	_prop(root, "gnome", Vector3(4.0, 0.12, bz - 3.6), 230.0)
	_omni(root, Vector3(0.0, 3.4, bz + 1.0), Color(1.0, 0.86, 0.6), 1.2, 9.0)
	_prop(root, "bell_light", Vector3(0.0, 3.85, bz + 1.0), 0.0, 1.0)

	# Path dressing between interior and safehouse (z 94..100)
	_prop(root, "fence_chain", Vector3(-7.0, 1.63, 97.0), 25.0)
	_prop(root, "fence_chain", Vector3(7.0, 1.63, 97.0), -20.0)
	_prop(root, "oildrum", Vector3(-4.4, 0.46, 96.5), 200.0)
	_prop(root, "bush", Vector3(5.2, 0.04, 95.5), 0.0)
	_prop(root, "bush", Vector3(-5.6, 0.04, 99.0), 120.0)
	_street_lamp(root, Vector3(4.5, 0.04, 98.5), -135.0, false)

	# Level complete trigger (unchanged)
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
# Skyline silhouettes around the playable space
# ---------------------------------------------------------------------------

func _build_skyline() -> void:
	var root := Node3D.new()
	root.name = "Skyline"
	add_child(root)

	var sil := StandardMaterial3D.new()
	sil.albedo_color = Color(0.13, 0.14, 0.165)
	sil.roughness = 1.0

	var lit := SourceMaterials.lit_window_mat()

	var blocks := [
		# x, z, w, h, d
		[-26.0, 6.0, 9.0, 17.0, 10.0], [-30.0, 26.0, 10.0, 22.0, 12.0],
		[-27.0, 48.0, 8.0, 14.0, 10.0], [-30.0, 70.0, 11.0, 25.0, 12.0],
		[-26.0, 95.0, 9.0, 16.0, 11.0], [-24.0, 115.0, 10.0, 20.0, 12.0],
		[26.0, 4.0, 10.0, 19.0, 11.0], [29.0, 26.0, 9.0, 15.0, 10.0],
		[27.0, 47.0, 11.0, 24.0, 13.0], [30.0, 70.0, 9.0, 14.0, 10.0],
		[26.0, 93.0, 10.0, 21.0, 11.0], [25.0, 114.0, 9.0, 15.0, 10.0],
		[-12.0, -34.0, 14.0, 18.0, 9.0], [9.0, -38.0, 16.0, 23.0, 10.0], [-1.0, -45.0, 12.0, 27.0, 10.0],
		[-2.0, 126.0, 13.0, 22.0, 10.0], [12.0, 124.0, 10.0, 16.0, 9.0],
		[-14.0, 124.0, 9.0, 13.0, 9.0],
	]
	var idx := 0
	for b in blocks:
		var h: float = b[3]
		_deco(root, Vector3(b[0], h * 0.5 - 0.2, b[1]), Vector3(b[2], h, b[4]), sil)
		# Sparse lit windows on the inward face
		idx += 1
		if idx % 2 == 0:
			var face_x: float = b[0] + (b[2] * 0.5 + 0.05) * (1.0 if b[0] < 0.0 else -1.0)
			for wy in [h * 0.35, h * 0.6]:
				_deco(root, Vector3(face_x, wy, b[1] + randf_range(-b[4] * 0.25, b[4] * 0.25)),
					Vector3(0.1, 0.8, 0.6), lit)

	# Distant radio mast — classic EP2 silhouette
	_prop(root, "antenna", Vector3(-34.0, -0.2, 92.0), 20.0, 0.8)


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
	AudioManager.play_sfx(radio_path, -8.0)

	await get_tree().create_timer(3.0).timeout
	GameManager.complete_level()


# ---------------------------------------------------------------------------
# NPC spawning (positions unchanged)
# ---------------------------------------------------------------------------

func _spawn_npcs() -> void:
	if ResourceLoader.exists(HECU_SOLDIER_SCENE):
		var hecu_scene := ResourceLoader.load(HECU_SOLDIER_SCENE) as PackedScene
		if hecu_scene != null:
			var hecu := hecu_scene.instantiate()
			hecu.position = Vector3(3.0, 0.5, 2.0)
			add_child(hecu)

	if ResourceLoader.exists(RESISTANCE_SOLDIER_SCENE):
		var rs_scene := ResourceLoader.load(RESISTANCE_SOLDIER_SCENE) as PackedScene
		if rs_scene != null:
			var street_positions := [
				Vector3(4.0, 0.5, 25.0),
				Vector3(5.0, 0.5, 40.0),
				Vector3(-5.5, 0.5, 35.0),
			]
			for pos in street_positions:
				var rs := rs_scene.instantiate()
				rs.position = pos
				add_child(rs)

			var alley_positions := [
				Vector3(-8.0, 0.5, 48.0),
				Vector3(-8.0, 0.5, 55.0),
			]
			for pos in alley_positions:
				var rs := rs_scene.instantiate()
				rs.position = pos
				add_child(rs)

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
# Pickups (positions unchanged)
# ---------------------------------------------------------------------------

func _spawn_pickups() -> void:
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
			wp2.position = Vector3(-4.0, 0.95, -2.0)
			if "weapon_type" in wp2:
				wp2.weapon_type = "pistol"
				wp2.ammo_count = 20
			add_child(wp2)

	if ResourceLoader.exists(HEALTH_PICKUP_SCENE):
		var hp_scene := ResourceLoader.load(HEALTH_PICKUP_SCENE) as PackedScene
		if hp_scene != null:
			var hp_positions := [
				Vector3(-11.0, 0.4, 46.0),
				Vector3(-11.0, 0.4, 53.0),
			]
			for pos in hp_positions:
				var hp := hp_scene.instantiate()
				hp.position = pos
				add_child(hp)


# ---------------------------------------------------------------------------
# Ambient sound zones along the route
# ---------------------------------------------------------------------------

func _add_ambient_zones() -> void:
	# Staging: low base rumble
	_ambient_zone(Vector3(0, 2, 0), Vector3(24, 8, 18),
		"res://sounds/ambient/levels/caves/rumble1.wav", -14.0)
	# Street: light wind
	_ambient_zone(Vector3(0, 3, 34), Vector3(16, 10, 52),
		"res://sounds/ambient/ambience/wind_light02_loop.wav", -10.0)
	# Alley: eerie howl
	_ambient_zone(Vector3(-10, 2.5, 50), Vector3(7, 7, 13),
		"res://sounds/ambient/levels/caves/cave_howl_loop1.wav", -18.0)
	# Plaza: open wind
	_ambient_zone(Vector3(0, 3, 70), Vector3(21, 10, 20),
		"res://sounds/ambient/ambience/wind_light02_loop.wav", -12.0)
	# Interior: close room tone
	_ambient_zone(Vector3(0, 2.5, 88), Vector3(10, 7, 12),
		"res://sounds/ambient/levels/caves/cave_heen_loop1.wav", -20.0)
	# End approach: rumble again
	_ambient_zone(Vector3(0, 2.5, 103), Vector3(14, 8, 16),
		"res://sounds/ambient/levels/caves/rumble2.wav", -16.0)
