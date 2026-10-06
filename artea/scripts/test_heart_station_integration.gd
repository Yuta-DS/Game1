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

func _walk_to(target: Vector3, frames := 1800) -> bool:
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
	create_timer(180).timeout.connect(func(): _release(); push_error("Heart station test timed out"); quit(1))
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
	# Start on the station access ramp and walk onto the arrival court.
	player.global_position = railway.to_global(Vector3(1585, 25, 7640))
	player.velocity = Vector3.ZERO
	for frame in 120: await physics_frame
	check(player.is_on_floor(), "station access ramp supports player")
	check(await _walk_to(connection.to_global(connection.WALK_START)), "walk from station ramp onto arrival court")
	check(await _walk_to(connection.to_global(connection.WALK_TURN)), "walk continuous garden slope without jumping")
	check(await _walk_to(connection.to_global(connection.WALK_FINISH)), "walk garden entrance bridge")
	check(await _walk_to(island.to_global(Vector3(-65, 1, 12))), "walk through arrival arch")
	check(current_scene == gallery and island.embedded_active, "entry stays in same overworld scene")
	check(player.input_enabled and island.camera.current, "garden camera and controls activate")
	check(island.get_node("HeartHUD").visible, "garden HUD activates on entry")
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
	check(await _walk_to(connection.to_global(connection.WALK_TURN)), "walk entrance bridge back to slope")
	check(await _walk_to(connection.to_global(connection.WALK_START)), "walk down slope to station court")
	check(not island.embedded_active and not island.get_node("HeartHUD").visible, "leaving restores overworld presentation")
	check(player.input_enabled and is_equal_approx(player.speed, original_speed), "overworld movement restored")
	check(current_scene == gallery and island.progress.data.planters.has("0"), "same scene retains saved progress")
	check(not state.has_treasure("harmony_jewel"), "walkthrough does not grant full-world treasure")
	print("HEART STATION INTEGRATION: all checks passed" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
