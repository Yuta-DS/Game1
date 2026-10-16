extends SceneTree

const Covers := preload("res://scripts/train_fps_gear_covers.gd")
const Transmission := preload("res://scripts/train_gear_transmission.gd")
const Sightline := preload("res://scripts/train_sightline_test_probe.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var target := Node3D.new()
	target.name = "CameraTarget"
	world.add_child(target)
	var railway := Node3D.new()
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	railway.set_process(false)
	var train := railway.get_node("RainbowGalaxyTrain") as Node3D
	var views := train.get_node("TrainTankViews")
	var covers := train.get_node("FPSGearHousings") as Node3D
	_check(covers == views.fps_gear_covers and not covers.visible, "Exterior starts with exposed original gears")
	_check(covers.get_child_count() == 2, "Fit exactly one curved surround per side")
	var transmission: RefCounted = railway.get("_gear_transmission")
	_check(transmission.parts.size() == 18, "Keep all original gear, hub and ring animations")
	var parents: Array[Node] = []
	for part: Node3D in transmission.parts:
		parents.append(part.get_parent())
	var camera := Camera3D.new()
	camera.set_script(load("res://scripts/CameraFollow.gd"))
	camera.set("player_path", NodePath("../CameraTarget"))
	camera.set("capture_mouse", false)
	world.add_child(camera)
	camera.call("begin_ride_view", 18.0)
	camera.call("configure_driver_view", train, Vector3(0, 4.7315, -15.6649))
	camera.call("set_view_mode", "first")
	await _frames()
	_check(covers.is_visible_in_tree(), "Actual driver FPS selector enables both surrounds")
	var proxy := Sightline.build(covers, world)
	await physics_frame
	await physics_frame
	var clear_samples := 0
	var through_samples := 0
	var eye := train.to_global(Vector3(0, 4.7315, -15.6649))
	for housing: Node3D in covers.get_children():
		var outline: PackedVector2Array = housing.get_meta("outline")
		var centres: Array = housing.get_meta("swept_centres")
		var radii: Array = housing.get_meta("swept_radii")
		_check(housing.get_node_or_null("PearlTransmissionShell") == null \
			and housing.get_node_or_null("PearlOuterSidePanel") == null \
			and housing.get_node_or_null("OuterServicePanel") == null \
			and housing.get_node_or_null("InsetServicePanel") == null \
			and housing.find_children("OuterLouvre*", "", false, false).is_empty() \
			and housing.find_children("RecessedLouvre*", "", false, false).is_empty(),
			"Neither broad face has a panel or vents")
		for label in ["PearlCurvedSurround"]:
			var panel := housing.get_node(label) as MeshInstance3D
			_check(panel.visible and panel.mesh.get_faces().size() > 0, "Keep the curved pearl top/bottom cover")
			_check((panel.material_override as BaseMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,
				"Retained cover stays solid, not fully transparent or hidden")
		for label in ["InnerGoldGuard", "OuterGoldGuard"]:
			var rail := housing.get_node(label) as MeshInstance3D
			_check(rail.mesh.get_aabb().size.x < .081, "Guard uses a thin 8cm tube, not a side wall")
		for label in ["PearlScallopedInfillInner", "PearlScallopedInfillOuter", "GoldOpeningLipInner", "GoldOpeningLipOuter"]:
			var infill := housing.get_node(label) as MeshInstance3D
			var vertices := infill.mesh.get_faces()
			var filled_area := 0.0
			var minimum_gap := INF
			for face in range(0, vertices.size(), 3):
				var triangle := PackedVector2Array()
				for corner in 3:
					var vertex := vertices[face + corner]
					triangle.append(Vector2(vertex.z, vertex.y))
				filled_area += absf((triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])) * .5
				for gear_index in 3:
					var point := Vector2(centres[gear_index].z, centres[gear_index].y)
					var distance := INF
					if Geometry2D.is_point_in_polygon(point, triangle):
						distance = 0.0
					else:
						for edge in 3:
							distance = minf(distance, point.distance_to(Geometry2D.get_closest_point_to_segment(
								point, triangle[edge], triangle[(edge + 1) % 3])))
					minimum_gap = minf(minimum_gap, distance - radii[gear_index])
			_check(infill.visible and filled_area > .001, "Scalloped trim actually fills the unused case gaps")
			_check(minimum_gap > .14, "Every infill triangle clears all swept gear discs by at least 14 cm")
		for index in [0, 2]:
			var foot := housing.get_node("DeckFoot_%d" % index) as MeshInstance3D
			var bounds := foot.transform * foot.mesh.get_aabb()
			_check(absf(bounds.position.y - Covers.DECK_Y) < .011, "Feet contact the side deck without floating")
			var rail_base := Covers._outline_floor(outline, centres[index].z)
			_check(bounds.end.y > rail_base and bounds.end.y < rail_base + Covers.RAIL_RADIUS,
				"Feet meet the lower rail without extending over the gear teeth")
		for i in 3:
			var centre: Vector3 = centres[i]
			var radius: float = radii[i]
			# Both broad faces must be open; the top and bottom must remain solid.
			var outer_eye := Vector3(signf(centre.x) * (Covers.OUTER_X + 1.0), centre.y, centre.z)
			var outer_query := PhysicsRayQueryParameters3D.create(train.to_global(outer_eye), train.to_global(centre), Sightline.LAYER)
			_check(world.get_world_3d().direct_space_state.intersect_ray(outer_query).is_empty(),
				"Outer face is open at every gear centre")
			var top_query := PhysicsRayQueryParameters3D.create(train.to_global(centre + Vector3.UP * 4.0), train.to_global(centre), Sightline.LAYER)
			_check(not world.get_world_3d().direct_space_state.intersect_ray(top_query).is_empty(),
				"Curved top remains above every gear")
			var bottom_query := PhysicsRayQueryParameters3D.create(train.to_global(centre),
				train.to_global(centre + Vector3.DOWN * 4.0), Sightline.LAYER)
			_check(not world.get_world_3d().direct_space_state.intersect_ray(bottom_query).is_empty(),
				"Curved bottom remains beneath every gear")
			var centre_query := PhysicsRayQueryParameters3D.create(eye, train.to_global(centre), Sightline.LAYER)
			_check(world.get_world_3d().direct_space_state.intersect_ray(centre_query).is_empty(),
				"All six gear centres are visible through the driver-facing opening")
			var gear_clear := 0
			for sample in 96:
				var perimeter := Vector2(centre.z, centre.y) + Vector2.from_angle(TAU * sample / 96.0) * radius
				_check(Geometry2D.is_point_in_polygon(perimeter, outline), "Enclose every gear's full swept circle")
				var clearance := INF
				for edge in outline.size():
					clearance = minf(clearance, perimeter.distance_to(Geometry2D.get_closest_point_to_segment(
						perimeter, outline[edge], outline[(edge + 1) % outline.size()])))
				_check(clearance - Covers.RAIL_RADIUS > .135, "Reserve tube-to-tooth clearance for every rotation phase")
				_check(clearance - Covers.WALL_THICKNESS > .13, "Curved shell stays clear of rotating tooth tips")
				var destination := train.to_global(Vector3(centre.x, perimeter.y, perimeter.x))
				var query := PhysicsRayQueryParameters3D.create(eye, destination, Sightline.LAYER)
				var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
				gear_clear += int(hit.is_empty())
				var through_from := Vector3(signf(centre.x) * (Covers.OUTER_X + 1.0), perimeter.y, perimeter.x)
				var through_to := Vector3(signf(centre.x) * (Covers.INNER_X - 1.0), perimeter.y, perimeter.x)
				var through_query := PhysicsRayQueryParameters3D.create(train.to_global(through_from), train.to_global(through_to), Sightline.LAYER)
				var open := world.get_world_3d().direct_space_state.intersect_ray(through_query).is_empty()
				_check(open, "Both faces stay open across every sampled gear edge")
				through_samples += int(open)
			clear_samples += gear_clear
			print("OPEN_GEAR ", housing.name, " gear=", i, " clear=", gear_clear, "/96")
			_check(gear_clear == 96, "Every sampled gear-edge sightline stays open through the guard")
	proxy.free()
	var saved_cover_pose := covers.transform
	for cycle in 8:
		var before: Transform3D = transmission.parts[0].transform
		transmission.advance(.31 if cycle % 2 == 0 else -.21)
		_check(not transmission.parts[0].transform.is_equal_approx(before), "Visible transmission still rotates forward and backward")
		_check(covers.transform.is_equal_approx(saved_cover_pose), "Curved surround stays fixed while gears rotate")
		for i in transmission.parts.size():
			_check(transmission.parts[i].visible and transmission.parts[i].get_parent() == parents[i],
				"Never hide, replace or reparent the original moving gears")
		camera.call("set_view_mode", "third")
		await _frames()
		_check(not covers.visible, "Third person restores uncovered exterior gears")
		camera.call("set_view_mode", "first")
		await _frames()
		_check(covers.visible, "Repeated first-person entry restores fitted housings")
	camera.call("enter_inspect", train)
	await _frames()
	_check(not covers.visible, "Inspection leaves original exterior unchanged")
	camera.call("exit_inspect")
	await _frames()
	_check(covers.visible, "Leaving inspection restores driver housings")
	camera.call("end_ride_view")
	await _frames()
	_check(not covers.visible, "Disembarking removes FPS-only covers")
	camera.call("begin_ride_view", 14.0)
	await _frames()
	_check(not covers.visible, "Passenger first person does not inherit driver housings")
	print("TRAIN_FPS_GEAR_COVERS: %s checks=%d failures=%d clear_gear_samples=%d/576 through_both_faces=%d/576" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size(), clear_samples, through_samples])
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _frames() -> void:
	await process_frame
	await process_frame
