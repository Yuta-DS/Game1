extends Node3D

const Garden := preload("res://scripts/castle_rooftop_garden.gd")
const CastleStyle := preload("res://scripts/castle_reference_style.gd")
const WaterShader := preload("res://shaders/castle_fountain_water.gdshader")
const StoneScene := preload("res://assets3D/royal_garden/glb/FountainStone.glb")
const WaterScene := preload("res://assets3D/royal_garden/glb/WaterMotion.glb")
const BASIN_FLOOR_Y := 0.75
const BASIN_RIM_Y := 0.95
const UPPER_FLOOR_Y := 1.8625
const UPPER_RIM_Y := 1.9875
const OUTER_RADIUS := 1.652
const LOWER_WATER_RADIUS := 1.365
const LOWER_IMPACT_RADIUS := 1.22
const UPPER_WATER_RADIUS := 0.637
const UPPER_IMPACT_RADIUS := 0.52
const ROOF_OFFSET := 0.0
const AISLE_CENTRE_RADIUS := 2.50

var _water_materials: Array[ShaderMaterial] = []
var _flow_time := 0.0
var _spray_emitters: Array[Dictionary] = []


static func build(parent: Node3D, roof_origin: Vector3, outward: Vector3) -> void:
	var fountain := new()
	fountain.name = "CastleRoyalFountain"
	parent.add_child(fountain)
	# The fountain is the court's centrepiece; the annular aisle stays open.
	fountain.global_position = roof_origin - outward * ROOF_OFFSET
	fountain.set_meta("centred_on_rooftop", true)
	fountain.set_meta("preserve_castle_finish", true)
	fountain.set_meta("replaces_rooftop_ballista", true)
	fountain.set_meta("solid_stone_animated_water", true)
	fountain.set_meta("basin_diameter", OUTER_RADIUS * 2.0)
	fountain.set_meta("size_increase", Vector2(1.4, 1.25))
	fountain._build()


func _build() -> void:
	var stone := CastleStyle.material("wall")
	var cream := CastleStyle.material("trim")
	var gold := Garden._material(Color("bda365"))
	var body := StaticBody3D.new()
	body.name = "SolidFountainStone"
	add_child(body)
	# Each stone floor is solid at the visible height. Water is only 20 mm deep,
	# so landing in a basin cannot conceal the player's lower body in a fake floor.
	_solid_cone("LowerBasinStone", 1.624, 1.372, BASIN_FLOOR_Y, BASIN_FLOOR_Y * 0.5, stone, body)
	_rim("LowerBasinRim", 1.372, OUTER_RADIUS, 0.725, BASIN_RIM_Y, cream, body)
	_solid_cone("CarvedPedestal", 0.252, 0.42, 0.90, 1.20, cream, body)
	_solid_cone("UpperBasinStone", 0.784, 0.28, 0.35, 1.6875, stone, body)
	_rim("UpperBasinRim", 0.644, 0.812, 1.825, UPPER_RIM_Y, cream, body)
	_solid_cone("CrownSpout", 0.098, 0.168, 0.45, 2.0875, gold, body)
	# These simple hulls remain the authoritative support surfaces. The Blender
	# carving is a finish on the same dimensions, not another raised fake floor.
	for child in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).hide()
	var carved_stone := StoneScene.instantiate() as Node3D
	carved_stone.name = "BlenderCarvedFountain"
	add_child(carved_stone)
	for part: MeshInstance3D in carved_stone.find_children("*", "MeshInstance3D", true, false):
		for index in part.mesh.get_surface_count():
			var label := part.get_active_material(index).resource_name
			if label == "Reference castle limestone":
				part.set_surface_override_material(index, stone)
			elif label == "Reference castle dressed trim" or label == "Pale carved limestone":
				part.set_surface_override_material(index, cream)
			elif label == "Recessed stone joints":
				part.set_surface_override_material(index, CastleStyle.material("recess"))
	var water := WaterScene.instantiate() as Node3D
	water.name = "BlenderLivingWater"
	add_child(water)
	var lower_pool := _pool_material(LOWER_WATER_RADIUS, LOWER_IMPACT_RADIUS)
	var upper_pool := _pool_material(UPPER_WATER_RADIUS, UPPER_IMPACT_RADIUS)
	var streams := ShaderMaterial.new()
	streams.shader = WaterShader
	streams.set_shader_parameter("flowing_stream", true)
	var spray := streams.duplicate() as ShaderMaterial
	spray.set_shader_parameter("spray", true)
	_water_materials.assign([lower_pool, upper_pool, streams, spray])
	for candidate in water.find_children("*", "MeshInstance3D", true, false):
		var water_mesh := candidate as MeshInstance3D
		if "LowerBasinWater" in String(water_mesh.name):
			water_mesh.material_override = lower_pool
		elif "UpperBasinWater" in String(water_mesh.name):
			water_mesh.material_override = upper_pool
		else:
			water_mesh.material_override = streams
		water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for candidate in water.find_children("*", "AnimationPlayer", true, false):
		var animator := candidate as AnimationPlayer
		for animation_name in animator.get_animation_list():
			if animation_name == "RESET":
				continue
			animator.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
			animator.play(animation_name)
			break
	set_meta("water_stream_count", 8)
	_build_spray("LowerImpactSpray", LOWER_IMPACT_RADIUS, BASIN_FLOOR_Y + 0.02, 48, 0.46, spray)
	_build_spray("UpperImpactSpray", UPPER_IMPACT_RADIUS, UPPER_FLOOR_Y + 0.02, 32, 0.34, spray)
	set_meta("water_animation", "ballistic_streams_morphs_gravity_splashes_and_impact_ripples")
	set_meta("fine_triangulated_stone", true)


func _process(delta: float) -> void:
	_flow_time = fmod(_flow_time + delta, 3600.0)
	for material in _water_materials:
		material.set_shader_parameter("flow_time", _flow_time)
	_update_spray()


func _pool_material(radius: float, impact_radius: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WaterShader
	material.set_shader_parameter("basin_radius", radius)
	material.set_shader_parameter("impact_radius", impact_radius)
	return material


# Eighty small 3D splash droplets use two draw calls on Web. Gravity returns
# them to the basin; no frozen spheres, glow sprites or particle colliders.
func _build_spray(label: String, radius: float, height: float, count: int,
		lifetime: float, material: Material) -> void:
	var drops := MultiMeshInstance3D.new()
	drops.name = label
	drops.multimesh = MultiMesh.new()
	drops.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var bead := SphereMesh.new()
	bead.radius = 1.0
	bead.height = 2.0
	bead.radial_segments = 8
	bead.rings = 4
	drops.multimesh.mesh = bead
	drops.multimesh.instance_count = count
	drops.material_override = material
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drops.custom_aabb = AABB(Vector3(-radius - 0.25, height - 0.05, -radius - 0.25),
		Vector3((radius + 0.25) * 2, 0.55, (radius + 0.25) * 2))
	add_child(drops)
	_spray_emitters.append({"mesh": drops.multimesh, "count": count,
		"radius": radius, "height": height, "lifetime": lifetime})
	_update_spray()


func _update_spray() -> void:
	for emitter: Dictionary in _spray_emitters:
		var mesh: MultiMesh = emitter.mesh
		for index in int(emitter.count):
			var age := fposmod(_flow_time / float(emitter.lifetime) + float(index) * 0.618034, 1.0)
			var seconds := age * float(emitter.lifetime)
			var angle := TAU * float(index % 4) / 4.0 + PI / 4.0
			var radial := Vector3(cos(angle), 0, sin(angle))
			var tangent := Vector3(-radial.z, 0, radial.x)
			var velocity := -radial * (0.08 + float(index % 3) * 0.04) \
				+ tangent * sin(float(index) * 2.399) * 0.35
			var position := radial * float(emitter.radius) + velocity * seconds
			position.y = float(emitter.height) + 4.905 * float(emitter.lifetime) * seconds - 4.905 * seconds * seconds
			var fade := maxf(0.001, sin(PI * age))
			var radius := (0.009 + float(index % 3) * 0.0035) * fade
			var basis := Basis.IDENTITY.scaled(Vector3(radius, radius * 1.3, radius))
			mesh.set_instance_transform(index, Transform3D(basis, position))


func _solid_cone(label: String, top: float, bottom: float, height: float,
		y: float, material: Material, body: StaticBody3D) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 32
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	node.position.y = y
	var collision := CollisionShape3D.new()
	collision.name = "%sCollision" % label
	collision.shape = mesh.create_convex_shape()
	body.add_child(collision)
	collision.position.y = y


func _rim(label: String, inner: float, outer: float, bottom: float, top: float,
		material: Material, body: StaticBody3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 48
	for index in SEGMENTS:
		var a := TAU * float(index) / float(SEGMENTS)
		var b := TAU * float(index + 1) / float(SEGMENTS)
		var points := PackedVector3Array()
		for angle: float in [a, b]:
			for radius: float in [inner, outer]:
				for y: float in [bottom, top]:
					points.append(Vector3(cos(angle) * radius, y, sin(angle) * radius))
		for face in [[0, 4, 5, 1], [2, 3, 7, 6], [1, 5, 7, 3], [0, 2, 6, 4]]:
			for vertex: int in [face[0], face[1], face[2], face[0], face[2], face[3]]:
				surface.add_vertex(points[vertex])
		# Closed overlapping convex cells stop a capsule catching at a segment
		# seam, while leaving the actual shallow basin interior accessible.
		var collision_points := PackedVector3Array()
		for angle: float in [a - 0.001, b + 0.001]:
			for radius: float in [inner, outer]:
				for y: float in [bottom, top]:
					collision_points.append(Vector3(cos(angle) * radius, y, sin(angle) * radius))
		var collision := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = collision_points
		collision.shape = shape
		body.add_child(collision)
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = surface.commit()
	node.material_override = material
	add_child(node)
