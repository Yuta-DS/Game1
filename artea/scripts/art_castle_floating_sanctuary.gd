extends Node3D

# A walkable foreground for the Art Castle's existing galaxy railway. The
# railway and three kingdom islands are generated separately; this sanctuary
# makes their shared station unmistakable from the gallery's player spawn.

const CENTER := Vector3(-11.0, 0.0, 27.3)
const BRIDGE_START := Vector3(0.0, 0.05, 14.0)
const BRIDGE_END := Vector3(-11.0, 0.05, 17.8)

var _animated_glows: Array[MeshInstance3D] = []


func _ready() -> void:
	_build_floating_foundation()
	_build_arrival_bridge()
	_build_picture_frame_gate()
	_build_lumen_tree()
	_build_route_beacons()
	_build_cloud_garden()


func _process(delta: float) -> void:
	for index in _animated_glows.size():
		var glow := _animated_glows[index]
		glow.rotation.y += delta * (0.18 + float(index % 3) * 0.05)


func _build_floating_foundation() -> void:
	var ivory := _material(Color("d9d5ef"), 0.78)
	var lavender := _glow_material(Color("9278df"), 0.35)

	# Wide enough to frame the existing Grand Station, while keeping its tracks
	# and shrines visible above this low architectural foundation.
	_add_cylinder("SanctuaryDeck", CENTER + Vector3(0.0, -0.38, 0.0), 10.6, 0.7, ivory, true)
	_add_cylinder("FloatingUnderside", CENTER + Vector3(0.0, -2.0, 0.0), 9.5, 3.0,
		_material(Color("d9d5ef").darkened(0.16), 0.86), false, 12)

	var crown_ring := MeshInstance3D.new()
	crown_ring.name = "CrownHalo"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 9.75
	ring_mesh.outer_radius = 10.05
	ring_mesh.rings = 48
	ring_mesh.ring_segments = 6
	crown_ring.mesh = ring_mesh
	crown_ring.position = CENTER + Vector3(0.0, 0.08, 0.0)
	crown_ring.material_override = lavender
	add_child(crown_ring)
	_animated_glows.append(crown_ring)

	# Crystal points below the platform sell the silhouette as a floating world.
	for index in 12:
		var angle := TAU * float(index) / 12.0
		var crystal := MeshInstance3D.new()
		crystal.name = "UndersideCrystal_%02d" % index
		var crystal_mesh := CylinderMesh.new()
		crystal_mesh.top_radius = 0.65
		crystal_mesh.bottom_radius = 0.08
		crystal_mesh.height = 3.4 + float(index % 3) * 0.55
		crystal_mesh.radial_segments = 5
		crystal.mesh = crystal_mesh
		crystal.position = CENTER + Vector3(cos(angle) * 7.4, -3.1, sin(angle) * 7.4)
		crystal.material_override = ivory
		add_child(crystal)


func _build_arrival_bridge() -> void:
	var bridge_color := _material(Color("e7e2f2"), 0.72)
	var gold := _glow_material(Color("f4c86b"), 0.42)
	_add_oriented_box("ArrivalBridge", BRIDGE_START, BRIDGE_END, 4.2, 0.42, bridge_color, true)

	var direction := BRIDGE_END - BRIDGE_START
	var length := direction.length()
	var midpoint := (BRIDGE_START + BRIDGE_END) * 0.5
	var yaw := atan2(direction.x, direction.z)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.name = "BridgeGlowRail"
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.16, 0.18, length)
		rail.mesh = rail_mesh
		rail.position = midpoint + Vector3(cos(yaw) * side * 1.88, 0.38, -sin(yaw) * side * 1.88)
		rail.rotation.y = yaw
		rail.material_override = gold
		add_child(rail)


func _build_picture_frame_gate() -> void:
	var direction := BRIDGE_END - BRIDGE_START
	var yaw := atan2(direction.x, direction.z)
	var gate := Node3D.new()
	gate.name = "WorldFrameGate"
	gate.position = BRIDGE_START + direction.normalized() * 1.2
	gate.rotation.y = yaw
	add_child(gate)

	var gold := _glow_material(Color("f0c96d"), 0.5)
	_add_box_to(gate, "FrameLeft", Vector3(-2.05, 2.15, 0.0), Vector3(0.28, 4.3, 0.35), gold, false)
	_add_box_to(gate, "FrameRight", Vector3(2.05, 2.15, 0.0), Vector3(0.28, 4.3, 0.35), gold, false)
	_add_box_to(gate, "FrameTop", Vector3(0.0, 4.2, 0.0), Vector3(4.38, 0.28, 0.35), gold, false)
	for side in [-1.0, 1.0]:
		var finial := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.28
		mesh.height = 0.56
		finial.mesh = mesh
		finial.position = Vector3(side * 2.05, 4.52, 0.0)
		finial.material_override = gold
		gate.add_child(finial)

	# The former large floating title sat directly in the player's view and read
	# like another banner. The physical frame remains as the visual threshold.


func _build_lumen_tree() -> void:
	var tree := Node3D.new()
	tree.name = "LumenTree"
	tree.position = CENTER + Vector3(-6.4, 0.15, 1.0)
	add_child(tree)
	var bark := _material(Color("5b496f"), 0.86)
	var blossom := _glow_material(Color("b89cff"), 0.62)
	_add_cylinder_to(tree, "Trunk", Vector3(0.0, 1.65, 0.0), 0.5, 3.3, bark, false, 7)

	for index in 17:
		var angle := float(index) * 2.39996
		var radius := 0.55 + sqrt(float(index)) * 0.55
		var bloom := MeshInstance3D.new()
		bloom.name = "StarBloom_%02d" % index
		var mesh := SphereMesh.new()
		mesh.radius = 0.72 + float(index % 3) * 0.12
		mesh.height = mesh.radius * 1.45
		mesh.radial_segments = 8
		mesh.rings = 4
		bloom.mesh = mesh
		bloom.position = Vector3(cos(angle) * radius, 3.4 + sin(float(index) * 1.7) * 0.7, sin(angle) * radius)
		bloom.material_override = blossom
		tree.add_child(bloom)
		_animated_glows.append(bloom)


func _build_route_beacons() -> void:
	var routes := [
		{"label": "MIND SPARK", "color": Color("70a4ff"), "position": CENTER + Vector3(2.0, 0.2, -7.4)},
		{"label": "HEART MELODY", "color": Color("ff936b"), "position": CENTER + Vector3(4.8, 0.2, 0.0)},
		{"label": "CREATOR'S LIGHT", "color": Color("ffd26b"), "position": CENTER + Vector3(2.0, 0.2, 7.4)},
	]
	for route in routes:
		var beacon := Node3D.new()
		beacon.name = "Route_%s" % String(route.label).replace("'", "").replace(" ", "")
		beacon.position = route.position
		add_child(beacon)
		var color: Color = route.color
		var glow := _glow_material(color, 0.58)
		_add_cylinder_to(beacon, "Beacon", Vector3(0.0, 1.0, 0.0), 0.22, 2.0, glow, false, 6)
		var halo := MeshInstance3D.new()
		var halo_mesh := TorusMesh.new()
		halo_mesh.inner_radius = 0.65
		halo_mesh.outer_radius = 0.78
		halo_mesh.rings = 16
		halo_mesh.ring_segments = 4
		halo.mesh = halo_mesh
		halo.position.y = 2.1
		halo.material_override = glow
		beacon.add_child(halo)
		_animated_glows.append(halo)
		var label := Label3D.new()
		label.text = route.label
		label.position = Vector3(0.0, 2.9, 0.0)
		label.font_size = 22
		label.outline_size = 7
		label.modulate = color.lightened(0.25)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		beacon.add_child(label)


func _build_cloud_garden() -> void:
	var cloud := _material(Color(0.86, 0.84, 0.96, 0.8), 1.0)
	for index in 22:
		var angle := TAU * float(index) / 22.0
		var radius := 12.5 + float(index % 4) * 1.2
		var puff := MeshInstance3D.new()
		puff.name = "CloudPuff_%02d" % index
		var mesh := SphereMesh.new()
		mesh.radius = 1.2 + float(index % 3) * 0.35
		mesh.height = 1.3
		mesh.radial_segments = 8
		mesh.rings = 4
		puff.mesh = mesh
		puff.scale = Vector3(1.7, 0.55, 1.0)
		puff.position = CENTER + Vector3(cos(angle) * radius, -1.0 + sin(float(index)) * 0.45, sin(angle) * radius)
		puff.material_override = cloud
		add_child(puff)


func _add_oriented_box(node_name: String, start: Vector3, end: Vector3,
		width: float, height: float, material: Material, collision_enabled: bool) -> void:
	var direction := end - start
	var length := direction.length()
	var box := MeshInstance3D.new()
	box.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, length)
	box.mesh = mesh
	box.position = (start + end) * 0.5
	box.rotation.y = atan2(direction.x, direction.z)
	box.material_override = material
	add_child(box)
	if collision_enabled:
		_add_box_collision(box.position, mesh.size, box.rotation.y)


func _add_cylinder(node_name: String, position: Vector3, radius: float,
		height: float, material: Material, collision_enabled: bool,
		segments: int = 32) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.04
	mesh.height = height
	mesh.radial_segments = segments
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	add_child(mesh_instance)
	if collision_enabled:
		var body := StaticBody3D.new()
		body.name = "%sCollision" % node_name
		var shape_node := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		shape_node.shape = shape
		body.add_child(shape_node)
		body.position = position
		add_child(body)


func _add_box_collision(position: Vector3, size: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name = "WalkableBridgeCollision"
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	body.position = position
	body.rotation.y = yaw
	add_child(body)


func _add_box_to(parent: Node3D, node_name: String, position: Vector3,
		size: Vector3, material: Material, collision_enabled: bool) -> void:
	var box := MeshInstance3D.new()
	box.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.position = position
	box.material_override = material
	parent.add_child(box)
	if collision_enabled:
		var body := StaticBody3D.new()
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		body.position = position
		parent.add_child(body)


func _add_cylinder_to(parent: Node3D, node_name: String, position: Vector3,
		radius: float, height: float, material: Material,
		collision_enabled: bool, segments: int) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.1
	mesh.height = height
	mesh.radial_segments = segments
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	if collision_enabled:
		var body := StaticBody3D.new()
		var shape_node := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		shape_node.shape = shape
		body.add_child(shape_node)
		body.position = position
		parent.add_child(body)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.25)
	material.roughness = 0.42
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
