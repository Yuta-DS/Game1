extends SceneTree
const STORE := "user://inspection_bay_capture.json"
func _init() -> void: call_deferred("run")
func run() -> void:
	var recorder_mode := "--recorder" in OS.get_cmdline_user_args()
	var tester_mode := "--tester" in OS.get_cmdline_user_args()
	var perspective_mode := "--perspective" in OS.get_cmdline_user_args()
	var projector_mode := "--projector" in OS.get_cmdline_user_args()
	if FileAccess.file_exists(STORE): DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	root.size = Vector2i(1280,720)
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = STORE
	world.get_node("QuestController").enabled = false
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("acc7cd")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d4e1dd")
	environment.environment.ambient_light_energy = .65
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-30,0)
	sun.light_color = Color("fff1d8")
	sun.light_energy = .85
	sun.shadow_enabled = true
	root.add_child(sun)
	var scanner := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.MEMORY_CONSTELLATION if recorder_mode else QuestObjectDefinition.ObjectKind.EVIDENCE_SCANNER)
	if tester_mode: scanner=world.get_object_by_kind(QuestObjectDefinition.ObjectKind.LOGIC_GATE_ARCH)
	if perspective_mode: scanner=world.get_object_by_kind(QuestObjectDefinition.ObjectKind.PERSPECTIVE_LENS)
	if projector_mode: scanner=world.get_object_by_kind(QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE)
	scanner.interaction_enabled = true
	var camera := Camera3D.new()
	camera.fov = 60
	camera.near = .05
	root.add_child(camera)
	camera.global_position = scanner.to_global(Vector3(0,2.5,9))
	camera.look_at(scanner.to_global(Vector3(0,2.4,0)))
	if "--planter" in OS.get_cmdline_user_args():
		var bed := world.get_node("GardenOfUnfinishedLight/ConservatoryOfPossibleTomorrow/ResearchPlanter_20") as Node3D
		camera.global_position=bed.to_global(Vector3(9,7,12))
		camera.look_at(bed.to_global(Vector3(0,1.7,0)))
		await create_timer(2).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/projector/research_planter.png"))
		world.queue_free()
		await process_frame
		print("RESEARCH_PLANTER_CAPTURE: native Compatibility detail review")
		quit()
		return
	if "--conservatory" in OS.get_cmdline_user_args():
		var gallery := world.get_node("GardenOfUnfinishedLight/ConservatoryOfPossibleTomorrow") as Node3D
		camera.global_position=gallery.to_global(Vector3(55,38,48))
		camera.look_at(gallery.to_global(Vector3(0,20,0)))
		await create_timer(2).timeout
		RenderingServer.force_draw(false)
		var destination := ProjectSettings.globalize_path("res://artifacts/projector/conservatory.png")
		root.get_texture().get_image().save_png(destination)
		world.queue_free()
		await process_frame
		print("CONSERVATORY_CAPTURE: native Compatibility architectural review, not player traversal")
		quit()
		return
	var out := ProjectSettings.globalize_path("res://artifacts/recorder_bay" if recorder_mode else "res://artifacts/inspection_bay")
	if tester_mode: out=ProjectSettings.globalize_path("res://artifacts/tester_bay")
	if perspective_mode: out=ProjectSettings.globalize_path("res://artifacts/perspective_bay")
	if projector_mode: out=ProjectSettings.globalize_path("res://artifacts/projector")
	DirAccess.make_dir_recursive_absolute(out)
	await create_timer(2).timeout
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out+"/front.png")
	camera.global_position = scanner.to_global(Vector3(0,1.7,4.5))
	camera.look_at(scanner.to_global(Vector3(0,1.8,0)))
	if projector_mode:
		scanner.interact(&"approach",0)
	elif perspective_mode:
		scanner.interact(&"view",0)
	elif tester_mode:
		scanner.interact(&"model",1)
		scanner.interact(&"trial",0)
	elif recorder_mode:
		scanner.interact(&"replay")
	else:
		for i in 2: scanner.interact(&"adjust",0)
	await create_timer(.5).timeout
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out+"/player.png")
	var actor := Node3D.new()
	world.add_child(actor)
	actor.global_position = camera.global_position - Vector3.UP * 1.7
	var panel := preload("res://scripts/mind_spark/island_two_station_panel.gd").new()
	world.add_child(panel)
	panel.open_object(scanner,actor,18)
	await create_timer(.5).timeout
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out+"/controls.png")
	panel.queue_free()
	await process_frame
	if projector_mode:
		for approach in [1,2]:
			scanner.interact(&"approach",approach)
			await create_timer(1.2).timeout
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(out+"/approach_%d.png"%approach)
		scanner.interact(&"approach",0)
		for channel in [0,0,1]:
			assert(scanner.interact(&"tune",channel).accepted)
		assert(scanner.interact(&"project").accepted)
		await create_timer(1.5).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(out+"/restored.png")
	if perspective_mode:
		for view in [1,2]:
			scanner.interact(&"view",view)
			await create_timer(1.5).timeout
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(out+"/view_%d.png"%view)
	if tester_mode:
		scanner.interact(&"trial",1)
		await create_timer(1.5).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(out+"/bypass_open.png")
	world.queue_free()
	await process_frame
	if FileAccess.file_exists(STORE): DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	print("INSPECTION_BAY_CAPTURE: Compatibility/native render, not browser verification")
	quit()
