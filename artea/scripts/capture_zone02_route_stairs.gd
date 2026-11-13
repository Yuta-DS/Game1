extends SceneTree

## Renders every route access flight near Zone 02 (Living Network Forest).
##
## The route stairs are built by the deferred _build_route_access_stairs() pass,
## which raycasts the finished world and drops a flight at each rise the player
## cannot walk up. Because their positions are discovered at runtime rather than
## authored, this resolves them from the live tree instead of hard-coded points.

const ZONE_ID := "02_living_network_forest"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var world := (load("res://scenes/art_castle_floating_world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	# The deferred stair pass needs the physics server to settle first.
	for _i in 150:
		await process_frame
		await physics_frame

	var world_one := world.get_node_or_null("MindSparkWorldOne")
	if world_one == null:
		push_error("ZONE02_CAPTURE: MindSparkWorldOne missing")
		quit(1)
		return

	var zone_local: Vector3 = world_one.get_zone_position(ZONE_ID)
	var zone_radius: float = world_one.get_zone_radius(ZONE_ID)
	var zone: Vector3 = (world_one as Node3D).to_global(zone_local)
	print("ZONE02_CAPTURE: zone=%s radius=%.1f" % [zone, zone_radius])

	var geometry := world_one.get_node_or_null("WorldOneGeometry") as Node3D
	if geometry == null:
		push_error("ZONE02_CAPTURE: WorldOneGeometry missing")
		quit(1)
		return

	# Collect the route flights that sit within reach of the zone.
	var flights: Array = []
	for child in geometry.get_children():
		var flight := child as Node3D
		if flight == null or not str(flight.name).begins_with("RouteStairs_"):
			continue
		var centre: Vector3 = flight.global_position
		var ramp := flight.get_node_or_null("StationStairRamp") as MeshInstance3D
		if ramp != null:
			centre = ramp.global_position
		if centre.distance_to(zone) <= zone_radius + 260.0:
			flights.append([str(flight.name), flight, centre])
	flights.sort_custom(func(a, b): return a[2].distance_to(zone) < b[2].distance_to(zone))
	print("ZONE02_CAPTURE: %d route flights near the zone" % flights.size())

	for node in world.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false

	var camera := Camera3D.new()
	camera.fov = 60.0
	camera.near = 0.05
	camera.far = 6000.0
	world.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts/zone02_route_stairs")

	if flights.is_empty():
		push_error("ZONE02_CAPTURE: no route flights found near Zone 02")
		quit(1)
		return

	for entry in flights:
		var label: String = entry[0]
		var flight: Node3D = entry[1]
		var centre: Vector3 = entry[2]
		var step_count: int = int(flight.get_meta("step_count", 0))
		var max_riser: float = float(flight.get_meta("max_riser", 0.0))
		print("ZONE02_CAPTURE: %s at %s steps=%d riser=%.2f dist_to_zone=%.1f"
			% [label, centre, step_count, max_riser, centre.distance_to(zone)])

		# Two angles per flight: a side elevation that shows whether the foot and
		# the head actually meet ground, and a low three-quarter that exposes
		# clipping into whatever the flight lands on.
		var shots := {
			"side": centre + Vector3(46.0, 20.0, 0.0),
			"quarter": centre + Vector3(32.0, 12.0, -34.0),
		}
		for view in shots:
			camera.global_position = shots[view]
			camera.look_at(centre, Vector3.UP)
			for _i in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			var path := "res://artifacts/zone02_route_stairs/%s_%s.png" % [label, view]
			var error := root.get_texture().get_image().save_png(path)
			if error != OK:
				push_error("ZONE02_CAPTURE: failed %s (%s)" % [path, error_string(error)])
				quit(error)
				return
			print("ZONE02_CAPTURE: wrote %s" % path)

	print("ZONE02_CAPTURE: PASS — %d flights" % flights.size())
	quit()
