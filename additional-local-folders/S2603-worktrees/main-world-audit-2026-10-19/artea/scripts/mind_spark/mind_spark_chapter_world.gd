class_name MindSparkChapterWorld
extends Control

const SceneLoader := preload("res://scripts/scene_loader.gd")

## Full five-quest Mind Spark chapter coordinator. Story and encounter data are
## curated, local resources; presentation nodes never award journey progress.

const EncounterDirector := preload("res://scripts/mind_spark/mind_spark_encounter_director.gd")
const ChapterCatalog := preload("res://scripts/mind_spark/mind_spark_chapter_catalog.gd")
const CheckpointStore := preload("res://scripts/mind_spark/mind_spark_checkpoint_store.gd")
const PerspectiveScript := preload("res://scripts/mind_spark/mind_spark_perspective.gd")
const CASTLE_SCENE := "res://scenes/art_gallery_3d_inprogress.tscn"
const VIEWPORT_CAP := Vector2i(640, 720)
const REQUIRED_ECHO_IDS: Array[String] = ["round.small_step", "round.safe_connection"]
const INPUT_BINDINGS := {
	"mind_alarm_move_left": KEY_A, "mind_alarm_move_right": KEY_D,
	"mind_alarm_move_forward": KEY_W, "mind_alarm_move_back": KEY_S,
	"mind_alarm_interact": KEY_E, "mind_alarm_ping": KEY_Q,
	"mind_hope_move_left": KEY_LEFT, "mind_hope_move_right": KEY_RIGHT,
	"mind_hope_move_forward": KEY_UP, "mind_hope_move_back": KEY_DOWN,
	"mind_hope_interact": KEY_ENTER, "mind_hope_ping": KEY_SHIFT,
}

@onready var alarm_viewport: SubViewport = $Layout/WorldArea/Split/AlarmViewportContainer/AlarmViewport
@onready var hope_viewport: SubViewport = $Layout/WorldArea/Split/HopeViewportContainer/HopeViewport
@onready var alarm_perspective = $Layout/WorldArea/Split/AlarmViewportContainer/AlarmViewport/MindSparkPerspective
@onready var hope_perspective = $Layout/WorldArea/Split/HopeViewportContainer/HopeViewport/MindSparkPerspective
@onready var quest_status: Label = $Layout/Header/Phase
@onready var guardian_name_label: Label = $Layout/ActionPanel/Box/GuardianName
@onready var guardian_dialogue: Label = $Layout/ActionPanel/Box/GuardianDialogue
@onready var purpose_label: Label = $Layout/ActionPanel/Box/Purpose
@onready var task_label: Label = $Layout/ActionPanel/Box/Prompt
@onready var instruction_label: Label = $Layout/ActionPanel/Box/Instruction
@onready var hint_label: Label = $Layout/ActionPanel/Box/Hint
@onready var continue_button: Button = $Layout/ActionPanel/Box/Utility/SoloMode
@onready var companion_button: Button = $Layout/ActionPanel/Box/Utility/CompanionPing
@onready var swap_button: Button = $Layout/ActionPanel/Box/Utility/SwapRoles
@onready var assist_button: Button = $Layout/ActionPanel/Box/Utility/CoopMode
@onready var receive_button: Button = $Layout/ActionPanel/Box/Consent/Receive
@onready var beside_button: Button = $Layout/ActionPanel/Box/Consent/Beside
@onready var watch_button: Button = $Layout/ActionPanel/Box/Consent/Watch
@onready var reduced_motion_button: CheckButton = $Layout/Header/ReducedMotion
@onready var local_coop_button: CheckButton = $Layout/Header/LocalCoop
@onready var skip_dialog: ConfirmationDialog = $SkipConfirmation

var director := EncounterDirector.new()
var story := ChapterCatalog.new()
var checkpoint_store := CheckpointStore.new()
var journey_state: Node
var campaign: Node
var audience_profile := ChapterCatalog.PROFILE_FAITH
var prologue_active := true
var completion_committed := false
var return_requested := false
var solo_mode := true
var _last_quest_index := -1
var _object_choice_bar: HBoxContainer


func inject_dependencies(new_journey_state: Node, new_campaign: Node, new_director = null,
		new_story = null, new_checkpoint_store = null) -> void:
	journey_state = new_journey_state
	campaign = new_campaign
	if new_director != null:
		director = new_director
	if new_story != null:
		story = new_story
	if new_checkpoint_store != null:
		checkpoint_store = new_checkpoint_store


func _ready() -> void:
	_ensure_input_actions()
	_ensure_object_choice_bar()
	_cap_viewports()
	get_viewport().size_changed.connect(_cap_viewports)
	if journey_state == null:
		journey_state = get_node_or_null("/root/JourneyState")
	if campaign == null:
		campaign = get_node_or_null("/root/JourneyCampaign")
	if journey_state != null and str(journey_state.get("audience_mode")) == "universal":
		audience_profile = ChapterCatalog.PROFILE_UNIVERSAL
	director.configure_solo(true, EncounterDirector.LENS_ALARM)
	if checkpoint_store.load_into(director):
		prologue_active = false
		solo_mode = director.solo_mode
	_configure_perspectives()
	director.phase_changed.connect(_on_phase_changed)
	director.roles_swapped.connect(_on_roles_swapped)
	continue_button.pressed.connect(_on_continue)
	companion_button.pressed.connect(_command_companion)
	swap_button.pressed.connect(_exchange_roles)
	assist_button.pressed.connect(_perform_accessibility_action)
	receive_button.pressed.connect(_complete_chapter.bind("receive"))
	beside_button.pressed.connect(_complete_chapter.bind("beside"))
	watch_button.pressed.connect(_complete_chapter.bind("watch"))
	reduced_motion_button.toggled.connect(_set_reduced_motion)
	local_coop_button.toggled.connect(_set_local_coop)
	$Layout/Header/Skip.pressed.connect(skip_dialog.popup_centered)
	skip_dialog.confirmed.connect(_confirm_skip)
	_render()


func set_solo_mode(enabled: bool, human_lens := EncounterDirector.LENS_ALARM) -> bool:
	var result: Dictionary = director.configure_solo(enabled, human_lens)
	if not bool(result.get("accepted", false)):
		return false
	solo_mode = enabled
	_apply_companion_state()
	_render()
	return true


func _configure_perspectives() -> void:
	alarm_perspective.configure_perspective(PerspectiveScript.PerspectiveKind.ALARM_SCIENCE,
		"alarm", "mind_alarm_keyboard")
	hope_perspective.configure_perspective(PerspectiveScript.PerspectiveKind.HOPE_NATURE_MAGIC,
		"hope", "mind_hope_keyboard")
	alarm_perspective.role_interaction_requested.connect(_on_role_interaction)
	hope_perspective.role_interaction_requested.connect(_on_role_interaction)
	alarm_perspective.role_ping_requested.connect(_on_role_ping)
	hope_perspective.role_ping_requested.connect(_on_role_ping)
	_apply_companion_state()


func _on_continue() -> void:
	if completion_committed:
		_return_to_castle()
		return
	if prologue_active:
		prologue_active = false
		director.start_current_encounter()
	elif director.phase == EncounterDirector.PHASE_BETWEEN:
		director.advance_to_next_encounter()
		director.start_current_encounter()
	checkpoint_store.save(director)
	_render()


func _on_role_interaction(role_id: String) -> void:
	if director.phase != EncounterDirector.PHASE_ACTIVE:
		return
	var perspective = alarm_perspective if role_id == EncounterDirector.LENS_ALARM else hope_perspective
	var support: Dictionary = perspective.interact_support_if_near()
	if bool(support.get("handled", false)):
		hint_label.text = "%s • %s" % [support.get("object_name", "Support tool"),
			str(support.get("reason", "ready")).replace("_", " ").to_upper()]
		return
	if not perspective.role_is_near_station():
		hint_label.text = "Move beside the required object, Focus Bell, or dotted-route Projector. No timing is required."
		return
	_perform_object_interaction(perspective, role_id)


func _perform_object_interaction(perspective, role_id: String,
		action: StringName = &"primary", value: Variant = null) -> bool:
	var result: Dictionary = perspective.interact_current_object(action, value)
	if not bool(result.get("accepted", false)):
		hint_label.text = str(result.get("reason", "try again")).replace("_", " ").capitalize()
		_render_object_choices(perspective, role_id)
		return false
	var reason := str(result.get("reason", "progress"))
	if bool(result.get("completed", false)) or reason in ["already_complete", "skipped"]:
		_clear_object_choices()
		return _perform_current_step(role_id)
	hint_label.text = "%s • %d/%d" % [reason.replace("_", " ").to_upper(),
		int(result.get("progress", 0)), int(result.get("total", 1))]
	_render_object_choices(perspective, role_id)
	return true


func _on_role_ping(_role_id: String) -> void:
	_command_companion()


func _perform_current_step(role_id: String, companion := false) -> bool:
	var step: Dictionary = director.current_step()
	if step.is_empty() or str(step.get("actor", "")) != role_id:
		hint_label.text = "This step belongs to the other Lens. Each view holds different information."
		return false
	var action_id := str(step.get("id", ""))
	var result: Dictionary
	if companion:
		result = director.ping_solo_companion(action_id)
	else:
		var actor_id := "solo_player" if solo_mode else (
			director.alarm_controller if role_id == EncounterDirector.LENS_ALARM else director.hope_controller)
		result = director.perform_action(action_id, actor_id)
	if not bool(result.get("accepted", false)):
		hint_label.text = "That handoff is not ready: %s." % str(result.get("reason", "try together")).replace("_", " ")
		return false
	_play_cross_seam_consequence()
	checkpoint_store.save(director)
	_render()
	return true


func _command_companion() -> void:
	if not solo_mode or director.phase != EncounterDirector.PHASE_ACTIVE:
		return
	var step: Dictionary = director.current_step()
	var lens := str(step.get("actor", ""))
	if lens not in [EncounterDirector.LENS_ALARM, EncounterDirector.LENS_HOPE]:
		return
	var companion_lens := EncounterDirector.LENS_HOPE if director.solo_human_lens == EncounterDirector.LENS_ALARM else EncounterDirector.LENS_ALARM
	if lens != companion_lens:
		hint_label.text = "The companion waits until the authored step belongs to its Lens."
		return
	var perspective = alarm_perspective if lens == EncounterDirector.LENS_ALARM else hope_perspective
	perspective.command_companion(perspective.interaction_station_position(), true)
	hint_label.text = "Companion moving visibly to the %s station…" % lens.capitalize()


func _perform_accessibility_action() -> void:
	if director.phase != EncounterDirector.PHASE_ACTIVE:
		return
	var step: Dictionary = director.current_step()
	var lens := str(step.get("actor", ""))
	if lens == "role_swap":
		_exchange_roles()
		return
	var human_lens := director.solo_human_lens if solo_mode else lens
	if solo_mode and lens != human_lens:
		_command_companion()
		return
	var perspective = alarm_perspective if lens == EncounterDirector.LENS_ALARM else hope_perspective
	perspective.role.position = perspective.interaction_station_position()
	_perform_object_interaction(perspective, lens)


func _exchange_roles() -> void:
	var result: Dictionary = director.exchange_roles()
	if bool(result.get("accepted", false)) and str(result.get("reason", "")) == "roles_swapped":
		alarm_perspective.swap_role_policy(hope_perspective)
		_apply_companion_state()
		checkpoint_store.save(director)
	_render()


func _complete_chapter(consent_choice: String) -> void:
	if completion_committed or director.phase != EncounterDirector.PHASE_COMPLETION_READY:
		return
	var result: Dictionary = director.request_completion()
	if not bool(result.get("accepted", false)) or journey_state == null:
		return
	var echoes := [
		{"id": REQUIRED_ECHO_IDS[0], "text": "I can pause, check, and take one supported step."},
		{"id": REQUIRED_ECHO_IDS[1], "text": "I can notice the alarm and look for a safe connection."},
	]
	for echo in echoes:
		journey_state.call("record_thought_echo", echo["text"], echo["id"])
		journey_state.call("mark_popped", echo["text"])
	if not bool(journey_state.call("complete_mind_spark", 2, REQUIRED_ECHO_IDS)):
		instruction_label.text = "The Star is waiting for complete journey evidence. Nothing was lost."
		return
	completion_committed = true
	checkpoint_store.clear()
	guardian_dialogue.text = _finale_dialogue()
	purpose_label.text = "STAR OF WISDOM • Consent choice: %s. Every choice receives the same treasure." % consent_choice
	task_label.text = "The Observatory joins living vines and constellation circuits into one light."
	instruction_label.text = "The Star now lights the first point of your Crown of Life journey."
	continue_button.text = "Return to ARTÉA Castle"
	_render()


func _render() -> void:
	var guardian := story.guardian_name(audience_profile)
	guardian_name_label.text = guardian
	local_coop_button.disabled = not prologue_active
	_hide_context_actions()
	if prologue_active:
		var prologue: Dictionary = story.data.get("prologue", {})
		quest_status.text = "CROWN OF LIFE • PROLOGUE"
		guardian_dialogue.text = story.localized_dialogue(prologue, audience_profile)
		purpose_label.text = str(prologue.get("purpose", ""))
		task_label.text = str(prologue.get("title", "The Crown of Life"))
		instruction_label.text = "The Castle is not broken, and neither are you. The first treasure is the Star of Wisdom."
		continue_button.visible = true
		continue_button.text = "Begin the First Journey"
		return
	var quest_index := mini(director.current_encounter_index, 4)
	var quest: Dictionary = story.quests()[quest_index]
	var encounter: Dictionary = director.current_encounter()
	quest_status.text = "QUEST %d / 5 • %s" % [quest_index + 1, str(encounter.get("title", quest.get("title", "")))]
	guardian_dialogue.text = story.localized_dialogue(quest, audience_profile)
	purpose_label.text = "PURPOSE • %s\nSTORY REASON • %s" % [quest.get("purpose", ""), quest.get("reason", "")]
	if quest_index != _last_quest_index:
		_last_quest_index = quest_index
		alarm_perspective.set_quest_environment(quest_index, str(encounter.get("title", "")))
		hope_perspective.set_quest_environment(quest_index, str(encounter.get("title", "")))
	if director.phase == EncounterDirector.PHASE_ACTIVE:
		_render_active_step(encounter)
	elif director.phase == EncounterDirector.PHASE_BETWEEN:
		task_label.text = "QUEST COMPLETE • A visible change now crosses the seam."
		instruction_label.text = "No thought was destroyed. Both Lenses contributed to the next Crown clue."
		hint_label.text = "Checkpoint reached. Continue when ready."
		continue_button.visible = true
		continue_button.text = "Travel to Quest %d" % (quest_index + 2)
	elif director.phase == EncounterDirector.PHASE_COMPLETION_READY:
		guardian_dialogue.text = _finale_dialogue()
		task_label.text = "THE WISDOM CONSTELLATION IS COMPLETE"
		instruction_label.text = "Choose how the Star is presented. All choices award the same treasure."
		receive_button.get_parent().visible = true
	elif director.phase == EncounterDirector.PHASE_COMPLETE and completion_committed:
		continue_button.visible = true
		continue_button.text = "Return to ARTÉA Castle"


func _render_active_step(encounter: Dictionary) -> void:
	var step: Dictionary = director.current_step()
	var lens := str(step.get("actor", ""))
	task_label.text = "TASK %d / %d • %s" % [director.current_step_index + 1,
		encounter.get("steps", []).size(), str(step.get("verb", "notice")).to_upper()]
	instruction_label.text = str(step.get("instruction", "Notice what changes across both worlds."))
	hint_label.text = _step_hint(lens)
	var positions := [Vector3(-2.6, 0.14, 1.4), Vector3(2.5, 0.14, 0.2), Vector3(0.0, 0.14, -1.55)]
	var target: Vector3 = positions[director.current_step_index % positions.size()]
	alarm_perspective.set_interaction_station(str(step.get("id", "")), "%s • E" % str(step.get("verb", "ACT")).to_upper(), target,
		lens == EncounterDirector.LENS_ALARM)
	hope_perspective.set_interaction_station(str(step.get("id", "")), "%s • ENTER" % str(step.get("verb", "ACT")).to_upper(), target,
		lens == EncounterDirector.LENS_HOPE)
	swap_button.visible = lens == "role_swap"
	assist_button.visible = lens in [EncounterDirector.LENS_ALARM, EncounterDirector.LENS_HOPE] or lens == "role_swap"
	if solo_mode and lens in [EncounterDirector.LENS_ALARM, EncounterDirector.LENS_HOPE]:
		var companion_lens := EncounterDirector.LENS_HOPE if director.solo_human_lens == EncounterDirector.LENS_ALARM else EncounterDirector.LENS_ALARM
		companion_button.visible = lens == companion_lens
	if lens in [EncounterDirector.LENS_ALARM, EncounterDirector.LENS_HOPE]:
		var perspective = alarm_perspective if lens == EncounterDirector.LENS_ALARM else hope_perspective
		_render_object_choices(perspective, lens)


func _step_hint(lens: String) -> String:
	if lens == "role_swap":
		return "Role exchange prevents either person from being labelled the negative or positive player."
	if lens == EncounterDirector.LENS_ALARM:
		return "Alarm sees signal information that Hope cannot see. Move to the cyan station and interact."
	return "Hope sees a grounded connection that Alarm cannot see. Move to the gold station and interact."


func _play_cross_seam_consequence() -> void:
	var progress := float(director.current_step_index) / maxf(1.0, director.current_encounter().get("steps", []).size())
	alarm_perspective.set_bridge_integrated(progress)
	hope_perspective.set_bridge_integrated(progress)
	alarm_perspective.set_shared_anchor_active(director.current_step_index > 0)
	hope_perspective.set_shared_anchor_active(director.current_step_index > 0)
	if director.current_encounter_index == 4:
		alarm_perspective.set_constellation_progress(director.current_step_index, 5)
		hope_perspective.set_constellation_progress(director.current_step_index, 5)


func _apply_companion_state() -> void:
	if not is_instance_valid(alarm_perspective) or not is_instance_valid(hope_perspective):
		return
	alarm_perspective.set_solo_companion(solo_mode and director.solo_human_lens != EncounterDirector.LENS_ALARM)
	hope_perspective.set_solo_companion(solo_mode and director.solo_human_lens != EncounterDirector.LENS_HOPE)


func _hide_context_actions() -> void:
	continue_button.visible = false
	companion_button.visible = false
	swap_button.visible = false
	assist_button.visible = false
	receive_button.get_parent().visible = false
	_clear_object_choices()


func _ensure_object_choice_bar() -> void:
	if is_instance_valid(_object_choice_bar):
		return
	_object_choice_bar = HBoxContainer.new()
	_object_choice_bar.name = "ObjectChoices"
	_object_choice_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_object_choice_bar.add_theme_constant_override("separation", 10)
	$Layout/ActionPanel/Box.add_child(_object_choice_bar)
	$Layout/ActionPanel/Box.move_child(_object_choice_bar, 5)


func _render_object_choices(perspective, role_id: String) -> void:
	_clear_object_choices()
	if not is_instance_valid(_object_choice_bar):
		return
	var actions: Array = perspective.current_object_actions()
	# Primary movement keys already cover simple repeated actions. Buttons are
	# reserved for a real choice, help, or reset.
	if actions == [&"primary"]:
		return
	for action in actions:
		if action in [&"scan", &"turn", &"dodge", &"strike"]:
			continue
		var button := Button.new()
		button.text = _object_action_label(action)
		button.pressed.connect(_on_object_choice.bind(perspective, role_id, action))
		_object_choice_bar.add_child(button)
	_object_choice_bar.visible = _object_choice_bar.get_child_count() > 0


func _clear_object_choices() -> void:
	if not is_instance_valid(_object_choice_bar):
		return
	for child in _object_choice_bar.get_children():
		_object_choice_bar.remove_child(child)
		child.free()
	_object_choice_bar.visible = false


func _on_object_choice(perspective, role_id: String, action: StringName) -> void:
	_perform_object_interaction(perspective, role_id, action)


func _object_action_label(action: StringName) -> String:
	var labels := {
		&"fact": "★ FACT", &"fear": "☁ FEAR", &"node": "CONNECT NEXT NODE",
		&"reset": "↺ RESET", &"help": "? HELP", &"answer_a": "ANSWER A",
		&"answer_b": "ANSWER B", &"private": "PRIVATE", &"skip": "SKIP",
		&"replay": "REPLAY", &"save": "SAVE", &"heal": "HEAL", &"task": "CURRENT TASK",
	}
	return str(labels.get(action, str(action).replace("_", " ").to_upper()))


func _set_reduced_motion(enabled: bool) -> void:
	alarm_perspective.set_reduced_motion(enabled)
	hope_perspective.set_reduced_motion(enabled)


func _set_local_coop(enabled: bool) -> void:
	if not prologue_active:
		local_coop_button.set_pressed_no_signal(not solo_mode)
		return
	set_solo_mode(not enabled, EncounterDirector.LENS_ALARM)


func _confirm_skip() -> void:
	director.skip_session()
	checkpoint_store.clear()
	_return_to_castle()


func _return_to_castle() -> void:
	if return_requested:
		return
	return_requested = true
	if campaign != null and campaign.has_method("return_to_campaign"):
		campaign.call("return_to_campaign", get_tree())
	elif SceneLoader.can_open(CASTLE_SCENE):
		SceneLoader.change_scene_with_loading(get_tree(), CASTLE_SCENE)


func _finale_dialogue() -> String:
	return story.localized_dialogue(story.data.get("finale", {}), audience_profile)


func _on_phase_changed(_phase: String) -> void:
	_render()


func _on_roles_swapped(_alarm_controller: String, _hope_controller: String) -> void:
	_apply_companion_state()


func _cap_viewports() -> void:
	var half := Vector2(get_viewport_rect().size.x * 0.5, get_viewport_rect().size.y)
	var shrink := maxi(1, ceili(maxf(half.x / VIEWPORT_CAP.x, half.y / VIEWPORT_CAP.y)))
	($Layout/WorldArea/Split/AlarmViewportContainer as SubViewportContainer).stretch_shrink = shrink
	($Layout/WorldArea/Split/HopeViewportContainer as SubViewportContainer).stretch_shrink = shrink


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
