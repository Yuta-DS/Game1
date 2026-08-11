extends SceneTree

const TARGET := Vector3(-51.4, 94.0, 27.41)
const RADIUS := 70.0
const CAMERA_Y := 101.0
const LABELS := [
	"000_front", "030_front_right", "060_front_right",
	"090_right", "120_back_right", "150_back_right",
	"180_back", "210_back_left", "240_back_left",
	"270_left", "300_front_left", "330_front_left",
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _i in 72:
		await process_frame
	for node in hub.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false

	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.far = 1000.0
	hub.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts/castle_360")

	for index in LABELS.size():
		var angle := deg_to_rad(float(index) * 30.0)
		camera.global_position = Vector3(
			TARGET.x + cos(angle) * RADIUS,
			CAMERA_Y,
			TARGET.z + sin(angle) * RADIUS)
		camera.look_at(TARGET, Vector3.UP)
		for _i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://artifacts/castle_360/castle_%s.png" % LABELS[index]
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("CASTLE_360: failed %s (%s)" % [path, error_string(error)])
			quit(error)
			return
		print("CASTLE_360: wrote %s" % path)

	print("CASTLE_360: PASS — wrote 12 angles")
	quit()
