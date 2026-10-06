extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("CROWN_TRAIN_STEAM_ENGINE_MOTION_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var world := Node3D.new()
	world.name = "ArtCastleFloatingWorld"
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .5
	capsule.height = 1.8
	collision.shape = capsule
	player.add_child(collision)
	world.add_child(player)

	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	for _frame in 12:
		await process_frame

	var train := railway.get_node_or_null("RainbowGalaxyTrain") as Node3D
	var detailed := train.get_node_or_null("BlenderCrownLineTrain") as Node3D \
		if train != null else null
	if detailed == null:
		_fail("playable Blender train was not instantiated")
		return
	var state: Dictionary = railway.call("get_steam_engine_animation_state")
	if int(state.gear_count) < 18 or int(state.rod_count) != 2 \
			or int(state.pressure_count) != 4 or int(state.valve_count) < 7 \
			or int(state.celestial_halo_count) != 2 or not bool(state.has_exhaust):
		_fail("runtime export is missing steam mechanisms, the two halo layers, or exhaust")
		return

	var gear := detailed.find_child("*SteamDriveGear*", true, false) as Node3D
	var rod := detailed.find_child("*SteamConnectingRod*", true, false) as Node3D
	var pressure := detailed.find_child("*SteamPressureOrb*", true, false) as Node3D
	var valve := detailed.find_child("*SteamPipeValve*", true, false) as Node3D
	var halo_outer := detailed.find_child("*CelestialHaloOuterMechanism*", true, false) as Node3D
	var halo_inner := detailed.find_child("*CelestialHaloInnerMechanism*", true, false) as Node3D
	if gear == null or rod == null or pressure == null or valve == null \
			or halo_outer == null or halo_inner == null:
		_fail("named steam and celestial-halo mechanisms are not addressable in the imported GLB")
		return
	var gear_basis := gear.basis
	var rod_transform := rod.transform
	var pressure_scale := pressure.scale
	var valve_basis := valve.basis
	var halo_outer_basis := halo_outer.basis
	var halo_inner_basis := halo_inner.basis

	player.global_position = railway.call("get_driver_interaction_position")
	if not bool(railway.call("board_as_driver")):
		_fail("could not enter driving mode")
		return
	# Use one fixed command/update pair per sample; the normal Input poll has no
	# held key in this direct-call test and must not inject a second zero throttle.
	railway.set_process(false)
	var gear_moved := false
	var rod_moved := false
	var pressure_moved := false
	var valve_moved := false
	var halo_outer_moved := false
	var halo_inner_moved := false
	# Observe movement after the new cab startup and direction-selection checks.
	for _frame in 270:
		railway.call("drive_manual", 1.0, 1.0 / 60.0)
		railway.call("_update_train_mechanisms", 1.0 / 60.0)
		await process_frame
		gear_moved = gear_moved or not gear.basis.is_equal_approx(gear_basis)
		rod_moved = rod_moved or not rod.transform.is_equal_approx(rod_transform)
		pressure_moved = pressure_moved or not pressure.scale.is_equal_approx(pressure_scale)
		valve_moved = valve_moved or not valve.basis.is_equal_approx(valve_basis)
		halo_outer_moved = halo_outer_moved or not halo_outer.basis.is_equal_approx(halo_outer_basis)
		halo_inner_moved = halo_inner_moved or not halo_inner.basis.is_equal_approx(halo_inner_basis)
	if not gear_moved or not rod_moved or not pressure_moved or not valve_moved \
			or not halo_outer_moved or not halo_inner_moved:
		_fail("one or more functional steam or celestial-halo mechanisms stayed static while driving")
		return
	if not _check_gear_rotation(railway, detailed, 1):
		return
	# Reverse through the real braking/direction-change path, not a forced flag.
	for _frame in 300:
		railway.call("drive_manual", -1.0, 1.0 / 60.0)
		railway.call("_update_train_mechanisms", 1.0 / 60.0)
	if not _check_gear_rotation(railway, detailed, -1):
		return
	state = railway.call("get_steam_engine_animation_state")
	if not bool(state.exhaust_emitting):
		_fail("chimney steam did not emit while the engine was running")
		return

	print("CROWN_TRAIN_STEAM_ENGINE_MOTION_TEST: PASS — gears, rods, pressure orbs, valves, chimney steam, and both celestial-halo layers animate in the playable train")
	quit()


func _check_gear_rotation(railway: Node3D, detailed: Node3D, direction: int) -> bool:
	var parts: Array[Node3D] = []
	var before: Array[Basis] = []
	for node in detailed.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("mechanism_spin_ratio") and String(node.name).contains("Steam"):
			parts.append(node)
			before.append(node.basis.orthonormalized())
	if parts.size() != 18:
		_fail("expected both sides' three gears, hubs and energy rings")
		return false
	railway.call("_update_train_mechanisms", 1.0 / 60.0)
	for index in parts.size():
		var part := parts[index]
		var change := part.basis.orthonormalized() * before[index].inverse()
		var spin := change.get_rotation_quaternion()
		var expected_sign := -direction * (-1 if String(part.name).ends_with("_1") else 1)
		# GLB axle is parent-space X. Turning about Z tumbles the gear face.
		if absf(spin.y) > .00001 or absf(spin.z) > .00001 \
				or spin.x * expected_sign <= .00001:
			_fail("%s must spin on its axle with the opposite neighbour direction (drive %d, delta %s)" \
				% [part.name, direction, spin])
			return false
	return true
