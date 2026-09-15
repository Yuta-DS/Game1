# The inner rooftop edge must be guarded in world space, not merely have a
# named mesh somewhere in the scene. Reuse the real packed-player driver.
extends "res://scripts/test_castle_rooftop_barrier_safety.gd"


func _fail(message: String) -> void:
	push_error("CASTLE_INNER_ROOF_GUARD_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 80:
		await process_frame
		await physics_frame
	var stair := hub.get_node("CastleStairs/CastleStair") as Node3D
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.set_physics_process(false)
	player.set_process_input(false)
	var base: Vector2 = stair.get_meta("tower_base")
	var crown_y := float(stair.get_meta("tower_top_y")) + CROWN_SURFACE_OFFSET
	var centre := Vector3(base.x, crown_y, base.y)
	var wall := stair.get_node("CrownStairwellInnerReturn") as MeshInstance3D
	if wall.global_position.distance_to(centre) > 0.01:
		_fail("inner barrier is not anchored to the rooftop: %s, expected %s" % [
			wall.global_position, centre])
		return
	var centre_angle := float(stair.get_meta("crown_stairwell_centre_angle"))
	var half_angle := float(stair.get_meta("crown_stairwell_half_angle"))
	var space := wall.get_world_3d().direct_space_state
	# Sample the whole exposed arc, including both joints, at knee and chest
	# height. A ray must hit this wall, not a distant parapet or the lower stair.
	for sample_index in 25:
		var angle := lerpf(centre_angle - half_angle, centre_angle + half_angle,
			float(sample_index) / 24.0)
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		for height: float in [0.25, 0.85]:
			var ray := PhysicsRayQueryParameters3D.create(
				centre + radial * 4.1 + Vector3.UP * height,
				centre + radial * 5.25 + Vector3.UP * height)
			ray.exclude = [player.get_rid()]
			var hit := space.intersect_ray(ray)
			if not hit.has("collider") or not wall.is_ancestor_of(hit["collider"]):
				_fail("unprotected inner roof edge at sample %d height %.2f" % [
					sample_index, height])
				return
	# Sprint into different points, including oblique wall contacts, then back
	# away. Keep both feet on the roof instead of falling into the stairwell.
	for sample_index in 7:
		var angle := lerpf(centre_angle - half_angle * 0.8,
			centre_angle + half_angle * 0.8, float(sample_index) / 6.0)
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := Vector3(-radial.z, 0.0, radial.x)
		if not await _settle(player, centre + radial * 3.6 + Vector3.UP * 2.2):
			_fail("player did not settle on roof")
			return
		var start_y := player.global_position.y
		var direction := (radial + tangent * (0.18 if sample_index % 2 else -0.18)).normalized()
		await _run_direction(player, direction, 26)
		var impact_radius := Vector2(player.global_position.x - base.x,
			player.global_position.z - base.y).length()
		if impact_radius > 4.6 or absf(player.global_position.y - start_y) > 0.12:
			_fail("player crossed/sank at inner guard sample %d: %s" % [
				sample_index, player.global_position])
			return
		if not await _walk_to(player, player.global_position - radial * 1.1):
			_fail("player stuck after inner guard impact %d" % sample_index)
			return
	print("CASTLE_INNER_ROOF_GUARD_TEST: PASS — 50 edge probes, 7 sprint/oblique impacts and clean escapes")
	quit(0)
