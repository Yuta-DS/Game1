extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("STYLIZED_OCEAN: " + message)

func _run() -> void:
	var ocean := (load("res://scripts/Water.tscn") as PackedScene).instantiate()
	root.add_child(ocean)
	ocean.set_process(false)
	ocean.configure_harbour(Vector2(38,188.5),20.0)
	_check(is_equal_approx(ocean.sample_depth(Vector2(38,200)).x,.75),"port stays in shallow wave-depth zone")
	_check(is_equal_approx(ocean.sample_depth(Vector2(38,390)).x,12.0),"offshore wave-depth zone reaches twelve metres")
	var deep_min := INF
	var deep_max := 0.0
	for t in range(0,301,3):
		var previous_cap := 0.0
		for z in range(200,401,5):
			var cap: Vector3 = ocean.sample_crest_limit(Vector2(38,z),float(t))
			_check(cap.x >= .5 and cap.x <= 1.5,"crest target stays between 0.5 and 1.5m")
			_check(cap.x >= previous_cap,"deeper zones never have a smaller crest target at the same wind")
			previous_cap = cap.x
			var finite_difference: float = (ocean.sample_crest_limit(Vector2(38,z+.01),float(t)).x-ocean.sample_crest_limit(Vector2(38,z-.01),float(t)).x)/.02
			_check(absf(finite_difference-cap.z)<.0001,"height limit has correct spatial derivative")
		deep_min = minf(deep_min,previous_cap)
		deep_max = maxf(deep_max,previous_cap)
	_check(deep_max>1.45 and deep_max-deep_min>.5,"deep waves have varied heights, including strong 1.5m gusts")
	for z in [213.49,213.5,213.51,260.0,300.0,363.49,363.5,363.51]:
		var p := Vector2(40,z)
		var sample: Vector4 = ocean.sample_wave(p,69.0)
		var dz: float = (ocean.sample_wave(p+Vector2(0,.01),69.0).x-ocean.sample_wave(p-Vector2(0,.01),69.0).x)/.02
		_check(absf(dz-sample.z)<.003,"buoyancy slopes remain continuous across depth-zone boundaries")
	for path in ["res://Water.gdshader","res://shaders/web_water.gdshader","res://shaders/curling_surf.gdshader"]:
		var code := FileAccess.get_file_as_string(path)
		_check(code.contains("ocean_style.gdshaderinc"),"all wave types use the same art palette")
		_check(code.contains("ocean_reference_water(") and code.contains("ocean_flow_gradient("),"rolling waves and curls use the same detailed reference shading")
		_check(not code.contains("unshaded") and code.contains("NORMAL =") and code.contains("SPECULAR = .18"),"all waves retain matching lit surface response")
		if not path.ends_with("curling_surf.gdshader"):
			var fragment := code.substr(code.find("void fragment()"))
			_check(not fragment.contains("sea_wave_field("),"full ocean field is not evaluated per pixel")
			_check(fragment.contains("sea_reference_foam(") and fragment.contains("smoothstep(70.0,150.0"),"ocean foam uses the reference detail with distance limiting")
	var surface_code := FileAccess.get_file_as_string("res://shaders/ocean_surface.gdshaderinc")
	_check(surface_code.contains("ocean_foam_samples(") and surface_code.contains("ocean_foam_coverage("),"background whitecaps and curling lips share the same foam pattern")
	# Readability guards complement the graphical Web capture: broken foam
	# must remain distinct from the blue wall, without more mesh/spray.
	var curl_code := FileAccess.get_file_as_string("res://shaders/curling_surf.gdshader")
	_check(curl_code.contains(".30+.70*foam_patches") and curl_code.contains("smoothstep(.04,.18,face_height)"),"broken crest survives detail filtering but fades at the waterline")
	_check(curl_code.contains("water *= 1.0-hollow*.28") and curl_code.contains("ocean_reference_whitewater(pores)"),"blue hollow and shared whitewater remain separate")
	_check(surface_code.contains("float coverage = sea_breaker_foam(p)") and not surface_code.contains("crest_signal"),"all visible whitecaps belong to the approved 3D curl, not a competing flat wave pattern")
	var geometry_code := FileAccess.get_file_as_string("res://shaders/surf_geometry.gdshaderinc")
	_check(geometry_code.contains("smoothstep(.10,.34,peel)") and geometry_code.contains("smoothstep(.66,.90,peel)"),"curl forms early and holds its silhouette before collapsing")
	_check(geometry_code.contains("surf_profile_peel(u,age,wave_width)") and surface_code.contains("surf_profile_peel(u,a.w,patch.z*2.0)"),"shell, spray and wash share event-specific peeling")
	_check(geometry_code.contains("surf_profile_bend(u,wave_width)") and surface_code.contains("surf_profile_bend(u,patch.z*2.0)"),"wash follows the wandering crest")
	_check(geometry_code.contains("u*8.0+phase") and not geometry_code.contains("u*wave_width*1.2"),"vertex noise remains resolved by the fixed mesh at tenfold width")
	var scene := FileAccess.get_file_as_string("res://scripts/Water.tscn")
	_check(not scene.contains("NoiseTexture2D"),"unused 2000px noise generation is removed from scene startup")
	if failures == 0:
		print("STYLIZED_OCEAN: PASS — shared palette, base depth-zone limits, varied gusts, smooth buoyancy, shader/startup cost guards")
	quit(failures)
