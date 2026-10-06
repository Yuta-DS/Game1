extends Node3D

const Plants := preload("res://scripts/castle_medieval_planting.gd")
const Bot := preload("res://scripts/castle_royal_botanicals.gd")
const FlameShader := preload("res://shaders/castle_parapet_flame.gdshader")
var _clock := 0.0
var _phase := 0.0
var _flame: ShaderMaterial
var _light: OmniLight3D

static func build(parent: Node3D, at: Vector3, phase: float) -> Node3D:
	var torch := Node3D.new()
	torch.set_script(load("res://scripts/castle_parapet_torch.gd"))
	torch.name = "PalaceParapetTorch_%d" % parent.get_child_count()
	parent.add_child(torch)
	torch.global_position = at
	torch._phase = phase
	torch._build()
	return torch

func _build() -> void:
	set_meta("visual_only", true)
	set_meta("replaces", "green_globe_urn")
	set_meta("animation", "independent_realtime_flame_and_light")
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	const IRON := Color("393d3b")
	Plants.rod(s, Vector3(0, -0.065, 0), Vector3(0, 0.02, 0), 0.20, IRON, 12)
	Plants.rod(s, Vector3(0, 0.02, 0), Vector3(0, 0.20, 0), 0.055, IRON, 8)
	# Open basket with a closed bowl/fuel base, not a solid green globe.
	for index in 16:
		var a := TAU * float(index) / 16.0
		var b := TAU * float(index + 1) / 16.0
		var low_a := Vector3(cos(a)*0.10, 0.17, sin(a)*0.10)
		var low_b := Vector3(cos(b)*0.10, 0.17, sin(b)*0.10)
		var top_a := Vector3(cos(a)*0.245, 0.31, sin(a)*0.245)
		var top_b := Vector3(cos(b)*0.245, 0.31, sin(b)*0.245)
		Bot._tri(s, low_a, low_b, top_b, IRON)
		Bot._tri(s, low_a, top_b, top_a, IRON)
		Bot._tri(s, Vector3(0, 0.295, 0), top_a, top_b, Color("382c25"))
		Plants.rod(s, top_a, top_b, 0.018, IRON, 5)
		if index % 2 == 0:
			Plants.rod(s, top_a, top_a + Vector3.UP * 0.11, 0.012, IRON)
	for index in 3:
		var a := float(index) * TAU / 3.0
		var v := Vector3(cos(a), 0, sin(a)) * 0.15
		Plants.rod(s, -v + Vector3.UP * 0.305, v + Vector3.UP * 0.33, 0.028, Color("493126"), 7)
	s.generate_normals()
	var basket := MeshInstance3D.new()
	basket.name = "ForgedIronBasketAndFuel"
	basket.mesh = s.commit()
	var iron := StandardMaterial3D.new()
	iron.vertex_color_use_as_albedo = true
	iron.vertex_color_is_srgb = true
	iron.cull_mode = BaseMaterial3D.CULL_DISABLED
	iron.roughness = 0.86
	basket.material_override = iron
	add_child(basket)
	var fire := SurfaceTool.new()
	fire.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lobe in 5:
		var angle := TAU * float(lobe) / 5.0
		var p := Vector3.ZERO if lobe == 0 else Vector3(cos(angle), 0, sin(angle)) * 0.10
		var h := 0.53 if lobe == 0 else 0.30 + float(lobe % 3) * 0.065
		for row in 7:
			var ta := float(row) / 7.0
			var tb := float(row+1) / 7.0
			for side in 9:
				var a := TAU * float(side) / 9.0
				var b := TAU * float(side+1) / 9.0
				for data: Vector2 in [Vector2(a,ta),Vector2(b,ta),Vector2(b,tb),Vector2(a,ta),Vector2(b,tb),Vector2(a,tb)]:
					var radius := (0.077 if lobe == 0 else 0.043) * pow(1.0-data.y, 0.8) * (0.85+0.28*sin(data.y*PI))
					fire.set_uv(Vector2(float(lobe),data.y))
					fire.add_vertex(p+Vector3(cos(data.x)*radius, 0.315+data.y*h, sin(data.x)*radius))
	fire.generate_normals()
	var flame := MeshInstance3D.new()
	flame.name = "LiveFlames"
	flame.mesh = fire.commit()
	flame.extra_cull_margin = 0.12
	_flame = ShaderMaterial.new()
	_flame.shader = FlameShader
	_flame.set_shader_parameter("phase", _phase)
	flame.material_override = _flame
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)
	_light = OmniLight3D.new()
	_light.name = "WarmFireLight"
	_light.position.y = 0.52
	_light.light_color = Color("ffbb6c")
	_light.omni_range = 2.0
	_light.shadow_enabled = false
	add_child(_light)

func _process(delta: float) -> void:
	if _flame == null:
		return
	_clock += delta
	_flame.set_shader_parameter("flame_time", _clock)
	_light.light_energy = 0.65 + 0.08*sin(_clock*7.3+_phase) + 0.04*sin(_clock*11.9+_phase)
