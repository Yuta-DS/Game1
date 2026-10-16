extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("CURLING_SURF: " + message)
		quit(1)
	return ok

func _run() -> void:
	var import_settings := ConfigFile.new()
	var import_error := import_settings.load("res://assets3D/curling_surf/curling_surf.glb.import")
	if not _check(import_error == OK and not import_settings.get_value("params","meshes/generate_lods",true), "static-mesh LOD must not remove the animated parametric grid"):
		return
	var ocean := (load("res://scripts/Water.tscn") as PackedScene).instantiate()
	root.add_child(ocean)
	ocean.set_process(false)
	ocean.configure_harbour(Vector2(38,188.5),20.0)
	var surf: Node3D = ocean.get_node("CurlingSurf")
	if not _check(surf.get_child_count() == 6, "six spaced surf patches"):
		return
	var mesh := surf.get_node("Breaker_00/BlenderBarrel") as MeshInstance3D
	var arrays := mesh.mesh.surface_get_arrays(0)
	# All six slots must use the same approved silhouette and face/crest
	# shader; size, timing and location may differ, never the wave art style.
	for i in 6:
		var instance := surf.get_node("Breaker_%02d/BlenderBarrel" % i) as MeshInstance3D
		var material := instance.material_override as ShaderMaterial
		if not _check(instance.mesh == mesh.mesh and material.shader.resource_path == "res://shaders/curling_surf.gdshader", "every visible wave shares the approved Blender curl and material"):
			return
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var enclosed_volume := 0.0
	for triangle in range(0,indices.size(),3):
		var a := vertices[indices[triangle]]
		var b := vertices[indices[triangle+1]]
		var c := vertices[indices[triangle+2]]
		enclosed_volume += a.dot(b.cross(c))/6.0
	if not _check(absf(enclosed_volume)>2.0 and mesh.mesh.get_aabb().size.z>2.0, "Blender asset encloses a deep water body instead of two thin sheets"):
		return
	if not _check(vertices.size() >= 5000 and vertices.size() < 6000, "efficient Blender mesh retains rounded curl cross-sections within the vertex budget"):
		return
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var shell: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	if not _check(uv.size() == vertices.size() and shell.size() == vertices.size(), "Blender asset retains both surface and shell UV sets"):
		return
	var inner := 0
	var rounded_lip := 0
	for p in shell:
		if p.x > .9:
			inner += 1
		if p.x > .05 and p.x < .95:
			rounded_lip += 1
	if not _check(rounded_lip >= 576, "solid rounded rim has intermediate shell vertices, not a flat strip"):
		return
	if not _check(inner > 1000 and inner < vertices.size() - 1000, "curling lip has two joined surfaces"):
		return
	for t in range(0,61):
		ocean.wave_time = float(t)
		ocean._process(0)
		for i in 6:
			var s: Dictionary = surf.sample_patch(i,float(t))
			var wind: Vector3 = ocean.sample_wind(float(t))
			var direction := Vector2(sin(s.angle),cos(s.angle))
			if not _check(direction.dot(Vector2(wind.x,wind.y)) >= cos(deg_to_rad(3.0))-.00001, "every breaker follows the shared wind within three degrees"):
				return
			var spray := surf.get_node("Breaker_%02d/LipSpray" % i) as MultiMeshInstance3D
			var spray_material := spray.material_override as ShaderMaterial
			var barrel_material := (surf.get_node("Breaker_%02d/BlenderBarrel" % i) as MeshInstance3D).material_override as ShaderMaterial
			if not _check(is_equal_approx(s.wind_strength,wind.z) and is_equal_approx(spray_material.get_shader_parameter("wind_strength"),wind.z) and is_equal_approx(barrel_material.get_shader_parameter("wind_strength"),wind.z), "spray and 3D crest receive the ocean gust strength"):
				return
			if not _check(spray.multimesh.mesh is SphereMesh, "foam is real 3D geometry, not a billboard"):
				return
			if not _check(spray.multimesh.instance_count == 96 and is_equal_approx(spray_material.get_shader_parameter("wave_age"),s.age), "bounded 3D spray follows the same crest clock"):
				return
			if not _check(s.center.distance_to(Vector2(38,188.5)) > 85.0 and s.height >= 1.5 and s.height <= 4.5, "breakers stay outside the harbour with depth-based 1.5–4.5m crest targets"):
				return
			var base_width: float = surf.WIDTHS[i]*lerpf(.85,1.15,surf._event_noise(i,s.cycle,65.3))
			if not _check(is_equal_approx(s.width,base_width*10.0) and is_equal_approx(s.height,ocean.sample_crest_limit(s.center,float(t)).x*3.0),"all randomized waves are exactly 10x wider and 3x taller than the base dimensions"):
				return
			var barrel := surf.get_node("Breaker_%02d/BlenderBarrel" % i) as MeshInstance3D
			if not _check(is_equal_approx(barrel_material.get_shader_parameter("wave_depth_scale"),3.0) and is_equal_approx(spray_material.get_shader_parameter("wave_depth_scale"),3.0) and is_equal_approx(surf.patches[i].w,7.5),"rounded barrel, spray, and water footprint share the enlarged depth"):
				return
			for bounds in [barrel.custom_aabb,spray.custom_aabb]:
				if not _check(bounds.position.x <= -s.width*.5 and bounds.end.x >= s.width*.5 and bounds.end.y >= s.height+1.0,"displaced wave and spray bounds enclose the full enlarged geometry"):
					return
			if not _check(absf(s.center.x - 38) > s.width*.5 + 40, "harbour sailing approach stays open"):
				return
			var water: Vector4 = ocean.sample_wave(s.center,float(t))
			if s.envelope > .99 and not _check(absf(water.x) < .045, "underlying sea stays below the hollow barrel"):
				return
			# Include the edge blend, where incorrect normals would produce a seam.
			var p: Vector2 = s.center + Vector2(s.width*.5+1.5,2.5)
			var sample: Vector4 = ocean.sample_wave(p,float(t))
			var dx: float = (ocean.sample_wave(p+Vector2(.01,0),float(t)).x-ocean.sample_wave(p-Vector2(.01,0),float(t)).x)/.02
			var dz: float = (ocean.sample_wave(p+Vector2(0,.01),float(t)).x-ocean.sample_wave(p-Vector2(0,.01),float(t)).x)/.02
			if not _check(absf(dx-sample.y)<.003 and absf(dz-sample.z)<.003,"base-water blend and buoyancy share correct slopes"):
				return
	var minimum_height := INF
	var maximum_height := 0.0
	for t in range(301):
		var s: Dictionary = surf.sample_patch(2,float(t))
		minimum_height = minf(minimum_height,s.height)
		maximum_height = maxf(maximum_height,s.height)
	if not _check(maximum_height-minimum_height > .3, "random gusts visibly change breaker height"):
		return
	for t in [17.0,29.0,34.0,58.0,85.0,116.0]:
		for i in 6:
			var before: Dictionary = surf.sample_patch(i,t-.001)
			var after: Dictionary = surf.sample_patch(i,t+.001)
			var before_direction := Vector2(sin(before.angle),cos(before.angle))
			var after_direction := Vector2(sin(after.angle),cos(after.angle))
			if not _check(before_direction.distance_to(after_direction)<.001 and absf(before.height-after.height)<.001,"breaker steering and height remain smooth at random wind boundaries"):
				return
	var web := ShaderMaterial.new()
	web.shader = load("res://shaders/web_water.gdshader")
	ocean.get_node("MeshInstance3D").material_override = web
	ocean._process(0)
	if not _check(web.get_shader_parameter("surf_patches") == surf.patches and web.get_shader_parameter("surf_axes") == surf.axes,"Web receives the same breaker blending"):
		return
	ocean.max_crest_height = 0.0
	ocean._process(0)
	for child in surf.get_children():
		if not _check(not child.visible and not child.get_node("LipSpray").visible,"zero wave height disables barrels and spray"):
			return
	print("CURLING_SURF: PASS — 10x width / 3x height, depth-scaled 1.5–4.5m crests, complete culling bounds, sheltered sailing lane, base-water normals and Web parity")
	quit()
