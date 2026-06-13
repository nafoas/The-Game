class_name NPCAnimator
extends Node
## Procedural skeletal animation for imported HL2 ValveBiped characters.
##
## The GodotVMF MDL importer brings models in at their bind pose (A-pose) with
## no sequence playback, so NPCs looked like mannequins. This node drives the
## Skeleton3D bones directly each frame:
##  - IDLE:       relaxed stance (arms at sides, bent elbows) + breathing sway
##  - WALK:       leg/arm swing cycle driven by actual horizontal velocity
##  - COMBAT:     two-handed low-ready pose, slight forward lean
##  - COMBAT_AIM: gun raised — both upper arms lifted forward, forearms angled
##                toward the enemy (set_aim_pitch tracks them vertically)
##  - CROUCH:     deep duck (hiding behind cover)
##  - LEAN:       leaning a shoulder against a wall (actbusy-style idle)
##  - DEAD:       limp slump (body fall itself is handled by the owner)
##
## All rotations are computed in skeleton (model) space using the bind-pose
## global transforms, then converted into each bone's local pose. Model space
## (verified via probe on barney.mdl): +Y up, +Z forward, +X = model's left.

enum Pose { IDLE, WALK, COMBAT, COMBAT_AIM, CROUCH, LEAN, DEAD }

const WALK_CYCLE_SPEED: float = 3.6   # phase radians per metre travelled (approx)
const BLEND_SPEED: float = 6.0        # pose-space blend rate (1/s)
const FAST_BLEND_SPEED: float = 24.0  # blend rate for fast-oscillating channels

## Channels that carry the walk-cycle oscillation. These must blend much
## faster than static pose channels: a 6/s low-pass against the ~12.6 rad/s
## swing sinusoid attenuates it to ~43% amplitude (legs barely moved). At
## 24/s the cycle keeps ~88% of its amplitude while pose switches stay smooth.
const FAST_CHANNELS: Dictionary = {
	"thigh_l": true, "thigh_r": true,
	"calf_l": true, "calf_r": true,
	"foot_l": true, "foot_r": true,
	"arm_fwd_l": true, "arm_fwd_r": true,
	"spine_sway": true, "pelvis_drop": true,
}

const FLINCH_TIME: float = 0.35       # damage stagger duration (s)

var _skeleton: Skeleton3D = null
var _pose: Pose = Pose.IDLE
var _speed: float = 0.0               # horizontal speed (m/s), set by owner
var _phase: float = 0.0               # walk cycle phase
var _time: float = 0.0
var _idle_seed: float = 0.0           # desync idle breathing between NPCs
var _flinch_timer: float = 0.0        # >0 while staggering from a hit
var _flinch_side: float = 1.0         # randomized recoil side
var _aim_pitch: float = 0.0           # radians; >0 = aim up (COMBAT_AIM arms)
var _lean_side: float = 1.0           # which shoulder touches the wall in LEAN

# Cached per-bone data
var _bones: Dictionary = {}           # short name -> bone idx
var _body_node: Node3D = null                 # model root (drop/roll target)
var _body_base_pos: Vector3 = Vector3.ZERO    # model root rest position
var _body_base_basis: Basis = Basis.IDENTITY  # model root rest basis
var _rest_quat: Dictionary = {}       # bone idx -> rest rotation (Quaternion)
var _parent_global_inv: Dictionary = {}  # bone idx -> parent global rest basis inverse
var _parent_global: Dictionary = {}      # bone idx -> parent global rest basis

# Blended angle channels (so state switches don't snap)
var _current: Dictionary = {}
var _target: Dictionary = {}

# Bones we animate, looked up by ValveBiped suffix.
const BONE_SUFFIXES: Dictionary = {
	"pelvis": "Pelvis",
	"spine": "Spine",
	"spine1": "Spine1",
	"spine2": "Spine2",
	"spine4": "Spine4",
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


## Attach an animator to a spawned MDL model node. Returns null when the model
## has no recognisable ValveBiped skeleton (e.g. props or fallback capsules).
static func attach(model_node: Node3D) -> NPCAnimator:
	if model_node == null:
		return null
	var skels := model_node.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return null
	var anim := NPCAnimator.new()
	anim.name = "NPCAnimator"
	if not anim._setup(skels[0] as Skeleton3D):
		anim.free()
		return null
	anim._body_node = model_node
	anim._body_base_pos = model_node.position
	anim._body_base_basis = model_node.basis
	model_node.add_child(anim)
	return anim


func _setup(skeleton: Skeleton3D) -> bool:
	_skeleton = skeleton
	_idle_seed = randf() * TAU

	# Map ValveBiped bones by suffix
	var count := skeleton.get_bone_count()
	for i in count:
		var bname := skeleton.get_bone_name(i)
		for key in BONE_SUFFIXES:
			if bname.ends_with(BONE_SUFFIXES[key]):
				_bones[key] = i

	# Need at least arms + legs to be useful
	if not (_bones.has("l_upperarm") and _bones.has("r_upperarm")
			and _bones.has("l_thigh") and _bones.has("r_thigh")):
		return false

	# Global rest transforms (for converting model-space rotations to local)
	var globals: Array[Basis] = []
	globals.resize(count)
	for i in count:
		var parent := skeleton.get_bone_parent(i)
		var rest := skeleton.get_bone_rest(i)
		globals[i] = rest.basis if parent == -1 else globals[parent] * rest.basis

	for key in _bones:
		var idx: int = _bones[key]
		_rest_quat[idx] = skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()
		var parent := skeleton.get_bone_parent(idx)
		var pg := Basis.IDENTITY if parent == -1 else globals[parent]
		_parent_global[idx] = pg
		_parent_global_inv[idx] = pg.inverse()
	return true


func set_pose(p: Pose) -> void:
	_pose = p


func set_speed(speed: float) -> void:
	_speed = speed


## Vertical aim angle for COMBAT_AIM (radians; positive aims up). The owner
## feeds the pitch toward its enemy so the raised arms actually track them.
func set_aim_pitch(pitch: float) -> void:
	_aim_pitch = clampf(pitch, deg_to_rad(-45.0), deg_to_rad(45.0))


## Pick which shoulder rests on the wall for the LEAN pose. Probe-verified:
## +1 tips the body toward the CHARACTER'S RIGHT shoulder.
func set_lean_side(side: float) -> void:
	_lean_side = signf(side) if absf(side) > 0.01 else 1.0


## Brief damage stagger: torso/head recoil that decays over FLINCH_TIME.
## Applied additively after the channel blender so it reads instantly.
func flinch() -> void:
	_flinch_timer = FLINCH_TIME
	_flinch_side = 1.0 if randf() < 0.5 else -1.0


## Skeleton access for weapon attachments (right-hand bone etc.).
func get_skeleton() -> Skeleton3D:
	return _skeleton


func get_bone_idx(key: String) -> int:
	return _bones.get(key, -1)


func _process(delta: float) -> void:
	if _skeleton == null or not is_instance_valid(_skeleton):
		return
	_time += delta
	_phase += _speed * WALK_CYCLE_SPEED * delta
	_flinch_timer = maxf(0.0, _flinch_timer - delta)

	_compute_target_pose()
	_blend_channels(delta)
	_apply_pose()


# ---------------------------------------------------------------------------
# Pose targets — every channel is an angle in radians
# ---------------------------------------------------------------------------

func _compute_target_pose() -> void:
	var t := _time + _idle_seed
	var breathe := sin(t * 1.7)            # slow breathing oscillator
	var moving := _speed > 0.3
	var walk_blend: float = clampf(_speed / 2.0, 0.0, 1.0)
	var swing := sin(_phase) * walk_blend  # leg swing oscillator

	# Defaults: relaxed idle stance
	var arm_down := deg_to_rad(28.0)       # lower arms from A-pose to sides
	var arm_fwd_l := 0.0                   # upper-arm forward swing
	var arm_fwd_r := 0.0
	var arm_in := 0.0                      # pull arms inward/forward (aiming)
	var elbow := deg_to_rad(14.0)          # slight natural elbow bend
	var hand_curl := deg_to_rad(20.0)      # relaxed finger-ward hand curl
	var spine_lean := deg_to_rad(2.0 + breathe * 1.0)  # subtle breathing
	var spine_sway := deg_to_rad(sin(t * 0.9) * 1.5)   # slow weight shift
	var head_pitch := deg_to_rad(sin(t * 0.55) * 2.0)
	var head_yaw := deg_to_rad(sin(t * 0.4 + 1.3) * 4.0)
	var thigh_l := 0.0
	var thigh_r := 0.0
	var calf_l := deg_to_rad(2.0)
	var calf_r := deg_to_rad(2.0)
	var foot_l := 0.0
	var foot_r := 0.0
	var pelvis_drop := 0.0
	var pelvis_roll := 0.0

	match _pose:
		Pose.WALK:
			if moving:
				# HL2 walk/jog: big scissoring stride must read in a single
				# still frame, so the hips swing wide (~±36 deg target,
				# ~±32 deg effective after the fast blend).
				thigh_l = swing * deg_to_rad(36.0)
				thigh_r = -swing * deg_to_rad(36.0)
				# Knee bends as the leg comes back/under
				calf_l = deg_to_rad(8.0) + maxf(0.0, -sin(_phase + 0.7)) * deg_to_rad(46.0) * walk_blend
				calf_r = deg_to_rad(8.0) + maxf(0.0, sin(_phase + 0.7)) * deg_to_rad(46.0) * walk_blend
				foot_l = -thigh_l * 0.4
				foot_r = -thigh_r * 0.4
				# Arms counter-swing the legs
				arm_fwd_l = -swing * deg_to_rad(24.0)
				arm_fwd_r = swing * deg_to_rad(24.0)
				arm_down = deg_to_rad(32.0)
				elbow = deg_to_rad(26.0)
				spine_lean = deg_to_rad(6.0)
				spine_sway = deg_to_rad(sin(_phase) * 4.0)
				head_pitch = 0.0
				head_yaw = 0.0
				pelvis_drop = absf(sin(_phase)) * -0.035
		Pose.COMBAT:
			# Two-handed ready pose: arms forward and inward, elbows bent,
			# slight crouch + forward lean. Legs keep walking if moving.
			arm_down = deg_to_rad(18.0)
			arm_fwd_l = deg_to_rad(48.0)
			arm_fwd_r = deg_to_rad(54.0)
			arm_in = deg_to_rad(38.0)
			elbow = deg_to_rad(42.0)
			hand_curl = deg_to_rad(30.0)
			spine_lean = deg_to_rad(7.0)
			spine_sway = deg_to_rad(breathe * 0.8)
			head_pitch = 0.0
			head_yaw = 0.0
			if moving:
				thigh_l = swing * deg_to_rad(32.0)
				thigh_r = -swing * deg_to_rad(32.0)
				calf_l = deg_to_rad(10.0) + maxf(0.0, -sin(_phase + 0.7)) * deg_to_rad(40.0) * walk_blend
				calf_r = deg_to_rad(10.0) + maxf(0.0, sin(_phase + 0.7)) * deg_to_rad(40.0) * walk_blend
				foot_l = -thigh_l * 0.4
				foot_r = -thigh_r * 0.4
			else:
				# Combat crouch
				thigh_l = deg_to_rad(-14.0)
				thigh_r = deg_to_rad(-10.0)
				calf_l = deg_to_rad(20.0)
				calf_r = deg_to_rad(16.0)
				foot_l = deg_to_rad(-6.0)
				foot_r = deg_to_rad(-6.0)
				pelvis_drop = -0.05
		Pose.COMBAT_AIM:
			# Gun raised and ON TARGET: both upper arms lifted well forward,
			# forearms angled in toward the enemy, hands meeting around the
			# weapon. _aim_pitch rides on the arm-forward channels so the
			# muzzle visibly tracks the target up/down.
			arm_down = deg_to_rad(6.0)
			arm_fwd_l = deg_to_rad(64.0) + _aim_pitch
			arm_fwd_r = deg_to_rad(74.0) + _aim_pitch
			arm_in = deg_to_rad(46.0)
			elbow = deg_to_rad(30.0)
			hand_curl = deg_to_rad(26.0)
			spine_lean = deg_to_rad(9.0)
			spine_sway = deg_to_rad(breathe * 0.6)
			head_pitch = -_aim_pitch * 0.4
			head_yaw = 0.0
			if moving:
				thigh_l = swing * deg_to_rad(32.0)
				thigh_r = -swing * deg_to_rad(32.0)
				calf_l = deg_to_rad(10.0) + maxf(0.0, -sin(_phase + 0.7)) * deg_to_rad(40.0) * walk_blend
				calf_r = deg_to_rad(10.0) + maxf(0.0, sin(_phase + 0.7)) * deg_to_rad(40.0) * walk_blend
				foot_l = -thigh_l * 0.4
				foot_r = -thigh_r * 0.4
			else:
				# HL2 firing stance: knees bent in a half-crouch
				thigh_l = deg_to_rad(-18.0)
				thigh_r = deg_to_rad(-12.0)
				calf_l = deg_to_rad(26.0)
				calf_r = deg_to_rad(20.0)
				foot_l = deg_to_rad(-8.0)
				foot_r = deg_to_rad(-8.0)
				pelvis_drop = -0.07
		Pose.CROUCH:
			# Ducked low behind cover: deep knee bend, hunched spine, weapon
			# pulled in tight against the chest.
			arm_down = deg_to_rad(14.0)
			arm_fwd_l = deg_to_rad(40.0)
			arm_fwd_r = deg_to_rad(46.0)
			arm_in = deg_to_rad(40.0)
			elbow = deg_to_rad(70.0)
			hand_curl = deg_to_rad(30.0)
			spine_lean = deg_to_rad(24.0)
			spine_sway = deg_to_rad(breathe * 0.6)
			head_pitch = deg_to_rad(-10.0)  # eyes up over the cover lip
			head_yaw = 0.0
			# Body sinks (skeleton drop) while the thighs come up forward and
			# the knees fold back, keeping the feet roughly underneath.
			thigh_l = deg_to_rad(64.0)
			thigh_r = deg_to_rad(56.0)
			calf_l = deg_to_rad(98.0)
			calf_r = deg_to_rad(88.0)
			foot_l = deg_to_rad(-34.0)
			foot_r = deg_to_rad(-30.0)
			pelvis_drop = -0.5
		Pose.LEAN:
			# actbusy ACT_BUSY_LEAN: shoulder against the wall, ankles crossed,
			# arms hanging relaxed. _lean_side picks the wall shoulder.
			var s := _lean_side
			arm_down = deg_to_rad(32.0)
			arm_fwd_l = deg_to_rad(4.0)
			arm_fwd_r = deg_to_rad(4.0)
			elbow = deg_to_rad(18.0)
			hand_curl = deg_to_rad(24.0)
			spine_lean = deg_to_rad(3.0 + breathe * 0.8)
			spine_sway = deg_to_rad(-6.0 * s)
			head_yaw = deg_to_rad(sin(t * 0.35) * 8.0 - 6.0 * s)
			head_pitch = deg_to_rad(sin(t * 0.5) * 2.5)
			pelvis_roll = deg_to_rad(12.0) * s
			pelvis_drop = -0.02
			# Wall-side leg straight and loaded; free leg crossed over slack
			thigh_l = deg_to_rad(-4.0 if s > 0.0 else 7.0)
			thigh_r = deg_to_rad(7.0 if s > 0.0 else -4.0)
			calf_l = deg_to_rad(3.0 if s > 0.0 else 16.0)
			calf_r = deg_to_rad(16.0 if s > 0.0 else 3.0)
		Pose.DEAD:
			# Limp: everything droops; the owner tweens the body over.
			arm_down = deg_to_rad(40.0)
			arm_fwd_l = deg_to_rad(8.0)
			arm_fwd_r = deg_to_rad(12.0)
			elbow = deg_to_rad(10.0)
			hand_curl = deg_to_rad(35.0)
			spine_lean = deg_to_rad(18.0)
			spine_sway = deg_to_rad(6.0)
			head_pitch = deg_to_rad(28.0)
			head_yaw = deg_to_rad(15.0)
			thigh_l = deg_to_rad(-6.0)
			thigh_r = deg_to_rad(4.0)
			calf_l = deg_to_rad(14.0)
			calf_r = deg_to_rad(8.0)
		_:
			pass  # IDLE uses the defaults above

	_target = {
		"arm_down": arm_down, "arm_in": arm_in,
		"arm_fwd_l": arm_fwd_l, "arm_fwd_r": arm_fwd_r,
		"elbow": elbow, "hand_curl": hand_curl,
		"spine_lean": spine_lean, "spine_sway": spine_sway,
		"head_pitch": head_pitch, "head_yaw": head_yaw,
		"thigh_l": thigh_l, "thigh_r": thigh_r,
		"calf_l": calf_l, "calf_r": calf_r,
		"foot_l": foot_l, "foot_r": foot_r,
		"pelvis_drop": pelvis_drop, "pelvis_roll": pelvis_roll,
	}


func _blend_channels(delta: float) -> void:
	var w_slow: float = clampf(BLEND_SPEED * delta, 0.0, 1.0)
	var w_fast: float = clampf(FAST_BLEND_SPEED * delta, 0.0, 1.0)
	for key in _target:
		var cur: float = _current.get(key, 0.0)
		var w: float = w_fast if FAST_CHANNELS.has(key) else w_slow
		_current[key] = lerpf(cur, _target[key], w)


# ---------------------------------------------------------------------------
# Apply: model-space rotations -> local bone poses
# Model space: +Y up, +Z forward, +X model-left.
# ---------------------------------------------------------------------------

func _apply_pose() -> void:
	var c := _current

	# Damage flinch: additive (bypasses the blender — must snap on instantly).
	# Torso whips back and to one side, head snaps back, then decays.
	var flinch_amt := 0.0
	if _flinch_timer > 0.0:
		flinch_amt = _flinch_timer / FLINCH_TIME

	# Whole-body drop (crouch / walk bob) and roll (wall lean) are applied to
	# the model root node: bone-position offsets don't survive the Source axis
	# conventions, but the node transform always works. Pivot = feet (origin).
	if _body_node != null and is_instance_valid(_body_node):
		_body_node.position = _body_base_pos + Vector3(0, c["pelvis_drop"], 0)
		if absf(c["pelvis_roll"]) > 0.0005:
			_body_node.basis = Basis(Vector3(0, 0, 1), c["pelvis_roll"]) * _body_base_basis
		else:
			_body_node.basis = _body_base_basis

	# Spine: lean forward (about +X by +angle moves chest toward +Z) and sway
	var lean := Quaternion(Vector3(1, 0, 0),
		c["spine_lean"] * 0.5 - flinch_amt * deg_to_rad(20.0) * 0.5)
	var sway := Quaternion(Vector3(0, 0, 1),
		c["spine_sway"] * 0.5 + flinch_amt * _flinch_side * deg_to_rad(11.0) * 0.5)
	for sb in ["spine1", "spine2"]:
		if _bones.has(sb):
			_set_bone(_bones[sb], sway * lean)

	# Head/neck (positive pitch = nod forward/down)
	if _bones.has("head"):
		_set_bone(_bones["head"],
			Quaternion(Vector3(0, 1, 0), c["head_yaw"] + flinch_amt * _flinch_side * deg_to_rad(10.0))
			* Quaternion(Vector3(1, 0, 0), c["head_pitch"] - flinch_amt * deg_to_rad(16.0)))

	# Arms. Lowering: rotate about +Z — left arm (+X side) by -angle, right by +angle.
	# Forward swing: rotate about +X by -angle (moves arm toward +Z).
	# Inward pull (aiming): about +Y — left arm by -angle, right by +angle.
	if _bones.has("l_upperarm"):
		_set_bone(_bones["l_upperarm"],
			Quaternion(Vector3(0, 1, 0), -c["arm_in"])
			* Quaternion(Vector3(1, 0, 0), -c["arm_fwd_l"])
			* Quaternion(Vector3(0, 0, 1), -c["arm_down"]))
	if _bones.has("r_upperarm"):
		_set_bone(_bones["r_upperarm"],
			Quaternion(Vector3(0, 1, 0), c["arm_in"])
			* Quaternion(Vector3(1, 0, 0), -c["arm_fwd_r"])
			* Quaternion(Vector3(0, 0, 1), c["arm_down"]))

	# Elbows bend forward (toward +Z): about +X by -angle
	var elbow_q := Quaternion(Vector3(1, 0, 0), -c["elbow"])
	if _bones.has("l_forearm"):
		_set_bone(_bones["l_forearm"], elbow_q)
	if _bones.has("r_forearm"):
		_set_bone(_bones["r_forearm"], elbow_q)

	# Hands: relaxed curl inward (about +Z toward the body)
	if _bones.has("l_hand"):
		_set_bone(_bones["l_hand"], Quaternion(Vector3(0, 0, 1), c["hand_curl"]))
	if _bones.has("r_hand"):
		_set_bone(_bones["r_hand"], Quaternion(Vector3(0, 0, 1), -c["hand_curl"]))

	# Legs. Thigh forward swing: positive = leg forward (toward +Z) = about +X by -angle.
	if _bones.has("l_thigh"):
		_set_bone(_bones["l_thigh"], Quaternion(Vector3(1, 0, 0), -c["thigh_l"]))
	if _bones.has("r_thigh"):
		_set_bone(_bones["r_thigh"], Quaternion(Vector3(1, 0, 0), -c["thigh_r"]))

	# Knees only bend backward: about +X by +angle
	if _bones.has("l_calf"):
		_set_bone(_bones["l_calf"], Quaternion(Vector3(1, 0, 0), c["calf_l"]))
	if _bones.has("r_calf"):
		_set_bone(_bones["r_calf"], Quaternion(Vector3(1, 0, 0), c["calf_r"]))

	# Feet: counter-rotate to stay near level
	if _bones.has("l_foot"):
		_set_bone(_bones["l_foot"], Quaternion(Vector3(1, 0, 0), -c["foot_l"]))
	if _bones.has("r_foot"):
		_set_bone(_bones["r_foot"], Quaternion(Vector3(1, 0, 0), -c["foot_r"]))


## Apply a model-space rotation offset to a bone on top of its rest pose.
func _set_bone(idx: int, model_offset: Quaternion) -> void:
	var pg_inv: Basis = _parent_global_inv[idx]
	var pg: Basis = _parent_global[idx]
	var local_offset := (pg_inv * Basis(model_offset) * pg).get_rotation_quaternion()
	_skeleton.set_bone_pose_rotation(idx, local_offset * _rest_quat[idx])
