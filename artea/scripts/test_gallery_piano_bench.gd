extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	current_scene = gallery
	for frame in 10: await physics_frame
	var piano = gallery.get_node("GrandPiano")
	var player = gallery.get_node("Player3D")
	player.set_physics_process(false)
	assert(piano.has_node("PianoBench") and piano.start_in_keyboard_view)
	player.global_position = piano.to_global(Vector3(0, 0.3, 0.95))
	var standing: Transform3D = player.global_transform
	for frame in 4: await physics_frame
	var q := InputEventAction.new()
	q.action = "interact"
	q.pressed = true
	piano._unhandled_input(q)
	for frame in 4: await physics_frame
	assert(piano._seated and piano._keyboard_view and player.is_seated() and player._sit_pose_applied)
	assert(player.global_position.distance_to(piano.to_global(piano.BENCH_TOP)) < 0.01)
	var camera = gallery.get_node("Camera3D")
	var expected_focus: Vector3 = piano.to_global(piano.SEAT_FOCUS)
	assert(camera._inspect_focus.distance_to(expected_focus) < 0.01, "Gallery keeps its close keyboard framing")
	await create_timer(0.7).timeout
	var note_count: int = piano._voice_index
	var key_mesh := piano._keys[60].get_child(0) as MeshInstance3D
	var pixel: Vector2 = camera.unproject_position(key_mesh.to_global(Vector3(0, 0.012, 0.055)))
	assert(root.get_visible_rect().has_point(pixel), "Middle C remains visible and clickable")
	piano._strike_at(pixel, true)
	assert(piano._voice_index != note_count, "Clicking the visible keyboard sounds a real note")
	var seat_position: Vector3 = player.global_position
	piano._stand_up()
	assert(piano._dismounting and not player.is_seated() and not player.input_enabled)
	await create_timer(0.15).timeout
	assert(player.global_position.distance_to(seat_position) > 0.01, "Player visibly steps down from the seat")
	await create_timer(0.3).timeout
	assert(not piano._dismounting and player.input_enabled and not player._sit_pose_applied)
	assert(player.global_transform.origin.distance_to(standing.origin) < 0.01)
	gallery.queue_free()
	await process_frame
	print("GALLERY PIANO BENCH: PASS")
	quit()
