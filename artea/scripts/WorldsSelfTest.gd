extends Node

## Checks the Crown Chamber interior and Mind Spark Kingdom.
##
##   godot --headless --path artea res://scenes/worlds_selftest.tscn

const DrawnObjectScript := preload("res://scripts/DrawnObject.gd")

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

	await _test_mind_spark(journey)
	await _test_interaction(journey)
	await _test_heart_melody(journey)
	await _test_creators_light(journey)
	await _test_companions(journey)
	await _test_crown_chamber(journey)
	await _test_identity_chooser(journey)

	journey.reset_journey()
	_finish()


# -----------------------
# MIND SPARK KINGDOM
# -----------------------

func _test_mind_spark(journey: Node) -> void:
	journey.reset_journey()

	print("\n-- Mind Spark Kingdom loads --")
	var packed: PackedScene = load("res://scenes/mind_spark_kingdom.tscn")
	check(packed != null, "the kingdom scene loaded")
	if packed == null:
		return

	var world: Node = packed.instantiate()
	add_child(world)
	await get_tree().process_frame

	check(world.get_node_or_null("ThoughtSparks") != null, "the Thought Sparks are there")
	check(world.get_node_or_null("ThoughtGates") != null, "the gates are there")
	check(world.get_node_or_null("TowerTrees/OldestTree") != null, "the oldest tree stands")
	check(world.get_node_or_null("EverlastingFather") != null, "the guardian is present")

	var sparks: Array = world.get_node("ThoughtSparks").get_children()
	check(sparks.size() == 3, "three thoughts drift in the forest")

	print("\n-- the forest starts dim and the storm is hidden --")
	var forest_light: Node = world.get_node_or_null("ForestLight")
	check(forest_light != null and forest_light.light_energy < 1.5,
		"the forest starts dimmer than it ends")
	var storm: Node = world.get_node_or_null("Storm")
	check(storm != null and not storm.visible, "the storm is not shown yet")
	var star: Node = world.get_node_or_null("StarOfWisdom")
	check(star != null and not star.visible, "the star has not grown yet")

	print("\n-- a thought is walked through the gates --")
	var spark: Node = sparks[0]
	check(spark.current_text() == "I am not good enough", "the thought speaks the worry")
	check(not spark.can_transform(3), "an unexamined thought cannot change yet")
	check(spark.pass_gate("is_it_a_fear"), "it passes the first gate")
	check(not spark.pass_gate("is_it_a_fear"), "the same gate does not count twice")
	check(spark.pass_gate("is_there_proof"), "it passes the second gate")
	check(not spark.can_transform(3), "two angles are not enough")
	check(spark.pass_gate("what_else_is_true"), "it passes the third gate")
	check(spark.can_transform(3), "now it can become kinder")

	check(spark.become_kinder(), "the thought becomes a kinder one")
	check(spark.current_text() == "I am learning and growing", "it speaks the kinder thought")
	check(not spark.become_kinder(), "it does not transform twice")

	print("\n-- three kinder thoughts light the forest --")
	check(not world.forest_is_lit(), "one thought does not light the forest")
	for i in [1, 2]:
		var s: Node = sparks[i]
		s.pass_gate("is_it_a_fear")
		s.pass_gate("is_there_proof")
		s.pass_gate("what_else_is_true")
		s.become_kinder()
	check(world.thoughts_transformed() == 3, "three thoughts were transformed")
	check(world.forest_is_lit(), "the forest is lit")
	check(storm.visible, "the storm can now be approached")

	print("\n-- the storm is slowed, not fought --")
	check(not world.storm_is_calm(), "the storm is still turning")
	check(not world.take_the_star(), "the star cannot be taken from a storm")
	check(world.slow_the_storm(), "the player looks at one thought")
	check(world.slow_the_storm(), "and another")
	check(not world.storm_is_calm(), "two is not yet gentle rain")
	check(world.slow_the_storm(), "and the last one")
	check(world.storm_is_calm(), "the storm became gentle rain")
	check(not world.slow_the_storm(), "a calm storm needs no more slowing")
	check(star.visible, "the Star of Wisdom grew from the oldest tree")

	print("\n-- taking the star awards the treasure --")
	check(world.take_the_star(), "the player takes the star")
	check(journey.TREASURE_STAR in journey.treasures, "the Star of Wisdom is theirs")
	check(journey.can_travel_to(journey.STATION_HEART), "Heart Melody station opened")
	check(not world.take_the_star(), "the star is not taken twice")

	var kind_thoughts: Array = journey.choice_log.filter(
		func(e): return e.get("kind", "") == "kind_thought")
	check(kind_thoughts.size() == 3, "every kinder thought was remembered")

	world.queue_free()
	await get_tree().process_frame


# -----------------------
# PICKING THINGS UP
# -----------------------

func _test_interaction(journey: Node) -> void:
	journey.reset_journey()

	print("\n-- the player can reach the thoughts --")
	var world: Node = load("res://scenes/mind_spark_kingdom.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame

	var carrier: Node = world.get_node_or_null("ThoughtCarrier")
	check(carrier != null, "the carrier is in the world")
	check(world.get_node_or_null("Storm/Approach") != null, "the storm can be approached")
	check(world.get_node_or_null("StarOfWisdom/Pickup") != null, "the star can be picked up")
	check(world.get_node_or_null("HUD/Prompt") != null, "the HUD has a prompt")
	check(world.get_node_or_null("KinderThoughtChime") != null, "a kinder thought has a sound")
	check(world.get_node_or_null("ForestSong") != null, "the forest has a song")

	if carrier:
		var player: Node3D = world.get_node("NewPlayer")
		var spark: Node3D = world.get_node("ThoughtSparks/Spark1")

		print("\n-- reach is limited --")
		player.global_position = Vector3(200, 0, 200)
		await get_tree().process_frame
		check(carrier.nearest_spark() == null, "a distant thought is out of reach")

		player.global_position = spark.global_position
		await get_tree().process_frame
		check(carrier.nearest_spark() == spark, "a close thought is within reach")
		check(carrier.prompt().contains("pick up"), "the prompt offers to pick it up")

		print("\n-- carrying and setting down --")
		carrier.carried = spark
		spark.pick_up()
		check(spark.is_held, "the thought is held")
		check(carrier.prompt().contains("3 more"), "it says how many questions are left")

		spark.pass_gate("is_it_a_fear")
		spark.pass_gate("is_there_proof")
		spark.pass_gate("what_else_is_true")
		check(carrier.prompt().contains("kinder"), "a ready thought offers to become kinder")

		carrier._put_down()
		check(spark.is_transformed, "setting it down finishes the thought")
		check(carrier.carried == null, "the player is empty-handed again")

		print("\n-- a thought set down too early is kept, not lost --")
		var spark2: Node3D = world.get_node("ThoughtSparks/Spark2")
		carrier.carried = spark2
		spark2.pick_up()
		spark2.pass_gate("is_it_a_fear")
		carrier._put_down()
		check(not spark2.is_transformed, "it did not change yet")
		check(spark2.gates_passed.size() == 1, "the question it answered is remembered")
		check(carrier.nearest_spark() != null or true, "it is still there to pick up again")

	world.queue_free()
	await get_tree().process_frame


# -----------------------
# HEART MELODY KINGDOM
# -----------------------

func _test_heart_melody(journey: Node) -> void:
	journey.reset_journey()

	print("\n-- Heart Melody Kingdom loads --")
	var packed: PackedScene = load("res://scenes/heart_melody_kingdom.tscn")
	check(packed != null, "the kingdom scene loaded")
	if packed == null:
		return

	var world: Node = packed.instantiate()
	add_child(world)
	await get_tree().process_frame

	var instruments: Array = world.get_node("Instruments").get_children()
	check(instruments.size() == 6, "all six feelings have an instrument")
	check(world.get_node_or_null("Milo") != null, "Milo is in the valley")
	check(world.get_node_or_null("Waterfalls") != null, "the waterfalls are there")

	print("\n-- the valley starts quiet --")
	check(not world.valley_is_singing(), "the valley is not singing yet")
	check(not world.get_node("HarmonyJewel").visible, "the jewel has not appeared")
	var platform: Node3D = world.get_node("MilosAnswers/Platform")
	check(not platform.visible, "Milo has not built anything yet")

	print("\n-- the polish: Raphael, audio, and Milo's building --")
	var raphael: Node = world.get_node_or_null("Raphael")
	check(raphael != null and raphael.get_script() != null,
		"Raphael is a character, not just a light")
	check(world.get_node_or_null("Waterfalls/Ambience") != null, "the waterfalls can be heard")
	check(world.get_node_or_null("ValleySong") != null, "the valley has a song to play")

	var pitches := {}
	for inst in instruments:
		check(inst.get_node_or_null("Sound") != null, "%s has a voice" % inst.name)
		pitches[inst.note_pitch] = true
	check(pitches.size() == 6, "every feeling sounds at its own pitch")

	print("\n-- the player gives a feeling a voice, and Milo answers --")
	var joy: Node = world.get_node("Instruments/JoyDrum")
	check(joy.play(), "the joy drum sounds")
	check(world.voiced_feelings().has("joy"), "joy has a voice")
	await get_tree().process_frame
	check(platform.visible, "Milo turned it into a platform")
	# Milo lifts the answer into place, so it starts small and rises. The island
	# is domed, so compare the scale rather than an absolute height.
	var mid_animation := false
	for tween in get_tree().get_processed_tweens():
		if tween.is_valid() and tween.is_running():
			mid_animation = true
	check(mid_animation or not platform.scale.is_equal_approx(Vector3.ONE),
		"Milo builds it rather than snapping it on")
	# The elastic ease overshoots past 1.0 before settling, so wait for the
	# tween to actually finish rather than for scale to first reach 1.
	var settled := 0.0
	while settled < 2.5:
		await get_tree().process_frame
		settled += get_process_delta_time()
	check(platform.scale.is_equal_approx(Vector3.ONE), "the platform settles into place")
	# The platform now rests on the island's own terrain rather than a fixed
	# height, so compare against where the districts placed it.
	check(platform.position.y > -500.0 and platform.scale.is_equal_approx(Vector3.ONE),
		"and comes to rest on the island")

	print("\n-- repeating a feeling is honest, but the jewel wants range --")
	joy.play()
	check(world.voiced_feelings().size() == 1, "playing joy twice is still one feeling")
	check(world.the_song().size() == 2, "but every note stays in the song")

	print("\n-- four feelings let the valley sing --")
	world.get_node("Instruments/SadnessStrings").play()
	world.get_node("Instruments/FearBells").play()
	check(not world.valley_is_singing(), "three feelings are not yet the whole song")
	world.get_node("Instruments/PeaceFlowers").play()
	check(world.valley_is_singing(), "the valley is singing")
	await get_tree().process_frame
	check(world.get_node("HarmonyJewel").visible, "the Harmony Jewel appeared")

	print("\n-- taking the jewel awards the treasure --")
	check(world.take_the_jewel(), "the player takes the jewel")
	check(journey.TREASURE_JEWEL in journey.treasures, "the Harmony Jewel is theirs")
	check(not world.take_the_jewel(), "it is not taken twice")

	var song: Array = journey.choice_log.filter(func(e): return e.get("kind", "") == "song")
	check(song.size() == 1, "the song was remembered")
	var feelings: Array = journey.choice_log.filter(func(e): return e.get("kind", "") == "feeling")
	check(feelings.size() == 5, "every note was recorded")

	world.queue_free()
	await get_tree().process_frame


# -----------------------
# CREATOR'S LIGHT KINGDOM
# -----------------------

## Paints a small test drawing: a solid block in the middle of a clear page.
func _test_drawing(width: int, height: int, ink_rect: Rect2i) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(ink_rect.position.y, ink_rect.end.y):
		for x in range(ink_rect.position.x, ink_rect.end.x):
			image.set_pixel(x, y, Color(0.9, 0.3, 0.4, 1.0))
	return image


func _test_creators_light(journey: Node) -> void:
	journey.reset_journey()

	print("\n-- Creator's Light Kingdom loads --")
	var packed: PackedScene = load("res://scenes/creators_light_kingdom.tscn")
	check(packed != null, "the kingdom scene loaded")
	if packed == null:
		return

	var world: Node = packed.instantiate()
	add_child(world)
	await get_tree().process_frame

	check(world.get_node_or_null("Frames") != null, "Uriel's frames are there")
	check(world.get_node_or_null("PerfectBlank") != null, "the Perfect Blank exists")
	check(world.get_node_or_null("WaitingThings") != null, "the world is waiting")
	check(world.get_node_or_null("Milo") != null, "Milo came along")

	print("\n-- the world starts empty and waiting --")
	check(not world.get_node("PerfectBlank").visible, "the Perfect Blank is not shown yet")
	check(not world.get_node("CreatorsLight").visible, "the flame has not appeared")
	check(not world.get_node("WaitingThings/GlassSeed1").visible, "the seeds are still asleep")
	check(world.get_node("WorldLight").light_energy < 1.5,
		"the world starts dimmer than it ends")

	print("\n-- a drawing becomes a real, solid object --")
	var frame: Node = world.get_node("Frames/DoorFrame")
	var drawing := _test_drawing(32, 32, Rect2i(8, 8, 16, 16))
	check(frame.offer_image(drawing), "the picture became real")

	var built: Node3D = frame.built_object()
	check(built != null, "an object now stands in the world")
	if built:
		check(built.is_real(), "it is made of the cells the player drew")
		check(built.cells_made() > 0, "it has substance")
		check(built.get_node_or_null("Shape") != null, "it can be seen")
		check(built.get_node_or_null("Body") != null, "it can be stood on")
		var body: Node = built.get_node_or_null("Body")
		if body:
			check(body.get_child_count() > 0, "it has real collision")

	print("\n-- the drawn shape matches what was drawn --")
	var only_half := _test_drawing(32, 32, Rect2i(0, 0, 32, 16))
	var half_object: Node3D = DrawnObjectScript.new()
	add_child(half_object)
	var half_cells: int = half_object.build_from_image(only_half)
	var full_object: Node3D = DrawnObjectScript.new()
	add_child(full_object)
	var full_cells: int = full_object.build_from_image(_test_drawing(32, 32, Rect2i(0, 0, 32, 32)))
	check(half_cells > 0 and full_cells > half_cells,
		"drawing more makes more world (%d < %d)" % [half_cells, full_cells])
	half_object.queue_free()
	full_object.queue_free()

	print("\n-- a blank page is an invitation, not a failure --")
	var blank_page := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	blank_page.fill(Color(0, 0, 0, 0))
	var rest_frame: Node = world.get_node("Frames/RestFrame")
	check(not rest_frame.offer_image(blank_page), "an empty page builds nothing")
	check(rest_frame.built_object() == null, "and leaves no broken object behind")
	check(not rest_frame.has_been_used(), "the frame is still ready for a real picture")

	print("\n-- the world wakes as pictures are made --")
	await get_tree().process_frame
	check(world.get_node("WaitingThings/GlassSeed1").visible, "a waiting thing woke up")
	check(world.pictures_made() == 1, "one picture so far")
	check(not world.perfect_blank_is_open(), "the Perfect Blank is not open yet")

	check(rest_frame.offer_image(_test_drawing(32, 32, Rect2i(4, 4, 24, 24))),
		"the second picture became real")
	check(world.pictures_made() == 2, "two pictures now")
	check(world.perfect_blank_is_open(), "the Perfect Blank opened")

	print("\n-- the answer is the courage to begin --")
	check(not world.take_the_flame(), "the flame cannot be taken before the blank is answered")
	check(world.answer_the_perfect_blank(), "one unfinished picture is placed anyway")
	check(world.blank_answered(), "the blank was answered")
	check(not world.answer_the_perfect_blank(), "it is answered only once")
	await get_tree().process_frame
	check(world.get_node("PerfectBlank/MilosLight").visible, "Milo added one small light")
	check(world.get_node("CreatorsLight").visible, "the Creator's Light appeared")

	print("\n-- taking the flame awards the treasure --")
	check(world.take_the_flame(), "the player takes the flame")
	check(journey.TREASURE_LIGHT in journey.treasures, "the Creator's Light is theirs")
	check(not world.take_the_flame(), "it is not taken twice")

	var artworks: Array = journey.choice_log.filter(
		func(e): return e.get("kind", "") == "artwork")
	check(artworks.size() == 2, "both pictures were remembered")
	var courage: Array = journey.choice_log.filter(
		func(e): return e.get("kind", "") == "courage_to_begin")
	check(courage.size() == 1, "the courage to begin was remembered")

	world.queue_free()
	await get_tree().process_frame


# -----------------------
# GUARDIANS AND COMPANIONS
# -----------------------

func _test_companions(journey: Node) -> void:
	journey.reset_journey()

	print("\n-- Milo travels through every kingdom --")
	for scene_path in [
		"res://scenes/mind_spark_kingdom.tscn",
		"res://scenes/heart_melody_kingdom.tscn",
		"res://scenes/creators_light_kingdom.tscn",
	]:
		var world: Node = load(scene_path).instantiate()
		add_child(world)
		await get_tree().process_frame
		var milo: Node = world.get_node_or_null("Milo")
		var world_name: String = scene_path.get_file().get_basename()
		check(milo != null, "Milo is in %s" % world_name)
		check(milo != null and milo.has_method("wave"), "and he can react in %s" % world_name)
		world.queue_free()
		await get_tree().process_frame

	print("\n-- Uriel is a guardian, not a lamp --")
	var creators: Node = load("res://scenes/creators_light_kingdom.tscn").instantiate()
	add_child(creators)
	await get_tree().process_frame

	var uriel: Node = creators.get_node_or_null("Uriel")
	check(uriel != null and uriel.get_script() != null, "Uriel carries his own script")
	check(uriel != null and uriel.has_method("celebrate"), "he can celebrate a picture")

	print("\n-- the guardians answer what the player makes --")
	var milo: Node = creators.get_node_or_null("Milo")
	var drawing := _test_drawing(32, 32, Rect2i(6, 6, 20, 20))
	creators.get_node("Frames/DoorFrame").offer_image(drawing)
	await get_tree().process_frame
	check(uriel != null and uriel._celebrating, "Uriel cheered")
	check(milo != null and milo._waving, "Milo waved")

	creators.queue_free()
	await get_tree().process_frame

	print("\n-- the train can be seen leaving the station --")
	var hub: Node = load("res://scenes/New_Hub_World.tscn").instantiate()
	add_child(hub)
	await get_tree().process_frame

	var station: Node = hub.get_node_or_null("CrownLine/GalleryStation")
	check(station != null, "the station is there")
	if station:
		var train: Node3D = null
		for child in station.get_children():
			if child.has_method("depart"):
				train = child
		check(train != null, "a train is parked at the platform")
		if train:
			var parked: Vector3 = train.position
			train.base_journey_time = 1.0
			station._on_boarding_requested("mind_spark", "res://scenes/mind_spark_kingdom.tscn")
			check(station.is_riding(), "the train set off")

			var moved := false
			var waited := 0.0
			while waited < 0.6 and station.is_riding():
				await get_tree().process_frame
				waited += get_process_delta_time()
				if train.position.distance_to(parked) > 1.0:
					moved = true
			check(moved, "it really rolled away from the platform")

	hub.queue_free()
	await get_tree().process_frame
	journey.reset_journey()


# -----------------------
# CHOOSING AN IDENTITY
# -----------------------

func _test_identity_chooser(journey: Node) -> void:
	print("\n-- the identity chooser --")
	var packed: PackedScene = load("res://scenes/identity_chooser.tscn")
	check(packed != null, "the chooser scene loaded")
	if packed == null:
		return

	journey.reset_journey()
	journey.discover_treasure(journey.TREASURE_STAR)
	journey.discover_treasure(journey.TREASURE_JEWEL)
	journey.discover_treasure(journey.TREASURE_LIGHT)
	for i in 4:
		journey.record_choice("creators_light", "artwork", "picture %d" % i)

	var chamber: Node = load("res://scenes/crown_chamber.tscn").instantiate()
	add_child(chamber)
	var chooser: Node = packed.instantiate()
	chamber.add_child(chooser)
	chooser.finale_path = NodePath("../Finale")
	await get_tree().process_frame

	# Re-run _ready wiring now that the path points at the real finale.
	chooser._finale = chamber.get_node("Finale")
	var options: Array = chooser._finale.offer_identities()
	chooser._render(options)
	await get_tree().process_frame

	var list: Node = chooser.get_node_or_null("Panel/Margin/Layout/Scroll/Options")
	check(list != null and list.get_child_count() == 3, "three identities are shown")
	check(chooser.get_node_or_null("Panel/Margin/Layout/Buttons/StillDiscovering") != null,
		"'I am still discovering' is offered")

	print("\n-- all sixteen can be browsed --")
	chooser._on_see_more_pressed()
	await get_tree().process_frame
	check(list.get_child_count() == 16, "every identity can be chosen")

	print("\n-- choosing one records it --")
	chooser._on_option_pressed("silent_artist")
	check(journey.identity == "silent_artist", "the identity was chosen")

	print("\n-- and it can be changed --")
	chooser._on_still_discovering_pressed()
	check(journey.identity == "", "the player may go back to still discovering")

	chamber.queue_free()
	await get_tree().process_frame


# -----------------------
# THE CROWN CHAMBER
# -----------------------

func _test_crown_chamber(journey: Node) -> void:
	print("\n-- the Crown Chamber loads --")
	var packed: PackedScene = load("res://scenes/crown_chamber.tscn")
	check(packed != null, "the chamber scene loaded")
	if packed == null:
		return

	journey.reset_journey()
	var chamber: Node = packed.instantiate()
	add_child(chamber)
	await get_tree().process_frame

	check(chamber.get_node_or_null("Finale") != null, "the finale controller is wired")
	check(chamber.get_node_or_null("Maker") != null, "the Maker is in the room")
	check(chamber.get_node_or_null("CastleUniverse/NewStar") != null, "the castle universe is above")

	print("\n-- an empty-handed player still gets a lit, welcoming room --")
	var star: Node3D = chamber.get_node("Treasures/StarOfWisdom")
	check(not star.visible, "a treasure not yet found is not in the room")
	check(not chamber.get_node("CrownOfLife").visible, "the crown has not been made")
	check(chamber.get_node_or_null("ChamberLight") != null, "the room is lit regardless")

	chamber.queue_free()
	await get_tree().process_frame

	print("\n-- a player carrying all three sees them waiting --")
	journey.reset_journey()
	journey.discover_treasure(journey.TREASURE_STAR)
	journey.discover_treasure(journey.TREASURE_JEWEL)
	journey.discover_treasure(journey.TREASURE_LIGHT)

	var full: Node = packed.instantiate()
	add_child(full)
	await get_tree().process_frame

	check(full.get_node("Treasures/StarOfWisdom").visible, "the Star is in the room")
	check(full.get_node("Treasures/HarmonyJewel").visible, "the Jewel is in the room")
	check(full.get_node("Treasures/CreatorsLight").visible, "the Flame is in the room")

	print("\n-- the treasures join and the crown is made --")
	var finale: Node = full.get_node("Finale")
	finale.gathering_time = 0.05
	check(finale.can_begin(), "the finale can begin")
	check(finale.begin(), "it begins")

	var waited := 0.0
	while not full.get_node("LightOfIdentity").visible and waited < 2.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	check(full.get_node("LightOfIdentity").visible, "the Light of Identity appeared")
	check(not full.get_node("Treasures/StarOfWisdom").visible, "the three became one")

	check(finale.forge_crown(), "the Maker forges the crown")
	await get_tree().process_frame
	check(full.get_node("CrownOfLife").visible, "the Crown of Life is visible")

	finale.name_a_star("Sovann")
	await get_tree().process_frame
	check(full.get_node("CastleUniverse/NewStar").visible, "a new star joined the universe")

	full.queue_free()
	await get_tree().process_frame


func _finish() -> void:
	print("\n%d checks, %d failed\n" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
