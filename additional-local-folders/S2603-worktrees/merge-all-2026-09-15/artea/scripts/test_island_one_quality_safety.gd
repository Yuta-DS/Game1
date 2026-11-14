extends SceneTree
const STORE := "user://test_island_one_quality_safety.json"
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if FileAccess.file_exists(STORE): DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud=false
	world.object_state_store_path=STORE
	world.get_node("QuestController").enabled=false
	root.add_child(world)
	var actor := load("res://scenes/player_3d.tscn").instantiate() as CharacterBody3D
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.global_position=Vector3(0,2000,0)
	for i in 8: await physics_frame
	var gate := world.get_island_one_heavenly_star_gate()
	var left := gate.get_node("WestGoldenStarLeaf") as Node3D
	# Real player capsule placed at a future point in the leaf's opening arc.
	var occupied := Transform3D(Basis(Vector3.UP,deg_to_rad(-45)),left.position)*Vector3(2.68,4,0)
	actor.global_position=gate.to_global(occupied)
	for i in 3: await physics_frame
	world.call("_set_island_one_star_gate_open",true,true)
	await create_timer(2.5).timeout
	assert(gate.get_meta("gate_state")=="obstructed","Opening must stop before occupied sweep")
	var held := left.rotation.y
	await create_timer(.2).timeout
	assert(is_equal_approx(left.rotation.y,held))
	actor.global_position=Vector3(0,2000,0)
	await create_timer(2.1).timeout
	assert(gate.get_meta("gate_state")=="open")
	actor.global_position=gate.to_global(occupied)
	for i in 3: await physics_frame
	world.call("_set_island_one_star_gate_open",false,true)
	await create_timer(2.5).timeout
	assert(gate.get_meta("gate_state")=="obstructed","Closing must stop before occupied sweep")
	actor.global_position=Vector3(0,2000,0)
	await create_timer(2.1).timeout
	assert(gate.get_meta("gate_state")=="sealed")
	var puzzle := world.get_island_one_puzzle()
	var controls := puzzle.get_node("PuzzleControls")
	var walked := 0
	for control in controls.get_children():
		if not control.has_node("InspectionAnchor"): continue
		var from := control.get_node("InspectionAnchor").global_position as Vector3
		var floor_hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from+Vector3.UP*3,from-Vector3.UP*15))
		assert(not floor_hit.is_empty())
		actor.global_position=floor_hit.position+Vector3.UP*1.1
		await physics_frame
		var direction: Vector3=control.global_position-actor.global_position
		direction.y=0
		var hit: KinematicCollision3D
		for step in 30:
			hit=actor.move_and_collide(direction.normalized()*.4)
			if hit!=null: break
			await physics_frame
		assert(hit!=null,"Player passes through "+str(control.name))
		assert(control.is_ancestor_of(hit.get_collider()),"Unexpected obstacle before "+str(control.name)+": "+str(hit.get_collider().get_path()))
		walked+=1
	assert(walked==16)
	var cabinet_count := 0
	for station in world.get_quest_objects():
		if not station.has_node("CampusSolidCabinet"): continue
		actor.global_position=Vector3(0,2000,0)
		var start := station.to_global(Vector3(0,0,3))
		var floor_hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start+Vector3.UP*6,start-Vector3.UP*15))
		assert(not floor_hit.is_empty(),"Missing helper approach floor: "+station.save_id)
		actor.global_position=floor_hit.position+Vector3.UP*1.1
		await physics_frame
		var direction: Vector3=station.global_position-actor.global_position
		direction.y=0
		var hit: KinematicCollision3D
		for step in 45:
			hit=actor.move_and_collide(direction.normalized()*.4)
			if hit!=null: break
			await physics_frame
		assert(hit!=null and station.is_ancestor_of(hit.get_collider()),"Non-solid campus helper: "+station.save_id)
		cabinet_count+=1
	assert(cabinet_count==4)
	actor.global_position=controls.get_node("PuzzleControl_echo_signal_1/InspectionAnchor").global_position
	assert(puzzle.solve_for_test().reason=="completed")
	# Exercise the real accessible panel at a narrow viewport and preserve focus.
	root.size=Vector2i(480,640)
	var panel = load("res://scripts/mind_spark/quest_station_panel.gd").new()
	world.add_child(panel)
	panel.open(puzzle,actor,"echo_signal_1")
	for i in 5: await process_frame
	assert(panel._panel.position.x>=0 and panel._panel.get_rect().end.x<=480)
	assert(panel._panel.get_rect().end.y<=640)
	assert(panel._scroll!=null)
	var first := panel._body.get_node(panel._body.get_children().filter(func(node): return node is Button)[0].get_path()) as Button
	first.pressed.emit()
	for i in 3: await process_frame
	assert(root.gui_get_focus_owner().get_meta("focus_action","")=="classify0")
	panel.queue_free()
	await process_frame
	world.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	print("ISLAND_ONE_QUALITY_SAFETY: PASS — occupied opening/closing stop and resume, 16 instruments + 4 helpers block real player, narrow panel fits and preserves focus")
	quit()
