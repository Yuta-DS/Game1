extends SceneTree
const STORE := "user://recorder_bay_geometry_test.json"
func _init() -> void: call_deferred("run")
func run() -> void:
	if FileAccess.file_exists(STORE): DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud=false
	world.object_state_store_path=STORE
	world.get_node("QuestController").enabled=false
	root.add_child(world)
	var station := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.MEMORY_CONSTELLATION)
	station.interaction_enabled=true
	var bay := station.get_node("ProductionRecorderBay")
	assert(station.scale==Vector3.ONE)
	assert(not station.get_node("VisualRoot").visible)
	assert(bay.model.find_children("*","MeshInstance3D",true,false).size()==8)
	station.interact(&"swap",0)
	station.interact(&"replay")
	for frame in 180:
		await process_frame
		for i in 3:
			for j in range(i+1,3):
				var a: Vector3=bay.tiles[i].position
				var b: Vector3=bay.tiles[j].position
				assert(absf(a.x-b.x)>=1.20 or absf(a.y-b.y)>=.60,"Event plates intersect during transfer")
	assert(bay.displayed_order==[0,2,1])
	assert(bay.playing_order==[0,2,1])
	assert(bay.elapsed>=0,"Replay starts after plates settle")
	# Rapid changes are queued behind the active physical transfer. They must
	# settle on the latest saved order without intersecting the other plates.
	for frame in 150:
		if frame in [0,8,16,24]:
			station.interact(&"swap",0 if frame%16==0 else 1)
			station.interact(&"replay")
		await process_frame
		for i in 3:
			for j in range(i+1,3):
				var a: Vector3=bay.tiles[i].position
				var b: Vector3=bay.tiles[j].position
				assert(absf(a.x-b.x)>=1.20 or absf(a.y-b.y)>=.60,"Rapid-input transfer intersects")
	assert(bay.displayed_order==station.current_state.timeline)
	assert(bay.playing_order==station.current_state.timeline)
	for label in bay.tile_labels: assert(label.is_visible_in_tree())
	station.call("_on_body_entered",world)
	assert(not station.get_node("Prompt").visible,"Legacy label must not overlap physical instrument")
	world.queue_free()
	await process_frame
	if FileAccess.file_exists(STORE): DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	print("RECORDER_BAY: PASS — runtime asset, ordered transfer clearance, replay, physical signage")
	quit()
