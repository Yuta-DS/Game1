extends SceneTree

const STORE := "user://test_island_one_research_campus.json"
const OUTPUT := "res://artifacts/island_one_research_campus"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if FileAccess.file_exists(STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud=false
	world.object_state_store_path=STORE
	world.get_node("QuestController").enabled=false
	root.add_child(world)
	for frame in 8: await physics_frame
	var puzzle := world.get_island_one_puzzle()
	var campus := world.get_node("IslandOneResearchCampus")
	# Duplicate noninteractive checkpoint benches were intentionally retired;
	# unique functional quest instruments now define the research route.
	assert(campus.find_children("*SampleBench*","Node3D",false,false).is_empty())
	var zones: Dictionary=world.get("_zone_nodes")
	var garden: Node3D=zones["02_living_network_forest"]
	var arrival: Node3D=zones["01_world_gate_landing"]
	var controls := puzzle.get_node("PuzzleControls")
	var spark_socket: QuestObjectBase
	for station in world.get_quest_objects():
		if station.save_id == "world_one.spark_socket":
			spark_socket=station
			break
	assert(spark_socket != null)
	assert(spark_socket.get_node_or_null("VisualRoot/CampusSparkReceiver") is Node3D)
	var legacy_socket := spark_socket.get_node_or_null("VisualRoot/BlenderModel") as Node3D
	assert(legacy_socket != null and not legacy_socket.visible,
		"obsolete socket ring/circuit model must be hidden")
	assert(spark_socket.interact().accepted,
		"redesigned Spark Receiver must retain the existing deposit interaction")
	var charge_cell := spark_socket.get_node("VisualRoot/CampusSparkReceiver/ChargeCell_01") as MeshInstance3D
	assert(charge_cell.material_override == charge_cell.get_meta("active_material"),
		"first deposited Spark lights the redesigned receiver cell")
	var legacy_gameplay := world.find_child("MSI1_Runtime_Gameplay",true,false) as MeshInstance3D
	assert(legacy_gameplay != null and not legacy_gameplay.visible,
		"legacy green line/ring/gold-track overlay must remain hidden")
	assert(world.find_child("FibreRoot", true, false) == null,
		"obsolete raised green FibreRoot bars must not be built on the finished garden deck")
	assert(world.get_node_or_null("WorldOneGeometry/MindSparkTransitNetwork") == null,
		"retired cyan transit pad and violet/cyan shortcut ring must not be built")
	var actor := Node3D.new()
	world.add_child(actor)
	var checked := 0
	for control in controls.get_children():
		if not control.has_meta("approach_position"): continue
		checked+=1
		var front: Vector3=control.basis*Vector3.LEFT
		var approach: Vector3=control.get_meta("approach_position")-control.position
		approach.y=0
		assert(front.dot(approach.normalized())>.999,"Wrong station facing: "+str(control.name))
		var anchor := control.get_node("InspectionAnchor") as Node3D
		actor.global_position=anchor.global_position
		assert(puzzle.nearest_control(actor)==control,"Approach selects another station: "+str(control.name))
		var local_garden := garden.to_local(control.global_position)
		if str(control.name).contains("echo_"):
			assert(Vector2(local_garden.x,local_garden.z).length()<120,"Echo station outside garden deck")
			assert(control.global_position.distance_to(garden.global_position)<control.global_position.distance_to(arrival.global_position))
		# Verify actual physics support below the operator, not just decorative art.
		var foot := anchor.global_position
		var query := PhysicsRayQueryParameters3D.create(foot+Vector3.UP*3,foot-Vector3.UP*15)
		var floor_hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		assert(not floor_hit.is_empty(),"No walkable foundation at "+str(control.name))
		assert(floor_hit.normal.y>.65,"Operator stands on steep geometry: "+str(control.name))
		var capsule := CapsuleShape3D.new()
		capsule.radius=.6
		capsule.height=2.2
		var body_query := PhysicsShapeQueryParameters3D.new()
		body_query.shape=capsule
		body_query.transform.origin=floor_hit.position+Vector3.UP*1.3
		var obstacles := world.get_world_3d().direct_space_state.intersect_shape(body_query)
		assert(obstacles.is_empty(),"Operator capsule blocked at "+str(control.name)+": "+str(obstacles))
	assert(checked==16)
	for id in ["colour","rhythm","weight"]:
		var output := controls.get_node("PuzzleControl_%s_prism/EnergyOutputAnchor"%id) as Node3D
		var pulse := puzzle.get_node("LivingLightLaboratoryRoutes/LightBeamPulse_%s_0_A"%id)
		assert((pulse.get_meta("path_start") as Vector3).distance_to(puzzle.to_local(output.global_position))<.01)
	var echo := puzzle.get_node("EchoGardenQuestArchitecture") as Node3D
	assert(garden.to_local(echo.to_global(Vector3(-52,0,24))).distance_to(Vector3(-28,0,40))<.01)
	assert(not world.is_island_one_star_gate_open())
	for operation in [["colour_prism",1],["rhythm_prism",2],["weight_prism",3],["analysis_console",1],["west_regulator",1],["east_regulator",2],["outer_ring",3],["middle_ring",2],["inner_ring",1],["confirm",1]]:
		var control := controls.get_node("PuzzleControl_"+operation[0]) as Node3D
		actor.global_position=(control.get_node("InspectionAnchor") as Node3D).global_position
		for press in int(operation[1]):
			assert(puzzle.interact_nearest(actor).accepted)
	assert(world.is_island_one_star_gate_open())
	assert(not world.is_quest_gate_open(0))
	actor.global_position=controls.get_node("PuzzleControl_echo_collector/InspectionAnchor").global_position
	assert(puzzle.interact_nearest(actor).accepted)
	assert(puzzle.get_puzzle_state().prism_installed)
	if "--capture" in OS.get_cmdline_user_args():
		if not await _screenshots(world,arrival,garden,puzzle):
			quit(1)
			return
	# Optional reasoning is exercised through the same controls as the player UI.
	actor.global_position=controls.get_node("PuzzleControl_echo_signal_1/InspectionAnchor").global_position
	var panel = load("res://scripts/mind_spark/quest_station_panel.gd").new()
	world.add_child(panel)
	panel.open(puzzle,actor,"echo_signal_1")
	for i in 3: await process_frame
	var challenge = panel._body.get_children().filter(func(node): return node is CheckButton)[0]
	challenge.toggled.emit(true)
	for i in 3: await process_frame
	var prediction = panel._body.get_children().filter(func(node): return node is OptionButton)[0]
	prediction.item_selected.emit(4) # Initial phase zero + three = notch four.
	var gear = panel._body.get_children().filter(func(node): return node.get_meta("focus_action","")=="tune3")[0]
	gear.pressed.emit()
	for i in 3: await process_frame
	assert(panel._feedback.begins_with("Prediction matched"))
	panel.queue_free()
	world.queue_free()
	await process_frame
	# Let the audio mixer consume deferred playback releases after scene teardown.
	await create_timer(.2).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	print("ISLAND_ONE_RESEARCH_CAMPUS: PASS — 16 oriented stations, operator floor support/proximity, garden relocation, beam endpoints, Q1-to-Q2 access, external gate locked")
	quit()

func _screenshots(world: Node3D, arrival: Node3D, garden: Node3D, puzzle: Node3D) -> bool:
	root.size=Vector2i(1280,720)
	root.msaa_3d=Viewport.MSAA_4X
	var containing=load("res://scenes/art_castle_floating_world.tscn").instantiate()
	for name in ["WorldEnvironment","Sun","FillLight"]:
		var light=containing.get_node(name)
		containing.remove_child(light)
		light.owner=null
		root.add_child(light)
	containing.free()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov=58
	camera.far=4000
	camera.make_current()
	for entry in [["part_1",arrival,Vector3(-140,155,190),Vector3(0,8,0)],["part_2",garden,Vector3(-155,150,185),Vector3(-22,8,24)]]:
		camera.global_position=entry[1].to_global(entry[2])
		camera.look_at(entry[1].to_global(entry[3]))
		await create_timer(1).timeout
		RenderingServer.force_draw(false)
		if root.get_texture().get_image().save_png(OUTPUT+"/"+entry[0]+".png")!=OK: return false
	for id in ["colour_prism","echo_collector","echo_signal_2"]:
		var control := puzzle.get_node("PuzzleControls/PuzzleControl_"+id) as Node3D
		camera.global_position=control.get_node("InspectionAnchor").global_position
		camera.look_at(control.to_global(Vector3(0,2,0)))
		await create_timer(1).timeout
		RenderingServer.force_draw(false)
		if root.get_texture().get_image().save_png(OUTPUT+"/"+id+".png")!=OK: return false
	var bench := world.get_node("IslandOneResearchCampus/LivingResearchGardenSampleBench0") as Node3D
	camera.global_position=bench.to_global(Vector3(0,6,17))
	camera.look_at(bench.to_global(Vector3(0,5,0)))
	await create_timer(1).timeout
	RenderingServer.force_draw(false)
	if root.get_texture().get_image().save_png(OUTPUT+"/laboratory_bench.png")!=OK: return false
	var manifold := puzzle.get_node("EchoGardenQuestArchitecture/GardenReceivingManifold") as Node3D
	camera.global_position=manifold.to_global(Vector3(-8,5,9))
	camera.look_at(manifold.to_global(Vector3(0,1,0)))
	await create_timer(1).timeout
	RenderingServer.force_draw(false)
	if root.get_texture().get_image().save_png(OUTPUT+"/garden_manifold.png")!=OK: return false
	var spark_socket: QuestObjectBase
	for station in world.get_quest_objects():
		if station.save_id == "world_one.spark_socket":
			spark_socket=station
			break
	assert(spark_socket != null)
	camera.global_position=spark_socket.to_global(Vector3(3.2,2.4,-3.8))
	camera.look_at(spark_socket.to_global(Vector3(0,.78,0)))
	await create_timer(1).timeout
	RenderingServer.force_draw(false)
	if root.get_texture().get_image().save_png(OUTPUT+"/spark_receiver.png")!=OK: return false
	var control := puzzle.get_node("PuzzleControls/PuzzleControl_echo_signal_1") as Node3D
	camera.global_position=control.get_node("InspectionAnchor").global_position
	camera.look_at(control.to_global(Vector3(0,2,0)))
	var panel = load("res://scripts/mind_spark/quest_station_panel.gd").new()
	world.add_child(panel)
	panel.open(puzzle,camera,"echo_signal_1")
	await create_timer(1).timeout
	RenderingServer.force_draw(false)
	if root.get_texture().get_image().save_png(OUTPUT+"/quest_panel.png")!=OK: return false
	root.size=Vector2i(480,640)
	await create_timer(1).timeout
	RenderingServer.force_draw(false)
	if root.get_texture().get_image().save_png(OUTPUT+"/quest_panel_narrow.png")!=OK: return false
	panel.queue_free()
	return true
