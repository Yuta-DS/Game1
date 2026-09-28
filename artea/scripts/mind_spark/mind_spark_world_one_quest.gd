class_name MindSparkWorldOneQuest
extends Node

signal task_completed(task_id: String)
signal quest_completed(quest_id: String)
signal world_completed
signal island_transition_started(from_island: int, to_island: int)
signal island_arrived(island_index: int)

const SAVE_PATH := "user://mind_spark_walkable_world_one_progress.json"
const ECHO_IDS := ["world_one.fact_and_fear", "world_one.hope_path"]
const QUESTS := [
	{"id": "notice_signal", "title": "NOTICE THE SIGNAL", "task_end": 0, "xp": 0, "target_minutes": 10},
	{"id": "island_one_awareness", "title": "LISTEN TO THE ECHO", "task_end": 1, "xp": 75, "target_minutes": 7},
	{"id": "broken_pattern", "title": "UNDERSTAND THE MOMENT", "task_end": 4, "xp": 100, "target_minutes": 13},
	{"id": "hope_path", "title": "BUILD A POSSIBLE TOMORROW", "task_end": 7, "xp": 125, "target_minutes": 14},
	{"id": "free_warden", "title": "CALM THE THOUGHT STORM", "task_end": 9, "xp": 200, "target_minutes": 20},
]
const TASKS := [
	{"id": "wake_two_roots", "quest": 0, "title": "Form the Signal Prism", "zone": "01", "prompt": "Explore the thought signal and align the Observatory to form the Signal Prism"},
	{"id": "collect_two_sparks", "quest": 1, "title": "Carry the Echo Seed forward", "zone": "02", "prompt": "Complete the two Thought Spark relay to carry the intact Echo Seed to Island Two"},
	{"id": "scan_fact_fear", "quest": 2, "title": "Investigate Ari's interrupted experiment", "zone": "03", "prompt": "Focus the optical plate, inspect the recorder, and test the cooling valve. Capture three observations"},
	{"id": "restore_memory", "quest": 2, "title": "Reconstruct what happened", "zone": "03", "prompt": "Reorder the recorded event strips and replay them against your observations"},
	{"id": "open_logic_gate", "quest": 2, "title": "Test an explanation", "zone": "03", "prompt": "Test how cooling affects the shutter; distinguish what the evidence explains from what remains unknown"},
	{"id": "turn_lens", "quest": 3, "title": "See more than one perspective", "zone": "04", "prompt": "Distinguish Ari's feeling, the machine's behaviour and the helper's offer"},
	{"id": "form_truth_bridge", "quest": 3, "title": "Restore the living projection", "zone": "04", "prompt": "Choose a useful approach, adjust the coupled optics and project the leaf pattern"},
	{"id": "clear_elite_guard", "quest": 3, "title": "Share what changed with Ari", "zone": "04", "prompt": "Return to the completed projector and share the discovery to reveal Island Three"},
	{"id": "free_warden_core", "quest": 4, "title": "Break three anchors and free the core", "zone": "05", "prompt": "Dodge wide lines, strike open rings, then attack the crystal core"},
	{"id": "place_final_spark", "quest": 4, "title": "Change the storm into gentle rain", "zone": "05–06", "prompt": "HOLD at the Calm Rain Basin; there is no timed input"},
]
const ISLAND_TWO_STORY_ORDER := {
	"dormant": 0, "invited": 1, "received": 2, "evidence_sorted": 3,
	"memory_woven": 4, "archive_open": 5, "hope_reframed": 6,
	"truth_materialised": 7, "guardian_freed": 8,
}
const IDENTITY_MOMENTS := {
	0: {"id": "MS_ID_01", "axis": "energy", "a": "E • Talk and act with others", "b": "I • Think and act quietly", "side_a": "E", "side_b": "I"},
	1: {"id": "MS_ID_02", "axis": "information", "a": "S • Notice clear details", "b": "N • Notice patterns and possibilities", "side_a": "S", "side_b": "N"},
	2: {"id": "MS_ID_03", "axis": "decisions", "a": "T • Use reason and rules", "b": "F • Use care and personal values", "side_a": "T", "side_b": "F"},
	3: {"id": "MS_ID_04", "axis": "structure", "a": "J • Plan the order", "b": "P • Explore and adapt", "side_a": "J", "side_b": "P"},
	4: {"id": "MS_ID_05", "axis": "energy", "a": "E • Ask for help", "b": "I • Try quietly first", "side_a": "E", "side_b": "I"},
	5: {"id": "MS_ID_06", "axis": "information", "a": "S • Follow one pattern detail", "b": "N • Follow the big picture", "side_a": "S", "side_b": "N"},
	8: {"id": "MS_ID_07", "axis": "decisions", "a": "T • Follow the safe rule", "b": "F • Protect the living storm", "side_a": "T", "side_b": "F"},
	9: {"id": "MS_ID_08", "axis": "structure", "a": "J • Reflect in order", "b": "P • Replay what stood out", "side_a": "J", "side_b": "P"},
}

@export var enabled := true
@export var force_enable_without_world_hud := false
@export var save_path := SAVE_PATH

var world: MindSparkWorldOne
var journey_state: Node
var identity_tracker: Node
var progress := {
	"completed_task_ids": [], "completed_quest_ids": [], "checkpoint_root_ids": [],
	"collected_spark_ids": [], "defeated_enemy_ids": [], "island_one_compass_solved": false,
	"completed_island_one_quest_ids": [],
	"island_two_invitation_received": false, "island_two_arrived": false,
	"xp": 0, "completed": false,
}
var _current_task_index := 0
var _reflection_queue: Array[Dictionary] = []
var _reflection_open := false
var _player: CharacterBody3D
var _hud_root: Control
var _quest_label: Label
var _task_label: Label
var _dialogue_label: Label
var _reflection_label: Label


func _ready() -> void:
	call_deferred("_bind_world")


func inject_dependencies(new_journey_state: Node, new_identity_tracker: Node = null) -> void:
	journey_state = new_journey_state
	identity_tracker = new_identity_tracker


func current_task() -> Dictionary:
	return TASKS[_current_task_index].duplicate(true) if _current_task_index < TASKS.size() else {}


func completed_task_count() -> int:
	return (progress.completed_task_ids as Array).size()


func has_open_identity_reflection() -> bool:
	return _reflection_open


func pending_identity_count() -> int:
	return _reflection_queue.size()


func target_first_play_minutes() -> int:
	var total := 0
	for quest in QUESTS:
		total += int(quest.target_minutes)
	return total


func _bind_world() -> void:
	world = get_parent() as MindSparkWorldOne
	if not enabled or world == null or (not world.build_hud and not force_enable_without_world_hud):
		enabled = false
		return
	if journey_state == null:
		journey_state = get_node_or_null("/root/JourneyState")
	if identity_tracker == null:
		identity_tracker = get_node_or_null("/root/PlayerIdentityTracker")
	_load_progress()
	_find_player()
	_connect_world_events()
	_restore_runtime_state()
	_build_hud()
	_apply_task_gating()


func _connect_world_events() -> void:
	if not world.island_one_puzzle_solved.is_connected(_on_island_one_puzzle_solved):
		world.island_one_puzzle_solved.connect(_on_island_one_puzzle_solved)
	for object in world.get_quest_objects():
		object.completed.connect(_on_object_completed)
		object.progress_changed.connect(_on_object_progress)
		object.linked_task_opened.connect(_on_linked_task_opened)
		if object.definition.object_kind == QuestObjectDefinition.ObjectKind.CHECKPOINT_SERVER_ROOT:
			object.checkpoint_action_requested.connect(_on_checkpoint_action.bind(object.save_id))
	for collectible in world.get_collectibles():
		collectible.collected.connect(_on_spark_collected)
	for enemy in world.get_enemies():
		enemy.defeated.connect(_on_enemy_defeated)
	var boss := world.get_warden() as MindSparkWardenBoss
	if boss != null:
		boss.defeated.connect(_on_boss_defeated)
		boss.combat_stopped.connect(_on_boss_combat_stopped)
	var compass := world.get_island_one_puzzle()
	if compass != null and not compass.quest_completed.is_connected(_on_island_one_subquest_completed):
		compass.quest_completed.connect(_on_island_one_subquest_completed)
	if compass != null and compass.is_powered():
		progress.island_one_compass_solved = true


func _on_island_one_subquest_completed(quest_id: String, reward: Dictionary) -> void:
	var completed: Array = progress.completed_island_one_quest_ids
	if not completed.has(quest_id):
		completed.append(quest_id)
	_save_progress()
	if _dialogue_label != null:
		_dialogue_label.text = "Everlasting Father: The Signal Prism now reveals the Echo Garden." \
			if str(reward.get("relic_id", "")) == "signal_prism" else \
			"Everlasting Father: The warning became a helpful question. The Echo Seed can awaken the golden gate."
	_update_support_target()


func _on_island_one_puzzle_solved(_result: Dictionary) -> void:
	progress.island_one_compass_solved = true
	_save_progress()
	if _dialogue_label != null:
		_dialogue_label.text = "Everlasting Father: You noticed the thought, found the useful question, and formed the Echo Seed. Island Two can now receive its light."
	_try_complete_landing_task()
	_try_complete_network_quest_task()
	_update_support_target()


func _process(_delta: float) -> void:
	if not enabled:
		return
	if _player == null:
		_find_player()
	_try_begin_island_two_story()
	if _current_task_index == 0: _try_complete_landing_task()
	elif _current_task_index == 1: _try_complete_network_quest_task()
	if _hud_root == null:
		return
	_hud_root.visible = _player != null and _player.global_position.distance_to(world.global_position) < 2050.0
	_render_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not event is InputEventKey or not event.pressed or event.echo:
		return
	if world != null and world.has_node("QuestStationPanel"):
		return
	if event.keycode == KEY_R and not _reflection_queue.is_empty():
		_reflection_open = not _reflection_open
		get_viewport().set_input_as_handled()
		return
	if not _reflection_open or _reflection_queue.is_empty():
		return
	if event.keycode in [KEY_1, KEY_2, KEY_3]:
		if event.keycode == KEY_1:
			_record_identity_side(true)
		elif event.keycode == KEY_2:
			_record_identity_side(false)
		else:
			_dismiss_identity_moment()
		get_viewport().set_input_as_handled()


func _on_checkpoint_action(action: String, save_id: String) -> void:
	match action:
		"save":
			# Checkpoints remain usable after the Observatory advances task zero.
			var roots: Array = progress.checkpoint_root_ids
			if not roots.has(save_id):
				roots.append(save_id)
			_save_progress()
			if _dialogue_label != null:
				_dialogue_label.text = "Progress saved at this Server Root."
			if _current_task_index == 0:
				world.set_world_state("waking")
				_try_complete_landing_task()
			elif _current_task_index == 1:
				_try_complete_network_quest_task()
		"heal":
			if _player == null:
				_find_player()
			if _player != null and _player.has_method("heal"):
				_player.call("heal", float(_player.get("max_health")))
			if _dialogue_label != null:
				_dialogue_label.text = "Health restored. Take a safe pause."
		"task":
			if _dialogue_label != null:
				_dialogue_label.text = str(current_task().get("prompt", "World One is complete."))


func _on_spark_collected(collectible_id: String) -> void:
	var collected: Array = progress.collected_spark_ids
	if not collected.has(collectible_id):
		collected.append(collectible_id)
	_update_spark_socket_inventory()
	_save_progress()


func _on_object_progress(save_id: String, current: int, _total: int) -> void:
	if save_id == "world_one.spark_socket" and _current_task_index == 1 and current >= 2:
		_try_complete_network_quest_task()


func _on_object_completed(save_id: String, _result: Dictionary) -> void:
	match save_id:
		"world_one.evidence_scanner":
			if _current_task_index == 2: _complete_current_task("scan_fact_fear")
		"world_one.memory_board":
			if _current_task_index == 3:
				_complete_current_task("restore_memory")
				_update_spark_socket_inventory()
		"world_one.spark_socket":
			_apply_task_gating()
		"world_one.logic_gate":
			if _current_task_index == 4:
				_complete_current_task("open_logic_gate")
		"world_one.perspective_lens":
			if _current_task_index == 5: _complete_current_task("turn_lens")
		"world_one.truth_bridge":
			if _current_task_index == 6: _complete_current_task("form_truth_bridge")
		"world_one.calm_rain_basin":
			if _current_task_index == 9: _complete_current_task("place_final_spark")


func _on_linked_task_opened(save_id: String, task_id: String) -> void:
	if save_id != "world_one.spark_socket" or task_id != "open_logic_gate":
		return
	var logic := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.LOGIC_GATE_ARCH)
	if logic != null:
		logic.interaction_enabled = true
	if _dialogue_label != null:
		_dialogue_label.text = "The third Spark powers the technology core. The linked Logic Gate task is open."
	_update_support_target()


func _on_enemy_defeated(enemy: MindSparkEnemyBase, xp_reward: int) -> void:
	var defeated_ids: Array = progress.defeated_enemy_ids
	if not defeated_ids.has(enemy.name):
		defeated_ids.append(enemy.name)
		progress.xp = int(progress.xp) + xp_reward
	_save_progress()
	if _current_task_index == 1:
		_try_complete_network_quest_task()
	elif _current_task_index == 4 and _wave_cleared("constellation"):
		var gate := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.LOGIC_GATE_ARCH)
		if gate != null and bool(gate.current_state.get("completed", false)):
			_complete_current_task("open_logic_gate")
	elif _current_task_index == 7 and _wave_cleared("ridge"):
		_complete_current_task("clear_elite_guard")


func _on_boss_combat_stopped() -> void:
	if _current_task_index == 8:
		_complete_current_task("free_warden_core")


func _on_boss_defeated(xp_reward: int) -> void:
	progress.xp = int(progress.xp) + xp_reward
	_save_progress()


func _try_complete_network_quest_task() -> void:
	var socket := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.THOUGHT_SPARK_SOCKET)
	if _current_task_index == 1 and socket != null and int(socket.current_state.get("progress", 0)) >= 2 \
			and bool(progress.island_one_compass_solved) \
			and (progress.checkpoint_root_ids as Array).size() >= 2 and _wave_cleared("network"):
		_complete_current_task("collect_two_sparks")


func _try_complete_landing_task() -> void:
	var puzzle := world.get_island_one_puzzle()
	if _current_task_index == 0 and puzzle != null and puzzle.is_signal_observatory_complete():
		_complete_current_task("wake_two_roots")


func _complete_current_task(expected_id: String) -> bool:
	if _current_task_index >= TASKS.size() or str(TASKS[_current_task_index].id) != expected_id:
		return false
	var task_index := _current_task_index
	var task_id := str(TASKS[task_index].id)
	var completed_tasks: Array = progress.completed_task_ids
	if not completed_tasks.has(task_id):
		completed_tasks.append(task_id)
	_queue_identity_moment(task_index)
	_current_task_index += 1
	task_completed.emit(task_id)
	var quest_index := int(TASKS[task_index].quest)
	if int(QUESTS[quest_index].task_end) == task_index:
		var completed_quests: Array = progress.completed_quest_ids
		var quest_id := str(QUESTS[quest_index].id)
		if not completed_quests.has(quest_id):
			completed_quests.append(quest_id)
			progress.xp = int(progress.xp) + int(QUESTS[quest_index].xp)
		# Saving intentionally precedes the gate/path unlock.
		_save_progress()
		if quest_index > 0: world.set_quest_gate_open(quest_index - 1, true)
		if quest_index == 1:
			_begin_island_two_handoff()
		quest_completed.emit(quest_id)
		if quest_index == 4:
			_complete_world()
	else:
		_save_progress()
	_sync_island_two_story_state()
	_apply_task_gating()
	return true


func complete_garden_reflection() -> bool:
	if _current_task_index != 7: return false
	var projector := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE)
	if projector == null or not bool(projector.current_state.get("completed", false)): return false
	var result: Variant = projector.current_state.get("result", {})
	progress["garden_approach"] = result.get("approach", "Earlier restoration") if result is Dictionary else "Earlier restoration"
	return _complete_current_task("clear_elite_guard")


func _begin_island_two_handoff() -> void:
	progress.island_two_invitation_received = true
	_sync_island_two_story_state()
	_save_progress()
	island_transition_started.emit(1, 2)
	if _dialogue_label != null:
		_dialogue_label.text = "Everlasting Father: Your Echo Seed is whole. Carry it to Ari's garden; its light can help us understand an unfinished experiment."


func _try_begin_island_two_story() -> void:
	if _player == null or _current_task_index != 2 or bool(progress.island_two_arrived):
		return
	if not bool(progress.island_two_invitation_received):
		return
	var centre := world.to_global(world.get_zone_position("03_constellation_court"))
	var player_flat := Vector2(_player.global_position.x, _player.global_position.z)
	var centre_flat := Vector2(centre.x, centre.z)
	if player_flat.distance_to(centre_flat) > world.get_zone_radius("03_constellation_court") * 0.92:
		return
	progress.island_two_arrived = true
	_sync_island_two_story_state()
	_save_progress()
	island_arrived.emit(2)
	if _dialogue_label != null:
		_dialogue_label.text = "Everlasting Father: Ari believes the stopped garden proves they should never have tried. Something happened here. Let us understand it before deciding what it means."
	_update_support_target()


func _island_two_story_state_for_progress() -> String:
	if _current_task_index >= 8: return "guardian_freed"
	if _current_task_index == 7: return "truth_materialised"
	if _current_task_index == 6: return "hope_reframed"
	if _current_task_index == 5: return "archive_open"
	if _current_task_index == 4: return "memory_woven"
	if _current_task_index == 3: return "evidence_sorted"
	if bool(progress.island_two_arrived): return "received"
	if bool(progress.island_two_invitation_received): return "invited"
	return "dormant"


func _sync_island_two_story_state() -> void:
	if world == null:
		return
	var state := _island_two_story_state_for_progress()
	world.set_island_two_story_state(state)


func _complete_world() -> void:
	if bool(progress.completed):
		return
	progress.completed = true
	_save_progress()
	var boss := world.get_warden() as MindSparkWardenBoss
	boss.set_gentle_rain()
	world.set_world_state("gentle_rain")
	world.set_station_spur_available(true)
	world.set_return_gate_enabled(true)
	_equip_wisdom_blade()
	if journey_state != null:
		var echoes := [
			{"id": ECHO_IDS[0], "text": "A strong thought can be a fear without being a fact."},
			{"id": ECHO_IDS[1], "text": "I can choose one truthful next step."},
		]
		for echo in echoes:
			journey_state.call("record_thought_echo", echo.text, echo.id)
			journey_state.call("mark_popped", echo.text)
		journey_state.call("complete_mind_spark", 2, ECHO_IDS)
	var mirror := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.IDENTITY_REFLECTION_MIRROR)
	if mirror != null:
		mirror.interaction_enabled = true
	var guardian := world.get_cast_member("guardian")
	if guardian != null:
		guardian.position = world.get_zone_position("06_oldest_tree_sanctuary") + _world_offset(Vector3(-36, 4, -18))
	world_completed.emit()


func _apply_task_gating() -> void:
	for object in world.get_quest_objects():
		var kind := object.definition.object_kind
		object.interaction_enabled = kind in [
			QuestObjectDefinition.ObjectKind.FOCUS_BELL_BEACON,
			QuestObjectDefinition.ObjectKind.CLEAR_PATH_PROJECTOR,
			QuestObjectDefinition.ObjectKind.CHECKPOINT_SERVER_ROOT,
		] or bool(progress.completed)
	if _current_task_index >= TASKS.size():
		return
	match _current_task_index:
		1:
			_enable_kind(QuestObjectDefinition.ObjectKind.THOUGHT_SPARK_SOCKET)
		2:
			_enable_kind(QuestObjectDefinition.ObjectKind.EVIDENCE_SCANNER)
		3:
			_enable_kind(QuestObjectDefinition.ObjectKind.MEMORY_CONSTELLATION)
		4:
			_enable_kind(QuestObjectDefinition.ObjectKind.THOUGHT_SPARK_SOCKET)
			var socket := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.THOUGHT_SPARK_SOCKET)
			if socket != null and bool(socket.current_state.get("completed", false)):
				_enable_kind(QuestObjectDefinition.ObjectKind.LOGIC_GATE_ARCH)
		5:
			_enable_kind(QuestObjectDefinition.ObjectKind.PERSPECTIVE_LENS)
		6:
			_enable_kind(QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE)
		7:
			_enable_kind(QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE)
		8:
			_enable_kind(QuestObjectDefinition.ObjectKind.WARDEN_ANCHOR)
		9:
			_enable_kind(QuestObjectDefinition.ObjectKind.CALM_RAIN_BASIN)
	_update_spark_socket_inventory()
	_activate_current_combat()
	_update_support_target()
	var focus_bell := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.FOCUS_BELL_BEACON)
	if focus_bell != null:
		focus_bell.arm_hint_timer()
	_update_cast_for_task()


func _update_cast_for_task() -> void:
	var milo := world.get_cast_member("milo")
	var guardian := world.get_cast_member("guardian")
	if milo != null:
		milo.position = world.get_zone_position("01_world_gate_landing") + _world_offset(Vector3(-28, 3, -12))
		if milo.has_method("set_dialogue_line"):
			milo.call("set_dialogue_line", "Balance the twin towers, align the compass, then wake both roots. Its cyan route points to Island Two.")
	if guardian == null:
		return
	var guide_position := world.get_zone_position("03_constellation_court") + _world_offset(Vector3(0, 4, -84))
	if _current_task_index >= 5 and _current_task_index <= 7:
		guide_position = world.get_zone_position("04_hope_path_ridge") + _world_offset(Vector3(-72, 4, -54))
	elif _current_task_index >= 8 and _current_task_index <= 9:
		guide_position = world.get_zone_position("05_thought_storm_arena") + _world_offset(Vector3(0, 4, -142))
	elif _current_task_index >= TASKS.size():
		guide_position = world.get_zone_position("06_oldest_tree_sanctuary") + _world_offset(Vector3(-36, 4, -18))
	guardian.position = guide_position
	if guardian.has_method("set_dialogue_line"):
		guardian.call("set_dialogue_line", _guardian_line_for_task(_current_task_index).get_slice(":", 1).strip_edges())


func _world_offset(value: Vector3) -> Vector3:
	if world != null and str(world.get_meta("foundation_mode", "")) == "walkable_mind_district":
		return Vector3(value.x * 0.34, maxf(1.0, value.y * 0.5), value.z * 0.34)
	return value


func _update_support_target() -> void:
	if _current_task_index >= TASKS.size():
		world.set_support_target_position(world.get_zone_position("06_oldest_tree_sanctuary"), "Oldest Tree Sanctuary")
		return
	var target: QuestObjectBase
	match _current_task_index:
		0, 1:
			var island_puzzle := world.get_island_one_puzzle()
			if island_puzzle != null and not island_puzzle.is_powered():
				var target_control_id := island_puzzle.current_target_control_id()
				var target_control := island_puzzle.get_node_or_null(
					"PuzzleControls/PuzzleControl_%s" % target_control_id) as Node3D
				if target_control != null:
					world.set_support_target_position(world.to_local(target_control.global_position),
						island_puzzle.current_objective())
					return
			if not bool(progress.island_one_compass_solved):
				var compass := world.get_island_one_puzzle()
				if compass != null:
					world.set_support_target_position(world.to_local(compass.to_global(Vector3(0, 3, 8))),
						"Aether Compass")
					return
			for object in world.get_quest_objects():
				if object.definition.object_kind == QuestObjectDefinition.ObjectKind.CHECKPOINT_SERVER_ROOT \
						and not (progress.checkpoint_root_ids as Array).has(object.save_id):
					target = object
					break
			if target == null: target = world.get_object_by_kind(QuestObjectDefinition.ObjectKind.THOUGHT_SPARK_SOCKET)
		2: target = world.get_object_by_kind(QuestObjectDefinition.ObjectKind.EVIDENCE_SCANNER)
		3: target = world.get_object_by_kind(QuestObjectDefinition.ObjectKind.MEMORY_CONSTELLATION)
		4:
			target = world.get_object_by_kind(QuestObjectDefinition.ObjectKind.LOGIC_GATE_ARCH)
		5: target = world.get_object_by_kind(QuestObjectDefinition.ObjectKind.PERSPECTIVE_LENS)
		6: target = world.get_object_by_kind(QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE)
		7:
			target = world.get_object_by_kind(QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE)
		8:
			for object in world.get_quest_objects():
				if object.definition.object_kind == QuestObjectDefinition.ObjectKind.WARDEN_ANCHOR \
						and not bool(object.current_state.get("completed", false)):
					target = object
					break
		9: target = world.get_object_by_kind(QuestObjectDefinition.ObjectKind.CALM_RAIN_BASIN)
	if target != null:
		world.set_support_target_position(world.to_local(target.global_position), target.definition.display_name)


func _activate_current_combat() -> void:
	if _current_task_index <= 1:
		world.activate_enemy_wave("network")
	elif _current_task_index == 8:
		world.activate_enemy_wave("boss_adds")
		(world.get_warden() as MindSparkWardenBoss).start_battle()
	else:
		world.activate_enemy_wave("")


func _enable_kind(kind: int) -> void:
	for object in world.get_quest_objects():
		if object.definition.object_kind == kind:
			object.interaction_enabled = true


func _wave_cleared(wave_id: String) -> bool:
	for enemy in world.get_enemies():
		if enemy.encounter_id == wave_id and enemy.state != MindSparkEnemyBase.State.DEFEATED:
			return false
	return true


func _update_spark_socket_inventory() -> void:
	var socket := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.THOUGHT_SPARK_SOCKET)
	if socket == null:
		return
	var available := (progress.collected_spark_ids as Array).size()
	if (progress.completed_task_ids as Array).has("restore_memory"):
		available += 1
	socket.set_meta("available_sparks", mini(3, available))


func _restore_runtime_state() -> void:
	_current_task_index = 0
	while _current_task_index < TASKS.size() and (progress.completed_task_ids as Array).has(str(TASKS[_current_task_index].id)):
		_current_task_index += 1
	for collectible in world.get_collectibles():
		if (progress.collected_spark_ids as Array).has(collectible.collectible_id):
			collectible.restore_collected()
	for enemy in world.get_enemies():
		if (progress.defeated_enemy_ids as Array).has(enemy.name):
			enemy.restore_defeated()
	for quest_index in 4:
		world.set_quest_gate_open(quest_index, (progress.completed_quest_ids as Array).has(str(QUESTS[quest_index + 1].id)))
	# Existing task IDs remain stable; the extra chapter is a zero-XP subdivision.
	if (progress.completed_task_ids as Array).has("wake_two_roots") and not (progress.completed_quest_ids as Array).has("notice_signal"):
		progress.completed_quest_ids.append("notice_signal")
	if (progress.completed_quest_ids as Array).has("island_one_awareness"):
		progress.island_two_invitation_received = true
	_sync_island_two_story_state()
	if (progress.completed_task_ids as Array).has("free_warden_core"):
		(world.get_warden() as MindSparkWardenBoss).restore_combat_stopped()
	if bool(progress.completed):
		(world.get_warden() as MindSparkWardenBoss).set_gentle_rain()
		world.set_world_state("gentle_rain")
		world.set_station_spur_available(true)
		world.set_return_gate_enabled(true)
		_equip_wisdom_blade()
	elif bool(progress.island_one_compass_solved) or not (progress.checkpoint_root_ids as Array).is_empty():
		world.set_world_state("waking")


func _queue_identity_moment(task_index: int) -> void:
	if not IDENTITY_MOMENTS.has(task_index):
		return
	var moment: Dictionary = IDENTITY_MOMENTS[task_index]
	if identity_tracker != null and identity_tracker.has_method("has_evidence") and bool(identity_tracker.call("has_evidence", moment.id)):
		return
	_reflection_queue.append(moment.duplicate(true))


func _record_identity_side(side_a: bool) -> void:
	if _reflection_queue.is_empty():
		return
	var moment: Dictionary = _reflection_queue[0]
	if identity_tracker != null:
		identity_tracker.call("record_evidence", moment.id, moment.axis, moment.side_a if side_a else moment.side_b)
	_dismiss_identity_moment()


func _dismiss_identity_moment() -> void:
	if not _reflection_queue.is_empty():
		_reflection_queue.pop_front()
	_reflection_open = false


func _equip_wisdom_blade() -> void:
	if _player == null:
		_find_player()
	if _player == null:
		return
	_player.attack_damage = 30.0
	var socket := _player.get_node_or_null("EquipmentSockets/WisdomBlade") as Marker3D
	if socket == null or socket.has_node("WisdomBladeCrystal"):
		return
	var crystal := MeshInstance3D.new()
	crystal.name = "WisdomBladeCrystal"
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.24, 1.35, 0.32)
	crystal.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("62e5ff")
	material.emission_enabled = true
	material.emission = Color("38d9ff")
	material.emission_energy_multiplier = 1.5
	crystal.material_override = material
	socket.add_child(crystal)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("Player")
	if not players.is_empty():
		_player = players[0] as CharacterBody3D


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "MindSparkQuestHUD"
	canvas.layer = 31
	add_child(canvas)
	_hud_root = ColorRect.new()
	_hud_root.name = "QuestPanel"
	_hud_root.color = Color(0.025, 0.05, 0.12, 0.88)
	_hud_root.position = Vector2(22, 78)
	_hud_root.size = Vector2(530, 184)
	canvas.add_child(_hud_root)
	_quest_label = _hud_label(Vector2(16, 12), Vector2(498, 30), 20, Color("ffe27a"))
	_task_label = _hud_label(Vector2(16, 48), Vector2(498, 58), 17, Color("e8f7ff"))
	_dialogue_label = _hud_label(Vector2(16, 108), Vector2(498, 38), 15, Color("b8e9d0"))
	_reflection_label = _hud_label(Vector2(16, 148), Vector2(498, 28), 14, Color("e6cfff"))


func _hud_label(at: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = size_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	_hud_root.add_child(label)
	return label


func _render_hud() -> void:
	if bool(progress.completed):
		_quest_label.text = "WORLD ONE COMPLETE • STAR OF WISDOM"
		_task_label.text = "Wisdom Blade equipped • Heart Melody World Gate ready"
		_dialogue_label.text = "Everlasting Father: What helped you move forward when the path was not clear?"
	else:
		var task := current_task()
		if _current_task_index in [0, 1]:
			var island_puzzle := world.get_island_one_puzzle()
			var signal_complete := island_puzzle != null and island_puzzle.is_signal_observatory_complete()
			_quest_label.text = "ISLAND ONE • QUEST %d/5 • %s" % [2 if signal_complete else 1,
				"ECHO GARDEN" if signal_complete else "SIGNAL OBSERVATORY"]
			_task_label.text = "%s\n%s" % [island_puzzle.current_objective(),
				str(island_puzzle.current_task_id()).replace("_", " ").replace(".", " • ").to_upper()]
			_dialogue_label.text = _guardian_line_for_task(_current_task_index)
			_reflection_label.text = "Movement and experimentation are untimed; every wrong attempt preserves your work."
			if island_puzzle.is_echo_garden_complete():
				_task_label.text = "Echo Seed secured. Save at the two Server Roots: %d/2.\nThen complete the Thought Spark relay before the route to Island Two opens." % (progress.checkpoint_root_ids as Array).size()
				_dialogue_label.text = "Everlasting Father: Your seed is ready. Ground its light at the roots, then carry it onward."
			return
		var quest: Dictionary = QUESTS[int(task.get("quest", 0))]
		_quest_label.text = "QUEST %d/5 • %s • %d XP" % [int(task.quest) + 1, quest.title, int(progress.xp)]
		if _current_task_index == 1:
			task.prompt = "Place two Thought Sparks and clear the network encounter to open the next route."
		_task_label.text = "TASK %d/10 • %s\n%s" % [_current_task_index + 1, task.title, task.prompt]
		_dialogue_label.text = _guardian_line_for_task(_current_task_index)
	if _reflection_queue.is_empty():
		_reflection_label.text = "Identity evidence is private, optional, and never affects quest success."
	elif not _reflection_open:
		_reflection_label.text = "R • Optional private reflection available"
	else:
		var moment: Dictionary = _reflection_queue[0]
		_reflection_label.text = "1 %s     2 %s     3 PRIVATE / SKIP" % [moment.a, moment.b]


func _guardian_line_for_task(task_index: int) -> String:
	if task_index == 0:
		return "Everlasting Father: Notice the signal without obeying it. Then listen for the useful question inside its echo."
	if task_index == 1:
		var puzzle := world.get_island_one_puzzle()
		if puzzle != null and not puzzle.is_echo_garden_complete():
			return "Everlasting Father: Carry your Signal Prism into the Echo Garden. Listen for the useful question inside the thought."
		return "Everlasting Father: Complete the Spark relay. Its current will carry your Echo Seed across the golden threshold to Island Two."
	if task_index == 2:
		if bool(progress.island_two_invitation_received) and not bool(progress.island_two_arrived):
			return "Everlasting Father: The intact Echo Seed reveals Ari's unfinished garden. Follow its receiver light from the bridge."
		return "Everlasting Father: Ari feels frightened. That feeling matters. Inspect the plate, recorder and cooling valve before testing an explanation."
	if task_index == 3:
		return "Everlasting Father: The record shows drift, lost cooling and a protective shutdown. Reconstruct their order. Ari's touch alone may not explain it."
	if task_index == 4:
		return "Everlasting Father: Which explanation fits every observation? Run the model. A mismatch is useful information, not a failure."
	if task_index == 5:
		return "Everlasting Father: Ari's feeling, the machine's behaviour and an offer of help each add something. Explore all three."
	if task_index == 6:
		return "Everlasting Father: Test a smaller bed, work with Ari, or restore cooling first. Each is a useful next step. Watch how your optical adjustments change the light."
	if task_index == 7:
		return "Ari: I still have something to learn. Now I know where to start. Share our discovery at the projector to reveal the storm beyond."
	return "Everlasting Father: You found a way forward without every answer. Help the troubled storm release its anchors and become gentle rain."


func _save_progress() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"schema_version": 1, "progress": progress}))
	file.close()
	return true


func _load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if parsed is Dictionary and parsed.get("progress", null) is Dictionary:
		progress.merge(parsed.progress, true)
