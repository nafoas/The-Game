extends Area3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	GameManager.checkpoint_position = global_position + Vector3(0, 1, 0)
	SubtitleManager.show_subtitle_direct("[Checkpoint]", 1.5, "")
