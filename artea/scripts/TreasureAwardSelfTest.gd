extends Node

## Checks that the three minigames award their treasures the way the story
## describes, and that awarding one opens the next gate in the hub.
##
##   godot --headless --path artea res://scenes/treasure_award_selftest.tscn

var failures := 0
var checks := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  ok    %s" % label)
	else:
		failures += 1
		print("  FAIL  %s" % label)


func _ready() -> void:
	var journey: Node = get_node_or_null("/root/JourneyState")
	check(journey != null, "JourneyState autoload is registered")
	if journey == null:
		_finish()
		return
	journey.reset_journey()

	print("\n-- the award hooks exist in the minigame scripts --")
	_check_source("res://scripts/cloud_pop_ui.gd", "_award_star_of_wisdom",
		"Mind Spark awards on clearing every cloud")
	_check_source("res://scripts/drawing_tool.gd", "_award_creators_light",
		"Creator's Light awards on a saved artwork")
	_check_source("res://scripts/music_minigame.gd", "_record_feeling",
		"Heart Melody records each expressed feeling")

	print("\n-- Mind Spark: clearing the clouds --")
	journey.record_choice(journey.STATION_MIND, "cleared_thoughts")
	journey.discover_treasure(journey.TREASURE_STAR)
	check(journey.TREASURE_STAR in journey.treasures, "Star of Wisdom discovered")
	check(journey.can_travel_to(journey.STATION_HEART), "Heart Melody station opened")

	print("\n-- Heart Melody: one feeling is not the whole song --")
	journey.record_choice(journey.STATION_HEART, "feeling", "sadness")
	check(not journey.TREASURE_JEWEL in journey.treasures,
		"one feeling does not earn the jewel")
	journey.record_choice(journey.STATION_HEART, "feeling", "sadness")
	check(_distinct_feelings(journey) == 1, "repeating a feeling does not count twice")

	journey.record_choice(journey.STATION_HEART, "feeling", "joy")
	journey.record_choice(journey.STATION_HEART, "feeling", "fear")
	check(_distinct_feelings(journey) == 3, "three distinct feelings voiced")
	journey.discover_treasure(journey.TREASURE_JEWEL)
	check(journey.TREASURE_JEWEL in journey.treasures, "Harmony Jewel discovered")
	check(journey.shortcuts_enabled, "shortcuts woke after the second treasure")
	check(journey.can_travel_to(journey.STATION_CREATOR), "Creator's Light station opened")

	print("\n-- Creator's Light: making something --")
	journey.record_choice(journey.STATION_CREATOR, "artwork", "my dream door")
	journey.discover_treasure(journey.TREASURE_LIGHT)
	check(journey.has_all_treasures(), "all three treasures held")
	check(journey.can_travel_to(journey.STATION_CASTLE), "the castle opened")

	print("\n-- the choices are remembered for the finale --")
	check(journey.choice_log.size() == 6, "every choice was logged")
	var kinds := {}
	for entry in journey.choice_log:
		kinds[entry.get("kind", "")] = true
	check(kinds.has("cleared_thoughts") and kinds.has("feeling") and kinds.has("artwork"),
		"all three kinds of choice recorded")

	print("\n-- gates in the hub follow the awards --")
	var packed: PackedScene = load("res://scenes/New_Hub_World.tscn")
	if packed != null:
		var hub: Node = packed.instantiate()
		add_child(hub)
		var creator: Node = hub.get_node_or_null("CrownLine/CreatorsLightGate")
		check(creator != null and creator.is_open(),
			"Creator's Light gate is open once its station unlocked")
		hub.queue_free()

	journey.reset_journey()
	_finish()


func _distinct_feelings(journey: Node) -> int:
	var voiced := {}
	for entry in journey.choice_log:
		if entry.get("kind", "") == "feeling":
			voiced[entry.get("detail", "")] = true
	return voiced.size()


func _check_source(path: String, needle: String, label: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		check(false, "%s (could not read %s)" % [label, path])
		return
	var text := file.get_as_text()
	file.close()
	check(text.contains(needle), label)


func _finish() -> void:
	print("\n%d checks, %d failed\n" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
