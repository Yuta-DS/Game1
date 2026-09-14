extends SceneTree
const Experiment := preload("res://scripts/mind_spark/causal_experiment.gd")
const STORE := "user://causal_experiment_test.json"
func _init() -> void: call_deferred("run")
func run() -> void:
	for model in 3:
		var matches := true
		for trial in 2: matches=matches and Experiment.prediction(model,trial)==Experiment.outcome(trial).shutter_open
		assert(matches==(model==1))
	if FileAccess.file_exists(STORE): DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud=false
	world.object_state_store_path=STORE
	world.get_node("QuestController").enabled=false
	root.add_child(world)
	var station := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.LOGIC_GATE_ARCH)
	station.interaction_enabled=true
	var bay := station.get_node("ProductionTesterBay")
	station.interact(&"model",1)
	assert(not station.interact(&"test").accepted,"Answer alone cannot complete the experiment")
	station.interact(&"trial",0)
	for i in 90: await process_frame
	assert(absf(bay.model.get_node("Shutter").position.y-2.08)<.01)
	assert(absf(bay.model.get_node("FlowColumn").scale.y-.25)<.01)
	assert(not station.interact(&"test").accepted,"Both measurements are required")
	station.interact(&"trial",1)
	for i in 90: await process_frame
	assert(absf(bay.model.get_node("Shutter").position.y-3.12)<.01)
	assert(absf(bay.model.get_node("FlowColumn").scale.y-1)<.01)
	for model in [0,2]:
		station.interact(&"model",model)
		assert(not station.interact(&"test").accepted)
	station.interact(&"model",1)
	assert(station.interact(&"test").accepted)
	assert(station.current_state.completed)
	world.queue_free()
	await process_frame
	if FileAccess.file_exists(STORE): DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	print("CAUSAL_EXPERIMENT: PASS — prediction consistency, both trials required, wrong models rejected, physical flow/shutter response")
	quit()
