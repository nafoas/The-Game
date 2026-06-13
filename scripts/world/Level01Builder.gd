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
	# truck001a's materials don't ship in EP1/EP2 — the EP2 muscle car does.
	"truck": "res://models/vehicle/vehicle_rich.mdl",
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
	# --- world-building pass: verified-safe additions (VMT+VTF or alias) ---
	"car_cluster2": "res://models/props_vehicles/car001b_cluster02.mdl",
	"car_cluster3": "res://models/props_vehicles/car001b_cluster03.mdl",
	"refrigerator": "res://models/props_forest/refrigerator01.mdl",
	"sawhorse": "res://models/props_forest/sawhorse.mdl",
	"ladder_wood": "res://models/props_forest/ladderwood.mdl",
	"elecbox": "res://models/props_silo/electricalbox01.mdl",
	"fuel_cask": "res://models/props_silo/fuel_cask.mdl",
	"duct": "res://models/props_silo/duct.mdl",
	"barrel_warn": "res://models/props_silo/barrelwarning.mdl",
	"acunit2": "res://models/props_silo/acunit02.mdl",
	"mining_barrier": "res://models/props_mining/barrier_cluster.mdl",
	"wall_ruin9": "res://models/props_debris/walldestroyed09a.mdl",
	"chunk_a": "res://models/props_debris/concrete_spawnchunk001a.mdl",
	"chunk_b": "res://models/props_debris/concrete_spawnchunk001b.mdl",
	"chunk_c": "res://models/props_debris/concrete_spawnchunk001c.mdl",
	"rebar_big": "res://models/props_debris/rebar003a_32.mdl",
	"fence_ext": "res://models/props_wasteland/exterior_fence_notbarbed002c.mdl",
	"detail_grass": "res://models/props_foliage/detail_cluster01.mdl",
	"hospital_cart": "res://models/props_c17/hospital_cart01.mdl",
	"gate_door": "res://models/props_c17/gate_door03.mdl",
	"truss": "res://models/props_c17/truss02a.mdl",
	"wall_shelf": "res://models/props_c17/furnitureshelf002a.mdl",
	"powerbox_dmg": "res://models/props_c17/powerbox_damaged.mdl",
	"ladder_dmg": "res://models/props_c17/metalladder002c_damaged.mdl",
}

var _level_complete_triggered: bool = false
var _lit_window_count: int = 0
var _spawned_npcs: Array = []


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
	_build_map_edges()
	_build_skyline()
	_spawn_npcs()
	_spawn_pickups()
	_add_ambient_zones()

	# Land every NPC exactly on whatever surface is below it (road, sidewalk,
	# upstairs slab) once physics is live — fixes spawn-in-ground/floating NPCs.
	get_tree().physics_frame.connect(_snap_npcs_to_ground, CONNECT_ONE_SHOT)


func _snap_npcs_to_ground() -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	for npc in _spawned_npcs:
		if not is_instance_valid(npc):
			continue
		var from: Vector3 = npc.global_position + Vector3(0.0, 1.5, 0.0)
		var params := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -10.0, 0.0), 1)
		params.exclude = [npc.get_rid()]
		var hit := space.intersect_ray(params)
		if hit.size() > 0:
			npc.global_position.y = hit["position"].y + 0.05


# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

func _build_world_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()

	# Overcast dusk — real HL2 six-face skybox when the VTF faces load,
	# otherwise a tinted procedural sky (never a flat color void).
	var sky_mat := _make_skybox_material()
	if sky_mat != null:
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.sky = sky
		env.background_energy_multiplier = 1.0
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.31, 0.34, 0.39)

	env.fog_enabled = true
	env.fog_light_color = Color(0.34, 0.37, 0.42)
	env.fog_light_energy = 1.0
	env.fog_density = 0.016
	env.fog_sky_affect = 0.15

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
	env.ambient_light_energy = 0.5

	world_env.environment = env
	add_child(world_env)

	var dir_light := DirectionalLight3D.new()
	dir_light.name = "SunLight"
	dir_light.light_color = Color(0.74, 0.77, 0.86)
	dir_light.light_energy = 0.65
	dir_light.shadow_enabled = true
	dir_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	dir_light.shadow_blur = 2.0
	dir_light.directional_shadow_max_distance = 70.0
	dir_light.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	add_child(dir_light)


## Builds a ShaderMaterial sampling the six HL2 sky_ep01_01 VTF faces as a
## cubemap. Falls back to a tinted ProceduralSkyMaterial if any face (or the
## sky shader) fails to load, so the level never shows a flat void.
func _make_skybox_material() -> Material:
	const SKY_SET := "res://materials/skybox/sky_ep01_01"
	const FACES := ["ft", "bk", "lf", "rt", "up", "dn"]

	var shader := load("res://materials/source_sky.gdshader") as Shader
	var textures := {}
	var complete := true
	for face in FACES:
		var path: String = "%s%s.vtf" % [SKY_SET, face]
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
		if tex == null:
			complete = false
			break
		textures[face] = tex

	if shader != null and complete:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		for face in FACES:
			mat.set_shader_parameter("face_%s" % face, textures[face])
		# Slight cool grey grade so the sky sits with the overcast dusk fog.
		mat.set_shader_parameter("tint", Color(0.92, 0.96, 1.05))
		mat.set_shader_parameter("energy", 1.0)
		return mat

	# Fallback: hazy greyish-blue procedural sky matching the level mood.
	var proc := ProceduralSkyMaterial.new()
	proc.sky_top_color = Color(0.31, 0.34, 0.39)
	proc.sky_horizon_color = Color(0.42, 0.45, 0.5)
	proc.ground_bottom_color = Color(0.12, 0.13, 0.15)
	proc.ground_horizon_color = Color(0.36, 0.38, 0.42)
	proc.sun_angle_max = 30.0
	proc.sun_curve = 0.15
	return proc


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
	# Quadratic-style falloff — lower values leave a hard-edged bright disc.
	lamp.omni_attenuation = 2.0
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

	# Rooftop clutter for taller buildings: parapet ring + utility props
	if size.y >= 7.0:
		_parapet(parent, pos, size)
		var roll := randf()
		if roll < 0.4:
			_prop(parent, "acunit", Vector3(pos.x, top_y + 1.62, pos.z + size.z * 0.15), randf_range(0, 360))
		elif roll < 0.7:
			_prop(parent, "chimney", Vector3(pos.x, top_y, pos.z - size.z * 0.2), randf_range(0, 360))
		else:
			# Rooftop water tank (HL2 skyline staple)
			_prop(parent, "fuel_cask", Vector3(pos.x, top_y, pos.z), randf_range(0, 360), 0.7)
		# Small AC unit on the parapet edge + duct piping
		if randf() < 0.7:
			_prop(parent, "acunit2", Vector3(pos.x + size.x * 0.25, top_y + 0.58, pos.z - size.z * 0.25),
				randf_range(0, 360))

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

	var lamp := _omni(parent, head_pos + Vector3(0, -0.35, 0), Color(1.0, 0.9, 0.7), 0.9, 9.0)
	if flicker:
		_add_flicker(lamp)


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


## Loose concrete chunks + rebar scattered on the ground (HL2 streets are
## never clean). Chunk models sit flush at y~0; pos.y should be the floor top.
func _rubble_pile(parent: Node, pos: Vector3, big: bool = false) -> void:
	var keys := ["chunk_a", "chunk_b", "chunk_c"]
	var n := 4 if big else 3
	for i in range(n):
		var key: String = keys[i % keys.size()]
		var off := Vector3(randf_range(-0.7, 0.7), 0.12, randf_range(-0.7, 0.7))
		_prop(parent, key, pos + off, randf_range(0, 360))
	if big:
		_prop(parent, "rubble_slab", pos + Vector3(0, 0.1, 0), randf_range(0, 360))
		_prop(parent, "rebar", pos + Vector3(0.4, 0.41, -0.3), randf_range(0, 360))


static var _paper_mat: StandardMaterial3D = null

static func _get_paper_mat() -> StandardMaterial3D:
	if _paper_mat == null:
		_paper_mat = StandardMaterial3D.new()
		_paper_mat.albedo_color = Color(0.72, 0.7, 0.63)
		_paper_mat.roughness = 1.0
		_paper_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _paper_mat


## Scattered papers/newspapers lying flat on the floor.
func _paper_scatter(parent: Node, center: Vector3, count: int, radius: float = 1.2) -> void:
	var pmat := _get_paper_mat()
	for i in range(count):
		var mi := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = Vector2(randf_range(0.2, 0.3), randf_range(0.26, 0.36))
		mi.mesh = quad
		mi.material_override = pmat
		mi.position = center + Vector3(randf_range(-radius, radius), 0.012,
			randf_range(-radius, radius))
		mi.rotation_degrees = Vector3(0.0, randf_range(0, 360), 0.0)
		parent.add_child(mi)


## Rooftop parapet ledge ring (HL2 buildings never end in a knife edge).
func _parapet(parent: Node, bpos: Vector3, bsize: Vector3) -> void:
	var mat := SourceMaterials.mat("trim")
	var top := bpos.y + bsize.y * 0.5
	var hw := bsize.x * 0.5
	var hd := bsize.z * 0.5
	_deco(parent, Vector3(bpos.x, top + 0.25, bpos.z - hd), Vector3(bsize.x + 0.3, 0.5, 0.3), mat)
	_deco(parent, Vector3(bpos.x, top + 0.25, bpos.z + hd), Vector3(bsize.x + 0.3, 0.5, 0.3), mat)
	_deco(parent, Vector3(bpos.x - hw, top + 0.25, bpos.z), Vector3(0.3, 0.5, bsize.z + 0.3), mat)
	_deco(parent, Vector3(bpos.x + hw, top + 0.25, bpos.z), Vector3(0.3, 0.5, bsize.z + 0.3), mat)


## Sagging power/phone line between two points (thin dark cylinder).
static var _wire_mat: StandardMaterial3D = null

func _wire(parent: Node, a: Vector3, b: Vector3) -> void:
	if _wire_mat == null:
		_wire_mat = StandardMaterial3D.new()
		_wire_mat.albedo_color = Color(0.06, 0.06, 0.07)
		_wire_mat.roughness = 0.9
	var mid := (a + b) * 0.5 + Vector3(0, -0.35, 0)  # slight sag at the middle
	for seg in [[a, mid], [mid, b]]:
		var p0: Vector3 = seg[0]
		var p1: Vector3 = seg[1]
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.015
		cyl.bottom_radius = 0.015
		cyl.height = p0.distance_to(p1)
		cyl.radial_segments = 5
		mi.mesh = cyl
		mi.material_override = _wire_mat
		mi.position = (p0 + p1) * 0.5
		var dir := (p1 - p0).normalized()
		var axis := Vector3.UP.cross(dir)
		if axis.length() > 0.001:
			mi.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
		parent.add_child(mi)


## Wall-mounted fire escape: two grated platforms + damaged ladder + railings.
## wall_x is the building face plane; side is +1 if the platform extends +x.
func _fire_escape(parent: Node, wall_x: float, z: float, side: float) -> void:
	var metal := SourceMaterials.mat("metal_rusty")
	for fl in range(2):
		var py := 3.1 + fl * 3.0
		_deco(parent, Vector3(wall_x + side * 0.7, py, z),
			Vector3(1.4, 0.08, 3.0), metal)
		# railing
		_deco(parent, Vector3(wall_x + side * 1.35, py + 0.5, z), Vector3(0.06, 1.0, 3.0), metal)
		_deco(parent, Vector3(wall_x + side * 0.7, py + 0.5, z - 1.5), Vector3(1.4, 1.0, 0.06), metal)
		_deco(parent, Vector3(wall_x + side * 0.7, py + 0.5, z + 1.5), Vector3(1.4, 1.0, 0.06), metal)
	# Ladder dropping from the lower platform (damaged C17 ladder, base origin)
	_prop(parent, "ladder_dmg", Vector3(wall_x + side * 0.55, 0.05, z + 1.2), 0.0 if side > 0 else 180.0, 0.6)


## Simple HL2-style wooden bench: concrete supports + slats.
func _bench(parent: Node, pos: Vector3, rot_y: float = 0.0) -> void:
	var bench := Node3D.new()
	parent.add_child(bench)
	bench.position = pos
	bench.rotation_degrees.y = rot_y
	var wood := SourceMaterials.mat("wood_board")
	var conc := SourceMaterials.mat("concrete_old")
	for sx in [-0.7, 0.7]:
		_csg(bench, Vector3(sx, 0.21, 0.0), Vector3(0.12, 0.42, 0.5), conc)
	for i in range(3):
		_deco(bench, Vector3(0.0, 0.46, -0.18 + i * 0.18), Vector3(1.8, 0.05, 0.14), wood)
	for i in range(2):
		_deco(bench, Vector3(0.0, 0.75 + i * 0.2, 0.28), Vector3(1.8, 0.12, 0.05), wood)


## Dead-plant concrete planter (plaza dressing).
func _planter(parent: Node, pos: Vector3, dead: bool = true) -> void:
	var conc := SourceMaterials.mat("concrete_old")
	_csg(parent, pos + Vector3(0, 0.3, 0), Vector3(1.5, 0.6, 1.5), conc)
	_deco(parent, pos + Vector3(0, 0.56, 0), Vector3(1.26, 0.1, 1.26), SourceMaterials.mat("dirt"))
	if dead:
		_prop(parent, "detail_grass", pos + Vector3(0.1, 0.6, 0.0), randf_range(0, 360))
	else:
		_prop(parent, "bush", pos + Vector3(0, 0.6, 0), randf_range(0, 360))


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
	# Soft additive flame sprites + dark smoke (no hard-edged quads).
	SourceMaterials.add_fire(parent, pos, 1.0)

	# Flickering fire glow
	var ember := _omni(parent, pos + Vector3(0, 0.4, 0), Color(1.0, 0.5, 0.15), 0.8, 4.5)
	_add_flicker(ember)


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
	var tent_light := _omni(root, Vector3(0.0, 2.9, 2.0), Color(1.0, 0.9, 0.65), 1.0, 7.0)
	tent_light.shadow_enabled = true

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
	# generator_b instead of "equipment": equipment1's real texture is a
	# near-white silo cabinet and reads as an untextured block outdoors.
	_prop(root, "generator_b", Vector3(-2.6, 0.07, 4.2), 180.0)
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
	# Screen faces the spawn walkway; the casing's rear UVs land on a white
	# patch of the stand-in monitor texture and read as an untextured box.
	_prop(root, "monitor", Vector3(1.2, 0.55, 1.3), -20.0)
	_prop(root, "receiver_b", Vector3(2.0, 0.63, 1.5), 200.0)
	_prop(root, "stool", Vector3(0.6, 0.07, 0.4), 30.0)

	# Military truck parked at the pad edge (model base is at its origin —
	# it was floating 1.5m in the air before)
	_prop(root, "truck", Vector3(-7.0, 0.02, -10.5), 80.0)

	# Entry control point onto the street
	_concrete_barrier(root, Vector3(-3.2, 0.06, 8.6), 14.0)
	_concrete_barrier(root, Vector3(3.2, 0.06, 9.4), -10.0)
	_prop(root, "barricade_x", Vector3(0.2, 0.86, 10.6), 18.0)

	# Floodlight pole watching the exit
	_street_lamp(root, Vector3(-8.8, 0.06, 7.4), 140.0, false)

	# FOB clutter: spare drums, warning barrel, paperwork blown off the table
	_prop(root, "barrel_warn", Vector3(8.2, 0.07, 0.5), 0.0)
	_prop(root, "fuel_cask", Vector3(9.0, 0.07, -5.8), 0.0, 0.55)
	_paper_scatter(root, Vector3(0.8, 0.07, 0.2), 5, 1.4)
	_prop(root, "sawhorse", Vector3(-6.8, 0.07, 0.8), 25.0)
	_rubble_pile(root, Vector3(8.6, 0.07, 5.4))


# ---------------------------------------------------------------------------
# SECTION 2: Street A
# ---------------------------------------------------------------------------

func _build_street_a() -> void:
	var root := Node3D.new()
	root.name = "StreetA"
	add_child(root)

	# Left side: two buildings then the alley gap (alley z 44..56), then corner
	# block. 12m+ tall so the street reads as a real C17 canyon (no sky gaps).
	_building(root, Vector3(-10.0, 6.0, 22.5), Vector3(6.0, 12.0, 15.0), "brick_inn", ["+x"], "BldL1")
	_building(root, Vector3(-10.0, 6.0, 37.0), Vector3(6.0, 12.0, 14.0), "plaster_tan", ["+x"], "BldL2")
	_building(root, Vector3(-10.0, 6.0, 58.0), Vector3(6.0, 12.0, 4.0), "plaster_gray", ["+x"], "BldL3")
	# Tall block forming the alley's west wall
	_building(root, Vector3(-15.0, 7.0, 49.0), Vector3(4.0, 14.0, 20.0), "indust_wall", [], "BldLW")

	# Right side
	_building(root, Vector3(10.0, 6.0, 22.0), Vector3(6.0, 12.0, 12.0), "concrete_panels", ["-x"], "BldR1")
	_building(root, Vector3(10.0, 6.0, 36.0), Vector3(6.0, 12.0, 14.0), "concrete_wall_b", ["-x"], "BldR2")
	_building(root, Vector3(10.0, 6.0, 50.0), Vector3(6.0, 12.0, 10.0), "plaster_gray", ["-x"], "BldR3")

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

	# Wrecked vehicles on the road (model bases measured — sit ON the asphalt)
	_prop(root, "hatchback", Vector3(-2.2, 0.65, 23.0), 205.0)
	_prop(root, "hatchback", Vector3(3.1, 0.65, 14.5), 24.0)
	_prop(root, "van", Vector3(3.0, 0.93, 44.0), -28.0)
	var burned := _prop(root, "hatchback", Vector3(-1.2, 0.65, 51.5), 160.0)
	if burned != null:
		burned.rotation_degrees.z = 6.0
		_smoke_column(root, Vector3(-1.2, 1.15, 51.5))

	# Dumpsters on the sidewalks
	_prop(root, "dumpster", Vector3(-5.6, 0.13, 29.5), 4.0, 0.78)
	_prop(root, "dumpster", Vector3(5.4, 0.13, 41.5), 182.0, 0.78)

	# Street clutter (heights from measured model AABBs — nothing floats)
	_prop(root, "oildrum", Vector3(-4.6, 0.49, 18.5), 70.0)
	_prop(root, "oildrum", Vector3(4.3, 0.49, 33.0), -25.0)
	_prop(root, "oildrum", Vector3(5.0, 0.49, 24.5), 140.0)
	_prop(root, "spool", Vector3(6.2, 0.45, 19.0), 12.0)
	_prop(root, "propane", Vector3(-4.2, 0.57, 31.0), 0.0)
	_prop(root, "bicycle", Vector3(-6.6, 0.66, 20.5), 100.0)
	_prop(root, "rubble_slab", Vector3(5.8, 0.22, 47.5), 35.0)
	_prop(root, "rebar", Vector3(5.6, 0.53, 47.4), 60.0)
	_prop(root, "butane", Vector3(-5.2, 0.12, 39.5), 0.0)
	_prop(root, "powerbox", Vector3(-6.85, 0.12, 26.0), 90.0)
	# Abandoned fridge + warning barrel + sawhorse — C17 sidewalk junk
	_prop(root, "refrigerator", Vector3(-6.3, 0.12, 33.8), 110.0)
	_prop(root, "barrel_warn", Vector3(4.7, 0.12, 37.5), 0.0)
	_prop(root, "sawhorse", Vector3(-4.8, 0.12, 25.8), 75.0)
	_prop(root, "hospital_cart", Vector3(5.9, 0.55, 27.5), -35.0)
	# Substation box bank against the right building face
	_prop(root, "elecbox", Vector3(6.92, 0.12, 36.0), 180.0, 0.9)
	_prop(root, "powerbox_dmg", Vector3(6.85, 0.12, 31.5), -90.0)
	_prop(root, "duct", Vector3(-6.9, 3.2, 35.0), 90.0)

	# Rubble piles every few meters along the curbs — streets are never clean
	_rubble_pile(root, Vector3(-5.3, 0.12, 15.5))
	_rubble_pile(root, Vector3(4.9, 0.12, 21.0))
	_rubble_pile(root, Vector3(-4.7, 0.12, 27.8), true)
	_rubble_pile(root, Vector3(5.6, 0.12, 34.5))
	_rubble_pile(root, Vector3(-5.8, 0.12, 44.5))
	_rubble_pile(root, Vector3(4.6, 0.12, 49.8), true)
	_paper_scatter(root, Vector3(-4.5, 0.12, 22.0), 5)
	_paper_scatter(root, Vector3(4.8, 0.12, 39.0), 6)
	_paper_scatter(root, Vector3(0.5, 0.06, 30.0), 4)

	# Fire escapes on the facing walls (classic C17 streetscape)
	_fire_escape(root, -6.95, 24.0, 1.0)
	_fire_escape(root, 6.95, 39.5, -1.0)
	# Wall ladder snugged against the corner block (centered origin, 13m tall)
	_prop(root, "ladder", Vector3(6.8, 5.2, 51.0), -90.0, 0.8)

	# Power lines sagging across the street between rooflines
	_wire(root, Vector3(-7.0, 11.6, 21.0), Vector3(7.0, 11.3, 23.5))
	_wire(root, Vector3(-7.0, 11.4, 36.0), Vector3(7.0, 11.6, 34.0))
	_wire(root, Vector3(-7.0, 11.5, 42.5), Vector3(7.0, 11.2, 47.0))

	# Mid-street barricade funnel (cover for the firefight)
	_concrete_barrier(root, Vector3(-2.0, 0.06, 33.5), 8.0)
	_prop(root, "barricade_tri", Vector3(1.4, 0.57, 34.2), 40.0)
	_prop(root, "barricade_x", Vector3(-0.4, 0.87, 16.8), -15.0)

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

	# Dumpster + junk — alleys in C17 are PACKED
	_prop(root, "dumpster", Vector3(-11.0, 0.06, 45.6), 95.0, 0.75)
	_prop(root, "oildrum", Vector3(-9.0, 0.42, 46.4), 130.0)
	_prop(root, "oildrum", Vector3(-11.6, 0.42, 51.2), 60.0)
	_crate_stack(root, Vector3(-12.0, 0.06, 53.5), 2)
	_crate_stack(root, Vector3(-8.3, 0.06, 52.6), 2)
	_prop(root, "rubble_slab", Vector3(-9.5, 0.15, 52.0), 75.0)
	_prop(root, "ibeam", Vector3(-10.8, 0.25, 55.2), 25.0)
	_prop(root, "bush", Vector3(-12.6, 0.05, 47.0), 0.0)
	# Stacked pallets/boxes against the west wall + leaning ladder
	_prop(root, "spool", Vector3(-12.2, 0.38, 48.8), 40.0)
	_prop(root, "propane", Vector3(-8.6, 0.5, 49.6), 0.0)
	_prop(root, "sawhorse", Vector3(-9.8, 0.05, 47.9), 105.0)
	_prop(root, "barrel_warn", Vector3(-12.3, 0.05, 55.6), 0.0)
	var lean_ladder := _prop(root, "ladder_wood", Vector3(-11.85, 1.85, 49.9), 90.0)
	if lean_ladder != null:
		lean_ladder.rotation_degrees.x = -12.0
	_prop(root, "refrigerator", Vector3(-8.4, 0.05, 45.2), -100.0)
	_rubble_pile(root, Vector3(-10.6, 0.05, 47.2))
	_rubble_pile(root, Vector3(-9.2, 0.05, 54.0), true)
	_paper_scatter(root, Vector3(-10.0, 0.05, 50.5), 7, 1.6)
	# Broken chain-link section partway across the alley (squeeze-through gap
	# on the west side)
	_prop(root, "fence_ext", Vector3(-9.0, 1.95, 51.5), 90.0)

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
	var lamp := _omni(root, Vector3(-8.8, 2.9, 45.2), Color(1.0, 0.78, 0.5), 0.8, 6.0)
	_add_flicker(lamp)


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

	# Perimeter buildings with facades (12m+ street-canyon heights)
	_building(root, Vector3(-12.0, 6.5, 63.0), Vector3(5.0, 13.0, 6.0), "concrete_wall", ["+x"], "PlazaBldA")
	_building(root, Vector3(12.0, 6.5, 63.0), Vector3(5.0, 13.0, 6.0), "plaster_tan", ["-x"], "PlazaBldB")
	_building(root, Vector3(-12.0, 6.5, 77.0), Vector3(5.0, 13.0, 6.0), "plaster_worn", ["+x"], "PlazaBldC")
	_building(root, Vector3(12.0, 6.5, 77.0), Vector3(5.0, 13.0, 6.0), "brick_inn", ["-x"], "PlazaBldD")
	# North wings flanking the radio building entrance
	_building(root, Vector3(-7.5, 5.0, 82.5), Vector3(5.0, 10.0, 3.0), "plaster_gray", ["-z"], "PlazaWingL")
	_building(root, Vector3(7.5, 5.0, 82.5), Vector3(5.0, 10.0, 3.0), "plaster_gray", ["-z"], "PlazaWingR")

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
	_prop(root, "oildrum", Vector3(-8.8, 0.45, 64.0), 30.0)
	_prop(root, "spool", Vector3(8.6, 0.41, 76.4), -15.0)
	_prop(root, "barricade_x", Vector3(-3.0, 0.89, 60.5), 75.0)
	_prop(root, "rubble_slab", Vector3(3.4, 0.18, 78.6), 10.0)

	# Benches ringing the fountain + dead planters (a plaza that used to live)
	_bench(root, Vector3(-3.6, 0.08, 70.0), 90.0)
	_bench(root, Vector3(3.6, 0.08, 70.0), -90.0)
	_bench(root, Vector3(0.0, 0.08, 66.4), 180.0)
	_planter(root, Vector3(-8.5, 0.08, 74.5), true)
	_planter(root, Vector3(8.5, 0.08, 67.0), true)
	_planter(root, Vector3(-8.5, 0.08, 61.5), false)
	_paper_scatter(root, Vector3(-1.5, 0.08, 67.5), 8, 2.2)
	_paper_scatter(root, Vector3(4.0, 0.08, 73.5), 6, 1.8)
	_rubble_pile(root, Vector3(-9.0, 0.08, 78.0), true)
	_rubble_pile(root, Vector3(9.2, 0.08, 62.0))

	# Notice board on the west building wall (resistance flyers)
	var board_frame := SourceMaterials.mat("wood_board")
	_deco(root, Vector3(-9.42, 1.8, 63.0), Vector3(0.1, 1.2, 2.0), board_frame)
	for i in range(6):
		var flyer := _deco(root, Vector3(-9.34, 1.8 + randf_range(-0.4, 0.4),
			63.0 + randf_range(-0.8, 0.8)), Vector3(0.02, 0.3, 0.22), _get_paper_mat())
		flyer.rotation_degrees.x = randf_range(-6.0, 6.0)

	# Extra combat cover: sandbag nests + overturned cart
	_sandbag_row(root, Vector3(-2.4, 0.08, 62.2), 4, "x")
	_sandbag_row(root, Vector3(1.0, 0.08, 77.6), 4, "x")
	var cart := _prop(root, "handtruck", Vector3(6.2, 0.45, 72.6), 35.0)
	if cart != null:
		cart.rotation_degrees.z = 88.0
	_prop(root, "barrel_warn", Vector3(-6.4, 0.08, 66.8), 0.0)
	_prop(root, "sawhorse", Vector3(2.4, 0.08, 63.2), 120.0)

	# Power lines crossing the plaza corners
	_wire(root, Vector3(-9.5, 12.4, 63.0), Vector3(-5.2, 9.6, 81.0))
	_wire(root, Vector3(9.5, 12.4, 77.0), Vector3(5.2, 9.6, 81.0))

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

	# Open door at the entrance (door01 has a centered origin — y is half height)
	var door := _prop(root, "door", Vector3(-1.4, 1.49, bz - 6.0), -55.0)
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
	# Lockers instead of the near-white equipment1 cabinet (see staging area).
	_prop(root, "lockers", Vector3(4.5, 0.12, bz + 5.2), 180.0)
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
	var wall_clock := _prop(root, "clock", Vector3(0.0, 3.2, bz + 5.75), 0.0)
	if wall_clock != null:
		wall_clock.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_prop(root, "butane", Vector3(-3.6, 0.13, bz - 4.4), 0.0)

	# Lived-in mess: sleeping bag, scattered papers, overturned crate,
	# supply cart, food cans on the cooler, maps pinned to the wall.
	var bag_mat := StandardMaterial3D.new()
	bag_mat.albedo_color = Color(0.23, 0.27, 0.2)
	bag_mat.roughness = 1.0
	_deco(root, Vector3(-2.6, 0.17, bz + 4.4), Vector3(0.8, 0.1, 2.0), bag_mat)
	_deco(root, Vector3(-2.6, 0.22, bz + 5.2), Vector3(0.6, 0.14, 0.4), bag_mat)  # pillow roll
	_paper_scatter(root, Vector3(0.5, 0.12, bz - 1.5), 9, 1.8)
	_paper_scatter(root, Vector3(2.2, 0.12, bz + 2.8), 5, 1.0)
	var tipped := _prop(root, "beacon_crate", Vector3(-1.6, 0.5, bz - 2.6), 20.0)
	if tipped != null:
		tipped.rotation_degrees.z = 94.0
	_prop(root, "hospital_cart", Vector3(0.8, 0.55, bz + 4.4), 165.0)
	# Cans on the cooler top (cooler is 1.28 tall, base origin)
	var can_mat := SourceMaterials.mat("metal")
	for ci in range(3):
		var can := CSGCylinder3D.new()
		can.radius = 0.05
		can.height = 0.12
		can.sides = 8
		can.use_collision = false
		can.material = can_mat
		can.position = Vector3(4.15 + ci * 0.22, 1.46, bz - 1.0 + (ci % 2) * 0.18)
		root.add_child(can)
	# Maps/charts pinned to the back wall over the radio desk
	for mi_i in range(3):
		var chart := _deco(root, Vector3(1.6 + mi_i * 0.9, 2.1 + (mi_i % 2) * 0.35, bz + 5.76),
			Vector3(0.7, 0.55, 0.02), _get_paper_mat())
		chart.rotation_degrees.z = randf_range(-4.0, 4.0)
	# Wall shelf with supplies near the entrance
	_prop(root, "wall_shelf", Vector3(-4.7, 1.5, bz - 4.6), 90.0)
	_prop(root, "monitor_sm", Vector3(-4.6, 1.86, bz - 4.6), 110.0)

	# Crates on the second floor (slab top at 4.32)
	_crate_stack(root, Vector3(3.0, 4.32, bz + 3.0), 2)
	_prop(root, "oildrum", Vector3(-1.5, 4.69, bz + 4.8), 65.0)
	_prop(root, "footlocker", Vector3(-2.8, 4.63, bz + 4.4), 30.0)
	_paper_scatter(root, Vector3(1.0, 4.32, bz + 3.5), 4, 1.2)

	# Hanging industrial lights + dust
	for lp in [Vector3(0.0, 3.9, bz - 2.0), Vector3(2.0, 3.9, bz + 3.5)]:
		_prop(root, "bell_light", lp, 0.0, 1.0)
		var l := _omni(root, lp + Vector3(0, -0.45, 0), Color(0.95, 0.93, 0.85), 0.8, 6.0)
		if lp.x == 0.0:
			l.shadow_enabled = true
	_omni(root, Vector3(0.0, 6.4, bz + 2.0), Color(1.0, 0.85, 0.6), 0.6, 6.0)

	# Light shaft through the lit front window + drifting motes
	var shaft := SpotLight3D.new()
	shaft.position = Vector3(3.5, 2.4, bz - 6.0)
	shaft.rotation_degrees = Vector3(-28.0, 195.0, 0.0)
	shaft.light_color = Color(0.75, 0.8, 0.95)
	shaft.light_energy = 0.9
	shaft.spot_range = 7.0
	shaft.spot_angle = 28.0
	shaft.spot_angle_attenuation = 1.5
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

	# Door ajar (centered origin)
	var door := _prop(root, "door", Vector3(-1.5, 1.49, bz - 5.0), -35.0)
	if door == null:
		_csg(root, Vector3(-1.3, 1.35, bz - 5.1), Vector3(0.1, 2.7, 1.1), SourceMaterials.mat("wood_door"))

	# Defensive dressing outside — last-stand position
	_concrete_barrier(root, Vector3(-3.0, 0.05, bz - 7.5), 4.0)
	_concrete_barrier(root, Vector3(3.0, 0.05, bz - 7.5), -7.0)
	_sandbag_row(root, Vector3(-1.6, 0.05, bz - 8.6), 5, "x")
	_sandbag_row(root, Vector3(-4.8, 0.05, bz - 9.4), 4, "x")
	_prop(root, "barricade_tri", Vector3(-4.6, 0.56, bz - 6.4), 30.0)
	_prop(root, "barricade_x", Vector3(4.6, 0.86, bz - 8.4), -60.0)
	_prop(root, "oildrum", Vector3(4.8, 0.42, bz - 6.2), 110.0)
	_prop(root, "barrel_warn", Vector3(-5.6, 0.05, bz - 7.8), 0.0)
	# Ammo crates stacked against the front wall
	_prop(root, "ammocrate_s", Vector3(3.6, 0.46, bz - 5.6), 4.0)
	_prop(root, "ammocrate_p", Vector3(4.6, 0.46, bz - 5.4), -10.0)
	_prop(root, "ammocrate_s", Vector3(4.1, 1.32, bz - 5.5), 8.0)
	_crate_stack(root, Vector3(-5.4, 0.05, bz - 5.6), 2)
	_rubble_pile(root, Vector3(-3.4, 0.05, bz - 10.6), true)
	_rubble_pile(root, Vector3(5.4, 0.05, bz - 10.0))
	_paper_scatter(root, Vector3(0.0, 0.05, bz - 7.0), 6, 2.0)

	# Porch light over the door
	_prop(root, "sconce", Vector3(0.0, 3.4, bz - 5.25), 0.0, 1.0)
	var porch := _omni(root, Vector3(0.0, 3.2, bz - 5.8), Color(1.0, 0.8, 0.5), 0.9, 7.0)
	_add_flicker(porch)

	# Interior: someone left in a hurry
	_prop(root, "hospital_bed", Vector3(3.4, 0.48, bz + 3.4), 12.0)
	_prop(root, "footlocker", Vector3(1.6, 0.43, bz + 3.8), 80.0)
	_prop(root, "radio", Vector3(-3.8, 0.87, bz + 4.2), 145.0)
	var crate := _prop(root, "beacon_crate", Vector3(-3.8, 0.12, bz + 4.2), 10.0)
	if crate == null:
		_csg(root, Vector3(-3.8, 0.5, bz + 4.2), Vector3(0.8, 0.8, 0.8), board)
	_prop(root, "stool", Vector3(-2.6, 0.12, bz + 3.2), -140.0)
	_prop(root, "shelf", Vector3(5.1, 1.22, bz + 1.0), -90.0)
	_prop(root, "gnome", Vector3(4.0, 0.12, bz - 3.6), 230.0)
	# Back wall (faces the entrance): lockers, wall shelf, pinned charts, duct
	_prop(root, "lockers", Vector3(-1.2, 1.02, bz + 4.55), 0.0)
	_prop(root, "wall_shelf", Vector3(0.8, 1.5, bz + 4.72), 180.0)
	_prop(root, "frame", Vector3(2.2, 2.0, bz + 4.78), 180.0)
	_prop(root, "duct", Vector3(-4.6, 3.4, bz + 4.7), 180.0)
	for ci3 in range(3):
		var chart3 := _deco(root, Vector3(-2.9 + ci3 * 0.8, 2.0 + (ci3 % 2) * 0.5, bz + 4.78),
			Vector3(0.6, 0.5, 0.02), _get_paper_mat())
		chart3.rotation_degrees.z = randf_range(-5.0, 5.0)
	_omni(root, Vector3(0.0, 2.6, bz + 3.5), Color(1.0, 0.85, 0.6), 0.7, 6.0)
	_paper_scatter(root, Vector3(0.0, 0.12, bz + 1.0), 7, 2.0)
	_prop(root, "refrigerator", Vector3(-4.9, 0.12, bz + 0.2), 90.0)
	_prop(root, "wall_shelf", Vector3(-5.25, 1.5, bz + 2.4), 90.0)
	# Planning table in the middle of the room — Biden's abandoned escape plan
	var tbl := _csg(root, Vector3(0.6, 0.5, bz - 0.6), Vector3(2.0, 0.08, 1.0),
		SourceMaterials.mat("wood_board"), "PlanTable")
	tbl.rotation_degrees.y = 14.0
	var tmetal := SourceMaterials.mat("metal")
	for leg_off in [Vector3(-0.85, 0.25, -0.4), Vector3(0.85, 0.25, -0.4),
			Vector3(-0.85, 0.25, 0.4), Vector3(0.85, 0.25, 0.4)]:
		_deco(root, Vector3(0.6, 0, bz - 0.6) + leg_off, Vector3(0.07, 0.5, 0.07), tmetal)
	for pi in range(4):
		var page := _deco(root, Vector3(0.6 + randf_range(-0.7, 0.7), 0.56,
			bz - 0.6 + randf_range(-0.3, 0.3)), Vector3(0.26, 0.012, 0.34), _get_paper_mat())
		page.rotation_degrees.y = randf_range(0, 360)
	_prop(root, "monitor_sm", Vector3(1.1, 0.69, bz - 0.7), -160.0)
	_prop(root, "stool", Vector3(-0.3, 0.12, bz - 1.4), 75.0)
	var tipped_stool := _prop(root, "stool", Vector3(1.8, 0.35, bz + 0.4), 0.0)
	if tipped_stool != null:
		tipped_stool.rotation_degrees.z = 96.0
	# Charts pinned over the side walls
	for ci2 in range(2):
		var chart2 := _deco(root, Vector3(-5.28, 1.9 + ci2 * 0.7, bz - 2.0 + ci2 * 1.2),
			Vector3(0.02, 0.5, 0.65), _get_paper_mat())
		chart2.rotation_degrees.x = randf_range(-5.0, 5.0)
	_paper_scatter(root, Vector3(1.0, 0.12, bz - 2.6), 5, 1.2)
	_prop(root, "butane", Vector3(2.6, 0.13, bz - 4.2), 0.0)
	_prop(root, "hospital_cart", Vector3(-3.2, 0.55, bz - 3.8), 50.0)
	# Inside of the front wall: locker bank, leaning planks, barricade junk
	_prop(root, "lockers", Vector3(2.9, 1.02, bz - 4.45), 0.0)
	for bi in range(3):
		var plank := _deco(root, Vector3(-3.4 + bi * 0.35, 1.3, bz - 4.62),
			Vector3(0.25, 2.6, 0.07), board)
		plank.rotation_degrees.x = randf_range(-10.0, -4.0)
		plank.rotation_degrees.y = randf_range(-8.0, 8.0)
	_prop(root, "footlocker", Vector3(0.9, 0.43, bz - 4.4), 95.0)
	_paper_scatter(root, Vector3(0.0, 0.12, bz - 3.6), 6, 1.4)
	_rubble_pile(root, Vector3(-2.2, 0.12, bz - 4.0))
	_omni(root, Vector3(0.0, 3.4, bz + 1.0), Color(1.0, 0.86, 0.6), 0.9, 7.0)
	_prop(root, "bell_light", Vector3(0.0, 3.85, bz + 1.0), 0.0, 1.0)

	# Path dressing between interior and safehouse (z 94..100)
	_prop(root, "fence_chain", Vector3(-7.0, 1.63, 97.0), 25.0)
	_prop(root, "fence_chain", Vector3(7.0, 1.63, 97.0), -20.0)
	_prop(root, "oildrum", Vector3(-4.4, 0.42, 96.5), 200.0)
	_prop(root, "bush", Vector3(5.2, 0.04, 95.5), 0.0)
	_prop(root, "bush", Vector3(-5.6, 0.04, 99.0), 120.0)
	_rubble_pile(root, Vector3(3.8, 0.05, 94.0))
	_prop(root, "detail_grass", Vector3(-4.4, 0.04, 94.5), 70.0)
	_prop(root, "detail_grass", Vector3(4.8, 0.04, 92.5), 200.0)
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
# Map edges — continuous street-canyon walls + collapsed street ends so the
# player can never see out of the world.
# ---------------------------------------------------------------------------

func _build_map_edges() -> void:
	var root := Node3D.new()
	root.name = "MapEdges"
	add_child(root)

	var dark_mat := SourceMaterials.mat("skyline", Color(0.13, 0.14, 0.165))
	var lit := SourceMaterials.lit_window_mat()

	# Continuous 16m canyon walls along both sides of the playable corridor.
	# They read as the unbroken back row of City 17 blocks.
	_csg(root, Vector3(-22.0, 7.8, 60.0), Vector3(4.0, 16.0, 152.0), dark_mat, "CanyonWest")
	_csg(root, Vector3(22.0, 7.8, 60.0), Vector3(4.0, 16.0, 152.0), dark_mat, "CanyonEast")
	# Parapet caps so the rooflines don't end in a knife edge
	_deco(root, Vector3(-22.0, 16.0, 60.0), Vector3(4.3, 0.5, 152.3), SourceMaterials.mat("trim"))
	_deco(root, Vector3(22.0, 16.0, 60.0), Vector3(4.3, 0.5, 152.3), SourceMaterials.mat("trim"))
	# Sparse lit windows facing inward so the walls read as inhabited blocks
	for i in range(10):
		var wz := -8.0 + i * 14.0
		if i % 3 != 1:
			_deco(root, Vector3(-19.95, 4.0 + (i % 4) * 2.6, wz), Vector3(0.1, 1.0, 0.7), lit)
		if i % 3 != 2:
			_deco(root, Vector3(19.95, 5.0 + (i % 4) * 2.4, wz + 5.0), Vector3(0.1, 1.0, 0.7), lit)
	# Rooftop water tanks/chimneys silhouetted on the canyon walls
	_prop(root, "fuel_cask", Vector3(-22.0, 15.8, 30.0), 20.0, 0.8)
	_prop(root, "chimney", Vector3(22.0, 15.8, 52.0), -15.0)
	_prop(root, "fuel_cask", Vector3(22.0, 15.8, 96.0), 70.0, 0.8)
	_prop(root, "chimney", Vector3(-22.0, 15.8, 88.0), 35.0)

	# South end (behind the staging area): row of building masses + rubble berm.
	_end_building_row(root, -16.0, false)
	_street_end_blockade(root, Vector3(0.0, 0.0, -13.0), 0.0)

	# North end (past the safehouse): same treatment, collapsed street.
	_end_building_row(root, 130.0, true)
	_street_end_blockade(root, Vector3(0.0, 0.0, 124.0), 180.0)

	# Caps over the side gaps between plaza blocks and the canyon walls
	_csg(root, Vector3(-17.0, 6.0, 70.0), Vector3(6.0, 12.0, 4.0), dark_mat, "PlazaCapW")
	_csg(root, Vector3(17.0, 6.0, 70.0), Vector3(6.0, 12.0, 4.0), dark_mat, "PlazaCapE")


## Street-end backdrop: three offset building masses with varied facades,
## lit windows and roof clutter, so the map edge reads as more city — not a
## single giant blank wall. `faces_north` flips which side gets windows.
func _end_building_row(parent: Node, z: float, faces_north: bool) -> void:
	var face := "-z" if faces_north else "+z"
	var dz := -1.5 if faces_north else 1.5
	_building(parent, Vector3(-14.0, 7.0, z - dz), Vector3(20.0, 14.0, 5.0),
		"indust_wall", [face])
	_building(parent, Vector3(2.0, 8.5, z), Vector3(14.0, 17.0, 5.0),
		"concrete_wall_b", [face])
	_building(parent, Vector3(16.0, 6.5, z - dz), Vector3(16.0, 13.0, 5.0),
		"brick_inn", [face])
	# Backfill behind the row so no sky leaks between the offset masses
	_deco(parent, Vector3(0.0, 9.0, z - dz * 2.0),
		Vector3(50.0, 20.0, 2.0), SourceMaterials.mat("skyline", Color(0.13, 0.14, 0.165)))


## Collapsed-street blockade: rubble mound + ruined wall + wrecked cars +
## barricades. Implies the road continues but is buried.
func _street_end_blockade(parent: Node, pos: Vector3, rot_y: float) -> void:
	var blockade := Node3D.new()
	parent.add_child(blockade)
	blockade.position = pos
	blockade.rotation_degrees.y = rot_y

	var rubble_mat := SourceMaterials.mat("concrete_old")
	var dirt_mat := SourceMaterials.mat("dirt")

	# Rubble mound: stacked tilted slabs reading as a collapsed building edge
	var mound := _csg(blockade, Vector3(0.0, 0.8, -1.0), Vector3(18.0, 2.6, 4.5), rubble_mat)
	mound.rotation_degrees.x = -14.0
	var mound2 := _csg(blockade, Vector3(-4.0, 1.6, -1.8), Vector3(9.0, 2.4, 4.0), dirt_mat)
	mound2.rotation_degrees = Vector3(-9.0, 14.0, 6.0)
	var mound3 := _csg(blockade, Vector3(5.0, 1.4, -2.0), Vector3(8.0, 2.2, 3.6), rubble_mat)
	mound3.rotation_degrees = Vector3(-11.0, -10.0, -5.0)

	# Ruined wall sections rising out of the rubble
	_prop(blockade, "wall_ruin9", Vector3(0.0, 1.9, -3.0), 0.0)
	_prop(blockade, "wall_ruin", Vector3(-6.5, 1.8, -1.5), 12.0)
	_prop(blockade, "wall_ruin", Vector3(7.0, 1.7, -2.0), -8.0)

	# Wrecked car cluster shoved against the rubble (kept clear of the
	# staging-area truck on the south end)
	_prop(blockade, "car_cluster2", Vector3(4.5, 0.1, 2.2), 14.0, 0.9)

	# Front dressing: barricades, rebar, loose chunks
	_prop(blockade, "barricade_x", Vector3(-3.5, 0.81, 4.4), 25.0)
	_prop(blockade, "barricade_tri", Vector3(3.0, 0.51, 4.8), -30.0)
	_prop(blockade, "rebar_big", Vector3(1.2, 0.45, 3.6), 50.0)
	_rubble_pile(blockade, Vector3(-5.5, 0.0, 4.0), true)
	_rubble_pile(blockade, Vector3(4.8, 0.0, 3.4), true)
	_rubble_pile(blockade, Vector3(0.5, 0.0, 5.2))


# ---------------------------------------------------------------------------
# Skyline silhouettes around the playable space
# ---------------------------------------------------------------------------

func _build_skyline() -> void:
	var root := Node3D.new()
	root.name = "Skyline"
	add_child(root)

	# Textured dark concrete — flat albedo boxes this close to the playable
	# area read as untextured geometry.
	var sil := SourceMaterials.mat("skyline", Color(0.13, 0.14, 0.165))

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
			hecu.position = Vector3(3.0, 0.3, 2.0)
			add_child(hecu)
			_spawned_npcs.append(hecu)

	if ResourceLoader.exists(RESISTANCE_SOLDIER_SCENE):
		var rs_scene := ResourceLoader.load(RESISTANCE_SOLDIER_SCENE) as PackedScene
		if rs_scene != null:
			# Street fighters patrol up and down the road so they read as
			# moving (visible walk cycle) instead of standing mannequins.
			# NOTE: spawn points must be clear of prop collision bodies —
			# overlapping a static body at spawn depenetrates the capsule
			# through the thin road CSG (the "NPC in the ground" bug; the old
			# spawn at (5, 40) intersected the sidewalk dumpster).
			var street_spawns := [
				[Vector3(4.0, 0.3, 25.0), [Vector3(4.0, 0.3, 36.0), Vector3(4.0, 0.3, 24.0)]],
				[Vector3(3.8, 0.3, 38.0), [Vector3(-3.0, 0.3, 46.5), Vector3(3.8, 0.3, 38.0)]],
				[Vector3(-5.5, 0.3, 35.0), [Vector3(-5.5, 0.3, 23.0), Vector3(-5.5, 0.3, 36.0)]],
			]
			for entry in street_spawns:
				var rs := rs_scene.instantiate()
				rs.position = entry[0]
				var wp: Array[Vector3] = []
				wp.assign(entry[1])
				rs.waypoints = wp
				add_child(rs)
				_spawned_npcs.append(rs)

			var alley_positions := [
				Vector3(-10.2, 0.3, 49.0),
				Vector3(-8.3, 0.3, 48.4),
			]
			for pos in alley_positions:
				var rs := rs_scene.instantiate()
				rs.position = pos
				add_child(rs)
				_spawned_npcs.append(rs)

			# Two plaza guards circle the fountain; the rest hold position.
			var plaza_spawns := [
				[Vector3(-3.0, 0.3, 65.0), [Vector3(3.0, 0.3, 65.0), Vector3(-3.0, 0.3, 65.0)]],
				[Vector3(3.0, 0.3, 65.5), []],
				[Vector3(-6.0, 0.3, 70.0), [Vector3(-6.0, 0.3, 76.0), Vector3(-6.0, 0.3, 69.0)]],
				[Vector3(6.0, 0.3, 69.0), []],
				[Vector3(0.0, 0.3, 74.0), []],
			]
			for entry in plaza_spawns:
				var rs := rs_scene.instantiate()
				rs.position = entry[0]
				var wp: Array[Vector3] = []
				wp.assign(entry[1])
				rs.waypoints = wp
				add_child(rs)
				_spawned_npcs.append(rs)

			var interior_positions := [
				Vector3(-2.0, 0.3, 87.0),
				Vector3(2.5, 0.3, 89.5),
				Vector3(0.0, 4.5, 88.0),
			]
			for pos in interior_positions:
				var rs := rs_scene.instantiate()
				rs.position = pos
				add_child(rs)
				_spawned_npcs.append(rs)


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
