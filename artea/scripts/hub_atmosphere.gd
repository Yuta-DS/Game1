# One cheap global particle field for the Castle Universe. The motes are visual
# punctuation, not gameplay: low count, additive, unshadowed and one draw mesh.
extends Node3D


func _ready() -> void:
	var motes := GPUParticles3D.new()
	motes.name = "AetherMotes"
	motes.amount = 84
	motes.lifetime = 26.0
	motes.randomness = 0.9
	motes.preprocess = 26.0
	motes.position = Vector3(0.0, 92.0, 0.0)
	motes.visibility_aabb = AABB(Vector3(-270.0, -100.0, -270.0),
		Vector3(540.0, 210.0, 540.0))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(245.0, 82.0, 245.0)
	process.direction = Vector3(0.22, 0.7, -0.16)
	process.spread = 55.0
	process.initial_velocity_min = 0.12
	process.initial_velocity_max = 0.42
	process.gravity = Vector3(0.0, 0.015, 0.0)
	process.scale_min = 0.45
	process.scale_max = 1.35
	motes.process_material = process

	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow.albedo_color = Color(0.92, 0.84, 1.0, 0.62)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.82, 0.52)
	glow.emission_energy_multiplier = 1.35
	quad.material = glow
	motes.draw_pass_1 = quad
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(motes)
