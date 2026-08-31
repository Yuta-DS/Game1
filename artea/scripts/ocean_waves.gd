extends Node3D
## Seeded, smoothly varying wave groups shared by both renderers and the boat.

# Travel toward shore (-Z), with a narrow fan of wind-driven wave headings.
const PREVAILING_WIND_ANGLE := -PI * .5
const MAX_WIND_SWAY := PI / 18.0 # +/-10 degrees
const WAVE_DIRECTION_SPREAD := PI / 15.0 # +/-12 degrees
# The six Blender curls own the visible breaking waves (scaled separately). The old
# carrier field is now just quiet moving water between those same-style curls.
const CARRIER_SWELL_GAIN := 0.12

@export var wave_seed: int = 260828
@export var small_wave_height: float = 0.085
@export var medium_wave_height: float = 0.29
@export var large_wave_height: float = 0.64
## Crest rise above the normal water level; troughs remain below that level.
@export_range(0.0, 1.5, 0.01) var max_crest_height: float = 1.5

var wave_time := 0.0
var wave_shape := PackedVector4Array()
var wave_motion := PackedVector4Array()
var harbour_center := Vector2.ZERO
var harbour_clear_radius := 0.0
var _surface: MeshInstance3D
var _material: ShaderMaterial
var _surf: Node3D

func _ready() -> void:
	_surface = get_node("MeshInstance3D") as MeshInstance3D
	_generate_waves()
	# Do not modify a shared scene material or another ocean instance.
	_surface.material_override = _surface.get_active_material(0).duplicate()
	_build_coastal_mesh(Vector2.ZERO)
	_bind_material()

func _mesh_axis(focus: float) -> PackedFloat32Array:
	# Spend vertices where the player sails; keep the original 1km ocean bounds.
	# Shared row/column vertices make the density transitions watertight.
	var center := clampf(focus, -350.0, 350.0)
	var points := PackedFloat32Array()
	for i in 32:
		points.append(lerpf(-500.0, center - 128.0, float(i) / 32.0))
	for i in 320:
		points.append(center - 128.0 + float(i) * .8)
	for i in 33:
		points.append(lerpf(center + 128.0, 500.0, float(i) / 32.0))
	return points

func _build_coastal_mesh(focus: Vector2) -> void:
	var xs := _mesh_axis(focus.x)
	var zs := _mesh_axis(focus.y)
	var width := xs.size()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.resize(width * zs.size())
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	for z in zs.size():
		for x in width:
			vertices[z * width + x] = Vector3(xs[x], 0.0, zs[z])
	indices.resize((width - 1) * (zs.size() - 1) * 6)
	var cursor := 0
	for z in zs.size() - 1:
		for x in width - 1:
			var a := z * width + x
			for index in [a, a + 1, a + width, a + 1, a + width + 1, a + width]:
				indices[cursor] = index
				cursor += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_surface.mesh = mesh

func _generate_waves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = wave_seed
	wave_shape.clear()
	wave_motion.clear()
	var wavelengths := [Vector2(6.0, 10.0), Vector2(14.0, 26.0), Vector2(38.0, 70.0)]
	var heights := [small_wave_height, medium_wave_height, large_wave_height]
	for band in 3:
		for component in 3:
			var angle := PREVAILING_WIND_ANGLE + rng.randf_range(-WAVE_DIRECTION_SPREAD, WAVE_DIRECTION_SPREAD)
			var wavelength := rng.randf_range(wavelengths[band].x, wavelengths[band].y)
			var frequency := TAU / wavelength
			var amplitude: float = heights[band] * rng.randf_range(0.55, 1.0)
			var speed := sqrt(9.81 * frequency) * rng.randf_range(0.52, 0.76)
			wave_shape.append(Vector4(cos(angle) * frequency, sin(angle) * frequency, amplitude, speed))
			wave_motion.append(Vector4(rng.randf_range(0, TAU), rng.randf_range(0.13, 0.31),
				rng.randf_range(-0.14, 0.14), rng.randf_range(0, TAU)))

func _bind_material() -> void:
	var current := _surface.get_active_material(0) as ShaderMaterial
	if current == null or current == _material:
		return
	_material = current
	_material.set_shader_parameter("wave_shape", wave_shape)
	_material.set_shader_parameter("wave_motion", wave_motion)
	_material.set_shader_parameter("harbour_center", harbour_center)
	_material.set_shader_parameter("harbour_clear_radius", harbour_clear_radius)
	_material.set_shader_parameter("sea_time", wave_time)
	_material.set_shader_parameter("wind_state", sample_wind(wave_time))
	_material.set_shader_parameter("max_crest_height", max_crest_height)
	_material.set_shader_parameter("carrier_swell_gain", CARRIER_SWELL_GAIN)
	_bind_surf_uniforms()

func _bind_surf_uniforms() -> void:
	if _surf != null and _material != null:
		_material.set_shader_parameter("surf_patches", _surf.patches)
		_material.set_shader_parameter("surf_axes", _surf.axes)

func configure_harbour(center: Vector2, radius: float) -> void:
	var moved := not center.is_equal_approx(harbour_center)
	harbour_center = center
	harbour_clear_radius = radius
	if moved:
		var local_focus := _surface.to_local(Vector3(center.x, _surface.global_position.y, center.y + 60.0))
		_build_coastal_mesh(Vector2(local_focus.x, local_focus.z))
	if _surf == null:
		_surf = Node3D.new()
		_surf.name = "CurlingSurf"
		_surf.set_script(load("res://scripts/curling_surf.gd"))
		add_child(_surf)
	_surf.setup(self, center)
	_material = null
	_bind_material()

func _process(delta: float) -> void:
	wave_time += delta
	if _surf != null:
		_surf.tick(wave_time)
	# Web compatibility can replace the material after this node becomes ready.
	_bind_material()
	if _material != null:
		_material.set_shader_parameter("sea_time", wave_time)
		_material.set_shader_parameter("wind_state", sample_wind(wave_time))
		_material.set_shader_parameter("max_crest_height", max_crest_height)
		_bind_surf_uniforms()

func _wind_noise(t: float, salt: float) -> float:
	var cell := floorf(t)
	var blend := t - cell
	blend = blend * blend * (3.0 - 2.0 * blend)
	var a := fposmod(sin((cell + wave_seed * .017 + salt) * 127.1) * 43758.5453, 1.0)
	var b := fposmod(sin((cell + 1.0 + wave_seed * .017 + salt) * 127.1) * 43758.5453, 1.0)
	return lerpf(a, b, blend)

func sample_wind(t: float) -> Vector3:
	# Random lulls/gusts, but only gentle steering around one prevailing heading.
	# The carrier wave vectors stay fixed, avoiding rotation of the whole sea.
	var angle := PREVAILING_WIND_ANGLE + (_wind_noise(t / 29.0, 8.3) * 2.0 - 1.0) * MAX_WIND_SWAY
	var strength := .06 + .94 * _wind_noise(t / 17.0, 37.1)
	return Vector3(cos(angle), sin(angle), strength)

func sample_depth(point: Vector2) -> Vector3:
	# Authored wave-depth zones, not a terrain survey: the hub's offshore
	# terrain is a flat shelf. Keep land/collision untouched and deepen the
	# wave response smoothly from 0.75m at the harbour to 12m offshore.
	# Return depth and its X/Z derivatives; mirrored in ocean_waves.gdshaderinc.
	var u := clampf((point.y-harbour_center.y-25.0)/150.0,0.0,1.0)
	return Vector3(.75+11.25*u*u*(3.0-2.0*u),0.0,11.25*6.0*u*(1.0-u)/150.0)

func sample_crest_limit(point: Vector2, t: float) -> Vector3:
	var depth := sample_depth(point)
	var blend := (depth.x-.75)/11.25
	var gust := .25+.75*sample_wind(t).z
	var scale := clampf(max_crest_height,0.0,1.5)/1.5
	return Vector3((.5+blend*gust)*scale,depth.y*gust*scale/11.25,depth.z*gust*scale/11.25)

func _seismic_profile(phase: float) -> Vector2:
	# Art-directed pulse: a narrow crest with smaller oscillating shoulders.
	# Return height and its exact phase derivative for matching lighting/buoyancy.
	return Vector2((cos(phase) + .35 * cos(2.0 * phase) + .12 * cos(3.0 * phase)) / 1.47,
		-(sin(phase) + .70 * sin(2.0 * phase) + .36 * sin(3.0 * phase)) / 1.47)

func _seismic_packet(phase: float) -> Vector2:
	var pulse := .5 + .5 * sin(phase)
	return Vector2(.06 + .94 * pow(pulse, 4.0), 1.88 * pow(pulse, 3.0) * cos(phase))

func sample_wave(point: Vector2, at_time: float = -1.0) -> Vector4:
	var t := wave_time if at_time < 0.0 else at_time
	if max_crest_height <= 0.0:
		return Vector4.ZERO
	var wind := sample_wind(t)
	var wind_direction := Vector2(wind.x, wind.y)
	var gust_vector := wind_direction * .0278
	var gust_phase := point.dot(gust_vector) - t * .16
	var gust := .72 + .28 * sin(gust_phase)
	var gust_gradient := .28 * cos(gust_phase) * gust_vector
	var result := Vector4.ZERO
	for i in wave_shape.size():
		var w := wave_shape[i]
		var m := wave_motion[i]
		var alignment := .5 + .5 * Vector2(w.x, w.y).normalized().dot(wind_direction)
		var wind_gain := 4.0 * wind.z * (.35 + .65 * alignment * alignment)
		var packet_vector := Vector2(w.x, w.y) * .18 + Vector2(-w.y, w.x) * m.y * .5
		var packet := point.dot(packet_vector) + t * (-w.w * .21 + m.z * .22) + m.w
		var packet_shape := _seismic_packet(packet)
		var envelope := packet_shape.x
		var phase := point.dot(Vector2(w.x, w.y)) - t * w.w + m.x + 0.65 * sin(packet)
		var waveform := _seismic_profile(phase)
		var profile := waveform.x
		var phase_gradient := Vector2(w.x, w.y) + 0.65 * cos(packet) * packet_vector
		var envelope_gradient := packet_shape.y * packet_vector
		var slope := w.z * (envelope_gradient * profile + envelope * waveform.y * phase_gradient)
		var height := w.z * envelope * profile
		result.x += height * gust * wind_gain
		var wind_slope := (slope * gust + height * gust_gradient) * wind_gain
		result.y += wind_slope.x
		result.z += wind_slope.y
		if w.z >= .001:
			result.w = maxf(result.w, maxf(profile, 0.0) * envelope * (0.82 if i < 3 else 1.0) * minf(1.0, wind_gain * gust))
	# Smooth asymmetrical saturation prevents >1m crests or deep seabed holes.
	# Its analytic derivative keeps boat pitch and shader normals consistent.
	var cap := sample_crest_limit(point,t)
	var limit_scale := 1.0 if result.x >= 0.0 else .45
	var limit := cap.x * limit_scale
	var raw_height := result.x
	var e := exp(-2.0 * absf(result.x) / limit)
	var derivative := 4.0 * e / ((1.0 + e) * (1.0 + e))
	var saturation := signf(result.x) * (1.0 - e) / (1.0 + e)
	result.x = limit * saturation
	var limit_slope := saturation-derivative*raw_height/limit
	result.y = result.y*derivative + cap.y*limit_scale*limit_slope
	result.z = result.z*derivative + cap.z*limit_scale*limit_slope
	if harbour_clear_radius > 0.1:
		var offset := point - harbour_center
		var distance_to_port := offset.length()
		var span := harbour_clear_radius * 2.0
		var u := clampf((distance_to_port - harbour_clear_radius * 1.25) / span, 0.0, 1.0)
		var blend := u * u * (3.0 - 2.0 * u)
		var gain := lerpf(0.13, 1.0, blend)
		var gradient := 0.87 * 6.0 * u * (1.0 - u) / span * offset / maxf(distance_to_port, 0.001)
		result.y = result.y * gain + result.x * gradient.x
		result.z = result.z * gain + result.x * gradient.y
		result.x *= gain
		result.w *= lerpf(0.32, 1.0, blend)
	result *= CARRIER_SWELL_GAIN
	return _surf.damp_wave(point, t, result) if _surf != null else result

func get_water_height(point: Vector3) -> float:
	return _surface.global_position.y + sample_wave(Vector2(point.x, point.z)).x
