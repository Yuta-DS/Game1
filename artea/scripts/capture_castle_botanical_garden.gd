extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.set_physics_process(false)
	player.global_position = Vector3(-30.6, 69.18, 27.41)
	for frame in 100:
		await process_frame
		await physics_frame
	for layer: CanvasLayer in hub.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	var camera := Camera3D.new()
	camera.fov = 54
	camera.near = 0.05
	camera.far = 2000
	hub.add_child(camera)
	camera.make_current()
	var shots := [
		["01_centred_fountain", Vector3(10, 78, 40), Vector3(-4, 68.6, 27.4)],
		["02_spiral_garden", Vector3(16, 66, 44), Vector3(-1.4, 57, 27.41)],
		["03_royal_stair_and_gate", Vector3(-14, 78, 40), Vector3(-30, 73.0, 27.41)],
		["04_castle_garden_overview", Vector3(42, 106, 90), Vector3(-25, 71, 27.41)],
		["06_original_keep", Vector3(-25, 97, 45), Vector3(-48, 89, 27.41)],
	]
	var living := hub.get_node("CastleRoyalBotanicals")
	for anchor: Dictionary in living.get_meta("placement_anchors"):
		if anchor.zone == "SpiralOuter":
			var at: Transform3D = anchor.transform
			var normal := at.basis.z.normalized()
			shots.append(["05_moss_leaf_fibre_detail", at.origin + normal * 3.0 + Vector3.UP * 0.45,
				at.origin - Vector3.UP * 0.25])
			break
	DirAccess.make_dir_recursive_absolute("res://artifacts/castle_botanical_garden")
	for shot in shots:
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://artifacts/castle_botanical_garden/%s.png" % shot[0]
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("BOTANICAL_CAPTURE: " + error_string(error))
			quit(1)
			return
		print("BOTANICAL_CAPTURE: " + path)
	var botanicals := hub.get_node_or_null("CastleRoyalBotanicals")
	if botanicals:
		print("BOTANICAL_CAPTURE: %d clusters, %d triangles, %d draw surfaces" % [
			botanicals.get_meta("cluster_count"), botanicals.get_meta("triangle_count"), botanicals.get_meta("draw_surfaces")])
	quit(0)
