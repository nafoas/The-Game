class_name NPCRagdoll
extends Node3D
## Physics ragdoll for HL2 ValveBiped characters, built at the moment of death.
##
## Source-engine deaths swap the animated character for a jointed set of rigid
## bodies (the model's .phy collision solids, one per limb, linked by
## constraints). This recreates that behaviour at runtime: eleven capsule
## RigidBody3Ds (pelvis, chest, head, upper arms, forearms, thighs, calves)
## sized from the skeleton's actual bone positions, connected with cone-twist
## joints anchored at the bone heads. Every physics tick the simulated body
## transforms are written back onto the Skeleton3D via set_bone_global_pose(),
## so the skinned mesh crumples and flops with the physics.
##
## Why not PhysicalBone3D: NPC models are spawned with a 1.27x node scale
## (restoring true HL2 size over the MDL importer's 0.02), and Godot's
## physical-bone simulation feeds that scale into the physics state, shrinking
## or distorting the bind. Free-standing world-space rigid bodies avoid the
## problem entirely; the scale is unwound once when mapping body transforms
## back into skeleton space (affine_inverse + orthonormalize).

## Same ValveBiped suffix lookup NPCAnimator uses.
const BONE_SUFFIXES: Dictionary = {
	"pelvis": "Pelvis",
	"spine1": "Spine1",
	"spine2": "Spine2",
	"neck": "Neck1",
	"head": "Head1",
	"l_upperarm": "L_UpperArm",
	"r_upperarm": "R_UpperArm",
	"l_forearm": "L_Forearm",
	"r_forearm": "R_Forearm",
	"l_hand": "L_Hand",
	"r_hand": "R_Hand",
	"l_thigh": "L_Thigh",
	"r_thigh": "R_Thigh",
	"l_calf": "L_Calf",
	"r_calf": "R_Calf",
	"l_foot": "L_Foot",
	"r_foot": "R_Foot",
}

## Rigid bodies to build, parents before children (bone sync relies on it).
## bone: driven bone. tail: capsule end (first suffix found wins; head uses a
## synthetic tail along the neck->head axis). parent: body the joint anchors
## to. extend: extra capsule length past the tail (covers hands/feet).
## swing/twist: cone-twist joint limits in degrees.
const BODY_DEFS: Array = [
	{"name": "pelvis", "bone": "pelvis", "tail": ["spine2", "spine1"], "parent": "",
		"radius": 0.15, "mass": 9.0, "extend": 0.0, "swing": 0.0, "twist": 0.0},
	{"name": "chest", "bone": "spine2", "tail": ["neck", "head"], "parent": "pelvis",
		"radius": 0.14, "mass": 9.0, "extend": 0.04, "swing": 25.0, "twist": 20.0},
	{"name": "head", "bone": "head", "tail": [], "parent": "chest",
		"radius": 0.10, "mass": 4.0, "extend": 0.0, "swing": 35.0, "twist": 45.0},
	{"name": "upperarm_l", "bone": "l_upperarm", "tail": ["l_forearm"], "parent": "chest",
		"radius": 0.055, "mass": 2.2, "extend": 0.0, "swing": 80.0, "twist": 30.0},
	{"name": "upperarm_r", "bone": "r_upperarm", "tail": ["r_forearm"], "parent": "chest",
		"radius": 0.055, "mass": 2.2, "extend": 0.0, "swing": 80.0, "twist": 30.0},
	{"name": "forearm_l", "bone": "l_forearm", "tail": ["l_hand"], "parent": "upperarm_l",
		"radius": 0.045, "mass": 1.6, "extend": 0.14, "swing": 60.0, "twist": 25.0},
	{"name": "forearm_r", "bone": "r_forearm", "tail": ["r_hand"], "parent": "upperarm_r",
		"radius": 0.045, "mass": 1.6, "extend": 0.14, "swing": 60.0, "twist": 25.0},
	{"name": "thigh_l", "bone": "l_thigh", "tail": ["l_calf"], "parent": "pelvis",
		"radius": 0.075, "mass": 4.5, "extend": 0.0, "swing": 60.0, "twist": 20.0},
	{"name": "thigh_r", "bone": "r_thigh", "tail": ["r_calf"], "parent": "pelvis",
		"radius": 0.075, "mass": 4.5, "extend": 0.0, "swing": 60.0, "twist": 20.0},
	{"name": "calf_l", "bone": "l_calf", "tail": ["l_foot"], "parent": "thigh_l",
		"radius": 0.055, "mass": 3.0, "extend": 0.12, "swing": 60.0, "twist": 15.0},
	{"name": "calf_r", "bone": "r_calf", "tail": ["r_foot"], "parent": "thigh_r",
		"radius": 0.055, "mass": 3.0, "extend": 0.12, "swing": 60.0, "twist": 15.0},
]

const HEAD_CAPSULE_LENGTH: float = 0.22
const CHEST_IMPULSE: float = 9.0    # kg*m/s along the killing shot
const PELVIS_IMPULSE: float = 4.0
const HEAD_IMPULSE: float = 1.5

var _skeleton: Skeleton3D = null
# Each entry: { body: RigidBody3D, bone: int, offset: Transform3D }
# offset maps body world transform -> bone world transform (constant).
var _entries: Array = []


## Build a ragdoll from the model's current animated pose. Returns null when
## the model has no usable ValveBiped skeleton (capsule-fallback NPCs etc.).
static func create(owner_npc: Node3D, model_node: Node3D, hit_dir: Vector3 = Vector3.ZERO) -> NPCRagdoll:
	if model_node == null:
		return null
	var skels := model_node.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return null
	var rd := NPCRagdoll.new()
	rd.name = "NPCRagdoll"
	rd.top_level = true  # bodies live in world space, ignore the NPC transform
	owner_npc.add_child(rd)
	rd.global_transform = Transform3D.IDENTITY
	if not rd._build(skels[0] as Skeleton3D, hit_dir):
		rd.queue_free()
		return null
	return rd


func _build(skeleton: Skeleton3D, hit_dir: Vector3) -> bool:
	_skeleton = skeleton

	# Map ValveBiped bones by suffix.
	var bones: Dictionary = {}
	for i in skeleton.get_bone_count():
		var bname := skeleton.get_bone_name(i)
		for key in BONE_SUFFIXES:
			if bname.ends_with(BONE_SUFFIXES[key]):
				bones[key] = i

	for required in ["pelvis", "spine2", "head", "l_upperarm", "r_upperarm", "l_thigh", "r_thigh"]:
		if not bones.has(required):
			return false

	var bodies: Dictionary = {}
	for def in BODY_DEFS:
		if not bones.has(def["bone"]):
			continue
		var bone_idx: int = bones[def["bone"]]
		var bone_world := _bone_world(bone_idx)

		# Capsule endpoints in world space, from the current animated pose.
		var head_pos := bone_world.origin
		var tail_pos := head_pos
		if def["name"] == "head":
			# No child bone: extend along the neck->head axis.
			var base_idx: int = bones.get("neck", bones["spine2"])
			var axis := head_pos - _bone_world(base_idx).origin
			if axis.length() < 0.01:
				axis = Vector3.UP
			tail_pos = head_pos + axis.normalized() * HEAD_CAPSULE_LENGTH
		else:
			var found := false
			for tail_key in def["tail"]:
				if bones.has(tail_key):
					tail_pos = _bone_world(bones[tail_key]).origin
					found = true
					break
			if not found:
				continue

		var dir := tail_pos - head_pos
		var length := dir.length()
		if length < 0.03:
			continue
		dir /= length
		var full_len: float = length + def["extend"]
		var radius: float = def["radius"]

		var body := RigidBody3D.new()
		body.name = "RB_" + def["name"]
		body.mass = def["mass"]
		body.collision_layer = 0  # corpses block nothing (rays, LOS, bullets)
		body.collision_mask = 1   # world geometry
		body.angular_damp = 1.5
		body.linear_damp = 0.25
		var col := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = radius
		capsule.height = maxf(full_len, radius * 2.1)
		col.shape = capsule
		body.add_child(col)
		add_child(body)
		# Capsule Y axis along the limb, centred between the endpoints.
		body.global_transform = Transform3D(_basis_from_y(dir), head_pos + dir * full_len * 0.5)
		bodies[def["name"]] = body

		# Joint to the parent body, anchored at the bone head, twist axis (X)
		# along the limb.
		if def["parent"] != "" and bodies.has(def["parent"]):
			var joint := ConeTwistJoint3D.new()
			joint.name = "J_" + def["name"]
			add_child(joint)
			joint.global_transform = Transform3D(_basis_from_x(dir), head_pos)
			joint.node_a = joint.get_path_to(bodies[def["parent"]])
			joint.node_b = joint.get_path_to(body)
			joint.swing_span = deg_to_rad(def["swing"])
			joint.twist_span = deg_to_rad(def["twist"])

		_entries.append({
			"body": body,
			"bone": bone_idx,
			"offset": body.global_transform.affine_inverse() * bone_world,
		})

	if not (bodies.has("pelvis") and bodies.has("chest")):
		return false

	# Knockback from the killing shot, like Source's death impulse.
	if hit_dir.length_squared() > 0.0001:
		var imp := hit_dir.normalized()
		(bodies["chest"] as RigidBody3D).apply_central_impulse(imp * CHEST_IMPULSE)
		(bodies["pelvis"] as RigidBody3D).apply_central_impulse(imp * PELVIS_IMPULSE)
		if bodies.has("head"):
			(bodies["head"] as RigidBody3D).apply_central_impulse(imp * HEAD_IMPULSE)
	return true


func _physics_process(_delta: float) -> void:
	if _skeleton == null or not is_instance_valid(_skeleton):
		set_physics_process(false)
		return
	# Write the simulated body transforms back onto the bones. Entries are
	# parent-first, so each set_bone_global_pose sees up-to-date parents.
	var to_skel := _skeleton.global_transform.affine_inverse()
	for e in _entries:
		var body: RigidBody3D = e["body"]
		var bone_world: Transform3D = body.global_transform * e["offset"]
		var pose: Transform3D = to_skel * bone_world
		pose.basis = pose.basis.orthonormalized()
		_skeleton.set_bone_global_pose(e["bone"], pose)


## Bone's current world transform, orthonormalized (the model node carries a
## uniform visual scale that must not leak into the physics bodies).
func _bone_world(bone_idx: int) -> Transform3D:
	var t := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone_idx)
	return Transform3D(t.basis.orthonormalized(), t.origin)


static func _basis_from_y(y: Vector3) -> Basis:
	var helper := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := helper.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


static func _basis_from_x(x: Vector3) -> Basis:
	var helper := Vector3.UP if absf(x.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var z := x.cross(helper).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)
