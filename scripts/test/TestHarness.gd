extends Node
## Automated playthrough harness. Temporarily registered as an autoload for
## headless testing; drives the game through menu -> cutscene -> level ->
## end-of-demo and saves screenshots at each stage. Not shipped with the game.

const SHOT_DIR := "/tmp/shots"

var _shot_idx := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_run.call_deferred()


func _run() -> void:
	await _wait(3.0)
	await _shot("01_main_menu")

	print("HARNESS: starting new game")
	GameManager.new_game()
	await _wait(5.0)
	await _shot("02_cutscene_early")
	await _wait(8.0)
	await _shot("03_cutscene_mid")

	print("HARNESS: waiting for cutscene end")
	var deadline := Time.get_ticks_msec() + 40000
	while not _current_scene_is_level() and Time.get_ticks_msec() < deadline:
		await _wait(1.0)
	if not _current_scene_is_level():
		print("HARNESS: cutscene never ended, forcing level load")
		get_tree().change_scene_to_file("res://scenes/level/level_01.tscn")
		await _wait(2.0)

	await _wait(3.0)
	var player := _find_player()
	if player == null:
		print("HARNESS: FATAL no player found")
		get_tree().quit(1)
		return

	await _shot("04_level_spawn")

	# Walk forward through the staging area using real input.
	print("HARNESS: walking forward")
	Input.action_press("move_forward")
	await _wait(2.5)
	Input.action_release("move_forward")
	await _shot("05_staging_area")

	# Street A: teleport partway down the street, look around.
	await _teleport(player, Vector3(0, 1.2, 25), 180.0)
	await _shot("06_street_a")

	# Find nearest NPC and face it for a combat shot.
	var npc := _find_nearest_npc(player)
	if npc:
		print("HARNESS: engaging NPC at ", npc.global_position)
		_face_point(player, npc.global_position)
		await _wait(0.5)
		Input.action_press("fire")
		await _wait(0.15)
		await _shot("07_combat_firing")
		await _wait(1.0)
		Input.action_release("fire")
		await _shot("08_combat_aftermath")
	else:
		print("HARNESS: no NPC found for combat test")

	# Alley.
	await _teleport(player, Vector3(-8, 1.2, 50), 90.0)
	await _shot("09_alley")

	# Plaza.
	await _teleport(player, Vector3(0, 1.2, 70), 180.0)
	await _shot("10_plaza")

	# Interior.
	await _teleport(player, Vector3(8, 1.2, 90), 180.0)
	await _shot("11_interior")

	# End area / safehouse.
	await _teleport(player, Vector3(0, 1.2, 105), 180.0)
	await _shot("12_end_area")

	# Verify HUD damage flow: hurt the player.
	print("HARNESS: testing damage")
	GameManager.apply_damage(30.0)
	await _wait(0.2)
	await _shot("13_damage_vignette")

	# Finish the level.
	print("HARNESS: completing level")
	GameManager.complete_level()
	await _wait(5.0)
	await _shot("14_end_of_demo")

	print("HARNESS: DONE")
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [SHOT_DIR, name]
	img.save_png(path)
	_shot_idx += 1
	print("HARNESS: saved ", path)


func _current_scene_is_level() -> bool:
	var cs := get_tree().current_scene
	return cs != null and cs.is_in_group("gameplay")


func _find_player() -> CharacterBody3D:
	var nodes := get_tree().get_nodes_in_group("player")
	return nodes[0] as CharacterBody3D if nodes.size() > 0 else null


func _find_nearest_npc(player: Node3D) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("npc"):
		var n3 := n as Node3D
		if n3 == null:
			continue
		if "current_state" in n3 and n3.current_state == 4:  # DEAD
			continue
		if "is_friendly" in n3 and n3.is_friendly:
			continue
		var d: float = player.global_position.distance_to(n3.global_position)
		if d < best_d:
			best_d = d
			best = n3
	return best


func _teleport(player: CharacterBody3D, pos: Vector3, yaw_degrees: float) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.rotation.y = deg_to_rad(yaw_degrees)
	var head := player.get_node_or_null("Head")
	if head:
		head.rotation.x = 0.0
	await _wait(1.2)


func _face_point(player: CharacterBody3D, target: Vector3) -> void:
	var to_target := target - player.global_position
	var yaw := atan2(-to_target.x, -to_target.z)
	player.rotation.y = yaw
	var head := player.get_node_or_null("Head")
	if head:
		var flat_dist := Vector2(to_target.x, to_target.z).length()
		head.rotation.x = atan2(to_target.y, flat_dist)
