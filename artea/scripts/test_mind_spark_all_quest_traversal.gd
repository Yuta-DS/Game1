extends SceneTree

# One uninterrupted production-player journey from the World One arrival,
# through every quest operator, across both sky bridges, and back to Island One.
# This closes the gap left by isolated landing and per-island probes.
const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const PlayerScene := preload("res://scenes/player_3d.tscn")
const STATE_PATH := "user://test_all_quest_traversal.json"
const WALK_SPEED := 24.0
const GRAVITY := 28.0
const TARGET_RADIUS := 2.0

var _world: MindSparkWorldOne
var _player: CharacterBody3D
var _objects := {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(STATE_PATH)
	_world = WorldScene.instantiate() as MindSparkWorldOne
	_world.build_hud = false
	_world.object_state_store_path = STATE_PATH
	root.add_child(_world)
	for _frame in 6:
		await physics_frame
	for object in _world.get_quest_objects():
		_objects[object.save_id] = object
	_player = PlayerScene.instantiate() as CharacterBody3D
	root.add_child(_player)
	_player.set_physics_process(false)
	_player.set_process_input(false)
	_player.global_position = _world.to_global(_world.get_player_arrival_local())
	if not await _land():
		return _fail("World One spawn has no supporting floor")
	var island_one_gate := _world.get_island_one_heavenly_star_gate() as Node3D

	var route: Array = [
		_operator("world_one.checkpoint.landing"),
		["arrival south aisle", _world.to_global(Vector3(-860, 2, 138))],
		_operator("world_one.path_projector"),
		["Island One west saddle", _world.to_global(Vector3(-790, 2, 142))],
		["Island One gate approach", island_one_gate.to_global(Vector3(0, 2, -20))],
		["Island One gate threshold", island_one_gate.to_global(Vector3(0, 2, 0))],
		["Island One gate garden landing", island_one_gate.to_global(Vector3(0, 2, 20))],
		["Island One garden bypass", _world.to_global(Vector3(-735, 2, 170))],
		["living network outer promenade", _world.to_global(Vector3(-600, 2, 170))],
		["living network eastern aisle", _world.to_global(Vector3(-540, 2, 100))],
		_operator("world_one.checkpoint.network"),
		_operator("world_one.focus_bell"),
		_operator("world_one.spark_socket"),
	]
	_append_bridge(route, 1, "Island One to Island Two")
	route.append_array([
		["constellation ramp foot", _world.to_global(Vector3(-316, 10, -97))],
		["constellation ramp top", _world.to_global(Vector3(-292, 13, -93))],
		_operator("world_one.evidence_scanner"),
		["evidence station bypass", _world.to_global(Vector3(-268, 13, -115))],
		["memory station aisle", _world.to_global(Vector3(-235, 13, -115))],
		_operator("world_one.memory_board"),
		["memory station west exit", _world.to_global(Vector3(-250, 13, -70))],
		["memory station bypass", _world.to_global(Vector3(-250, 13, -135))],
		["logic station aisle", _world.to_global(Vector3(-175, 13, -135))],
		["logic rail west end", _world.to_global(Vector3(-190, 13, -115))],
		["logic rail inner side", _world.to_global(Vector3(-190, 13, -70))],
		_operator("world_one.logic_gate"),
		["memory promenade evidence landing", _world.to_global(Vector3(-158, 10, -53))],
		["memory promenade midpoint", _world.to_global(Vector3(-110, 10, -30))],
		["memory promenade hope landing", _world.to_global(Vector3(-61, 10, -7))],
		["memory promenade clear", _world.to_global(Vector3(-45, 10, 1))],
		_operator("world_one.perspective_lens"),
		["perspective station bypass", _world.to_global(Vector3(-45, 10, 45))],
		["truth station aisle", _world.to_global(Vector3(-10, 10, 45))],
		_operator("world_one.truth_bridge"),
	])
	_append_bridge(route, 3, "Island Two to Island Three")
	var arena := MindSparkWorldOne.ZONES[4].position as Vector3
	route.append_array([
		["storm arrival axis", _world.to_global(arena + Vector3(-110, 0, 0))],
		_operator("world_one.warden_anchor.1"),
		["storm west court", _world.to_global(arena + Vector3(-64, 0, -12))],
		["storm west garden bypass", _world.to_global(arena + Vector3(-80, 0, -82))],
		["storm west garden return", _world.to_global(arena + Vector3(-80, 0, -45))],
		["storm north processional", _world.to_global(arena + Vector3(0, 0, -65))],
		["forge east entry", _world.to_global(arena + Vector3(40, 0, -95))],
		["forge operator flank", _world.to_global(arena + Vector3(25, 0, -117))],
		_operator("world_one.warden_anchor.2"),
		["forge east flank", _world.to_global(arena + Vector3(30, 0, -130))],
		["storm east court", _world.to_global(arena + Vector3(80, 0, -83))],
		["archive outer flank", _world.to_global(arena + Vector3(120, 0, 10))],
		_operator("world_one.warden_anchor.3"),
		["archive garden egress", _world.to_global(arena + Vector3(120, 0, 85))],
		["storm south court", _world.to_global(arena + Vector3(65, 0, 55))],
		["rain lane", _world.to_global(arena + Vector3(0, 0, 55))],
		_operator("world_one.calm_rain_basin"),
		["storm court return", _world.to_global(arena + Vector3(38, 0, 35))],
		["reflection promenade entry", _world.to_global(arena + Vector3(65, 0, -8))],
		["reflection promenade middle", _world.to_global(arena + Vector3(112, 0, -31))],
		_operator("world_one.identity_reflection"),
	])

	var visited := {}
	for stop in route:
		if not await _walk_to(stop[1], stop[0]):
			return
		if stop.size() > 2:
			var save_id := str(stop[2])
			visited[save_id] = true
			var object := _objects[save_id] as QuestObjectBase
			assert(_player.global_position.distance_to(object.global_position) <= 14.0,
				"%s operator remains inside interaction range" % save_id)
			if save_id == "world_one.path_projector":
				var puzzle_result: Dictionary = _world.get_island_one_puzzle().solve_for_test()
				assert(str(puzzle_result.get("reason", "")) == "completed",
					"the arrival puzzle unlocks its physical onward gate")
				await create_timer(4.0).timeout
				assert(str(_world.get_island_one_heavenly_star_gate().get_meta(
					"gate_state", "")) == "open", "the onward star gate finishes opening")
			elif save_id == "world_one.logic_gate":
				_world.set_quest_gate_open(1, true)
				await create_timer(3.0).timeout
				assert(_world.is_quest_gate_open(1),
					"the completed evidence sequence opens the Memory Gate")
			elif save_id == "world_one.truth_bridge":
				_world.set_quest_gate_open(2, true)
				await create_timer(1.0).timeout
				assert(_world.is_quest_gate_open(2),
					"the completed Hope sequence opens the storm bridge departure")

	assert(visited.size() == 15, "the continuous route reaches all fifteen quest operators")

	# Prove that the authored return route remains usable after the full outward
	# journey. Revisit both bridges in reverse and finish at the original spawn.
	var return_route: Array = [
		["reflection promenade return", _world.to_global(arena + Vector3(112, 0, -31))],
		["reflection promenade exit", _world.to_global(arena + Vector3(65, 0, -8))],
		["storm court return lane", _world.to_global(arena + Vector3(38, 0, 35))],
		["rain return lane", _world.to_global(arena + Vector3(0, 0, 55))],
		["storm south return", _world.to_global(arena + Vector3(65, 0, 55))],
		["archive garden return", _world.to_global(arena + Vector3(120, 0, 85))],
		_operator("world_one.warden_anchor.3"),
		["archive outer return", _world.to_global(arena + Vector3(120, 0, 10))],
		["storm east return", _world.to_global(arena + Vector3(80, 0, -83))],
		["forge east flank return", _world.to_global(arena + Vector3(30, 0, -130))],
		_operator("world_one.warden_anchor.2"),
		["forge operator flank return", _world.to_global(arena + Vector3(25, 0, -117))],
		["forge east entry return", _world.to_global(arena + Vector3(40, 0, -95))],
		["storm north return", _world.to_global(arena + Vector3(0, 0, -65))],
		["storm garden return aisle", _world.to_global(arena + Vector3(-80, 0, -45))],
		["storm garden return", _world.to_global(arena + Vector3(-80, 0, -82))],
		["storm west return", _world.to_global(arena + Vector3(-64, 0, -12))],
		["storm arrival return", _world.to_global(arena + Vector3(-110, 0, 0))],
	]
	_append_bridge(return_route, 3, "Island Three return bridge", true)
	return_route.append_array([
		["truth station return aisle", _world.to_global(Vector3(-10, 10, 45))],
		["hope pavilion south return", _world.to_global(Vector3(-10, 10, 65))],
		["hope pavilion west return", _world.to_global(Vector3(-45, 10, 65))],
		["perspective return bypass", _world.to_global(Vector3(-45, 10, 45))],
		["memory promenade return entry", _world.to_global(Vector3(-45, 10, 1))],
		["memory promenade return midpoint", _world.to_global(Vector3(-110, 10, -30))],
		["memory promenade evidence return", _world.to_global(Vector3(-158, 10, -53))],
		["logic rail return inner side", _world.to_global(Vector3(-190, 13, -70))],
		["logic rail return west end", _world.to_global(Vector3(-190, 13, -115))],
		["constellation south return", _world.to_global(Vector3(-250, 13, -135))],
		["constellation ramp return top", _world.to_global(Vector3(-292, 13, -93))],
		["constellation ramp return foot", _world.to_global(Vector3(-316, 10, -97))],
	])
	_append_bridge(return_route, 1, "Island Two return bridge", true)
	return_route.append_array([
		["living network return aisle", _world.to_global(Vector3(-540, 2, 100))],
		["living network return promenade", _world.to_global(Vector3(-600, 2, 170))],
		["Island One garden return bypass", _world.to_global(Vector3(-735, 2, 170))],
		["Island One gate garden return", island_one_gate.to_global(Vector3(0, 2, 20))],
		["Island One gate return threshold", island_one_gate.to_global(Vector3(0, 2, 0))],
		["Island One gate return approach", island_one_gate.to_global(Vector3(0, 2, -20))],
		["Island One west return saddle", _world.to_global(Vector3(-790, 2, 142))],
		["arrival return aisle", _world.to_global(Vector3(-860, 2, 138))],
		["World One return spawn", _world.to_global(_world.get_player_arrival_local())],
	])
	for stop in return_route:
		if not await _walk_to(stop[1], stop[0]):
			return

	print("MindSparkAllQuestTraversal: PASS — spawn, 15 quest operators, both bridges and return route are continuously walkable")
	_cleanup()
	quit()


func _operator(save_id: String) -> Array:
	var object := _objects[save_id] as QuestObjectBase
	var parent := object.get_parent() as Node3D
	return [save_id, parent.to_global(object.get_meta("operator_approach_local")), save_id]


func _append_bridge(route: Array, source_index: int, label: String,
		reverse := false) -> void:
	var source: Dictionary = MindSparkWorldOne.ZONES[source_index]
	var destination: Dictionary = MindSparkWorldOne.ZONES[source_index + 1]
	var source_center: Vector3 = source.position
	var destination_center: Vector3 = destination.position
	var direction := destination_center - source_center
	direction.y = 0.0
	direction = direction.normalized()
	var start := source_center + direction * (float(source.radius) - 45.0)
	var finish := destination_center - direction * (float(destination.radius) - 3.5)
	var stops := [
		["%s approach" % label, _world.to_global(start)],
		["%s exit" % label, _world.to_global(finish)],
	]
	if reverse:
		stops.reverse()
	route.append_array(stops)


func _land() -> bool:
	for _frame in 150:
		_player.velocity.y -= GRAVITY / 60.0
		_player.move_and_slide()
		await physics_frame
		if _player.is_on_floor():
			return true
	return false


func _walk_to(target: Vector3, label: String) -> bool:
	var best_distance := _flat_distance(_player.global_position, target)
	var stalled_frames := 0
	var airborne_frames := 0
	for _frame in 1800:
		var offset := target - _player.global_position
		offset.y = 0.0
		if offset.length() < TARGET_RADIUS:
			if not _player.is_on_floor():
				return _fail("%s reached while airborne at %s" % [label, str(_player.global_position)])
			return true
		var heading := offset.normalized()
		_player.velocity.x = heading.x * WALK_SPEED
		_player.velocity.z = heading.z * WALK_SPEED
		_player.velocity.y -= GRAVITY / 60.0
		_player.move_and_slide()
		airborne_frames = 0 if _player.is_on_floor() else airborne_frames + 1
		if airborne_frames > 8:
			return _fail("%s has a floor gap near %s" % [label, str(_player.global_position)])
		var distance := _flat_distance(_player.global_position, target)
		if distance < best_distance - .02:
			best_distance = distance
			stalled_frames = 0
		else:
			stalled_frames += 1
		if stalled_frames > 100:
			return _fail("%s blocked near %s by %s target=%s" % [
				label, str(_player.global_position), _collision_summary(), str(target)])
		await physics_frame
	return _fail("%s timed out near %s target=%s" % [label,
		str(_player.global_position), str(target)])


func _collision_summary() -> String:
	var result := ""
	for collision_index in _player.get_slide_collision_count():
		var collision := _player.get_slide_collision(collision_index)
		var collider := collision.get_collider() as CollisionObject3D
		var source_mesh := ""
		if collider != null:
			var owner_id := collider.shape_find_owner(collision.get_collider_shape_index())
			if owner_id != 0:
				var owner := collider.shape_owner_get_owner(owner_id)
				if owner != null:
					source_mesh = str(owner.get_meta("source_mesh", ""))
		result += "%s source=%s normal=%s; " % [
			str(collider.get_path()), source_mesh, str(collision.get_normal())]
	return result


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _cleanup() -> void:
	if is_instance_valid(_player):
		_player.queue_free()
	if is_instance_valid(_world):
		_world.queue_free()
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(STATE_PATH)


func _fail(message: String) -> bool:
	push_error("MindSparkAllQuestTraversal: " + message)
	_cleanup()
	quit(1)
	return false
