extends Area3D

@export var weapon_type: String = "mp5"
@export var ammo_count: int = 30

var _mesh_instance: MeshInstance3D = null
var _rotation_speed: float = 1.2


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_visual()


func _build_visual() -> void:
	_mesh_instance = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.1, 0.5)
	_mesh_instance.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.5, 0.0)
	mat.emission_energy_multiplier = 0.5
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)

	# Collision for Area3D
	var cshape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.5, 0.3, 0.7)
	cshape.shape = box_shape
	add_child(cshape)


func _process(delta: float) -> void:
	if _mesh_instance != null:
		_mesh_instance.rotation.y += _rotation_speed * delta


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

	var pickup_path := "res://sounds/items/item_battery_pickup.wav"
	if ResourceLoader.exists(pickup_path):
		AudioManager.play_sfx_at(pickup_path, global_position)

	queue_free()
