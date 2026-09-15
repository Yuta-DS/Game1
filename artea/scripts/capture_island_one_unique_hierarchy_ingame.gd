extends SceneTree

## Focused native-game verification of the de-duplicated Island One stations.
## Uses the production world scene and its live first-person-scale coordinates.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const OUTPUT := "res://artifacts/island_one_unique_hierarchy_ingame"
const STATE := "user://capture_island_one_unique_hierarchy_ingame.json"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size=Vector2i(1280,720)
	root.msaa_3d=Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud=false
	world.object_state_store_path=STATE
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled=false
	root.add_child(world)
	for _frame in 8:
		await process_frame
	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(puzzle != null)
	_add_lighting(world)
	# Retain authored machine plaques, but hide distant narration that competes
	# with a player's view of the redesigned silhouettes.
	for label in world.find_children("*","Label3D",true,false):
		if label.name not in ["QuestRolePlaque","QuestPurposeLabel"]:
			(label as Label3D).hide()
	var camera := Camera3D.new()
	camera.name="PlayerEyeCamera"
	camera.fov=61.0
	camera.near=.08
	camera.far=5000.0
	world.add_child(camera)
	camera.make_current()
	_add_hud(world)
	var controls := puzzle.get_node("PuzzleControls")
	_validate_quest_layout(controls)
	await _capture_group(camera,controls,
		["colour_prism","rhythm_prism","weight_prism","analysis_console"],
		Vector3(35,9,-32),"01_signal_laboratory_player.png")
	await _capture_group(camera,controls,
		["echo_collector","echo_signal_1","echo_signal_2","echo_signal_3","echo_question","echo_beacon"],
		Vector3(30,9,18),"02_living_research_garden_player.png")
	print("ISLAND_ONE_UNIQUE_HIERARCHY_INGAME: PASS")
	if FileAccess.file_exists(STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE))
	world.queue_free()
	await process_frame
	quit()


func _validate_quest_layout(controls: Node3D) -> void:
	var route_ids := [
		"colour_prism","rhythm_prism","weight_prism","analysis_console",
		"echo_collector","echo_signal_1","echo_signal_2","echo_signal_3",
		"echo_question","echo_beacon"]
	for route_index in route_ids.size():
		var control := controls.get_node("PuzzleControl_"+route_ids[route_index]) as Node3D
		var approach: Vector3=control.get_meta("approach_position")
		var intended_front := (controls.to_global(approach)-control.global_position).normalized()
		var actual_front := (-control.global_basis.x).normalized()
		assert(actual_front.dot(intended_front)>.995,"Quest instrument faces away from its operator aisle: "+route_ids[route_index])
		assert(int(control.get_meta("quest_route_order",-1))==route_index+1,"Quest route order is discontinuous")
	for first_index in route_ids.size():
		for second_index in range(first_index+1,route_ids.size()):
			var first := controls.get_node("PuzzleControl_"+route_ids[first_index]) as Node3D
			var second := controls.get_node("PuzzleControl_"+route_ids[second_index]) as Node3D
			# Controls in separate departments can overlap in local coordinates but
			# never in the production world; therefore audit their global footprints.
			assert(first.global_position.distance_to(second.global_position)>6.0,
				"Quest instruments overlap: %s / %s"%[route_ids[first_index],route_ids[second_index]])
	print("QUEST_LAYOUT_AUDIT: 10/10 face operator aisle; clearance PASS")


func _capture_group(camera: Camera3D, controls: Node, ids: Array[String], offset: Vector3,
		file_name: String) -> void:
	var center := Vector3.ZERO
	for id in ids:
		center += (controls.get_node("PuzzleControl_"+id) as Node3D).global_position
	center /= float(ids.size())
	camera.global_position=center+offset
	camera.look_at(center+Vector3.UP*3.8,Vector3.UP)
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png("%s/%s"%[OUTPUT,file_name]) == OK)


func _add_lighting(world: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("07182b")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("c8e1df")
	environment.ambient_light_energy=.52
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled=true
	var world_environment := WorldEnvironment.new()
	world_environment.environment=environment
	world.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-48,-28,0)
	key.light_color=Color("ffe3b4")
	key.light_energy=1.25
	key.shadow_enabled=true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(22,145,0)
	fill.light_color=Color("88c9d2")
	fill.light_energy=.55
	world.add_child(fill)


func _add_hud(world: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer=20
	world.add_child(layer)
	var title := Label.new()
	title.position=Vector2(32,28)
	title.text="ISLAND ONE • PLAYER VIEW • QUEST INSTRUMENTS"
	title.add_theme_font_size_override("font_size",24)
	title.add_theme_color_override("font_color",Color("fff0cc"))
	layer.add_child(title)
	var instruction := Label.new()
	instruction.position=Vector2(32,650)
	instruction.text="WASD • MOVE     MOUSE • LOOK     Q • OPERATE"
	instruction.add_theme_font_size_override("font_size",22)
	instruction.add_theme_color_override("font_color",Color("8be0dc"))
	layer.add_child(instruction)
	var crosshair := Label.new()
	crosshair.position=Vector2(632,347)
	crosshair.text="+"
	crosshair.add_theme_font_size_override("font_size",30)
	crosshair.add_theme_color_override("font_color",Color.WHITE)
	layer.add_child(crosshair)
