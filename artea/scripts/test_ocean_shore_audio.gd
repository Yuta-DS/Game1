extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var water := (load("res://scenes/Water.tscn") as PackedScene).instantiate()
	water.position.y = 0.514
	var player := Node3D.new()
	player.add_to_group("Player")
	root.add_child(player)
	root.add_child(water)
	await process_frame
	var ocean := water.get_node("Ocean_System")
	var sound := ocean.get_node("Ocean Sound") as AudioStreamPlayer3D
	assert(ocean.shoreline.size() > 20, "Coastal sound must cover the island rather than two fixed points")
	assert(ocean.get_child_count() == 1, "Only one surf loop plays at a time")
	assert(sound.playing and sound.stream is AudioStreamOggVorbis and sound.stream.loop)
	assert(sound.unit_size == 20 and sound.max_distance == 90 and sound.max_db == -6)
	for point in [Vector3(180, 2, 0), Vector3(-180, 2, 0), Vector3(0, 2, 180), Vector3(0, 2, -180)]:
		player.global_position = point
		ocean._update_shore_source()
		var shore: Vector3 = ocean._target
		player.global_position = shore + Vector3(0, 2, 8)
		ocean._update_shore_source()
		for i in 20: ocean._process(0.1)
		assert(sound.global_position.distance_to(player.global_position) < sound.unit_size, "Surf is audible on every side of the coast")
		assert(absf(sound.global_position.y - 0.514) < 0.01, "Surf stays at sea level rather than following the player's altitude")
	player.global_position = Vector3(0, 300, 0)
	ocean._update_shore_source()
	for i in 20: ocean._process(0.1)
	assert(sound.global_position.distance_to(player.global_position) > sound.max_distance, "Ocean fades outside its coastal listening range")
	assert(root.audio_listener_enable_3d)
	water.queue_free()
	player.queue_free()
	await process_frame
	print("OCEAN SHORE AUDIO: PASS")
	quit()
