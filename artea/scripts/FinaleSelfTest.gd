extends Node

## Checks the castle finale and the train-boarding flow.
##
##   godot --headless --path artea res://scenes/finale_selftest.tscn

const FinaleScript := preload("res://scripts/CastleFinale.gd")

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

	print("\n-- the castle waits until every treasure is found --")
	var finale: Node3D = FinaleScript.new()
	finale.gathering_time = 0.05
	add_child(finale)
	check(not finale.can_begin(), "the finale will not start empty-handed")
	check(not finale.begin(), "beginning early is refused")
	check(finale.celebration_route().is_empty(), "no celebration route yet")

	journey.discover_treasure(journey.TREASURE_STAR)
	journey.discover_treasure(journey.TREASURE_JEWEL)
	check(not finale.can_begin(), "two treasures are still not enough")

	journey.discover_treasure(journey.TREASURE_LIGHT)
	check(finale.can_begin(), "all three treasures open the finale")

	print("\n-- the treasures join into the Light of Identity --")
	var seen := {"gathered": false, "formed": false, "offered": []}
	finale.treasures_gathered.connect(func(): seen["gathered"] = true)
	finale.light_of_identity_formed.connect(func(): seen["formed"] = true)
	finale.identities_offered.connect(func(o): seen["offered"] = o)

	check(finale.begin(), "the finale begins")
	check(seen["gathered"], "the treasures gathered")
	var waited := 0.0
	while not seen["formed"] and waited < 2.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	check(seen["formed"], "the Light of Identity formed")

	print("\n-- the game offers identities, it does not assign one --")
	var options: Array = seen["offered"]
	check(options.size() == 3, "three identities were offered")
	check(options.all(func(o): return o.has("name") and o.has("purpose")),
		"each option carries a name and a purpose")
	check(journey.identity == "", "no identity was chosen for the player")

	print("\n-- the reading follows how the player actually played --")
	journey.reset_journey()
	journey.discover_treasure(journey.TREASURE_STAR)
	journey.discover_treasure(journey.TREASURE_JEWEL)
	journey.discover_treasure(journey.TREASURE_LIGHT)
	for i in 5:
		journey.record_choice("creators_light", "artwork", "picture %d" % i)
	var arty: Array = finale.offer_identities()
	var arty_ids: Array = arty.map(func(o): return o["id"])
	check(arty_ids.any(func(id): return id in ["joyful_creator", "silent_artist", "radiant_star"]),
		"a player who mostly made art is offered a maker's identity")

	journey.reset_journey()
	journey.discover_treasure(journey.TREASURE_STAR)
	journey.discover_treasure(journey.TREASURE_JEWEL)
	journey.discover_treasure(journey.TREASURE_LIGHT)
	for i in 5:
		journey.record_choice("mind_spark", "cleared_thoughts")
	var thinky: Array = finale.offer_identities()
	var thinky_ids: Array = thinky.map(func(o): return o["id"])
	check(thinky_ids.any(func(id): return id in ["wise_strategist", "deep_thinker", "calm_craftsman"]),
		"a player who mostly cleared thoughts is offered a thinker's identity")
	check(thinky_ids != arty_ids, "different journeys give different suggestions")

	print("\n-- choosing, and being allowed not to --")
	check(finale.choose_identity("fearless_explorer"), "any of the 16 may be chosen")
	check(journey.identity == "fearless_explorer", "the choice was recorded")
	check(not finale.choose_identity("not_an_identity"), "an unknown identity is refused")

	finale.stay_undecided()
	check(journey.identity == "", "'I am still discovering' is a real answer")

	print("\n-- the Crown of Life --")
	check(finale.forge_crown(), "the crown is forged")
	check(journey.journey_complete, "the journey is complete")
	check(finale.closing_message().contains("Your story matters"),
		"the closing message is the story's own")

	finale.choose_identity("guiding_light")
	check(finale.closing_message().contains("The Guiding Light"),
		"a chosen identity is woven into the closing words")

	print("\n-- naming a star --")
	finale.name_a_star("  Sovann  ")
	var named: Array = journey.choice_log.filter(func(e): return e.get("kind", "") == "star_named")
	check(named.size() == 1 and named[0]["detail"] == "Sovann", "the star carries the player's name")
	finale.name_a_star("")
	check(journey.choice_log.filter(func(e): return e.get("detail", "") == "a new light").size() == 1,
		"an unnamed star still gets a light")

	print("\n-- Celebration Mode rides the whole Crown Line --")
	var route: Array = finale.celebration_route()
	check(route.size() == 5, "the route covers every stop")
	check(route[0] == "gallery" and route[-1] == "castle", "it starts at the Gallery and ends at the castle")

	print("\n-- the station carries the player instead of cutting --")
	var packed: PackedScene = load("res://scenes/New_Hub_World.tscn")
	check(packed != null, "hub scene loaded")
	if packed != null:
		var hub: Node = packed.instantiate()
		add_child(hub)
		var station: Node = hub.get_node_or_null("CrownLine/GalleryStation")
		check(station != null, "GalleryStation exists")
		check(station != null and station.get_script() != null, "it carries the station script")
		var gate: Node = hub.get_node_or_null("CrownLine/MindSparkGate")
		check(gate != null and gate.board_the_train, "gates board the train rather than cutting")
		for line_name in ["MindSparkLine", "HeartMelodyLine", "CreatorsLightLine"]:
			check(hub.get_node_or_null("CrownLine/%s" % line_name) != null,
				"%s is laid" % line_name)
		hub.queue_free()

	journey.reset_journey()
	finale.queue_free()
	_finish()


func _finish() -> void:
	print("\n%d checks, %d failed\n" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
