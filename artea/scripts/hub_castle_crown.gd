# A small brass-and-crystal accent on the hub castle's roofline — four thin
# conduits, each carrying one glowing crystal, echoing the same magic
# already established at the portal pylons (hub_magitech.gd) and village
# lanterns (hub_landmark_glow.gd). Deliberately restrained: this kit reads
# as hand-modeled low-poly fantasy, and large runtime primitive shapes
# (rings, thick masts) sit on top of it looking like a placeholder mod
# rather than a designed piece. Small, thin, few — matching the kit's own
# scale — reads as intentional.
#
# Attached to the HubWorld root alongside hub_magitech.gd. Wakes on the same
# stage progression as everything else via apply_stage(), called from
# hub_awakening.gd.
extends Node3D

const CrystalShader := preload("res://shaders/artea_crystal.gdshader")
const CASTLE_NAME := "building_castle_red2"

const BRASS := Color(0.72, 0.52, 0.24)
const CROWN_CORE := Color(1.00, 0.72, 0.30)
const CROWN_RIM := Color(1.00, 0.88, 0.55)

const STAGE_AWAKE := [0.10, 0.35, 0.58, 0.8, 1.0]
const STAGE_GEAR_SPEED := [0.0, 0.06, 0.14, 0.24, 0.36]
const WAKE_SECONDS := 2.5

var _castle: Node3D
var _crystal_materials: Array[ShaderMaterial] = []
var _conduits: Array[Node3D] = []
var _gear_speed: float = 0.0
var _spire_lamp: OmniLight3D
var _breathe_time: float = 0.0


func _ready() -> void:
	await get_tree().process_frame
	_castle = get_parent().get_node_or_null(CASTLE_NAME) as Node3D
	if _castle == null:
		push_warning("Castle Crown: hub castle not found")
		return

	_build_crown()
	apply_stage(_current_stage())


func _process(delta: float) -> void:
	if not is_zero_approx(_gear_speed):
		for i in _conduits.size():
			var direction := 1.0 if i % 2 == 0 else -1.0
			_conduits[i].rotate_y(_gear_speed * direction * delta)

	if _spire_lamp != null:
		_breathe_time += delta
		var pulse := 0.5 + 0.5 * sin(_breathe_time * 0.6)
		_spire_lamp.light_energy = lerpf(1.1, 1.7, pulse)


func apply_stage(stage: int) -> void:
	stage = clampi(stage, 0, STAGE_AWAKE.size() - 1)
	if _crystal_materials.is_empty():
		return

	_gear_speed = STAGE_GEAR_SPEED[stage]
	var target: float = STAGE_AWAKE[stage]

	var tween := create_tween().set_parallel()
	for material in _crystal_materials:
		tween.tween_method(
			func(v: float) -> void: material.set_shader_parameter("awake", v),
			material.get_shader_parameter("awake"), target, WAKE_SECONDS
		).set_trans(Tween.TRANS_SINE)


# --- construction ------------------------------------------------------

func _build_crown() -> void:
	var rig := Node3D.new()
	rig.name = "CrownRig"
	_castle.add_child(rig)

	for i in range(4):
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var arm := Node3D.new()
		arm.name = "Conduit_%d" % (i + 1)
		arm.position = Vector3(cos(angle) * 0.42, 0.95, sin(angle) * 0.42)
		rig.add_child(arm)
		_conduits.append(arm)

		var pipe := MeshInstance3D.new()
		var pipe_mesh := CylinderMesh.new()
		pipe_mesh.top_radius = 0.018
		pipe_mesh.bottom_radius = 0.022
		pipe_mesh.height = 0.5
		pipe.mesh = pipe_mesh
		pipe.position.y = 0.25
		pipe.rotation.z = deg_to_rad(18.0) * (1.0 if i % 2 == 0 else -1.0)

		var brass_mat := StandardMaterial3D.new()
		brass_mat.albedo_color = BRASS
		brass_mat.metallic = 0.88
		brass_mat.roughness = 0.32
		pipe.material_override = brass_mat
		arm.add_child(pipe)

		var shard := MeshInstance3D.new()
		var shard_mesh := SphereMesh.new()
		shard_mesh.radius = 0.09
		shard_mesh.height = 0.26
		shard_mesh.radial_segments = 6
		shard_mesh.rings = 3
		shard.mesh = shard_mesh
		shard.position.y = 0.52

		var shard_mat := ShaderMaterial.new()
		shard_mat.shader = CrystalShader
		shard_mat.set_shader_parameter("awake", STAGE_AWAKE[0])
		shard_mat.set_shader_parameter("core_color", CROWN_CORE)
		shard_mat.set_shader_parameter("rim_color", CROWN_RIM)
		shard.material_override = shard_mat
		_crystal_materials.append(shard_mat)
		arm.add_child(shard)

		var lamp := OmniLight3D.new()
		lamp.position.y = 0.52
		lamp.light_color = CROWN_RIM
		lamp.light_energy = 0.9
		lamp.omni_range = 4.0
		lamp.shadow_enabled = false
		arm.add_child(lamp)

	var crown_jewel := MeshInstance3D.new()
	var jewel_mesh := SphereMesh.new()
	jewel_mesh.radius = 0.16
	jewel_mesh.height = 0.42
	jewel_mesh.radial_segments = 8
	jewel_mesh.rings = 4
	crown_jewel.mesh = jewel_mesh
	crown_jewel.position = Vector3(0.0, 1.55, 0.0)

	var jewel_mat := ShaderMaterial.new()
	jewel_mat.shader = CrystalShader
	jewel_mat.set_shader_parameter("awake", STAGE_AWAKE[0])
	jewel_mat.set_shader_parameter("core_color", CROWN_CORE)
	jewel_mat.set_shader_parameter("rim_color", CROWN_RIM)
	crown_jewel.material_override = jewel_mat
	_crystal_materials.append(jewel_mat)
	rig.add_child(crown_jewel)

	_spire_lamp = OmniLight3D.new()
	_spire_lamp.position = Vector3(0.0, 1.55, 0.0)
	_spire_lamp.light_color = CROWN_RIM
	_spire_lamp.light_energy = 1.4
	_spire_lamp.omni_range = 7.0
	_spire_lamp.shadow_enabled = false
	rig.add_child(_spire_lamp)

	var bob := create_tween().set_loops()
	bob.tween_property(crown_jewel, "position:y", 1.68, 2.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(crown_jewel, "position:y", 1.55, 2.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_build_chimney_smoke(rig)


func _build_chimney_smoke(rig: Node3D) -> void:
	var smoke := GPUParticles3D.new()
	smoke.name = "ChimneySmoke"
	smoke.position = Vector3(0.55, 0.3, -0.3)
	smoke.amount = 8
	smoke.lifetime = 4.0
	smoke.speed_scale = 0.6

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 12.0
	mat.gravity = Vector3(0.0, 0.15, 0.0)
	mat.initial_velocity_min = 0.12
	mat.initial_velocity_max = 0.22
	mat.scale_min = 0.15
	mat.scale_max = 0.32
	mat.color = Color(0.85, 0.85, 0.88, 0.35)
	smoke.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	smoke.draw_pass_1 = quad

	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(0.9, 0.9, 0.92, 0.4)
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = smoke_mat

	rig.add_child(smoke)


func _current_stage() -> int:
	if not is_inside_tree():
		return 0
	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return 0
	return clampi(js.stage, 0, STAGE_AWAKE.size() - 1)
