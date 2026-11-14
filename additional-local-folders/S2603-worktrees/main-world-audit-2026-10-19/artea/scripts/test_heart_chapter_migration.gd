extends SceneTree
const Progress = preload("res://scripts/heart_melody/heart_progress.gd")
const Catalog = preload("res://scripts/heart_melody/heart_melody_chapter_catalog.gd")
const Director = preload("res://scripts/heart_melody/heart_melody_quest_director.gd")
const Challenge = preload("res://scripts/heart_melody/heart_instrument_challenge_controller.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		push_error(label)

func run() -> void:
	var state := Progress.new()
	state.path = "res://../work/heart_chapter_migration_test.json"
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(state.path + suffix))
	check(state.commit(), "fresh chapter commits")
	for i in 3: check(state.plant(i, 6), "private/sound planter commits")
	check(state.edit_phrase([0, 2]), "partial phrase persists")
	var legacy: Dictionary = state.data.duplicate(true)
	legacy.erase("chapter")
	legacy.schema = 1
	legacy.erase("music")
	check(Progress.valid(legacy), "schema one fixture migrates")
	check(legacy.chapter.tasks == [Catalog.TASKS[0]] and legacy.phrase == [0, 2], "migration preserves partial phrase and task")
	var fractional_schema := legacy.duplicate(true)
	fractional_schema.schema = 1.5
	check(not Progress.valid(fractional_schema), "fractional schema cannot masquerade as a supported version")
	check(state.edit_phrase([0, 2, 1]) and state.solve(), "garden phrase solves")
	check(state.clear_wave(1) and state.clear_wave(2), "garden rewards commit")
	for stage in ["valves", "bulbs"]:
		for i in 3: check(state.river_step(stage, i), "legacy river step commits")
	check(state.river_step("boat"), "legacy boat commits")
	for i in 3: check(state.river_step("chimes", i), "legacy chime commits")
	check(state.river_step("warning"), "legacy warning commits")
	legacy = state.data.duplicate(true)
	legacy.erase("chapter")
	var old_receipts: Dictionary = legacy.receipts.duplicate(true)
	check(Progress.valid(legacy), "completed region B migrates")
	check(legacy.chapter.tasks == Catalog.TASKS.slice(0, 7), "seven prior accomplishments map to stable task IDs")
	check(legacy.receipts == old_receipts and legacy.xp == 119, "migration preserves XP receipts")
	check(legacy.chapter.reward_receipts.is_empty(), "migration does not award finale")
	var director := Director.new()
	director.configure(state)
	check(director.harvest_story("echo_berry"), "story harvest commits")
	check(director.harvest_story("echo_berry") and director.snapshot().quest_pouch.echo_berry == 4, "story harvest receipt prevents duplicates")
	check(not director.craft("echo_nectar"), "crafting cannot consume quest fruit")
	check(director.harvest_material("echo_berry", 99), "material stack fills")
	check(director.harvest_material("echo_berry", 8, 0), "overflow stored")
	check(director.snapshot().materials.echo_berry == 99 and director.snapshot().storage.echo_berry == 8, "overflow loses no fruit")
	check(director.craft("echo_nectar") and director.snapshot().materials.echo_berry == 98, "recipe consumes material only")
	check(director.snapshot().quest_pouch.echo_berry == 4, "recipe preserves story allotment")
	check(director.withdraw("echo_berry", 0) and director.snapshot().storage.echo_berry == 7, "existing stack can withdraw without a new slot")
	var before := director.snapshot()
	state.path = "res://missing_directory/chapter.json"
	check(not director.harvest_material("dew_pear"), "failed write rejected")
	check(director.snapshot() == before and state.data.chapter == before, "failed write cannot fund subsequent actions")
	state.plant(0, 1)
	check(state.dirty and not director.harvest_material("dew_pear"), "chapter edits cannot overwrite a pending legacy save")
	state.path = "res://../work/heart_chapter_migration_test.json"
	check(state.commit(), "pending legacy transaction remains retryable")
	for mutation in [{"tasks": [Catalog.TASKS[9]]}, {"quest_pouch": {"bogus": 1}},
		{"materials": {"echo_berry": 100}}, {"storage": {"echo_berry": -1}},
		{"reward_receipts": ["harmony_jewel"]}, {"settings": {}}, {"anchors": ["rhythm", "rhythm"]},
		{"challenges": {Catalog.TASKS[9]: {"input": [], "failures": 0, "hint": 0}}}]:
		var bad: Dictionary = state.data.duplicate(true)
		bad.chapter.merge(mutation, true)
		check(not Progress.valid(bad), "reject invalid chapter " + str(mutation))
	var challenge := Challenge.new()
	check(challenge.configure("sequence", [0, 2, 1]), "configure phrase")
	challenge.enter(0)
	challenge.enter(1)
	check(not challenge.submit() and challenge.input == [0, 1], "incorrect notes remain editable")
	check(challenge.undo() and challenge.input == [0], "undo preserves prior notes")
	challenge.enter(2)
	challenge.enter(1)
	check(challenge.submit() and not challenge.submit(), "completion fires once per attempt")
	challenge.reset()
	challenge.paused = true
	challenge.advance(10.0)
	check(not challenge.enter(0) and challenge.elapsed == 0.0, "pause freezes input and time")
	challenge.paused = false
	check(challenge.configure("pitch", [0, 1, 2, 3, 4]), "configure five string harp")
	for i in 5: challenge.tune(i, i)
	check(not challenge.tune(2, 8) and challenge.input == [0, 1, 2, 3, 4], "unsafe tension preserves other strings")
	check(challenge.submit(), "five string ascending pattern")
	for fps in [30, 60, 120]:
		challenge.configure("timing", [2])
		for frame in fps: challenge.advance(1.0 / fps)
		check(challenge.strike(2, 1.0, 0.1) and challenge.submit(), "same beat at %d FPS" % fps)
	# Exercise backup recovery with real JSON, including JSON's floating point numbers.
	check(director.harvest_material("dew_pear", 1), "second primary write makes persistent backup")
	var file := FileAccess.open(state.path, FileAccess.WRITE)
	file.store_string("{corrupted")
	file.close()
	var reload := Progress.new()
	reload.path = state.path
	reload.load_progress()
	check(reload.dirty and reload.committed.chapter.tasks.size() == 7, "corrupt primary recovers chapter from backup")
	check(reload.committed.xp == 119, "backup retains original XP")
	print("HEART CHAPTER MIGRATION: PASS" if failures.is_empty() else "HEART CHAPTER MIGRATION: " + str(failures))
	quit(0 if failures.is_empty() else 1)
