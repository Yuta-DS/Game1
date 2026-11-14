# Rideable free-sailing boat for the hub ocean.
extends CharacterBody3D

@export var speed: float = 12.0
@export var reverse_speed: float = 5.5
@export var acceleration: float = 7.0
@export var water_drag: float = 4.2
@export var turn_speed: float = 1.35
@export var water_level: float = 0.92
@export var bob_height: float = 0.13
@export var bob_speed: float = 1.05

var _player: CharacterBody3D
var _time := 0.0
var _seat: Marker3D
var _visual_pivot: Node3D
var _help: Label3D
var _wake: Array[MeshInstance3D] = []
var _helm_input := Vector2.ZERO
var _boarding_cooldown := 0.0
var _player_collision_was_disabled := false
var _ocean: Node3D


func _ready() -> void:
	_ocean = get_node_or_null("../Environment/Water") as Node3D
	_seat = get_node_or_null("Seat") as Marker3D
	_visual_pivot = get_node_or_null("VisualPivot") as Node3D
	_help = get_node_or_null("SailingHelp") as Label3D
	for path in ["WakeLeft", "WakeRight"]:
		var wake_mesh := get_node_or_null(path) as MeshInstance3D
		if wake_mesh != null:
			_wake.append(wake_mesh)


func _physics_process(delta: float) -> void:
	_time += delta
	_boarding_cooldown = maxf(0.0, _boarding_cooldown - delta)
	global_position.y = _floating_height()
	_helm_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward") \
		if _player != null else Vector2.ZERO
	_apply_helm(_helm_input, delta)
	move_and_slide()
	global_position.y = _floating_height()
	_update_visuals(delta)
	if _player != null and _seat != null:
		_player.global_position = _seat.global_position
		_player.global_rotation.y = global_rotation.y


func _floating_height() -> float:
	if is_instance_valid(_ocean) and _ocean.has_method("get_water_height"):
		return float(_ocean.call("get_water_height", global_position)) + 0.17
	return water_level + sin(_time * bob_speed) * bob_height


func _apply_helm(input: Vector2, delta: float) -> void:
	var forward_speed := -input.y * (speed if input.y <= 0.0 else reverse_speed)
	var current_forward := velocity.dot(-global_transform.basis.z)
	current_forward = move_toward(current_forward, forward_speed,
		acceleration * delta if not is_zero_approx(forward_speed) else water_drag * delta)
	if absf(current_forward) > 0.08:
		var steering_scale := clampf(absf(current_forward) / speed, 0.28, 1.0)
		rotate_y(-input.x * turn_speed * steering_scale * delta * signf(current_forward))
	var forward := -global_transform.basis.z
	velocity.x = forward.x * current_forward
	velocity.z = forward.z * current_forward
	velocity.y = 0.0


func _update_visuals(delta: float) -> void:
	var sailing_speed := Vector2(velocity.x, velocity.z).length()
	var speed_ratio := clampf(sailing_speed / speed, 0.0, 1.0)
	if _visual_pivot != null:
		var swell_pitch := sin(_time * 1.45) * 0.025
		var swell_roll := 0.0
		if is_instance_valid(_ocean) and _ocean.has_method("get_water_height"):
			var front: float = _ocean.call("get_water_height", global_position - global_basis.z * 1.8)
			var back: float = _ocean.call("get_water_height", global_position + global_basis.z * 1.8)
			var right: float = _ocean.call("get_water_height", global_position + global_basis.x)
			var left: float = _ocean.call("get_water_height", global_position - global_basis.x)
			swell_pitch = clampf(atan2(front - back, 3.6), -0.2, 0.2)
			swell_roll = clampf(atan2(right - left, 2.0), -0.2, 0.2)
		_visual_pivot.rotation.z = lerp_angle(_visual_pivot.rotation.z,
			swell_roll - _helm_input.x * speed_ratio * 0.12, delta * 4.0)
		_visual_pivot.rotation.x = lerp_angle(_visual_pivot.rotation.x,
			swell_pitch + speed_ratio * 0.018, delta * 3.0)
	for wake_mesh in _wake:
		wake_mesh.visible = sailing_speed > 1.25
		wake_mesh.scale.z = 0.65 + speed_ratio * 1.35


func board(player: CharacterBody3D) -> void:
	if _player != null or player == null:
		return
	_player = player
	_player.set_meta("sailing_boat", true)
	_player.velocity = Vector3.ZERO
	_player.set_physics_process(false)
	if "interacting" in _player:
		_player.set("interacting", true)
	var player_collision := _player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if player_collision != null:
		_player_collision_was_disabled = player_collision.disabled
		player_collision.set_deferred("disabled", true)
	if _help != null:
		_help.text = "WASD sail • SPACE disembark"


func disembark() -> void:
	if _player == null:
		return
	var landing := _find_safe_landing()
	if not landing.is_finite():
		if _help != null:
			_help.text = "Sail beside the dock or shore to leave"
		return
	var departing_player := _player
	departing_player.remove_meta("sailing_boat")
	_player = null
	_boarding_cooldown = 1.0
	velocity = Vector3.ZERO
	if "interacting" in departing_player:
		departing_player.set("interacting", false)
	var player_collision := departing_player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if player_collision != null:
		player_collision.set_deferred("disabled", _player_collision_was_disabled)
	departing_player.global_position = landing
	departing_player.velocity = Vector3.ZERO
	departing_player.set_physics_process(true)
	if _help != null:
		_help.text = "Walk aboard • WASD sail • SPACE leave"


func _find_safe_landing() -> Vector3:
	var space := get_world_3d().direct_space_state
	var collision := _player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	for distance in [2.8, 3.5, 4.2]:
		for direction in [global_basis.x, -global_basis.x, global_basis.z, -global_basis.z]:
			var point: Vector3 = global_position + direction * distance
			var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3.0,
				point - Vector3.UP * 1.5, collision_mask, [get_rid(), _player.get_rid()])
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or hit.position.y < water_level - 0.1 or hit.normal.y < 0.75:
				continue
			var landing: Vector3 = hit.position + Vector3.UP * 0.06
			if collision != null:
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = collision.shape
				query.transform = Transform3D(_player.global_basis, landing) * collision.transform
				query.collision_mask = collision_mask
				query.exclude = [get_rid(), _player.get_rid()]
				if not space.intersect_shape(query, 1).is_empty():
					continue
			return landing
	return Vector3.INF


func is_boarded() -> bool:
	return _player != null


func _on_body_entered(body: Node3D) -> void:
	if _player == null and _boarding_cooldown <= 0.0 \
			and body is CharacterBody3D and body.has_method("collect_item"):
		board(body as CharacterBody3D)


func _unhandled_input(event: InputEvent) -> void:
	if _player != null and event.is_action_pressed("jump"):
		disembark()
		get_viewport().set_input_as_handled()
