# An enclosed medieval-inspired herb garden. All placement is local to the roof datum;
# only the low stone beds collide, never individual stems or leaves.
extends RefCounted

const Herbs := preload("res://scripts/castle_medieval_planting.gd")
const BED_SIDES := [0, 5, 6, 7]
# Shallow beds plus the raised parapet leave margin for both the player's
# 0.65 m step probe and the rounded feet of the collision capsule.
const BED_SIZE := Vector3(2.65, 0.32, 1.42)
const BED_RADIUS := 7.02


static func build(parent: Node3D, roof_origin: Vector3) -> void:
	var garden := Node3D.new()
	garden.name = "CrownRoofGarden"
	parent.add_child(garden)
	garden.global_position = roof_origin
	garden.set_meta("keeps_stair_and_bridge_clear", true)
	garden.set_meta("plant_collision", false)
	garden.set_meta("garden_style", "medieval_enclosed_herb_garden")
	var stone := _material(Color("8399a6"))
	var coping := _material(Color("c7d2d2"))
	var soil := _material(Color("514331"))
	for index in BED_SIDES.size():
		var angle := TAU * float(BED_SIDES[index]) / 8.0
		var bed := Node3D.new()
		bed.name = "RooftopFlowerBed_%d" % index
		garden.add_child(bed)
		bed.position = Vector3(cos(angle) * BED_RADIUS, 0.0,
			sin(angle) * BED_RADIUS)
		bed.rotation.y = -angle + PI * 0.5
		bed.set_meta("wall_side", BED_SIDES[index])
		bed.set_meta("walkable_top_y", BED_SIZE.y)
		var plinth := MeshInstance3D.new()
		plinth.name = "ChamferedStonePlanter"
		plinth.mesh = _chamfered_bed_mesh(BED_SIZE, 0.12)
		plinth.material_override = stone
		bed.add_child(plinth)
		var body := StaticBody3D.new()
		body.name = "PlanterSolidBody"
		bed.add_child(body)
		var collision := CollisionShape3D.new()
		collision.shape = plinth.mesh.create_convex_shape()
		body.add_child(collision)
		# The soil and rim share a single walkable height, so a jumping player's
		# feet never sink into the bed or float above an uncollidable inset.
		# Four millimetres of visual bias prevents the soil's top face fighting
		# the solid bed cap; this is not another raised walking layer.
		_box(bed, "Soil", Vector3(2.35, 0.02, 1.12),
			Vector3(0.0, BED_SIZE.y - 0.006, 0.0), soil)
		for side: float in [-1.0, 1.0]:
			_box(bed, "StoneRimLong", Vector3(2.39, 0.09, 0.14),
				Vector3(0.0, BED_SIZE.y - 0.045, side * 0.63), coping)
			_box(bed, "StoneRimEnd", Vector3(0.14, 0.09, 1.18),
				Vector3(side * 1.24, BED_SIZE.y - 0.045, 0.0), coping)
		# Small, low-contrast blocks echo the surrounding ashlar, without grooves
		# through the floor or extra collision edges.
		for column in 5:
			_box(bed, "PlanterAshlar_%d" % column, Vector3(0.43, 0.15, 0.025),
				Vector3(-1.0 + float(column) * 0.5, 0.14, -0.717), coping)
		Herbs.build(bed, BED_SIZE.y)


static func _leaf(parent: Node3D, label: String, position: Vector3,
		size: Vector3, rotation: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = "%s_%d" % [label, parent.get_child_count()]
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.position = position
	node.scale = size
	node.rotation = rotation


static func _box(parent: Node3D, label: String, size: Vector3,
		position: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	node.position = position


static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.94
	return material


static func _chamfered_bed_mesh(size: Vector3, bevel: float) -> ArrayMesh:
	var x := size.x * 0.5
	var z := size.z * 0.5
	var outline := PackedVector2Array([
		Vector2(-x + bevel, -z), Vector2(x - bevel, -z),
		Vector2(x, -z + bevel), Vector2(x, z - bevel),
		Vector2(x - bevel, z), Vector2(-x + bevel, z),
		Vector2(-x, z - bevel), Vector2(-x, -z + bevel),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for index in outline.size():
		var a := Vector3(outline[index].x, 0.0, outline[index].y)
		var b := Vector3(outline[(index + 1) % outline.size()].x, 0.0,
			outline[(index + 1) % outline.size()].y)
		var at := a + Vector3.UP * size.y
		var bt := b + Vector3.UP * size.y
		for vertex: Vector3 in [a, b, bt, a, bt, at,
				Vector3.UP * size.y, at, bt, Vector3.ZERO, b, a]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()
