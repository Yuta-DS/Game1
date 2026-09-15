extends Node3D

## Camera-local environment with reversible sun/fill balance. The shared
## WorldEnvironment resource is never edited; leaving restores both lights.
var _camera: Camera3D
var _previous: Environment
var _source: Environment
var _profile: Environment
var _sky_material: ProceduralSkyMaterial
var _original_sky: ProceduralSkyMaterial
var _strength := 0.0
var _directional_lights: Dictionary = {}

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != _camera:
		_restore()
		_camera = camera
	if camera == null:
		return
	var controls := get_parent().get_node_or_null("PuzzleControls")
	if controls == null:
		return
	var distance := INF
	var local_camera := (get_parent() as Node3D).to_local(camera.global_position)
	for control in controls.get_children():
		if control is Node3D:
			var local_control := (get_parent() as Node3D).to_local(control.global_position)
			distance = minf(distance, local_camera.distance_to(local_control))
	var target := 1.0 - smoothstep(30.0, 90.0, distance)
	# The whole first island shares one atmosphere, not only instrument hotspots.
	# An overview looking at this island receives the same palette as its player.
	var world := get_parent()
	while world != null and not world is MindSparkWorldOne:
		world = world.get_parent()
	if world is MindSparkWorldOne:
		# The approved quest family needs the same readable material exposure on
		# later islands, without replacing their whole ambient atmosphere.
		for station in world.get_quest_objects():
			var station_distance: float = world.to_local(camera.global_position).distance_to(world.to_local(station.global_position))
			target = maxf(target, 1.0-smoothstep(34.0,54.0,station_distance))
		for id in ["01_world_gate_landing", "02_living_network_forest", "03_constellation_court", "04_hope_path_ridge"]:
			var center: Vector3 = world.get_zone_position(id)
			var view_position: Vector3 = world.to_local(camera.global_position)
			var direction: Vector3 = world.global_transform.basis.inverse() * -camera.global_basis.z
			if direction.y < -.05:
				var t := (center.y-view_position.y)/direction.y
				if t > 0:
					view_position += direction*t
			var radius := float({"01_world_gate_landing":125.0, "02_living_network_forest":155.0, "03_constellation_court":150.0, "04_hope_path_ridge":122.0}[id])
			var edge_distance := Vector2(view_position.x-center.x,view_position.z-center.z).length()-radius
			target = maxf(target,1.0-smoothstep(0,45,edge_distance))
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
	_profile.ambient_light_energy = lerpf(_source.ambient_light_energy, .30 if compatibility else .48, _strength)
	_profile.ambient_light_sky_contribution = lerpf(_source.ambient_light_sky_contribution, 0.0, _strength)
	_profile.tonemap_exposure = lerpf(_source.tonemap_exposure, .82, _strength)
	for light in _directional_lights:
		if is_instance_valid(light):
			var original: Array = _directional_lights[light]
			var daylight := .50 if compatibility else .78
			light.light_energy = lerpf(float(original[0]),daylight if light.name == "Sun" else .12,_strength)
			light.light_color = (original[1] as Color).lerp(Color("ffe8cd") if light.name == "Sun" else Color("d9dfeb"),_strength)
	_profile.fog_light_color = _source.fog_light_color.lerp(Color("b8c6cf"), _strength)
	if _sky_material != null:
		_sky_material.sky_top_color = _original_sky.sky_top_color.lerp(Color("708ba6"), _strength)
		_sky_material.sky_horizon_color = _original_sky.sky_horizon_color.lerp(Color("e5d7c2"), _strength)
		_sky_material.ground_horizon_color = _original_sky.ground_horizon_color.lerp(Color("d2c7b5"), _strength)
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

func _exit_tree() -> void:
	_restore()
