extends SceneTree

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
	var player := Node3D.new()
	player.name = "CameraTarget"
	world.add_child(player)
	var railway := Node3D.new()
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	var train := railway.get_node("RainbowGalaxyTrain") as Node3D
	var views := train.get_node("TrainTankViews")
	var exterior := views.get_node("OriginalTankShell") as MeshInstance3D
	var low := views.get_node("FPSTankShell") as MeshInstance3D
	var original_barrel := _barrel_bounds(exterior, train)
	var fps_barrel := _barrel_bounds(low, train)
	print("TANK_BOUNDS original=", original_barrel, " fps=", fps_barrel)
	_check(original_barrel.size.x > 4.0 and original_barrel.size.y > 4.0, "Restore the full-size pearl-and-gold boiler")
	_check(absf(fps_barrel.size.x / original_barrel.size.x - .65) < .0001 \
		and absf(fps_barrel.size.y / original_barrel.size.y - .65) < .0001, "Keep the same 65% FPS clearance model")
	_check(absf(original_barrel.get_center().y - 4.72) < .001, "Original tank returns to its authored height")
	_check(absf(fps_barrel.get_center().y - (4.72 * .65 - .268)) < .001, "FPS tank retains its previous position")
	_check(absf(original_barrel.size.z - fps_barrel.size.z) < .001, "Tank length is unchanged between views")
	_check(exterior.mesh.get_faces().size() == low.mesh.get_faces().size(), "Keep every tank triangle in both variants")
	_check(views.exterior_parts.size() == 16 and views.fps_parts.size() == 16, "One shell plus fifteen matching native tank trims per view")
	_check(views.moving_mounts.size() > 6, "Moving tank fixtures keep shared animation pivots")
	var camera := Camera3D.new()
	camera.set_script(load("res://scripts/CameraFollow.gd"))
	camera.set("player_path", NodePath("../CameraTarget"))
	camera.set("capture_mouse", false)
	world.add_child(camera)
	await process_frame
	await process_frame
	_check(not views.first_person_active and exterior.visible and not low.visible, "Walking/third-person shows only original tank")
	camera.call("begin_ride_view", 18.0)
	camera.call("configure_driver_view", train, Vector3(0, 4.73, -15.665))
	for cycle in 8:
		camera.call("set_view_mode", "first")
		await process_frame
		await process_frame
		_check(views.first_person_active and low.visible and not exterior.visible, "Driver FPS shows only clearance tank")
		_check(is_equal_approx(camera.fov, 95.0) and is_equal_approx(float(camera.get("driver_initial_pitch_degrees")), -4.0), "Camera FOV and initial pitch stay exactly unchanged")
		for mount: Node3D in views.moving_mounts:
			_check(mount.transform.is_equal_approx(mount.get_meta("fps_fit")), "FPS fixtures follow the tank without altered animation pivots")
		for i in views.exterior_parts.size():
			_check(not views.exterior_parts[i].visible and views.fps_parts[i].visible, "Never render both tank variants at once")
		camera.call("set_view_mode", "third")
		await process_frame
		await process_frame
		_check(not views.first_person_active and exterior.visible and not low.visible, "Third-person restores original tank")
		for mount: Node3D in views.moving_mounts:
			_check(mount.transform.is_equal_approx(Transform3D.IDENTITY), "Exterior fixtures return to original placement without drift")
	camera.call("set_view_mode", "first")
	camera.call("enter_inspect", train)
	await process_frame
	await process_frame
	_check(not views.first_person_active, "Inspection shows original tank even if previous view was FPS")
	camera.call("exit_inspect")
	await process_frame
	await process_frame
	_check(views.first_person_active, "Leaving inspection restores driver FPS tank")
	camera.call("end_ride_view")
	await process_frame
	await process_frame
	_check(not views.first_person_active, "Disembarking restores original tank")
	camera.call("begin_ride_view", 14.0)
	camera.call("set_view_mode", "first")
	await process_frame
	await process_frame
	_check(not views.first_person_active, "Passenger FPS does not inherit the driver cutaway")
	camera.call("configure_driver_view", train, Vector3.ZERO)
	await process_frame
	await process_frame
	var inspection := Camera3D.new()
	world.add_child(inspection)
	inspection.make_current()
	await process_frame
	await process_frame
	_check(not views.first_person_active, "External capture camera sees original tank")
	_check(_barrel_bounds(exterior, train).is_equal_approx(original_barrel), "Repeated view switches never resize original mesh")
	print("TRAIN_ORIGINAL_TANK_VIEWS: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _barrel_bounds(instance: MeshInstance3D, train: Node3D) -> AABB:
	var pose := train.global_transform.affine_inverse() * instance.global_transform
	var found := false
	var bounds := AABB()
	for surface in instance.mesh.get_surface_count():
		var material := instance.get_active_material(surface)
		if not material.resource_name.to_lower().contains("engine_tank_pearlwhite"):
			continue
		var arrays := instance.mesh.surface_get_arrays(surface)
		for vertex in arrays[Mesh.ARRAY_VERTEX]:
			var point: Vector3 = pose * vertex
			bounds = bounds.expand(point) if found else AABB(point, Vector3.ZERO)
			found = true
	_check(found, "Original pearl tank surface is preserved")
	return bounds

