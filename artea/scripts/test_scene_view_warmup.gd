extends SceneTree

const Warmup = preload("res://scripts/scene_view_warmup.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var scene := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 12: await process_frame
	var camera := root.get_camera_3d()
	var player := scene.get_node("Player3D") as CharacterBody3D
	player.set_physics_process(false)
	var camera_pose := camera.global_transform
	var player_pose := player.global_transform
	var process := camera.is_processing()
	var input := camera.is_processing_unhandled_input()
	var yaw: float = camera.get("_yaw")
	var pitch: float = camera.get("_pitch")
	var director := scene.get_node("ArtCastleFloatingWorld/WorldStreamingDirector")
	var states: Array[bool] = []
	for cell in director.get("_cells"): states.append(cell.shown)
	var progress: Array[float] = []
	var views: int = await Warmup.run(scene, func(fraction: float): progress.append(fraction))
	assert(views >= 20 and is_equal_approx(progress[-1], 1.0), "Real arrival, court, garden and world views are prepared")
	assert(camera.global_transform.is_equal_approx(camera_pose), "The exact normal entry camera is restored")
	assert(camera.get("_yaw") == yaw and camera.get("_pitch") == pitch, "Player camera angles remain unchanged")
	assert(camera.is_processing() == process and camera.is_processing_unhandled_input() == input)
	assert(player.global_transform.is_equal_approx(player_pose), "Warmup never teleports the player into another region")
	for i in states.size(): assert(director.get("_cells")[i].shown == states[i], "Normal visual streaming is restored")
	assert(director.is_processing(), "Streaming resumes before control is handed over")
	scene.queue_free()
	await process_frame
	print("SCENE VIEW WARMUP: PASS — real views, original camera/player, restored streaming")
	quit()
