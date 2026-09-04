extends SceneTree

## Renders the Art Castle stair crown and the skyrail Grand Station from the
## angles the bug screenshots were taken at, so the reported clipping, gaps and
## z-fighting can be inspected directly instead of inferred from tests.

const CROWN := Vector3(-1.4, 67.73, 27.41)
const STATION := Vector3(-22.0, 66.15, 52.0)
const GROUND_ENTRY := Vector3(5.1, 27.2, 24.4)

const SHOTS := [
	# label, camera position, look-at target
	["01_stair_from_deck", Vector3(14.0, 72.0, 40.0), CROWN],
	["02_stair_side", Vector3(24.0, 70.5, 27.41), CROWN],
	["03_stair_foot_up", Vector3(-1.4, 69.0, 46.0), Vector3(-1.4, 68.6, 27.41)],
	["04_stair_top_down", Vector3(-1.4, 78.0, 44.0), CROWN],
	["05_station_wide", Vector3(-2.0, 74.0, 72.0), STATION],
	["06_station_deck", Vector3(-22.0, 69.5, 68.0), STATION],
	["07_station_stair_junction", Vector3(6.0, 73.0, 56.0), Vector3(-12.0, 67.5, 40.0)],
	["08_crown_gate", Vector3(-14.0, 71.0, 38.0), Vector3(-6.0, 68.2, 27.41)],
	["09_grounded_castle_entry", Vector3(13.0, 31.5, 15.0), GROUND_ENTRY],
	["10_crown_fountain", Vector3(-1.4, 73.8, 38.5), CROWN],
	["11_crown_beneath_surface", Vector3(8.0, 64.0, 41.0),
		Vector3(-1.4, 67.15, 27.41)],
	["12_spiral_finished_soffit", Vector3(14.0, 50.0, 39.0),
		Vector3(-1.4, 49.0, 27.41)],
	["13_spiral_soffit_edge_close", Vector3(3.1, 50.5, 31.0),
		Vector3(6.2, 53.0, 27.41)],
	["14_inner_barrier_finished_edge", Vector3(-1.4, 78.0, 44.0),
		Vector3(-1.4, 67.8, 27.41)],
	["15_clean_rooftop_stair_barrier", Vector3(-1.4, 77.0, 38.5),
		Vector3(-1.4, 68.0, 27.41)],
	["16_rooftop_stair_arrival_safety", Vector3(-11.0, 74.5, 36.5),
		Vector3(-5.2, 68.3, 32.6)],
	["17_rooftop_guard_alignment", Vector3(-2.6, 70.8, 29.0),
		Vector3(-5.4, 68.4, 32.8)],
	["18_rooftop_garden_detail", Vector3(-3.8, 71.4, 25.8),
		Vector3(-1.4, 68.3, 20.6)],
	["19_royal_rooftop_garden", Vector3(1.0, 73.7, 29.5),
		Vector3(-1.4, 68.0, 23.0)],
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	# The stair, skyrail and scatter passes all build over several frames.
	for _i in 120:
		await process_frame
		await physics_frame

	for node in hub.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false

	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.05
	camera.far = 4000.0
	hub.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts/castle_stairs_station")

	var captured := 0
	var shots := SHOTS.duplicate()
	var fountain := hub.get_node_or_null("CastleStairs/CastleStair/CastleRoyalFountain") as Node3D
	if fountain != null:
		shots.append(["20_royal_fountain_detail", fountain.global_position + Vector3(3.5, 3.4, 4.8),
			fountain.global_position + Vector3.UP * 0.9])
	var bridge := hub.find_child("CastleMasonryCauseway", true, false) as Node3D
	if bridge != null:
		shots.append(["21_masonry_bridge", bridge.global_position + Vector3(1.5, 5.2, 8.6),
			bridge.global_position + Vector3.UP * 0.3])
		shots.append(["22_masonry_bridge_underside", bridge.global_position + Vector3(1.4, -2.5, 8.0),
			bridge.global_position - Vector3.UP * 0.45])
	var flower_bed := hub.find_child("RooftopFlowerBed_1", true, false) as Node3D
	if flower_bed != null:
		shots.append(["23_veined_royal_flowers", flower_bed.to_global(Vector3(0.75, 1.4, -1.8)),
			flower_bed.to_global(Vector3(0, 0.5, 0))])
	for shot in shots:
		var label: String = shot[0]
		if OS.get_cmdline_user_args().has("--roof-only") and int(label.left(2)) < 15:
			continue
		var eye: Vector3 = shot[1]
		var target: Vector3 = shot[2]
		camera.global_position = eye
		camera.look_at(target, Vector3.UP)
		for _i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://artifacts/castle_stairs_station/%s.png" % label
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("CASTLE_STATION_CAPTURE: failed %s (%s)" % [path, error_string(error)])
			quit(error)
			return
		print("CASTLE_STATION_CAPTURE: wrote %s" % path)
		captured += 1
	if fountain != null and OS.get_cmdline_user_args().has("--water-motion"):
		camera.global_position = fountain.global_position + Vector3(2.8, 2.8, 3.4)
		camera.look_at(fountain.global_position + Vector3.UP * 1.1)
		DirAccess.make_dir_recursive_absolute("res://artifacts/royal_garden_refinement/water_frames")
		for frame in 36:
			await create_timer(1.0 / 9.0).timeout
			await RenderingServer.frame_post_draw
			var frame_image := root.get_texture().get_image()
			frame_image.resize(768, 432, Image.INTERPOLATE_LANCZOS)
			var error := frame_image.save_png("res://artifacts/royal_garden_refinement/water_frames/%03d.png" % frame)
			if error != OK:
				push_error("CASTLE_STATION_CAPTURE: animation frame write failed")
				quit(1)
				return
		print("CASTLE_STATION_CAPTURE: water animation — 36 live rendered frames")

	print("CASTLE_STATION_CAPTURE: PASS — wrote %d shots" % captured)
	quit()
