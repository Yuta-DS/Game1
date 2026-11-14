extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("FAIL: " + label)

func run() -> void:
	var state := root.get_node("JourneyState")
	state.treasures["star_of_wisdom"] = false
	state.treasures["harmony_jewel"] = false
	check(change_scene_to_file("res://scenes/start_screen.tscn") == OK, "start screen loads")
	for frame in 180:
		await process_frame
		if current_scene != null: break
	check(current_scene != null, "start screen becomes current scene")
	if current_scene == null:
		quit(1)
		return
	var menu := current_scene.get_node("AnimationParent/CenterContainer/PanelContainer/VBoxContainer")
	check(menu.get_node_or_null("VisitHeartMelodyButton") == null,
		"start screen does not expose a direct Heart Melody option")
	check(menu.get_node_or_null("Button") is Button and menu.get_node_or_null("RegisterButton") is Button
		and menu.get_node_or_null("GuestButton") is Button,
		"standard start-screen options remain available")
	check(not state.has_treasure("star_of_wisdom") and not state.has_treasure("harmony_jewel"),
		"opening the start screen awards no unrelated treasure")
	print("START SCREEN HEART OPTION: all checks passed" if failures.is_empty() else "START SCREEN HEART OPTION FAILURES: " + str(failures))
	quit(0 if failures.is_empty() else 1)
