extends Node

## Checks the Rainbow Galaxy Train obeys the story's railway rules.
##
##   godot --headless --path artea res://scenes/galaxy_train_selftest.tscn

const TrainScript := preload("res://scripts/GalaxyTrain.gd")

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

	var train: Node3D = TrainScript.new()
	add_child(train)
	train.current_station = "gallery"

	print("\n-- at the start, the wheel offers only Mind Spark --")
	var dests: Array = train.available_destinations()
	check(dests == ["mind_spark"], "only Mind Spark is on the dial")
	check(not train.turn_wheel_to("heart_melody"), "the wheel refuses a sleeping station")
	check(not train.turn_wheel_to("castle"), "the wheel refuses the castle")
	check(train.turn_wheel_to("mind_spark"), "the wheel turns to Mind Spark")

	# Lambdas capture locals by value in GDScript, so signal results are
	# collected in a dictionary, which is captured by reference.
	var seen := {"arrived_at": "", "rang": false}
	train.arrived.connect(func(s): seen["arrived_at"] = s)
	train.bell_rung.connect(func(): seen["rang"] = true)

	print("\n-- the ride is a real journey, not a jump --")
	check(train.depart(), "the train departs")
	check(train.is_travelling(), "the train is moving")
	check(train.journey_progress() < 1.0, "it does not arrive instantly")

	# A short ride so the test does not idle: 1 second at full speed.
	train.base_journey_time = 1.0
	train.set_speed(2.0)
	var moved_at_full := await _advance(train, 0.6)

	print("\n-- the brake slows the ride down --")
	train.progress = 0.0
	train.set_brake(true)
	var moved_braking := await _advance(train, 0.6)
	check(moved_braking < moved_at_full, "braking covers less ground than full speed")
	train.set_brake(false)

	print("\n-- arriving --")
	# The brake run may already have completed the ride, so start a fresh one.
	train.current_station = "gallery"
	seen["arrived_at"] = ""
	check(train.turn_wheel_to("mind_spark"), "the wheel turns for a fresh ride")
	check(train.depart(), "the train departs again")
	await _advance(train, 2.0)
	check(not train.is_travelling(), "the train has stopped")
	check(seen["arrived_at"] == "mind_spark", "it announced arriving at Mind Spark")
	check(train.current_station == "mind_spark", "the train is standing at Mind Spark")

	print("\n-- before the shortcuts wake, the route is the main line --")
	var from_mind: Array = train.available_destinations()
	check(from_mind == ["gallery"], "from a kingdom the train returns to the Gallery")

	print("\n-- treasures put new symbols on the dial --")
	journey.discover_treasure(journey.TREASURE_STAR)
	train.current_station = "gallery"
	check(train.available_destinations() == ["heart_melody"],
		"the Gallery now offers Heart Melody")

	journey.discover_treasure(journey.TREASURE_JEWEL)
	var open_now: Array = train.available_destinations()
	check(journey.shortcuts_enabled, "the shortcut lines woke up")
	check(open_now.size() >= 3, "the wheel now offers every open station")
	check(not "gallery" in open_now, "the train is not offered its own station")

	print("\n-- the bell and Milo --")
	seen["rang"] = false
	train.ring_bell()
	check(seen["rang"], "the light bell rings")

	train.destination = ""
	train.set_milo_driving(true)
	check(train.milo_driving, "Milo takes the controls")
	check(train.destination == journey.next_story_station(),
		"Milo steers towards the next stop in the story")

	journey.reset_journey()
	train.queue_free()
	_finish()


## Runs the train for `seconds` of game time and reports how far it moved.
func _advance(train: Node3D, seconds: float) -> float:
	var before: float = train.journey_progress()
	var elapsed := 0.0
	while elapsed < seconds and train.is_travelling():
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return train.journey_progress() - before


func _finish() -> void:
	print("\n%d checks, %d failed\n" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
