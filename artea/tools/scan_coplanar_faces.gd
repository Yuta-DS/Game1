extends SceneTree
## Lists z-fighting candidates: faces of different primitive meshes that lie in
## the same plane and overlap.
##
##   Godot --headless --path artea --script res://tools/scan_coplanar_faces.gd \
##       -- res://scenes/art_castle_floating_world.tscn [plane tolerance m]
##
## Covers BoxMesh faces, PlaneMesh (FACE_Y) and CylinderMesh end caps -- what
## the runtime builders use for almost all architecture. ArrayMesh and other
## custom geometry is skipped and only counted. Opposite-facing faces are only
## reported when one material renders both sides (cull disabled), since
## otherwise one of the two is always back-face culled.

## Metres between planes still treated as one. Far-away geometry can z-fight
## at a few centimetres, so pass a larger value as the second argument.
var PLANE_TOLERANCE := 0.004
const MIN_AREA := 0.01          # m2 of overlap worth reporting
const SETTLE_FRAMES := 30       # frames with no new nodes before scanning
const MAX_FRAMES := 1500

var _faces: Array[Dictionary] = []
var _skipped_meshes := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if not args.is_empty() else "res://scenes/art_castle_floating_world.tscn"
	if args.size() > 1:
		PLANE_TOLERANCE = float(args[1])
	var scene := (load(path) as PackedScene).instantiate()
	root.add_child(scene)

	# Runtime builders add geometry over several frames; wait until it settles.
	var last_count := -1
	var stable := 0
	for frame in MAX_FRAMES:
		await process_frame
		var count := scene.find_children("*", "MeshInstance3D", true, false).size()
		stable = stable + 1 if count == last_count else 0
		last_count = count
		if stable >= SETTLE_FRAMES:
			break

	# Report what hides the skipped meshes, so a coverage gap is visible.
	var hidden_by := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if not instance.is_visible_in_tree():
			var hider: Node = instance
			var cursor: Node = instance
			while cursor != scene and cursor != null:
				if cursor is Node3D and not (cursor as Node3D).visible:
					hider = cursor
				cursor = cursor.get_parent()
			var hider_path := str(scene.get_path_to(hider))
			hidden_by[hider_path] = int(hidden_by.get(hider_path, 0)) + 1
		_collect(instance)
	var hiders := hidden_by.keys()
	hiders.sort_custom(func(x, y) -> bool: return hidden_by[x] > hidden_by[y])
	for hider_path in hiders.slice(0, 15):
		print("HIDDEN %6d meshes under %s" % [hidden_by[hider_path], hider_path])
	var pairs := _find_pairs(scene)
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.area > b.area)
	for pair in pairs:
		print("%s %7.2f m2 | %s [%s] | %s [%s] | at %s | normal %s" % [
			"HIDDEN_PAIR" if pair.hidden else "COPLANAR", pair.area, pair.a, pair.mat_a, pair.b, pair.mat_b,
			_fmt(pair.at), _fmt(pair.normal)])
	print("SCAN_DONE %s: %d meshes, %d faces, %d custom meshes skipped, %d overlaps" % [
		path, last_count, _faces.size(), _skipped_meshes, pairs.size()])
	quit()


func _collect(instance: MeshInstance3D) -> void:
	if instance.mesh == null:
		return
	var xf := instance.global_transform
	var mesh := instance.mesh
	if mesh is BoxMesh:
		var h: Vector3 = (mesh as BoxMesh).size * 0.5
		for axis in 3:
			for sign_value in [-1.0, 1.0]:
				var u := (axis + 1) % 3
				var v := (axis + 2) % 3
				var corners := PackedVector3Array()
				for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					var p := Vector3.ZERO
					p[axis] = h[axis] * sign_value
					p[u] = h[u] * c.x
					p[v] = h[v] * c.y
					corners.append(xf * p)
				var n := Vector3.ZERO
				n[axis] = sign_value
				_add_face(instance, corners, (xf.basis * n).normalized())
	elif mesh is PlaneMesh and (mesh as PlaneMesh).orientation == PlaneMesh.FACE_Y:
		var s: Vector2 = (mesh as PlaneMesh).size * 0.5
		var corners := PackedVector3Array()
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			corners.append(xf * Vector3(s.x * c.x, 0.0, s.y * c.y))
		_add_face(instance, corners, (xf.basis * Vector3.UP).normalized())
	elif mesh is CylinderMesh:
		var cylinder := mesh as CylinderMesh
		var segments := maxi(cylinder.radial_segments, 3)
		for cap in [[cylinder.top_radius, 1.0], [cylinder.bottom_radius, -1.0]]:
			if cap[0] <= 0.0:
				continue
			var ring := PackedVector3Array()
			for i in segments:
				var angle := TAU * float(i) / float(segments)
				ring.append(xf * Vector3(sin(angle) * cap[0], cylinder.height * 0.5 * cap[1],
					cos(angle) * cap[0]))
			_add_face(instance, ring, (xf.basis * Vector3(0, cap[1], 0)).normalized())
	else:
		_skipped_meshes += 1


func _add_face(instance: MeshInstance3D, corners: PackedVector3Array, normal: Vector3) -> void:
	# Canonical normal: first non-zero component positive, so a face and its
	# opposite-facing twin land in the same bucket.
	var canon := normal
	for i in 3:
		if absf(canon[i]) > 0.0001:
			if canon[i] < 0.0:
				canon = -canon
			break
	_faces.append({
		"node": instance, "corners": corners, "facing": normal.dot(canon) > 0.0,
		"canon": canon, "d": canon.dot(corners[0]),
	})


func _find_pairs(scene: Node) -> Array[Dictionary]:
	var buckets := {}
	for index in _faces.size():
		var face := _faces[index]
		var c: Vector3 = face.canon
		var key := "%d,%d,%d,%d" % [roundi(c.x * 200), roundi(c.y * 200), roundi(c.z * 200),
			floori(face.d / PLANE_TOLERANCE)]
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(index)

	var pairs: Array[Dictionary] = []
	var seen := {}
	for key in buckets:
		var parts: PackedStringArray = key.split(",")
		var base := "%s,%s,%s," % [parts[0], parts[1], parts[2]]
		var slot := int(parts[3])
		var others: Array = []
		for neighbour in [slot, slot + 1]:
			others.append_array(buckets.get(base + str(neighbour), []))
		for i in buckets[key]:
			for j in others:
				if i == j or seen.has(Vector2i(mini(i, j), maxi(i, j))):
					continue
				seen[Vector2i(mini(i, j), maxi(i, j))] = true
				var pair := _compare(_faces[i], _faces[j], scene)
				if not pair.is_empty():
					pairs.append(pair)
	return pairs


func _compare(a: Dictionary, b: Dictionary, scene: Node) -> Dictionary:
	if a.node == b.node or absf(float(a.d) - float(b.d)) > PLANE_TOLERANCE:
		return {}
	var mat_a := _material(a.node)
	var mat_b := _material(b.node)
	if a.facing != b.facing and not (_cull_disabled(mat_a) or _cull_disabled(mat_b)):
		return {}
	if _looks_identical(mat_a, mat_b):
		return {}
	var canon: Vector3 = a.canon
	var u := canon.cross(Vector3.UP if absf(canon.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := canon.cross(u)
	var area := 0.0
	var centre := Vector2.ZERO
	for poly in Geometry2D.intersect_polygons(_project(a.corners, u, v), _project(b.corners, u, v)):
		var poly_area := absf(_area(poly))
		area += poly_area
		for p in poly:
			centre += p * poly_area / float(poly.size())
	if area < MIN_AREA:
		return {}
	centre /= area
	var hidden: bool = not (a.node as MeshInstance3D).is_visible_in_tree() 		or not (b.node as MeshInstance3D).is_visible_in_tree()
	return {
		"area": area, "hidden": hidden,
		"a": str(scene.get_path_to(a.node)), "b": str(scene.get_path_to(b.node)),
		"mat_a": _describe(mat_a), "mat_b": _describe(mat_b),
		"at": u * centre.x + v * centre.y + canon * float(a.d), "normal": canon,
	}


func _project(points: PackedVector3Array, u: Vector3, v: Vector3) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(p.dot(u), p.dot(v)))
	if _area(out) < 0.0:
		out.reverse()
	return out


func _area(poly: PackedVector2Array) -> float:
	var total := 0.0
	for i in poly.size():
		total += poly[i].cross(poly[(i + 1) % poly.size()])
	return total * 0.5


func _material(instance: MeshInstance3D) -> Material:
	if instance.material_override != null:
		return instance.material_override
	if instance.get_surface_override_material_count() > 0 \
			and instance.get_surface_override_material(0) != null:
		return instance.get_surface_override_material(0)
	return instance.mesh.surface_get_material(0) if instance.mesh.get_surface_count() > 0 else null


func _cull_disabled(material: Material) -> bool:
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED
	if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
		return "cull_disabled" in (material as ShaderMaterial).shader.code
	return false


func _looks_identical(a: Material, b: Material) -> bool:
	if a == b:
		return true
	if a is StandardMaterial3D and b is StandardMaterial3D:
		var sa := a as StandardMaterial3D
		var sb := b as StandardMaterial3D
		return sa.albedo_color.is_equal_approx(sb.albedo_color) \
			and sa.albedo_texture == sb.albedo_texture \
			and sa.emission_enabled == sb.emission_enabled \
			and (not sa.emission_enabled or sa.emission.is_equal_approx(sb.emission))
	return false


func _describe(material: Material) -> String:
	if material is StandardMaterial3D:
		return "#" + (material as StandardMaterial3D).albedo_color.to_html(false)
	if material is ShaderMaterial:
		return "shader"
	return "none" if material == null else material.get_class()


func _fmt(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
