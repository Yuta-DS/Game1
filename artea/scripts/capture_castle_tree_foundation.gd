extends SceneTree

const OUTPUT_PATH := "res://artifacts/castle_tree_foundation.png"
const SUPPORT_OUTPUT_PATH := "res://artifacts/castle_tree_two_area_support.png"
const FACADE_OUTPUT_PATH := "res://artifacts/castle_tree_facade_reference.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/New_Hub_World.tscn") as PackedScene
	var hub := scene.instantiate() as Node3D
	root.add_child(hub)
	for _frame in 48:
		await process_frame

	for node in hub.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false

	var camera := Camera3D.new()
	camera.name = "CastleTreeFoundationCaptureCamera"
	camera.fov = 66.0
	camera.far = 900.0
	hub.add_child(camera)
	camera.make_current()

	DirAccess.make_dir_recursive_absolute("res://artifacts")
	if not await _save_angle(camera, Vector3(-15.0, 34.0, 27.4),
			Vector3(-51.4, 58.0, 27.4), OUTPUT_PATH):
		quit(1)
		return
	if not await _save_angle(camera, Vector3(-10.0, 47.0, 61.0),
			Vector3(-37.0, 71.0, 27.4), SUPPORT_OUTPUT_PATH):
		quit(1)
		return
	if not await _save_angle(camera, Vector3(-8.0, 38.0, 55.0),
			Vector3(-36.0, 72.0, 27.4), FACADE_OUTPUT_PATH):
		quit(1)
		return
	print("CASTLE_TREE_CAPTURE: PASS — wrote overall, support, and facade views")
	quit()


func _save_angle(camera: Camera3D, position: Vector3, target: Vector3,
		path: String) -> bool:
	camera.global_position = position
	camera.look_at(target, Vector3.UP)
	for _frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("CASTLE_TREE_CAPTURE: failed %s (%s)" % [path, error_string(error)])
		return false
	return true
