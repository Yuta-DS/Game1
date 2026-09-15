class_name QuestObjectBase
extends Node3D

signal interaction_requested(object: QuestObjectBase)
signal progress_changed(save_id: String, current: int, total: int)
signal feedback_changed(save_id: String, message: String, icon: String)
signal completed(save_id: String, result: Dictionary)
signal linked_task_opened(save_id: String, task_id: String)
signal hint_requested(save_id: String)
signal checkpoint_action_requested(action: String)

const Definition := preload("res://scripts/mind_spark/quest_objects/quest_object_definition.gd")
const StateStore := preload("res://scripts/mind_spark/quest_objects/quest_object_state_store.gd")
const UnfinishedLight := preload("res://scripts/mind_spark/unfinished_light_rules.gd")
const ResearchSound := preload("res://scripts/mind_spark/research_sound_cues.gd")
const MODEL_SCENE_PATHS := [
	"res://scenes/mind_spark/quest_objects/models/thought_spark_socket_model.tscn",
	"res://scenes/mind_spark/quest_objects/models/evidence_scanner_model.tscn",
	"res://scenes/mind_spark/quest_objects/models/perspective_lens_model.tscn",
	"res://scenes/mind_spark/quest_objects/models/memory_constellation_board_model.tscn",
	"res://scenes/mind_spark/quest_objects/models/logic_gate_arch_model.tscn",
	"res://scenes/mind_spark/quest_objects/models/truth_bridge_tile_model.tscn",
	"res://scenes/mind_spark/quest_objects/models/focus_bell_beacon_model.tscn",
	"res://scenes/mind_spark/quest_objects/models/warden_anchor_model.tscn",
	"res://scenes/mind_spark/quest_objects/models/calm_rain_basin_model.tscn",
	"res://scenes/mind_spark/quest_objects/models/identity_reflection_mirror_model.tscn",
	"res://scenes/mind_spark/quest_objects/models/checkpoint_server_root_model.tscn",
	"res://scenes/mind_spark/quest_objects/models/clear_path_projector_model.tscn",
]
const BLENDER_MODEL_PATHS := [
	"res://assets3D/mind_spark/quest_objects/glb/thought_spark_socket.glb",
	"res://assets3D/mind_spark/quest_objects/glb/evidence_scanner.glb",
	"res://assets3D/mind_spark/quest_objects/glb/perspective_lens.glb",
	"res://assets3D/mind_spark/quest_objects/glb/memory_constellation_board.glb",
	"res://assets3D/mind_spark/quest_objects/glb/logic_gate_arch.glb",
	"res://assets3D/mind_spark/quest_objects/glb/truth_bridge_tile.glb",
	"res://assets3D/mind_spark/quest_objects/glb/focus_bell_beacon.glb",
	"res://assets3D/mind_spark/quest_objects/glb/warden_anchor.glb",
	"res://assets3D/mind_spark/quest_objects/glb/calm_rain_basin.glb",
	"res://assets3D/mind_spark/quest_objects/glb/identity_reflection_mirror.glb",
	"res://assets3D/mind_spark/quest_objects/glb/checkpoint_server_root.glb",
	"res://assets3D/mind_spark/quest_objects/glb/clear_path_projector.glb",
]
const BLENDER_STATE_PARTS := [
	{"inactive": ["CentralSpark_Inactive"], "active": ["CentralSpark_Active"], "completed": ["CentralSpark", "SparkBeam"]},
	{"inactive": ["ScannerGlass_State_Inactive"], "active": ["ScannerGlass_State_Active"], "completed": ["ScannerGlass_State_Completed"]},
	{"inactive": ["LensGlass_Inactive"], "active": ["LensGlass_Active"], "completed": ["LensGlass_Completed"]},
	{"inactive": ["ConstellationGlyph_Inactive"], "active": ["ConstellationGlyph_Active"], "completed": ["ConstellationStar"]},
	{"inactive": ["Door"], "active": ["Door_Active"], "completed": ["Door_Completed", "PathBeam"]},
	{"inactive": ["CircuitTileState_Inactive"], "active": ["CircuitTileState_Active"], "completed": ["CompletionCrystal"]},
	{"inactive": ["HintArrowMarker_Inactive"], "active": ["HintArrowMarker_Active"], "completed": ["HintArrowMarker_Completed"]},
	{"inactive": ["WardenShield_Inactive"], "active": ["WardenShield_Active"], "completed": ["BrokenCore"]},
	{"inactive": ["StormCloud_Inactive"], "active": ["StormCloud_Active"], "completed": ["BasinWater"]},
	{"inactive": ["ReflectionSurface_Inactive"], "active": ["ReflectionSurface_Active"], "completed": ["ReflectionSurface"]},
	{"inactive": ["ServerConsoleGlow_Inactive"], "active": ["ServerConsoleGlow_Active"], "completed": ["ServerConsoleGlow_Completed"]},
	{"inactive": ["ProjectorBeam_Inactive"], "active": ["ProjectorBeam_Active"], "completed": ["ProjectorGoalStar"]},
]
const AUTHORED_TEXTURE_PATHS := [
	"res://assets/textures/mind_spark/quest_objects/thought_spark_socket_albedo_v1.png",
	"res://assets/textures/mind_spark/quest_objects/evidence_scanner_albedo_v1.png",
	"res://assets/textures/mind_spark/quest_objects/perspective_lens_albedo_v1.png",
	"res://assets/textures/mind_spark/quest_objects/memory_constellation_albedo_v1.png",
	"res://assets/textures/mind_spark/quest_objects/logic_gate_arch_albedo_v1.png",
	"res://assets/textures/mind_spark/quest_objects/truth_bridge_tile_albedo_v1.png",
	"res://assets/textures/mind_spark/quest_objects/focus_bell_beacon_albedo_v1.png",
	"res://assets/textures/mind_spark/quest_objects/warden_anchor_albedo_v1.png",
	"res://assets/textures/mind_spark/quest_objects/calm_rain_basin_albedo_v1.png",
	"res://assets/textures/mind_spark/quest_objects/identity_reflection_mirror_albedo_v1.png",
	"res://assets/textures/mind_spark/quest_objects/checkpoint_server_root_albedo_v1.png",
	"res://assets/textures/mind_spark/quest_objects/clear_path_projector_albedo_v1.png",
]
const AUTHORED_TEXTURE_TARGETS := [
	"SparkReceiverBowl",
	"ScannerGlass",
	"LensBody/LensCrystal",
	"ConstellationSlate",
	"Door",
	"BridgeTile/CircuitTile",
	"FocusBell",
	"WardenShield",
	"BasinWater",
	"ReflectionSurface",
	"ServerRootTrunk",
	"RouteProjector",
]

enum AnchorState { TELEGRAPH, VULNERABLE, RECOVERY, BROKEN }

@export var definition: QuestObjectDefinition
@export var save_id := ""
@export var persist_state := true
@export var interaction_enabled := true
@export var state_store_path := StateStore.DEFAULT_PATH

@onready var interaction_area: Area3D = $InteractionArea
@onready var prompt: Label3D = $Prompt
@onready var status: Label3D = $Status
@onready var icon: Label3D = $Icon
@onready var visual_root: Node3D = $VisualRoot
@onready var core: MeshInstance3D = $VisualRoot/Core
@onready var feedback_sound: AudioStreamPlayer3D = $FeedbackSound
@onready var hint_timer: Timer = $HintTimer

var current_state: Dictionary = {}
var state_store := StateStore.new()
var _completion_emitted := false
var _ready_for_use := false
var _sound_action: StringName = &"primary"
var _sound_cache: Dictionary = {}


func configure(new_definition: QuestObjectDefinition, new_save_id: String,
		custom_store_path := "") -> void:
	definition = new_definition
	save_id = new_save_id
	if not custom_store_path.is_empty():
		state_store_path = custom_store_path
	if is_node_ready():
		_setup_object()


func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	hint_timer.timeout.connect(_on_hint_timer_timeout)
	_setup_object()


func _setup_object() -> void:
	if definition == null:
		push_error("QuestObjectBase requires a QuestObjectDefinition")
		return
	if save_id.is_empty():
		save_id = definition.resource_path.get_file().get_basename()
	state_store = StateStore.new(state_store_path)
	current_state = _default_state()
	if persist_state:
		var restored := state_store.load_object(save_id)
		if not restored.is_empty():
			current_state.merge(restored, true)
	_completion_emitted = bool(current_state.get("completed", false))
	_build_specialized_visuals()
	_apply_visual_state(false)
	_ready_for_use = true
	if definition.object_kind == Definition.ObjectKind.FOCUS_BELL_BEACON and interaction_enabled:
		arm_hint_timer()


func interact(action: StringName = &"primary", value: Variant = null) -> Dictionary:
	if not _ready_for_use:
		return _result(false, "not_ready")
	if not interaction_enabled:
		return _result(false, "locked_by_current_quest")
	if bool(current_state.get("completed", false)) and definition.object_kind not in [
		Definition.ObjectKind.IDENTITY_REFLECTION_MIRROR,
		Definition.ObjectKind.CHECKPOINT_SERVER_ROOT,
		Definition.ObjectKind.CLEAR_PATH_PROJECTOR,
		Definition.ObjectKind.FOCUS_BELL_BEACON]:
		return _result(true, "already_complete")
	if definition.object_kind == Definition.ObjectKind.THOUGHT_SPARK_SOCKET:
		var available_sparks := int(get_meta("available_sparks", definition.validated_total()))
		if int(current_state.get("progress", 0)) >= available_sparks:
			return _result(false, "find_thought_spark_first")
	if bool(get_meta("unfinished_light", false)) and save_id in UnfinishedLight.IDS:
		_sound_action=action
		var outcome := UnfinishedLight.use(self, action, value)
		_apply_visual_state(true)
		return _result(bool(outcome[0]), str(outcome[1]))
	if definition.object_kind == Definition.ObjectKind.FOCUS_BELL_BEACON:
		arm_hint_timer()
	var accepted := false
	var reason := "unsupported_action"
	match definition.object_kind:
		Definition.ObjectKind.THOUGHT_SPARK_SOCKET:
			accepted = action == &"primary" or action == &"place_spark"
			if accepted: reason = _advance_progress()
		Definition.ObjectKind.EVIDENCE_SCANNER:
			var scanner := _use_evidence_scanner(action)
			accepted = scanner[0]; reason = scanner[1]
		Definition.ObjectKind.PERSPECTIVE_LENS:
			var lens := _use_perspective_lens(action)
			accepted = lens[0]; reason = lens[1]
		Definition.ObjectKind.MEMORY_CONSTELLATION:
			var board := _use_sequence(action, value)
			accepted = board[0]; reason = board[1]
		Definition.ObjectKind.LOGIC_GATE_ARCH:
			accepted = action in [&"primary", &"place_evidence"]
			if accepted: reason = _advance_progress()
		Definition.ObjectKind.TRUTH_BRIDGE_TILE:
			var truth := _use_truth_materialiser(action)
			accepted = truth[0]; reason = truth[1]
		Definition.ObjectKind.FOCUS_BELL_BEACON:
			accepted = action in [&"primary", &"help", &"toggle"]
			if accepted:
				current_state["hint_enabled"] = not bool(current_state.get("hint_enabled", false))
				reason = "hint_on" if current_state["hint_enabled"] else "hint_off"
				_save_and_feedback(reason, "➜" if current_state["hint_enabled"] else "◇")
				if current_state["hint_enabled"]: hint_requested.emit(save_id)
		Definition.ObjectKind.WARDEN_ANCHOR:
			var anchor := _use_warden_anchor(action)
			accepted = anchor[0]; reason = anchor[1]
		Definition.ObjectKind.CALM_RAIN_BASIN:
			accepted = action in [&"primary", &"hold"]
			if accepted: reason = _complete({"weather": "gentle_rain"})
		Definition.ObjectKind.IDENTITY_REFLECTION_MIRROR:
			var reflection := _use_reflection(action, value)
			accepted = reflection[0]; reason = reflection[1]
		Definition.ObjectKind.CHECKPOINT_SERVER_ROOT:
			var checkpoint := _use_checkpoint(action)
			accepted = checkpoint[0]; reason = checkpoint[1]
		Definition.ObjectKind.CLEAR_PATH_PROJECTOR:
			accepted = action in [&"primary", &"toggle"]
			if accepted:
				current_state["guide_enabled"] = not bool(current_state.get("guide_enabled", false))
				reason = "route_on" if current_state["guide_enabled"] else "route_off"
				_save_and_feedback(reason, "★" if current_state["guide_enabled"] else "◇")
	_apply_visual_state(true)
	return _result(accepted, reason)


func take_damage(amount: float, _source: Node = null) -> float:
	if definition == null or definition.object_kind != Definition.ObjectKind.WARDEN_ANCHOR or amount <= 0.0:
		return 0.0
	if int(current_state.get("anchor_state", AnchorState.TELEGRAPH)) != AnchorState.VULNERABLE:
		_save_and_feedback("DODGE FIRST • WAIT FOR OPEN RING", "➜")
		return 0.0
	var result := interact(&"strike")
	return amount if bool(result.get("accepted", false)) else 0.0


func reset_sequence() -> bool:
	if definition == null or definition.object_kind not in [
			Definition.ObjectKind.MEMORY_CONSTELLATION,
			Definition.ObjectKind.PERSPECTIVE_LENS]:
		return false
	current_state["progress"] = 0
	current_state["sequence"] = []
	current_state["angle_step"] = -1
	current_state["completed"] = false
	_completion_emitted = false
	_save_and_feedback("RESET • 0/%d" % definition.validated_total(), "↺")
	_apply_visual_state(true)
	return true


func available_actions() -> Array[StringName]:
	match definition.object_kind:
		Definition.ObjectKind.EVIDENCE_SCANNER:
			return [&"fact", &"fear"] if bool(current_state.get("scanned", false)) else [&"scan"]
		Definition.ObjectKind.PERSPECTIVE_LENS:
			return [&"turn", &"reset"]
		Definition.ObjectKind.MEMORY_CONSTELLATION:
			return [&"node", &"reset", &"help"]
		Definition.ObjectKind.LOGIC_GATE_ARCH:
			return [&"place_evidence"]
		Definition.ObjectKind.TRUTH_BRIDGE_TILE:
			return [&"fear", &"fantasy", &"true"]
		Definition.ObjectKind.FOCUS_BELL_BEACON:
			return [&"help", &"toggle"]
		Definition.ObjectKind.WARDEN_ANCHOR:
			return [&"strike"] if int(current_state.get("anchor_state", 0)) == AnchorState.VULNERABLE else [&"dodge"]
		Definition.ObjectKind.IDENTITY_REFLECTION_MIRROR:
			return [&"answer_a", &"answer_b", &"private", &"skip", &"replay"]
		Definition.ObjectKind.CHECKPOINT_SERVER_ROOT:
			return [&"save", &"heal", &"task"]
		_:
			return [&"primary"]


func arm_hint_timer(wait_seconds := 45.0) -> void:
	if definition == null or definition.object_kind != Definition.ObjectKind.FOCUS_BELL_BEACON:
		return
	hint_timer.start(maxf(1.0, wait_seconds))


func _default_state() -> Dictionary:
	return {
		"completed": false,
		"progress": 0,
		"sequence": [],
		"scanned": false,
		"result": "",
		"angle_step": -1,
		"hint_enabled": false,
		"anchor_state": AnchorState.TELEGRAPH,
		"guide_enabled": false,
		"last_action": "",
	}


func _advance_progress() -> String:
	var total := definition.validated_total()
	current_state["progress"] = mini(total, int(current_state.get("progress", 0)) + 1)
	if int(current_state["progress"]) >= total:
		return _complete({"count": total})
	_save_and_feedback("%d/%d" % [current_state["progress"], total], "◆")
	progress_changed.emit(save_id, int(current_state["progress"]), total)
	return "progress"


func _use_evidence_scanner(action: StringName) -> Array:
	if save_id == "world_one.evidence_scanner":
		return _use_evidence_cards(action)
	if action in [&"primary", &"scan"] and not bool(current_state.get("scanned", false)):
		current_state["scanned"] = true
		_save_and_feedback("SCANNED • CHOOSE FACT OR FEAR", "⌕")
		return [true, "choose_fact_or_fear"]
	if action in [&"fact", &"fear"] and bool(current_state.get("scanned", false)):
		current_state["result"] = str(action)
		return [true, _complete({"evidence": str(action)})]
	return [false, "scan_first" if not current_state["scanned"] else "choose_fact_or_fear"]


const EVIDENCE_CARDS := [
	"The practice log records one completed attempt.",
	"One difficult attempt means I will always fail.",
	"The log records a second attempt after a pause.",
]
const EVIDENCE_ANSWERS := [&"fact", &"fear", &"fact"]
const EVIDENCE_HINTS := [
	"Look for something the log actually records, not a prediction.",
	"Does one attempt prove what will always happen? Worry is real, but this prediction is not established.",
	"The second attempt is an observed action, even though its outcome is unknown.",
]

func _use_evidence_cards(action: StringName) -> Array:
	var index := clampi(int(current_state.get("evidence_index", 0)), 0, 2)
	if action in [&"scan", &"primary"]:
		current_state["scanned"] = true
		_save_and_feedback("CARD %d/3 • READ THE LOG" % (index + 1), "⌕")
		return [true, "read_evidence"]
	if not bool(current_state.get("scanned", false)):
		return [false, "scan_first"]
	if action not in [&"fact", &"fear"]:
		return [false, "choose_fact_or_fear"]
	if action != EVIDENCE_ANSWERS[index]:
		_save_and_feedback(EVIDENCE_HINTS[index], "?")
		return [false, "reconsider_evidence"]
	current_state["evidence_index"] = index + 1
	current_state["progress"] = index + 1
	if index == 2:
		return [true, _complete({"evidence": "verified_log", "cards": 3})]
	current_state["scanned"] = false
	_save_and_feedback("EVIDENCE SECURED • SCAN THE NEXT CARD", "◆")
	return [true, "evidence_secured"]


func _use_perspective_lens(action: StringName) -> Array:
	if action == &"reset":
		return [reset_sequence(), "reset"]
	if action not in [&"primary", &"turn"]:
		return [false, "turn_or_reset"]
	current_state["angle_step"] = (int(current_state.get("angle_step", 0)) + 1) % 3
	current_state["progress"] = int(current_state["angle_step"]) + 1
	if int(current_state["angle_step"]) == 2:
		return [true, _complete({"angle_step": 2, "path_revealed": true})]
	_save_and_feedback("ANGLE %d/3" % (int(current_state["angle_step"]) + 1), "◒")
	return [true, "angle_changed"]


const TRUTH_STATEMENTS := {
	"fear": "One difficult attempt proves I will always fail.",
	"fantasy": "If I hope enough, every attempt will be easy.",
	"true": "One difficult attempt can teach me how to try the next step.",
}


func _use_truth_materialiser(action: StringName) -> Array:
	if action == &"primary" or action not in [&"fear", &"fantasy", &"true"]:
		return [false, "choose_supported_statement"]
	current_state["selected_statement"] = str(action)
	if action == &"fear":
		_save_and_feedback("FEAR IS MEANINGFUL • BUT ‘ALWAYS’ IS NOT IN THE LOG", "?")
		return [false, "prediction_not_supported"]
	if action == &"fantasy":
		_save_and_feedback("HOPE NEEDS AN HONEST NEXT STEP • NOT A PROMISE OF EASE", "?")
		return [false, "fantasy_not_supported"]
	return [true, _complete({"answer": "true", "statement": TRUTH_STATEMENTS["true"],
		"materialised_path": true})]


func _use_sequence(action: StringName, value: Variant) -> Array:
	if save_id == "world_one.memory_board":
		if action == &"undo":
			var prior: Array = current_state.get("sequence", [])
			if prior.is_empty():
				return [false, "nothing_to_undo"]
			prior.pop_back()
			current_state["sequence"] = prior
			current_state["progress"] = prior.size()
			_save_and_feedback("LAST LINK REMOVED • TRY ANOTHER CONNECTION", "↺")
			return [true, "link_undone"]
		if action in [&"primary", &"node"] and value == null:
			return [false, "choose_a_memory_node"]
	if action == &"reset":
		return [reset_sequence(), "reset"]
	if action == &"help":
		hint_requested.emit(save_id)
		_save_and_feedback("TRY THE LARGE NODES IN ORDER", "?")
		return [true, "help"]
	if action not in [&"primary", &"node"]:
		return [false, "choose_node"]
	var order: Array[String] = definition.sequence_order
	if order.is_empty():
		order = ["notice", "name", "choose"]
	var sequence: Array = current_state.get("sequence", [])
	var expected := order[sequence.size()]
	var chosen := str(value) if value != null else expected
	if chosen != expected:
		current_state["sequence"] = []
		current_state["progress"] = 0
		_save_and_feedback("GENTLE RESET • 0/%d" % order.size(), "↺")
		return [true, "wrong_link_reset"]
	sequence.append(chosen)
	current_state["sequence"] = sequence
	current_state["progress"] = sequence.size()
	if sequence.size() == order.size():
		return [true, _complete({"memory_restored": true, "spark_awarded": true})]
	_save_and_feedback("%d/%d NODES" % [sequence.size(), order.size()], "◆")
	return [true, "progress"]


func _use_warden_anchor(action: StringName) -> Array:
	var anchor_state := int(current_state.get("anchor_state", AnchorState.TELEGRAPH))
	if anchor_state == AnchorState.TELEGRAPH and action in [&"primary", &"dodge"]:
		current_state["anchor_state"] = AnchorState.VULNERABLE
		_save_and_feedback("OPEN RING • STRIKE", "◎")
		return [true, "vulnerable"]
	if anchor_state == AnchorState.VULNERABLE and action in [&"primary", &"strike"]:
		current_state["anchor_state"] = AnchorState.BROKEN
		return [true, _complete({"shield_layers_broken": 1})]
	return [false, "dodge_telegraph" if anchor_state == AnchorState.TELEGRAPH else "wait_for_open_ring"]


func _use_reflection(action: StringName, value: Variant) -> Array:
	if action in [&"primary", &"replay"]:
		_save_and_feedback("CHOOSE • PRIVATE • SKIP", "◇")
		return [true, "choices_open"]
	if action in [&"private", &"skip"]:
		_save_and_feedback("NO ANSWER SAVED • QUEST CONTINUES", "✓")
		return [true, "skipped"]
	if action not in [&"answer_a", &"answer_b"]:
		return [false, "choose_or_skip"]
	var tracker := get_node_or_null("/root/PlayerIdentityTracker")
	var evidence_id := definition.identity_evidence_id
	if evidence_id.is_empty():
		evidence_id = save_id
	var choice := str(value) if value != null else ("outward" if action == &"answer_a" else "inward")
	if tracker == null:
		return [false, "identity_save_failed"]
	if tracker.has_method("has_evidence") and bool(tracker.call("has_evidence", evidence_id)):
		_save_and_feedback("FIRST ANSWER KEPT • REPLAY ONLY", "✓")
		return [true, "first_answer_kept"]
	if not bool(tracker.call("record_evidence", evidence_id, "energy", choice)):
		return [false, "identity_save_failed"]
	current_state["result"] = choice
	return [true, _complete({"identity_evidence": evidence_id, "choice": choice})]


func _use_checkpoint(action: StringName) -> Array:
	if action == &"primary":
		_save_and_feedback("SAVE • HEAL • CURRENT TASK", "☰")
		return [true, "menu_open"]
	if action not in [&"save", &"heal", &"task"]:
		return [false, "choose_menu_action"]
	current_state["last_action"] = str(action)
	if not _save_and_feedback(str(action).to_upper(), "✓"):
		return [false, "save_failed"]
	checkpoint_action_requested.emit(str(action))
	return [true, str(action)]


func _complete(result: Dictionary) -> String:
	current_state["completed"] = true
	current_state["progress"] = definition.validated_total()
	current_state["result"] = result
	# The disk write intentionally precedes every gate/reward completion signal.
	if persist_state and not state_store.save_object(save_id, current_state):
		current_state["completed"] = false
		return "save_failed"
	_save_and_feedback(definition.success_message, definition.icon_success, false)
	progress_changed.emit(save_id, definition.validated_total(), definition.validated_total())
	if not _completion_emitted:
		_completion_emitted = true
		completed.emit(save_id, result)
		if not definition.linked_task_id.is_empty():
			linked_task_opened.emit(save_id, definition.linked_task_id)
	return "completed"


func _save_and_feedback(message: String, feedback_icon: String, save := true) -> bool:
	if save and persist_state and not state_store.save_object(save_id, current_state):
		return false
	status.text = message
	icon.text = feedback_icon
	feedback_changed.emit(save_id, message, feedback_icon)
	var cue: StringName = &""
	if bool(get_meta("unfinished_light",false)) and save_id in UnfinishedLight.IDS:
		cue=ResearchSound.select(_sound_action,feedback_icon!="?",bool(current_state.get("completed",false)))
	_play_tone(cue)
	return true


func _apply_visual_state(animate: bool) -> void:
	if definition == null:
		return
	prompt.text = "%s\n%s" % [definition.action_prompt, _progress_text()]
	icon.text = definition.icon_success if bool(current_state.get("completed", false)) else definition.icon_waiting
	var material := core.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = definition.accent_color
		material.emission = definition.accent_color
		material.emission_energy_multiplier = 1.5 if bool(current_state.get("completed", false)) else 0.35
	core.scale = Vector3(1.3, 1.5, 1.3) if bool(current_state.get("completed", false)) else Vector3.ONE
	var path_beam := visual_root.get_node_or_null("PathBeam") as MeshInstance3D
	if path_beam != null:
		path_beam.visible = bool(current_state.get("completed", false)) or bool(current_state.get("guide_enabled", false))
	var door := visual_root.get_node_or_null("Door") as AnimatableBody3D
	if door != null:
		door.position.y = 2.4 if bool(current_state.get("completed", false)) else 0.8
	var tile_collision := visual_root.get_node_or_null("BridgeTile/CollisionShape3D") as CollisionShape3D
	if tile_collision != null:
		tile_collision.disabled = not bool(current_state.get("completed", false))
	var arrow := visual_root.get_node_or_null("HintArrow") as Label3D
	if arrow != null:
		arrow.visible = bool(current_state.get("hint_enabled", false))
	var dots := visual_root.get_node_or_null("RouteDots") as Node3D
	if dots != null:
		dots.visible = bool(current_state.get("guide_enabled", false))
	var completion_crystal := visual_root.get_node_or_null("CompletionCrystal") as MeshInstance3D
	if completion_crystal != null:
		completion_crystal.visible = bool(current_state.get("completed", false))
	var central_spark := visual_root.get_node_or_null("CentralSpark") as MeshInstance3D
	if central_spark != null:
		central_spark.visible = int(current_state.get("progress", 0)) > 0
		central_spark.scale = Vector3.ONE * (0.72 + float(current_state.get("progress", 0)) * 0.16)
	var storm_cloud := visual_root.get_node_or_null("StormCloud") as Node3D
	if storm_cloud != null:
		storm_cloud.visible = not bool(current_state.get("completed", false))
	var calm_heart := visual_root.get_node_or_null("CalmHeart") as Label3D
	if calm_heart != null:
		calm_heart.visible = bool(current_state.get("completed", false))
	for index in 3:
		var pip := visual_root.get_node_or_null("Pip%d" % (index + 1)) as MeshInstance3D
		if pip != null:
			pip.scale = Vector3.ONE * (1.35 if index < int(current_state.get("progress", 0)) else 0.62)
	for index in 2:
		var link := visual_root.get_node_or_null("MemoryLink%d" % (index + 1)) as MeshInstance3D
		if link != null:
			link.visible = int(current_state.get("progress", 0)) > index
	var lens_body := visual_root.get_node_or_null("LensBody") as StaticBody3D
	if lens_body != null:
		lens_body.rotation_degrees.y = float(maxi(0, int(current_state.get("angle_step", -1)))) * 45.0
	var rain := visual_root.get_node_or_null("GentleRain") as GPUParticles3D
	if rain != null:
		rain.emitting = bool(current_state.get("completed", false))
	var safe_arrow := visual_root.get_node_or_null("SafeArrow") as Label3D
	if safe_arrow != null:
		safe_arrow.visible = int(current_state.get("anchor_state", 0)) == AnchorState.VULNERABLE
	var scanner_prompt := visual_root.get_node_or_null("ScannerPromptState") as Label3D
	if scanner_prompt != null:
		scanner_prompt.visible = not bool(current_state.get("scanned", false)) and not bool(current_state.get("completed", false))
	var scanner_choice := visual_root.get_node_or_null("ScannerChoiceState") as Label3D
	if scanner_choice != null:
		scanner_choice.visible = bool(current_state.get("scanned", false)) and not bool(current_state.get("completed", false))
	var scanner_confirmed := visual_root.get_node_or_null("ScannerConfirmedState") as Label3D
	if scanner_confirmed != null:
		scanner_confirmed.visible = bool(current_state.get("completed", false))
	var gate_lock := visual_root.get_node_or_null("GateLockGlyph") as Label3D
	if gate_lock != null:
		gate_lock.visible = not bool(current_state.get("completed", false))
	var storm_lightning := visual_root.get_node_or_null("StormLightning") as Label3D
	if storm_lightning != null:
		storm_lightning.visible = not bool(current_state.get("completed", false))
	var reflection_resolved := visual_root.get_node_or_null("ReflectionResolved") as Label3D
	if reflection_resolved != null:
		reflection_resolved.visible = bool(current_state.get("completed", false))
	var warden_shield := visual_root.get_node_or_null("WardenShield") as MeshInstance3D
	if warden_shield != null:
		warden_shield.visible = int(current_state.get("anchor_state", 0)) != AnchorState.BROKEN
	var broken_core := visual_root.get_node_or_null("BrokenCore") as MeshInstance3D
	if broken_core != null:
		broken_core.visible = int(current_state.get("anchor_state", 0)) == AnchorState.BROKEN
	if animate and not bool(current_state.get("completed", false)):
		var tween := create_tween()
		tween.tween_property(core, "scale", Vector3.ONE * 1.12, 0.09)
		tween.tween_property(core, "scale", Vector3.ONE, 0.12)
	_apply_blender_visual_state()


func _progress_text() -> String:
	if save_id == "world_one.evidence_scanner":
		return "%d/3" % clampi(int(current_state.get("evidence_index", 0)), 0, 3)
	match definition.object_kind:
		Definition.ObjectKind.FOCUS_BELL_BEACON:
			return "HINT ON" if current_state.get("hint_enabled", false) else "OPTIONAL"
		Definition.ObjectKind.CLEAR_PATH_PROJECTOR:
			return "ROUTE ON" if current_state.get("guide_enabled", false) else "OPTIONAL"
		Definition.ObjectKind.CHECKPOINT_SERVER_ROOT:
			return "SAFE PAUSE"
		Definition.ObjectKind.IDENTITY_REFLECTION_MIRROR:
			return "PRIVATE • SKIP • REPLAY"
		_:
			return "%d/%d" % [int(current_state.get("progress", 0)), definition.validated_total()]


func _build_specialized_visuals() -> void:
	for child in visual_root.get_children():
		if child == core or child.name == "Pedestal":
			continue
		visual_root.remove_child(child)
		child.queue_free()
	core.visible = false
	var greybox_pedestal := visual_root.get_node_or_null("Pedestal") as MeshInstance3D
	if greybox_pedestal != null:
		greybox_pedestal.visible = false
	var kind := int(definition.object_kind)
	if kind < 0 or kind >= MODEL_SCENE_PATHS.size() or not ResourceLoader.exists(MODEL_SCENE_PATHS[kind]):
		push_error("Missing authored quest-object model for %s" % definition.display_name)
		return
	var packed := load(MODEL_SCENE_PATHS[kind]) as PackedScene
	var authored_model := packed.instantiate() as Node3D
	for child in authored_model.get_children():
		authored_model.remove_child(child)
		_clear_scene_owner_recursive(child)
		visual_root.add_child(child)
	authored_model.free()
	_apply_authored_surface_texture(kind)
	_hide_legacy_model_surfaces()
	_attach_blender_model(kind)
	if kind == Definition.ObjectKind.THOUGHT_SPARK_SOCKET:
		_apply_torch_spark_ball_textures()
	set_meta("authored_model_path", MODEL_SCENE_PATHS[kind])
	set_meta("runtime_procedural_visuals", false)


func _clear_scene_owner_recursive(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_scene_owner_recursive(child)


func _hide_legacy_model_surfaces() -> void:
	for geometry in visual_root.find_children("*", "GeometryInstance3D", true, false):
		(geometry as GeometryInstance3D).transparency = 1.0
	# This old single-loop halo remained legible in the Compatibility renderer
	# even with instance transparency. The detailed GLB supplies the replacement
	# segmented well, energy fins, staged beam and orbit system.
	var legacy_spark_halo := visual_root.get_node_or_null("SparkHalo") as MeshInstance3D
	if legacy_spark_halo != null:
		legacy_spark_halo.visible = false
	var legacy_object_glow := visual_root.get_node_or_null("ObjectGlow") as OmniLight3D
	if legacy_object_glow != null:
		legacy_object_glow.visible = false
	for particles in visual_root.find_children("*", "GPUParticles3D", true, false):
		(particles as GPUParticles3D).visible = false
	for label in visual_root.find_children("*", "Label3D", true, false):
		(label as Label3D).modulate.a = 0.0


func _attach_blender_model(kind: int) -> void:
	if kind < 0 or kind >= BLENDER_MODEL_PATHS.size():
		return
	var path := str(BLENDER_MODEL_PATHS[kind])
	var family := save_id.begins_with("world_one.") and kind != Definition.ObjectKind.MEMORY_CONSTELLATION
	if family:
		var slug := path.get_file().get_basename()
		path = "res://assets3D/mind_spark/quest_kit/memory_style_family/%s/export/%s.glb" % [slug, slug]
	if kind == Definition.ObjectKind.MEMORY_CONSTELLATION and save_id == "world_one.memory_board":
		path = "res://assets3D/mind_spark/quest_kit/memory_board/export/memory_board.glb"
	if not ResourceLoader.exists(path):
		push_error("Missing Blender quest-object model for %s: %s" % [definition.display_name, path])
		return
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Could not load Blender quest-object model for %s" % definition.display_name)
		return
	var imported := packed.instantiate() as Node3D
	imported.name = "BlenderModel"
	if kind == Definition.ObjectKind.THOUGHT_SPARK_SOCKET and not family:
		# Match the former two-metre gameplay prop while retaining source detail.
		imported.scale = Vector3.ONE * 0.30
	visual_root.add_child(imported)
	if family:
		imported.set_meta("memory_style_family", true)
		set_meta("preserve_authored_nodes", true)
		if kind not in [Definition.ObjectKind.LOGIC_GATE_ARCH, Definition.ObjectKind.TRUTH_BRIDGE_TILE, Definition.ObjectKind.CALM_RAIN_BASIN]:
			var caption := Label3D.new()
			caption.name = "ActionCaption"
			caption.text = ["PLACE SPARKS", "SCAN / COMPARE", "TURN / OBSERVE", "", "", "", "ASK FOR HELP", "DODGE / RESPOND", "", "REFLECT / SKIP", "SAVE / REST", "SHOW THE WAY"][kind]
			caption.position = Vector3(0, .63, .499)
			caption.font_size = 28
			caption.pixel_size = .0015
			caption.modulate = Color("245b61")
			caption.outline_size = 0
			imported.add_child(caption)
	if kind == Definition.ObjectKind.MEMORY_CONSTELLATION and save_id == "world_one.memory_board":
		imported.set_meta("memory_board_benchmark", true)
		set_meta("preserve_authored_nodes", true)
		for index in 3:
			var label := Label3D.new()
			label.name = "MemoryNodeCaption%d" % index
			label.text = str(definition.sequence_order[index]).to_upper() if index < definition.sequence_order.size() else str(index + 1)
			label.position = Vector3(-0.53 + index * 0.53, 0.94, 0.158)
			label.font_size = 32
			label.pixel_size = 0.0013
			label.modulate = Color("245b61")
			label.outline_size = 0
			imported.add_child(label)
	for child in imported.find_children("LOD1*", "Node3D", true, false):
		(child as Node3D).visible = false
	for child in imported.find_children("LOD2*", "Node3D", true, false):
		(child as Node3D).visible = false
	for collision_visual in imported.find_children("UCX_*", "MeshInstance3D", true, false):
		(collision_visual as MeshInstance3D).visible = false
	set_meta("blender_model_path", path)
	set_meta("blender_lod", "LOD0")
	set_meta("blender_rendering", true)


func _find_blender_part(part_name: String) -> Node3D:
	var blender_model := visual_root.get_node_or_null("BlenderModel")
	if blender_model == null:
		return null
	if blender_model.name == part_name:
		return blender_model as Node3D
	for descendant in blender_model.find_children(part_name, "Node3D", true, false):
		if descendant.name == part_name:
			return descendant as Node3D
	return null


func _blender_part_material(part_name: String) -> Material:
	var part := _find_blender_part(part_name)
	if part == null:
		return null
	var mesh_instance := part as MeshInstance3D
	if mesh_instance == null:
		for child in part.find_children("*", "MeshInstance3D", true, false):
			mesh_instance = child as MeshInstance3D
			break
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return null
	return mesh_instance.get_active_material(0)


func _apply_textured_ball(target: MeshInstance3D, source: Material, emission_energy: float) -> void:
	if target == null or source == null:
		return
	var textured := source.duplicate(true) as Material
	if textured is StandardMaterial3D:
		(textured as StandardMaterial3D).emission_energy_multiplier = emission_energy
	target.material_override = textured
	target.transparency = 0.0
	target.visible = true
	target.set_meta("torch_spark_textured_ball", true)


func _apply_torch_spark_ball_textures() -> void:
	# The original Godot socket includes gameplay spheres that remain responsible
	# for progress scaling. Give them the same PBR stacks as the Blender model so
	# the pink, white and blue balls no longer render as flat placeholder colors.
	var pink_material := _blender_part_material("Well_Luminous_Core")
	var white_material := _blender_part_material("Orb_Luminous_Core")
	var blue_material := _blender_part_material("Pylon_0_Crystal")
	_apply_textured_ball(visual_root.get_node_or_null("Core") as MeshInstance3D,
		blue_material, 0.18)
	_apply_textured_ball(visual_root.get_node_or_null("CentralSpark") as MeshInstance3D,
		pink_material, 0.48)
	_apply_textured_ball(visual_root.get_node_or_null("Pip1") as MeshInstance3D,
		pink_material, 0.42)
	_apply_textured_ball(visual_root.get_node_or_null("Pip2") as MeshInstance3D,
		white_material, 0.34)
	_apply_textured_ball(visual_root.get_node_or_null("Pip3") as MeshInstance3D,
		blue_material, 0.24)
	var decorative_materials: Array[Material] = [pink_material, white_material, blue_material, pink_material]
	for index in range(4):
		var decorative_ball := visual_root.get_node_or_null("_MeshInstance3D_%d" % (index + 10)) as MeshInstance3D
		_apply_textured_ball(decorative_ball, decorative_materials[index], 0.24)
	for index in range(0, 12, 2):
		var stud := visual_root.get_node_or_null("PedestalCircuitStud%02d" % index) as MeshInstance3D
		_apply_textured_ball(stud, white_material if index % 4 == 0 else blue_material, 0.18)
	for index in range(4):
		var pylon_ball := visual_root.get_node_or_null("SocketPylonCrystal%02d" % index) as MeshInstance3D
		_apply_textured_ball(pylon_ball, blue_material if index % 2 == 0 else pink_material, 0.20)


func _apply_blender_visual_state() -> void:
	if definition == null:
		return
	var imported := visual_root.get_node_or_null("BlenderModel")
	if imported != null and imported.get_meta("memory_style_family", false):
		_apply_memory_family_state(imported)
		return
	if imported != null and imported.get_meta("memory_board_benchmark", false):
		# Mobile/Compatibility can still render legacy instance transparency.
		# Retain behavior nodes, but explicitly hide their obsolete surfaces after
		# the shared visual updater has touched them on every state change.
		for geometry in visual_root.find_children("*", "GeometryInstance3D", true, false):
			if not imported.is_ancestor_of(geometry):
				geometry.visible = false
		var progress := clampi(int(current_state.get("progress", 0)), 0, 3)
		prompt.text = "MEMORY RESTORED • 3/3" if bool(current_state.get("completed", false)) else "CONNECT THE MEMORY • %d/3" % progress
		for index in 3:
			var cap := _find_blender_part("NodeCap%d" % index)
			if cap != null:
				if not cap.has_meta("rest_position"):
					cap.set_meta("rest_position", cap.position)
				cap.position = cap.get_meta("rest_position") + Vector3(0, 0, -0.018 if index < progress else 0.0)
				cap.set_meta("selected", index < progress)
		for index in 2:
			var link := _find_blender_part("Link%d" % index)
			if link != null:
				link.visible = progress >= index + 2
		var reward := _find_blender_part("RewardSeal")
		if reward != null:
			reward.visible = bool(current_state.get("completed", false))
		return
	var kind := int(definition.object_kind)
	if kind < 0 or kind >= BLENDER_STATE_PARTS.size():
		return
	var completed_now := bool(current_state.get("completed", false))
	var active_now := int(current_state.get("progress", 0)) > 0 \
		or bool(current_state.get("scanned", false)) \
		or bool(current_state.get("hint_enabled", false)) \
		or int(current_state.get("anchor_state", AnchorState.TELEGRAPH)) != AnchorState.TELEGRAPH
	var visible_phase := "completed" if completed_now else ("active" if active_now else "inactive")
	var groups: Dictionary = BLENDER_STATE_PARTS[kind]
	for phase in ["inactive", "active", "completed"]:
		for part_name in groups.get(phase, []):
			var part := _find_blender_part(str(part_name))
			if part != null:
				part.visible = phase == visible_phase
	if kind == Definition.ObjectKind.THOUGHT_SPARK_SOCKET:
		_apply_torch_spark_socket_stage()


func _apply_memory_family_state(imported: Node3D) -> void:
	# Retain authored collisions and scripts; hide only their replaced surfaces.
	for geometry in visual_root.find_children("*", "GeometryInstance3D", true, false):
		if not imported.is_ancestor_of(geometry):
			if geometry.name in ["PathBeam", "HintArrow", "SafeArrow", "GentleRain"] or geometry.get_parent().name == "RouteDots":
				geometry.transparency = 0.0
				if geometry is Label3D:
					geometry.modulate.a = 1.0
				if geometry is GPUParticles3D:
					geometry.visible = true
				continue
			geometry.visible = false
	# Labels must clear the new silhouette, rather than intersect the housing.
	var top := 1.92
	if definition.object_kind in [Definition.ObjectKind.PERSPECTIVE_LENS, Definition.ObjectKind.IDENTITY_REFLECTION_MIRROR]:
		top = 2.22
	if definition.object_kind == Definition.ObjectKind.LOGIC_GATE_ARCH:
		top = 3.83
	elif definition.object_kind in [Definition.ObjectKind.CALM_RAIN_BASIN, Definition.ObjectKind.TRUTH_BRIDGE_TILE]:
		top = .93
	prompt.text = definition.display_name.to_upper()
	prompt.position = Vector3(0, top + .18, .10)
	prompt.font_size = 24
	prompt.pixel_size = .0032
	status.position = Vector3(0, top, .10)
	status.font_size = 19
	status.pixel_size = .0028
	status.text = status.text.replace("_", " ").to_upper()
	var hint := visual_root.get_node_or_null("HintArrow") as Label3D
	if hint != null:
		hint.position = Vector3(0, top + .36, .10)
		hint.font_size = 19
		hint.pixel_size = .0028
	icon.visible = false # The three physical indicator windows carry this state.
	var done := bool(current_state.get("completed", false))
	var progress := int(current_state.get("progress", 0))
	if save_id == "world_one.evidence_scanner":
		progress = int(current_state.get("evidence_index", 0))
	var active := progress > 0 or bool(current_state.get("scanned", false))
	active = active or bool(current_state.get("guide_enabled", false)) or bool(current_state.get("hint_enabled", false))
	var stage := 3 if done else (clampi(progress, 1, 2) if active else 0)
	if definition.object_kind == Definition.ObjectKind.LOGIC_GATE_ARCH:
		stage = clampi(progress,0,2)
	var binary := definition.object_kind in [Definition.ObjectKind.TRUTH_BRIDGE_TILE, Definition.ObjectKind.FOCUS_BELL_BEACON, Definition.ObjectKind.WARDEN_ANCHOR, Definition.ObjectKind.CALM_RAIN_BASIN, Definition.ObjectKind.IDENTITY_REFLECTION_MIRROR, Definition.ObjectKind.CHECKPOINT_SERVER_ROOT, Definition.ObjectKind.CLEAR_PATH_PROJECTOR]
	if binary:
		stage = 1 if done or active or str(current_state.get("last_action", "")) != "" else 0
	for i in 3:
		var indicator := _find_blender_part("Status%d" % i)
		if indicator != null:
			indicator.visible = i < stage
		var charge := _find_blender_part("Charge%d" % i)
		if charge != null:
			charge.visible = i < progress
	var mechanism := _find_blender_part("Mechanism")
	if mechanism != null:
		if not mechanism.has_meta("rest_transform"):
			mechanism.set_meta("rest_transform", mechanism.transform)
		mechanism.transform = mechanism.get_meta("rest_transform")
		match definition.object_kind:
			Definition.ObjectKind.EVIDENCE_SCANNER:
				mechanism.position.y += .10 if bool(current_state.get("scanned", false)) else -.12
			Definition.ObjectKind.PERSPECTIVE_LENS:
				mechanism.rotation.y = float(maxi(0,int(current_state.get("angle_step",0)))) * PI / 4.0
			Definition.ObjectKind.LOGIC_GATE_ARCH:
				mechanism.position.y += 1.6 if done else 0.0
			Definition.ObjectKind.WARDEN_ANCHOR:
				mechanism.visible = int(current_state.get("anchor_state",0)) != AnchorState.BROKEN
			Definition.ObjectKind.CALM_RAIN_BASIN, Definition.ObjectKind.TRUTH_BRIDGE_TILE:
				mechanism.visible = done
			Definition.ObjectKind.FOCUS_BELL_BEACON:
				mechanism.position.x += .10 if bool(current_state.get("hint_enabled",false)) else 0.0
	var reward := _find_blender_part("Reward")
	if reward != null:
		reward.visible = done


func _apply_torch_spark_socket_stage() -> void:
	var blender_model := visual_root.get_node_or_null("BlenderModel") as Node3D
	if blender_model == null:
		return
	var stage := clampi(int(current_state.get("progress", 0)), 0, 3)
	# At 0/3 the socket should read as an engineered receptacle, not as an
	# already-powered magic ring. Keep the segmented well, inset cyan seams and
	# radial energy fins visible, but wake the continuous halo with the first
	# recovered Spark.
	var well_halo := _find_blender_part("Well_Violet_Halo")
	if well_halo != null:
		well_halo.visible = stage >= 1
	# glTF imports may keep the authored component name on a Node3D parent and
	# give its mesh child a generic Blender datablock name (for example Torus.8).
	# Stage the named parent hierarchy so every surface of that component follows
	# the same state.
	for descendant in blender_model.find_children("*", "Node3D", true, false):
		var part := descendant as Node3D
		var part_name := str(part.name)
		var beam_part := part_name.begins_with("Beam_")
		var orb_part := part_name.begins_with("Orb_Glass") \
			or part_name.begins_with("Orb_Luminous") \
			or part_name.begins_with("Orb_Equator") \
			or part_name.begins_with("Orb_Meridian") \
			or part_name.begins_with("Orb_Diagonal") \
			or part_name.begins_with("Orb_Outer")
		var crown_part := part_name.begins_with("Orb_Crown")
		var spark_part := part_name.begins_with("Spark_")
		if beam_part:
			part.visible = stage >= 1
		elif orb_part:
			part.visible = stage >= 2
		elif crown_part or spark_part:
			part.visible = stage >= 3


func _apply_authored_surface_texture(kind: int) -> void:
	if kind < 0 or kind >= AUTHORED_TEXTURE_PATHS.size():
		return
	var texture_path := str(AUTHORED_TEXTURE_PATHS[kind])
	var texture: Texture2D
	if OS.has_feature("editor"):
		# Direct source loading keeps focused tooling usable while the large Godot
		# import cache is absent. Exported builds use the normal imported resource.
		var image := Image.new()
		var image_error := image.load(ProjectSettings.globalize_path(texture_path))
		if image_error == OK and not image.is_empty():
			image.generate_mipmaps()
			texture = ImageTexture.create_from_image(image)
	else:
		texture = load(texture_path) as Texture2D
	if texture == null:
		push_error("Missing authored surface texture for %s: %s" % [definition.display_name, texture_path])
		return
	var target_path := str(AUTHORED_TEXTURE_TARGETS[kind])
	var target := visual_root.get_node_or_null(target_path)
	if target == null:
		push_error("Missing authored texture target for %s: %s" % [definition.display_name, target_path])
		return
	var meshes: Array[MeshInstance3D] = []
	if target is MeshInstance3D:
		meshes.append(target as MeshInstance3D)
	for child in target.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child as MeshInstance3D)
	for mesh_instance in meshes:
		var material := mesh_instance.material_override as StandardMaterial3D
		if material == null:
			material = StandardMaterial3D.new()
		else:
			material = material.duplicate() as StandardMaterial3D
		material.albedo_texture = texture
		material.albedo_color = Color.WHITE
		material.metallic = 0.28
		material.roughness = 0.54
		material.emission_enabled = false
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mesh_instance.material_override = material
	set_meta("authored_texture_path", texture_path)
	set_meta("authored_texture_target", target_path)


# Editor-only source kept so the checked-in model scenes can be regenerated.
# Runtime instances always use MODEL_SCENE_PATHS above.
func _build_bake_source_visuals() -> void:
	for child in visual_root.get_children():
		if child != core and child.name != "Pedestal":
			child.queue_free()
	# Each approved tool owns a distinct silhouette; the old shared sphere was
	# useful for greyboxing but made every production object read the same.
	core.visible = false
	_build_production_pedestal()
	match definition.object_kind:
		Definition.ObjectKind.THOUGHT_SPARK_SOCKET:
			var bowl := _cylinder_mesh(0.54, 0.24); bowl.name = "SparkReceiverBowl"; bowl.position.y = 0.36; visual_root.add_child(bowl)
			var crown := _mesh(TorusMesh.new(), 0.48); crown.name = "SocketCrown"; crown.position.y = 0.52; visual_root.add_child(crown)
			var central_spark := _crystal_mesh(0.20, Color("b36dff")); central_spark.name = "CentralSpark"; central_spark.position.y = 0.98; central_spark.visible = false; visual_root.add_child(central_spark)
			var beam := _cylinder_mesh(0.035, 0.72); beam.name = "SparkBeam"; beam.position.y = 0.68; visual_root.add_child(beam)
			for crystal_index in 4:
				var angle := TAU * float(crystal_index) / 4.0
				var crystal := _crystal_mesh(0.09, Color("8f7cff")); crystal.position = Vector3(cos(angle) * 0.68, 0.50, sin(angle) * 0.68); visual_root.add_child(crystal)
			for index in 3:
				var pip := _mesh(SphereMesh.new(), 0.12)
				pip.name = "Pip%d" % (index + 1)
				pip.position = Vector3(-0.36 + index * 0.36, 0.58, 0.0)
				visual_root.add_child(pip)
		Definition.ObjectKind.EVIDENCE_SCANNER:
			_add_terminal_frame(visual_root, "ScannerFrame", 1.55, 1.38)
			var screen := _mesh(BoxMesh.new(), 0.55); screen.name = "ScannerGlass"; (screen.mesh as BoxMesh).size = Vector3(1.25, 0.72, 0.08); screen.position = Vector3(0, 0.78, -0.16); visual_root.add_child(screen)
			var top_crystal := _crystal_mesh(0.14, Color("a86cff")); top_crystal.name = "ScannerCrystal"; top_crystal.position.y = 1.55; visual_root.add_child(top_crystal)
			_add_button("FactButton", Vector3(-0.48, 0.22, 0.0), "✓ FACT")
			_add_button("FearButton", Vector3(0.48, 0.22, 0.0), "☁ FEAR")
		Definition.ObjectKind.PERSPECTIVE_LENS:
			var body := StaticBody3D.new(); body.name = "LensBody"; visual_root.add_child(body)
			for index in 3:
				var ring := _mesh(TorusMesh.new(), 0.22 + index * 0.08)
				ring.position.y = 0.82; ring.rotation.x = PI * 0.5; body.add_child(ring)
			var lens_disc := _crystal_mesh(0.42, Color("626eff")); lens_disc.name = "LensCrystal"; lens_disc.position.y = 0.82; lens_disc.scale.z = 0.18; body.add_child(lens_disc)
			for side in [-1.0, 1.0]:
				var support := _stone_mesh(BoxMesh.new(), 0.18); (support.mesh as BoxMesh).size = Vector3(0.18, 0.72, 0.24); support.position = Vector3(float(side) * 0.54, 0.48, 0); body.add_child(support)
			var lens_top := _crystal_mesh(0.10, Color("a875ff")); lens_top.position.y = 1.45; body.add_child(lens_top)
			_add_path_beam()
		Definition.ObjectKind.MEMORY_CONSTELLATION:
			_add_terminal_frame(visual_root, "ConstellationFrame", 1.8, 1.55)
			var board_back := _dark_mesh(BoxMesh.new(), 0.8); board_back.name = "ConstellationSlate"; (board_back.mesh as BoxMesh).size = Vector3(1.55, 1.18, 0.10); board_back.position = Vector3(0, 0.72, -0.10); visual_root.add_child(board_back)
			var board_crystal := _crystal_mesh(0.13, Color("a86cff")); board_crystal.position.y = 1.72; visual_root.add_child(board_crystal)
			for index in 3:
				var socket := Area3D.new(); socket.name = "Socket%d" % (index + 1); socket.position = Vector3(-0.52 + index * 0.52, 0.65 + abs(index - 1) * 0.28, 0.0); visual_root.add_child(socket)
				socket.add_child(_mesh(SphereMesh.new(), 0.13))
			for index in 2:
				var link := _mesh(BoxMesh.new(), 0.08); link.name = "MemoryLink%d" % (index + 1); (link.mesh as BoxMesh).size = Vector3(0.58, 0.045, 0.045); link.position = Vector3(-0.275 + index * 0.55, 0.54, 0.0); link.rotation.z = (-0.42 if index == 0 else 0.42); link.visible = false; visual_root.add_child(link)
		Definition.ObjectKind.LOGIC_GATE_ARCH:
			for side in [-1.0, 1.0]:
				var pillar := _stone_mesh(BoxMesh.new(), 0.18); pillar.name = "LogicPillar"; (pillar.mesh as BoxMesh).size = Vector3(0.32, 1.45, 0.34); pillar.position = Vector3(float(side) * 0.78, 0.67, 0); visual_root.add_child(pillar)
				var cap := _crystal_mesh(0.13, Color("53dfff")); cap.position = Vector3(float(side) * 0.78, 1.48, 0); visual_root.add_child(cap)
			var lintel := _stone_mesh(BoxMesh.new(), 0.18); lintel.name = "LogicLintel"; (lintel.mesh as BoxMesh).size = Vector3(1.85, 0.26, 0.34); lintel.position = Vector3(0, 1.35, 0); visual_root.add_child(lintel)
			var crown_crystal := _crystal_mesh(0.17, Color("62e6ff")); crown_crystal.name = "GateCrownCrystal"; crown_crystal.position.y = 1.62; visual_root.add_child(crown_crystal)
			for index in 2:
				var socket := Area3D.new(); socket.name = "EvidenceSocket%d" % (index + 1); socket.position = Vector3(-0.42 + index * 0.84, 0.3, 0.0); visual_root.add_child(socket)
				socket.add_child(_mesh(SphereMesh.new(), 0.14))
			var door := AnimatableBody3D.new(); door.name = "Door"; door.sync_to_physics = false; door.position.y = 0.8; visual_root.add_child(door); door.add_child(_mesh(BoxMesh.new(), 0.6))
			_add_path_beam()
		Definition.ObjectKind.TRUTH_BRIDGE_TILE:
			var tile := StaticBody3D.new(); tile.name = "BridgeTile"; tile.position = Vector3(0.0, 0.15, -0.8); visual_root.add_child(tile)
			var collision := CollisionShape3D.new(); collision.name = "CollisionShape3D"; collision.shape = BoxShape3D.new(); (collision.shape as BoxShape3D).size = Vector3(1.5, 0.18, 1.2); collision.disabled = true; tile.add_child(collision)
			var tile_mesh := _dark_mesh(BoxMesh.new(), 0.75); tile_mesh.name = "CircuitTile"; (tile_mesh.mesh as BoxMesh).size = Vector3(1.5, 0.18, 1.2); tile.add_child(tile_mesh)
			var tile_ring := _mesh(TorusMesh.new(), 0.32); tile_ring.name = "TileCircuitRing"; tile_ring.position = Vector3(0.0, 0.27, -0.8); visual_root.add_child(tile_ring)
			var completion_crystal := _crystal_mesh(0.22, Color("9b67ff")); completion_crystal.name = "CompletionCrystal"; completion_crystal.position.y = 0.45; completion_crystal.visible = false; visual_root.add_child(completion_crystal)
		Definition.ObjectKind.FOCUS_BELL_BEACON:
			_add_terminal_frame(visual_root, "BellShrine", 1.15, 1.42)
			var bell := _cylinder_mesh(0.32, 0.44); bell.name = "FocusBell"; bell.position.y = 0.72; bell.rotation.z = PI; visual_root.add_child(bell)
			var bell_ring := _mesh(TorusMesh.new(), 0.38); bell_ring.name = "BellRim"; bell_ring.position.y = 0.48; visual_root.add_child(bell_ring)
			var bell_crystal := _crystal_mesh(0.13, Color("6de8ff")); bell_crystal.position.y = 1.55; visual_root.add_child(bell_crystal)
			var arrow := Label3D.new(); arrow.name = "HintArrow"; arrow.text = "➜ CURRENT OBJECT"; arrow.font_size = 34; arrow.outline_size = 8; arrow.position = Vector3(0.0, 1.0, 0.0); arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED; arrow.visible = false; visual_root.add_child(arrow)
		Definition.ObjectKind.WARDEN_ANCHOR:
			var body := StaticBody3D.new(); body.name = "AnchorBody"; visual_root.add_child(body)
			for crystal_index in 7:
				var angle := TAU * float(crystal_index) / 7.0
				var shard := _crystal_mesh(0.16 if crystal_index % 2 == 0 else 0.12, Color("7546bd")); shard.position = Vector3(cos(angle) * 0.48, 0.42 + 0.10 * (crystal_index % 2), sin(angle) * 0.48); shard.rotation.z = -cos(angle) * 0.35; body.add_child(shard)
			var spine := _crystal_mesh(0.27, Color("9b54ef")); spine.name = "CrystalSpine"; spine.position.y = 0.72; body.add_child(spine)
			var hurtbox := Area3D.new(); hurtbox.name = "Hurtbox"; body.add_child(hurtbox)
			var ring := _mesh(TorusMesh.new(), 0.42); ring.position.y = 0.42; ring.rotation.x = PI * 0.5; hurtbox.add_child(ring)
			var safe := Label3D.new(); safe.name = "SafeArrow"; safe.text = "➜ SAFE SIDE"; safe.font_size = 34; safe.outline_size = 8; safe.position = Vector3(1.15, 0.72, 0.0); safe.billboard = BaseMaterial3D.BILLBOARD_ENABLED; safe.visible = false; visual_root.add_child(safe)
		Definition.ObjectKind.CALM_RAIN_BASIN:
			var basin := _cylinder_mesh(0.72, 0.22); basin.name = "RainBasin"; basin.position.y = 0.22; visual_root.add_child(basin)
			var basin_rim := _mesh(TorusMesh.new(), 0.68); basin_rim.name = "RainBasinRim"; basin_rim.position.y = 0.36; visual_root.add_child(basin_rim)
			for crystal_index in 6:
				var angle := TAU * float(crystal_index) / 6.0
				var basin_crystal := _crystal_mesh(0.10, Color("64dfff")); basin_crystal.position = Vector3(cos(angle) * 0.78, 0.42, sin(angle) * 0.78); visual_root.add_child(basin_crystal)
			var cloud := Node3D.new(); cloud.name = "StormCloud"; cloud.position.y = 1.42; visual_root.add_child(cloud)
			for cloud_index in 5:
				var cloud_piece := _dark_mesh(SphereMesh.new(), 0.20); cloud_piece.position = Vector3(-0.38 + cloud_index * 0.19, abs(cloud_index - 2) * -0.05, 0); cloud.add_child(cloud_piece)
			var heart := Label3D.new(); heart.name = "CalmHeart"; heart.text = "♡"; heart.font_size = 62; heart.outline_size = 10; heart.modulate = Color("8fffff"); heart.position.y = 1.52; heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED; heart.visible = false; visual_root.add_child(heart)
			var rain := GPUParticles3D.new(); rain.name = "GentleRain"; rain.amount = 36; rain.lifetime = 1.4; rain.emitting = false; rain.position.y = 1.6
			var rain_material := ParticleProcessMaterial.new(); rain_material.direction = Vector3(0.0, -1.0, 0.0); rain_material.initial_velocity_min = 1.2; rain_material.initial_velocity_max = 1.8; rain_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX; rain_material.emission_box_extents = Vector3(1.0, 0.2, 1.0); rain.process_material = rain_material
			var drop := QuadMesh.new(); drop.size = Vector2(0.025, 0.22); drop.orientation = PlaneMesh.FACE_Z; var drop_material := StandardMaterial3D.new(); drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; drop_material.albedo_color = Color(0.62, 0.84, 1.0, 0.72); drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; drop.material = drop_material; rain.draw_pass_1 = drop
			visual_root.add_child(rain)
		Definition.ObjectKind.IDENTITY_REFLECTION_MIRROR:
			var mirror := _crystal_mesh(0.62, Color("8edfff")); mirror.name = "ReflectionSurface"; mirror.position.y = 0.82; mirror.scale = Vector3(0.82, 1.25, 0.12); visual_root.add_child(mirror)
			var mirror_ring := _mesh(TorusMesh.new(), 0.66); mirror_ring.name = "MirrorFrame"; mirror_ring.position.y = 0.82; mirror_ring.rotation.x = PI * 0.5; visual_root.add_child(mirror_ring)
			for crystal_index in 10:
				var angle := TAU * float(crystal_index) / 10.0
				var frame_crystal := _crystal_mesh(0.075, Color("9b74ff")); frame_crystal.position = Vector3(cos(angle) * 0.72, 0.82 + sin(angle) * 0.72, 0); visual_root.add_child(frame_crystal)
		Definition.ObjectKind.CHECKPOINT_SERVER_ROOT:
			_add_terminal_frame(visual_root, "ServerConsole", 1.45, 1.18)
			var trunk := _cylinder_mesh(0.24, 1.15); trunk.name = "ServerRootTrunk"; trunk.position.y = 0.52; visual_root.add_child(trunk)
			var root_crystal := _crystal_mesh(0.14, Color("6fe3ff")); root_crystal.position.y = 1.42; visual_root.add_child(root_crystal)
			for branch_index in 4:
				var branch := _mesh(BoxMesh.new(), 0.16); branch.name = "LivingRootBranch"; (branch.mesh as BoxMesh).size = Vector3(0.16, 0.16, 1.15); branch.position = Vector3(0, 0.12, -0.42); branch.rotation.y = TAU * float(branch_index) / 4.0; visual_root.add_child(branch)
			for index in 3:
				_add_button("MenuButton%d" % index, Vector3(-0.62 + index * 0.62, 0.25, 0.0), ["SAVE", "HEAL", "TASK"][index])
		Definition.ObjectKind.CLEAR_PATH_PROJECTOR:
			var projector := _cylinder_mesh(0.46, 0.50); projector.name = "RouteProjector"; projector.position.y = 0.35; visual_root.add_child(projector)
			var projector_crystal := _crystal_mesh(0.13, Color("65dfff")); projector_crystal.position.y = 0.92; visual_root.add_child(projector_crystal)
			var dots := Node3D.new(); dots.name = "RouteDots"; dots.visible = false; visual_root.add_child(dots)
			for index in 8:
				var dot := _mesh(SphereMesh.new(), 0.06); dot.position = Vector3(sin(float(index) * 0.75) * 0.34, 0.08, -0.45 - index * 0.35); dots.add_child(dot)
			var goal := Marker3D.new(); goal.name = "Goal"; goal.position = Vector3(0.0, 0.0, -3.2); dots.add_child(goal)
			var star := Label3D.new(); star.text = "★"; star.font_size = 40; star.position = goal.position + Vector3(0.0, 0.3, 0.0); dots.add_child(star)
	_add_authored_detail_pass()


# Dense silhouette/detail layer for the shipped model scenes. These nodes are
# baked once into .tscn assets; they are never generated during gameplay.
func _add_authored_detail_pass() -> void:
	_add_segmented_pedestal_armor()
	match definition.object_kind:
		Definition.ObjectKind.THOUGHT_SPARK_SOCKET:
			for index in 4:
				var angle := TAU * float(index) / 4.0
				var pylon := _stone_mesh(BoxMesh.new(), 0.16); pylon.name = "SocketPylon%02d" % index; (pylon.mesh as BoxMesh).size = Vector3(0.20, 0.54, 0.20); pylon.position = Vector3(cos(angle) * 0.72, 0.38, sin(angle) * 0.72); pylon.rotation.y = -angle; visual_root.add_child(pylon)
				var tip := _crystal_mesh(0.10, Color("7eeaff")); tip.name = "SocketPylonCrystal%02d" % index; tip.position = pylon.position + Vector3(0, 0.35, 0); visual_root.add_child(tip)
			var halo := _mesh(TorusMesh.new(), 0.34); halo.name = "SparkHalo"; halo.position.y = 1.0; halo.rotation.x = PI * 0.5; visual_root.add_child(halo)
			_add_icon_disc("SocketStarSeal", "✦", Vector3(0, 0.34, 0.57), Color("bd76ff"), 30)
		Definition.ObjectKind.EVIDENCE_SCANNER:
			_add_screen_bezel(Vector3(0, 0.78, -0.08), Vector3(1.46, 0.94, 0.12))
			for side in [-1.0, 1.0]:
				var fin := _stone_mesh(BoxMesh.new(), 0.2); fin.name = "ScannerFin%s" % ("L" if side < 0 else "R"); (fin.mesh as BoxMesh).size = Vector3(0.22, 0.78, 0.38); fin.position = Vector3(side * 0.89, 0.58, 0.02); fin.rotation.z = side * -0.20; visual_root.add_child(fin)
			_add_state_label("ScannerPromptState", "⌕  SCAN", Vector3(0, 0.82, 0.02), Color("72eaff"), 28)
			_add_state_label("ScannerChoiceState", "FACT  ✦     ☁  FEAR", Vector3(0, 0.82, 0.03), Color("f4f8ff"), 22)
			_add_state_label("ScannerConfirmedState", "✓", Vector3(0, 0.82, 0.04), Color("84ffbb"), 48)
		Definition.ObjectKind.PERSPECTIVE_LENS:
			for index in 12:
				var angle := TAU * float(index) / 12.0
				var facet := _crystal_mesh(0.07, Color("7888ff")); facet.name = "LensFacet%02d" % index; facet.position = Vector3(cos(angle) * 0.49, 0.82 + sin(angle) * 0.49, 0); facet.rotation.z = -angle; visual_root.add_child(facet)
			for side in [-1.0, 1.0]:
				var dial := _cylinder_mesh(0.15, 0.12); dial.name = "LensDial%s" % ("L" if side < 0 else "R"); dial.position = Vector3(side * 0.62, 0.42, 0); dial.rotation.z = PI * 0.5; visual_root.add_child(dial)
			_add_icon_disc("LensAngleSeal", "III", Vector3(0, 0.26, 0.58), Color("9b78ff"), 20)
		Definition.ObjectKind.MEMORY_CONSTELLATION:
			for index in 4:
				var x := -0.54 + float(index) * 0.36
				var grid_v := _mesh(BoxMesh.new(), 0.04); grid_v.name = "BoardGridV%02d" % index; (grid_v.mesh as BoxMesh).size = Vector3(0.018, 1.04, 0.018); grid_v.position = Vector3(x, 0.76, 0.02); visual_root.add_child(grid_v)
			for index in 3:
				var y := 0.42 + float(index) * 0.34
				var grid_h := _mesh(BoxMesh.new(), 0.04); grid_h.name = "BoardGridH%02d" % index; (grid_h.mesh as BoxMesh).size = Vector3(1.38, 0.018, 0.018); grid_h.position = Vector3(0, y, 0.02); visual_root.add_child(grid_h)
			for index in 3:
				_add_state_label("ConstellationNumber%d" % (index + 1), str(index + 1), Vector3(-0.52 + index * 0.52, 0.79 + abs(index - 1) * 0.28, 0.10), Color.WHITE, 18)
		Definition.ObjectKind.LOGIC_GATE_ARCH:
			for side in [-1.0, 1.0]:
				for level in 3:
					var buttress := _stone_mesh(BoxMesh.new(), 0.18); buttress.name = "GateButtress%s%d" % [("L" if side < 0 else "R"), level]; (buttress.mesh as BoxMesh).size = Vector3(0.30, 0.32, 0.48); buttress.position = Vector3(side * (0.94 - level * 0.08), 0.25 + level * 0.34, 0); buttress.rotation.z = side * -0.10; visual_root.add_child(buttress)
				var socket_ring := _mesh(TorusMesh.new(), 0.20); socket_ring.name = "EvidenceRing%s" % ("L" if side < 0 else "R"); socket_ring.position = Vector3(side * 0.42, 1.30, 0.06); socket_ring.rotation.x = PI * 0.5; visual_root.add_child(socket_ring)
			_add_state_label("GateLockGlyph", "▣", Vector3(0, 0.80, 0.08), Color("ad72ff"), 46)
		Definition.ObjectKind.TRUTH_BRIDGE_TILE:
			for corner in 4:
				var sx := -1.0 if corner % 2 == 0 else 1.0
				var sz := -1.0 if corner < 2 else 1.0
				var plate := _stone_mesh(BoxMesh.new(), 0.16); plate.name = "TileCorner%02d" % corner; (plate.mesh as BoxMesh).size = Vector3(0.34, 0.14, 0.30); plate.position = Vector3(sx * 0.58, 0.32, -0.8 + sz * 0.43); visual_root.add_child(plate)
			for spoke in 4:
				var circuit := _mesh(BoxMesh.new(), 0.05); circuit.name = "TileCircuitSpoke%02d" % spoke; (circuit.mesh as BoxMesh).size = Vector3(0.035, 0.025, 0.46); circuit.position = Vector3(0, 0.38, -1.08); circuit.rotation.y = TAU * float(spoke) / 4.0; visual_root.add_child(circuit)
		Definition.ObjectKind.FOCUS_BELL_BEACON:
			for side in [-1.0, 1.0]:
				var foot := _stone_mesh(BoxMesh.new(), 0.18); foot.name = "BellFoot%s" % ("L" if side < 0 else "R"); (foot.mesh as BoxMesh).size = Vector3(0.34, 0.22, 0.46); foot.position = Vector3(side * 0.48, 0.24, 0); visual_root.add_child(foot)
				var wave := _mesh(TorusMesh.new(), 0.38); wave.name = "BellWave%s" % ("L" if side < 0 else "R"); wave.position = Vector3(side * 0.46, 0.76, 0); wave.rotation.x = PI * 0.5; wave.scale = Vector3(0.45, 1, 1); visual_root.add_child(wave)
			_add_icon_disc("BellDirectionSeal", "➜", Vector3(0, 0.26, 0.59), Color("ffc95c"), 28)
		Definition.ObjectKind.WARDEN_ANCHOR:
			for index in 9:
				var angle := TAU * float(index) / 9.0
				var size := 0.13 + 0.045 * float(index % 3)
				var shard := _crystal_mesh(size, Color("60389d")); shard.name = "WardenOuterShard%02d" % index; shard.position = Vector3(cos(angle) * 0.68, 0.32 + float(index % 3) * 0.14, sin(angle) * 0.68); shard.rotation.z = -cos(angle) * 0.55; visual_root.add_child(shard)
			var shield := _dark_mesh(SphereMesh.new(), 0.31); shield.name = "WardenShield"; shield.position.y = 0.46; shield.scale.z = 0.18; visual_root.add_child(shield)
			var broken := _crystal_mesh(0.16, Color("8b94a9")); broken.name = "BrokenCore"; broken.position.y = 0.36; broken.visible = false; visual_root.add_child(broken)
		Definition.ObjectKind.CALM_RAIN_BASIN:
			var water := _mesh(CylinderMesh.new(), 0.59); water.name = "BasinWater"; (water.mesh as CylinderMesh).height = 0.035; water.position.y = 0.39; visual_root.add_child(water)
			for index in 6:
				var angle := TAU * float(index) / 6.0
				var shrine := _stone_mesh(BoxMesh.new(), 0.13); shrine.name = "BasinShrine%02d" % index; (shrine.mesh as BoxMesh).size = Vector3(0.20, 0.34, 0.20); shrine.position = Vector3(cos(angle) * 0.85, 0.30, sin(angle) * 0.85); visual_root.add_child(shrine)
			_add_state_label("StormLightning", "ϟ ϟ", Vector3(0, 1.15, 0.04), Color("bd77ff"), 34)
		Definition.ObjectKind.IDENTITY_REFLECTION_MIRROR:
			var inner_frame := _mesh(TorusMesh.new(), 0.54); inner_frame.name = "MirrorInnerFrame"; inner_frame.position.y = 0.82; inner_frame.rotation.x = PI * 0.5; inner_frame.scale = Vector3(0.78, 1.18, 1); visual_root.add_child(inner_frame)
			var outer_frame := visual_root.get_node_or_null("MirrorFrame") as MeshInstance3D
			if outer_frame != null: outer_frame.scale = Vector3(0.82, 1.18, 1)
			for side in [-1.0, 1.0]:
				var foot := _stone_mesh(BoxMesh.new(), 0.16); foot.name = "MirrorFoot%s" % ("L" if side < 0 else "R"); (foot.mesh as BoxMesh).size = Vector3(0.34, 0.34, 0.48); foot.position = Vector3(side * 0.45, 0.26, 0); visual_root.add_child(foot)
			_add_state_label("ReflectionResolved", "✦", Vector3(0, 0.82, 0.08), Color("96ffff"), 48)
		Definition.ObjectKind.CHECKPOINT_SERVER_ROOT:
			for index in 7:
				var angle := TAU * float(index) / 7.0
				var canopy := _crystal_mesh(0.13, Color("7650a8")); canopy.name = "RootCanopy%02d" % index; canopy.position = Vector3(cos(angle) * 0.44, 1.24 + sin(angle) * 0.18, sin(angle) * 0.24); canopy.rotation.z = -cos(angle) * 0.35; visual_root.add_child(canopy)
			_add_state_label("ServerSaveState", "▣", Vector3(-0.52, 0.56, 0.08), Color("73dfff"), 26)
			_add_state_label("ServerHealState", "♥", Vector3(0, 0.56, 0.08), Color("7dffbc"), 26)
			_add_state_label("ServerTaskState", "≡", Vector3(0.52, 0.56, 0.08), Color("c397ff"), 26)
		Definition.ObjectKind.CLEAR_PATH_PROJECTOR:
			for index in 3:
				var ring := _mesh(TorusMesh.new(), 0.24 + index * 0.10); ring.name = "ProjectorHalo%02d" % index; ring.position.y = 0.66 + index * 0.10; ring.rotation.x = PI * 0.5; visual_root.add_child(ring)
			for side in [-1.0, 1.0]:
				var wing := _stone_mesh(BoxMesh.new(), 0.15); wing.name = "ProjectorWing%s" % ("L" if side < 0 else "R"); (wing.mesh as BoxMesh).size = Vector3(0.32, 0.22, 0.52); wing.position = Vector3(side * 0.48, 0.28, 0); wing.rotation.z = side * -0.14; visual_root.add_child(wing)


func _add_segmented_pedestal_armor() -> void:
	for index in 12:
		var angle := TAU * float(index) / 12.0
		var block := _stone_mesh(BoxMesh.new(), 0.14)
		block.name = "PedestalArmor%02d" % index
		(block.mesh as BoxMesh).size = Vector3(0.30, 0.16, 0.24)
		block.position = Vector3(cos(angle) * 0.79, 0.02, sin(angle) * 0.79)
		block.rotation.y = -angle
		visual_root.add_child(block)
		if index % 2 == 0:
			var stud := _crystal_mesh(0.045, definition.accent_color.lightened(0.18))
			stud.name = "PedestalCircuitStud%02d" % index
			stud.position = Vector3(cos(angle) * 0.88, 0.12, sin(angle) * 0.88)
			visual_root.add_child(stud)


func _add_screen_bezel(at: Vector3, size: Vector3) -> void:
	for side in [-1.0, 1.0]:
		var vertical := _stone_mesh(BoxMesh.new(), 0.1); vertical.name = "ScreenBezelV%s" % ("L" if side < 0 else "R"); (vertical.mesh as BoxMesh).size = Vector3(0.10, size.y, size.z); vertical.position = at + Vector3(side * size.x * 0.5, 0, 0.03); visual_root.add_child(vertical)
		var horizontal := _stone_mesh(BoxMesh.new(), 0.1); horizontal.name = "ScreenBezelH%s" % ("B" if side < 0 else "T"); (horizontal.mesh as BoxMesh).size = Vector3(size.x, 0.10, size.z); horizontal.position = at + Vector3(0, side * size.y * 0.5, 0.03); visual_root.add_child(horizontal)


func _add_state_label(node_name: String, text_value: String, at: Vector3, color: Color, text_size: int) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text_value
	label.font_size = text_size
	label.outline_size = maxi(4, int(text_size / 6))
	label.modulate = color
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	visual_root.add_child(label)
	return label


func _add_icon_disc(node_name: String, glyph: String, at: Vector3, color: Color, text_size: int) -> void:
	var disc := _cylinder_mesh(0.20, 0.06); disc.name = node_name; disc.position = at; disc.rotation.x = PI * 0.5; visual_root.add_child(disc)
	_add_state_label(node_name + "Glyph", glyph, at + Vector3(0, 0, 0.04), color, text_size)


func _build_production_pedestal() -> void:
	var lower_base := _stone_cylinder(0.86, 0.20)
	lower_base.name = "PedestalStoneBase"
	lower_base.position.y = -0.02
	visual_root.add_child(lower_base)
	var upper_base := _stone_cylinder(0.70, 0.16)
	upper_base.name = "PedestalStoneCrown"
	upper_base.position.y = 0.12
	visual_root.add_child(upper_base)
	var outer_ring := _mesh(TorusMesh.new(), 0.68)
	outer_ring.name = "PedestalEnergyRing"
	outer_ring.position.y = 0.05
	visual_root.add_child(outer_ring)
	var inner_ring := _mesh(TorusMesh.new(), 0.48)
	inner_ring.name = "PedestalInnerRing"
	inner_ring.position.y = 0.12
	visual_root.add_child(inner_ring)
	for index in 4:
		var strut := _mesh(BoxMesh.new(), 0.13)
		strut.name = "PedestalStrut"
		(strut.mesh as BoxMesh).size = Vector3(0.16, 0.12, 0.62)
		strut.position = Vector3(0, 0.08, -0.40)
		strut.rotation.y = TAU * float(index) / 4.0
		visual_root.add_child(strut)
	var glow := OmniLight3D.new()
	glow.name = "ObjectGlow"
	glow.position.y = 0.75
	glow.light_color = definition.accent_color
	glow.light_energy = 1.4
	glow.omni_range = 3.8
	glow.shadow_enabled = false
	visual_root.add_child(glow)


func _add_terminal_frame(parent: Node3D, node_name: String, width: float, height: float) -> void:
	var frame := Node3D.new()
	frame.name = node_name
	parent.add_child(frame)
	for side in [-1.0, 1.0]:
		var pillar := _stone_mesh(BoxMesh.new(), 0.18)
		(pillar.mesh as BoxMesh).size = Vector3(0.20, height, 0.22)
		pillar.position = Vector3(float(side) * width * 0.5, height * 0.5, 0.0)
		frame.add_child(pillar)
	var top := _stone_mesh(BoxMesh.new(), 0.18)
	(top.mesh as BoxMesh).size = Vector3(width + 0.20, 0.20, 0.22)
	top.position.y = height
	frame.add_child(top)


func _stone_cylinder(radius: float, height: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.94
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(Color("27334a"), Color("101827"), 0.22, 0.72)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _stone_mesh(mesh: PrimitiveMesh, size: float) -> MeshInstance3D:
	var instance := _mesh_with_material(mesh, size, _material(Color("34425a"), Color("101827"), 0.18, 0.68))
	return instance


func _dark_mesh(mesh: PrimitiveMesh, size: float) -> MeshInstance3D:
	return _mesh_with_material(mesh, size, _material(Color("111d34"), Color("09101f"), 0.08, 0.76))


func _crystal_mesh(size: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.5
	mesh.radial_segments = 6
	mesh.rings = 3
	return _mesh_with_material(mesh, size, _material(color, color, 1.35, 0.20))


func _material(albedo: Color, emission: Color, energy: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = 0.48
	material.roughness = roughness
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


func _mesh_with_material(mesh: PrimitiveMesh, size: float, material: Material) -> MeshInstance3D:
	if mesh is SphereMesh:
		(mesh as SphereMesh).radius = size
		(mesh as SphereMesh).height = size * 2.0
	elif mesh is TorusMesh:
		(mesh as TorusMesh).inner_radius = size
		(mesh as TorusMesh).outer_radius = size + 0.07
	elif mesh is BoxMesh:
		(mesh as BoxMesh).size = Vector3(size * 2.0, size, size * 2.0)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _cylinder_mesh(radius: float, height: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.82
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = definition.accent_color.darkened(0.22)
	material.metallic = 0.42
	material.roughness = 0.32
	material.emission_enabled = true
	material.emission = definition.accent_color
	material.emission_energy_multiplier = 0.38
	instance.material_override = material
	return instance


func _add_path_beam() -> void:
	var beam := _mesh(BoxMesh.new(), 0.34)
	beam.name = "PathBeam"
	(beam.mesh as BoxMesh).size = Vector3(0.18, 0.08, 3.2)
	beam.position = Vector3(0.0, 0.08, -1.7)
	beam.visible = false
	visual_root.add_child(beam)


func _add_button(node_name: String, at: Vector3, label_text: String) -> void:
	var button := Area3D.new(); button.name = node_name; button.position = at; visual_root.add_child(button)
	button.add_child(_mesh(BoxMesh.new(), 0.22))
	var label := Label3D.new(); label.text = label_text; label.font_size = 22; label.outline_size = 5; label.position.y = 0.3; button.add_child(label)


func _mesh(mesh: PrimitiveMesh, size: float) -> MeshInstance3D:
	return _mesh_with_material(mesh, size, _material(definition.accent_color,
		definition.accent_color, 0.62, 0.32))


func _play_tone(cue: StringName = &"") -> void:
	if cue!=&"":
		if not _sound_cache.has(cue): _sound_cache[cue]=ResearchSound.make(cue)
		feedback_sound.stop()
		feedback_sound.stream=_sound_cache[cue]
		set_meta("last_sound_cue",cue)
	elif feedback_sound.stream == null:
		feedback_sound.stream = _make_tone()
	feedback_sound.play()


func _exit_tree() -> void:
	# Stop scene-local playback before releasing its generated stream. Scene
	# changes can interrupt feedback, and re-entry can lazily create a fresh clip.
	if is_instance_valid(feedback_sound):
		feedback_sound.stop()
		feedback_sound.stream = null
	_sound_cache.clear()


func _make_tone() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 11025
	wav.stereo = false
	var frames := 1102
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for index in frames:
		var envelope := 1.0 - float(index) / frames
		var sample := int(sin(TAU * 660.0 * float(index) / wav.mix_rate) * 6800.0 * envelope)
		bytes[index * 2] = sample & 0xff
		bytes[index * 2 + 1] = (sample >> 8) & 0xff
	wav.data = bytes
	return wav


func _on_body_entered(_body: Node3D) -> void:
	prompt.visible = not bool(get_meta("physical_signage", false))
	interaction_requested.emit(self)


func _on_body_exited(_body: Node3D) -> void:
	prompt.visible = false


func _on_hint_timer_timeout() -> void:
	if definition != null and definition.object_kind == Definition.ObjectKind.FOCUS_BELL_BEACON \
			and interaction_enabled and not bool(current_state.get("completed", false)):
		hint_requested.emit(save_id)
		_save_and_feedback("HELP AVAILABLE • NEVER SOLVES", "?")


func _result(accepted: bool, reason: String) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"completed": bool(current_state.get("completed", false)),
		"progress": int(current_state.get("progress", 0)),
		"total": definition.validated_total() if definition != null else 1,
		"actions": available_actions() if definition != null else [],
	}
