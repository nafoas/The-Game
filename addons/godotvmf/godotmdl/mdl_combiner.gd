## This class generates a MeshInstance3D from parsed MDL, VTX, VVD and PHY files.
class_name MDLCombiner extends RefCounted

var st := SurfaceTool.new();
var array_mesh := ArrayMesh.new();
var mesh_instance := MeshInstance3D.new();
var skeleton := Skeleton3D.new();
var options: Dictionary = {};
var mdl: MDLReader;
var vtx: VTXReader;
var vvd: VVDReader;
var phy: PHYReader;

var is_static_body: bool:
	get: return (mdl.header.flags & mdl.MDLFlag.STATIC_PROP) != 0;

var scale: float:
	get: return options.scale if not options.use_global_scale else VMFConfig.import.scale;

var rotation_radians: Vector3:
	get: return options.get("additional_rotation", Vector3.ZERO) / 180.0 * PI;

var additional_basis: Basis:
	get: return Basis.from_euler(rotation_radians);
	
## Apply a skin to a mesh instance
## directly means that skin is applied to internal mesh itself
static func apply_skin(mesh_instance: MeshInstance3D, skin_id: int, directly: bool = false):
	if not mesh_instance.has_meta("skin_" + str(skin_id)): return;
	var materials = mesh_instance.get_meta("skin_" + str(skin_id));

	for surface_idx in range(mesh_instance.mesh.get_surface_count()):
		if directly:
			mesh_instance.mesh.surface_set_material(surface_idx, materials[surface_idx]);
		else:
			mesh_instance.set_surface_override_material(surface_idx, materials[surface_idx]);

func _init(mdl: MDLReader, vtx: VTXReader, vvd: VVDReader, phy: PHYReader, options: Dictionary):
	self.options = options;
	self.mdl = mdl;
	self.vtx = vtx;
	self.vvd = vvd;
	self.phy = phy;

	setup_mesh_instance();
	setup_skeleton();

	generate_lods()
	generate_collision();
	create_occluder();
	assign_materials();

## Material slot (index into mdl.textures via skin families) per committed surface.
var surface_material_slots: Array[int] = [];

func setup_mesh_instance():
	var scale = options.scale if not options.use_global_scale else VMFConfig.import.scale;

	var body_part_index = 0;
	for body_part in vtx.body_parts:
		process_body_part(body_part, body_part_index);
		body_part_index += 1;

	# NOTE: Skinned (non static prop) meshes keep their bone arrays;
	#       lightmap unwrapping would rebuild the mesh and drop them.
	if is_static_body:
		array_mesh.lightmap_unwrap(Transform3D.IDENTITY, VMFConfig.models.lightmap_texel_size);
	mesh_instance.name = "mesh";
	mesh_instance.gi_mode = options.get("gi_mode", GeometryInstance3D.GI_MODE_DYNAMIC);
	mesh_instance.set_mesh(array_mesh);

func process_body_part(body_part: VTXReader.VTXBodyPart, body_part_index: int):
	var model_index = 0;
	for model in body_part.models:
		process_model(model, body_part_index, model_index);
		model_index += 1;

func process_model(model: VTXReader.VTXModel, body_part_index: int, model_index: int):
	# NOTE: Since godot doesn't support importing custom 
	# 		lod models, we will only use the first lod
	process_lod(model.lods[0], body_part_index, model_index);

func process_lod(lod: VTXReader.VTXLod, body_part_index: int, model_index: int):
	var mesh_index = 0;
	for mesh in lod.meshes:
		process_mesh(mesh, body_part_index, model_index, mesh_index);
		mesh_index += 1;

func process_mesh(mesh: VTXReader.VTXMesh, body_part_index: int, model_index: int, mesh_index: int):
	var mdl_model = mdl.body_parts[body_part_index].models[model_index];
	var mdl_mesh = mdl_model.meshes[mesh_index];

	var model_vertex_index_start = mdl_model.vert_index / 0x30 | 0; # vert_index is a byte offset; VVD vertices are 0x30 bytes each

	# NOTE: One surface per MDL mesh. VTX indices are pre-offset by the strip
	#       group's vertex base inside the mesh (see VTXReader.idx_base), so all
	#       strip groups of a mesh must land in a single surface — otherwise
	#       every strip group after the first commits its vertices without any
	#       valid indices and renders as garbage triangle soup.
	var total_verts := 0;
	for strip_group in mesh.strip_groups:
		total_verts += strip_group.vertices.size();

	if total_verts == 0: return;

	st.begin(Mesh.PRIMITIVE_TRIANGLES);
	for strip_group in mesh.strip_groups:
		for vert_info in strip_group.vertices:
			var vid = vvd.find_vertex_index(model_vertex_index_start + mdl_mesh.vertex_index_start + vert_info.orig_mesh_vert_id);
			var vert := vvd.vertices[vid];
			var tangent := vvd.tangents[vid];

			st.set_normal(vert.normal * additional_basis);
			st.set_tangent(tangent);
			st.set_uv(vert.uv);
			st.set_bones(vert.bone_weight.bone_bytes);
			st.set_weights(vert.bone_weight.weight_bytes);
			st.add_vertex(vert.position * additional_basis.scaled(Vector3.ONE * scale));

	for strip_group in mesh.strip_groups:
		for indice in strip_group.indices:
			if indice > total_verts - 1: continue;
			st.add_index(indice);

	st.commit(array_mesh);
	surface_material_slots.append(mdl_mesh.material);

func create_occluder():
	if not options.generate_occluder: return;

	var occluder := OccluderInstance3D.new();
	var am: ArrayMesh = ArrayMesh.new();
	var box = ArrayOccluder3D.new();

	var colliders = VMFUtils.get_children_recursive(mesh_instance).filter(func(n): return n is CollisionShape3D);
	if not options.primitive_occluder:
		var st = SurfaceTool.new();
		var vertices = [];
		var indices = [];

		var begin_vid = 0;

		st.begin(Mesh.PRIMITIVE_TRIANGLES);

		for child in colliders:
			var s: ConcavePolygonShape3D = child.shape;
			var points = s.get_faces();

			for p in points:
				st.add_vertex(p);

			for i in range(points.size()):
				st.add_index(begin_vid + i);

			begin_vid += points.size();

		st.commit(am);

		var arrays = am.surface_get_arrays(0);
		if arrays.size() > 0:
			box.set_arrays(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_INDEX]);
	else:
		box = BoxOccluder3D.new();
		var aabb = mesh_instance.mesh.get_aabb();
		box.size = aabb.size * options.primitive_occluder_scale;
		occluder.position = aabb.position + aabb.size / 2.0;

	occluder.occluder = box;
	occluder.name = "occluder";

	mesh_instance.add_child(occluder);
	occluder.set_owner(mesh_instance);

# TODO: For non-static props collision should be rotated by 90 degrees around y-axis
func generate_collision():
	var yup_to_zup = Basis().rotated(Vector3.RIGHT, PI / 2);
	var yup_to_zup_transform = Transform3D(yup_to_zup, Vector3.ZERO);

	var surface_index = 0;
	for surface in phy.surfaces:
		var solid_index = 0;
		var static_body: StaticBody3D;

		for solid in surface.solids:
			# NOTE: Skip the last solid since it's a fullbody collision shape
			if solid_index == surface.solids.size() - 1 and surface.solids.size() > 1: break;

			if not is_static_body:
				static_body = StaticBody3D.new();
				static_body.name = "solid_" + str(surface_index) + "_" + str(solid_index);
			else:
				var is_new_static_body = static_body == null;
				static_body = StaticBody3D.new() if not static_body else static_body;
				if is_new_static_body:
					static_body.name = "static_body";

			var collision: CollisionShape3D = CollisionShape3D.new();
			var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new();

			collision.name = "collision_" + str(surface_index) + "_" + str(solid_index);
			static_body.basis *= additional_basis;

			var vertices = [];

			for face in solid.faces:
				var v1 = surface.vertices[face.v1] * additional_basis.scaled(Vector3.ONE * scale);
				var v2 = surface.vertices[face.v2] * additional_basis.scaled(Vector3.ONE * scale);
				var v3 = surface.vertices[face.v3] * additional_basis.scaled(Vector3.ONE * scale);

				vertices.append_array([v1, v2, v3]);

			shape.points = PackedVector3Array(vertices);
			collision.shape = shape;

			if not is_static_body:
				var bone_attachment: BoneAttachment3D = BoneAttachment3D.new();
				bone_attachment.name = "bone_attachment_" + str(surface_index) + "_" + str(solid_index);
				bone_attachment.bone_idx = max(0, solid.bone_index - 1);
				bone_attachment.add_child(static_body);
				skeleton.add_child(bone_attachment);
				bone_attachment.set_owner(mesh_instance);
				static_body.set_owner(mesh_instance);
			else:
				# NOTE: We don't need bone attachment for static bodies since they has only one bone
				mesh_instance.add_child(static_body);
				static_body.set_owner(mesh_instance);

			static_body.add_child(collision);
			collision.set_owner(mesh_instance);

			solid_index += 1;

		surface_index += 1;

func setup_skeleton():
	if Engine.get_version_info().minor < 4: return;
	if is_static_body: return;

	for bone in mdl.bones:
		skeleton.add_bone(bone.name);

	# NOTE: Bone pos/quat are local bind-pose transforms (already converted to
	#       y-up by ByteReader). Rest = bind pose, with translations scaled the
	#       same way as the vertices. Scaling the basis as well would compound
	#       down the bone chain and destroy the skin binds, so only the origin
	#       is scaled here.
	for bone in mdl.bones:
		if bone.parent != -1:
			skeleton.set_bone_parent(bone.id, bone.parent);

		var rest := Transform3D(Basis(bone.quat), bone.pos * scale);
		if bone.parent == -1:
			rest = Transform3D(additional_basis, Vector3.ZERO) * rest;

		skeleton.set_bone_rest(bone.id, rest);
		skeleton.reset_bone_pose(bone.id);

	# Skin binds = inverse of the global rest (bind) pose, which matches the
	# model-space vertex positions stored in the VVD.
	var skin = skeleton.create_skin_from_rest_transforms();
	skeleton.name = "skeleton";
	mesh_instance.add_child(skeleton);
	mesh_instance.set_skeleton_path("skeleton");
	mesh_instance.set_skin(skin);
	skeleton.set_owner(mesh_instance);

## Known-missing textures remapped to shipped equivalents (EP1/EP2 only ships
## a subset of the HL2 character materials). Keys/values are normalized
## lowercase material paths relative to the materials folder.
const TEXTURE_PATH_ALIASES := {
	"models/alyx/alyx_sheet": "models/alyx/alyxhunted_sheet",
	"models/alyx/alyx_sheet_skin": "models/alyx/alyxhunted_sheet",
	"models/alyx/alyx_faceandhair": "models/alyx/alyxhunted_faceandhair",
	"models/alyx/eyeball_r": "models/humans/female/eyeball_r",
	"models/alyx/eyeball_l": "models/humans/female/eyeball_l",
	# Only the blue vortigaunt recolor ships; same UV layout as the base sheet.
	"models/vortigaunt/vortigaunt_sheet": "models/vortigaunt/vortigaunt_blue",
	"models/vortigaunt/eyeball": "models/vortigaunt/eyeball_blue",

	# --- Props (EP1/EP2 only ships a subset of the HL2 prop materials) ---
	# Same van, EP1 re-export ("thrown" variant) — same paint scheme.
	"models/props_vehicles/van001a_01": "models/vehicles/vehicle_van/vanthrown001a_01",
	"models/props_vehicles/van001b_01": "models/vehicles/vehicle_van/vanthrown001a_01",
	# "Off" / alternate skin variants share the UV layout of the missing base.
	# (radio_sheet_off / lab_objects02_off VMTs exist but their VTFs don't,
	# so those two fall back to flat colors below instead.)
	"models/props_lab/recievers01": "models/props_lab/recievers01_off",
	"models/props_lab/monitor02": "models/props_lab/monitor_lost",
	"models/props_lab/monitor02b": "models/props_lab/monitor_lost",
	"models/props_c17/industrialbellbottomon01": "models/props_c17/industrialbellbottomoff01",
	"models/props_c17/door01a": "models/props_c17/door01a_skin15",
	"models/props_c17/door01a_skin2": "models/props_c17/door01a_skin15",
	"models/props_c17/door01a_skin3": "models/props_c17/door01a_skin16",
	"models/props_c17/door01a_skin4": "models/props_c17/door01a_skin15",
	"models/props_c17/door01a_skin5": "models/props_c17/door01a_skin16",
	"models/props_c17/door01a_skin6": "models/props_c17/door01a_skin15",
	"models/props_c17/door01a_skin7": "models/props_c17/door01a_skin16",
	"models/props_c17/door01a_skin8": "models/props_c17/door01a_skin15",
	"models/props_c17/door01a_skin9": "models/props_c17/door01a_skin16",
	"models/props_c17/door01a_skin10": "models/props_c17/door01a_skin15",
	"models/props_c17/door01a_skin11": "models/props_c17/door01a_skin16",
	"models/props_c17/door01a_skin12": "models/props_c17/door01a_skin15",
	"models/props_c17/door01a_skin13": "models/props_c17/door01a_skin16",
	"models/props_c17/door01a_skin14": "models/props_c17/door01a_skin15",
	# Weathered stand-ins of the same material family (rusty/painted metal,
	# concrete, junk sheets) — UVs differ but they read correctly in-game,
	# which beats flat white.
	# Mostly-uniform brush textures stand in for prop sheets whose art is
	# missing: with mismatched UVs a uniform texture still reads correctly,
	# while high-contrast sheets (planks, composites) turn into garbled stripes.
	# Green rusted metal = the HL2 dumpster's painted steel.
	"models/props_lab/dogdumpster_sheet": "metal/bunker_metalwall02a",
	"models/props_c17/oil_drum001a": "models/props_c17/canister02a",
	"models/props_c17/canister_propane01a": "models/props_c17/canister02a",
	# Green painted metal reads like the HL2 locker bank; the previous
	# nucleartestcabinet stand-in rendered near-white in game lighting.
	"models/props_c17/lockers001a": "metal/bunker_metalwall02a",
	"models/props_junk/i-beam_cluster01": "models/props_radiostation/metal_truss",
	# Hazard stripes = the road-barricade look of barricade_composite01.
	"models/props_wasteland/barricade_composite01": "metal/metal_emergencystripe01a",
	"models/props_wasteland/prison_yard001": "models/props_wasteland/fence_sheet01",
	"models/props_debris/rebar_concrete001": "models/props_debris/concretefloor030a",
	"models/props_debris/plasterwall021a": "models/props_debris/concretefloor013a",
	"models/props_citizen_tech/itemcrate_sheet": "models/items/ammocrate_items",
	# Wrecked-car clusters use the car001b_03 paint sheet; only _01 ships.
	# Same car family/UV layout, different paint — reads correctly.
	"models/props_vehicles/car001b_03": "models/props_vehicles/car001b_01",
	# walldestroyed09a's courtyard sheet is missing; concretefloor013a is the
	# uniform broken-concrete stand-in already used for its plaster sheet.
	"models/props_debris/courtyard_template001c": "models/props_debris/concretefloor013a",
	# truss02* girders -> the shipped radiostation truss sheet (same family).
	"models/props_c17/metaltruss012b": "models/props_radiostation/metal_truss",
}

## Flat-color stand-ins for small detail textures (mouth interiors, hair cards,
## eye glints) that are missing from the shipped materials. Beats rendering
## those surfaces plain white.
const TEXTURE_COLOR_FALLBACKS := [
	["glint", Color(0.05, 0.05, 0.05)],
	["pupil", Color(0.08, 0.07, 0.06)],
	["eyeball", Color(0.75, 0.72, 0.68)],
	["teeth", Color(0.78, 0.73, 0.65)],
	["tongue", Color(0.45, 0.2, 0.18)],
	["mouth", Color(0.25, 0.1, 0.09)],
	["hairbit", Color(0.1, 0.08, 0.06)],
	["hair", Color(0.12, 0.1, 0.08)],
	# Prop material families with no shipped texture at all.
	["radio_sheet", Color(0.26, 0.3, 0.24)],
	["lab_objects", Color(0.32, 0.34, 0.33)],
	["furniture", Color(0.38, 0.28, 0.18)],
	["shelf", Color(0.38, 0.28, 0.18)],
	["wood", Color(0.36, 0.26, 0.17)],
	["photo", Color(0.32, 0.27, 0.2)],
	["concrete", Color(0.55, 0.52, 0.46)],
	["plaster", Color(0.6, 0.56, 0.49)],
	["rounds", Color(0.55, 0.42, 0.2)],
	["bicycle", Color(0.2, 0.22, 0.26)],
	["stool", Color(0.32, 0.33, 0.35)],
	["ladder", Color(0.35, 0.36, 0.38)],
	["bell", Color(0.28, 0.3, 0.3)],
];

## Last-resort albedo for completely unresolvable materials. Weathered grey
## reads as bare metal/primer in the HL2 palette — flat white reads as a bug.
const TEXTURE_DEFAULT_FALLBACK_COLOR := Color(0.42, 0.41, 0.39);

func assign_materials():
	# NOTE: The materials array must stay aligned with mdl.textures —
	#       a missing material may not shift the following indices.
	var materials = [];

	for tex in mdl.textures:
		var material: Material = null;
		for dir in mdl.textureDirs:
			var path = VMFUtils.normalize_path(dir + "/" + tex.name).to_lower();

			if path in TEXTURE_PATH_ALIASES and not VMTLoader.has_material(path):
				path = TEXTURE_PATH_ALIASES[path];

			if not VMTLoader.has_material(path): continue;
			material = VMTLoader.get_material(path);
			# A VMT can load while its $basetexture VTF is missing, which
			# yields a plain white material — treat that as unresolved.
			if material and not is_material_textured(material):
				material = null;
			if material: break;

		if not material:
			material = create_texture_fallback_material(tex.name);

		materials.append(material);

	var surfaces = mesh_instance.mesh.get_surface_count();
	var skin_id = 0;
	for skin_family in mdl.skin_families:
		var skin_materials = [];
		skin_materials.resize(surfaces);

		for i in range(surfaces):
			# Surfaces map to MDL meshes; each mesh stores its material slot,
			# which the skin family remaps to a texture index.
			var slot = surface_material_slots[i] if i < surface_material_slots.size() else i;
			var material_index = skin_family[slot] if slot < skin_family.size() else slot;
			if material_index > materials.size() - 1: continue;
			skin_materials.set(i, materials[material_index]);

		mesh_instance.set_meta("skin_" + str(skin_id), skin_materials);
		skin_id += 1;

	apply_skin(mesh_instance, 0, true);

## True when a resolved material actually carries an albedo texture (or is a
## deliberately flat-colored / shader material). VMTs whose $basetexture VTF
## is missing load as default-white StandardMaterial3D — those are unusable.
static func is_material_textured(material: Material) -> bool:
	if not (material is StandardMaterial3D): return true;
	if material.albedo_texture != null: return true;
	var c: Color = material.albedo_color;
	# Non-white albedo means the VMT intentionally tinted it.
	return c.r < 0.99 or c.g < 0.99 or c.b < 0.99;

## When no VMT exists for a texture (common for character models where only
## part of the source materials shipped), try to build a basic material from
## a same-named VTF in one of the model's texture dirs.
func create_texture_fallback_material(tex_name: String) -> Material:
	for dir in mdl.textureDirs:
		var path = VMFUtils.normalize_path(dir + "/" + tex_name).to_lower();
		var texture = VTFLoader.get_texture(path);
		if not texture: continue;

		var material := StandardMaterial3D.new();
		material.albedo_texture = texture;
		material.roughness = 1.0;
		return material;

	var lower_name := tex_name.to_lower();
	for entry in TEXTURE_COLOR_FALLBACKS:
		if not lower_name.contains(entry[0]): continue;
		var material := StandardMaterial3D.new();
		material.albedo_color = entry[1];
		material.roughness = 1.0;
		return material;

	var default_material := StandardMaterial3D.new();
	default_material.albedo_color = TEXTURE_DEFAULT_FALLBACK_COLOR;
	default_material.roughness = 1.0;
	return default_material;

func generate_lods():
	if not options.get("generate_lods", false): return;
	# NOTE: LOD generation rebuilds surfaces and can corrupt bone weight data
	#       on skinned meshes, so it's limited to static props.
	if not is_static_body: return;

	var mesh = mesh_instance.mesh;
	var importer_mesh := ImporterMesh.new();

	for surface_idx in range(mesh.get_surface_count()):
		importer_mesh.add_surface(
			ArrayMesh.PRIMITIVE_TRIANGLES,
			mesh.surface_get_arrays(surface_idx),
			[], {},
			mesh.surface_get_material(surface_idx),
			'surface_' + str(surface_idx)
		);

	importer_mesh.generate_lods(60, -1, []);

	mesh = importer_mesh.get_mesh();

	if not mesh: return;

	for meta in mesh.get_meta_list():
		mesh.set_meta(meta, mesh.get_meta(meta));

	mesh_instance.set_mesh(mesh);
