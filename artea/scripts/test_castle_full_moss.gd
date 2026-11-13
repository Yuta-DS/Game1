extends SceneTree

const Moss := preload("res://scripts/castle_stair_moss.gd")

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("FULL_STAIR_MOSS_TEST: " + message)
	quit(1)

func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for frame in 90:
		await process_frame
		await physics_frame
	var stair := hub.get_node("CastleStairs/CastleStair") as Node3D
	var surfaces: Array = hub.get_meta("castle_stair_moss_surfaces", [])
	if surfaces.size() < 40 or surfaces.size() > 300:
		_fail("wall coverage missing or excessive draw overhead: %d" % surfaces.size())
		return
	var ground := float(stair.get_meta("terrain_ground_y"))
	var top := float(stair.get_meta("tower_top_y"))
	for label in ["MasonryTower", "OuterStoneParapet", "InnerStoneParapet", "TerrainFittedEntryFoundation"]:
		var mesh := stair.get_node(label) as MeshInstance3D
		if mesh.material_overlay == null or mesh.material_overlay.get_meta("castle_stair_moss", false) != true:
			_fail("moss missing from " + label)
			return
		if "Parapet" in label:
			var bounds := mesh.global_transform * mesh.get_aabb()
			if bounds.position.y > ground+2.0 or bounds.end.y < top:
				_fail("moss does not follow full-height spiral: " + label)
				return
	var upper := hub.get_node("CastleEntrance/CastleEntrance/RoyalCastleStair")
	var walls := upper.find_children("RoyalStairParapet*", "MeshInstance3D", false, false)
	if walls.size() != 2:
		_fail("upper stair walls not found")
		return
	for wall: MeshInstance3D in walls:
		if wall.material_overlay == null:
			_fail("upper castle ascent was left bare")
			return
	var entrance := hub.get_node("CastleEntrance/CastleEntrance")
	for label in ["CastleArrivalTerrace", "CastleArrivalUnderside", "CastleUpperCourt",
			"CastleUpperCourtUnderside", "CastleUpperCourtSideBarrier_L", "CastleUpperCourtSideBarrier_R"]:
		var face := entrance.get_node(label) as MeshInstance3D
		if face.material_overlay == null or not surfaces.has(face.get_path()):
			_fail("terrace side surface was left bare: " + label)
			return
	var court := hub.get_node("CastleArchitecture/RoyalEntranceCourtyard") as Node3D
	var side_counts := [0, 0]
	for wall: MeshInstance3D in court.find_children("CourtyardSideBarrier*", "MeshInstance3D", false, false):
		if "Coping" in String(wall.name):
			continue
		if wall.material_overlay == null or not surfaces.has(wall.get_path()):
			_fail("arrival terrace side barrier was left bare")
			return
		side_counts[0 if wall.position.z < 0.0 else 1] += 1
	if side_counts != [2, 2]:
		_fail("expected both barrier sections on each side of the terrace: %s" % str(side_counts))
		return
	var original: Dictionary = {}
	for path: NodePath in surfaces:
		var part := root.get_node(path) as MeshInstance3D
		if not is_equal_approx(float((part.material_overlay as ShaderMaterial).get_shader_parameter("remaining_fraction")),Moss.COVERAGE):
			_fail("wall did not retain the requested reduced moss setting")
			return
		var label := String(part.name).to_lower()
		if "tread" in label or "walk" in label or "floor" in label or "deck" in label \
				or "flame" in label or "shield" in label or "window" in label:
			_fail("protected walk/decorative surface was painted: " + label)
			return
		original[path] = [part.mesh, part.global_transform, part.material_override, part.material_overlay]
	for band: MeshInstance3D in stair.find_children("StoneCourse_*", "MeshInstance3D", true, false):
		if band.material_overlay != null:
			_fail("moss obscures the reference keep's dark structural courses")
			return
	var collisions: Dictionary = {}
	for shape: CollisionShape3D in hub.find_children("*", "CollisionShape3D", true, false):
		collisions[shape.get_instance_id()] = [shape.shape,shape.global_transform]
	Moss.apply(hub)
	if surfaces != hub.get_meta("castle_stair_moss_surfaces"):
		_fail("moss application is not idempotent")
		return
	for path: NodePath in original:
		var part := root.get_node(path) as MeshInstance3D
		if original[path] != [part.mesh,part.global_transform,part.material_override,part.material_overlay]:
			_fail("moss application altered existing geometry, finish or duplicated its pass")
			return
	for shape: CollisionShape3D in hub.find_children("*", "CollisionShape3D", true, false):
		if collisions.get(shape.get_instance_id()) != [shape.shape,shape.global_transform]:
			_fail("moss changed collision geometry")
			return
	print("FULL_STAIR_MOSS_TEST: PASS — %d existing wall surfaces; full spiral from %.2fm ground to %.2fm crown plus upper stair; materials, meshes and %d collision shapes preserved" % [surfaces.size(),ground,top,collisions.size()])
	quit(0)
