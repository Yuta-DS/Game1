extends SceneTree

const OUTPUT := "res://artifacts/mind_spark_southern_quarter"
const LABELS := ["04_arrival_southeast", "05_arrival_south", "06_arrival_southwest"]
const ROTATIONS := [135.0, 180.0, 225.0]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 18:
		await process_frame
	for canvas in gallery.find_children("*", "CanvasLayer", true, false):
		(canvas as CanvasLayer).visible = false
	var floating_world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var regions := floating_world.get_node_or_null("KingdomRegions3000m") as Node3D
	if regions != null:
		regions.visible = false
	var forecourt := floating_world.get_node(
		"MindSparkDistrict/MindSparkCeremonialForecourt") as Node3D
	var camera := gallery.get_node("Camera3D") as Camera3D
	camera.set_script(null)
	camera.near = 0.2
	camera.far = 5000.0
	camera.fov = 62.0
	camera.make_current()
	var eye := forecourt.to_global(Vector3(0.0, 6.8, -58.0))
	var north := (forecourt.global_position - eye) * Vector3(1.0, 0.0, 1.0)
	north = north.normalized()
	camera.global_position = eye
	for index in LABELS.size():
		var direction := north.rotated(Vector3.UP, deg_to_rad(ROTATIONS[index]))
		camera.look_at(eye + direction * 80.0 + Vector3.UP * 1.6, Vector3.UP)
		for _frame in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [OUTPUT, LABELS[index]]
		assert(root.get_texture().get_image().save_png(path) == OK)
		print("MIND_SPARK_SOUTHERN_QUARTER_CAPTURE: wrote %s" % path)
	print("MIND_SPARK_SOUTHERN_QUARTER_CAPTURE: PASS")
	quit()
