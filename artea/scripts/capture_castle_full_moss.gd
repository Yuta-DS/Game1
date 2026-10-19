extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280,900)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.set_physics_process(false)
	player.global_position = Vector3(-31.1,69.18,27.41)
	for frame in 100:
		await process_frame
		await physics_frame
	for layer: CanvasLayer in hub.find_children("*","CanvasLayer",true,false):
		layer.hide()
	var camera := Camera3D.new()
	camera.fov = 52
	camera.near = 0.05
	camera.far = 2000
	hub.add_child(camera)
	camera.make_current()
	var shots := [
		["01_bottom_to_top",Vector3(35,61,66),Vector3(-1.4,47,27.41)],
		["02_ground_approach",Vector3(19,34,45),Vector3(-1.4,31,27.41)],
		["03_middle_stair",Vector3(15,52,44),Vector3(-1.4,46,27.41)],
		["04_rooftop",Vector3(10,78,40),Vector3(-4,68.6,27.4)],
		["05_upper_castle_stair",Vector3(-14,78,40),Vector3(-30,73,27.41)],
	]
	# Frame the actual ground approach from its walking datum; an unrelated
	# watchtower blocks the older fixed camera location at this height.
	var stair := hub.get_node("CastleStairs/CastleStair")
	var entry := stair.get_node("GroundedCastleEntry") as Node3D
	var from: Vector3 = entry.get_meta("surface_start")
	var to: Vector3 = entry.get_meta("surface_end")
	var outward := (from-to).normalized()
	shots[1] = ["02_ground_approach",from+outward*1.6+Vector3.UP*3.3,to+Vector3.UP*1.2]
	DirAccess.make_dir_recursive_absolute("res://artifacts/castle_full_moss")
	for shot in shots:
		camera.global_position = shot[1]
		camera.look_at(shot[2],Vector3.UP)
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://artifacts/castle_full_moss/%s.png" % shot[0]
		if root.get_texture().get_image().save_png(path) != OK:
			push_error("FULL_MOSS_CAPTURE: failed to save " + path)
			quit(1)
			return
		print("FULL_MOSS_CAPTURE: " + path)
	quit(0)
