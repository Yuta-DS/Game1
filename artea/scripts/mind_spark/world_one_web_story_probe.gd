extends Node

## Opt-in connected production story verifier. Enable with `?world_one_story=1`.
##
## The mini-game quality probe verifies player input separately. This probe
## follows the real quest signals from the Signal Observatory through Island 2,
## the Warden, gentle rain, reflection, and the awakened Oldest Tree. Every
## persistent writer is redirected to nonce-scoped files before the first
## action, so a diagnostic run cannot overwrite a player's saves. Reloading the
## page returns the session to the player's unchanged durable state.

const StateStore := preload("res://scripts/mind_spark/quest_objects/quest_object_state_store.gd")

class ProbeJourney extends Node:
	var thoughts: Array[Dictionary] = []
	var star_awarded := false

	func record_thought_echo(text: String, echo_id: String) -> void:
		thoughts.append({"text": text, "mind_echo_id": echo_id, "popped": false})

	func mark_popped(text: String) -> void:
		for thought in thoughts:
			if str(thought.text) == text:
				thought.popped = true

	func complete_mind_spark(minimum: int, required_ids: Array) -> bool:
		star_awarded = minimum == 2 and required_ids.size() == 2 and thoughts.size() == 2
		return star_awarded


var _world: MindSparkWorldOne
var _quest: MindSparkWorldOneQuest
var _journey: ProbeJourney
var _identity: Node
var _paths: Array[String] = []
var _errors: Array[String] = []


func configure(world: MindSparkWorldOne) -> void:
	_world = world
	call_deferred("_begin")


func _begin() -> void:
	# QuestController binds on a deferred call as well. One frame guarantees its
	# production signal graph exists before the isolated story state is applied.
	await get_tree().process_frame
	if _world == null or not is_instance_valid(_world):
		queue_free()
		return
	_quest = _world.get_node_or_null("QuestController") as MindSparkWorldOneQuest
	_identity = get_node_or_null("/root/PlayerIdentityTracker")
	if _quest == null or _identity == null:
		_finish({"ok": false, "errors": ["missing quest controller or identity tracker"]})
		return
	var nonce := "%d_%d" % [Time.get_ticks_msec(), randi()]
	_paths = isolated_story_paths(nonce, OS.has_feature("web"))
	var progress_path := _paths[0]
	var object_path := _paths[1]
	var identity_path := _paths[2]
	var puzzle_path := _paths[3]
	_prepare_isolated_story(progress_path, object_path, identity_path, puzzle_path)
	var checkpoints := _objects_of_kind(QuestObjectDefinition.ObjectKind.CHECKPOINT_SERVER_ROOT)
	var puzzle := _world.get_island_one_puzzle()
	_expect(puzzle != null, "Signal Observatory exists")
	if puzzle != null:
		var puzzle_result: Dictionary = puzzle.solve_for_test()
		_expect(bool(puzzle_result.get("accepted", false)), "Signal Observatory and Echo Garden complete")
	_expect(str(_quest.current_task().get("id", "")) == "collect_two_sparks",
		"Signal Observatory advances to the Spark relay")
	for checkpoint in checkpoints:
		_expect(bool(checkpoint.interact(&"save").get("accepted", false)),
			"checkpoint %s saves" % checkpoint.save_id)
	for collectible in _world.get_collectibles():
		collectible.collect()
	for enemy in _world.get_enemies():
		if enemy.encounter_id == "network":
			enemy.take_damage(999.0)
	var socket := _object(QuestObjectDefinition.ObjectKind.THOUGHT_SPARK_SOCKET)
	_expect(socket != null, "Thought Spark Socket exists")
	if socket != null:
		_expect(bool(socket.interact(&"place_spark").get("accepted", false)), "first Spark is placed")
		_expect(bool(socket.interact(&"place_spark").get("accepted", false)), "second Spark is placed")
	_expect(str(_quest.current_task().get("id", "")) == "scan_fact_fear",
		"Island 1 completion advances to Island 2 evidence")
	_expect(_world.is_quest_gate_open(0), "Island 1 to Island 2 gate opens")
	_expect(bool(_quest.progress.get("island_two_invitation_received", false)),
		"Island 2 invitation is issued")
	var player := _world.get_tree().get_first_node_in_group("Player") as CharacterBody3D
	if player != null:
		player.global_position = _world.to_global(
			_world.get_zone_position("03_constellation_court") + Vector3.UP * 3.0)
	_quest.call("_try_begin_island_two_story")
	_expect(bool(_quest.progress.get("island_two_arrived", false)),
		"arrival in Island 2 starts its story")

	var scanner := _object(QuestObjectDefinition.ObjectKind.EVIDENCE_SCANNER)
	if scanner != null:
		for channel in 3:
			for adjustment in [2, 1, 3][channel]:
				scanner.interact(&"adjust", channel)
			scanner.interact(&"capture", channel)
	_expect(scanner != null and bool(scanner.current_state.get("completed", false)),
		"Evidence Scanner completes through its production actions")
	for enemy in _world.get_enemies():
		if enemy.encounter_id == "constellation":
			enemy.take_damage(999.0)
	var board := _object(QuestObjectDefinition.ObjectKind.MEMORY_CONSTELLATION)
	if board != null:
		board.interact(&"swap", 0)
		board.interact(&"swap", 1)
		board.interact(&"replay")
	_expect(board != null and bool(board.current_state.get("completed", false)),
		"Memory Board advances the evidence story")
	if socket != null:
		socket.interact(&"place_spark")
	var logic := _object(QuestObjectDefinition.ObjectKind.LOGIC_GATE_ARCH)
	if logic != null:
		logic.interact(&"trial", 0)
		logic.interact(&"trial", 1)
		logic.interact(&"model", 1)
		logic.interact(&"test")
	_expect(logic != null and bool(logic.current_state.get("completed", false)),
		"Logic Gate completes and opens the Hope route")
	_expect(_world.is_quest_gate_open(1), "Island 2 evidence gate opens")
	var lens := _object(QuestObjectDefinition.ObjectKind.PERSPECTIVE_LENS)
	if lens != null:
		for view in 3:
			lens.interact(&"view", view)
			lens.interact(&"interpret", view)
	_expect(lens != null and bool(lens.current_state.get("completed", false)),
		"Perspective Lens completes")
	var truth := _object(QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE)
	if truth != null:
		truth.interact(&"approach", 0)
		for knob in [0, 0, 1]:
			truth.interact(&"tune", knob)
		truth.interact(&"project")
	_expect(truth != null and bool(truth.current_state.get("completed", false)),
		"Truth Bridge completes")
	_expect(_quest.complete_garden_reflection(), "Island 2 reflection reveals Island 3")
	_expect(_world.is_quest_gate_open(2), "Island 2 to Island 3 gate opens")

	var boss := _world.get_warden() as MindSparkWardenBoss
	for anchor in _objects_of_kind(QuestObjectDefinition.ObjectKind.WARDEN_ANCHOR):
		anchor.interact(&"dodge")
		anchor.take_damage(25.0)
	_expect(boss != null and boss.phase == MindSparkWardenBoss.Phase.PHASE_3,
		"three anchors expose the Warden core")
	if boss != null:
		boss.take_damage(300.0)
	_expect(str(_quest.current_task().get("id", "")) == "place_final_spark",
		"freeing the Warden opens rain recovery")
	var basin := _object(QuestObjectDefinition.ObjectKind.CALM_RAIN_BASIN)
	if basin != null:
		basin.interact(&"hold")
	_expect(bool(_quest.progress.get("completed", false)) and _quest.completed_task_count() == 10,
		"all ten connected story tasks complete")
	_expect(_world.is_quest_gate_open(3), "Oldest Tree sanctuary gate opens")
	_expect(boss != null and boss.rain.emitting and not boss.active,
		"the storm becomes gentle rain and combat stays stopped")
	_expect(_journey.star_awarded, "the Star of Wisdom is awarded")
	_expect(player != null and player.attack_damage == 30.0,
		"the Wisdom Blade upgrade is equipped")
	var mirror := _object(QuestObjectDefinition.ObjectKind.IDENTITY_REFLECTION_MIRROR)
	if mirror != null:
		mirror.interact(&"answer_a", "outward")
	await get_tree().process_frame
	await get_tree().process_frame
	var campus := _world.get_node_or_null("WorldOneGeometry/IslandThreeCivicSanctuary") as Node3D
	_expect(mirror != null and bool(mirror.current_state.get("completed", false)),
		"Rootbound Reflection records its first private answer")
	_expect(campus != null and bool(campus.get_meta("oldest_tree_awake", false)),
		"reflection awakens the Oldest Tree crown")

	# Prove the same production loader can reconstruct the completed story from
	# the isolated file without rebuilding the enormous visual world.
	_quest.progress = _fresh_progress()
	_quest.set("_current_task_index", 0)
	_quest.call("_load_progress")
	_quest.call("_restore_runtime_state")
	_quest.call("_apply_task_gating")
	var report := {
		"ok": _errors.is_empty()
			and _quest.completed_task_count() == 10
			and bool(_quest.progress.get("completed", false)),
		"tasks_completed": _quest.completed_task_count(),
		"quests_completed": (_quest.progress.get("completed_quest_ids", []) as Array).size(),
		"island_two_state": str(_world.get_meta("island_two_story_state", "")),
		"warden_phase": boss.phase if boss != null else -1,
		"gentle_rain": boss != null and boss.rain.emitting,
		"reflection_completed": mirror != null and bool(mirror.current_state.get("completed", false)),
		"oldest_tree_awake": campus != null and bool(campus.get_meta("oldest_tree_awake", false)),
		"star_awarded": _journey.star_awarded,
		"save_reload_completed": _quest.completed_task_count() == 10
			and bool(_quest.progress.get("completed", false)),
		"temporary_save_isolation": true,
		"errors": _errors.duplicate(),
	}
	# Web FileAccess writes flush asynchronously through IDBFS. Removing four
	# freshly written files here races that flush and produces a deterministic
	# `Failed to save IDB file system` error after an otherwise successful probe.
	# Reuse the same synthetic paths on the next opt-in run instead; native tests
	# keep their nonce files and remove them immediately.
	if not OS.has_feature("web"):
		_cleanup_temporary_files()
	_finish(report)


func _prepare_isolated_story(progress_path: String, object_path: String,
		identity_path: String, puzzle_path: String) -> void:
	if not OS.has_feature("web"):
		for path in _paths:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_journey = ProbeJourney.new()
	_journey.name = "WorldOneStoryProbeJourney"
	add_child(_journey)
	_identity.set("save_path", identity_path)
	_identity.call("clear_evidence")
	_quest.save_path = progress_path
	_quest.inject_dependencies(_journey, _identity)
	_quest.progress = _fresh_progress()
	_quest.set("_current_task_index", 0)
	_quest.set("_reflection_queue", [])
	_quest.set("_reflection_open", false)
	var store := StateStore.new(object_path)
	store.clear()
	for object in _world.get_quest_objects():
		object.persist_state = true
		object.state_store_path = object_path
		object.state_store = store
		object.current_state = object.call("_default_state")
		object.set("_completion_emitted", false)
		object.call("_apply_visual_state", false)
	var puzzle := _world.get_island_one_puzzle()
	if puzzle != null:
		puzzle.state_store_path = puzzle_path
		puzzle.set("_store", StateStore.new(puzzle_path))
		puzzle.current_state = puzzle.call("_default_state")
		puzzle.call("_apply_state", false)
	for collectible in _world.get_collectibles():
		collectible.collected_state = false
		collectible.call("_apply_state")
	for enemy in _world.get_enemies():
		enemy.reset_enemy()
	var boss := _world.get_warden() as MindSparkWardenBoss
	if boss != null:
		boss.reset_battle()
	for gate_index in 4:
		_world.set_quest_gate_open(gate_index, false)
	_world.set_station_spur_available(false)
	_world.set_return_gate_enabled(false)
	_world.set_world_state("sleeping")
	_quest.call("_restore_runtime_state")
	_quest.call("_apply_task_gating")


func _fresh_progress() -> Dictionary:
	return {
		"completed_task_ids": [], "completed_quest_ids": [], "checkpoint_root_ids": [],
		"collected_spark_ids": [], "defeated_enemy_ids": [],
		"island_one_compass_solved": false, "completed_island_one_quest_ids": [],
		"island_two_invitation_received": false, "island_two_arrived": false,
		"xp": 0, "completed": false,
	}


static func isolated_story_paths(nonce: String, web: bool) -> Array[String]:
	var suffix := "browser_probe" if web else nonce
	return [
		"user://world_one_web_story_progress_%s.json" % suffix,
		"user://world_one_web_story_objects_%s.json" % suffix,
		"user://world_one_web_story_identity_%s.json" % suffix,
		"user://world_one_web_story_puzzle_%s.json" % suffix,
	]


func _object(kind: int) -> QuestObjectBase:
	return _world.get_object_by_kind(kind)


func _objects_of_kind(kind: int) -> Array[QuestObjectBase]:
	var matches: Array[QuestObjectBase] = []
	for object in _world.get_quest_objects():
		if object.definition.object_kind == kind:
			matches.append(object)
	return matches


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _cleanup_temporary_files() -> void:
	for path in _paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish(report: Dictionary) -> void:
	_world.set_meta("web_story_results", report.duplicate(true))
	_world.set_meta("web_story_probe_completed", true)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"window.__ARTEA_WORLD_ONE_STORY__ = %s;" % JSON.stringify(report), true)
	print("WORLD_ONE_WEB_STORY: %s" % JSON.stringify(report))
	queue_free()
