extends Node
## Attach as child of a Light3D to give it a Source-style energy flicker.
## Optionally also dims sibling mesh emissive cones via `linked_meshes`.

@export var base_energy: float = 1.5
@export var jitter: float = 0.15
@export var drop_chance: float = 0.012
@export var drop_scale: float = 0.25

var _light: Light3D = null
var _time: float = 0.0
var _drop_timer: float = 0.0
var _linked_cones: Array[GeometryInstance3D] = []


func _ready() -> void:
	_light = get_parent() as Light3D
	if _light != null:
		base_energy = _light.light_energy
	_time = randf() * 10.0


func link_cone(cone: GeometryInstance3D) -> void:
	if cone != null:
		_linked_cones.append(cone)


func _process(delta: float) -> void:
	if _light == null:
		return
	_time += delta

	var energy := base_energy * (1.0 + sin(_time * 11.0) * jitter * 0.4 + randf_range(-jitter, jitter * 0.6))

	if _drop_timer > 0.0:
		_drop_timer -= delta
		energy *= drop_scale
	elif randf() < drop_chance:
		_drop_timer = randf_range(0.04, 0.14)

	_light.light_energy = clampf(energy, 0.0, base_energy * 1.4)

	var vis_scale := _light.light_energy / maxf(base_energy, 0.01)
	for cone in _linked_cones:
		if is_instance_valid(cone):
			cone.transparency = clampf(1.0 - vis_scale, 0.0, 0.9)
