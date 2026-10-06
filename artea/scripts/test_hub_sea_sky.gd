extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("HUB_SEA_SKY_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var water_scene := load("res://scenes/Water.tscn") as PackedScene
	if water_scene == null:
		_fail("water scene must load")
		return
	var water := water_scene.instantiate()
	var surface := water.get_node_or_null("MeshInstance3D") as MeshInstance3D
	var old_torus := water.get_node_or_null("MeshInstance3D2") as MeshInstance3D
	if surface == null or surface.mesh is not PlaneMesh:
		_fail("sea must retain one continuous plane surface")
		return
	var plane := surface.mesh as PlaneMesh
	# Water.tscn raises the complete water system at its root so the mesh,
	# ambience, and effects stay aligned. Validate the composed transform.
	if water.position.y + surface.position.y < 0.5:
		_fail("sea must sit above the zero-height terrain shelf to prevent sand holes")
		return
	if plane.subdivide_width < 96 or plane.subdivide_depth < 96:
		_fail("sea needs enough subdivisions for smooth vertex waves")
		return
	if old_torus != null and old_torus.visible:
		_fail("the retired decorative water torus must stay removed or hidden")
		return
	var water_material := surface.get_surface_override_material(0) as ShaderMaterial
	var water_code := water_material.shader.code if water_material != null else ""
	if water_code.contains("discard") or not water_code.contains("CAMERA_POSITION_WORLD"):
		_fail("desktop sea must be hole-free and fade naturally into atmospheric haze")
		return
	if not water_code.contains("sun_direction") or not water_code.contains("sun_glint"):
		_fail("desktop sea must retain its directional sunlight reflection path")
		return
	water.free()

	var cycle_scene := load("res://scripts/cycle.tscn") as PackedScene
	var cycle := cycle_scene.instantiate() if cycle_scene != null else null
	var world_environment := cycle.get_node_or_null("WorldEnvironment") as WorldEnvironment if cycle != null else null
	if world_environment == null or world_environment.environment == null:
		_fail("day/night environment must load")
		return
	var environment := world_environment.environment
	if environment.fog_density > 0.03 or environment.adjustment_saturation > 1.1:
		_fail("sky atmosphere must avoid opaque fog and oversaturation")
		return
	var sky_material := environment.sky.sky_material as ShaderMaterial
	if sky_material == null or sky_material.shader.code.contains("use_half_res_pass"):
		_fail("natural sky must avoid the blocky half-resolution cloud compositor")
		return
	cycle.free()

	var web_water := load("res://shaders/web_water.gdshader") as Shader
	var web_sky := load("res://shaders/web_sky_dome.gdshader") as Shader
	if web_water == null or web_water.code.contains("discard") \
			or not web_water.code.contains("CAMERA_POSITION_WORLD"):
		_fail("Web sea must remain continuous and horizon-faded")
		return
	if not web_water.code.contains("sun_direction") or not web_water.code.contains("sun_glint"):
		_fail("Web sea must retain its lightweight sunlight reflection path")
		return
	if web_sky == null or not web_sky.code.contains("cloud_amount"):
		_fail("Web sky must retain its lightweight natural cloud layer")
		return

	print("HUB_SEA_SKY_TEST: PASS — layered waves, sun reflection, atmospheric horizon, and natural sky")
	quit()
