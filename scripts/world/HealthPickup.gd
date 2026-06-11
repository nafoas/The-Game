extends Area3D

@export var heal_amount: float = 25.0

var _mesh_instance: MeshInstance3D = null
var _bob_timer: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_visual()
	_base_y = position.y


func _build_visual() -> void:
	_mesh_instance = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	_mesh_instance.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.0, 0.0)
	mat.emission_energy_multiplier = 0.5
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)

	var cshape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.5, 0.5, 0.5)
	cshape.shape = box_shape
	add_child(cshape)


func _process(delta: float) -> void:
	_bob_timer += delta
	position.y = _base_y + sin(_bob_timer * 2.0) * 0.1


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	GameManager.player_health = min(GameManager.player_health + heal_amount, 100.0)

	# Emit health changed signal if it exists
	if GameManager.has_signal("health_changed"):
		GameManager.emit_signal("health_changed", GameManager.player_health)

	SubtitleManager.show_subtitle_direct("Health +" + str(int(heal_amount)), 1.5, "")

	var sound_path := "res://sounds/items/medshot4.wav"
	if ResourceLoader.exists(sound_path):
		AudioManager.play_sfx_at(sound_path, global_position)

	queue_free()
