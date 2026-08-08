# The Lumen Engine Citadel is Artéa's original roaming landmark.
#
# It deliberately avoids copying any existing film castle: this is a bright,
# restorative machine-city whose science is visible. Brass mechanisms collect
# the light made by the player, while constellations map the next gentle step
# in their journey. It is built at runtime so the large hub scene stays easy
# to edit in Godot.
extends Node3D

const THOUGHTS_PORTAL := Vector3(90.3, 15.0, -83.0)
const CASTLE_NAME := "building_castle_red2"
const STAGE_COLOURS := [
	Color("415777"), # sleeping blue-grey
	Color("86b7ff"), # a thought noticed
	Color("f5a95e"), # a feeling named
	Color("d98cff"), # a creation made
	Color("ffd66e"), # a whole constellation
]

const BRASS := Color("b78242")
const INK := Color("18243d")
const GLASS := Color("86dfff")

var _castle: Node3D
var _castle_start_position := Vector3.ZERO
var _time := 0.0
var _stage := 0
var _rotors: Array[Node3D] = []
var _light_materials: Array[StandardMaterial3D] = []
var _waypoint_lights: Array[OmniLight3D] = []
var _citadel_lamp: OmniLight3D
var _castle_fill: OmniLight3D
var _foundation: Node3D
var _foundation_start_y := 0.0


func _ready() -> void:
	# The packed hub finishes instancing its large castle before we attach the
	# living machinery. This also makes the script safe when previewed alone.
	await get_tree().process_frame
	_castle = get_parent().get_node_or_null(CASTLE_NAME) as Node3D
	if _castle == null:
		push_warning("Lumen Citadel: hub castle not found")
		return

	_castle_start_position = _castle.position
	_brighten_castle_materials(_castle)
	_build_castle_foundation()
	_build_citadel_rig()
	_build_skyway()
	apply_stage(_current_stage())


func _process(delta: float) -> void:
	if _castle == null:
		return

	_time += delta
	# A slow buoyant drift makes it feel alive without moving its collision or
	# obscuring the village. The castle never becomes a chase target.
	var bob := sin(_time * 0.42) * 0.22
	_castle.position.y = _castle_start_position.y + bob
	if _foundation != null:
		_foundation.position.y = _foundation_start_y + bob

	for i in _rotors.size():
		var direction := 1.0 if i % 2 == 0 else -1.0
		_rotors[i].rotate_y(direction * delta * (0.18 + _stage * 0.12))


# Called by hub_awakening whenever the player returns with a new discovery.
func apply_stage(stage: int) -> void:
	_stage = clampi(stage, 0, STAGE_COLOURS.size() - 1)
	var glow: Color = STAGE_COLOURS[_stage]
	var energy := 0.18 + float(_stage) * 0.38

	for material in _light_materials:
		material.emission = glow
		material.emission_energy_multiplier = energy

	for i in _waypoint_lights.size():
		# The route only reveals the next destination at first. Later lights
		# make the complete journey legible as one path, rather than a menu.
		_waypoint_lights[i].visible = i <= _stage
		_waypoint_lights[i].light_color = glow

	if _citadel_lamp != null:
		_citadel_lamp.light_color = glow
		_citadel_lamp.light_energy = 0.4 + float(_stage) * 0.28
	if _castle_fill != null:
		_castle_fill.light_color = glow.lightened(0.28)
		_castle_fill.light_energy = 1.05 + float(_stage) * 0.16


func set_vibrant(vibrant: bool) -> void:
	apply_stage(4 if vibrant else 0)


func is_vibrant() -> bool:
	return _stage > 0


# --- Citadel ---------------------------------------------------------

# The imported castle previously hovered as a bare building with open sky under
# its floor. This low-poly rock/engine island gives it physical weight, a future
# gallery plaza, and anchor chains fading toward the fog below.
func _build_castle_foundation() -> void:
	_foundation = Node3D.new()
	_foundation.name = "CastleFoundation"
	get_parent().add_child(_foundation)
	_foundation.position = Vector3(_castle.position.x, _castle.position.y - 4.2,
		_castle.position.z)
	_foundation_start_y = _foundation.position.y

	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_color = Color(0.36, 0.34, 0.46)
	rock_material.roughness = 0.92
	rock_material.emission_enabled = true
	rock_material.emission = Color(0.16, 0.14, 0.23)
	rock_material.emission_energy_multiplier = 0.12

	var island := MeshInstance3D.new()
	var island_mesh := SphereMesh.new()
	island_mesh.radius = 16.5
	island_mesh.height = 11.0
	island_mesh.radial_segments = 10
	island_mesh.rings = 5
	island.mesh = island_mesh
	island.scale = Vector3(1.0, 1.0, 0.82)
	island.material_override = rock_material
	_foundation.add_child(island)

	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_cylinder := CylinderShape3D.new()
	floor_cylinder.radius = 15.2
	floor_cylinder.height = 2.0
	floor_shape.shape = floor_cylinder
	floor_shape.position.y = 4.7
	floor_body.add_child(floor_shape)
	_foundation.add_child(floor_body)

	# GALLERY_ANCHOR — future gallery/world content can attach here without
	# depending on the imported castle's internal glTF node names.
	var gallery_anchor := Node3D.new()
	gallery_anchor.name = "GALLERY_ANCHOR"
	gallery_anchor.position = Vector3(10.5, 5.8, 0.0)
	gallery_anchor.set_meta("purpose", "future_gallery_courtyard")
	_foundation.add_child(gallery_anchor)

	var plaza := MeshInstance3D.new()
	var plaza_mesh := CylinderMesh.new()
	plaza_mesh.top_radius = 7.0
	plaza_mesh.bottom_radius = 7.6
	plaza_mesh.height = 0.7
	plaza_mesh.radial_segments = 10
	plaza.mesh = plaza_mesh
	plaza.position = gallery_anchor.position
	plaza.material_override = _ink_material()
	_foundation.add_child(plaza)

	# Roots and brass chains descend beyond the clear play space into distance
	# fog. Five asymmetric anchors keep the silhouette from feeling manufactured.
	for i in 5:
		var angle := TAU * float(i) / 5.0 + 0.35
		var anchor := Vector3(cos(angle) * (8.0 + float(i % 2) * 2.5),
			-12.0 - float(i % 3) * 3.5, sin(angle) * (7.0 + float((i + 1) % 2) * 2.0))
		var chain := MeshInstance3D.new()
		var chain_mesh := CylinderMesh.new()
		chain_mesh.top_radius = 0.22
		chain_mesh.bottom_radius = 0.38
		chain_mesh.height = 25.0 + float(i) * 2.5
		chain_mesh.radial_segments = 5
		chain.mesh = chain_mesh
		chain.position = anchor
		chain.rotation_degrees = Vector3(5.0 + float(i) * 2.0, 0.0,
			-7.0 + float(i) * 3.0)
		chain.material_override = _brass_material() if i % 2 == 0 else rock_material
		chain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_foundation.add_child(chain)

	_castle_fill = OmniLight3D.new()
	_castle_fill.name = "CastleDetailFill"
	_castle_fill.position = Vector3(9.0, 18.0, 8.0)
	_castle_fill.light_color = Color(1.0, 0.78, 0.48)
	_castle_fill.light_energy = 1.05
	_castle_fill.omni_range = 58.0
	_castle_fill.omni_attenuation = 1.25
	_castle_fill.shadow_enabled = false
	_foundation.add_child(_castle_fill)


# Preserve the imported albedo texture in shadow by reusing it as a very low
# emission texture. Direct sunlight still supplies shape; this only prevents the
# castle from collapsing into a single mauve silhouette against the bright sky.
func _brighten_castle_materials(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_node := child as MeshInstance3D
			if mesh_node.mesh != null:
				for surface in mesh_node.mesh.get_surface_count():
					var source := mesh_node.get_active_material(surface)
					if source is StandardMaterial3D:
						var material := source.duplicate() as StandardMaterial3D
						material.emission_enabled = true
						material.emission = Color(0.58, 0.52, 0.48)
						material.emission_energy_multiplier = 0.24
						if material.albedo_texture != null:
							material.emission_texture = material.albedo_texture
						mesh_node.set_surface_override_material(surface, material)
		_brighten_castle_materials(child)

func _build_citadel_rig() -> void:
	var rig := Node3D.new()
	rig.name = "LumenEngineRig"
	_castle.add_child(rig)

	# The undercarriage gives the authored castle a singular identity: an
	# observatory, a power plant, and a sanctuary in the same silhouette.
	var engine := Node3D.new()
	engine.name = "Heart_Engine"
	engine.position = Vector3(0.0, -0.58, 0.0)
	rig.add_child(engine)
	_add_mesh(engine, _sphere(0.62, 1.12), _glow_material(STAGE_COLOURS[0]),
		Vector3.ZERO, Vector3(1.0, 0.62, 1.0))
	_add_mesh(engine, _cylinder(0.88, 0.88, 0.18), _brass_material(),
		Vector3(0.0, -0.23, 0.0))
	_add_mesh(engine, _torus(0.34, 0.76), _brass_material(),
		Vector3(0.0, 0.02, 0.0), Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0))

	_citadel_lamp = OmniLight3D.new()
	_citadel_lamp.position = Vector3(0.0, -0.2, 0.0)
	_citadel_lamp.omni_range = 18.0
	_citadel_lamp.shadow_enabled = false
	engine.add_child(_citadel_lamp)

	# Four articulated stabilisers read as a travelling machine, not a static
	# fantasy prop. They fold outward gently beneath the existing castle.
	for i in range(4):
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var leg := Node3D.new()
		leg.name = "Stabiliser_%d" % (i + 1)
		leg.position = Vector3(cos(angle) * 0.78, -0.42, sin(angle) * 0.78)
		leg.rotation.y = -angle
		rig.add_child(leg)
		_add_mesh(leg, _box(Vector3(0.17, 0.72, 0.18)), _brass_material(),
			Vector3(0.0, -0.35, 0.34), Vector3.ONE, Vector3(0.48, 0.0, 0.0))
		_add_mesh(leg, _box(Vector3(0.34, 0.13, 0.46)), _ink_material(),
			Vector3(0.0, -0.78, 0.62))

	# Three orbital instruments visibly turn. Their motion is intentionally
	# modest: a child-focused hub should feel wonderous, never frantic.
	for i in range(3):
		var rotor := Node3D.new()
		rotor.name = "Orbit_Instrument_%d" % (i + 1)
		rotor.position = Vector3(0.0, 0.95 + i * 0.25, 0.0)
		rotor.rotation_degrees = Vector3(28.0 + i * 19.0, i * 58.0, 0.0)
		rig.add_child(rotor)
		_add_mesh(rotor, _torus(0.48 + i * 0.14, 0.53 + i * 0.14), _brass_material(), Vector3.ZERO)
		var bead_position := Vector3(0.54 + i * 0.14, 0.0, 0.0)
		_add_mesh(rotor, _sphere(0.1, 0.1), _glow_material(STAGE_COLOURS[0]), bead_position)
		_rotors.append(rotor)

	_add_title(rig, "LUMEN ENGINE CITADEL", Vector3(0.0, 2.2, 0.0), Color("ffe5a1"), 40)


# --- Living map ------------------------------------------------------

func _build_skyway() -> void:
	var map := Node3D.new()
	map.name = "SkywayMap"
	get_parent().add_child(map)

	# A small, physical constellation is more useful than a full-screen map:
	# it literally connects the sleeping citadel to the first kingdom.
	var route := [
		Vector3(-28.0, 42.0, 22.0),
		Vector3(5.0, 39.0, 5.0),
		Vector3(35.0, 33.0, -20.0),
		Vector3(65.0, 27.0, -53.0),
		THOUGHTS_PORTAL + Vector3(0.0, 7.0, 0.0),
	]

	for i in route.size():
		var point: Vector3 = route[i]
		var star := MeshInstance3D.new()
		star.name = "Skyway_Star_%d" % (i + 1)
		star.mesh = _sphere(0.42 if i == route.size() - 1 else 0.22,
			0.42 if i == route.size() - 1 else 0.22)
		star.material_override = _glow_material(STAGE_COLOURS[0])
		star.position = point
		map.add_child(star)

		var lamp := OmniLight3D.new()
		lamp.position = point
		lamp.omni_range = 7.5
		lamp.light_energy = 0.8
		lamp.shadow_enabled = false
		map.add_child(lamp)
		_waypoint_lights.append(lamp)

		if i > 0:
			_add_route_segment(map, route[i - 1], point)

	var destination := Node3D.new()
	destination.name = "MindSparkWaypoint"
	destination.position = THOUGHTS_PORTAL + Vector3(0.0, 8.3, 0.0)
	map.add_child(destination)
	_add_mesh(destination, _torus(0.92, 1.02), _glow_material(STAGE_COLOURS[1]), Vector3.ZERO)
	_add_title(destination, "MIND SPARK KINGDOM", Vector3(0.0, 1.25, 0.0), Color("b9dfff"), 36)
	_add_title(destination, "Begin with one thought", Vector3(0.0, 0.78, 0.0), Color("eff7ff"), 22)


func _add_route_segment(parent: Node3D, from: Vector3, to: Vector3) -> void:
	var midpoint := (from + to) * 0.5
	var segment := MeshInstance3D.new()
	segment.mesh = _cylinder(0.035, 0.035, from.distance_to(to))
	segment.material_override = _glow_material(Color("789dcc"))
	segment.position = midpoint
	parent.add_child(segment)
	segment.look_at(to, Vector3.UP)
	segment.rotate_object_local(Vector3.RIGHT, PI * 0.5)


# --- Tiny mesh/material helpers -------------------------------------

func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, position: Vector3,
		scale := Vector3.ONE, rotation := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = position
	part.scale = scale
	part.rotation = rotation
	parent.add_child(part)
	return part


func _add_title(parent: Node3D, title: String, position: Vector3, colour: Color, size: int) -> void:
	var label := Label3D.new()
	label.text = title
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.font_size = size
	label.outline_size = 5
	label.modulate = colour
	label.pixel_size = 0.008
	parent.add_child(label)


func _glow_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 0.45
	material.metallic = 0.18
	material.roughness = 0.26
	_light_materials.append(material)
	return material


func _brass_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = BRASS
	material.metallic = 0.9
	material.roughness = 0.31
	return material


func _ink_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = INK
	material.metallic = 0.55
	material.roughness = 0.48
	return material


func _sphere(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


func _cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 12
	return mesh


func _torus(inner_radius: float, outer_radius: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 12
	mesh.ring_segments = 8
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _current_stage() -> int:
	var js := get_node_or_null("/root/JourneyState")
	return clampi(js.stage, 0, STAGE_COLOURS.size() - 1) if js != null else 0
