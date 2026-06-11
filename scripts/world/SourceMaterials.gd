class_name SourceMaterials
extends Object
## Shared Source-asset helper: builds triplanar StandardMaterial3D from VTF
## textures, spawns imported MDL prop scenes safely, and provides small
## dressing utilities (light cones, lit windows).
##
## Every texture/model path in here was verified by a headless probe run —
## but all loads remain guarded so a missing file can never crash the game.

## MDL files import at 0.02 scale (Source units * 0.02). True Source scale is
## 0.0254 m per unit, so multiply imported scenes by 1.27 to get HL2 size.
const MDL_SCALE := 1.27

## Curated palette. Each entry: texture, optional normal, tile size in meters,
## roughness, optional albedo tint.
const PALETTE := {
	# --- ground ---
	"road": {
		"texture": "res://materials/concrete/concretefloor039a.vtf",
		"normal": "res://materials/concrete/concretefloor039a_normal.vtf",
		"tile_m": 3.2, "roughness": 0.95, "tint": Color(0.62, 0.62, 0.64),
	},
	"sidewalk": {
		"texture": "res://materials/concrete/concretefloor033a.vtf",
		"normal": "res://materials/concrete/concretefloor033a_normal.vtf",
		"tile_m": 2.56, "roughness": 0.9,
	},
	"concrete_pad": {
		"texture": "res://materials/concrete/concretefloor028c.vtf",
		"normal": "res://materials/concrete/concretefloor028c_normal.vtf",
		"tile_m": 2.56, "roughness": 0.9,
	},
	"concrete_old": {
		"texture": "res://materials/concrete/concretefloor028d.vtf",
		"normal": "res://materials/concrete/concretefloor028d_normal.vtf",
		"tile_m": 2.56, "roughness": 0.95,
	},
	"cobble": {
		"texture": "res://materials/stone/cobble08a.vtf",
		"normal": "res://materials/stone/cobble08a_normal.vtf",
		"tile_m": 2.2, "roughness": 0.9,
	},
	"dirt": {
		"texture": "res://materials/nature/dirtfloor004a.vtf",
		"tile_m": 4.0, "roughness": 1.0, "tint": Color(0.85, 0.82, 0.78),
	},
	"gravel": {
		"texture": "res://materials/nature/forest_gravel_01.vtf",
		"tile_m": 2.3, "roughness": 1.0,
	},
	"sandbag": {
		"texture": "res://materials/nature/dirtfloor_mine001a.vtf",
		"tile_m": 0.9, "roughness": 1.0, "tint": Color(0.78, 0.72, 0.6),
	},
	# --- exterior walls ---
	"plaster_tan": {
		"texture": "res://materials/plaster/plasterwall008a.vtf",
		"tile_m": 2.56, "roughness": 0.92,
	},
	"plaster_gray": {
		"texture": "res://materials/plaster/plasterwall011b.vtf",
		"tile_m": 2.56, "roughness": 0.92,
	},
	"plaster_worn": {
		"texture": "res://materials/plaster/plasterwall053a.vtf",
		"tile_m": 2.56, "roughness": 0.92,
	},
	"plaster_aged": {
		"texture": "res://materials/plaster/plasterwall052a.vtf",
		"tile_m": 2.56, "roughness": 0.92,
	},
	"brick_inn": {
		"texture": "res://materials/concrete/concretewall_inn01a.vtf",
		"tile_m": 2.56, "roughness": 0.93,
	},
	"concrete_wall": {
		"texture": "res://materials/concrete/concretewall075a.vtf",
		"tile_m": 2.56, "roughness": 0.93,
	},
	"concrete_wall_b": {
		"texture": "res://materials/concrete/ep2_concretewall01a.vtf",
		"tile_m": 2.56, "roughness": 0.93,
	},
	"indust_wall": {
		"texture": "res://materials/concrete/indust_concretewall01a.vtf",
		"tile_m": 2.56, "roughness": 0.93,
	},
	"trim": {
		"texture": "res://materials/concrete/concretewall076a.vtf",
		"tile_m": 1.6, "roughness": 0.9, "tint": Color(0.8, 0.78, 0.75),
	},
	"baseboard": {
		"texture": "res://materials/concrete/concretewall075b.vtf",
		"tile_m": 1.8, "roughness": 0.95, "tint": Color(0.62, 0.6, 0.58),
	},
	# --- metal / wood ---
	"metal": {
		"texture": "res://materials/metal/forest_metal_02a.vtf",
		"tile_m": 2.0, "roughness": 0.6, "metallic": 0.4,
	},
	"metal_rusty": {
		"texture": "res://materials/metal/forest_metal01a.vtf",
		"tile_m": 2.0, "roughness": 0.8, "metallic": 0.2,
	},
	"metal_door": {
		"texture": "res://materials/metal/metaldoor043b.vtf",
		"tile_m": 2.56, "roughness": 0.7, "metallic": 0.3,
	},
	"hazard": {
		"texture": "res://materials/metal/metal_emergencystripe01a.vtf",
		"tile_m": 0.64, "roughness": 0.7,
	},
	"wood_floor": {
		"texture": "res://materials/wood/ep2_woodfloor01.vtf",
		"tile_m": 2.56, "roughness": 0.85,
	},
	"wood_wall": {
		"texture": "res://materials/wood/woodwall035a.vtf",
		"tile_m": 2.0, "roughness": 0.9,
	},
	"wood_board": {
		"texture": "res://materials/wood/woodfence001.vtf",
		"tile_m": 1.6, "roughness": 0.95,
	},
	"wood_door": {
		"texture": "res://materials/wood/wooddoor010a.vtf",
		"tile_m": 2.2, "roughness": 0.85,
	},
	"roof": {
		"texture": "res://materials/wood/shingles003.vtf",
		"tile_m": 2.2, "roughness": 0.95, "tint": Color(0.7, 0.7, 0.7),
	},
	# --- interior ---
	"int_wall": {
		"texture": "res://materials/plaster/plasterwall009a.vtf",
		"tile_m": 2.56, "roughness": 0.92,
	},
	"int_wall_b": {
		"texture": "res://materials/plaster/cellarwall01b.vtf",
		"tile_m": 2.56, "roughness": 0.95,
	},
	"ceiling": {
		"texture": "res://materials/wood/woodceiling003a.vtf",
		"tile_m": 2.56, "roughness": 0.95, "tint": Color(0.8, 0.8, 0.8),
	},
	"tile_wall": {
		"texture": "res://materials/tile/tilewall009e.vtf",
		"normal": "res://materials/tile/tilewall009e_normal.vtf",
		"tile_m": 2.56, "roughness": 0.55,
	},
	"tile_floor": {
		"texture": "res://materials/tile/tilefloor010b.vtf",
		"normal": "res://materials/tile/tilefloor010b_normal.vtf",
		"tile_m": 2.0, "roughness": 0.6,
	},
}

static var _mat_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _scene_cache: Dictionary = {}
static var _glass_mat: StandardMaterial3D = null
static var _lit_window_mat: StandardMaterial3D = null


# ---------------------------------------------------------------------------
# Textures / materials
# ---------------------------------------------------------------------------

static func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var result: Texture2D = null
	if ResourceLoader.exists(path):
		result = load(path) as Texture2D
	_tex_cache[path] = result
	return result


## World-triplanar tiled material from the curated palette.
## Falls back to a flat colored material only if the texture fails to load.
static func mat(key: String, fallback := Color(0.5, 0.5, 0.5)) -> Material:
	if _mat_cache.has(key):
		return _mat_cache[key]

	var m := StandardMaterial3D.new()
	var def: Dictionary = PALETTE.get(key, {})
	var texture: Texture2D = null
	if def.has("texture"):
		texture = tex(def["texture"])

	if texture != null:
		m.albedo_texture = texture
		m.albedo_color = def.get("tint", Color.WHITE)
		var tile_m: float = def.get("tile_m", 2.56)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * (1.0 / tile_m)
		m.roughness = def.get("roughness", 0.85)
		m.metallic = def.get("metallic", 0.0)
		m.metallic_specular = 0.3
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if def.has("normal"):
			var n := tex(def["normal"])
			if n != null:
				m.normal_enabled = true
				m.normal_texture = n
				m.normal_scale = 0.7
	else:
		m.albedo_color = fallback
		m.roughness = 0.9

	_mat_cache[key] = m
	return m


## Dark window glass (slightly reflective, unlit interior look).
static func glass_mat() -> StandardMaterial3D:
	if _glass_mat != null:
		return _glass_mat
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.04, 0.055, 0.08)
	m.roughness = 0.12
	m.metallic = 0.6
	m.metallic_specular = 0.7
	_glass_mat = m
	return m


## Warm emissive window pane for far/lit windows.
static func lit_window_mat() -> StandardMaterial3D:
	if _lit_window_mat != null:
		return _lit_window_mat
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.42, 0.2)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.72, 0.35)
	m.emission_energy_multiplier = 1.6
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var t := tex("res://materials/glass/ep2_window01.vtf")
	if t != null:
		m.albedo_texture = t
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.8
	_lit_window_mat = m
	return m


# ---------------------------------------------------------------------------
# MDL prop spawning
# ---------------------------------------------------------------------------

static func _load_model(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path]
	var ps: PackedScene = null
	if ResourceLoader.exists(path):
		ps = load(path) as PackedScene
	_scene_cache[path] = ps
	return ps


## Instantiate an imported MDL scene. Returns null on any failure.
## strip_collision removes the importer's StaticBody3D children (use for NPC
## bodies / viewmodels so they don't block bullets or movement).
static func spawn_model(parent: Node, path: String, pos: Vector3,
		rot_y_deg: float = 0.0, scale: float = MDL_SCALE,
		strip_collision: bool = false) -> Node3D:
	var ps := _load_model(path)
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return null
	if strip_collision:
		_strip_bodies(inst)
	inst.position = pos
	inst.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	inst.scale = Vector3.ONE * scale
	parent.add_child(inst)
	return inst


static func _strip_bodies(node: Node) -> void:
	var stack: Array = [node]
	var doomed: Array = []
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for child in n.get_children():
			if child is PhysicsBody3D:
				doomed.append(child)
			else:
				stack.append(child)
	for d in doomed:
		d.get_parent().remove_child(d)
		d.free()


# ---------------------------------------------------------------------------
# Dressing utilities
# ---------------------------------------------------------------------------

## Fake volumetric light cone (additive transparent cylinder->point mesh).
static func add_light_cone(parent: Node, pos: Vector3, length: float = 3.2,
		radius: float = 1.1, color := Color(1.0, 0.85, 0.55), alpha := 0.05) -> MeshInstance3D:
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.08
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	mesh.cap_top = false
	mesh.cap_bottom = false
	cone.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	cone.material_override = m
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.position = pos + Vector3(0.0, -length * 0.5, 0.0)
	parent.add_child(cone)
	return cone


## Drifting dust motes for interiors / light shafts.
static func add_dust_motes(parent: Node, pos: Vector3, extents: Vector3,
		amount: int = 12) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 6.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3(0, -1, 0)
	p.spread = 25.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.08
	p.scale_amount_min = 0.01
	p.scale_amount_max = 0.025
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.9, 0.85, 0.7, 0.18)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = m
	p.mesh = mesh
	p.position = pos
	parent.add_child(p)
	return p
