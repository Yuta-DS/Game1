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
	var camera := Camera3D.new()
	camera.position = Vector3(-760, 8, 120)
	camera.far = 5000.0
	root.add_child(camera)
	camera.make_current()
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
		"World One meshes must stop submitting duplicate Web shadow passes")
	assert(int(world.get_meta("web_island_two_foundation_lod_count", 0)) >= 8,
		"Island Two's large imported foundations must use their generated Web LODs")
	assert(int(world.get_meta("web_island_two_quest_detail_mesh_count", 0)) >= 80,
		"Island Two's small production-bay controls must stream by player distance")
	assert(int(world.get_meta("web_island_two_preserved_silhouette_mesh_count", 0)) >= 20,
		"Island Two's long-range station silhouettes must remain outside detail streaming")
	for path in [
		"WorldOneGeometry/03ConstellationCourt/ModularFloatingFoundation/IslandArchitecture/Architecture_v11_03",
		"WorldOneGeometry/04HopePathRidge/ModularFloatingFoundation/IslandArchitecture/Architecture_v17_04",
	]:
		var foundation_mesh := world.get_node(path) as MeshInstance3D
		assert(is_equal_approx(foundation_mesh.lod_bias, 0.25)
				and str(foundation_mesh.get_meta("web_lod_profile", "")) \
				== "island_two_foundation_0.25",
			"Island Two architecture must keep an explicit production Web LOD contract")
	var memory := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.MEMORY_CONSTELLATION)
	var memory_tile := memory.get_node("ProductionRecorderBay/recorder_bay/EventTile0") \
		as MeshInstance3D
	var memory_pavilion := memory.get_node("ProductionRecorderBay/recorder_bay/Pavilion") \
		as MeshInstance3D
	var memory_beacon := memory.get_node("ProductionStationMarker/MarkerStateBeacon") \
		as MeshInstance3D
	assert(is_equal_approx(memory_tile.visibility_range_end, 64.0)
			and memory_tile.has_meta("web_quest_detail_range"),
		"inactive memory controls must leave the Web render set outside their approach")
	assert(memory_pavilion.visibility_range_end > 64.0 \
			and memory_beacon.visibility_range_end > 64.0,
		"the memory pavilion and state beacon must remain readable from the evidence court")
	var render_scale := float(world.get_meta("web_3d_render_scale", 0.0))
	assert(render_scale >= 0.62 and render_scale < 0.67,
		"the 1444x1702 production canvas must render 3D near the 1.0 MP target")
	assert(absf(root.scaling_3d_scale - render_scale) < 0.002,
		"the measured render scale must be applied to the active viewport")
	var full_hd_scale := float(world.call(
		"_web_3d_scale_for_size", Vector2i(1280, 720)))
	assert(is_equal_approx(full_hd_scale, 1.0),
		"a sub-1.0 MP canvas must retain native 3D resolution")
	var retina_scale := float(world.call(
		"_web_3d_scale_for_size", Vector2i(2560, 1440)))
	var retina_render_pixels := 2560.0 * 1440.0 * retina_scale * retina_scale
	assert(retina_scale >= 0.520 and retina_scale < 0.523 \
			and absf(retina_render_pixels - 1000000.0) < 1000.0,
		"a 2560x1440 Retina canvas must obey the 1.0 MP 3D budget")
	assert(root.msaa_3d == Viewport.MSAA_DISABLED \
			and int(world.get_meta("web_msaa_3d", -1)) == int(Viewport.MSAA_DISABLED),
		"Web must avoid multisampling its already high-DPI internal buffer")
	assert(not sun.shadow_enabled \
			and int(world.get_meta("web_directional_shadows_disabled", 0)) == 1,
		"Web must remove the archipelago-wide directional shadow pass")
	assert(is_equal_approx(camera.far, 900.0) \
			and is_equal_approx(float(world.get_meta("web_camera_far", 0.0)), 900.0),
		"the active World One Web camera must exclude unrelated galaxy geometry")
	camera.position = Vector3(4000, 20, 4000)
	await process_frame
	assert(is_equal_approx(camera.far, 5000.0),
		"camera depth must restore after leaving World One")
	camera.position = Vector3(-760, 8, 120)
	await process_frame
	assert(bool(world.get_meta("web_island_detail_streaming", false)),
		"Web must stream stateful island detail branches by camera distance")
	assert(int(world.get_meta("web_streamed_static_batch_count", 0)) >= 100,
		"static replacement batches must inherit the visibility of their source island")
	world.call("_update_web_island_detail_streaming_position", Vector3(-760, 8, 120))
	assert(world.get_node("WorldOneGeometry/01WorldGateLanding").visible \
			and not world.get_node("WorldOneGeometry/03ConstellationCourt").visible \
			and not world.get_node("WorldOneGeometry/05ThoughtStormArena").visible,
		"Island 1 focus must retire distant Island 2 and 3 detail")
	world.call("_update_web_island_detail_streaming_position", Vector3(-440, 10, 0))
	assert(world.get_node("WorldOneGeometry/02LivingNetworkForest").visible \
			and world.get_node("WorldOneGeometry/03ConstellationCourt").visible,
		"the Island 1-to-2 crossing must keep both shores visible")
	var island_two_batch := _find_streamed_batch(world, 2)
	var island_three_batch := _find_streamed_batch(world, 3)
	assert(island_two_batch != null and island_two_batch.visible \
			and island_three_batch != null and not island_three_batch.visible,
		"replacement batches must follow the same crossing visibility contract")
	world.call("_update_web_island_detail_streaming_position", Vector3(520, 22, -20))
	assert(not world.get_node("WorldOneGeometry/03ConstellationCourt").visible \
			and world.get_node("WorldOneGeometry/05ThoughtStormArena").visible \
			and world.get_node("WorldOneGeometry/06OldestTreeSanctuary").visible,
		"Island 3 focus must preserve both local districts while retiring Island 2 detail")
	assert(not island_two_batch.visible and island_three_batch.visible,
		"replacement batches must switch with the active island")
	for object in world.get_quest_objects():
		assert(object.visible and object.definition != null,
			"the Web render budget must preserve all quest objects and their feedback")
	OS.set_environment("ARTEA_FORCE_WEB_LOD", "")
	print("WORLD_ONE_WEB_RENDER_BUDGET: PASS — scale %.3f; %d mesh shadows, the world sun shadow pass, distant island detail removed, %d Island Two foundation meshes use generated LODs, and %d small quest controls stream by distance; all 15 quest objects preserved" % [
		render_scale, int(world.get_meta("web_shadow_culled_mesh_count", 0)),
		int(world.get_meta("web_island_two_foundation_lod_count", 0)),
		int(world.get_meta("web_island_two_quest_detail_mesh_count", 0))])
	quit()


func _find_streamed_batch(world: MindSparkWorldOne, physical_island: int) -> GeometryInstance3D:
	for child in world.get_children():
		if child is GeometryInstance3D \
				and int(child.get_meta("web_detail_island", 0)) == physical_island:
			return child as GeometryInstance3D
	return null
