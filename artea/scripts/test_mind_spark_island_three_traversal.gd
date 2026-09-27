extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const PlayerScene := preload("res://scenes/player_3d.tscn")
const STATE_PATH := "user://test_island_three_traversal.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(STATE_PATH)
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = STATE_PATH
	root.add_child(world)
	for _frame in 5:
		await physics_frame

	var geometry := world.get_node("WorldOneGeometry") as Node3D
	var route := geometry.get_node("MainStoryCircuitRoute") as Node3D
	var campus := geometry.get_node("IslandThreeCivicSanctuary") as Node3D
	var supported_surfaces := [
		route.get_node("CircuitRoute_04_ACollision"),
		route.get_node("CircuitRoute_04_BCollision"),
		campus.get_node("StormworksArrivalPortico/IvoryArrivalTerraceCollision"),
		campus.get_node("StormworksGrandCourt/ShieldProcessional_01Collision"),
		campus.get_node("StormworksGrandCourt/ShieldProcessional_02Collision"),
		campus.get_node("StormworksGrandCourt/ShieldProcessional_03Collision"),
		campus.get_node("RainHarvestObservatory/IvoryRainApproachCollision"),
		campus.get_node("WisdomBasilicaPromenade/IvoryWisdomNaveCollision"),
		campus.get_node("WisdomBasilicaPromenade/OldestTreeReflectionApseCollision"),
	]
	for surface in supported_surfaces:
		_assert_supported(world, surface as StaticBody3D)

	var player := PlayerScene.instantiate() as CharacterBody3D
	root.add_child(player)
	player.set_physics_process(false)
	for object in world.get_quest_objects():
		if int(object.get_meta("physical_island", 0)) != 3:
			continue
		var approach_local: Vector3 = object.get_meta("operator_approach_local")
		var approach_global := (object.get_parent() as Node3D).to_global(approach_local)
		player.global_position = approach_global + Vector3.UP * 7.0
		await physics_frame
		var landing := player.move_and_collide(Vector3.DOWN * 14.0)
		assert(landing != null,
			"the production player capsule lands on supported ground at %s" % object.save_id)

	var heartwood := campus.get_node(
		"OldestTreeLivingCathedral/LivingHeartwoodCollision") as StaticBody3D
	var production_capsule := (player.get_node("CollisionShape3D") as CollisionShape3D).shape
	var tree_probe := PhysicsShapeQueryParameters3D.new()
	tree_probe.shape = production_capsule
	tree_probe.transform = Transform3D(Basis.IDENTITY, heartwood.global_position)
	tree_probe.collision_mask = 1
	tree_probe.exclude = [player.get_rid()]
	var tree_hits := world.get_world_3d().direct_space_state.intersect_shape(tree_probe)
	assert(tree_hits.any(func(hit: Dictionary) -> bool:
		return hit.get("collider") == heartwood),
		"the production player capsule cannot walk through the Oldest Tree")

	var state_paths := [
		"StormworksGrandCourt/StormLensTower/CompletionStateVisuals",
		"StormworksGrandCourt/ResonanceForge/CompletionStateVisuals",
		"StormworksGrandCourt/LightningArchive/CompletionStateVisuals",
		"RainHarvestObservatory/CompletionStateVisuals",
		"WisdomBasilicaPromenade/RootboundReflectionCourt/CompletionStateVisuals",
	]
	for state_path in state_paths:
		assert(not (campus.get_node(state_path) as Node3D).visible,
			"fresh Island 3 completion effects start dormant")
	for object in world.get_quest_objects():
		if int(object.get_meta("physical_island", 0)) == 3:
			object.current_state["completed"] = true
	world.call("_refresh_island_three_completion_visuals")
	for state_path in state_paths:
		assert((campus.get_node(state_path) as Node3D).visible,
			"completed Island 3 objects activate their local low-poly landmark")
	assert(int(campus.get_meta("completed_storm_landmarks", 0)) == 3)
	assert(bool(campus.get_meta("rain_observatory_active", false)))
	assert(bool(campus.get_meta("oldest_tree_awake", false)))

	print("MindSparkIslandThreeTraversal: PASS — bridge, five quest approaches, paths, tree collision and completion states")
	player.queue_free()
	world.queue_free()
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(STATE_PATH)
	quit()


func _assert_supported(world: Node3D, body: StaticBody3D) -> void:
	var ray := PhysicsRayQueryParameters3D.create(
		body.global_position + Vector3.UP * 10.0,
		body.global_position + Vector3.DOWN * 10.0)
	ray.collision_mask = 1
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	assert(not hit.is_empty(), "%s has a player-supporting collision surface" % body.name)
