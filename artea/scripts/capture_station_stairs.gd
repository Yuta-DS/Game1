extends SceneTree

## Renders the Mind Spark station access flight from a few angles so the stair
## repair can be checked visually, not only through the physics tests.

const SHOTS := [
	# label, offset from the stair mid-point, look-at bias along the climb
	["01_side", Vector3(70.0, 18.0, 0.0), 0.0],
	["02_foot", Vector3(0.0, 12.0, -70.0), 0.4],
	["03_landing", Vector3(0.0, 26.0, 78.0), -0.3],
	["04_three_quarter", Vector3(58.0, 30.0, -52.0), 0.1],
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var world := (load("res://scenes/art_castle_floating_world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for _i in 60:
		await process_frame

	var world_one := world.get_node_or_null("MindSparkWorldOne")
	if world_one == null:
		push_error("STATION_STAIRS_CAPTURE: MindSparkWorldOne missing")
		quit(1)
		return
	world_one.set_station_spur_available(true)
	for _i in 12:
		await process_frame

	var spur := world_one.get_node_or_null(
		"WorldOneGeometry/OptionalCompletedWorldStationSpur") as Node3D
	if spur == null:
		push_error("STATION_STAIRS_CAPTURE: station spur missing")
		quit(1)
		return
	var stairs := spur.get_node_or_null("StationAccessStairs") as Node3D
	if stairs == null:
		push_error("STATION_STAIRS_CAPTURE: access stairs missing")
		quit(1)
		return

	var step_count: int = int(stairs.get_meta("step_count"))
	var foot: Vector3 = spur.to_global(
		(stairs.get_node("StationStep_01") as MeshInstance3D).position)
	var landing: Vector3 = spur.to_global(
		(stairs.get_node("StationStep_%02d" % step_count) as MeshInstance3D).position)
	var middle: Vector3 = foot.lerp(landing, 0.5)
	print("STATION_STAIRS_CAPTURE: foot=%s landing=%s steps=%d" % [foot, landing, step_count])

	for node in world.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false

	var camera := Camera3D.new()
	camera.fov = 60.0
	camera.far = 4000.0
	world.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts/station_stairs")

	for shot in SHOTS:
		var label: String = shot[0]
		var offset: Vector3 = shot[1]
		var bias: float = shot[2]
		camera.global_position = middle + offset
		camera.look_at(foot.lerp(landing, 0.5 + bias), Vector3.UP)
		for _i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://artifacts/station_stairs/stairs_%s.png" % label
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("STATION_STAIRS_CAPTURE: failed %s (%s)" % [path, error_string(error)])
			quit(error)
			return
		print("STATION_STAIRS_CAPTURE: wrote %s" % path)

	print("STATION_STAIRS_CAPTURE: PASS — wrote %d shots" % SHOTS.size())
	quit()
