extends "res://scripts/test_castle_rooftop_barrier_safety.gd"

const Fountain := preload("res://scripts/castle_royal_fountain.gd")


func _fail(message: String) -> void:
	push_error("CASTLE_ROYAL_FOUNTAIN_TEST: %s" % message)
	quit(1)


func _land_on_roof(player: CharacterBody3D, roof_y: float) -> bool:
	# A horizontal waypoint can be reached while still falling from the upper
	# basin. Advance real gravity in place; never teleport feet onto the floor.
	for _frame in 120:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		player.velocity.y -= GRAVITY_PER_FRAME
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			return absf(player.global_position.y - roof_y) < 0.06
	return false


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 80:
		await process_frame
		await physics_frame
	var stair := hub.get_node("CastleStairs/CastleStair") as Node3D
	var fountain := stair.get_node_or_null("CastleRoyalFountain") as Node3D
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.set_physics_process(false)
	player.set_process_input(false)
	if fountain == null or stair.get_node_or_null("CastleBallista") != null:
		_fail("fountain did not replace the ballista")
		return
	var origin := fountain.global_position
	var tower_base: Vector2 = stair.get_meta("tower_base")
	if Vector2(origin.x, origin.z).distance_to(tower_base) > 0.001:
		_fail("fountain is not at the exact rooftop centre")
		return
	var carving := fountain.find_child("FountainStone", true, false) as MeshInstance3D
	if carving == null or carving.mesh.get_aabb().end.y > 2.36 \
			or carving.mesh.get_aabb().end.y < 2.30 \
			or carving.mesh.get_aabb().size.x < 3.30:
		_fail("refined stone must be 3.3m wide and 2.3m tall without importer widgets")
		return
	var triangles := 0
	for surface in carving.mesh.get_surface_count():
		var arrays := carving.mesh.surface_get_arrays(surface)
		triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	if triangles < 40000 or triangles > 60000:
		_fail("stone triangulation is missing or exceeds the focused fountain budget: %d" % triangles)
		return
	var crown_y := float(stair.get_meta("tower_top_y")) + CROWN_SURFACE_OFFSET
	if absf(origin.y - crown_y) > 0.001 \
			or fountain.find_children("*", "StaticBody3D", true, false).size() != 1 \
			or int(fountain.get_meta("water_stream_count", 0)) != 8:
		_fail("fountain is not grounded, solid or complete")
		return
	var pool := fountain.find_child("LowerBasinWater", true, false) as MeshInstance3D
	var stream := fountain.find_child("BasinCascade_0", true, false) as MeshInstance3D
	var pool_material := pool.material_override as ShaderMaterial
	var stream_material := stream.material_override as ShaderMaterial
	if pool_material == null or stream_material == null or not pool.is_visible_in_tree():
		_fail("castle styling hid the fountain water")
		return
	var time_before := float(pool_material.get_shader_parameter("flow_time"))
	var animation := fountain.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation == null or not animation.is_playing() or stream.mesh.get_blend_shape_count() != 3:
		_fail("Blender water does not contain a playing deformation animation")
		return
	var shape_before := stream.get_blend_shape_value(0)
	var droplet := fountain.find_child("BasinCascade droplet 0 0", true, false) as Node3D
	if droplet == null:
		_fail("Blender droplets missing")
		return
	var drop_before := droplet.position
	var droplets := fountain.find_children("*droplet*", "MeshInstance3D", true, false)
	var droplet_positions: Array[Vector3] = []
	for candidate: Node3D in droplets:
		droplet_positions.append(candidate.position)
	var spray := fountain.get_node("LowerImpactSpray") as MultiMeshInstance3D
	var upper_spray := fountain.get_node("UpperImpactSpray") as MultiMeshInstance3D
	if spray.multimesh.instance_count != 48 or upper_spray.multimesh.instance_count != 32:
		_fail("impact spray must use two instanced batches with 80 droplets")
		return
	var spray_before := spray.multimesh.get_instance_transform(0).origin
	# Dummy/headless rendering does not store MultiMesh transforms. The same
	# test under mobile, plus the isolated GL render test, verifies GPU instances.
	var has_renderer := DisplayServer.get_name() != "headless"
	for _frame in 16:
		await process_frame
	var drops_moving := 0
	for index in droplets.size():
		if (droplets[index] as Node3D).position.distance_to(droplet_positions[index]) > 0.000001:
			drops_moving += 1
	if float(pool_material.get_shader_parameter("flow_time")) <= time_before \
			or float(stream_material.get_shader_parameter("flow_time")) <= time_before \
			or absf(stream.get_blend_shape_value(0) - shape_before) < 0.000001 \
			or drops_moving < 4 \
			or (has_renderer and spray.multimesh.get_instance_transform(0).origin.distance_to(spray_before) < 0.000001):
		_fail("fountain animation: pool %.6f→%.6f stream %.6f shape %.6f→%.6f drop %s→%s animation=%s" % [
			time_before, float(pool_material.get_shader_parameter("flow_time")),
			float(stream_material.get_shader_parameter("flow_time")), shape_before,
			stream.get_blend_shape_value(0), drop_before, droplet.position, animation.current_animation])
		return
	for batch: MultiMeshInstance3D in [spray, upper_spray]:
		if not has_renderer:
			continue
		var floor_y := Fountain.BASIN_FLOOR_Y if batch == spray else Fountain.UPPER_FLOOR_Y
		var water_radius := Fountain.LOWER_WATER_RADIUS if batch == spray else Fountain.UPPER_WATER_RADIUS
		for index in batch.multimesh.instance_count:
			var point := batch.multimesh.get_instance_transform(index).origin
			if point.y < floor_y or Vector2(point.x, point.z).length() > water_radius:
				_fail("splash escaped the visible basin: %s" % point)
				return
	var space := fountain.get_world_3d().direct_space_state
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var radial := Vector3(cos(angle), 0, sin(angle))
		var query := PhysicsRayQueryParameters3D.create(
			origin + radial * 2.15 + Vector3.UP * 0.83,
			origin + radial * 1.1 + Vector3.UP * 0.83)
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty() or not fountain.is_ancestor_of(hit.collider):
			_fail("stone basin has a collision gap at side %d" % index)
			return
		# The packed player is a full metre wide. Leave enough room for the
		# chord between adjacent waypoints, not only a zero-width circular ray.
		var outside := origin + radial * Fountain.AISLE_CENTRE_RADIUS
		if not await _settle(player, outside + Vector3.UP * 2.0):
			_fail("player could not stand beside fountain")
			return
		await _run_direction(player, -radial, 10)
		if player.global_position.y < crown_y - 0.05:
			_fail("player sank through the fountain or rooftop")
			return
		if not await _walk_to(player, outside):
			_fail("player stuck after fountain impact at side %d: %s" % [index, player.global_position])
			return
		# Traverse the complete surrounding aisle in both diagonal and cardinal
		# directions, including the narrow side nearest the planted perimeter.
		var next_angle := angle + TAU / 8.0
		var next := origin + Vector3(cos(next_angle), 0, sin(next_angle)) * Fountain.AISLE_CENTRE_RADIUS
		if not await _walk_to(player, next) or not await _land_on_roof(player, crown_y):
			_fail("fountain aisle side %d: position=%s target=%s floor=%s height=%.3f" % [
				index, player.global_position, next, player.is_on_floor(), player.global_position.y - crown_y])
			return
	# Drop the real capsule onto the stone rim, basin and upper bowl, then
	# walk away. This exercises support and overhang escape, not node presence.
	for radius: float in [1.51, 1.11, 0.52]:
		var landing := origin + Vector3(radius, 4.0, 0)
		if not await _settle(player, landing):
			_fail("player fell through fountain landing radius %.2f" % radius)
			return
		if player.global_position.y < crown_y + Fountain.BASIN_FLOOR_Y - 0.01:
			_fail("player feet sank beneath the shallow basin floor")
			return
		if not await _walk_to(player, origin + Vector3(Fountain.AISLE_CENTRE_RADIUS, 0, 0)) \
				or not await _land_on_roof(player, crown_y):
			_fail("player stuck leaving a fountain landing radius %.2f" % radius)
			return
	print("CASTLE_ROYAL_FOUNTAIN_TEST: PASS — enlarged 3.3m basin, %d stone triangles, Blender mesh deformation, gravity droplets and 80 impact sprays; 8 solid rim probes, 8 impacts/escapes, full garden aisle and 3 landing exits" % triangles)
	quit(0)
