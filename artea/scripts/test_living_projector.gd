extends SceneTree
const Pattern := preload("res://scripts/mind_spark/light_pattern_state.gd")
const STORE := "user://living_projector_test.json"
func _init() -> void: call_deferred("run")
func run() -> void:
	assert(Pattern.describe({"completed":true}).optics==[2,3,1],"Legacy completion must display a restored pattern")
	if FileAccess.file_exists(STORE): DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud=false
	world.object_state_store_path=STORE
	world.get_node("QuestController").enabled=false
	root.add_child(world)
	var station := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE)
	station.interaction_enabled=true
	var projector := station.get_node("ProductionLivingProjector")
	assert(not world.get_node("GardenOfUnfinishedLight/ConservatoryOfPossibleTomorrow/LivingProjectionMachine").visible)
	for approach in 3:
		assert(station.interact(&"approach",approach).accepted)
		await process_frame
		await process_frame
		assert(projector.model.get_node("ReferenceBrace").visible==(approach==1))
		var visible_leaves := 0
		for i in 9:
			if projector.model.get_node("Leaf%d"%i).visible: visible_leaves+=1
		assert(visible_leaves==(3 if approach==0 else 9))
		assert(is_equal_approx(projector.targets[0].position.x,-.4 if approach==0 else -2.0))
		if approach==2:
			assert(not projector.beams[0].visible)
			assert(not station.interact(&"tune",0).accepted)
			assert(station.interact(&"cooling").accepted)
			await process_frame
			await process_frame
			assert(projector.beams[0].visible)
		var before: Array=station.current_state.optics.duplicate()
		station.interact(&"tune",0)
		station.interact(&"undo")
		assert(station.current_state.optics==before)
		station.interact(&"reset")
		await process_frame
		await process_frame
		assert(not projector.beams[0].visible)
		assert(not projector.model.get_node("ReferenceBrace").visible)
	# Solve through the public actions, then verify the physical response rather
	# than assigning completed=true (which would bypass the gameplay contract).
	assert(station.interact(&"approach",0).accepted)
	for channel in [0,0,1]:
		assert(station.interact(&"tune",channel).accepted)
	assert(station.current_state.optics==[2,3,1])
	assert(station.interact(&"project").accepted)
	await create_timer(1.5).timeout
	assert(station.current_state.completed)
	assert(projector.status.text.begins_with("GARDEN RESTORED"))
	for i in [3,4,5]:
		assert(absf(projector.model.get_node("Leaf%d"%i).rotation.x)<.01,
			"Successful projection must visibly unfold the active receivers")
	for i in 3:
		assert(projector.beams[i].visible)
		var ray: MeshInstance3D=projector.beams[i]
		var end: Vector3=ray.position-ray.basis.y*.5
		assert(end.distance_to(projector.targets[i].position)<.01,
			"Solved rays must terminate at their visible targets")
	world.queue_free()
	await process_frame
	if FileAccess.file_exists(STORE): DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	print("LIVING_PROJECTOR: PASS — three visible constraints, cooling interlock, undo/reset, legacy completion")
	quit()
