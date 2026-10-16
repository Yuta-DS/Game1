extends Node3D
## Art-directed breaking surf outside the navigable harbour approach.
# Three staggered offshore rows on either side of the open sailing channel.
# The larger footprints need real spacing, not just farther-apart centers.
const OFFSETS := [Vector2(-135,70), Vector2(-175,165), Vector2(-130,260), Vector2(140,75), Vector2(185,170), Vector2(155,265)]
const WIDTHS := [8.0,11.0,7.0,10.0,13.0,9.0]
const WIDTH_MULTIPLIER := 10.0
const HEIGHT_MULTIPLIER := 3.0
# Keep the barrel cross-section round as its height grows.
const DEPTH_MULTIPLIER := HEIGHT_MULTIPLIER
# Six independently jittered starts per ten-second block. Recycle the same
# six meshes only after their outgoing crests and foam have faded away.
const SPAWN_WINDOW := 10.0
const SPAWN_SPACING := SPAWN_WINDOW / 6.0
const POSITION_JITTER := 10.0
var patches := PackedVector4Array()
var axes := PackedVector4Array()
var _ocean: Node3D
var _center := Vector2.ZERO
var _roots: Array[Node3D] = []
var _materials: Array[ShaderMaterial] = []
var _spray: Array[MultiMeshInstance3D] = []
var _spray_materials: Array[ShaderMaterial] = []
var _events: Array[Dictionary] = [{},{},{},{},{},{}]

func setup(ocean: Node3D, center: Vector2) -> void:
	_ocean = ocean
	_center = center
	if not _roots.is_empty():
		tick(_ocean.wave_time)
		return
	var source := (load("res://assets3D/curling_surf/curling_surf.glb") as PackedScene).instantiate()
	var source_mesh := source.find_child("CurlingSurfSheet", true, false) as MeshInstance3D
	assert(source_mesh != null, "Blender curling surf sheet is required")
	var droplets := MultiMesh.new()
	droplets.transform_format = MultiMesh.TRANSFORM_3D
	droplets.use_custom_data = true
	var foam_piece := SphereMesh.new()
	foam_piece.radius = 1.0
	foam_piece.height = 2.0
	foam_piece.radial_segments = 8
	foam_piece.rings = 4
	droplets.mesh = foam_piece
	droplets.instance_count = 96
	var rng := RandomNumberGenerator.new()
	rng.seed = 260828
	for i in droplets.instance_count:
		droplets.set_instance_transform(i, Transform3D.IDENTITY)
		droplets.set_instance_custom_data(i, Color(rng.randf(),rng.randf(),rng.randf(),rng.randf()))
	for i in OFFSETS.size():
		var patch := Node3D.new()
		patch.name = "Breaker_%02d" % i
		add_child(patch)
		var mesh := MeshInstance3D.new()
		mesh.name = "BlenderBarrel"
		mesh.mesh = source_mesh.mesh
		# The imported parametric grid has automatic LOD disabled: simplifying
		# its static extrusion loses the vertices needed for runtime peeling.
		mesh.extra_cull_margin = 5.0
		# Vertex displacement does not update the imported mesh bounds. Include
		# the complete 10x width (plus spawn variation) and 3x crest/spray height.
		var maximum_width: float = WIDTHS[i]*WIDTH_MULTIPLIER*1.15
		var displaced_bounds := AABB(Vector3(-maximum_width*.5-1,-1,-16),Vector3(maximum_width+2,8,32))
		mesh.custom_aabb = displaced_bounds
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/curling_surf.gdshader")
		material.render_priority = 1
		mesh.material_override = material
		patch.add_child(mesh)
		var spray := MultiMeshInstance3D.new()
		spray.name = "LipSpray"
		spray.multimesh = droplets
		spray.custom_aabb = displaced_bounds
		spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spray.visibility_range_end = 85.0+maximum_width*.5
		spray.visibility_range_end_margin = 10.0
		var spray_material := ShaderMaterial.new()
		spray_material.shader = load("res://shaders/surf_spray.gdshader")
		spray_material.render_priority = 2
		spray.material_override = spray_material
		patch.add_child(spray)
		_roots.append(patch)
		_materials.append(material)
		_spray.append(spray)
		_spray_materials.append(spray_material)
	source.free()
	tick(_ocean.wave_time)

func _event_noise(i: int, cycle: int, salt: float) -> float:
	return fposmod(sin(float(cycle)*127.1+float(i)*311.7+float(_ocean.wave_seed)*.017+salt)*43758.5453,1.0)

func spawn_time(i: int, cycle: int) -> float:
	# A bounded random offset leaves at least 0.5s between adjacent starts,
	# including across block boundaries, instead of spawning a six-wave burst.
	return float(cycle)*SPAWN_WINDOW + (float(i)+.15+.70*_event_noise(i,cycle,8.3))*SPAWN_SPACING

func _event_at(i: int, t: float) -> Dictionary:
	var cycle := floori(t/SPAWN_WINDOW)
	if t < spawn_time(i,cycle):
		cycle -= 1
	var event := _events[i]
	if event.is_empty() or event.cycle != cycle or event.seed != _ocean.wave_seed:
		var start := spawn_time(i,cycle)
		var jitter := Vector2(_event_noise(i,cycle,19.7),_event_noise(i,cycle,43.1))*2.0-Vector2.ONE
		event = {"cycle":cycle,"seed":_ocean.wave_seed,"start":start,
			"duration":spawn_time(i,cycle+1)-start,
			"offset":OFFSETS[i]+jitter*POSITION_JITTER,
			"width":WIDTHS[i]*WIDTH_MULTIPLIER*lerpf(.85,1.15,_event_noise(i,cycle,65.3)),
			"steering":(_event_noise(i,cycle,93.7)*2.0-1.0)*deg_to_rad(3.0)}
		_events[i] = event
	return event

func sample_patch(i: int, t: float) -> Dictionary:
	var event := _event_at(i,t)
	var age: float = (t-event.start)/event.duration
	var wind: Vector3 = _ocean.sample_wind(t)
	# Godot's +Z-forward yaw uses atan2(X,Z), unlike the ocean's atan2(Z,X).
	var angle: float = atan2(wind.x,wind.y) + event.steering
	var forward := Vector2(sin(angle), cos(angle))
	var center: Vector2 = _center + event.offset + forward * (age - .5) * 5.0
	var envelope := smoothstep(0.0,.16,age) * (1.0 - smoothstep(.86,1.0,age))
	return {"center":center, "angle":angle, "width":event.width, "age":age,
		"cycle":event.cycle,"start":event.start,"duration":event.duration,
		"envelope":envelope if _ocean.max_crest_height > 0.0 else 0.0,
		"height":_ocean.sample_crest_limit(center,t).x*HEIGHT_MULTIPLIER, "wind_strength":wind.z}

func tick(t: float) -> void:
	patches.clear()
	axes.clear()
	for i in _roots.size():
		var state := sample_patch(i,t)
		var p: Vector2 = state.center
		_roots[i].global_position = Vector3(p.x, _ocean.get_node("MeshInstance3D").global_position.y, p.y)
		_roots[i].global_rotation.y = state.angle
		_roots[i].visible = state.envelope > .001
		for material in [_materials[i], _spray_materials[i]]:
			material.set_shader_parameter("wave_width", state.width)
			material.set_shader_parameter("wave_height", state.height)
			material.set_shader_parameter("wave_depth_scale", DEPTH_MULTIPLIER)
			material.set_shader_parameter("wave_age", state.age)
			material.set_shader_parameter("wave_period", state.duration)
			material.set_shader_parameter("sea_time", t)
			material.set_shader_parameter("wind_strength", state.wind_strength)
		_spray[i].visible = state.envelope > .1 and state.age > .15 and state.age < .96
		patches.append(Vector4(p.x,p.y,state.width * .5,2.5*DEPTH_MULTIPLIER))
		axes.append(Vector4(cos(state.angle),sin(state.angle),state.envelope,state.age))

func damp_wave(point: Vector2, t: float, wave: Vector4) -> Vector4:
	for i in OFFSETS.size():
		var s := sample_patch(i,t)
		var right := Vector2(cos(s.angle),-sin(s.angle))
		var forward := Vector2(sin(s.angle),cos(s.angle))
		var offset: Vector2 = point - s.center
		var local := Vector2(offset.dot(right),offset.dot(forward))
		var u := Vector2(clampf((absf(local.x)-s.width*.5)/3.0,0,1),clampf((absf(local.y)-2.5*DEPTH_MULTIPLIER)/3.0,0,1))
		var m := Vector2(1-u.x*u.x*(3-2*u.x),1-u.y*u.y*(3-2*u.y))
		var weight: float = m.x*m.y*s.envelope
		var gradient := (right * (-2*u.x*(1-u.x)*signf(local.x)*m.y) \
			+ forward * (-2*u.y*(1-u.y)*signf(local.y)*m.x)) * float(s.envelope)
		var gain := 1.0 - .97 * weight
		wave.y = wave.y * gain - wave.x * .97 * gradient.x
		wave.z = wave.z * gain - wave.x * .97 * gradient.y
		wave.x *= gain
		wave.w *= gain
	return wave
