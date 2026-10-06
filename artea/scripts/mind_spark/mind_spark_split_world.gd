class_name MindSparkSplitWorld
extends Control

## Coordinates two isolated Mind Spark perspectives around one deterministic,
## authored state machine. This layer owns presentation and persistence seams;
## the perspectives never mutate journey progress themselves.

const SharedStateScript := preload("res://scripts/mind_spark/mind_spark_shared_state.gd")
const PerspectiveScript := preload("res://scripts/mind_spark/mind_spark_perspective.gd")
const CASTLE_SCENE := "res://scenes/art_gallery_3d_inprogress.tscn"

const VIEWPORT_CAP := Vector2i(640, 720)
const INPUT_BINDINGS := {
	"mind_alarm_move_left": KEY_A,
	"mind_alarm_move_right": KEY_D,
	"mind_alarm_move_forward": KEY_W,
	"mind_alarm_move_back": KEY_S,
	"mind_alarm_interact": KEY_E,
	"mind_alarm_ping": KEY_Q,
	"mind_hope_move_left": KEY_LEFT,
	"mind_hope_move_right": KEY_RIGHT,
	"mind_hope_move_forward": KEY_UP,
	"mind_hope_move_back": KEY_DOWN,
	"mind_hope_interact": KEY_ENTER,
	"mind_hope_ping": KEY_SHIFT,
}

@onready var split_container: HSplitContainer = $Layout/WorldArea/Split
@onready var alarm_viewport: SubViewport = $Layout/WorldArea/Split/AlarmViewportContainer/AlarmViewport
@onready var hope_viewport: SubViewport = $Layout/WorldArea/Split/HopeViewportContainer/HopeViewport
@onready var seam_label: Label = $Layout/WorldArea/Seam/SeamBox/SeamLabel
@onready var phase_label: Label = $Layout/Header/Phase
@onready var prompt_label: Label = $Layout/ActionPanel/Box/Prompt
@onready var choices: HFlowContainer = $Layout/ActionPanel/Box/Choices
@onready var solo_button: Button = $Layout/ActionPanel/Box/Utility/SoloMode
@onready var coop_button: Button = $Layout/ActionPanel/Box/Utility/CoopMode
@onready var companion_button: Button = $Layout/ActionPanel/Box/Utility/CompanionPing
@onready var swap_button: Button = $Layout/ActionPanel/Box/Utility/SwapRoles
@onready var skip_button: Button = $Layout/Header/Skip

var shared_state: RefCounted
var journey_state: Node
var campaign: Node
var alarm_perspective: Node3D
var hope_perspective: Node3D

var solo_mode := true
var pending_companion_action := ""
var pending_companion_value := ""
var resolved_rounds: Array[Dictionary] = []
var completion_committed := false
var journey_evidence_recorded := false
var return_requested := false


func inject_dependencies(new_journey_state: Node, new_campaign: Node, new_shared_state: RefCounted = null) -> void:
	journey_state = new_journey_state
	campaign = new_campaign
	if new_shared_state != null:
		shared_state = new_shared_state


func _ready() -> void:
	_ensure_input_actions()
	_cap_viewports()
	get_viewport().size_changed.connect(_cap_viewports)
	if shared_state == null:
		shared_state = SharedStateScript.new()
	if journey_state == null:
		journey_state = get_node_or_null("/root/JourneyState")
	if campaign == null:
		campaign = get_node_or_null("/root/JourneyCampaign")
	_build_perspectives()
	_connect_state()
	skip_button.pressed.connect(skip_to_castle)
	solo_button.pressed.connect(set_solo_mode.bind(true, SharedStateScript.LENS_ALARM))
	coop_button.pressed.connect(set_solo_mode.bind(false, SharedStateScript.LENS_ALARM))
	companion_button.pressed.connect(companion_ping)
	swap_button.pressed.connect(swap_roles)
	shared_state.configure_solo(true, SharedStateScript.LENS_ALARM)
	_render_phase()


func _ensure_input_actions() -> void:
	for action_name: String in INPUT_BINDINGS:
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		var event := InputEventKey.new()
		event.physical_keycode = int(INPUT_BINDINGS[action_name])
		if action_name == "mind_hope_ping":
			event.location = KeyLocation.KEY_LOCATION_RIGHT
		InputMap.action_add_event(action_name, event)


func get_input_action_names() -> PackedStringArray:
	var names := PackedStringArray()
	for action_name: String in INPUT_BINDINGS:
		names.append(action_name)
	names.sort()
	return names


func set_solo_mode(enabled: bool, human_lens: String = SharedStateScript.LENS_ALARM) -> bool:
	var result: Dictionary = shared_state.configure_solo(enabled, human_lens)
	if not bool(result.get("accepted", false)):
		_show_reason(result)
		return false
	solo_mode = enabled
	_apply_companion_presentation()
	_render_phase()
	return true


func select_pair(pair_id: String) -> bool:
	return _accept_and_render(shared_state.choose_pair(pair_id))


func select_effect(effect_id: String) -> bool:
	return _perform_lens_action("scan_effect", effect_id, SharedStateScript.LENS_ALARM)


func select_response(response_id: String) -> bool:
	return _perform_lens_action("choose_response", response_id, SharedStateScript.LENS_HOPE)


func activate_anchor(anchor_id: String) -> bool:
	var anchor: Dictionary = _item_by_id(shared_state.current_round().get("anchors", []), anchor_id)
	if anchor.is_empty():
		return false
	return _perform_lens_action("activate_anchor", anchor_id, str(anchor.get("lens", "")))


func companion_ping() -> bool:
	if pending_companion_action.is_empty():
		prompt_label.text = "Finish your Lens action, then ping for the companion's authored step."
		return false
	var result: Dictionary = shared_state.ping_solo_companion(pending_companion_action, pending_companion_value)
	if bool(result.get("accepted", false)):
		pending_companion_action = ""
		pending_companion_value = ""
		_update_perspective_feedback()
	_render_phase()
	return bool(result.get("accepted", false))


func integrate_bridge() -> bool:
	var round_data: Dictionary = shared_state.current_round()
	var response: Dictionary = _item_by_id(round_data.get("hope_responses", []), shared_state.selected_response_id)
	var result: Dictionary = shared_state.integrate_bridge(str(round_data.get("bridge", {}).get("id", "")))
	if bool(result.get("accepted", false)) and str(result.get("reason", "")) != "already_complete":
		resolved_rounds.append({
			"id": str(round_data.get("id", "")),
			"helpful_text": str(response.get("label", "")),
		})
	_update_perspective_feedback()
	_render_phase()
	return bool(result.get("accepted", false))


func swap_roles() -> bool:
	var result: Dictionary = shared_state.swap_roles()
	if bool(result.get("accepted", false)) and str(result.get("reason", "")) == "roles_swapped":
		if _can_visual(alarm_perspective, "swap_role_policy") and _can_visual(hope_perspective, "swap_role_policy"):
			alarm_perspective.call("swap_role_policy", hope_perspective)
		_apply_companion_presentation()
	_render_phase()
	return bool(result.get("accepted", false))


func advance_round() -> bool:
	return _accept_and_render(shared_state.advance_to_next_round())


func activate_constellation_symbol(symbol_id: String) -> bool:
	var result: Dictionary = shared_state.activate_constellation_symbol(symbol_id)
	_update_perspective_feedback()
	_render_phase()
	return bool(result.get("accepted", false))


func complete_world() -> bool:
	if completion_committed:
		return true
	if resolved_rounds.size() != 2 or journey_state == null or not journey_state.has_method("record_thought_echo") \
			or not journey_state.has_method("mark_popped") or not journey_state.has_method("complete_mind_spark"):
		prompt_label.text = "The constellation needs two complete authored thought bridges."
		return false
	for round_result in resolved_rounds:
		var helpful_text := str(round_result.get("helpful_text", ""))
		var echo_id := str(round_result.get("id", ""))
		if helpful_text.is_empty() or echo_id.is_empty():
			return false
	var result: Dictionary = shared_state.request_completion()
	if not bool(result.get("accepted", false)) or shared_state.phase != SharedStateScript.PHASE_COMPLETE:
		_show_reason(result)
		return false
	if not journey_evidence_recorded:
		for round_result in resolved_rounds:
			var helpful_text := str(round_result.get("helpful_text", ""))
			var echo_id := str(round_result.get("id", ""))
			journey_state.call("record_thought_echo", helpful_text, echo_id)
			journey_state.call("mark_popped", helpful_text)
		journey_evidence_recorded = true
	var required_echo_ids: Array[String] = []
	for round_result in resolved_rounds:
		required_echo_ids.append(str(round_result.get("id", "")))
	if not bool(journey_state.call("complete_mind_spark", 2, required_echo_ids)):
		prompt_label.text = "Journey evidence was not accepted; no Star was awarded."
		return false
	completion_committed = true
	prompt_label.text = "STAR OF WISDOM • Fear was heard, checked, and joined with a grounded next step."
	_return_to_castle()
	return true


func skip_to_castle() -> void:
	if return_requested:
		return
	return_requested = true
	_return_to_castle()


func _perform_lens_action(action_id: String, value_id: String, lens: String) -> bool:
	if solo_mode and shared_state.solo_human_lens != lens:
		pending_companion_action = action_id
		pending_companion_value = value_id
		prompt_label.text = "COMPANION READY • Press Companion Ping to perform the visible %s step." % lens.capitalize()
		companion_button.disabled = false
		return false
	var actor: String = "solo_player" if solo_mode else (
		shared_state.alarm_controller if lens == SharedStateScript.LENS_ALARM else shared_state.hope_controller)
	var result: Dictionary
	match action_id:
		"scan_effect": result = shared_state.scan_effect(value_id, actor)
		"choose_response": result = shared_state.choose_response(value_id, actor)
		"activate_anchor": result = shared_state.activate_anchor(value_id, actor)
		_: return false
	_update_perspective_feedback()
	_render_phase()
	return bool(result.get("accepted", false))


func _accept_and_render(result: Dictionary) -> bool:
	if not bool(result.get("accepted", false)):
		_show_reason(result)
	_update_perspective_feedback()
	_render_phase()
	return bool(result.get("accepted", false))


func _build_perspectives() -> void:
	alarm_perspective = alarm_viewport.get_node_or_null("MindSparkPerspective")
	hope_perspective = hope_viewport.get_node_or_null("MindSparkPerspective")
	if alarm_perspective != null and alarm_perspective.has_method("configure_perspective"):
		alarm_perspective.call("configure_perspective", PerspectiveScript.PerspectiveKind.ALARM_SCIENCE,
			"alarm", "mind_alarm_keyboard")
	if hope_perspective != null and hope_perspective.has_method("configure_perspective"):
		hope_perspective.call("configure_perspective", PerspectiveScript.PerspectiveKind.HOPE_NATURE_MAGIC,
			"hope", "mind_hope_keyboard")
	if alarm_perspective != null and alarm_perspective.has_signal("role_interaction_requested"):
		alarm_perspective.role_interaction_requested.connect(_on_role_interaction)
	if hope_perspective != null and hope_perspective.has_signal("role_interaction_requested"):
		hope_perspective.role_interaction_requested.connect(_on_role_interaction)
	_apply_companion_presentation()


func _connect_state() -> void:
	if shared_state.has_signal("phase_changed"):
		shared_state.phase_changed.connect(_on_phase_changed)


func _cap_viewports() -> void:
	# With stretch enabled Godot owns SubViewport.size. A dynamic integer shrink
	# keeps that internal render target under the cap while each container still
	# fills its entire half of the screen.
	var display_size := get_viewport_rect().size
	var half_size := Vector2(display_size.x * 0.5, display_size.y)
	var shrink := maxi(1, ceili(maxf(half_size.x / VIEWPORT_CAP.x, half_size.y / VIEWPORT_CAP.y)))
	for container in [alarm_viewport.get_parent(), hope_viewport.get_parent()]:
		(container as SubViewportContainer).stretch_shrink = shrink


func _apply_companion_presentation() -> void:
	if not is_instance_valid(alarm_perspective) or not is_instance_valid(hope_perspective):
		return
	if _can_visual(alarm_perspective, "set_solo_companion"):
		alarm_perspective.call("set_solo_companion", solo_mode and shared_state.solo_human_lens != SharedStateScript.LENS_ALARM)
	if _can_visual(hope_perspective, "set_solo_companion"):
		hope_perspective.call("set_solo_companion", solo_mode and shared_state.solo_human_lens != SharedStateScript.LENS_HOPE)


func _update_perspective_feedback() -> void:
	var anchor_count: int = shared_state.activated_anchor_ids.size()
	for perspective in [alarm_perspective, hope_perspective]:
		if _can_visual(perspective, "set_shared_anchor_active"):
			perspective.call("set_shared_anchor_active", anchor_count > 0)
		if _can_visual(perspective, "set_bridge_integrated"):
			perspective.call("set_bridge_integrated", float(anchor_count) / 2.0)
		if _can_visual(perspective, "set_constellation_progress"):
			perspective.call("set_constellation_progress", shared_state.activated_symbol_ids.size(), 3)


func _render_phase() -> void:
	if not is_node_ready():
		return
	phase_label.text = "NOTICE → CHECK → CHOOSE → CONNECT    •    %s" % str(shared_state.phase).replace("_", " ").to_upper()
	seam_label.text = "TWO LENSES\nONE WHOLE THOUGHT\n\n%s" % _seam_progress()
	companion_button.visible = solo_mode
	companion_button.disabled = pending_companion_action.is_empty()
	var mode_locked: bool = shared_state.current_round_index != 0 or not shared_state.selected_pair_id.is_empty()
	solo_button.disabled = mode_locked or solo_mode
	coop_button.disabled = mode_locked or not solo_mode
	swap_button.visible = shared_state.phase == SharedStateScript.PHASE_BETWEEN_ROUNDS
	_clear_choices()
	var round_data: Dictionary = shared_state.current_round()
	match shared_state.phase:
		SharedStateScript.PHASE_CHOOSE_PAIR:
			prompt_label.text = "A difficult thought is visiting. It is not your identity."
			_add_choice(str(round_data.get("thought", "A thought is here")), select_pair.bind(str(round_data.get("id", ""))))
		SharedStateScript.PHASE_SCAN_EFFECT:
			prompt_label.text = "ALARM LENS • Notice what the authored thought could feel like. No answer is wrong."
			for choice in round_data.get("alarm_effects", []):
				_add_choice(str(choice.get("label", "Not sure")), select_effect.bind(str(choice.get("id", ""))))
		SharedStateScript.PHASE_CHOOSE_RESPONSE:
			prompt_label.text = "HOPE LENS • Choose a believable next step. Hope does not erase caution."
			for choice in round_data.get("hope_responses", []):
				_add_choice(str(choice.get("label", "I can pause")), select_response.bind(str(choice.get("id", ""))))
		SharedStateScript.PHASE_ACTIVATE_ANCHORS:
			prompt_label.text = "CROSS-SEAM ANCHORS • Technology reveals the signal; living magic carries it."
			for anchor in round_data.get("anchors", []):
				var done: bool = shared_state.activated_anchor_ids.has(str(anchor.get("id", "")))
				_add_choice(("✓ " if done else "") + str(anchor.get("label", "Anchor")),
					activate_anchor.bind(str(anchor.get("id", ""))), done)
		SharedStateScript.PHASE_INTEGRATE_BRIDGE:
			prompt_label.text = "Both truths are ready. Join them without destroying either side."
			_add_choice(str(round_data.get("bridge", {}).get("label", "Integrate Bridge")), integrate_bridge)
		SharedStateScript.PHASE_BETWEEN_ROUNDS:
			prompt_label.text = "ROLE SWAP REQUIRED • Understanding grows when both players carry both Lenses."
			_add_choice("Continue after role swap", advance_round, not shared_state.inter_round_role_swap_completed)
		SharedStateScript.PHASE_CONSTELLATION:
			prompt_label.text = "WISDOM CONSTELLATION • Connect every practice in any order."
			for symbol in shared_state.catalog.get("constellation", {}).get("symbols", []):
				var done: bool = shared_state.activated_symbol_ids.has(str(symbol.get("id", "")))
				_add_choice(("✦ " if done else "◇ ") + str(symbol.get("label", "Light")),
					activate_constellation_symbol.bind(str(symbol.get("id", ""))), done)
		SharedStateScript.PHASE_COMPLETION_READY:
			prompt_label.text = "The Star of Wisdom is ready. Difficult thoughts remain visible—and no longer steer alone."
			_add_choice("Receive the Star of Wisdom", complete_world)
		SharedStateScript.PHASE_COMPLETE:
			prompt_label.text = "STAR OF WISDOM • Returning to the ARTÉA Castle."


func _add_choice(label_text: String, callback: Callable, disabled := false) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(190.0, 46.0)
	button.disabled = disabled
	button.pressed.connect(callback)
	choices.add_child(button)


func _clear_choices() -> void:
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()


func _seam_progress() -> String:
	return "ROUND %d / 2\nBRIDGES %d / 2\nCONSTELLATION %d / 3" % [
		mini(shared_state.current_round_index + 1, 2),
		shared_state.completed_round_ids.size(),
		shared_state.activated_symbol_ids.size(),
	]


func _return_to_castle() -> void:
	if campaign != null and campaign.has_method("return_to_campaign"):
		campaign.call("return_to_campaign", get_tree())
	elif ResourceLoader.exists(CASTLE_SCENE):
		get_tree().change_scene_to_file(CASTLE_SCENE)


func _on_phase_changed(_phase_id: String) -> void:
	_render_phase()


func _on_role_interaction(role_id: String) -> void:
	if shared_state.phase != SharedStateScript.PHASE_ACTIVATE_ANCHORS:
		return
	for anchor in shared_state.current_round().get("anchors", []):
		if str(anchor.get("lens", "")) == role_id:
			activate_anchor(str(anchor.get("id", "")))
			return


func _show_reason(result: Dictionary) -> void:
	prompt_label.text = "That step is not ready yet • %s" % str(result.get("reason", "try again")).replace("_", " ")


func _item_by_id(items: Array, item_id: String) -> Dictionary:
	for item in items:
		if item is Dictionary and str(item.get("id", "")) == item_id:
			return item
	return {}


func _can_visual(node: Object, method_name: String) -> bool:
	return is_instance_valid(node) and node.has_method(method_name)
