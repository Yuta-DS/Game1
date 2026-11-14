class_name MindSparkWorldOneQuest
extends Node

signal task_completed(task_id: String)
signal quest_completed(quest_id: String)
signal world_completed

const SAVE_PATH := "user://mind_spark_walkable_world_one_progress.json"
const ECHO_IDS := ["world_one.fact_and_fear", "world_one.hope_path"]
const QUESTS := [
	{"id": "wake_network", "title": "WAKE THE LIVING NETWORK", "task_end": 1, "xp": 75, "target_minutes": 13},
	{"id": "broken_pattern", "title": "READ THE BROKEN PATTERN", "task_end": 4, "xp": 100, "target_minutes": 13},
	{"id": "hope_path", "title": "BUILD THE HOPE PATH", "task_end": 7, "xp": 125, "target_minutes": 14},
	{"id": "free_warden", "title": "FREE THE THOUGHT STORM WARDEN", "task_end": 9, "xp": 200, "target_minutes": 20},
]
const TASKS := [
	{"id": "wake_two_roots", "quest": 0, "title": "Wake two Checkpoint Server Roots", "zone": "01–02", "prompt": "Use SAVE at both glowing Server Roots • 0/2"},
	{"id": "collect_two_sparks", "quest": 0, "title": "Collect and place two Thought Sparks", "zone": "02", "prompt": "Walk through two Sparks, then use the Spark Socket • 0/2"},
	{"id": "scan_fact_fear", "quest": 1, "title": "Separate FACT from FEAR", "zone": "03", "prompt": "Scan the clue and choose FACT or FEAR"},
	{"id": "restore_memory", "quest": 1, "title": "Restore the three-node memory", "zone": "03", "prompt": "Connect the three large nodes in order; reset and help are available"},
	{"id": "open_logic_gate", "quest": 1, "title": "Open the Logic Gate", "zone": "03", "prompt": "Place the memory Spark, then place the two evidence pieces"},
	{"id": "turn_lens", "quest": 2, "title": "Reveal the Hope Path", "zone": "04", "prompt": "Turn the Perspective Lens through three fixed angles"},
	{"id": "form_truth_bridge", "quest": 2, "title": "Make the Truth Bridge solid", "zone": "04", "prompt": "Choose the true statement; the tile changes shape"},
	{"id": "clear_elite_guard", "quest": 2, "title": "Free the elite guard", "zone": "04", "prompt": "Break the Stalker and Sentinel Blight shells"},
	{"id": "free_warden_core", "quest": 3, "title": "Break three anchors and free the core", "zone": "05", "prompt": "Dodge wide lines, strike open rings, then attack the crystal core"},
	{"id": "place_final_spark", "quest": 3, "title": "Change the storm into gentle rain", "zone": "05–06", "prompt": "HOLD at the Calm Rain Basin; there is no timed input"},
]
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
	"collected_spark_ids": [], "defeated_enemy_ids": [], "xp": 0, "completed": false,
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
	boss.defeated.connect(_on_boss_defeated)
	boss.combat_stopped.connect(_on_boss_combat_stopped)


func _process(_delta: float) -> void:
	if not enabled or _hud_root == null:
		return
	if _player == null:
		_find_player()
	_hud_root.visible = _player != null and _player.global_position.distance_to(world.global_position) < 2050.0
	_render_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not event is InputEventKey or not event.pressed or event.echo:
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
			_save_progress()
			if _dialogue_label != null:
				_dialogue_label.text = "Progress saved at this Server Root."
			if _current_task_index == 0:
				var roots: Array = progress.checkpoint_root_ids
				if not roots.has(save_id):
					roots.append(save_id)
				world.set_world_state("waking")
				_save_progress()
				if roots.size() >= 2:
					_complete_current_task("wake_two_roots")
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
			if _current_task_index == 4 and _wave_cleared("constellation"):
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
			and _wave_cleared("network"):
		_complete_current_task("collect_two_sparks")


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
		world.set_quest_gate_open(quest_index, true)
		quest_completed.emit(quest_id)
		if quest_index == 3:
			_complete_world()
	else:
		_save_progress()
	_apply_task_gating()
	return true


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
			var logic := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.LOGIC_GATE_ARCH)
			logic.interaction_enabled = socket != null and bool(socket.current_state.get("completed", false))
		5:
			_enable_kind(QuestObjectDefinition.ObjectKind.PERSPECTIVE_LENS)
		6:
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
			milo.call("set_dialogue_line", "The Blight is a shell, not the creature. Wake both roots and follow the cyan path.")
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
		0:
			for object in world.get_quest_objects():
				if object.definition.object_kind == QuestObjectDefinition.ObjectKind.CHECKPOINT_SERVER_ROOT \
						and not (progress.checkpoint_root_ids as Array).has(object.save_id):
					target = object
					break
		1: target = world.get_object_by_kind(QuestObjectDefinition.ObjectKind.THOUGHT_SPARK_SOCKET)
		2: target = world.get_object_by_kind(QuestObjectDefinition.ObjectKind.EVIDENCE_SCANNER)
		3: target = world.get_object_by_kind(QuestObjectDefinition.ObjectKind.MEMORY_CONSTELLATION)
		4:
			var socket := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.THOUGHT_SPARK_SOCKET)
			target = world.get_object_by_kind(QuestObjectDefinition.ObjectKind.LOGIC_GATE_ARCH) \
				if socket != null and bool(socket.current_state.get("completed", false)) else socket
		5: target = world.get_object_by_kind(QuestObjectDefinition.ObjectKind.PERSPECTIVE_LENS)
		6: target = world.get_object_by_kind(QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE)
		7:
			world.set_support_target_position(world.get_zone_position("04_hope_path_ridge"), "Elite guard")
			return
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
	elif _current_task_index <= 4:
		world.activate_enemy_wave("constellation")
	elif _current_task_index == 7:
		world.activate_enemy_wave("ridge")
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
		world.set_quest_gate_open(quest_index, (progress.completed_quest_ids as Array).has(str(QUESTS[quest_index].id)))
	if (progress.completed_task_ids as Array).has("free_warden_core"):
		(world.get_warden() as MindSparkWardenBoss).restore_combat_stopped()
	if bool(progress.completed):
		(world.get_warden() as MindSparkWardenBoss).set_gentle_rain()
		world.set_world_state("gentle_rain")
		world.set_station_spur_available(true)
		world.set_return_gate_enabled(true)
		_equip_wisdom_blade()
	elif not (progress.checkpoint_root_ids as Array).is_empty():
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
	# Below the compact minimap, which fills the top-left corner down to y=304
	# (art_castle_minimap.gd: 18 px margin + 286 px COMPACT_SIZE, enlarged on
	# touch devices by hud_scale()).
	_hud_root.position = Vector2(22, 26 + 286 * preload("res://scripts/art_castle_minimap.gd").hud_scale(get_viewport()))
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
		_dialogue_label.text = "Mother Guardian: What helped you move forward when the path was not clear?"
	else:
		var task := current_task()
		var quest: Dictionary = QUESTS[int(task.get("quest", 0))]
		_quest_label.text = "QUEST %d/4 • %s • %d XP" % [int(task.quest) + 1, quest.title, int(progress.xp)]
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
	if task_index <= 1:
		return "Mayor Milo: The sword breaks only the Blight shell. Wake the roots and follow their cyan light."
	if task_index <= 4:
		return "Mother Guardian: A thought can feel strong without being a fact. Look for one clear sign."
	if task_index <= 7:
		return "Mother Guardian: Each clear choice changes the route; it does not grade you."
	return "Mother Guardian: The storm is hurt and confused. Break the dark anchors, then help it become rain."


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
