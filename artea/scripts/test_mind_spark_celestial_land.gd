extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const EXPECTED_CENTRES := [Vector3(-860, 2, 170), Vector3(-670, 2, 85),
	Vector3(-215, 10, -80), Vector3(-15, 10, 15), Vector3(430, 18, 25), Vector3(655, 18, -75)]
const EXPECTED_RADII := [125.0, 155.0, 150.0, 122.0, 175.0, 145.0]
const EXPECTED_REVISIONS := ["v11", "v12", "v16", "v17", "v11", "v11"]
const EXPECTED_DESIGNS := ["Sun Gate", "Verdant Engine Gardens", "Astral Observatory",
	"Dawn Viaduct", "Stormworks Bastion", "Crownroot Sanctuary"]
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("CELESTIAL_LAND: " + message)


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://test_celestial_land_objects.json"
	root.add_child(world)
	for _frame in 4:
		await physics_frame
	var shared_paving: Mesh
	var rock_profiles := {}
	var triangle_count := 0
	for index in 6:
		var zone_id: String = world.get_zone_ids()[index]
		var zone := world.get_node("WorldOneGeometry/" + zone_id.to_pascal_case()) as Node3D
		_check(zone.position.is_equal_approx(EXPECTED_CENTRES[index]), "zone position changed: " + zone_id)
		_check(is_equal_approx(world.get_zone_radius(zone_id), EXPECTED_RADII[index]), "zone radius changed")
		var land := zone.get_node_or_null("ModularFloatingFoundation") as Node3D
		_check(land != null, "missing celestial foundation")
		if land == null:
			continue
		_check(land.get_meta("source_revision", "") == EXPECTED_REVISIONS[index], "wrong art revision")
		_check(land.get_meta("style_reference_revision", "") == "v07", "wrong selected style")
		_check(land.get_meta("editable_island_part_count", 0) == 3000, "wrong per-island authoring count")
		_check(land.scale.is_equal_approx(Vector3.ONE * EXPECTED_RADII[index]), "incorrect shell scale")
		_check(land.find_children("*", "CollisionObject3D", true, false).is_empty(), "art shell adds gameplay obstacles")
		var expected_meshes := 14 if index == 2 else (10 if index == 3 else 6)
		_check(land.find_children("*", "MeshInstance3D", true, false).size() == expected_meshes, "unexpected batched visual families / moving assemblies")
		_check(land.find_child("CharcoalFloatingUnderbody", true, false) == null, "old land still visible")
		_check(land.get_meta("variant_design", "") == EXPECTED_DESIGNS[index], "wrong island design mapping")
		var paving := land.find_child("CelestialIvoryDeck", true, false) as MeshInstance3D
		_check(paving != null, "shared paving is missing")
		if paving != null:
			if index == 0:
				shared_paving = paving.mesh
			else:
				_check(paving.mesh == shared_paving, "paving should share one mesh resource")
		var rock_name := "Rock_v17_04" if index == 3 else "Rock_v11_%02d" % (index+1)
		var rock := land.find_child(rock_name, true, false) as MeshInstance3D
		_check(rock != null, "missing variant-specific rock profile")
		if rock != null:
			rock_profiles[snappedf(rock.mesh.get_aabb().size.y, 0.001)] = true
			if index == 1:
				_check(rock.mesh.get_aabb().size.y > 1.95, "Verdant split keels need their distinct longer silhouette")
				_check(land.get_meta("scenic_terraces", 0) == 4, "missing four hanging-garden terraces")
				_check(land.get_meta("silhouette", "") == "split asymmetric hanging-garden keels", "wrong Verdant silhouette")
			elif index == 2:
				_check(rock.mesh.get_aabb().size.y > 2.05, "Astral citadel is missing its crystalline needle keel")
				_check(land.get_meta("observation_turrets", 0) == 2, "Astral citadel needs two outboard turrets")
				_check(land.get_meta("lateral_flywheel_engines", 0) == 2, "Astral lower side bays need two engines")
				_check(land.get_meta("rear_condenser_vessels", 0) == 2, "Astral aft plant needs twin condensers")
				_check(land.get_meta("lower_service_gallery", false), "Astral underside needs its service gallery")
				_check(land.get_meta("enclosed_side_bays", 0) == 2, "Astral side chambers are missing")
				_check(land.get_meta("ground_barrier_completion", false), "Astral perimeter infills are missing")
			elif index == 3:
				_check(land.get_meta("silhouette", "") == "celestial oval engine arcades with split keels", "wrong Dawn arcade silhouette")
				_check(land.get_meta("winged_load_ribs", 0) == 14, "Dawn load wings need fourteen structural ribs")
				_check(land.get_meta("moving_gear_assemblies", 0) == 4, "Dawn engines need four independent gear assemblies")
		for visual_node in land.find_children("*", "MeshInstance3D", true, false):
			var visual := visual_node as MeshInstance3D
			_check(visual.mesh != null, "empty mesh")
			var is_railing := str(visual.name).begins_with("Railing_")
			var railing_clear := true
			var elevated_castle_clear := true
			var dawn_elevated_clear := true
			var route_directions: Array[Vector3] = []
			for neighbor in [(index + 5) % 6, (index + 1) % 6]:
				var direction: Vector3 = EXPECTED_CENTRES[neighbor] - EXPECTED_CENTRES[index]
				direction.y = 0.0
				route_directions.append(direction.normalized())
			if index == 4:
				route_directions.append(Vector3.BACK)
			var top := -INF
			for surface in visual.mesh.get_surface_count():
				var arrays := visual.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangle_count += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
				for vertex in vertices:
					top = maxf(top, zone.to_local(visual.to_global(vertex)).y)
					if index == 2 and not is_railing:
						var point := land.to_local(visual.to_global(vertex))
						if point.y > 0.0004:
							elevated_castle_clear = elevated_castle_clear and Vector2(point.x, point.z).length() > 1.03 and point.y < 0.55
							for direction in route_directions:
								if point.dot(direction) > 0.72 and absf(point.x * direction.z - point.z * direction.x) < 22.0 / EXPECTED_RADII[index]:
									elevated_castle_clear = false
					elif index == 3 and not is_railing:
						var point := land.to_local(visual.to_global(vertex))
						if point.y > 0.095:
							dawn_elevated_clear = dawn_elevated_clear and Vector2(point.x, point.z).length() > 0.985 and point.y < 1.6 / EXPECTED_RADII[index]
							for direction in route_directions:
								if point.dot(direction) > 0.72 and absf(point.x * direction.z - point.z * direction.x) < 22.0 / EXPECTED_RADII[index]:
									dawn_elevated_clear = false
					if is_railing:
						var point := land.to_local(visual.to_global(vertex))
						var radial := Vector2(point.x, point.z).length()
						railing_clear = railing_clear and (radial > 0.985 and radial < 1.0 and point.y < 3.2 / EXPECTED_RADII[index] if index in [2, 3] else radial > 1.003)
						for direction in route_directions:
							if point.dot(direction) > 0.72 and absf(point.x * direction.z - point.z * direction.x) < 22.0 / EXPECTED_RADII[index] - 0.00001:
								railing_clear = false
			if is_railing:
				if not visual.is_visible_in_tree():
					continue
				_check(railing_clear, "reference railings obstruct disc, bridge or station approach: " + str(visual.name))
			elif index == 2:
				_check(elevated_castle_clear, "Astral turrets intrude into walking disc or bridge corridors")
			elif index == 3:
				_check(dawn_elevated_clear, "Dawn guard posts intrude into its floor or bridge corridors")
			else:
				_check(top <= 0.095, "%s intrudes %.3f m above the walkable plane" % [visual.name, top])
		var floor_body := zone.get_node("WalkableZoneFloorCollision") as StaticBody3D
		var floor_shell := zone.get_node("WalkableZoneFloor") as MeshInstance3D
		_check(not (floor_shell.mesh as CylinderMesh).cap_top, "old cap overlaps the imported paving")
		_check(is_equal_approx(floor_body.physics_material_override.friction, 0.9), "floor friction changed")
		# Perimeter samples deliberately avoid authored courts and quest props.
		for sample in 12:
			var angle := TAU * float(sample) / 12.0
			var at := zone.to_global(Vector3(sin(angle) * EXPECTED_RADII[index] * 0.90, 2,
				cos(angle) * EXPECTED_RADII[index] * 0.90))
			var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 6, 1)
			var hit := root.world_3d.direct_space_state.intersect_ray(query)
			_check(not hit.is_empty(), "missing perimeter support: " + zone_id)
		# Probe the replacement barriers on exposed edges in the current layout.
		for sample in 12:
			var angle := TAU * float(sample) / 12.0
			if not world._is_exposed_garden_edge(index, angle):
				continue
			var outward := Vector3(sin(angle), 0, cos(angle))
			var edge: float = EXPECTED_RADII[index] * 0.985
			var inside := zone.to_global(outward * (edge - 2.0) + Vector3.UP * 3.0)
			var outside := zone.to_global(outward * (edge + 2.0) + Vector3.UP * 3.0)
			var barrier_query := PhysicsRayQueryParameters3D.create(inside, outside, 1)
			_check(not root.world_3d.direct_space_state.intersect_ray(barrier_query).is_empty(),
				"exposed edge needs collision: " + zone_id)
	_check(rock_profiles.size() == 6, "six designs must have six genuinely different rock profiles")
	# Two reference enginehouses per island and reinstated ornate balustrades.
	# Authoring granularity is batched to six runtime mesh nodes per island.
	_check(triangle_count > 10000 and triangle_count < 3500000, "whole-family geometry budget: %d" % triangle_count)
	world.queue_free()
	await process_frame
	if _failures == 0:
		print("CELESTIAL_LAND: PASS — six distinct designs, shared paving, %d total visible triangles, fused-island footprints, 72 support probes, no new obstacles" % triangle_count)
	quit(1 if _failures else 0)
