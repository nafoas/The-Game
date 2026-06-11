extends Area3D

@export var weapon_type: String = "mp5"
@export var ammo_count: int = 30

const PICKUP_MODELS := {
	"pistol": {"path": "res://models/weapons/w_alyx_gun.mdl", "scale": 1.6, "y": 0.12},
	"mp5": {"path": "res://models/weapons/w_combine_sniper.mdl", "scale": 1.1, "y": 0.05},
}

var _spin_root: Node3D = null
var _rotation_speed: float = 1.2
var _bob_timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_visual()
	_bob_timer = randf() * TAU


func _build_visual() -> void:
	_spin_root = Node3D.new()
	_spin_root.name = "SpinRoot"
	add_child(_spin_root)

	var def: Dictionary = PICKUP_MODELS.get(weapon_type, {})
	var model: Node3D = null
	if def.has("path"):
		model = SourceMaterials.spawn_model(_spin_root, def["path"],
			Vector3(0.0, def.get("y", 0.0), 0.0), 0.0, def.get("scale", 1.27), true)

	if model == null:
		# Fallback: simple gun-shaped box
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 0.16, 0.45)
		mi.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.2, 0.22)
		mat.metallic = 0.5
		mat.roughness = 0.4
		mi.material_override = mat
		_spin_root.add_child(mi)

	# Soft highlight so pickups read at a glance (subtle HL2 item shimmer)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.3)
	glow.light_energy = 0.45
	glow.omni_range = 1.4
	glow.position = Vector3(0, 0.15, 0)
	add_child(glow)

	var cshape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.7, 0.5, 0.8)
	cshape.shape = box_shape
	add_child(cshape)


func _process(delta: float) -> void:
	if _spin_root != null:
		_spin_root.rotation.y += _rotation_speed * delta
		_bob_timer += delta
		_spin_root.position.y = sin(_bob_timer * 2.0) * 0.05


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	# Try to find WeaponManager on player
	var weapon_manager: Node = null
	var head := body.get_node_or_null("Head")
	if head != null:
		weapon_manager = head.get_node_or_null("WeaponManager")
	if weapon_manager == null:
		weapon_manager = body.get_node_or_null("WeaponManager")

	if weapon_manager != null and weapon_manager.has_method("add_weapon"):
		weapon_manager.add_weapon(weapon_type, ammo_count)

	SubtitleManager.show_subtitle_direct("Picked up " + weapon_type.to_upper(), 2.0, "")

	AudioManager.play_sfx_at("res://sounds/items/item_battery_pickup.wav", global_position, -4.0)

	queue_free()
