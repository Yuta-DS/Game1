extends SceneTree

const Style := preload("res://scripts/castle_reference_style.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for frame in 90:
		await process_frame
		await physics_frame
	if hub.get_meta("castle_style_reference", "") != "original_right_tower_atlas":
		_fail("shared style was not applied")
		return
	var shapes := _collision_snapshot(hub)
	Style.apply_route(hub)
	if shapes != _collision_snapshot(hub):
		_fail("material pass changed collision geometry or transforms")
		return
	var patches := 0
	var stone_meshes := 0
	for path: String in Style.ROOTS:
		var route := hub.get_node(path)
		for patch: Node3D in route.find_children("ReferenceStonePatch*", "Node3D", true, false):
			patches += 1
			if patch.find_children("*", "CollisionObject3D", true, false).size() != 0 \
					or patch.find_children("*", "MeshInstance3D", true, false).size() != 1:
				_fail("stone patch added snag colliders or unbatched small meshes")
				return
		for mesh: MeshInstance3D in route.find_children("*", "MeshInstance3D", true, false):
			if not mesh.is_visible_in_tree() or mesh.mesh == null:
				continue
			for index in mesh.mesh.get_surface_count():
				var mat := mesh.get_active_material(index) as StandardMaterial3D
				if mat and mat.has_meta("reference_castle_role"):
					stone_meshes += 1
					var role: String = mat.get_meta("reference_castle_role")
					if mat.albedo_color != Style.material(role).albedo_color or mat.emission_enabled:
						_fail("reference material lost its sampled colour/non-emissive finish")
						return
	if patches < 75 or stone_meshes < 500:
		_fail("style pass did not cover the complete route")
		return
	var stair := hub.get_node("CastleStairs/CastleStair")
	if not _soffit_edge_is_welded(stair):
		_fail("soffit and parapet do not share one continuous lower edge")
		return
	var windows := stair.find_children("ReferenceRoundArchWindow*", "Node3D", false, false)
	var bands := stair.find_children("StoneCourse_*", "MeshInstance3D", false, false)
	if windows.size() != 20:
		_fail("five tiers of round-headed tower windows were not built")
		return
	for window: Node3D in windows:
		for band: MeshInstance3D in bands:
			var bounds := band.global_transform * band.mesh.get_aabb()
			var lo := window.global_position.y - 1.08 * window.scale.y
			var hi := window.global_position.y + 0.94 * window.scale.y
			if lo < bounds.end.y and hi > bounds.position.y:
				_fail("structural tower band intersects a window")
				return
	var original := hub.get_node("building_castle_red2/building_castle_red") as MeshInstance3D
	if (original.get_active_material(0) as StandardMaterial3D).albedo_texture == null:
		_fail("original tower atlas was overwritten")
		return
	for shader_path: String in ["res://shaders/castle_courtyard_stone.gdshader", "res://shaders/castle_palace_paving.gdshader"]:
		var shader := load(shader_path) as Shader
		if not "OUTPUT_IS_SRGB" in shader.code or "VERTEX +=" in shader.code:
			_fail("floor finish lacks renderer colour parity or displaces the physical surface")
			return
	print("CASTLE_REFERENCE_STYLE_TEST: PASS — %d route stone surfaces, %d batched patches, 20 aligned round windows; %d colliders unchanged; original atlas preserved" % [stone_meshes, patches, shapes.size()])
	quit(0)

func _collision_snapshot(hub: Node) -> Dictionary:
	var result := {}
	for path: String in Style.ROOTS:
		for shape: CollisionShape3D in hub.get_node(path).find_children("*", "CollisionShape3D", true, false):
			result[str(shape.get_path())] = [shape.global_transform, shape.shape.get_rid(), shape.disabled]
	return result

func _soffit_edge_is_welded(stair: Node) -> bool:
	var wall := stair.get_node("OuterStoneParapet") as MeshInstance3D
	var soffit := stair.get_node("AscentRoadbed") as MeshInstance3D
	if not wall.get_meta("underside_owned_by_soffit", false):
		return false
	var normals: PackedVector3Array = soffit.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	if not soffit.mesh.get_meta("outward_visual_helix", false) or normals[0].y < 0.5 or normals[6].y > -0.5:
		return false
	var base: Vector2 = stair.get_meta("tower_base")
	var bottom_points := {}
	var floor_vertices: PackedVector3Array = soffit.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var wall_vertices: PackedVector3Array = wall.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for point in floor_vertices:
		var xz := Vector2(point.x, point.z)
		if absf(xz.distance_to(base) - 8.72) < 0.001:
			if not bottom_points.has(xz) or point.y < bottom_points[xz].y:
				bottom_points[xz] = point
	if bottom_points.size() < 96:
		return false
	for point: Vector3 in bottom_points.values():
		var matched := false
		for edge_point in wall_vertices:
			if point.distance_squared_to(edge_point) < 0.000001:
				matched = true
				break
		if not matched:
			return false
	return true

func _fail(message: String) -> void:
	push_error("CASTLE_REFERENCE_STYLE_TEST: " + message)
	quit(1)
