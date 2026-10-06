extends SceneTree

const WorldScene = preload("res://scenes/heart_melody/heart_melody_world.tscn")
const Progress = preload("res://scripts/heart_melody/heart_progress.gd")
const Music = preload("res://scripts/heart_melody/musical_fruit_catalog.gd")

var failures: Array[String] = []
var world
var save_path := "res://../work/heart_musical_garden_test.json"

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("FAIL: " + label)

func run() -> void:
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	var state := get_root().get_node("JourneyState")
	state.treasures["star_of_wisdom"] = false
	state.treasures["harmony_jewel"] = false
	check(get_root().get_node("JourneyCampaign").can_enter_kingdom("heart"), "Heart entry is open on a new journey")
	check(not get_root().get_node("JourneyCampaign").can_enter_kingdom("creator"), "independent Heart access does not open Creator")
	var start_scene := FileAccess.get_file_as_string("res://scenes/start_screen.tscn")
	check(not start_scene.contains("Visit Heart Melody") and not start_scene.contains("VisitHeartMelodyButton"),
		"start screen does not expose direct Heart entry")

	world = WorldScene.instantiate()
	world.test_mode = true
	world.progress.path = save_path
	get_root().add_child(world)
	current_scene = world
	await process_frame
	await physics_frame
	check(world.musical_garden != null and world.interactables.filter(func(item): return str(item.kind).begins_with("music_")).size() >= 20,
		"real orchard and individual instrument interactions are built")

	# Walk the real player interaction owner to each fruit prompt; preview and
	# harvest through the same buttons used by keyboard/controller/touch focus.
	for fruit_index in Music.FRUIT_ORDER.size():
		var item: Dictionary = _find_interaction("music_fruit", fruit_index)
		world.player.position = item.pos
		world._process(0.0)
		world._interact_nearest()
		check(world.modal_open, "fruit %d opens from nearby interaction" % fruit_index)
		press("Preview sound")
		press("Harvest into musical basket")
		world._close()
	check(world.progress.data.music.discovered.size() == 4, "four recognisable fruit families enter the musical basket")
	check(world.progress.data.music.completed == [Music.ACTIVITY_ORCHARD], "orchard discovery completes only its local activity")

	check(world.progress.configure_instrument("marimba", 0, "bell_apple"), "place fruit in a fixed-pitch holder")
	check(world.progress.configure_instrument("marimba", 0, "bass_melon"), "swap fruit without losing discovery")
	check(world.progress.configure_instrument("marimba", 0, ""), "retrieve fruit to neutral timbre")
	check(world.progress.data.music.basket.has("bell_apple") and world.progress.data.music.basket.has("bass_melon"), "swap and retrieve never consume essential fruit")

	world.musical_garden._flower_activity()
	press("Add LEAF"); press("Add SUN"); press("Add DROPLET"); press("Answer the flowers")
	check(world.progress.data.music.completed.has(Music.ACTIVITY_FLOWERS), "untimed call-and-response accepts the authored symbolic phrase")
	world._close()

	world.musical_garden._marimba_activity()
	press("Add bar 1"); press("Add bar 3"); press("Add bar 5"); press("Confirm guided melody")
	check(world.progress.data.music.completed.has(Music.ACTIVITY_MARIMBA), "Fruit Marimba validates pitch independently from timbre")
	world._close()

	world.musical_garden._bell_activity()
	press("Try bell 3 / TRIANGLE"); press("Confirm missing note")
	check(world.progress.data.music.completed.has(Music.ACTIVITY_BELLS), "Bell Grove missing-note activity is visible and revisable")
	world._close()

	# Symbolic bounded recording, saved arrangement, and layer settings.
	world.musical_garden.recording = true
	world.musical_garden.play_note("harp", 0)
	world.musical_garden.play_note("marimba", 2)
	world.musical_garden.recording = false
	check(world.progress.set_recording(world.progress.data.music.phrases.recording, true), "symbolic recording saves as arrangement")
	check(world.progress.set_ensemble_layer("bells", false), "ensemble layers are independently persistent")
	await world.musical_garden._play_ensemble(true)
	check(world.progress.data.music.completed == Music.ACTIVITY_ORDER and world.progress.data.music.celebrated,
		"ensemble completes the island celebration without future-world progress")
	check(not state.has_treasure("star_of_wisdom") and not state.has_treasure("harmony_jewel"), "full musical loop awards no unrelated campaign treasure")

	var loaded := Progress.new()
	loaded.path = save_path
	loaded.load_progress()
	check(loaded.data.music.discovered.size() == 4 and loaded.data.music.completed == Music.ACTIVITY_ORDER,
		"harvests and activities survive reload")
	check(loaded.data.music.saved_arrangement.size() == 2 and not loaded.data.music.ensemble.bells,
		"arrangement events and layer choices survive reload")

	# Real schema-1 migration: preserve legacy fields and expose new activities.
	var legacy: Dictionary = Progress.fresh()
	legacy.schema = 1
	legacy.erase("music")
	var legacy_path := "res://../work/heart_musical_legacy_test.json"
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path + suffix))
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy)); file.close()
	var migrated := Progress.new(); migrated.path = legacy_path; migrated.load_progress()
	check(migrated.data.schema == 2 and migrated.data.music.completed.is_empty(), "schema 1 migrates without falsely completing new activities")
	check(migrated.data.planters == legacy.planters and migrated.data.river == legacy.river, "migration preserves established Heart state")

	world.queue_free()
	await process_frame
	for path in [save_path, legacy_path]:
		for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("HEART MUSICAL GARDEN: all checks passed" if failures.is_empty() else "HEART MUSICAL GARDEN FAILURES: " + str(failures))
	quit(0 if failures.is_empty() else 1)

func _find_interaction(kind: String, index: int) -> Dictionary:
	for item in world.interactables:
		if item.kind == kind and item.index == index: return item
	check(false, "interaction exists: %s %d" % [kind, index])
	return {"pos": Vector3.ZERO}

func press(title: String) -> void:
	for node in world.options.find_children("*", "Button", true, false):
		if node.text == title:
			node.pressed.emit()
			return
	check(false, "button exists: " + title)
