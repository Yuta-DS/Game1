# Irregular moss cushions and sparse ivy for an older enclosed castle garden.
# Source masonry still owns placement; no floor overlays or plant colliders.
extends RefCounted

const StairMoss := preload("res://scripts/castle_stair_moss.gd")

const MOSS := Color("4e6536")
const MOSS_LIGHT := Color("72834b")
const LEAF := Color("425a3c")
const LEAF_LIGHT := Color("647950")
const FIBRE := Color("889664")
const STEM := Color("4c5a37")
const IVORY := Color("f5e9d0")
const LAVENDER := Color("af87c3")
const GOLD := Color("d9b45c")


static func build(hub: Node3D) -> void:
	StairMoss.apply(hub)
	if hub.has_node("CastleRoyalBotanicals"):
		return
	var garden := Node3D.new()
	garden.name = "CastleRoyalBotanicals"
	hub.add_child(garden)
	garden.global_transform = Transform3D.IDENTITY
	garden.set_meta("preserve_castle_finish", true)
	garden.set_meta("style", "medieval_irregular_wall_moss_and_sparse_ivy")
	garden.set_meta("collision_policy", "visual_only_wall_attached_no_floor_growth")
	var material := StandardMaterial3D.new()
	material.resource_name = "Old castle moss and ivy palette"
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.89
	var templates: Array[ArrayMesh] = []
	for variant in 3:
		templates.append(_sprig(variant))
	var batches: Dictionary = {}
	var counts: Dictionary = {}
	var anchors: Array[Dictionary] = []
	var newel_bounds: Array[AABB] = []
	for newel: MeshInstance3D in hub.find_children("OuterStoneNewel_*", "MeshInstance3D", true, false):
		newel_bounds.append((newel.global_transform * newel.get_aabb()).grow(0.04))
	var sources: Array[Node] = []
	for path: String in ["CastleStairs/CastleStair", "CastleEntrance/CastleEntrance", "CastleArchitecture"]:
		var root := hub.get_node_or_null(path)
		if root:
			sources.append_array(root.find_children("ReferenceStonePatch*", "Node3D", true, false))
	for source: Node3D in sources:
		if not source.is_visible_in_tree():
			continue
		var path := String(source.get_path())
		var zone := "TowerAndArrival"
		var size := Vector3(0.78, 0.75, 1.0)
		var lift := 0.35
		var stride := 2
		if "OuterParapetMasonry" in path:
			zone = "SpiralOuter"
			size = Vector3(1.3, 1.15, 1.0)
			lift = 0.84
		elif "InnerParapetMasonry" in path:
			zone = "SpiralInner"
			size = Vector3(0.70, 0.70, 1.0)
			lift = 0.40
			stride = 3
		elif "CrownPalaceGardenArchitecture" in path:
			zone = "RooftopBorders"
			size = Vector3(0.72, 0.65, 1.0)
			lift = 0.34
			stride = 1
		elif "RoyalCastleStair" in path:
			zone = "RoyalStair"
			size = Vector3(1.1, 1.0, 1.0)
			lift = 0.02 # Keep growth below the royal shield, never over its crest.
			stride = 1
		elif "CastleArchitecture" in path:
			zone = "GateAndCourt"
			size = Vector3(0.78, 0.76, 1.0)
			lift = 0.40
			stride = 1
		counts[zone] = int(counts.get(zone, 0)) + 1
		var index := int(counts[zone]) - 1
		if index % stride != 0:
			continue
		var at := source.global_transform
		at.basis = at.basis.orthonormalized().scaled_local(size)
		at.origin += Vector3.UP * lift
		# Keep the root tucked behind the dressed stone; only soft blades,
		# fibres and petals stand slightly proud of the masonry face.
		at.origin -= source.global_basis.z.normalized() * 0.010
		if zone == "SpiralOuter":
			# Masonry patches and newels have different spacing on the helix.
			# Lower a sprig just below a post's foot instead of clipping its moss
			# through the post. No changes to the protected stair geometry.
			for bounds in newel_bounds:
				var plant_bounds := at * templates[index % 3].get_aabb()
				if plant_bounds.intersects(bounds):
					at.origin.y -= plant_bounds.end.y - bounds.position.y + 0.012
		_place(batches, anchors, zone, templates[index % 3], at, source)
	# Preserve the original keep's atlas/windows. Train sprigs on its added
	# buttresses instead of covering the imported window openings or roofs.
	var architecture := hub.get_node_or_null("CastleArchitecture")
	if architecture:
		for buttress: Node3D in architecture.find_children("GothicButtress_*", "Node3D", false, false):
			for tier in 2:
				var pier := buttress.get_node("ButtressPier_%02d" % (tier + 1)) as MeshInstance3D
				var box := pier.mesh as BoxMesh
				var side := signf(buttress.position.z)
				var normal := Vector3(0, 0, side)
				var basis := Basis(Vector3(side, 0, 0), Vector3.UP, normal)
				var at := pier.global_position + normal * (box.size.z * 0.5 + 0.008)
				at.y += box.size.y * 0.27
				_place(batches, anchors, "KeepButtresses", templates[tier],
					Transform3D(basis.scaled_local(Vector3(0.95, 1.5, 1)), at), pier)
	# Follow the existing bridge wall centreline, on the exterior of its finish.
	var keep := hub.get_node_or_null("building_castle_red2/building_castle_red") as MeshInstance3D
	if keep:
		# Audited large limestone faces of the original model, not its window
		# recesses or red roofs. Sample their real triangles so the planting
		# follows the imported tower's transform and stays attached to stone.
		var data := keep.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
		for face: int in [108, 114, 120, 126, 4812, 4818, 6186, 6192,
				7335, 7341, 8487, 8493, 14376, 14775, 15792, 16191]:
			if face + 2 >= indices.size():
				continue
			var a := vertices[indices[face]]
			var b := vertices[indices[face + 1]]
			var c := vertices[indices[face + 2]]
			var normal := (keep.global_basis * -(b-a).cross(c-a)).normalized()
			if absf(normal.y) > 0.05:
				continue
			var at := keep.to_global((a+b+c) / 3.0) + normal * 0.016
			var basis := Basis(Vector3(normal.z, 0, -normal.x), Vector3.UP, normal)
			_place(batches, anchors, "OriginalKeep", templates[face % 3],
				Transform3D(basis.scaled_local(Vector3(1.2, 1.2, 1)), at), keep)
			anchors.back()["audited_stone_triangle"] = face
	# Existing bridge safety walls also own the position of their living accents.
	var stair := hub.get_node_or_null("CastleStairs/CastleStair")
	if stair:
		for wall: MeshInstance3D in stair.find_children("CausewaySafetyWall_*", "MeshInstance3D", false, false):
			var normal := wall.global_basis.x.normalized()
			if normal.z * (wall.global_position.z - 27.41) < 0:
				normal = -normal
			var length := (wall.mesh as BoxMesh).size.z
			if length < 2.0:
				continue
			var at := wall.global_position + normal * 0.235 + Vector3.UP * 0.26
			var basis := Basis(Vector3(normal.z, 0, -normal.x), Vector3.UP, normal)
			_place(batches, anchors, "BridgeBorders", templates[1],
				Transform3D(basis.scaled_local(Vector3(1.15, 0.9, 1)), at), wall)
	var total_triangles := 0
	for zone: String in batches:
		var surface: SurfaceTool = batches[zone]
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.name = zone
		mesh.mesh = surface.commit()
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.set_meta("visual_only", true)
		garden.add_child(mesh)
		total_triangles += (mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	garden.set_meta("placement_anchors", anchors)
	garden.set_meta("triangle_count", total_triangles)
	garden.set_meta("draw_surfaces", batches.size())
	garden.set_meta("cluster_count", anchors.size())


static func _place(batches: Dictionary, anchors: Array[Dictionary], zone: String,
		mesh: ArrayMesh, at: Transform3D, source: Node3D) -> void:
	if not batches.has(zone):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[zone] = surface
	(batches[zone] as SurfaceTool).append_from(mesh, 0, at)
	anchors.append({"zone": zone, "source": source.get_path(), "transform": at,
		"local_bounds": mesh.get_aabb()})


static func _sprig(variant: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Continuous irregular moss mats, with broken edges and exposed stone gaps.
	# Small connected triangles read as velvety growth, not rows of green pebbles.
	for row in 14:
		for column in 25:
			var p := Vector2(-0.50+column*0.04, -0.64+row*0.04)
			var centre := p+Vector2.ONE*0.02
			var first := Vector2((centre.x+0.22)/0.28,(centre.y+0.27)/0.16).length()
			var second := Vector2((centre.x-0.23)/0.26,(centre.y+0.42)/0.19).length()
			var third := Vector2((centre.x+0.06)/0.20,(centre.y+0.52)/0.10).length()
			var edge := 0.93 + 0.16*sin(column*2.11+row*1.73+variant)
			if minf(first,minf(second,third)) > edge:
				continue
			var colour := MOSS.lerp(MOSS_LIGHT,0.15+0.35*(0.5+0.5*sin(column*1.31+row*2.03+variant)))
			var corners: Array[Vector3] = []
			for q: Vector2 in [p,p+Vector2(0.04,0),p+Vector2(0.04,0.04),p+Vector2(0,0.04)]:
				var jitter := Vector2(sin(q.x*173+q.y*93),cos(q.x*121-q.y*87))*0.008
				corners.append(Vector3(q.x+jitter.x,q.y+jitter.y,0.023+0.003*sin(q.x*157+q.y*97)))
			_tri(surface,corners[0],corners[1],corners[2],colour)
			_tri(surface,corners[0],corners[2],corners[3],colour)
			if (column+row)%3 == 0:
				var foot := Vector3(centre.x,centre.y,0.029)
				_ribbon(surface,foot,foot+Vector3(0.005,0.016,0.010),0.0014,FIBRE)
	# A single uneven climbing stem, with sparse small lobed ivy leaves.
	var last := Vector3(-0.30 + variant*0.09, -0.60, 0.045)
	for index in 10:
		var t := float(index+1)/10.0
		var p := Vector3(-0.30+variant*0.09+sin(t*4.0+variant)*0.13, -0.60+t*0.44, 0.045)
		_ribbon(surface,last,p,0.0035,STEM)
		if index % 2 == 0:
			var side := -1.0 if index % 4 else 1.0
			_ivy_leaf(surface,p,Vector2(side*0.065,0.044),LEAF if index % 4 else LEAF_LIGHT)
		last = p
	surface.generate_normals()
	return surface.commit()


static func _ivy_leaf(surface: SurfaceTool, p: Vector3, direction: Vector2, colour: Color) -> void:
	var up := direction.normalized()
	var across := Vector2(-up.y,up.x)
	var outline := [Vector2(0,0),Vector2(-0.32,0.20),Vector2(-0.57,0.57),
		Vector2(-0.20,0.54),Vector2(0,1),Vector2(0.20,0.54),Vector2(0.57,0.57),Vector2(0.32,0.20)]
	var centre := p + Vector3(direction.x*0.43,direction.y*0.43,0.008)
	for index in outline.size():
		var a: Vector2 = (across*outline[index].x+up*outline[index].y)*direction.length()
		var q: Vector2 = outline[(index+1)%outline.size()]
		var b: Vector2 = (across*q.x+up*q.y)*direction.length()
		_tri(surface,p+Vector3(a.x,a.y,0),p+Vector3(b.x,b.y,0),centre,colour)
	_ribbon(surface,p+Vector3(0,0,0.01),p+Vector3(direction.x,direction.y,0.01),0.0012,FIBRE)


static func _blade(surface: SurfaceTool, start: Vector3, direction: Vector3,
		width: float, colour: Color) -> void:
	var across := Vector3(-direction.y, direction.x, 0).normalized()
	for row in 6:
		var ta := float(row) / 6
		var tb := float(row + 1) / 6
		var a := start + direction * ta
		var b := start + direction * tb
		a.z += sin(ta * PI) * 0.012
		b.z += sin(tb * PI) * 0.012
		var wa := width * sin(ta * PI)
		var wb := width * sin(tb * PI)
		_tri(surface, a - across * wa, b - across * wb, b, colour)
		_tri(surface, a - across * wa, b, a, colour)
		_tri(surface, a, b, b + across * wb, colour.lightened(0.07))
		_tri(surface, a, b + across * wb, a + across * wa, colour.lightened(0.07))


static func _bloom(surface: SurfaceTool, p: Vector3, colour: Color) -> void:
	for petal in 5:
		var angle := TAU * petal / 5.0
		_blade(surface, p, Vector3(cos(angle), sin(angle), 0.14) * 0.085, 0.030, colour)
	_cushion(surface, p + Vector3(0, 0, 0.012), Vector3(0.024, 0.024, 0.016), GOLD)


static func _cushion(surface: SurfaceTool, p: Vector3, size: Vector3, colour: Color) -> void:
	for index in 10:
		var a := TAU * float(index) / 10
		var b := TAU * float(index + 1) / 10
		_tri(surface, p + Vector3(cos(a) * size.x, sin(a) * size.y, 0),
			p + Vector3(cos(b) * size.x, sin(b) * size.y, 0), p + Vector3(0, 0, size.z), colour)


static func _ribbon(surface: SurfaceTool, a: Vector3, b: Vector3, width: float, colour: Color) -> void:
	var cross := Vector3(-(b-a).y, (b-a).x, 0).normalized() * width
	_tri(surface, a-cross, b-cross, b+cross, colour)
	_tri(surface, a-cross, b+cross, a+cross, colour)


static func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	if (b-a).cross(c-a).length_squared() < 0.00000000001:
		return
	surface.set_color(colour)
	for p: Vector3 in [a, c, b]:
		surface.add_vertex(p)
