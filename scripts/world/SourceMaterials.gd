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
		"tile_m": 2.8, "roughness": 0.95, "tint": Color(0.78, 0.78, 0.8),
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
		# plasterwall011b is near-white and reads as a flat untextured box under
		# fog; 014b is the same family with visible weathering/stain contrast.
		"texture": "res://materials/plaster/plasterwall014b.vtf",
		"tile_m": 2.56, "roughness": 0.92, "tint": Color(0.84, 0.84, 0.82),
	},
	"plaster_worn": {
		"texture": "res://materials/plaster/plasterwall053a.vtf",
		"tile_m": 2.56, "roughness": 0.92,
	},
	"plaster_aged": {
		"texture": "res://materials/plaster/plasterwall052a.vtf",
		"tile_m": 2.56, "roughness": 0.92, "tint": Color(0.88, 0.88, 0.86),
	},
	"concrete_panels": {
		"texture": "res://materials/concrete/ep2_concretewall01c.vtf",
		"tile_m": 2.56, "roughness": 0.93,
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
	"skyline": {
		# Stained dark concrete for the out-of-bounds silhouette blocks —
		# they sit close enough to the playable space that flat albedo boxes
		# read as missing textures.
		"texture": "res://materials/concrete/concretewall_bunker04a.vtf",
		"tile_m": 3.4, "roughness": 1.0, "tint": Color(0.42, 0.44, 0.5),
	},
	"indust_wall": {
		"texture": "res://materials/concrete/indust_concretewall01a.vtf",
		"tile_m": 2.56, "roughness": 0.93,
	},
	"trim": {
		# NOTE: concretewall076a is BLUE-painted concrete — it made every
		# cornice/sill band blue. 075a is plain weathered grey concrete.
		"texture": "res://materials/concrete/concretewall075a.vtf",
		"tile_m": 1.6, "roughness": 0.9, "tint": Color(0.72, 0.7, 0.67),
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


## Dark window glass (subtle, near-black with faint sheen).
static func glass_mat() -> StandardMaterial3D:
	if _glass_mat != null:
		return _glass_mat
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.04, 0.055)
	m.roughness = 0.3
	m.metallic = 0.2
	m.metallic_specular = 0.5
	_glass_mat = m
	return m


static var _window_pane_mats: Dictionary = {}

## Industrial multi-pane window material using the real ep2 window texture.
## Plain UV (meant for QuadMesh windows, one texture per pane). `lit` adds a
## warm interior glow.
static func window_pane_mat(lit_pane: bool) -> StandardMaterial3D:
	var key := "lit" if lit_pane else "dark"
	if _window_pane_mats.has(key):
		return _window_pane_mats[key]
	var m := StandardMaterial3D.new()
	var t := tex("res://materials/glass/ep2_window01.vtf")
	if t != null:
		m.albedo_texture = t
	if lit_pane:
		m.albedo_color = Color(1.0, 0.95, 0.85)
		m.emission_enabled = true
		m.emission = Color(0.9, 0.62, 0.28)
		m.emission_energy_multiplier = 1.1
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		m.albedo_color = Color(0.5, 0.54, 0.6)
		m.roughness = 0.35
		m.metallic = 0.25
	_window_pane_mats[key] = m
	return m


## Warm emissive pane for far skyline windows (no texture detail needed).
static func lit_window_mat() -> StandardMaterial3D:
	if _lit_window_mat != null:
		return _lit_window_mat
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.66, 0.3)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.72, 0.35)
	m.emission_energy_multiplier = 1.4
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
# Audio helper
# ---------------------------------------------------------------------------

## Force a WAV stream to loop (imported WAVs default to one-shot).
## loop_end is in FRAMES, so account for bit depth and channel count.
static func make_wav_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		var bytes_per_sample := 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
		if wav.format == AudioStreamWAV.FORMAT_IMA_ADPCM:
			bytes_per_sample = 1  # approximation; ADPCM is 4-bit but loop still works
		var channels := 2 if wav.stereo else 1
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.data.size() / float(bytes_per_sample * channels))
	else:
		stream.set("loop", true)


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
	# NOTE: Keep the quad itself mote-sized — relying on scale_amount alone
	# leaves metre-wide additive squares floating in the room.
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.25
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.02, 0.02)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.9, 0.85, 0.7, 0.18)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = soft_radial_texture()
	mesh.material = m
	p.mesh = mesh
	p.position = pos
	parent.add_child(p)
	return p


## Soft radial sprite (bright centre fading to fully transparent edge).
## ALWAYS use this (or another soft texture) as the albedo of particle quads:
## a flat-colour quad has hard edges and, with glow + ACES tonemapping,
## renders as a large solid rectangle (esp. under llvmpipe).
static func soft_radial_texture(size: int = 64) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 0.45),
		Color(1, 1, 1, 0.0),
	])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = size
	t.height = size
	return t


## HL2-style fire (env_fire): additive billboard flame sprites with a radial
## soft texture and white->yellow->orange->out colour ramp, plus a few slow
## dark smoke puffs above. Small quads + scale curve; no hard-edged geometry.
static func add_fire(parent: Node, pos: Vector3, intensity: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Fire"
	parent.add_child(root)
	root.position = pos

	# --- Flames ---
	var flames := CPUParticles3D.new()
	flames.name = "Flames"
	flames.amount = 20
	flames.lifetime = 0.7
	flames.preprocess = 1.2
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.18 * intensity
	flames.direction = Vector3(0, 1, 0)
	flames.spread = 7.0
	flames.gravity = Vector3(0, 1.5, 0)
	flames.initial_velocity_min = 0.5
	flames.initial_velocity_max = 1.1
	flames.scale_amount_min = 0.55
	flames.scale_amount_max = 1.25
	var fcurve := Curve.new()
	fcurve.add_point(Vector2(0.0, 0.55))
	fcurve.add_point(Vector2(0.25, 1.0))
	fcurve.add_point(Vector2(1.0, 0.05))
	flames.scale_amount_curve = fcurve
	var framp := Gradient.new()
	framp.offsets = PackedFloat32Array([0.0, 0.22, 0.55, 0.85, 1.0])
	framp.colors = PackedColorArray([
		Color(1.0, 0.98, 0.85, 0.9),   # white-hot
		Color(1.0, 0.82, 0.35, 0.85),  # yellow
		Color(1.0, 0.45, 0.12, 0.7),   # orange
		Color(0.55, 0.12, 0.03, 0.35), # dark red
		Color(0.2, 0.05, 0.01, 0.0),   # out
	])
	flames.color_ramp = framp
	var fmesh := QuadMesh.new()
	fmesh.size = Vector2(0.3, 0.3) * intensity
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fmat.vertex_color_use_as_albedo = true
	fmat.albedo_texture = soft_radial_texture()
	fmesh.material = fmat
	flames.mesh = fmesh
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flames)

	# --- Smoke above the flames ---
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 10
	smoke.lifetime = 2.8
	smoke.preprocess = 2.5
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.15 * intensity
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 10.0
	smoke.gravity = Vector3(0.15, 0.5, 0.0)
	smoke.initial_velocity_min = 0.45
	smoke.initial_velocity_max = 0.85
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.2
	var scurve := Curve.new()
	scurve.add_point(Vector2(0.0, 0.4))
	scurve.add_point(Vector2(1.0, 1.0))
	smoke.scale_amount_curve = scurve
	var sramp := Gradient.new()
	sramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	sramp.colors = PackedColorArray([
		Color(0.1, 0.09, 0.08, 0.0),
		Color(0.09, 0.09, 0.1, 0.3),
		Color(0.08, 0.08, 0.09, 0.0),
	])
	smoke.color_ramp = sramp
	var smesh := QuadMesh.new()
	smesh.size = Vector2(0.45, 0.45) * intensity
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.vertex_color_use_as_albedo = true
	smat.albedo_texture = soft_radial_texture()
	smesh.material = smat
	smoke.mesh = smesh
	smoke.position = Vector3(0, 0.35 * intensity, 0)
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(smoke)

	return root
