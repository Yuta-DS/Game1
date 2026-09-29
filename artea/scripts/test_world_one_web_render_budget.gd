extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("ARTEA_FORCE_WEB_LOD", "1")
	root.size = Vector2i(1444, 1702)
	var sun := DirectionalLight3D.new()
	sun.name = "ProductionShadowSun"
	sun.shadow_enabled = true
	root.add_child(sun)
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://test_world_one_web_render_budget.json"
	root.add_child(world)
	await process_frame
	await process_frame
	assert(str(world.get_meta("visibility_range_profile", "")) \
		== "60/105/175/300/720m by world-space extent",
		"Web must use the tighter distance profile measured against the production canvas")
	assert(int(world.get_meta("web_shadow_culled_mesh_count", 0)) > 1000,
		"small static/detail meshes must stop submitting individual Web shadow passes")
	var render_scale := float(world.get_meta("web_3d_render_scale", 0.0))
	assert(render_scale >= 0.67 and render_scale < 0.75,
		"the 1444x1702 production canvas must render 3D near the 1.2 MP target")
	assert(absf(root.scaling_3d_scale - render_scale) < 0.002,
		"the measured render scale must be applied to the active viewport")
	assert(root.msaa_3d == Viewport.MSAA_2X \
			and int(world.get_meta("web_msaa_3d", -1)) == int(Viewport.MSAA_2X),
		"Web must reduce the desktop 8x MSAA preset to a high-DPI-safe 2x budget")
	assert(not sun.shadow_enabled \
			and int(world.get_meta("web_directional_shadows_disabled", 0)) == 1,
		"Web must remove the archipelago-wide directional shadow pass")
	for object in world.get_quest_objects():
		assert(object.visible and object.definition != null,
			"the Web render budget must preserve all quest objects and their feedback")
	OS.set_environment("ARTEA_FORCE_WEB_LOD", "")
	print("WORLD_ONE_WEB_RENDER_BUDGET: PASS — scale %.3f; %d small-mesh shadows and the world sun shadow pass removed; all 15 quest objects preserved" % [
		render_scale, int(world.get_meta("web_shadow_culled_mesh_count", 0))])
	quit()
