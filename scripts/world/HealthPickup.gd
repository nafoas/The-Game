extends Area3D

@export var heal_amount: float = 25.0

var _visual_root: Node3D = null
var _bob_timer: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_visual()
	_base_y = position.y
	_bob_timer = randf() * TAU


func _build_visual() -> void:
	# HL2-style medkit: white case with red cross + soft red glow.
	_visual_root = Node3D.new()
	_visual_root.name = "MedkitVisual"
	add_child(_visual_root)

	var case_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.36, 0.16, 0.28)
	case_mesh.mesh = box
	var case_mat := StandardMaterial3D.new()
	case_mat.albedo_color = Color(0.85, 0.86, 0.88)
	case_mat.roughness = 0.5
	case_mesh.material_override = case_mat
	_visual_root.add_child(case_mesh)

	var cross_mat := StandardMaterial3D.new()
	cross_mat.albedo_color = Color(0.75, 0.08, 0.06)
	cross_mat.emission_enabled = true
	cross_mat.emission = Color(0.6, 0.05, 0.04)
	cross_mat.emission_energy_multiplier = 0.6
	cross_mat.roughness = 0.5

	for cross_size in [Vector3(0.2, 0.012, 0.07), Vector3(0.07, 0.012, 0.2)]:
		var bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = cross_size
		bar.mesh = bar_mesh
		bar.material_override = cross_mat
		bar.position = Vector3(0.0, 0.085, 0.0)
		_visual_root.add_child(bar)

	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.25, 0.2)
	glow.light_energy = 0.4
	glow.omni_range = 1.2
	glow.position = Vector3(0, 0.2, 0)
	add_child(glow)

	var cshape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.6, 0.5, 0.6)
	cshape.shape = box_shape
	add_child(cshape)


func _process(delta: float) -> void:
	_bob_timer += delta
	position.y = _base_y + sin(_bob_timer * 2.0) * 0.08
	if _visual_root != null:
		_visual_root.rotation.y += 0.9 * delta


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	GameManager.player_health = min(GameManager.player_health + heal_amount, 100.0)

	# Emit health changed signal if it exists
	if GameManager.has_signal("health_changed"):
		GameManager.emit_signal("health_changed", GameManager.player_health)

	SubtitleManager.show_subtitle_direct("Health +" + str(int(heal_amount)), 1.5, "")

	AudioManager.play_sfx_at("res://sounds/items/medshot4.wav", global_position, -4.0)

	queue_free()
