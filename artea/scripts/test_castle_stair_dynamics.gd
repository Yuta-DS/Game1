# Dynamic regression for the complete terrain <-> spiral <-> crown route.
# Geometry checks alone do not catch one-way handoffs, jump traps, or loose
# props slipping through the continuous stair collision in a web build.
extends SceneTree

const WALK_SPEED := 9.0
const GRAVITY_PER_FRAME := 28.0 / 60.0
const STALL_FRAMES := 55
const MAX_WALK_FRAMES := 300

var _prop_diagnostic := ""


func _fail(message: String) -> void:
	push_error("CASTLE_STAIR_DYNAMICS_TEST: %s" % message)
	quit(1)


func _colliders(player: CharacterBody3D) -> String:
	var labels: Array[String] = []
	for index in player.get_slide_collision_count():
		var hit := player.get_slide_collision(index)
		var collider := hit.get_collider()
		if collider is Node:
			labels.append("%s normal=%s" % [
				(collider as Node).get_path(), hit.get_normal()])
	return "; ".join(labels)


func _settle(player: CharacterBody3D, position: Vector3) -> bool:
	player.global_position = position
	player.velocity = Vector3.ZERO
	for _frame in 210:
		player.velocity.y -= GRAVITY_PER_FRAME
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor() and absf(player.velocity.y) < 0.01:
			return true
	return false


func _walk_to(player: CharacterBody3D, destination: Vector3) -> bool:
	var best := Vector2(player.global_position.x - destination.x,
		player.global_position.z - destination.z).length()
	var stalled := 0
	for _frame in MAX_WALK_FRAMES:
		var delta := destination - player.global_position
		delta.y = 0.0
		if delta.length() < 0.28:
			return true
		var was_on_floor := player.is_on_floor()
		var before := player.global_position
		player.velocity.x = delta.normalized().x * WALK_SPEED
		player.velocity.z = delta.normalized().z * WALK_SPEED
		player.velocity.y -= GRAVITY_PER_FRAME
		var intended := player.velocity
		player.move_and_slide()
		player._try_step_up(was_on_floor, before, intended, 1.0 / 60.0)
		await physics_frame
		var distance := Vector2(player.global_position.x - destination.x,
			player.global_position.z - destination.z).length()
		if distance < best - 0.005:
			best = distance
			stalled = 0
		else:
			stalled += 1
		if stalled >= STALL_FRAMES:
			return false
	return false


func _jump_and_land(player: CharacterBody3D, destination: Vector3) -> bool:
	var delta := destination - player.global_position
	delta.y = 0.0
	if delta.length() < 0.1:
		return true
	player.velocity = delta.normalized() * 7.0 + Vector3.UP * 8.4
	var became_airborne := false
	for frame in 180:
		var direction := destination - player.global_position
		direction.y = 0.0
		if direction.length() > 0.15:
			player.velocity.x = direction.normalized().x * 7.0
			player.velocity.z = direction.normalized().z * 7.0
		player.velocity.y -= GRAVITY_PER_FRAME
		player.move_and_slide()
		await physics_frame
		if not player.is_on_floor():
			became_airborne = true
		if became_airborne and frame > 4 and player.is_on_floor():
			return await _walk_to(player, destination)
	return false


func _tread_destination(stair: Node3D, tread: MeshInstance3D,
		lane_offset: float = 0.0) -> Vector3:
	var base: Vector2 = stair.get_meta("tower_base")
	var radial := Vector3(tread.global_position.x - base.x, 0.0,
		tread.global_position.z - base.y).normalized()
	return tread.global_position + radial * lane_offset


func _route_indices(count: int, ascending: bool) -> Array[int]:
	var indices: Array[int] = []
	if ascending:
		for index in range(0, count, 4):
			indices.append(index)
		if indices.back() != count - 1:
			indices.append(count - 1)
	else:
		for index in range(count - 1, -1, -4):
			indices.append(index)
		if indices.back() != 0:
			indices.append(0)
	return indices


func _traverse_spiral(player: CharacterBody3D, stair: Node3D,
		treads: Array, ascending: bool) -> bool:
	var route := _route_indices(treads.size(), ascending)
	var jump_route_position := route.size() / 2
	for route_position in route.size():
		var tread := treads[route[route_position]] as MeshInstance3D
		var target := _tread_destination(stair, tread)
		if route_position == jump_route_position:
			if not await _jump_and_land(player, target):
				_fail("player failed %s jump/landing at %s; position %s; collisions: %s" % [
					"uphill" if ascending else "downhill", tread.name,
					player.global_position, _colliders(player)])
				return false
		elif not await _walk_to(player, target):
			_fail("player snagged going %s near %s; position %s; collisions: %s" % [
				"uphill" if ascending else "downhill", tread.name,
				player.global_position, _colliders(player)])
			return false
	return true


func _make_prop(parent: Node) -> RigidBody3D:
	var prop := RigidBody3D.new()
	prop.name = "CastleStairPhysicsProbe"
	prop.mass = 0.7
	prop.contact_monitor = true
	prop.max_contacts_reported = 8
	prop.can_sleep = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.28
	shape.shape = sphere
	prop.add_child(shape)
	parent.add_child(prop)
	return prop


func _test_loose_prop(stair: Node3D, treads: Array, tread_index: int) -> bool:
	_prop_diagnostic = ""
	var tread := treads[tread_index] as MeshInstance3D
	var next_index := mini(tread_index + 2, treads.size() - 1)
	if next_index == tread_index:
		next_index = maxi(0, tread_index - 2)
	var next_tread := treads[next_index] as MeshInstance3D
	var direction := next_tread.global_position - tread.global_position
	direction.y = 0.0
	direction = direction.normalized()
	var prop := _make_prop(stair)
	prop.global_position = _tread_destination(stair, tread) + Vector3.UP * 1.2
	var touched_stair := false
	for _frame in 120:
		await physics_frame
		if prop.get_contact_count() > 0:
			touched_stair = true
			break
	if not touched_stair:
		_prop_diagnostic = "made no stair contact at %s" % prop.global_position
		prop.queue_free()
		return false
	var start := prop.global_position
	prop.apply_central_impulse(direction * 1.8 + Vector3.UP * 0.22)
	var retained_contact := false
	var frames_without_contact := 0
	for _frame in 70:
		await physics_frame
		if prop.get_contact_count() > 0:
			retained_contact = true
			frames_without_contact = 0
		else:
			frames_without_contact += 1
		if retained_contact and frames_without_contact > 24 \
				and prop.linear_velocity.y < -6.0:
			_prop_diagnostic = "lost stair support for %d frames; velocity=%s position=%s" % [
				frames_without_contact, prop.linear_velocity, prop.global_position]
			prop.queue_free()
			return false
	var planar_progress := Vector2(prop.global_position.x - start.x,
		prop.global_position.z - start.z).length()
	if not retained_contact or planar_progress <= 0.22:
		_prop_diagnostic = "contact=%s planar_progress=%.3f start=%s end=%s" % [
			retained_contact, planar_progress, start, prop.global_position]
	prop.queue_free()
	return retained_contact and planar_progress > 0.22


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 80:
		await process_frame
		await physics_frame
	var stair := hub.get_node_or_null("CastleStairs/CastleStair") as Node3D
	var player := hub.get_node_or_null("NewPlayer") as CharacterBody3D
	if stair == null or player == null:
		_fail("castle stair or packed player did not load")
		return
	var entry := stair.get_node_or_null("GroundedCastleEntry") as Node3D
	var treads := stair.find_children("StairTread_*", "MeshInstance3D", true, false)
	treads.sort_custom(func(a, b):
		return (a as MeshInstance3D).global_position.y < (b as MeshInstance3D).global_position.y)
	if entry == null or treads.size() < 24:
		_fail("complete grounded stair route did not build")
		return
	var ground_start: Vector3 = entry.get_meta("surface_start", Vector3.INF)
	var ground_end: Vector3 = entry.get_meta("surface_end", Vector3.INF)
	if not ground_start.is_finite() or not ground_end.is_finite():
		_fail("ground entry does not expose stable route endpoints")
		return
	var base: Vector2 = stair.get_meta("tower_base")
	var crown_y: float = float(stair.get_meta("tower_top_y")) + 0.17
	var final_tread := treads.back() as MeshInstance3D
	var final_radial := Vector3(final_tread.global_position.x - base.x, 0.0,
		final_tread.global_position.z - base.y).normalized()
	var final_tangent := Vector3(-final_radial.z, 0.0, final_radial.x)
	# Traverse the open landing beyond the curved inner guard, then turn onto
	# the roof. The return route follows the same unobstructed doorway.
	var crown_entry := final_tread.global_position + final_tangent * 2.5
	var crown_point := Vector3(base.x, crown_y, base.y) \
		+ final_radial * 3.7 + final_tangent * 2.5

	player.set_physics_process(false)
	player.set_process_input(false)
	if not await _settle(player, ground_start + Vector3.UP * 4.0):
		_fail("player did not settle on terrain at the castle stair entrance")
		return
	if not await _walk_to(player, ground_end):
		_fail("player snagged on terrain-to-stair handoff at %s" % player.global_position)
		return
	if not await _traverse_spiral(player, stair, treads, true):
		return
	if not await _walk_to(player, crown_entry) \
			or not await _walk_to(player, crown_point):
		_fail("player did not complete final-tread-to-crown handoff")
		return
	if not await _walk_to(player, crown_entry):
		_fail("player did not reach the crown stair mouth for descent")
		return
	if not await _jump_and_land(player, _tread_destination(stair, final_tread)):
		_fail("player failed crown-to-final-tread jump/landing handoff")
		return
	if not await _traverse_spiral(player, stair, treads, false):
		return
	if not await _walk_to(player, ground_start):
		_fail("player did not complete stair-to-terrain downhill handoff")
		return

	for tread_index in [2, treads.size() / 2, treads.size() - 3]:
		if not await _test_loose_prop(stair, treads, tread_index):
			_fail("loose physics prop failed near tread %d: %s" % [
				tread_index, _prop_diagnostic])
			return

	print("CASTLE_STAIR_DYNAMICS_TEST: PASS — player crossed terrain-to-crown uphill and downhill, landed both jump transitions, and loose props remained supported at lower/middle/upper stair sections")
	quit(0)


func _init() -> void:
	call_deferred("_run")
