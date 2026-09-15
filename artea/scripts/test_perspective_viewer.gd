extends SceneTree
const Evidence := preload("res://scripts/mind_spark/perspective_evidence.gd")
const STORE := "user://perspective_viewer_test.json"
func _init() -> void: call_deferred("run")
func run() -> void:
	if FileAccess.file_exists(STORE): DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud=false
	world.object_state_store_path=STORE
	world.get_node("QuestController").enabled=false
	root.add_child(world)
	var station := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.PERSPECTIVE_LENS)
	station.interaction_enabled=true
	var bay := station.get_node("ProductionPerspectiveBay")
	assert(bay.model.find_children("*","MeshInstance3D",true,false).size()==4)
	for view in 3:
		assert(station.interact(&"view",view).accepted)
		for i in 75: await process_frame
		var angle: float=bay.model.get_node("Carousel").rotation.y
		assert(absf(wrapf(angle-Evidence.angle(view),-PI,PI))<.005)
		assert(bay.heading.text==Evidence.TITLES[view])
		assert(not station.interact(&"interpret",(view+1)%3).accepted)
		assert(station.interact(&"interpret",view).accepted)
	assert(station.current_state.view_answers==[true,true,true])
	assert(station.current_state.completed)
	world.queue_free()
	await process_frame
	if FileAccess.file_exists(STORE): DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	print("PERSPECTIVE_VIEWER: PASS — three distinct rotations, matching captions, retained interpretations and completion")
	quit()
