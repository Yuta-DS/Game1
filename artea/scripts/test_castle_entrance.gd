# Focused check for the front-door entrance and the gallery-exit arrival
# handoff. Deliberately does NOT instantiate the whole hub: that scene pulls in
# the local LLM, terrain streaming and audio, which makes it unusable as a fast
# feedback loop. This builds only the entrance node and the spawn plumbing.
extends SceneTree


func _fail(message: String) -> void:
	push_error("CASTLE_ENTRANCE_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var entrance := Node3D.new()
	entrance.name = "CastleEntrance"
	entrance.set_script(load("res://scripts/hub_castle_entrance.gd"))
	root.add_child(entrance)

	for _i in 10:
		await process_frame

	# 1. The entrance builds real geometry.
	var rig := entrance.get_node_or_null("CastleEntrance") as Node3D
	if rig == null:
		_fail("entrance rig did not build")
		return
	var meshes := rig.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() < 30:
		_fail("entrance is too bare: only %d meshes" % meshes.size())
		return

	# 2. It is walkable — a plaza with no collision drops the player into the void.
	var bodies := rig.find_children("*", "StaticBody3D", true, false)
	if bodies.is_empty():
		_fail("entrance has no collision, the player would fall through it")
		return

	# 3. The arrival point sits out on the plaza at door height.
	#
	# Measured door (probe_castle_door.gd): (-39.8, 69.33, 27.41) facing +X, so
	# a correct arrival point is further POSITIVE in x than the door face, and
	# clear of the castle's 16.5 m foundation around (-51.4, 27.41).
	var spawn: Vector3 = entrance.call("get_spawn_position")
	if spawn.x <= -39.8:
		_fail("arrival point is inside the castle, not out on the plaza: %s" % spawn)
		return
	if absf(spawn.y - 69.33) > 4.0:
		_fail("arrival point is not at door height: %s" % spawn)
		return
	if Vector2(spawn.x, spawn.z).distance_to(Vector2(-51.4, 27.41)) < 16.5:
		_fail("arrival point sits inside the castle foundation: %s" % spawn)
		return

	# 4. The Global handoff is one-shot: consuming must clear it, or every later
	#    entry to the hub would teleport the player to the castle door.
	var global := root.get_node_or_null("/root/Global")
	if global == null:
		_fail("Global autoload missing, gallery exit cannot hand off a spawn point")
		return
	global.request_spawn_at("castle_front_door")
	if global.consume_spawn_point() != "castle_front_door":
		_fail("spawn point did not survive the handoff")
		return
	if global.pending_spawn_point != "":
		_fail("spawn point was not cleared after being consumed")
		return

	# The castle exit may turn the visible fox toward the plaza, but it must not
	# rotate the CharacterBody root. NewPlayer's movement computes a world-space
	# travel angle for RogueSkin, while its camera is parented to the root; a
	# rotated root therefore makes the character appear to walk sideways and also
	# changes the camera-relative movement basis.
	var player := CharacterBody3D.new()
	player.name = "NewPlayer"
	player.add_to_group("player")
	var camera_controller := Node3D.new()
	camera_controller.name = "CameraController"
	camera_controller.rotation.y = PI
	player.add_child(camera_controller)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera_controller.add_child(camera)
	var visual := Node3D.new()
	visual.name = "RogueSkin"
	player.add_child(visual)
	root.add_child(player)
	var root_yaw_before := player.global_rotation.y
	global.request_spawn_at("castle_front_door")
	entrance.call("_apply_pending_spawn")
	if absf(angle_difference(player.global_rotation.y, root_yaw_before)) > 0.001:
		_fail("castle exit rotated the player root, causing sideways locomotion")
		return
	var outward_yaw := atan2(Vector3.RIGHT.x, Vector3.RIGHT.z)
	var camera_yaw := -outward_yaw
	if absf(angle_difference(camera.global_rotation.y, camera_yaw)) > 0.001:
		_fail("castle exit camera does not face outward with the character")
		return
	if absf(angle_difference(visual.global_rotation.y, outward_yaw)) > 0.001:
		_fail("castle exit did not face the visible character out over the plaza")
		return
	# NewPlayer maps Forward through the camera yaw. It must resolve to the same
	# +X direction as the doorway and visible fox, otherwise the first movement
	# after returning from the castle is a 90-degree sideways slide.
	var forward_motion := Vector2(0.0, -1.0).rotated(-camera.global_rotation.y)
	if forward_motion.distance_to(Vector2(Vector3.RIGHT.x, Vector3.RIGHT.z)) > 0.001:
		_fail("Forward input does not move outward after the castle exit")
		return
	var gallery_source := FileAccess.get_file_as_string("res://scripts/art_gallery.gd")
	if not gallery_source.contains("_request_castle_front_door_spawn()") \
			or not gallery_source.contains("request_spawn_at(\"castle_front_door\")"):
		_fail("the live Art Castle exit bypasses the front-door spawn handoff")
		return

	# 5. The entrance court keeps its deliberate lower datum.
	var upper_deck_y: float = entrance.get("UPPER_DECK_Y")
	if not is_equal_approx(upper_deck_y, 69.33):
		_fail("entrance court datum moved unexpectedly: %s" % upper_deck_y)
		return

	# 6. The terrace sits exactly one ceremonial rise below the upper court —
	# both quantities are script constants so this also proves the constant
	# wasn't left orphaned after the refactor.
	var terrace_deck_y: float = entrance.get("TERRACE_DECK_Y")
	var ceremonial_rise: float = entrance.get("CEREMONIAL_RISE")
	if not is_equal_approx(terrace_deck_y, upper_deck_y - ceremonial_rise):
		_fail("terrace deck does not sit one ceremonial rise below the upper court")
		return

	# 7. The High Aether Citadel must stand well above the entrance and be
	# reached by a collision-backed final flight, not by a visual-only step pile.
	var castle_threshold: Vector3 = entrance.get("CASTLE_THRESHOLD")
	var castle_rise: float = entrance.get("CASTLE_RISE")
	var door_level: Vector3 = entrance.get("DOOR_LEVEL")
	var court_level: Vector3 = entrance.get("COURT_LEVEL")
	var ascent_width: float = entrance.get("CASTLE_ASCENT_WIDTH")
	var threshold_width: float = entrance.get("CASTLE_THRESHOLD_WIDTH")
	if not is_equal_approx(castle_rise, 9.0) or not is_equal_approx(castle_threshold.y, 78.33):
		_fail("high citadel datum drifted: rise=%s threshold=%s"
			% [castle_rise, castle_threshold.y])
		return
	if not is_equal_approx(door_level.y, castle_rise) or not court_level.is_zero_approx():
		_fail("doorway does not align with the final stair while court furniture stays grounded")
		return
	if not is_equal_approx(ascent_width, 4.8) or not is_equal_approx(threshold_width, 5.2):
		_fail("upper approach is wider than the Art Castle doorway")
		return
	if castle_threshold.y <= upper_deck_y + 5.5:
		_fail("castle is not visibly higher than its entrance: %s vs %s"
			% [castle_threshold.y, upper_deck_y])
		return
	var stair := rig.get_node_or_null("RoyalCastleStair") as Node3D
	if stair == null or stair.get_meta("walk_surface_policy", "") != "visible_treads_are_physical_treads":
		_fail("royal stair must use matching visible and physical treads")
		return
	if rig.has_node("CastleAscentRamp") or rig.has_node("RaisedCastleThreshold"):
		_fail("superseded ramp or overlapping threshold remains")
		return
	var treads := stair.find_children("RoyalTread_*", "MeshInstance3D", true, false)
	if treads.size() != 18:
		_fail("royal ascent does not contain 18 regular closed treads")
		return
	for tread: MeshInstance3D in treads:
		if tread.find_children("*", "StaticBody3D", true, false).size() != 1:
			_fail("visible tread must own exactly one collision body")
			return
	var soffit := stair.get_node_or_null("RoyalStairSoffit")
	if soffit == null or not soffit.get_meta("finished_stone_soffit", false):
		_fail("finished closed underside is missing")
		return
	var guards := stair.find_children("RoyalStairParapet*", "MeshInstance3D", true, false)
	if guards.size() != 2:
		_fail("stair needs two continuous side barriers")
		return
	for guard in guards:
		if guard.find_children("*", "StaticBody3D", true, false).size() != 1:
			_fail("each side barrier must have one simple solid body")
			return
	if stair.find_children("RoyalStairCoping*", "MeshInstance3D", true, false).size() != 2:
		_fail("side barriers are missing their fitted stone coping")
		return
	var landing := stair.get_node_or_null("RoyalDoorLanding") as MeshInstance3D
	if landing == null or landing.find_children("*", "StaticBody3D", true, false).is_empty():
		_fail("door landing has no support")
		return
	var landing_bounds := landing.global_transform * landing.mesh.get_aabb()
	if absf(landing_bounds.end.y - castle_threshold.y) > 0.002 or landing_bounds.end.x > castle_threshold.x + 0.002:
		_fail("door landing projects above/over the final tread")
		return

	print("CASTLE_ENTRANCE_TEST: PASS — %d meshes, %d collision bodies, arrival at %s, "
		% [meshes.size(), bodies.size(), spawn]
		+ "entrance y=%s, castle threshold y=%s, terrace y=%s"
		% [upper_deck_y, castle_threshold.y, terrace_deck_y])
	quit()


func _init() -> void:
	call_deferred("_run")
