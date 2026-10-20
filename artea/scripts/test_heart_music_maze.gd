extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	current_scene = gallery
	for frame in 10:
		await physics_frame
		await process_frame
	var platform := gallery.get_node("ArtCastleFloatingWorld/KingdomRegions3000m/HeartKingdomPlatform")
	var maze := platform.get_node("HeartMusicMaze")
	var piano := platform.get_node("HeartMusicCircle/Playable_piano")
	var player := gallery.get_node("Player3D") as CharacterBody3D
	player.set_physics_process(false)
	assert(maze.passages.size() > 300, "Maze must cover the broad court rather than a tiny corner")
	for cell in maze.passages:
		assert(not maze.route_to(cell).is_empty(), "Every corridor must be reachable")
	for wall in maze.walls:
		var point: Vector3 = wall.position
		var size: Vector3 = wall.size
		assert(Vector2(point.x, point.z).length() - Vector2(size.x, size.z).length() * 0.5 > 118.0, "Hedges cannot encroach on the instrument circle")
	# Sweep the actual gallery player's walking capsule through the solution.
	# Stop beside the fountain instead of trying to walk through its stone basin.
	var route: Array = maze.route_to(maze.FOUNTAIN_CELL)
	assert(route.size() > 4)
	player.global_position = maze.to_global(maze.cell_position(route[0]) + Vector3.UP)
	for index in range(1, route.size() - 1):
		var target: Vector3 = maze.to_global(maze.cell_position(route[index]) + Vector3.UP)
		assert(not player.test_move(player.global_transform, target - player.global_position), "A solved corridor must be physically traversable")
		player.global_position = target
		await physics_frame
		await process_frame
	assert(maze.completed, "Reaching the fountain court must register completion")
	var wall: Dictionary = maze.walls[0]
	var normal := Vector3.RIGHT if wall.size.x < wall.size.z else Vector3.BACK
	player.global_position = maze.to_global(wall.position - normal * 6)
	assert(player.test_move(player.global_transform, normal * 12), "Real hedge collision must prevent walking through walls")
	player.global_position = maze.to_global(Vector3(96, 1, -410))
	assert(not player.test_move(player.global_transform, Vector3(0, 0, 298)), "The open promenade must reach the instrument circle without solving the maze")
	player.global_position = maze.to_global(maze.cell_position(maze.FOUNTAIN_CELL + Vector2i.RIGHT) + Vector3.UP)
	await process_frame
	var q := InputEventAction.new()
	q.action = "interact"
	q.pressed = true
	maze._unhandled_input(q)
	assert(player.global_position.distance_to(maze.to_global(maze.entrance_position() + Vector3.UP * 0.5)) < 0.01, "The maze's return action must always provide an escape")
	var fountain := platform.get_node("HeartArrivalGarden/MusicalFountain")
	var music := fountain.get_node("FountainMusic") as AudioStreamPlayer3D
	assert(music.stream != null and music.playing and music.max_distance <= 120.0)
	assert(music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.stream.get_length() > 15)
	assert(fountain.global_position.distance_to(maze.to_global(maze.fountain_position())) < 0.03)
	# Use the fully rigged gallery fox, not the simple controller fixture.
	player.global_position = piano.to_global(Vector3(0, 0.3, 0.5))
	for frame in 4: await physics_frame
	var standing := player.global_transform
	piano._sit_down()
	await process_frame
	assert(player.is_seated() and player._sit_pose_applied and not player.input_enabled)
	assert(player.global_position.distance_to(piano.to_global(piano.BENCH_TOP)) < 0.01)
	for frame in 4: await physics_frame
	assert(piano._seated, "Disabling the seated capsule must not auto-exit the piano")
	piano._stand_up()
	assert(not player.is_seated() and not player._sit_pose_applied and player.input_enabled)
	assert(player.global_position.distance_to(standing.origin) < 0.01)
	var connection := gallery.get_node("ArtCastleFloatingWorld/StoryCrownRailway/HeartMelodyConnection")
	var guide = connection.island.milo_guide
	player.global_position = maze.to_global(maze.cell_position(maze.ENTRANCE) + Vector3.UP)
	assert(guide.station_approach(), "Arrival guidance must continue into the maze court")
	assert(guide.play_line("station") and guide.voice.playing)
	var transcript := " ".join(guide._pages)
	assert(transcript.contains("maze") and transcript.contains("raised, flower-lined path"))
	assert(guide.caption.text.length() < 180, "Only the current short transcript page is visible")
	assert(player.input_enabled, "Milo's directions must not lock exploration")
	guide.stop()
	print("HEART MUSIC MAZE: PASS — connected passages, capsule traversal, solid hedges, fountain music, real bench pose and Milo directions")
	gallery.queue_free()
	await process_frame
	quit()
