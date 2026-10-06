extends SceneTree
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("FAIL: " + label)
func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("Heart gate test timed out"); quit(1))
	var state = root.get_node("JourneyState")
	state.treasures["star_of_wisdom"] = false
	var progress = load("res://scripts/heart_melody/heart_progress.gd").new()
	progress.data = progress.fresh()
	check(progress.plant(0, 6), "prepare committed seed")
	var fixture := Node3D.new()
	root.add_child(fixture)
	current_scene = fixture
	var gate = load("res://scenes/mind_spark/world_gate.tscn").instantiate()
	gate.target_kingdom_id = "heart_melody"
	gate.target_world_path = NodePath()
	fixture.add_child(gate)
	var player := CharacterBody3D.new()
	fixture.add_child(player)
	check(gate.teleport_player(player), "real World Gate accepts Heart destination")
	check(not state.has_treasure("star_of_wisdom"), "Heart entry does not fabricate Mind Spark completion")
	# Allow the normal gravity contract to settle the capsule from its 2 m spawn.
	for frame in 60: await physics_frame
	var heart = current_scene
	check(heart != null and heart.scene_file_path == "res://scenes/heart_melody/heart_melody_world.tscn", "real gate loads Heart without a Mind Spark builder")
	if heart == null or not heart.has_method("_close"):
		quit(1)
		return
	check(heart.progress.data.planters.has("0"), "gate entry restores committed seed")
	heart._close()
	check(heart.player.input_enabled and heart.camera.current, "entry restores camera and controls")
	check(heart.player.is_on_floor() and heart.player.position.x > -70, "safe landing is outside return gate")
	heart.player.position = Vector3(-71, 1.1, 12)
	heart._process(0)
	heart._interact_nearest()
	var castle_ready := false
	for frame in 1800:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/art_gallery_3d_inprogress.tscn":
			castle_ready = true
			break
	check(castle_ready, "Castle return loads the actual campaign scene")
	progress.load_progress()
	check(progress.data.planters.has("0") and not progress.data.complete, "early Castle return preserves seed without completing island")
	check(not state.has_treasure("harmony_jewel") and not root.get_node("JourneyCampaign").can_enter_kingdom("creator"), "travel cannot award Jewel or Creator access")
	print("HEART GATE ROUND TRIP: all checks passed" if failures.is_empty() else "HEART GATE FAILURES: " + str(failures))
	quit(0 if failures.is_empty() else 1)
