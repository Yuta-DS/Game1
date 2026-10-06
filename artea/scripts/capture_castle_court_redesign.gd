extends SceneTree

const SHOTS := [
	["01_court_fire_and_castle", Vector3(-7.0, 75.0, 14.0), Vector3(-27.0, 72.0, 27.41)],
	["02_live_fire_close", Vector3(-25.0, 74.0, 41.0), Vector3(-21.3, 69.3, 27.41)],
	["03_commander_upper_court", Vector3(-27.0, 83.0, 43.0), Vector3(-38.3, 79.0, 29.4)],
	["04_stair_village_style", Vector3(24.0, 70.5, 27.41), Vector3(-1.4, 67.73, 27.41)],
	["05_hearth_ward_overhead", Vector3(-20.0, 82.0, 40.0), Vector3(-21.3, 68.6, 27.41)],
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 120:
		await process_frame
		await physics_frame
	for canvas_candidate in hub.find_children("*", "CanvasLayer", true, false):
		(canvas_candidate as CanvasLayer).visible = false
	var fire := hub.get_node_or_null("CastleEntrance/CastleEntrance/CastleCourtyardFire") as Node3D
	var commander := hub.get_node_or_null("Knight2") as Node3D
	var hearth := fire.get_node_or_null("CourtyardFireHearth") as Node3D if fire != null else null
	print("CASTLE_COURT_CAPTURE: fire=", hearth.global_position if hearth != null else Vector3.ZERO,
		" commander=", commander.global_position if commander != null else Vector3.ZERO)

	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.05
	camera.far = 2000.0
	hub.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts/castle_court_redesign")

	for shot in SHOTS:
		camera.global_position = shot[1] as Vector3
		camera.look_at(shot[2] as Vector3, Vector3.UP)
		for _frame in 10:
			await process_frame
			await RenderingServer.frame_post_draw
		var path := "res://artifacts/castle_court_redesign/%s.png" % String(shot[0])
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("CASTLE_COURT_CAPTURE: failed %s" % path)
			quit(error)
			return
		print("CASTLE_COURT_CAPTURE: wrote %s" % path)

	print("CASTLE_COURT_CAPTURE: PASS")
	quit()
