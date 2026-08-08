# Small magitech lanterns at the village's landmark buildings — the castle,
# well, tavern, windmill, watermill, and lookout tower, plus each new
# district's market square. Deliberately few and small: one glowing crystal
# per landmark, no mast, no pipework. This kit is low-poly and hand-modeled;
# large runtime primitives read as a placeholder mod bolted onto it, so
# this stays a quiet accent light rather than a structure.
#
# The portal pylons (hub_magitech.gd) mark the journey's doorways. This
# marks a handful of landmarks, so the world reads as one waking place
# without turning every house into a lit-up prop.
extends Node3D

const CrystalShader := preload("res://shaders/artea_crystal.gdshader")

const LANDMARKS := [
	{
		"name": "Castle",
		"pos": Vector3(-51.4, 63.76, 27.41),
		"offset": Vector3(0.0, 9.0, 0.0),
		"color": Color(1.00, 0.72, 0.30),
	},
	{
		"name": "Well",
		"pos": Vector3(117.27, 20.6, -18.34),
		"offset": Vector3(0.0, 3.2, 0.0),
		"color": Color(0.45, 0.85, 1.00),
	},
	{
		"name": "Tavern",
		"pos": Vector3(55.0, 22.6, 55.3),
		"offset": Vector3(0.0, 6.5, 0.0),
		"color": Color(1.00, 0.55, 0.35),
	},
	{
		"name": "Windmill",
		"pos": Vector3(133.325, 33.616, 20.692),
		"offset": Vector3(0.0, 8.0, 0.0),
		"color": Color(0.72, 0.52, 1.00),
	},
	{
		"name": "Watermill",
		"pos": Vector3(115.175, 23.741, -33.069),
		"offset": Vector3(0.0, 6.5, 0.0),
		"color": Color(0.45, 0.85, 1.00),
	},
	{
		"name": "Tower",
		"pos": Vector3(19.9201, 6.67653, 189.907),
		"offset": Vector3(0.0, 10.0, 0.0),
		"color": Color(1.00, 0.72, 0.30),
	},
	{
		"name": "MindSparkMarket",
		"pos": Vector3(96.0, 20.3, -80.0),
		"offset": Vector3(0.0, 5.5, 0.0),
		"color": Color(0.31, 0.53, 0.86),
	},
	{
		"name": "CreatorsLightMarket",
		"pos": Vector3(46.0, 23.9, 52.0),
		"offset": Vector3(0.0, 5.5, 0.0),
		"color": Color(0.66, 0.33, 0.79),
	},
	{
		"name": "HeartMelodyMarket",
		"pos": Vector3(82.0, 21.8, 55.0),
		"offset": Vector3(0.0, 5.5, 0.0),
		"color": Color(0.95, 0.55, 0.30),
	},
	{
		"name": "MindSparkExtTower",
		"pos": Vector3(150.0, 17.87, -15.0),
		"offset": Vector3(0.0, 6.0, 0.0),
		"color": Color(0.31, 0.53, 0.86),
	},
	{
		"name": "CreatorsLightExtMine",
		"pos": Vector3(20.0, 19.1, 100.0),
		"offset": Vector3(0.0, 5.5, 0.0),
		"color": Color(0.66, 0.33, 0.79),
	},
	{
		"name": "HeartMelodyExtBlacksmith",
		"pos": Vector3(8.0, 25.39, 21.0),
		"offset": Vector3(0.0, 5.0, 0.0),
		"color": Color(0.95, 0.55, 0.30),
	},
]

const STAGE_AWAKE := [0.15, 0.40, 0.62, 0.82, 1.0]
const WAKE_SECONDS := 2.5

var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	await get_tree().process_frame

	for landmark in LANDMARKS:
		_build_lantern(landmark)

	apply_stage(_current_stage())


func apply_stage(stage: int) -> void:
	stage = clampi(stage, 0, STAGE_AWAKE.size() - 1)
	if _materials.is_empty():
		return
	var target: float = STAGE_AWAKE[stage]

	var tween := create_tween().set_parallel()
	for material in _materials:
		tween.tween_method(
			func(v: float) -> void: material.set_shader_parameter("awake", v),
			material.get_shader_parameter("awake"), target, WAKE_SECONDS
		).set_trans(Tween.TRANS_SINE)


func _build_lantern(landmark: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Lantern_%s" % landmark["name"]
	holder.position = landmark["pos"] + landmark["offset"]
	add_child(holder)

	var shard := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.32
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	shard.mesh = mesh

	var material := ShaderMaterial.new()
	material.shader = CrystalShader
	material.set_shader_parameter("awake", STAGE_AWAKE[0])
	material.set_shader_parameter("core_color", landmark["color"])
	material.set_shader_parameter("rim_color", landmark["color"].lightened(0.35))
	material.set_shader_parameter("glow_strength", 2.2)
	shard.material_override = material
	_materials.append(material)
	holder.add_child(shard)

	var lamp := OmniLight3D.new()
	lamp.light_color = landmark["color"]
	lamp.light_energy = 1.1
	lamp.omni_range = 6.0
	lamp.shadow_enabled = false
	holder.add_child(lamp)

	var phase := fmod(landmark["pos"].x + landmark["pos"].z, 3.0)
	var bob := create_tween().set_loops()
	bob.tween_interval(phase * 0.4)
	bob.tween_property(shard, "position:y", 0.35, 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(shard, "position:y", -0.35, 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _current_stage() -> int:
	if not is_inside_tree():
		return 0
	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return 0
	return clampi(js.stage, 0, STAGE_AWAKE.size() - 1)
