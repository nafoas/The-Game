extends Node
## Automated playthrough harness. Temporarily registered as an autoload for
## headless testing; drives the game through menu -> cutscene -> level ->
## end-of-demo and saves screenshots at each stage. Not shipped with the game.

const SHOT_DIR := "/tmp/shots"

var _shot_idx := 0
var _movie_keepalive := false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	# Movie capture mode: run with
	#   godot --path . --write-movie /tmp/capture/out.avi --fixed-fps 30 -- movie
	# Plays short scripted scenes showcasing animation instead of taking stills.
	if OS.get_cmdline_user_args().has("noharness"):
		return  # debugging/probe sessions: leave the game alone
	if OS.get_cmdline_user_args().has("movie"):
		_run_movie.call_deferred()
	else:
		_run.call_deferred()


func _run() -> void:
	# The AI now actively hunts the player (hearing, squads, suppression), so
	# keep the test driver alive through incidental fire like movie mode does.
	_movie_keepalive = true
	_movie_keepalive_loop()
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

	# Plaza — stand at the edge looking across the fountain.
	await _teleport(player, Vector3(-6.5, 1.2, 61), 0.0)
	_face_point(player, Vector3(0, 1.0, 70))
	await _wait(0.5)
	await _shot("10_plaza")

	# Interior — stand inside the radio shack looking at the radio corner.
	await _teleport(player, Vector3(-2.5, 1.2, 83.5), 0.0)
	_face_point(player, Vector3(2.4, 1.0, 92.0))
	await _wait(0.5)
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
	_movie_keepalive = false
	get_tree().quit(0)


# ---------------------------------------------------------------------------
# Movie capture mode — short scripted scenes that showcase animation.
# Whole session is recorded by --write-movie, so keep total runtime tight.
# ---------------------------------------------------------------------------

func _run_movie() -> void:
	print("HARNESS: movie mode — loading level directly")
	await _wait(0.5)
	get_tree().change_scene_to_file("res://scenes/level/level_01.tscn")
	await _wait(2.0)

	var player := _find_player()
	if player == null:
		print("HARNESS: FATAL no player found")
		get_tree().quit(1)
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_movie_keepalive = true
	_movie_keepalive_loop()
	# Freeze AI aggression: everyone just idles/wanders until each scene
	# deliberately wakes them up.
	_set_all_npcs_scripted(true)

	await _movie_idle_life(player)
	await _movie_combat(player)
	await _movie_squad(player)

	print("HARNESS: MOVIE DONE")
	_movie_keepalive = false
	await _wait(0.5)
	get_tree().quit(0)


## Keep the player alive through incidental NPC fire — a death/respawn screen
## would ruin the capture. Damage flashes still read; health just never hits 0.
func _movie_keepalive_loop() -> void:
	while _movie_keepalive:
		GameManager.heal(100.0)
		await _wait(1.0)


func _set_all_npcs_scripted(value: bool) -> void:
	for n in get_tree().get_nodes_in_group("npc"):
		if "scripted_patrol" in n:
			n.scripted_patrol = value


## Inject an action through the input pipeline. Unlike Input.action_press()
## (which, called from a timer callback at end-of-frame, stamps the press with
## the CURRENT frame so is_action_just_pressed() never sees it next frame),
## parse_input_event() is flushed at the start of the next frame — semi-auto
## fire / reload / weapon-switch handlers all see a clean just-pressed edge.
func _send_action(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _tap_action(action: String) -> void:
	_send_action(action, true)
	await _wait(0.1)
	_send_action(action, false)


## Scene 1 (~10s): actbusy idle life — the plaza guards (no waypoints) turn,
## wander to nearby points and lean on walls while the player watches from
## the plaza mouth. scripted_patrol only gates aggro, not the idle brain.
func _movie_idle_life(player: CharacterBody3D) -> void:
	print("HARNESS: movie scene 1 — idle wander/lean")
	await _teleport(player, Vector3(0, 1.2, 61.0), 180.0)
	# Watch the nearest plaza guard live its idle life (wander/turn/lean).
	var subject := _find_nearest_npc(player)
	for i in 20:
		if subject != null and is_instance_valid(subject):
			_face_point(player, subject.global_position + Vector3(0, 1.1, 0))
		await _wait(0.5)


## Scene 2 (~22s): senses + one-on-one combat. The player sneaks up BEHIND a
## street NPC (no detection — vision cone), fires a shot (heard -> ALERT ->
## turn -> COMBAT with the gun raised), trades fire, wounds it (stagger +
## cover dash) and finally drops it (ragdoll).
func _movie_combat(player: CharacterBody3D) -> void:
	print("HARNESS: movie scene 2 — senses and combat")
	var npc := _find_nearest_npc(player)
	if npc == null:
		print("HARNESS: movie — no NPC available, skipping combat scene")
		return

	# Stage: NPC mid-street near the barricade cover, facing AWAY from the
	# player (toward +Z). Player ~9 m behind it: inside DETECTION_RANGE and
	# HEARING_RANGE but outside the 120° vision cone — it must NOT see us.
	npc.global_position = Vector3(0.5, 0.5, 33.0)  # beside the barricade funnel (cover-rich)
	if "waypoints" in npc:
		var wp: Array[Vector3] = []
		npc.waypoints = wp
	if "current_state" in npc:
		npc.current_state = 0  # IDLE
	npc.rotation.y = deg_to_rad(180.0)  # character -Z forward -> faces +Z (away)
	# Pin the idle brain: no wandering off mid-beat (would drift out of the
	# hearing radius and ruin the staged demonstration).
	npc._idle_mode = 0  # IdleMode.STAND
	npc._idle_timer = 999.0
	npc.scripted_patrol = false
	await _teleport(player, Vector3(0.5, 1.2, 24), 180.0)
	_face_point(player, npc.global_position + Vector3(0, 1.0, 0))

	# Beat 1: stand in plain "sight" behind its back — nothing happens.
	for i in 10:
		if not is_instance_valid(npc):
			return
		print("DBG behind i=%d state=%s" % [i, npc.current_state])
		await _wait(0.3)

	# Beat 2: fire one shot into the air — it HEARS it, spins, spots us.
	print("HARNESS: movie — firing a shot to be heard")
	_face_point(player, npc.global_position + Vector3(0, 4.0, 0))  # miss high
	await _tap_action("fire")
	await _wait(0.3)
	for i in 16:
		if not is_instance_valid(npc):
			return
		print("DBG react i=%d pos=%v state=%s mode=%s" % [i, npc.global_position, npc.current_state, npc.get("_combat_mode")])
		_face_point(player, npc.global_position + Vector3(0, 1.1, 0))
		await _wait(0.25)

	# Beat 3: wound it twice — pronounced stagger, then a dash behind cover.
	print("HARNESS: movie — wounding NPC")
	for i in 2:
		if not is_instance_valid(npc) or npc.current_state == 4:
			break
		_face_point(player, npc.global_position + Vector3(0, 1.15, 0))
		await _tap_action("fire")
		await _wait(0.9)
	for i in 14:
		if not is_instance_valid(npc) or npc.current_state == 4:
			break
		print("DBG cover i=%d pos=%v mode=%s" % [i, npc.global_position, npc.get("_combat_mode")])
		_face_point(player, npc.global_position + Vector3(0, 1.0, 0))
		await _wait(0.25)

	# Beat 4: finish it — ragdoll death.
	print("HARNESS: movie — player firing to kill")
	for i in 14:
		if not is_instance_valid(npc):
			break
		if npc.current_state == 4:  # DEAD
			break
		_face_point(player, npc.global_position + Vector3(0, 1.2, 0))
		await _tap_action("fire")
		await _wait(0.22)
	if is_instance_valid(npc):
		_face_point(player, npc.global_position + Vector3(0, 0.5, 0))
	await _wait(2.0)


## Scene 3 (~13s): squad firefight in the plaza — multiple NPCs coordinate:
## the closest advances on the player while the others hold and suppress,
## seek cover behind the concrete barriers and pop up to fire.
func _movie_squad(player: CharacterBody3D) -> void:
	print("HARNESS: movie scene 3 — squad firefight")
	_set_all_npcs_scripted(false)
	await _teleport(player, Vector3(0, 1.2, 56), 180.0)
	_face_point(player, Vector3(0, 1.2, 70.0))
	# Announce ourselves: one shot toward the fountain wakes the plaza squad.
	await _tap_action("fire")
	var watch_start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - watch_start < 12000:
		# Keep the camera on the action: face the nearest live hostile.
		var npc := _find_nearest_npc(player)
		if npc != null:
			_face_point(player, npc.global_position + Vector3(0, 1.0, 0))
			print("DBG squad state=%s mode=%s suppress=%s" % [npc.current_state, npc.get("_combat_mode"), npc.get("_squad_suppress")])
		await _wait(0.4)
	# Fight back briefly so the finale has both sides shooting.
	for i in 6:
		var npc := _find_nearest_npc(player)
		if npc == null:
			break
		_face_point(player, npc.global_position + Vector3(0, 1.1, 0))
		await _tap_action("fire")
		await _wait(0.3)


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
