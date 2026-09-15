class_name HeartNatureKit
extends RefCounted

## Small flat-shaded mesh vocabulary shared by the garden and its creatures.
const COLORS := {"grass": "91ba59", "leaf": "548b49", "leaf_light": "b4cd70",
	"stone": "a1947f", "rock": "c6beab", "wood": "866141", "path": "e2cba0",
	"pink": "eaa0b6", "blue": "82c8d5", "gold": "eac66e", "soil": "655039",
	"blight": "61566b", "ivory": "f2e7c9"}

static func material(key: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(str(COLORS.get(key, key)))
	m.roughness = 1.0
	return m

static func mesh(parent: Node3D, label: String, shape: Mesh, at: Vector3,
		color: String, solid := false) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	item.mesh = shape
	item.material_override = material(color)
	item.position = at
	parent.add_child(item)
	if solid: item.create_trimesh_collision()
	return item

static func box(parent: Node3D, label: String, at: Vector3, size: Vector3,
		color: String, solid := false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, label, shape, at, color, solid)

static func cylinder(parent: Node3D, label: String, at: Vector3, radius: float,
		height: float, color: String, solid := false, sides := 8, bottom := -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius if bottom < 0.0 else bottom
	shape.height = height
	shape.radial_segments = sides
	shape.rings = 1
	return mesh(parent, label, shape, at, color, solid)

static func facet_mesh(size: Vector3) -> ArrayMesh:
	var points := [Vector3(0,1,0), Vector3(-1,0,0), Vector3(0,0,-1),
		Vector3(1,0,0), Vector3(0,0,1), Vector3(0,-1,0)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for indices in [[0,2,1], [0,3,2], [0,4,3], [0,1,4],
		[5,1,2], [5,2,3], [5,3,4], [5,4,1]]:
		var a: Vector3 = points[indices[0]] * size
		var b: Vector3 = points[indices[1]] * size
		var c: Vector3 = points[indices[2]] * size
		var n := (b-a).cross(c-a).normalized()
		for v in [a,c,b]:
			surface.set_normal(n)
			surface.add_vertex(v)
	return surface.commit()

static func facet(parent: Node3D, label: String, at: Vector3, size: Vector3,
		color: String, solid := false) -> MeshInstance3D:
	return mesh(parent, label, facet_mesh(size), at, color, solid)

static func branch(parent: Node3D, label: String, a: Vector3, b: Vector3,
		radius: float, color := "wood", solid := false) -> MeshInstance3D:
	var result := cylinder(parent, label, (a+b)*0.5, radius, a.distance_to(b), color, solid, 5)
	var direction := (b-a).normalized()
	result.quaternion = Quaternion(Vector3.UP, direction)
	return result

static func tree(parent: Node3D, at: Vector3, scale_value := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "FacetedTree"
	parent.add_child(root)
	root.position = at
	branch(root, "Trunk", Vector3.ZERO, Vector3(0,7,0)*scale_value, 0.7*scale_value, "wood", true)
	branch(root, "Bough", Vector3(0,4,0)*scale_value, Vector3(3,8,0)*scale_value, 0.4*scale_value)
	facet(root,"Crown",Vector3(0,9,0)*scale_value,Vector3(5,4.5,4.5)*scale_value,"leaf")
	facet(root,"CrownLight",Vector3(3,8,0)*scale_value,Vector3(3.8,3.5,3.7)*scale_value,"leaf_light")
	return root

static func flower(parent: Node3D, at: Vector3, size := 1.0, color := "pink") -> Node3D:
	var root := Node3D.new()
	root.name = "Flower"
	parent.add_child(root)
	root.position = at
	for i in 5:
		var angle := TAU * float(i)/5.0
		var petal := facet(root,"Petal%d"%i,Vector3(cos(angle),0,sin(angle))*size,
			Vector3(1,0.35,0.6)*size,color)
		petal.rotation.y = -angle
	cylinder(root,"Centre",Vector3(0,0.18,0)*size,0.6*size,0.3*size,"gold",false,6)
	return root

static func sign_text(parent: Node3D, text: String, at: Vector3, font_size := 32) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = font_size
	label.pixel_size = 0.018
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label
