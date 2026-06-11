extends "res://scripts/npc/NPCBase.gd"


func _ready() -> void:
	npc_name = "HECU Commander"
	faction = "hecu"
	voice_file_prefix = "commander"
	is_friendly = true
	health = 999.0

	super._ready()

	# Override mesh color for HECU
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.5)
	if _mesh_instance != null:
		_mesh_instance.material_override = mat

	current_state = State.IDLE

	# Briefing sequence
	_start_briefing()


func _start_briefing() -> void:
	await get_tree().create_timer(1.0).timeout
	_start_talking(5.0)
	SubtitleManager.show_subtitle_direct(
		"Listen up, soldier. Biden was spotted three blocks north. Move out — and don't come back without confirmation.",
		5.0,
		"Commander"
	)
	var brief_path := "res://voice/commander/briefing_01.mp3"
	if ResourceLoader.exists(brief_path):
		var stream := ResourceLoader.load(brief_path) as AudioStream
		if stream != null and _audio != null:
			_audio.stream = stream
			_audio.play()

	await get_tree().create_timer(6.0).timeout
	_start_talking(4.0)
	SubtitleManager.show_subtitle_direct(
		"Intel confirms resistance fighters between here and the target. Engage at will.",
		4.0,
		"Commander"
	)
	var brief2_path := "res://voice/commander/briefing_02.mp3"
	if ResourceLoader.exists(brief2_path):
		var stream2 := ResourceLoader.load(brief2_path) as AudioStream
		if stream2 != null and _audio != null:
			_audio.stream = stream2
			_audio.play()


func _physics_process(delta: float) -> void:
	# HECU Commander stays IDLE, never attacks, just faces player
	if current_state == State.DEAD:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	velocity.x = 0.0
	velocity.z = 0.0

	if player_ref != null:
		_face_target(player_ref.global_position, delta)

	move_and_slide()


func take_damage(amount: float, from_direction: Vector3 = Vector3.ZERO) -> void:
	# Immortal — ignore damage
	pass
