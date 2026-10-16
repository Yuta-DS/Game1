extends RefCounted
# Editable procedural low-poly source. Flat normals, shared palette, simple colliders.
static var palette: Dictionary = {}

static func material(colour: Color) -> StandardMaterial3D:
	var key := colour.to_html()
	if not palette.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = 0.92
		palette[key] = m
	return palette[key]

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, colour: Color, solid := false) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = shape
	item.position = pos
	item.material_override = material(colour)
	parent.add_child(item)
	if solid:
		if shape is BoxMesh:
			var body := StaticBody3D.new()
			var collider := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = shape.size
			collider.shape = box_shape
			body.add_child(collider)
			item.add_child(body)
		else: item.create_trimesh_collision()
	return item

static func box(parent: Node3D, pos: Vector3, size: Vector3, colour: Color, solid := false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, colour, solid)

static func cone(parent: Node3D, pos: Vector3, bottom: float, top: float, height: float, colour: Color, solid := false, sides := 7) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = sides
	shape.rings = 1
	# Deindex with face normals so every polygon reads as a separate plane.
	var arrays := shape.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i + 1]]
		var c := vertices[indices[i + 2]]
		var normal := (c - a).cross(b - a).normalized()
		for vertex in [a, b, c]:
			surface.set_normal(normal)
			surface.add_vertex(vertex)
	return mesh(parent, surface.commit(), pos, colour, solid)

static func label(parent: Node3D, words: String, pos: Vector3, size := 40) -> Label3D:
	var text := Label3D.new()
	text.text = words
	text.position = pos
	text.font_size = size
	text.pixel_size = 0.023
	text.modulate = Color("fff3d7")
	text.outline_modulate = Color("263f3d")
	text.outline_size = 9
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(text)
	return text

static func banner(parent: Node3D, words: String, pos: Vector3, size := 30) -> Label3D:
	# A single cloth sign with a quiet ivory border. All surfaces face together;
	# it has no physics and fades before distant signs stack over the landscape.
	var sign := Node3D.new()
	sign.set_script(preload("res://scripts/heart_melody/landmark_banner.gd"))
	sign.name = "LandmarkBanner"
	sign.position = pos
	sign.set_meta("anchor_position", pos)
	parent.add_child(sign)
	for layer in 1:
		var shape := QuadMesh.new()
		shape.size = Vector2(10.2, 2.8)
		var surface := MeshInstance3D.new()
		surface.mesh = shape
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Keep nearby landmark signs readable through crossing foliage.
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		var cloth := Image.create(256, 80, false, Image.FORMAT_RGBA8)
		cloth.fill(Color("cfbf8d"))
		cloth.fill_rect(Rect2i(3, 3, 250, 74), Color("29463e"))
		mat.albedo_texture = ImageTexture.create_from_image(cloth)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.render_priority = layer
		surface.material_override = mat
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		surface.visibility_range_end = 55
		surface.visibility_range_end_margin = 10
		sign.add_child(surface)
	var text := label(sign, words, Vector3(0, 0, 0.04), 44 if size >= 30 else 40)
	text.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	text.no_depth_test = true
	text.name = "BannerText"
	text.pixel_size = 0.018
	text.width = 540
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.outline_size = 2
	text.render_priority = 3
	text.visibility_range_end = 55
	text.visibility_range_end_margin = 10
	return text

static func flower(parent: Node3D, pos: Vector3, colour: Color, radius := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	cone(root, Vector3(0, 0.6, 0), 0.16, 0.12, 1.2, Color("53876a"))
	for i in 5:
		var angle := TAU * i / 5.0
		var petal := cone(root, Vector3(sin(angle) * radius * 0.7, 1.2, cos(angle) * radius * 0.7), radius * 0.6, radius * 0.4, 0.28, colour, false, 5)
		petal.rotation_degrees.z = sin(angle) * 16
		petal.rotation_degrees.x = cos(angle) * 16
	cone(root, Vector3(0, 1.38, 0), radius * 0.42, radius * 0.35, 0.25, Color("f6d58a"))
	return root

static func symbol(parent: Node3D, pos: Vector3, identity: int) -> void:
	# Mounted silhouettes accompany the words; they remain distinct in grayscale.
	var plaque := Node3D.new()
	plaque.position = pos
	parent.add_child(plaque)
	box(plaque, Vector3.ZERO, Vector3(1.6, 0.18, 1.6), Color("e2d8bb"))
	if identity == 0:
		var leaf := cone(plaque, Vector3(0, 0.25, 0), 0.65, 0.1, 0.2, Color("426754"), false, 4)
		leaf.scale.z = 0.65
		box(plaque, Vector3(0, 0.38, 0), Vector3(0.8, 0.05, 0.06), Color("e2d8bb"))
	elif identity == 1:
		cone(plaque, Vector3(0, 0.3, 0), 0.5, 0, 0.65, Color("426777"), false, 7)
	else:
		cone(plaque, Vector3(0, 0.25, 0), 0.35, 0.35, 0.15, Color("9b703a"), false, 8)
		for i in 8:
			var angle := i * TAU / 8
			var ray := box(plaque, Vector3(cos(angle) * 0.57, 0.25, sin(angle) * 0.57), Vector3(0.3, 0.12, 0.09), Color("9b703a"))
			ray.rotation.y = -angle

static func planter(parent: Node3D, pos: Vector3, identity: int) -> Node3D:
	var family := Node3D.new()
	family.name = "FeelingPlanter%d" % identity
	family.set_meta("art_family", "planter")
	family.position = pos
	parent.add_child(family)
	cone(family, Vector3(0, 0.25, 0), 2, 2.1, 0.5, Color("839681"), true)
	cone(family, Vector3(0, 0.51, 0), 1.85, 1.85, 0.06, Color("786655"))
	for i in 8:
		var angle := i * TAU / 8
		var stone := box(family, Vector3(cos(angle) * 1.85, 0.65, sin(angle) * 1.85), Vector3(1.5, 0.6, 0.5), Color("839681"), true)
		stone.rotation.y = -angle + PI / 2
	symbol(family, Vector3(0, 0.8, 2), identity)
	return flower(family, Vector3(0, 0.55, 0), Color("e4dbc5"), 1.3)

static func tree(parent: Node3D, pos: Vector3, variant: int) -> void:
	var family := Node3D.new()
	family.set_meta("art_family", "tree")
	parent.add_child(family)
	parent = family
	var bark := Color("826b5c")
	cone(parent, pos + Vector3(0, 3.5, 0), 0.9, 0.5, 7, bark, true)
	for i in 3:
		var offset := Vector3(cos(i * 2.1) * 2.2, 7.5 + i, sin(i * 2.1) * 2.2)
		cone(parent, pos + offset, 4.5 - i * 0.4, 1.1, 4.5, Color("94b696") if variant == 0 else Color("d4a9bd"), false, 6)
		camera_obstacle(parent.get_child(parent.get_child_count() - 1))

static func island(parent: Node3D, pos: Vector3, radius: float, depth: float, grass: Color) -> void:
	var top := cone(parent, pos + Vector3(0, -1, 0), radius * 0.98, radius, 2, grass, true, 16)
	top.name = "ContinuousGround"
	cone(parent, pos + Vector3(0, -depth / 2 - 2, 0), radius * 0.32, radius * 0.98, depth, Color("b0a396"), false, 16)
	for i in 9:
		var angle := i * TAU / 9
		cone(parent, pos + Vector3(sin(angle) * radius * 0.78, -depth * 0.7, cos(angle) * radius * 0.78), 0.2, 1.3, depth, Color("7e7461"), false, 5)

static func paired_island(parent: Node3D, open_station_entrance := false) -> void:
	var outline := PackedVector2Array()
	var join := acos(35.0 / 57.0)
	for i in 19:
		var a := lerpf(join, TAU - join, i / 18.0)
		outline.append(Vector2(-35 + cos(a) * 57, sin(a) * 57))
	for i in range(1, 18):
		var a := lerpf(PI + join, 3 * PI - join, i / 18.0)
		outline.append(Vector2(35 + cos(a) * 57, sin(a) * 57))
	var clipped := PackedVector2Array()
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		if a.x <= 66: clipped.append(a)
		if (a.x <= 66) != (b.x <= 66): clipped.append(a.lerp(b, (66 - a.x) / (b.x - a.x)))
	outline = clipped
	var indices := Geometry2D.triangulate_polygon(outline)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		for j in [0, 1, 2]:
			var point := outline[indices[i + j]]
			surface.set_normal(Vector3.UP)
			surface.add_vertex(Vector3(point.x, 0, point.y))
	var ground := mesh(parent, surface.commit(), Vector3.ZERO, Color("8fab88"), true)
	ground.name = "ContinuousPairedLobeGround"
	for i in outline.size():
		var a := Vector3(outline[i].x, -0.05, outline[i].y)
		var b := Vector3(outline[(i + 1) % outline.size()].x, -0.05, outline[(i + 1) % outline.size()].y)
		var station_opening := open_station_entrance and minf(a.x, b.x) < -78 and minf(a.z, b.z) < 19 and maxf(a.z, b.z) > 5
		if not station_opening and not (is_equal_approx(a.x, 66) and is_equal_approx(b.x, 66)):
			var railing := box(parent, (a + b) / 2 + Vector3(0, 0.85, 0), Vector3(0.8, 1.7, a.distance_to(b) + 0.4), Color("796e56"), true)
			railing.look_at(parent.to_global(b + Vector3(0, 0.85, 0)))
		var c := Vector3(a.x * 0.65, -25 - (i % 3) * 3, a.z * 0.55)
		var d := Vector3(b.x * 0.65, -25 - ((i + 1) % 3) * 3, b.z * 0.55)
		var side := SurfaceTool.new()
		side.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex in [a, c, b, b, c, d]: side.add_vertex(vertex)
		side.generate_normals()
		mesh(parent, side.commit(), Vector3.ZERO, Color("ac9e8e").darkened((i % 3) * 0.06))
		var underside := SurfaceTool.new()
		underside.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex in [c, d, Vector3(0, -30, 0)]: underside.add_vertex(vertex)
		underside.generate_normals()
		mesh(parent, underside.commit(), Vector3.ZERO, Color("887d70"))
		if i % 3 == 0: cone(parent, c + Vector3(0, -5, 0), 0.1, 1.2, 13, Color("7e7461"), false, 5)

# Camera-only convex hulls keep high foliage out of the view without blocking
# walking below it. The shared player only collides with world layer 1.
static func camera_obstacle(item: MeshInstance3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1 << 19
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = item.mesh.create_convex_shape()
	body.add_child(collider)
	item.add_child(body)

# Closed radial profile, with clockwise outward faces and explicit pole caps.
# Profiles support sculpted silhouettes; melon stripes wrap around every side.
static func fruit_body(parent: Node3D, pos: Vector3, profile: Array, colour: Color, striped := false) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 12
	for ring in range(profile.size() - 1):
		for sector in sides:
			var a := sector * TAU / sides
			var b := (sector + 1) * TAU / sides
			var low: Vector2 = profile[ring]
			var high: Vector2 = profile[ring + 1]
			var v0 := Vector3(cos(a) * low.x, low.y, sin(a) * low.x)
			var v1 := Vector3(cos(b) * low.x, low.y, sin(b) * low.x)
			var v2 := Vector3(cos(a) * high.x, high.y, sin(a) * high.x)
			var v3 := Vector3(cos(b) * high.x, high.y, sin(b) * high.x)
			for triangle in [[v0, v1, v2], [v1, v3, v2]]:
				var normal: Vector3 = (triangle[2] - triangle[0]).cross(triangle[1] - triangle[0]).normalized()
				if normal.is_zero_approx(): continue
				for vertex in triangle:
					surface.set_normal(normal)
					surface.set_color(colour.darkened(0.32) if striped and sector % 3 == 0 else colour)
					surface.add_vertex(vertex)
	var item := mesh(parent, surface.commit(), pos, Color.WHITE)
	var mat := material(Color.WHITE).duplicate() as StandardMaterial3D
	mat.vertex_color_use_as_albedo = true
	item.material_override = mat
	return item

static func garden_flower(parent: Node3D, pos: Vector3, variety: int, colour: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "GardenBloom"
	root.position = pos
	root.set_meta("flower_variety", variety)
	parent.add_child(root)
	var height := 0.65 + variety * 0.28
	cone(root, Vector3(0, height / 2, 0), 0.055, 0.035, height, Color("48745a"), false, 5)
	var petals: int = [6, 8, 4][variety]
	for i in petals:
		var angle := TAU * i / petals
		var petal := cone(root, Vector3(cos(angle) * 0.38, height, sin(angle) * 0.38), 0.34, 0.22, 0.16 if variety != 2 else 0.45, colour, false, 5)
		petal.scale.z = 0.65 if variety == 1 else 1.0
		petal.rotation = Vector3(sin(angle) * 0.28, -angle, cos(angle) * 0.28)
	cone(root, Vector3(0, height + 0.09, 0), 0.21, 0.15, 0.18, Color("eacb79"), false, 8)
	for side in [-1, 1]:
		var leaf := cone(root, Vector3(side * 0.19, height * 0.45, 0), 0.32, 0.04, 0.1, Color("588666"), false, 4)
		leaf.scale.z = 0.45
	merge_coloured(root)
	return root

# A flower/fruit animates as one object. Bake its opaque coloured pieces into
# one surface to avoid one Web draw call per petal, stem, leaf or berry.
static func merge_coloured(root: Node3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for child in root.get_children():
		if not child is MeshInstance3D: continue
		var mat := child.material_override as StandardMaterial3D
		for index in child.mesh.get_surface_count():
			var arrays: Array = child.mesh.surface_get_arrays(index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var colours = arrays[Mesh.ARRAY_COLOR]
			if indices.is_empty():
				for j in vertices.size(): indices.append(j)
			for j in indices:
				surface.set_normal((child.transform.basis.inverse().transposed() * normals[j]).normalized())
				surface.set_color(colours[j] if mat.vertex_color_use_as_albedo and colours != null and colours.size() > j else mat.albedo_color)
				surface.add_vertex(child.transform * vertices[j])
		child.free()
	var merged := mesh(root, surface.commit(), Vector3.ZERO, Color.WHITE)
	var mat := material(Color.WHITE).duplicate() as StandardMaterial3D
	mat.vertex_color_use_as_albedo = true
	merged.material_override = mat
