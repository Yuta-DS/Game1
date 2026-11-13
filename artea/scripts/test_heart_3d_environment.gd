extends SceneTree

var world
var failures: Array[String] = []
var captures := false
var samples: Array[float] = []
const SAVE := "res://../work/heart_3d_environment_test.json"

func _init() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
		push_error(description)

func run() -> void:
	captures = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1280, 720)
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	world = load("res://scenes/heart_melody/heart_melody_world.tscn").instantiate()
	world.test_mode = true
	world.progress.path = SAVE
	root.add_child(world)
	current_scene = world
	for frame in 8: await physics_frame
	# Movement uses the real player's camera-relative input and collision solver.
	var route := [Vector3(-65,1,12), Vector3(-66,1,-8), Vector3(-70,1,-9.4), Vector3(-66,1,-8), Vector3(-58,1,-24.4), Vector3(-40,1,-29.4), Vector3(-27,1,-22.4), Vector3(-21,1,-28), Vector3(8,1,-29), Vector3(21,1,-29), Vector3(23,1,-10), Vector3(15,1,4), Vector3(8,1,20), Vector3(8,1,29), Vector3(15,1,29), Vector3(8,1,20), Vector3(26,1,20), Vector3(38,1,24), Vector3(42,1,32), Vector3(30,1,48), Vector3(35,1,37), Vector3(42,1,16), Vector3(60,1,8), Vector3(94,1,8), Vector3(115,1,8), Vector3(146,1,8), Vector3(179,1,8), Vector3(179,1,-8), Vector3(225,1,-8), Vector3(244,1,8), Vector3(294,1,8)]
	world.player.position = route[0] + Vector3.UP
	for i in range(1, route.size()):
		check(await walk(route[i]), "walk section %d to %s" % [i, route[i]])
		if i in [2, 5, 7, 8, 10, 12, 13, 18, 19, 22, 24]:
			await orbit_area(i)
	# Rear/side approaches around the waterfall and instrument frames.
	for point in [Vector3(-7,1,-48), Vector3(8,1,-38), Vector3(-21,1,-36), Vector3(-70,1,-16), Vector3(42,1,25)]:
		world.player.position = point + Vector3.UP
		for frame in 8: await physics_frame
		await orbit_area(30 + int(point.x))
	# Full-volume collision test, including a roof directly over the camera arm.
	world.player.position = Vector3(-50,1,12)
	world.player.velocity = Vector3.ZERO
	world.player.set_input_enabled(false)
	world.camera.pitch = 0
	world.camera.yaw = 0
	world.camera._pitch = 0
	world.camera._yaw = 0
	var wall = world.Art.box(world, Vector3(-50,4,16), Vector3(8,8,1), Color.GRAY, true)
	for frame in 5: await physics_frame
	world._camera_update(1)
	check(world.camera.actual_distance < 3.2, "camera retracts before a wall")
	wall.free()
	for frame in 50: await physics_frame
	check(world.camera.actual_distance > 8.5, "camera restores distance smoothly after obstruction")
	var roof = world.Art.box(world, Vector3(-50,5,12), Vector3(15,0.5,15), Color.GRAY, true)
	world.camera.pitch = -1.0
	for frame in 30: await physics_frame
	check(world.camera.global_position.y < 4.45, "camera remains below bridge underside")
	roof.free()
	# Input convention, clamping and no exploration auto-recentre.
	world.camera.orbit(Vector2(TAU, 20))
	check(is_equal_approx(world.camera.pitch, -1.18), "comfortable downward limit")
	world.camera.orbit(Vector2(0, -40))
	check(is_equal_approx(world.camera.pitch, 1.05), "comfortable upward limit")
	world.reduced_motion = true
	var yaw: float = world.camera.yaw
	world._camera_update(1)
	check(is_equal_approx(yaw, world.camera.yaw), "reduced motion preserves chosen heading")
	# Essential fruit and visible basket survive reload without changing schema.
	for id in world.musical_garden.Catalog.FRUIT_ORDER:
		world.progress.discover_fruit(id)
		world.musical_garden.refresh()
		world.musical_garden._harvest_visual(id)
		check(not world.musical_garden.fruit_visuals[id].visible, "harvest removes " + id)
		check(world.musical_garden.basket_fruit[id].visible, "basket shows " + id)
	world.progress.load_progress()
	world.musical_garden.refresh()
	check(world.progress.data.music.basket.size() == 4, "reload retains all four fruit")
	check(world.progress.configure_instrument("marimba", 0, "bass_melon"), "reloaded fruit can be used")
	world.player.position = Vector3(-50,-20,12)
	world._process(0.016)
	check(world.player.position.y > 0, "fall recovery restores player")
	if not samples.is_empty():
		samples.sort()
		print("ORBIT METRICS frames=", samples.size(), " median_ms=", samples[samples.size()/2], " p95_ms=", samples[int(samples.size()*0.95)], " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("HEART 3D ENVIRONMENT: ", "PASS" if failures.is_empty() else failures)
	world.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	quit(0 if failures.is_empty() else 1)

func walk(target: Vector3) -> bool:
	world.player.set_input_enabled(true)
	for frame in 900:
		var offset: Vector3 = target - world.player.position
		offset.y = 0
		if offset.length() < 0.8:
			release()
			return world.player.position.y > -1
		var basis: Basis = world.camera.global_basis
		var forward := -basis.z; forward.y = 0; forward = forward.normalized()
		var right := basis.x; right.y = 0; right = right.normalized()
		var direction := offset.normalized()
		var x := direction.dot(right)
		var y := direction.dot(forward)
		release()
		Input.action_press("move_right" if x >= 0 else "move_left", absf(x))
		Input.action_press("move_forward" if y >= 0 else "move_backward", absf(y))
		await physics_frame
	release()
	print("BLOCKED at ", world.player.position, " wanted ", target)
	return false

func release() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_backward"]: Input.action_release(action)

func orbit_area(index: int) -> void:
	world.player.set_input_enabled(false)
	for frame in 72:
		world.camera.yaw = frame * TAU / 72.0
		world.camera.pitch = -0.24 + sin(frame * TAU / 72.0) * 0.65
		var before := Time.get_ticks_usec()
		await physics_frame
		if captures:
			await process_frame
			samples.append((Time.get_ticks_usec() - before) / 1000.0)
			if frame % 24 == 0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://../work/heart-orbit-%d-%d.png" % [index, frame])
		check(world.camera.global_position.is_finite(), "finite orbit camera")
	world.camera.pitch = -0.24
	world.player.set_input_enabled(true)
