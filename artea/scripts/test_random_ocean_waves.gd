extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("RANDOM_OCEAN_WAVES: " + message)
		quit(1)
	return condition

func _run() -> void:
	var ocean := (load("res://scripts/Water.tscn") as PackedScene).instantiate()
	root.add_child(ocean)
	ocean.set_process(false)
	ocean.configure_harbour(Vector2(38, 188.5), 20.0)
	# Sharper than a single sine/cosine wave, but smooth at the tip and wrap.
	if not _check(ocean._seismic_profile(0.0).is_equal_approx(Vector2(1.0, 0.0)) \
			and ocean._seismic_profile(.6).x < cos(.6) - .15, "seismic profile has a pronounced, smooth narrow crest"):
		return
	for phase in [-PI, -.6, 0.0, .6, PI, TAU]:
		var profile: Vector2 = ocean._seismic_profile(phase)
		var derivative: float = (ocean._seismic_profile(phase + .002).x - ocean._seismic_profile(phase - .002).x) / .004
		if not _check(absf(profile.y - derivative) < .0001, "seismic profile slopes match the new shape"):
			return
	if not _check(ocean._seismic_packet(-PI / 2.0).x < .061 and ocean._seismic_packet(PI / 2.0).x > .999, "seismic pulse groups have quiet gaps between strong bursts"):
		return
	var shapes: PackedVector4Array = ocean.wave_shape.duplicate()
	var motions: PackedVector4Array = ocean.wave_motion.duplicate()
	if not _check(shapes.size() == 9 and motions.size() == 9, "three components per small/medium/large band"):
		return
	var ranges := [Vector2(6, 10), Vector2(14, 26), Vector2(38, 70)]
	for i in 9:
		var wavelength := TAU / Vector2(shapes[i].x, shapes[i].y).length()
		if not _check(wavelength >= ranges[i / 3].x - .01 and wavelength <= ranges[i / 3].y + .01, "distinct wave lengths"):
			return
		if i >= 3 and not _check(shapes[i].z > shapes[i - 3].z, "larger bands have greater height"):
			return
	ocean._generate_waves()
	if not _check(ocean.wave_shape == shapes, "same seed reproduces the authored ocean"):
		return
	ocean.wave_seed += 1
	ocean._generate_waves()
	if not _check(ocean.wave_shape != shapes, "seed changes wave direction/spacing/phase"):
		return
	ocean.wave_seed -= 1
	ocean._generate_waves()
	var low := INF
	var high := -INF
	var sheltered_peak := 0.0
	var temporal_change := 0.0
	var weakest_wind := INF
	var strongest_wind := 0.0
	var strongest_time := 0.0
	var first_direction := Vector2(ocean.sample_wind(0).x, ocean.sample_wind(0).y)
	var direction_change := 0.0
	for t in range(0, 301, 3):
		var wind: Vector3 = ocean.sample_wind(float(t))
		weakest_wind = minf(weakest_wind, wind.z)
		if wind.z > strongest_wind:
			strongest_wind = wind.z
			strongest_time = float(t)
		direction_change = maxf(direction_change, first_direction.distance_to(Vector2(wind.x, wind.y)))
		for x in range(-140, 161, 20):
			for z in range(240, 421, 20):
				var p := Vector2(x, z)
				var sample: Vector4 = ocean.sample_wave(p, float(t))
				if not _check(sample.is_finite(), "finite continuous wave field"):
					return
				low = minf(low, sample.x)
				high = maxf(high, sample.x)
				temporal_change = maxf(temporal_change, absf(sample.x - ocean.sample_wave(p, float(t) + 2).x))
		for x in range(26, 51, 6):
			for z in range(177, 201, 6):
				sheltered_peak = maxf(sheltered_peak, absf(ocean.sample_wave(Vector2(x,z), float(t)).x))
	if not _check(high - low > .09 and temporal_change > .03, "quiet carrier water still moves with irregular peaks"):
		return
	if not _check(high > .15 and high <= .18 and low >= -.081 and sheltered_peak < .01, "carrier stays below 18cm; only the separately scaled 3D curls create prominent breaking waves"):
		return
	if not _check(weakest_wind < .25 and strongest_wind > .80 and direction_change > .03 and direction_change < .35, "wind has random lulls and gusts with gentle directional sway"):
		return
	for t in [17.0, 29.0, 34.0, 58.0, 85.0, 116.0]:
		if not _check(ocean.sample_wind(t - .001).distance_to(ocean.sample_wind(t + .001)) < .001, "wind changes smoothly across randomized target boundaries"):
			return
		var before: Vector4 = ocean.sample_wave(Vector2(40, 280), t - .001)
		var after: Vector4 = ocean.sample_wave(Vector2(40, 280), t + .001)
		if not _check(absf(before.x - after.x) < .003, "changing wind does not snap the sea surface"):
			return
	# Cap remains valid for other random patterns and a zero-height calm setting.
	var original_seed: int = ocean.wave_seed
	for seed_value in [1, 73, 90210]:
		ocean.wave_seed = seed_value
		ocean._generate_waves()
		if not _check_wind_alignment(ocean):
			return
		for t in range(0, 301, 11):
			for point in [Vector2(-140,310), Vector2(40,280), Vector2(180,420)]:
				var sample: Vector4 = ocean.sample_wave(point, float(t))
				var cap: Vector3 = ocean.sample_crest_limit(point,float(t))
				if not _check(sample.x >= -cap.x*.45-.00001 and sample.x <= cap.x+.00001, "local depth cap is independent of seed"):
					return
	ocean.wave_seed = original_seed
	ocean._generate_waves()
	ocean.max_crest_height = 0.0
	if not _check(ocean.sample_wave(Vector2(40,280), 6.0) == Vector4.ZERO, "0m produces calm, level water"):
		return
	ocean.max_crest_height = 1.5
	# Analytic lighting slopes must describe the same surface as buoyancy.
	for p in [Vector2(45,190), Vector2(70,200), Vector2(90,205), Vector2(40,280)]:
		var sample: Vector4 = ocean.sample_wave(p, 7.3)
		var dx: float = (ocean.sample_wave(p + Vector2(.01,0), 7.3).x - ocean.sample_wave(p - Vector2(.01,0), 7.3).x) / .02
		var dz: float = (ocean.sample_wave(p + Vector2(0,.01), 7.3).x - ocean.sample_wave(p - Vector2(0,.01), 7.3).x) / .02
		if not _check(absf(dx - sample.y) < .002 and absf(dz - sample.z) < .002, "correct normals including harbour damping"):
			return
	var mesh := ocean.get_node("MeshInstance3D") as MeshInstance3D
	if not _check(mesh.mesh is ArrayMesh, "runtime ocean uses the coast-focused continuous mesh"):
		return
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if not _check(vertices.size() == 385 * 385 and indices.size() / 3 < 296450, "sharper crests retain the old uniform grid's triangle budget"):
		return
	var xs: PackedFloat32Array = ocean._mesh_axis(38.0)
	for i in xs.size() - 1:
		if not _check(xs[i + 1] > xs[i], "mesh density transitions have no folded or duplicate edges"):
			return
		if i >= 32 and i < 352 and not _check(absf(xs[i + 1] - xs[i] - .8) < .0001, "seismic coastal crests have 0.8m vertex spacing"):
			return
	if not _check(xs[0] == -500.0 and xs[-1] == 500.0, "ocean retains its full extent"):
		return
	# Sample the actual triangles: rendered displacement stays close to boat height.
	var zs: PackedFloat32Array = ocean._mesh_axis(248.5)
	var mesh_error := 0.0
	for z in range(100, 280, 7):
		for x in range(70, 270, 7):
			var a := Vector2(xs[x], zs[z])
			var b := Vector2(xs[x + 1], zs[z])
			var c := Vector2(xs[x], zs[z + 1])
			var interpolated: float = (ocean.sample_wave(a, 6.0).x + ocean.sample_wave(b, 6.0).x + ocean.sample_wave(c, 6.0).x) / 3.0
			mesh_error = maxf(mesh_error, absf(interpolated - ocean.sample_wave((a + b + c) / 3.0, 6.0).x))
	if not _check(mesh_error < .025, "visible mesh and buoyancy agree to within 2.5cm near the coast (error %.3fm)" % mesh_error):
		return
	var web := ShaderMaterial.new()
	web.shader = load("res://shaders/web_water.gdshader")
	mesh.material_override = web
	ocean.wave_time = 12.0
	ocean._process(0.0)
	if not _check(web.get_shader_parameter("wave_shape") == shapes and web.get_shader_parameter("wave_motion") == motions \
			and web.get_shader_parameter("sea_time") == 12.0 and web.get_shader_parameter("harbour_clear_radius") == 20.0 \
			and web.get_shader_parameter("wind_state").is_equal_approx(ocean.sample_wind(12.0)) \
			and is_equal_approx(web.get_shader_parameter("carrier_swell_gain"),ocean.CARRIER_SWELL_GAIN) \
			and web.get_shader_parameter("max_crest_height") == 1.5, "Web replacement retains the same wind, height cap, waves, clock and sheltered harbour"):
		return
	print("RANDOM_OCEAN_WAVES: PASS — 3 quiet carrier bands, height %.2f..%.2fm, sheltered peak %.2fm, mesh error %.3fm, analytic slopes and Web parity" % [low, high, sheltered_peak, mesh_error])
	print("WIND_PATTERN: strength %.2f..%.2f; strongest gust at %.0fs; direction travel %.2f" % [weakest_wind, strongest_wind, strongest_time, direction_change])
	quit()

func _check_wind_alignment(ocean: Node3D) -> bool:
	var shoreward := Vector2(0,-1)
	for shape in ocean.wave_shape:
		var direction := Vector2(shape.x,shape.y).normalized()
		if not _check(direction.dot(shoreward) >= cos(deg_to_rad(12.0))-.00001 and shape.w > 0.0, "all wave sizes travel shoreward within twelve degrees"):
			return false
	for t in range(0,3601,3):
		var wind: Vector3 = ocean.sample_wind(float(t))
		var direction := Vector2(wind.x,wind.y)
		if not _check(is_equal_approx(direction.length(),1.0) and direction.dot(shoreward) >= cos(deg_to_rad(10.0))-.00001, "random wind stays within ten degrees of the prevailing heading for one hour"):
			return false
		for shape in ocean.wave_shape:
			if not _check(direction.dot(Vector2(shape.x,shape.y).normalized()) >= cos(deg_to_rad(22.0))-.00001, "gusts never oppose the swell direction"):
				return false
	return true
