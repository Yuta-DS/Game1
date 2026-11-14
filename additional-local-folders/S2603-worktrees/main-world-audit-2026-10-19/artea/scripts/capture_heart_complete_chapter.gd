extends SceneTree
const Chapter = preload("res://scripts/heart_melody/heart_chapter_world.gd")
var world
var folder := "res://../work/heart-production-captures/"

func _init() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("JourneyState").save_path = "res://../work/heart-capture-journey.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	world = load("res://scenes/heart_melody/heart_melody_world.tscn").instantiate()
	world.test_mode = true
	world.progress.path = "res://../work/heart_complete_chapter_test.json"
	root.add_child(world)
	current_scene = world
	for i in 30: await process_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	world.get_node("HeartHUD").hide()
	for i in 6:
		var centre: Vector3 = Chapter.CENTRES[i]
		world.camera.position = centre + Vector3(-22, 25, 30)
		world.camera.look_at(centre + Vector3(0, 2, 0))
		await capture("zone_%d_overview" % (i + 1))
		world.camera.position = centre + Vector3(-8, 2.5, 7)
		world.camera.look_at(centre + Vector3(0, 2, 0))
		await capture("zone_%d_player_height" % (i + 1))
	for i in 6:
		var centre: Vector3 = Chapter.FRUIT_POS[i]
		world.camera.position = centre + Vector3(4, 4, 7)
		world.camera.look_at(centre + Vector3(0, 2.5, 0))
		await capture("fruit_%d" % (i + 1))
	for task in Chapter.STATIONS:
		var centre: Vector3 = Chapter.STATIONS[task]
		world.camera.position = centre + Vector3(-9, 8, 12)
		world.camera.look_at(centre + Vector3(0, 2, -2))
		await capture("instrument_%d" % (task + 1))
	world.camera.position = Vector3(382, 14, 32)
	world.camera.look_at(Vector3(399, 2, 8))
	await capture("beat_anchors_restored")
	world.get_node("HeartHUD").show()
	world.player.position = Vector3(-65, 2, 12)
	world._camera_update(1)
	world._intro()
	await capture("arrival_controls")
	print("HEART PRODUCTION CAPTURES: saved to ", ProjectSettings.globalize_path(folder))
	quit()

func capture(name: String) -> void:
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + name + ".png")
