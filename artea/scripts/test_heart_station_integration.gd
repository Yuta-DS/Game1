extends SceneTree
var failures: Array[String] = []
var player: CharacterBody3D
var island

func _init() -> void: _run.call_deferred()
func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func _release() -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right"]:
		Input.action_release(action)

func _walk_to(target: Vector3, frames := 3600) -> bool:
	for frame in frames:
		var offset := target - player.global_position
		offset.y = 0
		if offset.length() < 2.0:
			_release()
			print("WALK REACHED ", target)
			return true
		if island.modal_open: island._close()
		var cam = player._active_camera()
		var forward: Vector3 = -cam.global_basis.z
		forward.y = 0
		forward = forward.normalized()
		var right: Vector3 = cam.global_basis.x
		right.y = 0
		right = right.normalized()
		var direction := offset.normalized()
		var x := direction.dot(right)
		var y := direction.dot(forward)
		_release()
		Input.action_press("move_right" if x > 0 else "move_left", absf(x))
		Input.action_press("move_forward" if y > 0 else "move_backward", absf(y))
		await physics_frame
	_release()
	print("WALK FAILED from ", player.global_position, " to ", target, " velocity ", player.velocity)
	for i in player.get_slide_collision_count(): print("COLLIDER ", player.get_slide_collision(i).get_collider().get_path())
	return false

func _run() -> void:
	create_timer(360).timeout.connect(func(): _release(); push_error("Heart station test timed out"); quit(1))
	var state = root.get_node("JourneyState")
	state.treasures["star_of_wisdom"] = false
	check(change_scene_to_file("res://scenes/art_gallery_3d_inprogress.tscn") == OK, "load actual overworld")
	await process_frame
	await process_frame
	var gallery = current_scene
	var railway = gallery.find_child("StoryCrownRailway", true, false)
	var connection = railway.get_node("HeartMelodyConnection")
	island = connection.island
	island.test_mode = true
	player = gallery.get_node("Player3D")
	var original_speed: float = player.speed
	check(railway.STATIONS[2].id == "heart", "third station is Heart")
	check(island.player == player, "island uses the overworld player")
	check(not island.embedded_active and not island.get_node("HeartHUD").visible, "distant island does not take over HUD")
	check(not connection.barrier.get_parent().visible, "Heart garden path is open without the Star")
	state.treasures["star_of_wisdom"] = true
	await process_frame
	await physics_frame
	check(not connection.barrier.get_parent().visible, "legitimate Star progress leaves the independent path open")
	# Start at main's current Heart station landing and walk onto the garden path.
	player.global_position = railway.to_global(railway.STATIONS[2].landing)
	player.velocity = Vector3.ZERO
	for frame in 120: await physics_frame
	check(player.is_on_floor(), "main Heart station landing supports player")
	check(await _walk_to(connection.to_global(connection.WALK_START)), "walk from main station landing onto garden path")
	var station_milo = root.get_node("MiloCompanionManager").get_active_milo()
	check(station_milo != null and player.get_meta("milo_heart_escort", false), "Milo joins the player at the station landing")
	var milo_station_position: Vector3 = station_milo.global_position
	# Follow the curving bridge the way a player would, a stretch at a time.
	var walk: PackedVector3Array = connection.walk_points
	var climbed := true
	for i in range(4, walk.size() / 2, 4): climbed = climbed and await _walk_to(connection.to_global(walk[i]))
	check(climbed, "walk continuous garden slope without jumping")
	print("MILO STATION ROUTE: start=", milo_station_position, " now=", station_milo.global_position, " player=", player.global_position, " breadcrumbs=", station_milo._breadcrumbs.size())
	check(station_milo.global_position.distance_to(milo_station_position) > 100, "Milo physically walks the station-to-garden slope")
	check(station_milo.global_position.distance_to(player.global_position) < 22, "walking escort keeps up on the station route")
	var crossed := true
	for i in range(walk.size() / 2, walk.size(), 4): crossed = crossed and await _walk_to(connection.to_global(walk[i]))
	check(crossed, "walk curved garden bridge")
	check(await _walk_to(connection.to_global(connection.WALK_FINISH)), "walk garden entrance bridge")
	var entry_camera = root.get_camera_3d()
	var entry_yaw: float = entry_camera._yaw
	var entry_pitch: float = entry_camera._pitch
	var entry_zoom: float = entry_camera.follow_distance
	check(await _walk_to(island.to_global(Vector3(-65, 1, 12))), "walk through arrival arch")
	check(root.get_camera_3d() == entry_camera and is_equal_approx(entry_camera._yaw, entry_yaw) and is_equal_approx(entry_camera._pitch, entry_pitch) and is_equal_approx(entry_camera.follow_distance, entry_zoom), "entry preserves the shared camera angle and zoom")
	check(current_scene == gallery and island.embedded_active, "entry stays in same overworld scene")
	check(player.input_enabled and gallery.get_node("Camera3D").current, "garden camera and controls activate")
	check(island.get_node("HeartHUD").visible, "garden HUD activates on entry")
	var companion = root.get_node("MiloCompanionManager").get_active_milo()
	check(is_instance_valid(companion) and companion.visible and companion.can_process(), "Milo remains visible and follows inside Heart Melody")
	if is_instance_valid(companion):
		check(companion.player == player, "Milo follows the shared player")
		var before: Vector3 = companion.global_position
		player.global_position = island.to_global(Vector3(-55, 1, 12))
		for frame in 120: await physics_frame
		check(companion.global_position.distance_to(before) > 0.5, "Milo walks after the player in Heart Melody")
	check(player.get_node("FoxVisuals").visible, "player remains visible inside Heart Melody")
	check(island.hud.get_parent().anchor_left == 1.0, "description is anchored to the right of the minimap")
	for guide in island.find_children("*", "Node3D", true, false):
		if guide.has_method("set_dialogue_line") and guide.has_node("DialogueLabel"):
			check(not guide.get_node("DialogueLabel").visible, "tiny guide captions removed")
	var arrival = gallery.find_child("StoryCheckpoint_01_arrival", true, false)
	# Find the Heart checkpoint specifically; other kingdoms have an arrival too.
	for node in gallery.find_children("StoryCheckpoint_01_arrival", "Node3D", true, false):
		if node.get_meta("kingdom_id", "") == "heart": arrival = node
	if arrival != null:
		check(arrival.find_children("EmotionInstrument*", "MeshInstance3D", true, false).is_empty(), "giant yellow arrival cylinders removed")
		var light = arrival.get_node("StoryLight")
		check(light.position.y + light.mesh.height / 2 < 0.54, "pink pad stays flush with the collision floor")
	for x in [126.0, 143.0, 160.0]:
		var grounded := false
		for bloom in island.river.get_children():
			if bloom is Node3D and bloom.position.is_equal_approx(Vector3(x, 0, 0)):
				grounded = true
		check(grounded, "organ valve flower is planted on the riverbank floor")
	# Real planter interaction at the translated and rotated world location.
	check(await _walk_to(island.to_global(Vector3(-40, 1, 8))), "walk to first planter")
	player.global_position = island.to_global(Vector3(-40, 1.1, 6.2))
	island._process(0)
	island._interact_nearest()
	check(island.modal_open, "translated planter interaction opens")
	island._close()
	check(island.progress.plant(0, 6), "shared island seed saves")
	for index in 3: island.progress.plant(index, 6)
	island.progress.edit_phrase([0, 2, 1])
	island.progress.solve()
	player.global_position = island.to_global(island.encounter_center)
	island._process(0)
	check(island.enemies.size() > 0, "embedded encounter activates in island coordinates")
	if not island.enemies.is_empty():
		var enemy = island.enemies[0]
		var warning_center: Vector3 = (enemy.origin + enemy.target) * 0.5 + Vector3.UP * 0.08
		check(enemy.marker.global_position.distance_to(warning_center) < 0.15, "attack marker matches translated enemy lane")
		var before: float = enemy.remaining
		enemy._physics_process(0.1)
		check(enemy.remaining < before, "enemy advances while player is in embedded clearing")
		island._notice("Pause test")
		before = enemy.remaining
		enemy._physics_process(0.1)
		check(is_equal_approx(enemy.remaining, before), "embedded modal suspends combat")
		island._close()
	# Recovery must resolve in island space, never back at world origin.
	island._recover()
	check(island.player_local_position().distance_to(Vector3(-56, 2, 17)) < 0.1, "recovery uses island transform")
	check(await _walk_to(island.to_global(Vector3(-65, 1, 12))), "walk back to arrival")
	check(await _walk_to(connection.to_global(connection.WALK_FINISH)), "walk out of arch")
	var returned := true
	for i in range(walk.size() - 4, 0, -4): returned = returned and await _walk_to(connection.to_global(walk[i]))
	check(returned, "walk the curved bridge back down to the court")
	check(await _walk_to(connection.to_global(connection.WALK_START)), "walk down slope to station court")
	check(not island.embedded_active and not island.get_node("HeartHUD").visible, "leaving restores overworld presentation")
	check(player.input_enabled and is_equal_approx(player.speed, original_speed), "overworld movement restored")
	check(current_scene == gallery and island.progress.data.planters.has("0"), "same scene retains saved progress")
	check(not state.has_treasure("harmony_jewel"), "walkthrough does not grant full-world treasure")
	player.global_position = island.to_global(Vector3(474, 1.2, 8))
	for frame in 8: await physics_frame
	if island.modal_open: island._close()
	island._process(0)
	check(island.nearest >= 0 and island.interactables[island.nearest].kind == "chapter_gate", "castle gate offers the return interaction")
	island._interact_nearest()
	for frame in 12: await physics_frame
	check(current_scene == gallery and player.global_position.distance_to(gallery.to_global(Vector3(0, 2, 26))) < 5, "return gate reaches the Castle without rebuilding the overworld")
	check(player.input_enabled and not island.embedded_active and not island._return_gate_busy, "return gate restores controls and releases its busy state")
	var return_position: Vector3 = player.global_position
	Input.action_press("move_forward")
	for frame in 30: await physics_frame
	Input.action_release("move_forward")
	check(player.global_position.distance_to(return_position) > 0.5, "player can walk after returning to Castle")
	print("HEART STATION INTEGRATION: all checks passed" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
