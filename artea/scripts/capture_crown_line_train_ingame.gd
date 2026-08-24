extends SceneTree

const OUTPUT_DIR := "res://artifacts"
const RAILWAY_SCRIPT := "res://scripts/art_castle_story_railway.gd"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	# Build the exact runtime railway used by the gallery scene in a focused
	# capture world. This avoids unrelated gallery art/UI while retaining the live
	# station, continuous track, collisions, train controls and imported GLB.
	var world := Node3D.new()
	world.name = "ArtCastleFloatingWorld"
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	# Use the same fox visual as the live castle world so the passenger proof is
	# an actual character-in-coach screenshot, not an invisible test body.
	var fox_visuals := Node3D.new()
	fox_visuals.name = "FoxVisuals"
	player.add_child(fox_visuals)
	var fox := (load("res://assets3D/characters/fox.glb") as PackedScene).instantiate() as Node3D
	fox.name = "Fox"
	fox.scale = Vector3.ONE * 3.0
	fox.position = Vector3(0.0, -0.98, 0.0)
	fox_visuals.add_child(fox)
	world.add_child(player)
	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load(RAILWAY_SCRIPT))
	world.add_child(railway)
	for _frame in 3:
		await process_frame

	var train := railway.get_node_or_null("RainbowGalaxyTrain") as Node3D
	if train == null or train.get_node_or_null("BlenderCrownLineTrain") == null:
		_fail("textured Blender Crown Line train was not instantiated")
		return

	# Hide only interface overlays so these remain genuine in-game world captures.
	for layer in world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	var gallery_station := railway.get_node_or_null(
		"StoryStations/Station_01_gallery") as Node3D
	if gallery_station != null:
		var pavilion := gallery_station.get_node_or_null("BioMagitechPavilion") as Node3D
		if pavilion != null:
			pavilion.visible = false

	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color("142b42")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("bfe7ff")
	environment_resource.ambient_light_energy = 0.46
	environment_resource.tonemap_exposure = 0.62
	environment.environment = environment_resource
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("fff0c9")
	sun.light_energy = 0.76
	sun.shadow_enabled = true
	world.add_child(sun)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	camera.fov = 58.0

	# Anchor every view to the live gameplay train rather than duplicating its
	# authored station coordinates.
	var centre := train.to_global(Vector3(0.0, 4.0, 0.0))
	var godot_cover := train.get_node_or_null("GodotEngineCover") as Node3D
	var blender_train := train.get_node_or_null("BlenderCrownLineTrain") as Node3D
	if godot_cover == null:
		_fail("native Godot engine cover was not instantiated")
		return
	# Identical gameplay camera for a renderer-to-renderer comparison. The first
	# image is the Blender GLB alone; the second adds the native Godot cover built
	# from the shared JSON profile; the third isolates its small components.
	camera.fov = 50.0
	camera.global_position = train.to_global(Vector3(12.0, 7.4, -34.0))
	camera.look_at(train.to_global(Vector3(0.0, 3.8, -25.0)), Vector3.UP)
	godot_cover.visible = false
	await _save(OUTPUT_DIR + "/crown_line_compare_blender_cover.png")
	godot_cover.visible = true
	await _save(OUTPUT_DIR + "/crown_line_compare_godot_cover.png")
	if blender_train != null:
		blender_train.visible = false
	await _save(OUTPUT_DIR + "/crown_line_compare_godot_components.png")
	# A clean native-Godot beauty shot makes the intended soft, readable game
	# style visible without the denser Blender artwork underneath it.
	camera.fov = 46.0
	camera.global_position = train.to_global(Vector3(10.0, 6.7, -35.0))
	camera.look_at(train.to_global(Vector3(0.0, 3.65, -25.0)), Vector3.UP)
	await _save(OUTPUT_DIR + "/crown_line_godot_cartoon_cover.png")
	if blender_train != null:
		blender_train.visible = true

	camera.global_position = train.to_global(Vector3(31.0, 13.0, -38.0))
	camera.look_at(train.to_global(Vector3(0.0, 4.5, -3.0)), Vector3.UP)
	print("CROWN_LINE_INGAME_CAPTURE: rendering station view")
	await _save(OUTPUT_DIR + "/crown_line_train_ingame_station.png")

	camera.fov = 65.0
	camera.global_position = train.to_global(Vector3(14.0, 7.0, -42.0))
	camera.look_at(train.to_global(Vector3(0.0, 4.0, -11.0)), Vector3.UP)
	print("CROWN_LINE_INGAME_CAPTURE: rendering engine view")
	await _save(OUTPUT_DIR + "/crown_line_train_ingame_engine.png")

	camera.fov = 52.0
	camera.global_position = train.to_global(Vector3(10.0, 7.5, -31.0))
	camera.look_at(train.to_global(Vector3(0.0, 5.1, -17.2)), Vector3.UP)
	print("CROWN_LINE_INGAME_CAPTURE: rendering Apollo frame close-up")
	await _save(OUTPUT_DIR + "/crown_line_train_ingame_apollo_frame.png")

	# A lower side view proves the textured body, passenger deck, and live rail
	# are present together in the gameplay scene.
	camera.fov = 62.0
	camera.global_position = train.to_global(Vector3(38.0, 6.0, 0.0))
	camera.look_at(centre, Vector3.UP)
	print("CROWN_LINE_INGAME_CAPTURE: rendering side view")
	await _save(OUTPUT_DIR + "/crown_line_train_ingame_side.png")

	# Orthographic profile removes perspective convergence: the rail surface in
	# this image is the true constant-height guideway, so any vertical dip would
	# be immediately visible beneath the train.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 72.0
	camera.global_position = train.to_global(Vector3(58.0, 7.0, 0.0))
	camera.look_at(train.to_global(Vector3(0.0, 4.0, 0.0)), Vector3.UP)
	print("CROWN_LINE_INGAME_CAPTURE: rendering level track profile")
	await _save(OUTPUT_DIR + "/crown_line_level_track_side.png")

	# Move the real runtime train to the upgraded Mind Spark stop and capture the
	# station at both presentation and player scale. These images prove that the
	# localized architecture, track guides and playable train coexist in-game.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	railway.call("_dock_manual_train", 1)
	await process_frame
	var mind_station := railway.get_node_or_null(
		"StoryStations/Station_02_mind") as Node3D
	if mind_station == null or mind_station.get_node_or_null(
			"MindSparkStationUpgrade") == null:
		_fail("Mind Spark station upgrade was not instantiated")
		return
	player.visible = false
	camera.fov = 55.0
	camera.global_position = train.to_global(Vector3(72.0, 48.0, -74.0))
	camera.look_at(mind_station.global_position + Vector3(0.0, 4.0, 0.0), Vector3.UP)
	print("CROWN_LINE_INGAME_CAPTURE: rendering Mind Spark station overview")
	await _save(OUTPUT_DIR + "/crown_line_mind_spark_station_upgrade.png")
	camera.fov = 50.0
	camera.global_position = mind_station.global_position + Vector3(0.0, 150.0, 0.1)
	camera.look_at(mind_station.global_position, Vector3.FORWARD)
	print("CROWN_LINE_INGAME_CAPTURE: rendering Mind Spark circuit ground top")
	await _save(OUTPUT_DIR + "/crown_line_mind_spark_circuit_ground_top.png")
	camera.fov = 52.0
	camera.global_position = mind_station.global_position + Vector3(82.0, -42.0, 82.0)
	camera.look_at(mind_station.global_position + Vector3(0.0, -10.0, 0.0), Vector3.UP)
	print("CROWN_LINE_INGAME_CAPTURE: rendering Mind Spark floating ground underside")
	await _save(OUTPUT_DIR + "/crown_line_mind_spark_floating_ground.png")
	var crystal_reactor := mind_station.get_node(
		"MindSparkStationUpgrade/MindSparkFloatingGround/AetherCrystalReactor") as Node3D
	camera.fov = 40.0
	camera.global_position = crystal_reactor.global_position + Vector3(23.0, -27.0, 23.0)
	camera.look_at(crystal_reactor.global_position + Vector3(0.0, -28.0, 0.0), Vector3.UP)
	print("CROWN_LINE_INGAME_CAPTURE: rendering powered crystal close-up")
	await _save(OUTPUT_DIR + "/crown_line_mind_spark_power_crystal_closeup.png")
	camera.fov = 48.0
	camera.global_position = mind_station.global_position + Vector3(0.0, -112.0, 0.1)
	camera.look_at(mind_station.global_position + Vector3(0.0, -14.0, 0.0), Vector3.FORWARD)
	print("CROWN_LINE_INGAME_CAPTURE: rendering all five powered crystals")
	await _save(OUTPUT_DIR + "/crown_line_mind_spark_all_power_crystals.png")
	var dock_forward: Vector3 = railway.call("get_route_forward_direction_at_station", 1)
	var dock_side := Vector3.UP.cross(dock_forward).normalized()
	camera.fov = 54.0
	camera.global_position = mind_station.global_position + dock_side * 185.0 \
		+ Vector3.UP * 145.0 - dock_forward * 45.0
	camera.look_at(mind_station.global_position + dock_forward * 55.0, Vector3.UP)
	print("CROWN_LINE_INGAME_CAPTURE: rendering straight dock and broad curve")
	await _save(OUTPUT_DIR + "/crown_line_straight_station_broad_curve.png")

	camera.fov = 64.0
	# Stand inside the perimeter monoliths, on the same circulation ring the
	# player uses, so neither a rune tower nor the safety rail hides the cab door.
	camera.global_position = train.to_global(Vector3(12.0, 5.2, -23.0))
	camera.look_at(train.to_global(Vector3(0.0, 3.4, -3.0)), Vector3.UP)
	print("CROWN_LINE_INGAME_CAPTURE: rendering player-level Mind Spark boarding")
	await _save(OUTPUT_DIR + "/crown_line_mind_spark_boarding.png")

	# Driver proof: Q is pressed 1.8 m from the accessible front doorway, then the
	# fox is moved into the true cab seat rather than a hidden carriage marker.
	railway.call("_dock_manual_train", 0)
	player.visible = true
	player.global_position = railway.call("get_driver_interaction_position") \
		+ train.global_basis.x.normalized() * 1.8
	var driver_q := InputEventKey.new()
	driver_q.keycode = KEY_Q
	driver_q.pressed = true
	railway.call("_unhandled_input", driver_q)
	if not bool(railway.call("is_driving")):
		_fail("player could not enter the driver cab from two-metre doorway range")
		return
	player.global_basis = train.global_basis
	camera.fov = 46.0
	camera.global_position = train.to_global(Vector3(22.0, 8.5, -18.0))
	camera.look_at(train.to_global(Vector3(0.0, 3.6, -13.0)), Vector3.UP)
	print("CROWN_LINE_INGAME_CAPTURE: rendering player in driver cab")
	await _save(OUTPUT_DIR + "/crown_line_player_driving_cab.png")
	if not bool(railway.call("request_disembark")):
		_fail("player could not leave the driver cab after capture")
		return

	# Passenger proof: Q by a coach seat starts a real route tween and the player
	# stays attached to the selected bench while the train is moving.
	railway.call("_dock_manual_train", 0)
	railway.set("ride_duration", 30.0)
	player.visible = true
	player.global_position = railway.call("get_passenger_seat_position", 0) \
		+ train.global_basis.x.normalized() * 1.8
	var passenger_q := InputEventKey.new()
	passenger_q.keycode = KEY_Q
	passenger_q.pressed = true
	railway.call("_unhandled_input", passenger_q)
	if not bool(railway.call("is_passenger_seated")):
		_fail("player could not sit in the passenger coach for capture")
		return
	await create_timer(0.25).timeout
	player.global_basis = train.global_basis
	camera.fov = 50.0
	camera.global_position = train.to_global(Vector3(38.0, 10.0, 5.0))
	camera.look_at(train.to_global(Vector3(-1.0, 3.2, 4.0)), Vector3.UP)
	print("CROWN_LINE_INGAME_CAPTURE: rendering player riding passenger coach")
	await _save(OUTPUT_DIR + "/crown_line_player_riding_passenger.png")

	print("CROWN_LINE_INGAME_CAPTURE: PASS")
	quit()


func _save(path: String) -> void:
	for _frame in 4:
		await process_frame
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		_fail("active display renderer did not provide a viewport texture")
		return
	var image := viewport_texture.get_image()
	if image == null:
		_fail("active display renderer did not provide a viewport image")
		return
	var error := image.save_png(path)
	if error != OK:
		_fail("failed to save %s" % path)


func _fail(message: String) -> void:
	push_error("CROWN_LINE_INGAME_CAPTURE: %s" % message)
	quit(1)
