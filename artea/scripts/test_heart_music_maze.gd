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
	assert(route.size() >= 40, "Finding the fountain must require searching winding passages")
	var turns := 0
	for index in range(2, route.size()):
		if route[index] - route[index - 1] != route[index - 1] - route[index - 2]: turns += 1
	assert(turns >= 8, "The fountain route needs turns, not a long straight corridor")
	var dead_ends := 0
	for cell in maze.passages:
		if maze.passages[cell].size() == 1: dead_ends += 1
	assert(dead_ends >= 15, "Wrong turns must give the player something to explore")
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
	assert(player.test_move(player.global_transform, Vector3(0, 0, 298)), "The old straight bypass must now lead into hedge passages")
	var music_route: Array = maze.route_to(maze.MUSIC_EXIT)
	assert(music_route.size() >= 40, "The instrument entrance must also require searching")
	player.global_position = maze.to_global(maze.cell_position(music_route[0]) + Vector3.UP)
	for index in range(1, music_route.size()):
		var target: Vector3 = maze.to_global(maze.cell_position(music_route[index]) + Vector3.UP)
		assert(not player.test_move(player.global_transform, target - player.global_position), "The instrument route must remain physically traversable")
		player.global_position = target
		await physics_frame
	var circle_entry: Vector3 = maze.to_global(maze.cell_position(maze.MUSIC_EXIT) + Vector3(0, 1, maze.CELL * 1.5))
	assert(not player.test_move(player.global_transform, circle_entry - player.global_position), "The maze exit must open into the instrument area")
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
	assert(music.volume_db == -12 and music.unit_size == 12 and music.max_distance == 72 and music.max_db == -10, "Maze fountain stays gentle nearby and fades on retreat")
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
