class_name MiloGuide
extends CharacterBody3D

signal dialogue_started
signal dialogue_finished
signal guide_point_reached(point_id: StringName)
signal reminder_delivered(objective_id: StringName)
signal celebration_started(objective_id: StringName)
signal celebration_finished(objective_id: StringName)
signal mission_briefing_requested(mission_id: StringName)
signal mission_acceptance_requested(mission_id: StringName)
signal hint_requested(objective_id: StringName)

enum GuideState {
	IDLE,
	WALKING_TO_POINT,
	GREETING,
	TALKING,
	REMINDING,
	CELEBRATING,
	RETURNING_HOME,
}

const MISSION_ID := &"artea_journey"
const OBJECTIVE_IDS := [
	&"wake_the_first_light",
	&"mind_spark",
	&"heart_melody",
	&"creators_light",
	&"crown_complete",
]
const REMINDER_NODES := [
	&"milo_guide_stage_0",
	&"milo_guide_stage_1",
	&"milo_guide_stage_2",
	&"milo_guide_stage_3",
	&"milo_guide_stage_4",
]
const HINT_NODES := [
	&"milo_hint_stage_0",
	&"milo_hint_stage_1",
	&"milo_hint_stage_2",
	&"milo_hint_stage_3",
	&"milo_guide_stage_4",
]
const CELEBRATION_NODES := {
	&"star_of_wisdom": &"milo_celebrate_mind",
	&"harmony_jewel": &"milo_celebrate_heart",
	&"creators_light": &"milo_celebrate_creator",
	&"journey_complete": &"milo_celebrate_complete",
}
const ANIMATION_CLIPS := {
	&"Idle": &"Idle_3",
	&"Walk": &"Walking",
	&"Greeting": &"Wave_One_Hand",
	&"Talk": &"Idle_3",
	&"Point": &"Wave_One_Hand",
	&"ReadMap": &"Idle_3",
	&"Celebrate": &"Wave_One_Hand",
}

@export var player_path := NodePath("../NewPlayer")
@export var guide_points_path := NodePath("../MiloGuidePoints")
@export var home_point_path := NodePath("../MiloGuidePoints/HomePoint")
@export var guide_display_name := "Mayor Milo"
@export_range(1.0, 1.35, 0.05) var walk_speed := 1.2
@export_range(4.0, 6.0, 0.1) var rotation_speed := 5.0
@export_range(0.25, 0.4, 0.01) var stopping_distance := 0.35
@export_range(1.5, 4.0, 0.1) var player_greeting_distance := 2.5
@export_range(60.0, 90.0, 1.0) var reminder_delay := 75.0
@export var automatic_reminders_enabled := true
@export var gravity_enabled := true

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var dialogue_area: Area3D = $DialogueArea
@onready var interaction_prompt: Label3D = $InteractionPrompt
@onready var reminder_timer: Timer = $ReminderTimer
@onready var celebration_timer: Timer = $CelebrationTimer

var state := GuideState.IDLE
var player: CharacterBody3D
var animation_player: AnimationPlayer
var animation_playback: AnimationNodeStateMachinePlayback
var home_point: Marker3D
var current_guide_point: Marker3D
var _state_after_arrival := GuideState.IDLE
var _player_in_range := false
var _dialogue_open := false
var _journey_stage := 0
var _last_progress_stage := 0
var _pending_hint := false
var _pending_reminder := false
var _pending_celebration_id := StringName()
var _celebrated_objectives: Dictionary = {}
var journey_state_override: Node


func _ready() -> void:
	# Milo detects the player through DialogueArea but never physically blocks
	# them. His body mask remains world-only for safe ground movement.
	collision_layer = 0
	collision_mask = 1
	player = get_node_or_null(player_path) as CharacterBody3D
	if player == null:
		player = get_tree().get_first_node_in_group("Player") as CharacterBody3D
	home_point = get_node_or_null(home_point_path) as Marker3D
	animation_player = _find_animation_player(self)
	_configure_animation_tree()
	_connect_journey_state()
	_sync_journey_stage(false)
	reminder_timer.wait_time = reminder_delay
	reminder_timer.start()
	set_state(GuideState.IDLE)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _configure_animation_tree() -> void:
	if animation_player == null:
		animation_tree.active = false
		return
	var machine := AnimationNodeStateMachine.new()
	var index := 0
	for state_name: StringName in ANIMATION_CLIPS:
		var clip_name: StringName = ANIMATION_CLIPS[state_name]
		if not animation_player.has_animation(clip_name):
			clip_name = &"Idle_3" if animation_player.has_animation(&"Idle_3") else &"Idle"
		var animation_node := AnimationNodeAnimation.new()
		animation_node.animation = clip_name
		machine.add_node(state_name, animation_node, Vector2(index * 180.0, 0.0))
		index += 1
	for from_state: StringName in ANIMATION_CLIPS:
		for to_state: StringName in ANIMATION_CLIPS:
			if from_state == to_state:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = 0.2
			machine.add_transition(from_state, to_state, transition)
	animation_tree.tree_root = machine
	animation_tree.anim_player = animation_tree.get_path_to(animation_player)
	animation_tree.active = true
	animation_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback


func _connect_journey_state() -> void:
	var journey := _journey_state()
	if journey == null:
		return
	if journey.has_signal("stage_changed") and not journey.stage_changed.is_connected(_on_stage_changed):
		journey.stage_changed.connect(_on_stage_changed)
	if journey.has_signal("treasure_awarded") and not journey.treasure_awarded.is_connected(_on_treasure_awarded):
		journey.treasure_awarded.connect(_on_treasure_awarded)
	if journey.has_signal("journey_completed") and not journey.journey_completed.is_connected(_on_journey_completed):
		journey.journey_completed.connect(_on_journey_completed)


func _process(delta: float) -> void:
	_sync_journey_stage(false)
	if state in [GuideState.GREETING, GuideState.TALKING, GuideState.CELEBRATING] \
			and _player_in_range:
		face_player(delta)


func _physics_process(delta: float) -> void:
	if gravity_enabled and not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	if state in [GuideState.WALKING_TO_POINT, GuideState.RETURNING_HOME]:
		_move_to_guide_point(delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


func request_guide_point(point: Marker3D) -> void:
	if point == null or not point.is_inside_tree():
		return
	if point.has_method("is_available") and not bool(point.call("is_available", _journey_stage)):
		return
	current_guide_point = point
	navigation_agent.target_position = point.global_position
	set_state(GuideState.WALKING_TO_POINT)


func _move_to_guide_point(delta: float) -> void:
	if current_guide_point == null or not is_instance_valid(current_guide_point):
		_stop_safely()
		return
	var destination := current_guide_point.global_position
	var to_target := destination - global_position
	to_target.y = 0.0
	if to_target.length() <= stopping_distance:
		_arrive_at_guide_point()
		return
	if player != null and global_position.distance_to(player.global_position) < player_greeting_distance:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var next_position := destination
	var navigation_map := navigation_agent.get_navigation_map()
	if navigation_map.is_valid() and not navigation_agent.is_navigation_finished():
		var path_position := navigation_agent.get_next_path_position()
		var path_step := path_position - global_position
		path_step.y = 0.0
		# A navigation map may exist before its region has synchronized. Falling
		# back to the authored nearby point prevents Milo from freezing at home;
		# he still stops safely rather than crossing a distant invalid route.
		if path_step.length_squared() > 0.0001:
			next_position = path_position
	var direction := next_position - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		_stop_safely()
		return
	direction = direction.normalized()
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), rotation_speed * delta)


func _arrive_at_guide_point() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	var point_id := StringName(current_guide_point.get("guide_point_id")) \
			if current_guide_point != null and "guide_point_id" in current_guide_point \
			else StringName(current_guide_point.name if current_guide_point != null else "")
	guide_point_reached.emit(point_id)
	if _state_after_arrival == GuideState.CELEBRATING:
		_begin_celebration_state()
	else:
		set_state(GuideState.IDLE)
	_state_after_arrival = GuideState.IDLE


func _stop_safely() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	set_state(GuideState.IDLE)


func return_home() -> void:
	if home_point == null or not is_instance_valid(home_point):
		set_state(GuideState.IDLE)
		return
	current_guide_point = home_point
	navigation_agent.target_position = home_point.global_position
	set_state(GuideState.RETURNING_HOME)


func begin_mission_briefing(mission_id: StringName = MISSION_ID) -> void:
	mission_briefing_requested.emit(mission_id)
	var briefing_point := _guide_point(&"MissionBriefingPoint")
	if briefing_point != null:
		request_guide_point(briefing_point)


func give_current_reminder() -> void:
	var objective_id := current_objective_id()
	_pending_reminder = true
	reminder_delivered.emit(objective_id)
	if _player_in_range and not _player_busy():
		open_dialogue(current_reminder_node())
	else:
		interaction_prompt.text = "%s has a reminder — Press Q" % guide_display_name
		interaction_prompt.visible = true


func give_optional_hint() -> void:
	_pending_hint = true
	hint_requested.emit(current_objective_id())
	if _player_in_range and not _player_busy():
		open_dialogue(HINT_NODES[_journey_stage])


func celebrate_progress(objective_id: StringName) -> void:
	if objective_id.is_empty() or _celebrated_objectives.has(objective_id):
		return
	_celebrated_objectives[objective_id] = true
	_pending_celebration_id = objective_id
	var celebration_point := _guide_point(&"CelebrationPoint")
	if celebration_point != null:
		_state_after_arrival = GuideState.CELEBRATING
		request_guide_point(celebration_point)
	else:
		_begin_celebration_state()


func _begin_celebration_state() -> void:
	set_state(GuideState.CELEBRATING)
	celebration_started.emit(_pending_celebration_id)
	interaction_prompt.text = "%s wants to celebrate — Press Q" % guide_display_name
	interaction_prompt.visible = _player_in_range
	celebration_timer.start()


func face_player(delta: float) -> void:
	if player == null:
		return
	var direction := player.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), rotation_speed * delta)


func open_dialogue(dialogue_key: StringName) -> void:
	if _dialogue_open or dialogue_key.is_empty() or _player_busy():
		return
	_dialogue_open = true
	set_state(GuideState.TALKING)
	velocity.x = 0.0
	velocity.z = 0.0
	if player != null and "interacting" in player:
		player.set("interacting", true)
	dialogue_started.emit()
	var manager := get_node_or_null("/root/GameManager")
	if manager != null and manager.has_method("start_dialogue"):
		manager.call("start_dialogue", String(dialogue_key), self)
	else:
		end_dialogue()


func end_dialogue() -> void:
	if not _dialogue_open:
		return
	_dialogue_open = false
	if player != null and is_instance_valid(player) and "interacting" in player:
		player.set("interacting", false)
	dialogue_finished.emit()
	_pending_hint = false
	_pending_reminder = false
	reminder_timer.start(reminder_delay)
	if not _pending_celebration_id.is_empty():
		_finish_celebration()
	else:
		set_state(GuideState.IDLE)


func set_state(next_state: GuideState) -> void:
	state = next_state
	update_animation()


func update_animation() -> void:
	if animation_playback == null:
		return
	var animation_state := &"Idle"
	match state:
		GuideState.WALKING_TO_POINT, GuideState.RETURNING_HOME:
			animation_state = &"Walk"
		GuideState.GREETING:
			animation_state = &"Greeting"
		GuideState.TALKING, GuideState.REMINDING:
			animation_state = &"Talk"
		GuideState.CELEBRATING:
			animation_state = &"Celebrate"
	animation_playback.travel(animation_state)


func current_objective_id() -> StringName:
	return OBJECTIVE_IDS[_journey_stage]


func current_reminder_node() -> StringName:
	return REMINDER_NODES[_journey_stage]


func guide_state_name() -> String:
	return GuideState.keys()[state]


func has_celebrated(objective_id: StringName) -> bool:
	return _celebrated_objectives.has(objective_id)


func _dialogue_for_interaction() -> StringName:
	if not _pending_celebration_id.is_empty():
		return CELEBRATION_NODES.get(_pending_celebration_id, &"milo_celebrate_progress")
	if _pending_hint:
		return HINT_NODES[_journey_stage]
	return current_reminder_node()


func _player_busy() -> bool:
	if player == null:
		return false
	if "interacting" in player and bool(player.get("interacting")):
		return true
	for property_name in [&"is_attacking", &"is_blocking", &"in_cutscene", &"using_puzzle"]:
		if property_name in player and bool(player.get(property_name)):
			return true
	return false


func _guide_point(point_name: StringName) -> Marker3D:
	var container := get_node_or_null(guide_points_path)
	return container.get_node_or_null(NodePath(String(point_name))) as Marker3D if container != null else null


func _sync_journey_stage(allow_celebration: bool) -> void:
	var journey := _journey_state()
	var next_stage := clampi(int(journey.get("stage")), 0, 4) if journey != null else 0
	if next_stage == _journey_stage:
		return
	_last_progress_stage = _journey_stage
	_journey_stage = next_stage
	reminder_timer.start(reminder_delay)
	if allow_celebration and next_stage > _last_progress_stage:
		celebrate_progress(OBJECTIVE_IDS[next_stage])


func _journey_state() -> Node:
	if journey_state_override != null and is_instance_valid(journey_state_override):
		return journey_state_override
	return get_node_or_null("/root/JourneyState")


func _on_stage_changed(next_stage: int) -> void:
	var previous_stage := _journey_stage
	_journey_stage = clampi(next_stage, 0, 4)
	reminder_timer.start(reminder_delay)
	if _journey_stage > previous_stage:
		celebrate_progress(OBJECTIVE_IDS[_journey_stage])


func _on_treasure_awarded(treasure_id: String) -> void:
	celebrate_progress(StringName(treasure_id))


func _on_journey_completed() -> void:
	celebrate_progress(&"journey_complete")


func _on_dialogue_area_body_entered(body: Node3D) -> void:
	if body != player:
		return
	_player_in_range = true
	interaction_prompt.text = "Press Q to speak with Mayor Milo"
	interaction_prompt.visible = true
	if state == GuideState.IDLE:
		set_state(GuideState.GREETING)


func _on_dialogue_area_body_exited(body: Node3D) -> void:
	if body != player:
		return
	_player_in_range = false
	interaction_prompt.visible = false
	if state == GuideState.GREETING:
		set_state(GuideState.IDLE)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or _dialogue_open or _player_busy():
		return
	if event.is_action_pressed("interact"):
		open_dialogue(_dialogue_for_interaction())
		get_viewport().set_input_as_handled()


func _on_reminder_timer_timeout() -> void:
	if not automatic_reminders_enabled or _journey_stage >= 4 or _dialogue_open:
		return
	_pending_reminder = true
	interaction_prompt.text = "Mayor Milo has a reminder — Press Q"
	interaction_prompt.visible = _player_in_range
	reminder_delivered.emit(current_objective_id())


func _on_celebration_timer_timeout() -> void:
	if not _dialogue_open:
		_finish_celebration()


func _finish_celebration() -> void:
	var completed_id := _pending_celebration_id
	_pending_celebration_id = StringName()
	celebration_timer.stop()
	celebration_finished.emit(completed_id)
	return_home()


func _exit_tree() -> void:
	var manager := get_node_or_null("/root/GameManager")
	if _dialogue_open and manager != null and manager.get("active_npc") == self:
		manager.call("end_dialogue")
	elif player != null and is_instance_valid(player) and "interacting" in player:
		player.set("interacting", false)
