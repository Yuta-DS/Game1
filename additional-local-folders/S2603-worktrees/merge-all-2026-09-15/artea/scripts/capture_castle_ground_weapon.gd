extends SceneTree

const SHOTS := [
	["grounded_castle_entry", Vector3(13.0, 31.5, 15.0),
		Vector3(5.1, 27.2, 24.4)],
	["crown_ballista", Vector3(-1.4, 73.8, 38.5),
		Vector3(-1.4, 68.0, 27.41)],
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 20:
		await process_frame
		await physics_frame
	for node in hub.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	# This proof render needs only terrain and the castle complex. Hiding the
	# unrelated districts avoids spending minutes drawing the entire campaign.
	for child in hub.get_children():
		if child is Node3D and String(child.name) not in [
				"Environment", "CastleStairs", "CastleFoundation",
				"CastleEntrance", "building_castle_red2"]:
			(child as Node3D).visible = false
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.05
	camera.far = 1000.0
	hub.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts/castle_ground_weapon")
	for shot in SHOTS:
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		for _frame in 4:
			await process_frame
			await RenderingServer.frame_post_draw
		var path := "res://artifacts/castle_ground_weapon/%s.png" % shot[0]
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("CASTLE_GROUND_WEAPON_CAPTURE: failed %s" % path)
			quit(error)
			return
		print("CASTLE_GROUND_WEAPON_CAPTURE: wrote %s" % path)
	print("CASTLE_GROUND_WEAPON_CAPTURE: PASS")
	quit()
