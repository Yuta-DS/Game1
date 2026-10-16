extends SceneTree
const STORE := "user://research_bay_clearance_test.json"
func _init() -> void: call_deferred("run")
func run() -> void:
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud=false
	world.object_state_store_path=STORE
	world.get_node("QuestController").enabled=false
	root.add_child(world)
	var actor := load("res://scenes/player_3d.tscn").instantiate() as CharacterBody3D
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.global_position=Vector3(0,2000,0)
	for frame in 5: await physics_frame
	for kind in [QuestObjectDefinition.ObjectKind.EVIDENCE_SCANNER,QuestObjectDefinition.ObjectKind.MEMORY_CONSTELLATION,QuestObjectDefinition.ObjectKind.LOGIC_GATE_ARCH,QuestObjectDefinition.ObjectKind.PERSPECTIVE_LENS,QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE]:
		var station := world.get_object_by_kind(kind)
		actor.global_position=station.to_global(Vector3(0,1.1,6))
		var hit := actor.move_and_collide(-station.global_basis.z*3)
		assert(hit==null,"Blocked operator approach: %s"%(str(hit.get_collider().get_path()) if hit else "clear"))
		hit=actor.move_and_collide(-station.global_basis.z*4)
		assert(hit!=null,"Player passed through bench")
		assert(station.is_ancestor_of(hit.get_collider()),"Unexpected obstruction before bench")
		actor.global_position=Vector3(0,2000,0)
		if kind==QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE: continue
		var physics := world.get_world_3d().direct_space_state
		for side in [-1,1]:
			var start := station.to_global(Vector3(side*3.3,2.5,-1))
			var finish := station.to_global(Vector3(side*3.3,.6,-1))
			var shelf := physics.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1))
			assert(not shelf.is_empty() and str(shelf.collider.name).begins_with("ServiceShelf"),"Shelf lacks physical support")
	world.queue_free()
	await process_frame
	if FileAccess.file_exists(STORE): DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	print("RESEARCH_BAY_CLEARANCE: PASS — actual player capsule reaches all five operator aprons; benches and bay shelves are solid")
	quit()
