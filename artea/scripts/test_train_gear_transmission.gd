extends SceneTree

const Transmission := preload("res://scripts/train_gear_transmission.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)

func _angle(before: Basis, after: Basis) -> float:
	var relative := before.inverse() * after
	return atan2(relative.z.x, relative.x.x)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	world.add_child(player)
	var railway := Node3D.new()
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	for frame in 6:
		await process_frame
	railway.set_process(false)
	player.set_physics_process(false)
	var train := railway.get_node("RainbowGalaxyTrain") as Node3D
	var detailed := train.get_node("BlenderCrownLineTrain") as Node3D
	var transmission: RefCounted = railway.get("_gear_transmission")
	_check(transmission.parts.size() == 18, "All six gears, six hubs and six rings must be linked")
	var rest: Array[Transform3D] = []
	for part: Node3D in transmission.parts:
		rest.append(part.transform)
		var train_axle := train.global_basis.inverse() * part.global_basis.y.normalized()
		_check(absf(train_axle.dot(Vector3.RIGHT)) > .9999, "Gear shaft must point across train: " + part.name)
	# Negative control: the old Z rotation tumbles the disc, which this test detects.
	_check(absf((rest[0].basis.rotated(Vector3.BACK, .7)).y.dot(rest[0].basis.y)) < .99, "Axle regression must reject previous Z rotation")
	for side in ["L", "R"]:
		for i in 2:
			var a := detailed.find_child("*Steam%sGear_%s_%d" % [Transmission.KINDS[i], side, i], true, false) as MeshInstance3D
			var b := detailed.find_child("*Steam%sGear_%s_%d" % [Transmission.KINDS[i + 1], side, i + 1], true, false) as MeshInstance3D
			_check(absf(a.position.distance_to(b.position) - Transmission.MODULE * (Transmission.TEETH[i] + Transmission.TEETH[i + 1]) * .5) < .00001, "Pitch circles must meet: " + side + str(i))
			_check(a.get_active_material(0) != null and b.get_active_material(0) != null, "Preserve original gear materials")
	# Sample complete repeating cycle on both sides; polygon intersections use
	# the actual transformed cross-sections, not just angular metadata.
	for sample in 1441:
		transmission.phase = TAU * 14.0 * sample / 1440.0
		transmission.apply_phase()
		for i in transmission.parts.size():
			var part: Node3D = transmission.parts[i]
			_check(part.position.distance_to(rest[i].origin) < .000001, "Gear shaft must not orbit")
			_check(part.basis.y.distance_to(rest[i].basis.y) < .000001, "Gear must not wobble or tumble")
		for side in ["L", "R"]:
			for i in 2:
				var a := detailed.find_child("*Steam%sGear_%s_%d" % [Transmission.KINDS[i], side, i], true, false) as MeshInstance3D
				var b := detailed.find_child("*Steam%sGear_%s_%d" % [Transmission.KINDS[i + 1], side, i + 1], true, false) as MeshInstance3D
				var a_rest: Transform3D = a.get_meta("gear_rest_transform")
				var plane := a_rest.affine_inverse()
				var poly_a := _polygon(Transmission.profile(i), plane * a.transform)
				var poly_b := _polygon(Transmission.profile(i + 1), plane * b.transform)
				var overlaps := Geometry2D.intersect_polygons(poly_a, poly_b)
				var area := 0.0
				for polygon in overlaps:
					area += _area(polygon)
				_check(area < .00001, "Teeth collide: %s pair %d sample %d area %.7f" % [side, i, sample, area])
	# Same integrated input at 30 and 120 Hz, and exact reverse to start.
	transmission.phase = 0.0
	for frame in 30:
		transmission.advance(.8 / 30.0)
	var thirty: Basis = transmission.parts[3].basis
	transmission.phase = 0.0
	for frame in 120:
		transmission.advance(.8 / 120.0)
	_check(thirty.is_equal_approx(transmission.parts[3].basis), "Gear motion must not depend on frame rate")
	transmission.advance(-.8)
	for i in transmission.parts.size():
		_check(transmission.parts[i].transform.is_equal_approx(rest[i]), "Reversing same distance must restore phase")
	transmission.phase = TAU * 14.0 - .01
	transmission.apply_phase()
	var before_wrap: Basis = transmission.parts[3].basis
	transmission.advance(.02)
	_check(absf(_angle(before_wrap, transmission.parts[3].basis) + .03) < .00002, "Phase wrap must not jump a driven gear")

	# Real cab startup, forward throttle, brake, reverse and stop.
	player.global_position = railway.call("get_driver_interaction_position")
	_check(bool(railway.call("board_as_driver")), "Player must board the driver seat")
	var forward_frames := 0
	var reverse_frames := 0
	for command in [1.0, 0.0, -1.0, 0.0]:
		for frame in 360:
			var before: Array[Basis] = []
			for part: Node3D in transmission.parts:
				before.append(part.basis)
			railway.call("drive_manual", command, 1.0 / 60.0)
			railway.call("_update_train_mechanisms", 1.0 / 60.0)
			var angle := _angle(before[0], transmission.parts[0].basis)
			var speed: float = railway.call("get_display_speed_kph")
			if speed > .1:
				var direction: int = railway.get("_drive_motion_direction")
				_check(angle * direction > 0.0, "Gear motion must follow real train direction")
				forward_frames += int(direction > 0)
				reverse_frames += int(direction < 0)
			else:
				_check(absf(angle) < .0001, "Transmission must stop when train stops")
			for i in transmission.parts.size():
				var part: Node3D = transmission.parts[i]
				var expected: float = part.get_meta("mechanism_spin_ratio")
				_check(absf(_angle(before[i], part.basis) - angle * expected) < .00002, "All gear/hub/ring angles must share exact tooth ratio")
	_check(forward_frames > 60 and reverse_frames > 60, "Must exercise actual forward and reverse driving")
	_check(float(railway.call("get_display_speed_kph")) == 0.0, "Train must finish stopped")
	var rod := detailed.find_child("*SteamConnectingRod_L", true, false) as Node3D
	var rod_stopped := rod.transform
	for frame in 30:
		railway.call("_update_train_mechanisms", 1.0 / 60.0)
	_check(rod.transform.is_equal_approx(rod_stopped), "Connecting rods must stop with gears")
	# Autopilot must use its actual travel direction, not the previous driver's
	# reverse selection. A stopped passenger train must not spin while its speed
	# display is still easing down.
	railway.set("_manual_driving", false)
	railway.set("_drive_motion_direction", -1)
	railway.set("_last_train_position", train.global_position + train.global_basis.z * .1)
	var passenger_before: Basis = transmission.parts[0].basis
	railway.call("_update_train_mechanisms", 1.0 / 60.0)
	_check(_angle(passenger_before, transmission.parts[0].basis) > 0.0, "Forward autopilot must not inherit reverse gear direction")
	passenger_before = transmission.parts[0].basis
	railway.call("_update_train_mechanisms", 1.0 / 60.0)
	_check(passenger_before.is_equal_approx(transmission.parts[0].basis), "Stationary autopilot gears must stop despite speed-display easing")
	print("TRAIN_GEAR_TRANSMISSION_TEST: %s checks=%d failures=%d forward_frames=%d reverse_frames=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), forward_frames, reverse_frames])
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _polygon(profile: PackedVector2Array, pose: Transform3D) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point in profile:
		var placed := pose * Vector3(point.x, 0, point.y)
		polygon.append(Vector2(placed.x, placed.z))
	return polygon

func _area(polygon: PackedVector2Array) -> float:
	var sum := 0.0
	for i in polygon.size():
		sum += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return absf(sum) * .5
