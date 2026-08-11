# ARTÉA's map is a physical place in the hub: half celestial observatory,
# half scientific instrument. It shows the three kingdoms as floating models
# rather than flat menu buttons, so the player can read their whole journey
# at a glance.
extends Node3D

const ATLAS_POSITION := Vector3(17.0, 37.0, -9.0)
const BRASS := Color("b78242")
const INK := Color("10182b")
const REALM_COLOURS := [Color("78b7ff"), Color("f29b67"), Color("d98cff")]
const REALM_NAMES := ["MIND SPARK", "HEART MELODY", "CREATOR'S LIGHT"]
const REALM_SUBTITLES := ["PATTERN / POSSIBILITY", "RESONANCE / REST", "ALCHEMY / EXPRESSION"]
const REALM_POSITIONS := [
	Vector3(-2.35, 0.75, -1.25),
	Vector3(2.35, 0.85, -1.15),
	Vector3(0.0, 0.95, 2.35),
]

var _built := false
var _stage := 0
var _time := 0.0
var _realm_materials: Array[StandardMaterial3D] = []
var _realm_lamps: Array[OmniLight3D] = []
var _realm_models: Array[Node3D] = []
var _core_material: StandardMaterial3D
var _core_lamp: OmniLight3D
var _crown: Node3D


func _ready() -> void:
	# The atlas is deliberately close to the arrival path: it gives the player
	# an immediate "where am I going?" answer before any gameplay begins.
	position = ATLAS_POSITION
	_build()
	_built = true
	apply_stage(_current_stage())


func _process(delta: float) -> void:
	if not _built:
		return
	_time += delta
	for i in _realm_models.size():
		var model := _realm_models[i]
		model.position.y = REALM_POSITIONS[i].y + sin(_time * 0.8 + i * 1.7) * 0.09
		model.rotate_y(delta * (0.14 + i * 0.03))
	if _crown != null:
		_crown.rotate_y(delta * 0.28)


# Called with all other hub transformation systems.
func apply_stage(stage: int) -> void:
	if not _built:
		return
	_stage = clampi(stage, 0, 4)

	for i in _realm_materials.size():
		var unlocked := _stage >= i + 1
		var material := _realm_materials[i]
		var colour: Color = REALM_COLOURS[i] if unlocked else Color("34425c")
		material.albedo_color = colour
		material.emission = colour
		material.emission_energy_multiplier = 1.05 if unlocked else 0.12
		_realm_lamps[i].light_color = colour
		_realm_lamps[i].light_energy = 1.35 if unlocked else 0.0

	if _core_material != null:
		var core_colour := Color("ffd66e") if _stage >= 4 else Color("6f85a9")
		_core_material.albedo_color = core_colour
		_core_material.emission = core_colour
		_core_material.emission_energy_multiplier = 1.45 if _stage >= 4 else 0.32
		_core_lamp.light_color = core_colour
		_core_lamp.light_energy = 1.5 if _stage >= 4 else 0.28
	if _crown != null:
		_crown.visible = _stage >= 4


func _build() -> void:
	name = "AetherAtlas"
	_build_observatory()
	_build_core()
	for i in REALM_NAMES.size():
		_build_realm(i)
	_build_titles()


# The table is the scientific side: graduated rings and brass mechanisms.
# The moving lights and suspended worlds make it magical without becoming an
# imitation of any existing fictional castle.
func _build_observatory() -> void:
	_add_mesh(_cylinder(3.7, 3.95, 0.42), _metal(BRASS), Vector3(0.0, -1.12, 0.0))
	_add_mesh(_cylinder(3.32, 3.32, 0.10), _metal(INK), Vector3(0.0, -0.86, 0.0))

	for radius in [1.32, 2.16, 3.04]:
		var ring := _add_mesh(_torus(radius - 0.035, radius + 0.035), _metal(BRASS),
			Vector3(0.0, -0.76, 0.0))
		ring.rotation.x = PI * 0.5

	# A circuit-like radial grid: compass bearings become spell traces.
	for i in range(12):
		var angle := TAU * float(i) / 12.0
		var tick := _add_mesh(_box(Vector3(0.035, 0.025, 1.1)), _metal(BRASS),
			Vector3(cos(angle) * 2.6, -0.71, sin(angle) * 2.6))
		tick.rotation.y = -angle

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(0.0, 1.4, 0.0)
	rim_light.light_color = Color("9bb8e8")
	rim_light.light_energy = 0.55
	rim_light.omni_range = 10.0
	rim_light.shadow_enabled = false
	add_child(rim_light)


# The core is the "story engine": the three paths connect into one eventual
# Crown of Life, not three separate activities.
func _build_core() -> void:
	var core := Node3D.new()
	core.name = "StoryEngine"
	core.position = Vector3(0.0, 0.03, 0.0)
	add_child(core)

	var orb := _add_mesh(_sphere(0.42, 0.78), _glow(Color("6f85a9")), Vector3.ZERO)
	_core_material = orb.material_override as StandardMaterial3D
	_add_mesh(_torus(0.52, 0.58), _metal(BRASS), Vector3.ZERO)

	_core_lamp = OmniLight3D.new()
	_core_lamp.omni_range = 8.0
	_core_lamp.shadow_enabled = false
	core.add_child(_core_lamp)

	_crown = Node3D.new()
	_crown.name = "CrownOfLife"
	_crown.position = Vector3(0.0, 0.76, 0.0)
	core.add_child(_crown)
	for i in range(5):
		var jewel := _add_mesh(_sphere(0.11, 0.25), _glow(Color("ffd66e")),
			Vector3(cos(TAU * i / 5.0) * 0.42, 0.0, sin(TAU * i / 5.0) * 0.42))
		jewel.rotation.z = 0.28


func _build_realm(index: int) -> void:
	var model := Node3D.new()
	model.name = REALM_NAMES[index].capitalize().replace(" ", "") + "Model"
	model.position = REALM_POSITIONS[index]
	add_child(model)
	_realm_models.append(model)

	var colour: Color = REALM_COLOURS[index]
	var glow := _glow(colour)
	_realm_materials.append(glow)

	# A little floating landform anchors every kingdom. Its low, faceted form
	# reads as a map model, not a second full-size world competing with the hub.
	_add_mesh_to(model, _sphere(0.83, 0.42), _metal(Color("28334b")),
		Vector3(0.0, -0.08, 0.0), Vector3(1.28, 0.54, 1.0))
	_add_mesh_to(model, _cylinder(0.68, 0.84, 0.15), _metal(BRASS), Vector3(0.0, -0.24, 0.0))

	match index:
		0:
			_build_mind_model(model, glow)
		1:
			_build_heart_model(model, glow)
		2:
			_build_creator_model(model, glow)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 0.72, 0.0)
	lamp.omni_range = 5.5
	lamp.shadow_enabled = false
	model.add_child(lamp)
	_realm_lamps.append(lamp)

	_add_label(model, REALM_NAMES[index], Vector3(0.0, 1.23, 0.0), colour, 27)
	_add_label(model, REALM_SUBTITLES[index], Vector3(0.0, 0.91, 0.0), Color("e8efff"), 14)
	_add_link(Vector3.ZERO, REALM_POSITIONS[index], colour)


# Mind Spark = a neural constellation held in a crystal analyser.
func _build_mind_model(model: Node3D, glow: StandardMaterial3D) -> void:
	for i in range(5):
		var angle := TAU * i / 5.0
		var node := _add_mesh_to(model, _sphere(0.09, 0.12), glow,
			Vector3(cos(angle) * 0.46, 0.26 + (i % 2) * 0.12, sin(angle) * 0.35))
		node.scale = Vector3(1.0, 1.45, 1.0)
	_add_mesh_to(model, _torus(0.38, 0.43), glow, Vector3(0.0, 0.26, 0.0),
		Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0))


# Heart Melody = two visible harmonic waves crossing around a warm core.
func _build_heart_model(model: Node3D, glow: StandardMaterial3D) -> void:
	for i in range(3):
		var wave := _add_mesh_to(model, _torus(0.24 + i * 0.15, 0.28 + i * 0.15), glow,
			Vector3(0.0, 0.25 + i * 0.07, 0.0))
		wave.rotation = Vector3(PI * 0.5, i * 0.7, 0.0)
	_add_mesh_to(model, _sphere(0.19, 0.32), glow, Vector3(0.0, 0.28, 0.0))


# Creator's Light = a gear-flower surrounding an alchemical crystal.
func _build_creator_model(model: Node3D, glow: StandardMaterial3D) -> void:
	var gear := _add_mesh_to(model, _torus(0.42, 0.54), _metal(BRASS), Vector3(0.0, 0.18, 0.0))
	gear.rotation.x = PI * 0.5
	for i in range(6):
		var angle := TAU * i / 6.0
		_add_mesh_to(model, _box(Vector3(0.12, 0.1, 0.22)), _metal(BRASS),
			Vector3(cos(angle) * 0.56, 0.18, sin(angle) * 0.56), Vector3.ONE,
			Vector3(0.0, -angle, 0.0))
	_add_mesh_to(model, _sphere(0.18, 0.48), glow, Vector3(0.0, 0.35, 0.0))


func _build_titles() -> void:
	_add_label(self, "ARTÉA AETHER ATLAS", Vector3(0.0, 2.18, 0.0), Color("ffe2a0"), 37)
	_add_label(self, "THOUGHT  →  FEELING  →  CREATION  →  LIGHT", Vector3(0.0, 1.82, 0.0),
		Color("c9d7f2"), 15)


func _add_link(from: Vector3, to: Vector3, colour: Color) -> void:
	var midpoint := (from + to) * 0.5
	var line := _add_mesh(_cylinder(0.028, 0.028, from.distance_to(to)), _glow(colour), midpoint)
	line.look_at(to, Vector3.UP)
	line.rotate_object_local(Vector3.RIGHT, PI * 0.5)


func _add_mesh(mesh: Mesh, material: Material, at: Vector3,
		scale := Vector3.ONE, rotation := Vector3.ZERO) -> MeshInstance3D:
	return _add_mesh_to(self, mesh, material, at, scale, rotation)


func _add_mesh_to(parent: Node3D, mesh: Mesh, material: Material, at: Vector3,
		scale := Vector3.ONE, rotation := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.scale = scale
	part.rotation = rotation
	parent.add_child(part)
	return part


func _add_label(parent: Node3D, text: String, at: Vector3, colour: Color, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.font_size = size
	label.outline_size = 4
	label.modulate = colour
	label.pixel_size = 0.007
	parent.add_child(label)


func _glow(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 0.3
	material.metallic = 0.2
	material.roughness = 0.25
	return material


func _metal(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = 0.87
	material.roughness = 0.34
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
	mesh.radial_segments = 16
	return mesh


func _torus(inner_radius: float, outer_radius: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 20
	mesh.ring_segments = 10
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _current_stage() -> int:
	var js := get_node_or_null("/root/JourneyState")
	return clampi(js.stage, 0, 4) if js != null else 0
