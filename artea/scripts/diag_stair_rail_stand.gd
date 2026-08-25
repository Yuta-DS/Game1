# Ad hoc diagnostic for the "jump on the railing and get stuck" report.
# Not part of the required regression suite (see AGENT.md); run manually:
#   Godot --headless --path artea --script res://scripts/diag_stair_rail_stand.gd
#
# Existing suites (test_castle_spiral_route.gd, test_castle_player_route.gd)
# only walk the tread walkway lanes. They never place the capsule on top of
# InnerContinuousCap itself, which is exactly where a player lands after
# jumping the inner rail. This settles the packed player on the cap at several
# points along the climb and tries to walk them forward along the spiral,
# failing if they don't move.
extends SceneTree

const HubCastleStairs = preload("res://scripts/hub_castle_stairs.gd")

const WALK_SPEED := 6.0
const MAX_FRAMES := 120
const STALL_FRAMES := 40


func _fail(message: String) -> void:
	push_error("STAIR_RAIL_STAND_DIAG: %s" % message)
	quit(1)


func _collider_label(player: CharacterBody3D) -> String:
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
	for _frame in 180:
		player.velocity.y -= 28.0 / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor() and absf(player.velocity.y) < 0.01:
			return true
	return false


func _walk_tangent(player: CharacterBody3D, tangent: Vector3) -> bool:
	var start := player.global_position
	var stalled := 0
	var best_progress := 0.0
	for _frame in MAX_FRAMES:
		player.velocity.x = tangent.x * WALK_SPEED
		player.velocity.z = tangent.z * WALK_SPEED
		player.velocity.y -= 28.0 / 60.0
		var intended := player.velocity
		var was_on_floor := player.is_on_floor()
		var before := player.global_position
		player.move_and_slide()
		player._try_step_up(was_on_floor, before, intended, 1.0 / 60.0)
		await physics_frame
		var progress := (player.global_position - start).length()
		if progress > best_progress + 0.01:
			best_progress = progress
			stalled = 0
		else:
			stalled += 1
		if stalled >= STALL_FRAMES:
			return false
	return true


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 60:
		await process_frame
		await physics_frame

	var stair := hub.get_node_or_null("CastleStairs/CastleStair") as Node3D
	var player := hub.get_node_or_null("NewPlayer") as CharacterBody3D
	if stair == null or player == null:
		_fail("castle stair or packed player did not load")
		return
	player.set_physics_process(false)
	player.set_process_input(false)

	var base: Vector2 = stair.get_meta("tower_base")
	var ground: float = stair.get_meta("terrain_ground_y")
	var top_y: float = stair.get_meta("tower_top_y")
	var start_angle := atan2(HubCastleStairs.CASTLE_XZ.y - base.y,
		HubCastleStairs.CASTLE_XZ.x - base.x) + PI
	var inner_edge := HubCastleStairs.STAIR_RADIUS - HubCastleStairs.STEP_WIDTH * 0.5
	var cap_radius := inner_edge
	var cap_top_offset := 1.43

	for t_value in [0.10, 0.35, 0.55, 0.75, 0.90, 0.97, 0.995]:
		var t: float = t_value
		var angle: float = start_angle + t * TAU * float(HubCastleStairs.TURNS)
		var y: float = lerpf(ground + float(HubCastleStairs.FIRST_TREAD_CENTRE_OFFSET), top_y, t)
		var stand_point := Vector3(
			base.x + cos(angle) * cap_radius,
			y + cap_top_offset + 1.0,
			base.y + sin(angle) * cap_radius)
		if not await _settle(player, stand_point):
			_fail("player did not settle on rail cap at t=%.3f, pos=%s; collisions: %s" % [
				t, player.global_position, _collider_label(player)])
			return
		var landed_on_floor := player.global_position.y
		var tangent := Vector3(-sin(angle), 0.0, cos(angle))
		if not await _walk_tangent(player, tangent):
			_fail("player stuck walking on rail cap at t=%.3f, settled at y=%.3f, stuck at %s; collisions: %s" % [
				t, landed_on_floor, player.global_position, _collider_label(player)])
			return
		print("  t=%.3f OK — settled y=%.3f, moved to %s" % [
			t, landed_on_floor, player.global_position])

	print("STAIR_RAIL_STAND_DIAG: PASS — player did not stick standing on the inner rail cap")
	quit(0)


func _init() -> void:
	call_deferred("_run")
