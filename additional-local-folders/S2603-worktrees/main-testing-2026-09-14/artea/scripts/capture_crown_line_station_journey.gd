extends SceneTree

const OUTPUT_DIR := "res://artifacts"
const GAME_SCENE := "res://scenes/art_gallery_3d_inprogress.tscn"


func _init() -> void:
	call_deferred("_capture_journey")


func _capture_journey() -> void:
	root.size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var packed := load(GAME_SCENE) as PackedScene
	if packed == null:
		_fail("existing Art Castle game scene could not be loaded")
		return
	var game := packed.instantiate()
	root.add_child(game)
	for _frame in 90:
		await process_frame

	var world := game.get_node_or_null("ArtCastleFloatingWorld") as Node3D
	var railway := game.get_node_or_null("ArtCastleFloatingWorld/StoryCrownRailway") as Node3D
	var player := game.get_node_or_null("Player3D") as CharacterBody3D
	var camera := game.get_node_or_null("Camera3D") as Camera3D
	if world == null or railway == null or player == null or camera == null:
		_fail("live game is missing the world, railway, player, or camera")
		return
	var train := railway.get_node_or_null("RainbowGalaxyTrain") as Node3D
	if train == null or train.get_node_or_null("BlenderCrownLineTrain") == null \
			or train.get_node_or_null("GodotEngineCover") == null:
		_fail("finished train was not instantiated in the existing game")
		return
	if int(railway.call("get_start_station_index")) != 0 \
			or String(railway.call("get_start_station_id")) != "gallery" \
			or int(railway.call("get_current_station")) != 0:
		_fail("train did not begin at the castle-side Gallery station")
		return

	for layer in game.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	for label in game.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	camera.set_script(null)
	camera.make_current()
	camera.fov = 56.0

	# Proof 1: the detailed train is parked at the first station beside the castle
	# arrival island before any ride input is sent.
	_place_camera_by_train(camera, train, Vector3(40.0, 20.0, -38.0), Vector3(0.0, 4.0, 0.0))
	await _save(OUTPUT_DIR + "/crown_line_castle_station_departure.png")

	# Board using the same public travel request used by gameplay. Station 01 and
	# Station 02 are intentionally available at the beginning of the story.
	player.global_position = railway.to_global(
		railway.call("get_station_position", 0) + Vector3(0.0, 0.0, 11.0))
	railway.set("ride_duration", 2.0)
	if not bool(railway.call("request_ride")):
		_fail("player could not board at the castle-side start station")
		return
	await create_timer(0.85).timeout
	camera.fov = 62.0
	_place_camera_by_train(camera, train, Vector3(64.0, 24.0, 5.0), Vector3(0.0, 3.8, 0.0))
	await _save_following_train(OUTPUT_DIR + "/crown_line_between_stations.png",
		camera, train, Vector3(64.0, 24.0, 5.0), Vector3(0.0, 3.8, 0.0))

	while bool(railway.call("is_riding")):
		await process_frame
	if int(railway.call("get_current_station")) != 1:
		_fail("train did not arrive at Mind Spark station")
		return
	camera.fov = 56.0
	_place_camera_by_train(camera, train, Vector3(39.0, 18.0, -36.0), Vector3(0.0, 4.0, 0.0))
	await _save(OUTPUT_DIR + "/crown_line_mind_station_arrival.png")
	print("CROWN_LINE_STATION_JOURNEY_CAPTURE: PASS — Gallery start to Mind Spark arrival")
	quit()


func _place_camera_by_train(camera: Camera3D, train: Node3D, offset: Vector3,
		look_offset: Vector3) -> void:
	camera.global_position = train.to_global(offset)
	camera.look_at(train.to_global(look_offset), Vector3.UP)


func _save(path: String) -> void:
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.save_png(path) != OK:
		_fail("failed to save %s" % path)


func _save_following_train(path: String, camera: Camera3D, train: Node3D,
		offset: Vector3, look_offset: Vector3) -> void:
	# The Gallery-to-Mind segment is intentionally long. Re-anchor on every
	# presentation frame so the moving train cannot outrun a static camera while
	# the GPU finishes the screenshot.
	for _frame in 8:
		_place_camera_by_train(camera, train, offset, look_offset)
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.save_png(path) != OK:
		_fail("failed to save moving train at %s" % path)


func _fail(message: String) -> void:
	push_error("CROWN_LINE_STATION_JOURNEY_CAPTURE: %s" % message)
	quit(1)
