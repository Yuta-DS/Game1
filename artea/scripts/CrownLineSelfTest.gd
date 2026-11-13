extends Node

## Boot-time self-check for the Crown Line nodes in New_Hub_World.
##
## Runs as a normal scene (so addons and autoloads are alive) rather than via
## --script, which starts before either exists:
##
##   godot --headless --path artea res://scenes/crown_line_selftest.tscn

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
	print("\n-- autoload --")
	var journey: Node = get_node_or_null("/root/JourneyState")
	check(journey != null, "JourneyState autoload is registered")
	if journey == null:
		_finish()
		return

	journey.reset_journey()

	print("\n-- loading New_Hub_World.tscn --")
	var packed: PackedScene = load("res://scenes/New_Hub_World.tscn")
	check(packed != null, "hub scene loaded")
	if packed == null:
		_finish()
		return

	var hub: Node = packed.instantiate()
	check(hub != null, "hub scene instantiated")
	if hub == null:
		_finish()
		return
	add_child(hub)

	print("\n-- Crown Line nodes --")
	check(hub.get_node_or_null("CrownLine") != null, "CrownLine exists")
	check(hub.get_node_or_null("CrownLine/GalleryStation") != null, "GalleryStation exists")

	var expected := {
		"MindSparkGate": "mind_spark",
		"HeartMelodyGate": "heart_melody",
		"CreatorsLightGate": "creators_light",
	}
	var gates := {}
	for gate_name in expected:
		var gate: Node = hub.get_node_or_null("CrownLine/%s" % gate_name)
		check(gate != null, "%s exists" % gate_name)
		if gate == null:
			continue
		gates[gate_name] = gate
		check(gate.get_script() != null, "%s carries the StationGate script" % gate_name)
		check(gate.station_id == expected[gate_name],
			"%s points at '%s'" % [gate_name, expected[gate_name]])
		check(gate.get_node_or_null("CollisionShape3D") != null, "%s has a collision shape" % gate_name)
		check(gate.get_node_or_null("GateLight") != null, "%s has a gate light" % gate_name)

	if gates.size() == 3:
		print("\n-- the gates form a compass around the castle --")
		var mind: Node3D = gates["MindSparkGate"]
		var heart: Node3D = gates["HeartMelodyGate"]
		var creator: Node3D = gates["CreatorsLightGate"]
		check(mind.position.z < -100, "Mind Spark lies north")
		check(heart.position.x > 100, "Heart Melody lies east")
		check(creator.position.z > 100, "Creator's Light lies south")

		print("\n-- gates follow the journey --")
		check(mind.is_open(), "Mind Spark is open from the beginning")
		check(not heart.is_open(), "Heart Melody is shut")
		check(not creator.is_open(), "Creator's Light is shut")

		journey.discover_treasure(journey.TREASURE_STAR)
		check(heart.is_open(), "Heart Melody opens after world one")
		check(not creator.is_open(), "Creator's Light is still shut")

		journey.discover_treasure(journey.TREASURE_JEWEL)
		check(creator.is_open(), "Creator's Light opens after world two")

	journey.reset_journey()
	_finish()


func _finish() -> void:
	print("\n%d checks, %d failed\n" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
