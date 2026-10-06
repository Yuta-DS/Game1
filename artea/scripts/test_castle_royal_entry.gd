extends "res://scripts/test_castle_rooftop_barrier_safety.gd"

const Entry := preload("res://scripts/castle_royal_entry.gd")

func _fail(message: String) -> void:
	push_error("ROYAL_ENTRY_TEST: " + message)
	quit(1)

func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.set_physics_process(false)
	player.set_process_input(false)
	player.global_position = Entry.FOOT + Vector3(1.0, 1, 0)
	for frame in 80:
		await process_frame
		await physics_frame
	var portal := hub.get_node("Art_Gallery") as Area3D
	# Traversal must test the architecture without swapping the scene mid-test.
	# Explicit entry uses exactly the same volume; automatic handoff is tested last.
	portal.set("require_interact", true)
	var rig := hub.get_node("CastleEntrance/CastleEntrance/RoyalCastleStair") as Node3D
	var treads := rig.find_children("RoyalTread_*", "MeshInstance3D", true, false)
	if treads.size() != Entry.STEPS:
		_fail("wrong tread count")
		return
	var space := player.get_world_3d().direct_space_state
	for tread: MeshInstance3D in treads:
		var bounds := tread.global_transform * tread.mesh.get_aabb()
		for lane: float in [-1.7, 0, 1.7]:
			var point := Vector3(bounds.get_center().x, bounds.end.y, Entry.TOP.z + lane)
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.20, point - Vector3.UP * 0.20)
			query.exclude = [player.get_rid()]
			var hit := space.intersect_ray(query)
			if hit.is_empty() or absf(hit.position.y - point.y) > 0.005:
				_fail("visible tread and physics disagree: %s" % point)
				return
	# Inspect upward from beneath every tread. The soffit must enclose the
	# lowest rear corner, not leave a repeated fringe of exposed step bottoms.
	for index in Entry.STEPS:
		var x := Entry.FOOT.x - Entry.RUN * (index + 0.5) / Entry.STEPS
		var underside_y := Entry.FOOT.y + Entry.RISE * (index + 0.5) / Entry.STEPS - 1.6
		var under := Vector3(x, underside_y, Entry.TOP.z)
		var query := PhysicsRayQueryParameters3D.create(under - Vector3.UP * 0.10, under + Vector3.UP * 0.10)
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty() or absf(hit.position.y - underside_y) > 0.006:
			_fail("underside is not continuously enclosed at tread %d" % index)
			return
	# Three lanes, sprint up/down. Stop in front of the solid door, not through it.
	for lane: float in [-1.6, 0.0, 1.6]:
		await _settle(player, Entry.FOOT + Vector3(0.9, 2, lane))
		if not await _walk_to(player, Entry.TOP + Vector3(0.65, 0, lane)):
			_fail("ascent blocked at %s" % player.global_position)
			return
		if player.global_position.y < Entry.TOP.y - 1.2:
			_fail("player walked beneath the visible stair")
			return
		if not await _walk_to(player, Entry.FOOT + Vector3(0.9, 0, lane)):
			_fail("descent blocked at %s" % player.global_position)
			return
	# Middle and lower guard faces must stop a sprint then allow escape.
	for side: float in [-1.0, 1.0]:
		for index in [3, 9]:
			var tread := treads[index] as MeshInstance3D
			var y := float(tread.get_meta("walk_surface_y"))
			await _settle(player, Vector3(tread.global_position.x, y + 1, Entry.TOP.z))
			await _run_direction(player, Vector3(0, 0, side), 22)
			if absf(player.global_position.z - Entry.TOP.z) > Entry.WIDTH * 0.5:
				_fail("player passed through stair parapet")
				return
			if not await _walk_to(player, Vector3(player.global_position.x, y, Entry.TOP.z)):
				_fail("player stuck against stair parapet")
				return
	# Stationary jump on a middle tread must land above the visible surface.
	var middle := treads[8] as MeshInstance3D
	var middle_y := float(middle.get_meta("walk_surface_y"))
	await _settle(player, Vector3(middle.global_position.x, middle_y + 1, Entry.TOP.z))
	player.velocity = Vector3(0, 8, 0)
	for frame in 100:
		player.velocity.y -= GRAVITY_PER_FRAME
		player.move_and_slide()
		await physics_frame
	if not player.is_on_floor() or player.global_position.y < middle_y - 0.07:
		_fail("jump landed under the stair")
		return
	# Trigger still recognises the actual capsule at the door; automatic mode
	# must enter the existing gallery scene, not a replacement destination.
	await _settle(player, Entry.FOOT + Vector3(0.9, 1, 0))
	portal.set("require_interact", false)
	current_scene = hub
	if not await _walk_to(player, Entry.TOP + Vector3(0.85, 0, 0)):
		_fail("could not reach gallery trigger")
		return
	for frame in 180:
		await process_frame
		if current_scene != null and current_scene != hub:
			break
	if current_scene == null or current_scene == hub or current_scene.scene_file_path != "res://scenes/art_gallery_3d_inprogress.tscn":
		_fail("automatic gallery entry did not fire")
		return
	print("ROYAL_ENTRY_TEST: PASS — 54 tread/collider and 18 underside probes, 3 ascent/descent lanes, 4 wall impacts/escapes, jump landing, live gallery entry")
	quit(0)
