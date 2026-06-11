extends Area3D

@export var trigger_id: String = ""
@export var action: String = "complete_level"
@export var subtitle_text: String = ""
@export var subtitle_speaker: String = ""
@export var scene_path: String = ""
@export var one_shot: bool = true

var triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if triggered and one_shot:
		return

	triggered = true

	match action:
		"complete_level":
			GameManager.complete_level()
		"checkpoint":
			GameManager.checkpoint_position = body.global_position
			SubtitleManager.show_subtitle_direct("[Checkpoint]", 1.5, "")
		"subtitle":
			SubtitleManager.show_subtitle_direct(subtitle_text, 3.0, subtitle_speaker)
		"load_scene":
			if scene_path != "":
				get_tree().change_scene_to_file(scene_path)
