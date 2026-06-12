extends SceneTree
## Temp diagnostic: dump MDL/VVD/VTX internals for character models.
## godot --headless --script res://probe_mdl.gd

const PATHS := [
	"res://models/barney.mdl",
	"res://models/alyx.mdl",
	"res://models/eli.mdl",
	"res://models/gman.mdl",
	"res://models/kleiner.mdl",
	"res://models/vortigaunt.mdl",
	"res://models/props_c17/chair_stool01a.mdl",
]

func _initialize() -> void:
	for path in PATHS:
		probe(path)
	quit(0)

func probe(path: String) -> void:
	print("\n=========== ", path)
	var mdl := MDLReader.new(path)
	if mdl.header == null:
		print("  FAILED to read header")
		return
	print("  version=%d flags=%x static=%s bones=%d textures=%d dirs=%s skinfam=%d" % [
		mdl.header.version, mdl.header.flags, str(mdl.is_static_prop),
		mdl.bones.size(), mdl.textures.size(), str(mdl.textureDirs), mdl.skin_families.size()])
	for t in mdl.textures:
		var found := []
		for dir in mdl.textureDirs:
			var p = VMFUtils.normalize_path(dir + "/" + t.name)
			if VMTLoader.has_material(p.to_lower()):
				found.append(p)
		print("  tex '%s' -> %s" % [t.name, "FOUND " + str(found) if found.size() else "MISSING"])
	print("  skin_families[0]=%s" % [str(mdl.skin_families[0]) if mdl.skin_families.size() else "none"])

	var vvd := VVDReader.new(path.replace(".mdl", ".vvd"))
	if vvd.header == null:
		print("  no VVD")
		return
	print("  vvd: lods=%d verts_lod0=%d fixups=%d" % [vvd.header.num_lods, vvd.header.num_lods_vertexes[0], vvd.fixups.size()])
	# bone weight stats
	var max_bone := 0
	var junk_weight := 0
	var bad_sum := 0
	var n := mini(vvd.vertices.size(), 100000)
	for i in n:
		var bw = vvd.vertices[i].bone_weight
		var sum := 0.0
		for j in bw.num_bones:
			sum += bw.weight[j]
			max_bone = maxi(max_bone, bw.bone[j])
		for j in range(bw.num_bones, 3):
			if absf(bw.weight[j]) > 0.0001:
				junk_weight += 1
				break
		if absf(sum - 1.0) > 0.01:
			bad_sum += 1
	print("  weights: max_bone_used=%d junk_weight_verts=%d/%d bad_sum=%d" % [max_bone, junk_weight, n, bad_sum])

	var vtx := VTXReader.new(path.replace(".mdl", ".vtx"), mdl.header.version)
	if vtx.header == null:
		print("  no VTX")
		return
	var bp_i := 0
	for bp in vtx.body_parts:
		var m_i := 0
		for model in bp.models:
			var lod = model.lods[0]
			var mesh_i := 0
			for mesh in lod.meshes:
				var sgs := []
				for sg in mesh.strip_groups:
					sgs.append("v%d/i%d/f%x" % [sg.num_verts, sg.num_indices, sg.flags])
				var mdl_mesh = mdl.body_parts[bp_i].models[m_i].meshes[mesh_i]
				print("  bp%d model%d mesh%d mat_slot=%d strip_groups=%s" % [bp_i, m_i, mesh_i, mdl_mesh.material, str(sgs)])
				mesh_i += 1
			m_i += 1
		bp_i += 1
	# body part model names
	for bp in mdl.body_parts:
		var names := []
		for m in bp.models:
			names.append(m.name + "(v" + str(m.num_verts) + " @" + str(m.vert_index) + ")")
		print("  mdl bodypart '%s' models=%s" % [bp.name, str(names)])
