extends "res://scripts/test_castle_rooftop_barrier_safety.gd"

const Stair := preload("res://scripts/hub_castle_stairs.gd")
const Style := preload("res://scripts/castle_reference_style.gd")

# Exercise the production acceleration, turning and gravity when reversing
# direction on the sloped helix, not an approximate constant-velocity driver.
func _drive_frame(player: CharacterBody3D, direction: Vector3) -> void:
	var camera := player.get("camera") as Camera3D
	var input := Vector2(direction.x, direction.z).rotated(camera.global_rotation.y)
	for action: String in ["move_left", "move_right", "move_forward", "move_backward"]:
		Input.action_release(action)
	Input.action_press("run")
	if input.x < 0:
		Input.action_press("move_left", -input.x)
	else:
		Input.action_press("move_right", input.x)
	if input.y < 0:
		Input.action_press("move_forward", -input.y)
	else:
		Input.action_press("move_backward", input.y)
	player._physics_process(1.0 / 60.0)

func _run_direction(player: CharacterBody3D, direction: Vector3, frames: int) -> void:
	for frame in frames:
		_drive_frame(player, direction)
		await physics_frame

func _walk_to(player: CharacterBody3D, destination: Vector3) -> bool:
	for frame in 120:
		var delta := destination - player.global_position
		delta.y = 0
		if delta.length() < 0.28:
			for action: String in ["move_left", "move_right", "move_forward", "move_backward", "run"]:
				Input.action_release(action)
			return true
		_drive_frame(player, delta.normalized())
		await physics_frame
	return false

func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for frame in 90:
		await process_frame
		await physics_frame
	var stair := hub.get_node("CastleStairs/CastleStair") as Node3D
	var base: Vector2 = stair.get_meta("tower_base")
	var details := stair.get_node("MedievalStairDetails")
	for name: String in ["OuterContinuousGuard"]:
		var guard := stair.get_node(name) as MeshInstance3D
		var normals: PackedVector3Array = guard.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		if normals[0].y < 0.5:
			_fail("guard collider is still inside-out")
			return
	var piers := details.find_children("KeepStairPier_*", "Node3D", false, false)
	var merlons := details.find_children("KeepSpiralMerlon_*", "MeshInstance3D", false, false)
	var dressing := stair.get_node("KeepTowerDressing")
	if piers.size() != 12 or merlons.size() != 22 \
			or dressing.find_children("KeepCornerDressing_*", "MeshInstance3D", false, false).size() != 40 \
			or dressing.find_children("KeepTowerPennant_*", "MeshInstance3D", false, false).size() != 10:
		_fail("keep-style stair/tower details were not built")
		return
	# Every major object on the parapet is solid and wholly outside its existing
	# lane-side face. Test transformed vertices, not just the centre coordinates.
	var solid_count := 0
	for mesh: MeshInstance3D in details.find_children("*", "MeshInstance3D", true, false):
		if mesh.get_parent().name.begins_with("ReferenceRoundArchWindow"):
			continue
		if not (mesh.name.begins_with("OuterStoneNewel_") or mesh.name.begins_with("NewelRedRoof_") \
				or mesh.name == "KeepPierCapital" or mesh.name.begins_with("KeepSpiralMerlon_")):
			continue
		if mesh.global_basis.determinant() < 0.99 or mesh.find_children("*", "CollisionShape3D", true, false).is_empty():
			_fail("mirrored or non-solid stair detail: " + mesh.name)
			return
		for v: Vector3 in mesh.mesh.get_faces():
			var world := mesh.global_transform * v
			if Vector2(world.x, world.z).distance_to(base) < Stair.OUTER_BARRIER_INNER_RADIUS + 0.04:
				_fail("stair detail projects into the clear lane: " + mesh.name)
				return
		solid_count += 1
	if solid_count != 58:
		_fail("unexpected number of solid stair components")
		return
	for mesh: MeshInstance3D in dressing.find_children("*", "MeshInstance3D", true, false):
		for v: Vector3 in mesh.mesh.get_faces():
			var world := mesh.global_transform * v
			if Vector2(world.x, world.z).distance_to(base) > Stair.STAIR_RADIUS - Stair.STEP_WIDTH * 0.5 - Stair.INNER_GUARD_HALF_WIDTH:
				_fail("tower facade reaches through the inner stair guard")
				return
		if mesh.global_basis.determinant() < 0.99:
			_fail("mirrored tower dressing")
			return
	for pier: Node3D in piers:
		var capital := pier.get_node("KeepPierCapital") as MeshInstance3D
		var roof := pier.find_child("NewelRedRoof_*", false, false) as MeshInstance3D
		if absf(roof.position.y - (roof.mesh as CylinderMesh).height * 0.5 \
				- capital.position.y - (capital.mesh as BoxMesh).size.y * 0.5) > 0.001:
			_fail("roof floats above its pier")
			return
		if roof.get_active_material(0) != Style.material("roof"):
			_fail("pier roof no longer matches the main keep")
			return
	# Sprint into representative additions from the actual stair, then turn back.
	# The pre-existing continuous guard must stop the capsule before any ornament.
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.set_physics_process(false)
	player.set_process_input(false)
	var impacts := 0
	for index in [1, 5, 11, 17, 20]:
		var wall := merlons[index] as MeshInstance3D
		var radial := Vector3(wall.global_position.x - base.x, 0, wall.global_position.z - base.y).normalized()
		var at := Vector3(base.x, wall.global_position.y + 0.4, base.y) + radial * 6.85
		if not await _settle(player, at):
			_fail("could not stand beside new stair detail")
			return
		var floor_y := player.global_position.y
		await _run_direction(player, radial, 20)
		if Vector2(player.global_position.x, player.global_position.z).distance_to(base) > Stair.OUTER_BARRIER_INNER_RADIUS \
				or absf(player.global_position.y - floor_y) > 0.6:
			_fail("capsule passed the guard or climbed decorative stone")
			return
		var after_impact := player.global_position
		if not await _walk_to(player, player.global_position - radial * 1.0):
			print("STAIR_KEEP_ESCAPE_DIAGNOSTIC index=%d start=%s impact=%s end=%s velocity=%s floor=%s wall=%s" % [index, at, after_impact, player.global_position, player.velocity, player.is_on_floor(), player.is_on_wall()])
			for hit_index in player.get_slide_collision_count():
				var hit := player.get_slide_collision(hit_index)
				print("STAIR_KEEP_COLLISION ", hit.get_collider().get_path(), " normal=", hit.get_normal())
			_fail("capsule stuck beside new stair detail")
			return
		impacts += 1
		# Continue across the same flight, press the inner guard, then release.
		await _run_direction(player, -radial, 25)
		var inner_radius := Vector2(player.global_position.x, player.global_position.z).distance_to(base)
		if inner_radius < Stair.INNER_BARRIER_LANE_FACE_RADIUS \
				or absf(player.global_position.y - floor_y) > 0.6 \
				or not await _walk_to(player, player.global_position + radial * 1.0):
			_fail("inner guard admitted or trapped the player")
			return
		impacts += 1
	print("STAIR_KEEP_DETAIL_TEST: PASS — 12 solid roofed piers, 22 battlements, 40 corner dressings, 10 pennants; outward outer-guard faces and %d real-input sprint impacts/escapes on both sides" % impacts)
	quit(0)
