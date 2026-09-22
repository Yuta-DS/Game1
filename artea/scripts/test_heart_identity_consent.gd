extends SceneTree
var failures: Array[String] = []
var world
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("FAIL: " + label)
func run() -> void:
	var tracker = root.get_node("PlayerIdentityTracker")
	tracker.save_path = "user://heart_consent_test.json"
	tracker.clear_evidence()
	tracker.record_evidence("existing_mind", "energy", "I")
	world = load("res://scenes/heart_melody/heart_melody_world.tscn").instantiate()
	world.test_mode = true
	world.progress.path = "user://heart_consent_world.json"
	root.add_child(world)
	for index in 4:
		world._identity(index)
		press("Skip")
		world._identity(index)
		press("Keep private — record nothing")
	check(tracker.evidence.size() == 1, "all skip/private actions record nothing")
	var answers := ["Talk together first", "Notice one individual sound", "Try a clear sequence", "Plan my phrase first"]
	for index in 4:
		world._identity(index)
		press(answers[index])
		check(tracker.evidence["HM_ID_%02d" % (index + 1)].world_id == "heart_melody", "explicit answer attributed to Heart")
	check(tracker.evidence.existing_mind.world_id == "mind_spark", "default world remains Mind Spark")
	check(tracker.identity_result_code.is_empty() and not tracker.identity_reveal_seen, "Heart does not reveal a result")
	check(world.progress.data.xp == 0 and world.progress.data.planters.is_empty(), "identity is reward neutral")
	var progress = load("res://scripts/heart_melody/heart_progress.gd").new()
	progress.plant(0, 6)
	progress.plant(1, 6)
	root.get_node("JourneyState").clear_journey()
	check(not FileAccess.file_exists(progress.path) and not FileAccess.file_exists(progress.path + ".bak"), "clear journey erases primary and backup Heart saves")
	check(tracker.evidence.size() == 1 and tracker.has_evidence("existing_mind"), "Heart erase preserves Mind Spark evidence")
	world.queue_free()
	await process_frame
	print("HEART CONSENT: all checks passed" if failures.is_empty() else "HEART CONSENT FAILURES: " + str(failures))
	quit(0 if failures.is_empty() else 1)
func press(title: String) -> void:
	for node in world.options.find_children("*", "Button", true, false):
		if node.text == title:
			node.pressed.emit()
			return
	check(false, "button exists " + title)
