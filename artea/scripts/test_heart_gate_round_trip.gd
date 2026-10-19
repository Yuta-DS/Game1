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
	state.treasures["harmony_jewel"] = false
	var progress = load("res://scripts/heart_melody/heart_progress.gd").new()
	progress.data = progress.fresh()
	check(progress.plant(0, 6), "prepare committed seed")
	var fixture := Node3D.new()
	root.add_child(fixture)
	current_scene = fixture
	var gate = load("res://scenes/mind_spark/world_gate.tscn").instantiate()
	gate.target_kingdom_id = "heart"
	gate.target_world_path = NodePath()
	fixture.add_child(gate)
	var player := CharacterBody3D.new()
	fixture.add_child(player)
	check(not gate.teleport_player(player), "Heart gate enforces Mind Spark completion")
	check(current_scene == fixture, "locked Heart gate keeps the current world active")
	state.treasures["star_of_wisdom"] = true
	check(gate.teleport_player(player), "real World Gate accepts the unlocked Heart destination")
	for frame in 10: await process_frame
	var heart = current_scene
	check(heart != null and heart.scene_file_path == "res://scenes/heart_melody/heart_garden_entry.tscn",
		"real gate loads the canonical Heart entry scene")
	progress.load_progress()
	check(progress.data.planters.has("0") and not progress.data.complete,
		"Heart entry preserves committed seed without completing the island")
	check(not state.has_treasure("harmony_jewel") and not root.get_node("JourneyCampaign").can_enter_kingdom("creator"),
		"travel cannot award Jewel or Creator access")
	print("HEART GATE ROUTING: all checks passed" if failures.is_empty() else "HEART GATE FAILURES: " + str(failures))
	quit(0 if failures.is_empty() else 1)
