extends SceneTree

const FRONT_OUTPUT := "res://artifacts/front_castle_bridge_fire_fixed.png"
const STAIR_OUTPUT := "res://artifacts/castle_stair_ground_contact_fixed.png"
const STAIR_CLEARANCE_OUTPUT := "res://artifacts/castle_stair_barrier_clearance_fixed.png"
const STAIR_GROUND_OUTPUT := "res://artifacts/castle_stair_terrain_join_fixed.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(hub)
	for _frame in 48:
		await process_frame
	for layer in hub.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false

	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.far = 700.0
	hub.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts")

	# Player-height bridge approach: joined timber/court, trimmed root, and fire.
	if not await _save(camera, Vector3(-10.8, 71.0, 27.41),
			Vector3(-22.0, 69.7, 27.41), FRONT_OUTPUT):
		quit(1)
		return

	# Terrain-level view of the spiral's first tread after removing the disc/rune.
	var stair := hub.get_node("CastleStairs/CastleStair") as Node3D
	var first_tread := stair.get_node("StairTread_000") as MeshInstance3D
	var target := first_tread.global_position + Vector3(0.0, 2.0, 0.0)
	if not await _save(camera, first_tread.global_position + Vector3(11.0, 4.8, 10.0),
			target, STAIR_OUTPUT):
		quit(1)
		return
	# Closer side view proving that tread and riser ends stop inside the guard.
	if not await _save(camera, first_tread.global_position + Vector3(7.0, 3.0, 5.5),
		first_tread.global_position + Vector3(-1.0, 1.2, 1.1),
		STAIR_CLEARANCE_OUTPUT):
		quit(1)
		return
	# Low player view confirming the fitted entry foundation follows the slope.
	if not await _save(camera, first_tread.global_position + Vector3(8.0, 1.25, 6.0),
		first_tread.global_position + Vector3(-0.5, 0.35, 1.0),
		STAIR_GROUND_OUTPUT):
		quit(1)
		return

	print("FRONT_CASTLE_REPAIR_CAPTURE: PASS — wrote front and stair views")
	quit()


func _save(camera: Camera3D, position: Vector3, target: Vector3, path: String) -> bool:
	camera.global_position = position
	camera.look_at(target, Vector3.UP)
	for _frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("FRONT_CASTLE_REPAIR_CAPTURE: failed %s" % error_string(error))
		return false
	return true
