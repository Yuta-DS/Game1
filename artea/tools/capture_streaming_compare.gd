extends SceneTree

# Renders the castle interior with the streaming director active and again with
# it disabled, from the same cameras, so the culling can be judged by looking at
# it rather than by trusting node counts. Re-run this after changing
# world_streaming_director.gd's SIZE_FACTOR or MIN_VIEW_DISTANCE.

const SHOTS := [
	# Standing on the gallery floor, looking north out of the room - the view
	# the player actually has while inside the castle.
	{"name": "inside_north", "pos": Vector3(0.0, 6.0, 40.0),
		"at": Vector3(0.0, 4.0, -200.0), "fov": 68.0},
	# In the doorway looking out across the approach bridge to the world.
	{"name": "doorway_out", "pos": Vector3(0.0, 12.0, 10.0),
		"at": Vector3(0.0, 0.0, -400.0), "fov": 75.0},
	# High and back, so anything that pops out of the distance is obvious.
	{"name": "wide_vista", "pos": Vector3(120.0, 140.0, 220.0),
		"at": Vector3(0.0, 0.0, -600.0), "fov": 70.0},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("res://artifacts/streaming_compare")
	await _capture_set(true, "on")
	await _capture_set(false, "off")
	print("STREAMING_COMPARE: PASS")
	quit()


func _capture_set(director_enabled: bool, suffix: String) -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _i in 90:
		await process_frame
	var director := gallery.find_child("WorldStreamingDirector", true, false)
	if director == null:
		push_error("STREAMING_COMPARE: no director found")
	elif not director_enabled:
		# Put the world back to how it drew before: stop the director and show
		# every cell it is managing. Cells it never managed (already-hidden
		# geometry) stay hidden, which is exactly the baseline.
		director.set_process(false)
		director.call("show_all_managed_cells")
		for _i in 10:
			await process_frame
	if director != null:
		print("[%s] cells=%d visible_cells=%d visible_instances=%d" % [
			suffix, director.call("get_cell_count"),
			director.call("get_visible_cell_count"), _visible_count(gallery)])
	for node in gallery.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	var camera := gallery.get_node("Camera3D") as Camera3D
	camera.set_script(null)
	camera.far = 4000.0
	for shot in SHOTS:
		camera.fov = shot["fov"]
		camera.global_position = shot["pos"]
		camera.look_at(shot["at"], Vector3.UP)
		await _save("res://artifacts/streaming_compare/%s_%s.png" % [shot["name"], suffix])
	gallery.queue_free()
	await process_frame


func _visible_count(scene: Node) -> int:
	var total := 0
	var stack: Array = [scene]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is VisualInstance3D and not (n is Light3D) and (n as Node3D).is_visible_in_tree():
			total += 1
	return total


func _save(path: String) -> void:
	for _i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("STREAMING_COMPARE: failed %s" % path)
