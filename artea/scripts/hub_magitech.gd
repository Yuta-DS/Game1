# Artéa's magic-meets-science dressing for the hub world.
#
# Howl's-Moving-Castle logic: the machinery and the magic are the same thing.
# Each portal gets a pylon that is half orrery, half spell circle — brass
# gears turning under a floating crystal, standing on an etched rune disc.
#
# Everything here is dormant at stage 0 and wakes as the journey deepens,
# reusing the same progression hub_awakening.gd already drives the sun with.
# Nothing is authored into New_Hub_World.tscn: this builds at runtime, so the
# scene file stays clean and the whole look can be removed by deleting one
# node.
extends Node3D

const CrystalShader := preload("res://shaders/artea_crystal.gdshader")
const HubLightFade := preload("res://scripts/hub_light_fade.gd")

# Where the journey's doorways are. Positions read from the Area3D teleports
# in New_Hub_World.tscn — the hub's ground sits at Y=15-20, not 0, so these
# are absolute world coordinates rather than offsets.
#
# Each portal gets the palette of the kingdom it leads to: thoughts are cool
# and analytical, emotions warm, creation golden.
const PORTALS := [
	{
		"name": "Thoughts",
		"pos": Vector3(90.3, 15.0, -83.0),
		"core": Color(0.42, 0.62, 1.00),   # cold blue — the science end
		"rim": Color(0.60, 0.90, 1.00),
	},
	{
		"name": "Gallery",
		"pos": Vector3(-32.3, 20.0, -2.0),
		"core": Color(1.00, 0.72, 0.30),   # gold — the finished self
		"rim": Color(1.00, 0.90, 0.60),
	},
	{
		"name": "Music",
		"pos": Vector3(80.0, 18.7, 72.0),
		"core": Color(0.95, 0.55, 0.30),   # warm amber — Heart Melody
		"rim": Color(1.00, 0.78, 0.55),
	},
]

# How awake the machinery is per stage. Index = JourneyState.stage.
# Stage 0 is not zero: a completely dead pylon reads as broken art rather
# than as sleeping machinery. A faint ember says "this could wake".
const STAGE_AWAKE := [0.08, 0.35, 0.60, 0.82, 1.0]

# Gear rotation speed (radians/sec) per stage — frozen, then turning.
const STAGE_GEAR_SPEED := [0.0, 0.15, 0.35, 0.6, 0.9]

const WAKE_SECONDS := 2.5

# Brass, for the science half. Warm metal against cold crystal light.
const BRASS := Color(0.72, 0.52, 0.24)

var _crystal_materials: Array[ShaderMaterial] = []
var _gears: Array[Node3D] = []
var _gear_speed: float = 0.0


func _ready() -> void:
	# Let the hub finish building before adding to it.
	await get_tree().process_frame

	for portal in PORTALS:
		_build_pylon(portal)

	apply_stage(_current_stage())


func _process(delta: float) -> void:
	if is_zero_approx(_gear_speed):
		return

	# Alternate direction so meshing gears look driven, not merely spinning.
	for i in _gears.size():
		var direction := 1.0 if i % 2 == 0 else -1.4
		_gears[i].rotate_y(_gear_speed * direction * delta)


# Wake the machinery to a stage. Public so hub_awakening's dev keys 1-5 and
# the journey-erase panel can drive it live.
func apply_stage(stage: int) -> void:
	stage = clampi(stage, 0, STAGE_AWAKE.size() - 1)
	# HubWorld applies its stage before children that await a frame have built
	# their meshes. Defer that first call; _ready applies the same stage after
	# the pylon materials exist.
	if _crystal_materials.is_empty():
		return

	_gear_speed = STAGE_GEAR_SPEED[stage]

	var target: float = STAGE_AWAKE[stage]
	var tween := create_tween().set_parallel()

	for material in _crystal_materials:
		material.set_shader_parameter("awake", STAGE_AWAKE[0])
		tween.tween_method(
			func(v: float) -> void: material.set_shader_parameter("awake", v),
			STAGE_AWAKE[0], target, WAKE_SECONDS).set_trans(Tween.TRANS_SINE)


# --- construction ----------------------------------------------------

func _build_pylon(portal: Dictionary) -> void:
	var pylon := Node3D.new()
	pylon.name = "Pylon_%s" % portal["name"]
	pylon.position = portal["pos"]
	add_child(pylon)

	pylon.add_child(_plinth())

	# Two gears at different heights and sizes, so the mechanism reads as a
	# mechanism rather than as one spinning ring.
	var lower := _gear(1.5, 10, 0.16)
	lower.position.y = 1.15
	pylon.add_child(lower)
	_gears.append(lower)

	var upper := _gear(1.05, 8, 0.13)
	upper.position.y = 1.72
	pylon.add_child(upper)
	_gears.append(upper)

	var shard := _crystal_shard(portal["core"], portal["rim"])
	shard.position.y = 2.75
	pylon.add_child(shard)

	# The crystal lights the ground under it. Range is deliberately short so
	# four pylons cannot wash out the stage lighting hub_awakening controls.
	var lamp := OmniLight3D.new()
	lamp.position.y = 2.75
	lamp.light_color = portal["rim"]
	lamp.light_energy = 1.6
	lamp.omni_range = 9.0
	lamp.shadow_enabled = false
	HubLightFade.apply(lamp)
	pylon.add_child(lamp)


# Stone base the mechanism stands on.
func _plinth() -> MeshInstance3D:
	var plinth := MeshInstance3D.new()

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.85
	mesh.bottom_radius = 1.15
	mesh.height = 0.9
	plinth.mesh = mesh
	plinth.position.y = 0.45

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.28, 0.27, 0.33)
	material.roughness = 0.85
	plinth.material_override = material

	return plinth


# A brass gear: a flat ring with teeth spaced around it. Built from boxes
# rather than a mesh asset, since the project has no gear model.
func _gear(radius: float, teeth: int, thickness: float) -> Node3D:
	var gear := Node3D.new()

	var brass := StandardMaterial3D.new()
	brass.albedo_color = BRASS
	brass.metallic = 0.9
	brass.roughness = 0.35

	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = radius
	body_mesh.bottom_radius = radius
	body_mesh.height = thickness
	body.mesh = body_mesh
	body.material_override = brass
	gear.add_child(body)

	var tooth_mesh := BoxMesh.new()
	tooth_mesh.size = Vector3(radius * 0.22, thickness, radius * 0.3)

	for i in teeth:
		var tooth := MeshInstance3D.new()
		tooth.mesh = tooth_mesh
		tooth.material_override = brass

		var angle := TAU * float(i) / float(teeth)
		tooth.position = Vector3(
			cos(angle) * radius, 0.0, sin(angle) * radius)
		tooth.rotation.y = -angle
		gear.add_child(tooth)

	return gear


# The floating shard. Faceted via a low-segment sphere so it catches light
# in planes rather than reading as a smooth ball.
func _crystal_shard(core: Color, rim: Color) -> Node3D:
	var holder := Node3D.new()

	var shard := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.55
	mesh.height = 1.7
	mesh.radial_segments = 6
	mesh.rings = 3
	shard.mesh = mesh

	var material := ShaderMaterial.new()
	material.shader = CrystalShader
	material.set_shader_parameter("awake", STAGE_AWAKE[0])
	material.set_shader_parameter("core_color", core)
	material.set_shader_parameter("rim_color", rim)
	shard.material_override = material
	_crystal_materials.append(material)

	holder.add_child(shard)

	# Bob and turn — the shard is held by the mechanism, not resting on it.
	var bob := create_tween().set_loops()
	bob.tween_property(shard, "position:y", 0.22, 2.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(shard, "position:y", -0.22, 2.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var spin := create_tween().set_loops()
	spin.tween_property(shard, "rotation:y", TAU, 14.0).from(0.0)

	return holder


func _current_stage() -> int:
	if not is_inside_tree():
		return 0

	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return 0

	return clampi(js.stage, 0, STAGE_AWAKE.size() - 1)
