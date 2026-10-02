extends Node3D

## Camera-local environment with reversible sun/fill balance. The shared
## WorldEnvironment resource is never edited; leaving restores both lights.
const SAMPLE_SECONDS := 0.1
const ZONE_RADII := [125.0, 155.0, 150.0, 122.0, 175.0, 145.0]
const WORLD_ONE_SKY_TOP := Color("467aa7")
const WORLD_ONE_SKY_HORIZON := Color("ead9c2")
const WORLD_ONE_GROUND_HORIZON := Color("cfc4b4")
const WORLD_ONE_FOG_LIGHT := Color("aec5cc")

var _camera: Camera3D
var _previous: Environment
var _source: Environment
var _profile: Environment
var _sky_material: ProceduralSkyMaterial
var _original_sky: ProceduralSkyMaterial
var _strength := 0.0
var _directional_lights: Dictionary = {}
var _world: MindSparkWorldOne
var _control_positions := PackedVector3Array()
var _station_positions := PackedVector3Array()
var _zone_centres := PackedVector3Array()
var _sample_elapsed := SAMPLE_SECONDS
var _target_strength := 0.0


func _ready() -> void:
	set_meta("atmosphere_revision", "warm_celestial_depth_v2")
	set_meta("sky_top_color", WORLD_ONE_SKY_TOP)
	set_meta("sky_horizon_color", WORLD_ONE_SKY_HORIZON)
	set_meta("fog_light_color", WORLD_ONE_FOG_LIGHT)
	call_deferred("_cache_scene_positions")


func _cache_scene_positions() -> void:
	var ancestor := get_parent()
	while ancestor != null and not ancestor is MindSparkWorldOne:
		ancestor = ancestor.get_parent()
	_world = ancestor as MindSparkWorldOne
	if _world == null:
		return
	_control_positions.clear()
	var controls := get_parent().get_node_or_null("PuzzleControls")
	if controls != null:
		for control in controls.get_children():
			if control is Node3D:
				_control_positions.append(_world.to_local((control as Node3D).global_position))
	_station_positions.clear()
	for station in _world.get_quest_objects():
		_station_positions.append(_world.to_local(station.global_position))
	_zone_centres.clear()
	for zone_info in MindSparkWorldOne.ZONES:
		_zone_centres.append(_world.get_zone_position(str(zone_info.id)))
	set_meta("cached_profile_control_count", _control_positions.size())
	set_meta("cached_profile_station_count", _station_positions.size())
	set_meta("profile_sample_seconds", SAMPLE_SECONDS)


func _sample_target(camera: Camera3D) -> float:
	if _world == null:
		_cache_scene_positions()
	if _world == null:
		return 0.0
	var view_position := _world.to_local(camera.global_position)
	var distance := INF
	for control_position in _control_positions:
		distance = minf(distance, view_position.distance_to(control_position))
	var target := 1.0 - smoothstep(30.0, 90.0, distance)
	for station_position in _station_positions:
		target = maxf(target, 1.0 - smoothstep(34.0, 54.0,
			view_position.distance_to(station_position)))
	var direction: Vector3 = _world.global_transform.basis.inverse() * -camera.global_basis.z
	for index in _zone_centres.size():
		var centre := _zone_centres[index]
		var projected_view := view_position
		if direction.y < -0.05:
			var projection_time := (centre.y - projected_view.y) / direction.y
			if projection_time > 0.0:
				projected_view += direction * projection_time
		var edge_distance: float = Vector2(projected_view.x - centre.x,
			projected_view.z - centre.z).length() - float(ZONE_RADII[index])
		target = maxf(target, 1.0 - smoothstep(0.0, 45.0, edge_distance))
	return target

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != _camera:
		_restore()
		_camera = camera
		_sample_elapsed = SAMPLE_SECONDS
	if camera == null:
		return
	_sample_elapsed += delta
	if _sample_elapsed >= SAMPLE_SECONDS:
		_sample_elapsed = fmod(_sample_elapsed, SAMPLE_SECONDS)
		_target_strength = _sample_target(camera)
	var target := _target_strength
	if target <= 0.0 and _profile == null:
		return
	if _profile == null:
		_previous = camera.environment
		_source = _previous if _previous != null else camera.get_world_3d().environment
		if _source == null:
			return
		_profile = _source.duplicate() as Environment
		if _source.sky != null and _source.sky.sky_material is ProceduralSkyMaterial:
			_profile.sky = _source.sky.duplicate() as Sky
			_original_sky = _source.sky.sky_material as ProceduralSkyMaterial
			_sky_material = _original_sky.duplicate() as ProceduralSkyMaterial
			_profile.sky.sky_material = _sky_material
		camera.environment = _profile
		for name in ["Sun","FillLight"]:
			var light := get_tree().root.find_child(name,true,false) as DirectionalLight3D
			if light != null:
				_directional_lights[light] = [light.light_energy,light.light_color]
	var previous_strength := _strength
	_strength = move_toward(_strength, target, delta * 1.5)
	if is_equal_approx(previous_strength, _strength):
		return
	_profile.ambient_light_color = _source.ambient_light_color.lerp(Color("f0dfc8"), _strength)
	var compatibility := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	_profile.ambient_light_energy = lerpf(_source.ambient_light_energy, .24 if compatibility else .40, _strength)
	_profile.ambient_light_sky_contribution = lerpf(_source.ambient_light_sky_contribution, 0.0, _strength)
	_profile.tonemap_exposure = lerpf(_source.tonemap_exposure, .70, _strength)
	for light in _directional_lights:
		if is_instance_valid(light):
			var original: Array = _directional_lights[light]
			var daylight := .42 if compatibility else .68
			light.light_energy = lerpf(float(original[0]),daylight if light.name == "Sun" else .12,_strength)
			light.light_color = (original[1] as Color).lerp(Color("ffe8cd") if light.name == "Sun" else Color("d9dfeb"),_strength)
	_profile.fog_light_color = _source.fog_light_color.lerp(WORLD_ONE_FOG_LIGHT, _strength)
	if _sky_material != null:
		_sky_material.sky_top_color = _original_sky.sky_top_color.lerp(WORLD_ONE_SKY_TOP, _strength)
		_sky_material.sky_horizon_color = _original_sky.sky_horizon_color.lerp(WORLD_ONE_SKY_HORIZON, _strength)
		_sky_material.ground_horizon_color = _original_sky.ground_horizon_color.lerp(WORLD_ONE_GROUND_HORIZON, _strength)
	if target == 0.0 and _strength == 0.0:
		_restore()

func _restore() -> void:
	for light in _directional_lights:
		if is_instance_valid(light):
			light.light_energy = _directional_lights[light][0]
			light.light_color = _directional_lights[light][1]
	_directional_lights.clear()
	if is_instance_valid(_camera) and _camera.environment == _profile and _profile != null:
		_camera.environment = _previous
	_profile = null
	_previous = null
	_source = null
	_sky_material = null
	_original_sky = null
	_strength = 0.0
	_target_strength = 0.0

func _exit_tree() -> void:
	_restore()
