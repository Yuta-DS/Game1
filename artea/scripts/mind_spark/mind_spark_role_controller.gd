class_name MindSparkRoleController
extends CharacterBody3D

## Lightweight, kingdom-local actor for one half of Mind Spark.
##
## It deliberately does not read the project's shared player actions. Each
## instance receives its own action policy, allowing couch co-op, remapping,
## role swapping, and deterministic solo-companion commands without coupling
## either role to the Art Castle player.

signal interaction_requested(role_id: String)
signal ping_requested(role_id: String)
signal input_policy_changed(role_id: String, policy_id: String)
signal solo_command_completed(role_id: String)

@export var role_id := "alarm"
@export var input_policy := "mind_alarm_keyboard"
@export var move_speed := 4.2
@export var acceleration := 18.0
@export var input_enabled := true

@export_group("Input actions")
@export var move_left_action: StringName = &"mind_alarm_move_left"
@export var move_right_action: StringName = &"mind_alarm_move_right"
@export var move_forward_action: StringName = &"mind_alarm_move_forward"
@export var move_back_action: StringName = &"mind_alarm_move_back"
@export var interact_action: StringName = &"mind_alarm_interact"
@export var ping_action: StringName = &"mind_alarm_ping"

var companion_mode := false
var _command_active := false
var _command_target := Vector3.ZERO
var _activate_on_arrival := false


func configure_role(new_role_id: String, new_policy: String, actions: Dictionary = {}) -> void:
	role_id = new_role_id
	input_policy = new_policy
	move_left_action = StringName(actions.get("left", move_left_action))
	move_right_action = StringName(actions.get("right", move_right_action))
	move_forward_action = StringName(actions.get("forward", move_forward_action))
	move_back_action = StringName(actions.get("back", move_back_action))
	interact_action = StringName(actions.get("interact", interact_action))
	ping_action = StringName(actions.get("ping", ping_action))
	_update_role_label()
	input_policy_changed.emit(role_id, input_policy)


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if enabled:
		companion_mode = false
		_command_active = false


func set_companion_mode(enabled: bool) -> void:
	companion_mode = enabled
	input_enabled = not enabled
	if not enabled:
		_command_active = false


## Explicit solo fallback seam. A coordinator chooses the safe destination;
## the actor never invents puzzle answers or advances progress on its own.
func command_solo(target: Vector3, activate_on_arrival: bool = false) -> void:
	companion_mode = true
	input_enabled = false
	_command_target = target
	_command_target.y = global_position.y
	_activate_on_arrival = activate_on_arrival
	_command_active = true


func cancel_solo_command() -> void:
	_command_active = false
	_activate_on_arrival = false


func request_interaction() -> void:
	interaction_requested.emit(role_id)


func request_ping() -> void:
	ping_requested.emit(role_id)


## Swaps only control policy. Perspective, role identity, and story meaning stay
## in place, so role swap remains an accessibility choice rather than a reset.
func swap_input_policy(other: MindSparkRoleController) -> void:
	if other == null or other == self:
		return
	var mine := input_actions()
	var mine_policy := input_policy
	configure_role(role_id, other.input_policy, other.input_actions())
	other.configure_role(other.role_id, mine_policy, mine)


func input_actions() -> Dictionary:
	return {
		"left": move_left_action,
		"right": move_right_action,
		"forward": move_forward_action,
		"back": move_back_action,
		"interact": interact_action,
		"ping": ping_action,
	}


func _ready() -> void:
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50.0)
	_update_role_label()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or companion_mode:
		return
	if _event_pressed(event, interact_action):
		request_interaction()
		get_viewport().set_input_as_handled()
	elif _event_pressed(event, ping_action):
		request_ping()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	var direction := Vector3.ZERO
	if companion_mode and _command_active:
		var offset := _command_target - global_position
		offset.y = 0.0
		if offset.length() <= 0.18:
			_command_active = false
			velocity.x = 0.0
			velocity.z = 0.0
			if _activate_on_arrival:
				_activate_on_arrival = false
				request_interaction()
			solo_command_completed.emit(role_id)
		else:
			direction = offset.normalized()
	elif input_enabled:
		var input_vector := _input_vector()
		direction = Vector3(input_vector.x, 0.0, input_vector.y)

	var target_x := direction.x * move_speed
	var target_z := direction.z * move_speed
	velocity.x = move_toward(velocity.x, target_x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_z, acceleration * delta)
	if direction.length_squared() > 0.01:
		rotation.y = rotate_toward(rotation.y, atan2(direction.x, direction.z), 8.0 * delta)
	move_and_slide()


func _input_vector() -> Vector2:
	var x := _action_strength(move_right_action) - _action_strength(move_left_action)
	var y := _action_strength(move_back_action) - _action_strength(move_forward_action)
	return Vector2(x, y).limit_length(1.0)


func _action_strength(action: StringName) -> float:
	return Input.get_action_strength(action) if InputMap.has_action(action) else 0.0


func _event_pressed(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action)


func _update_role_label() -> void:
	var label := get_node_or_null("RoleLabel") as Label3D
	if label == null:
		return
	label.text = "ALARM LENS" if role_id == "alarm" else "HOPE LENS"
	label.modulate = Color("#8deaff") if role_id == "alarm" else Color("#fff08a")
