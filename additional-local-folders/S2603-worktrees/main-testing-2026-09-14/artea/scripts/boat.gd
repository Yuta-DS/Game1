# A small rideable boat. Walk into it to board, walk off (or press the
# board key again) to disembark. While boarded, player input drives the
# boat instead of the player body, and the boat is free to travel
# anywhere over the water — no rails, no fixed route.
extends CharacterBody3D

@export var speed: float = 10.0
@export var turn_speed: float = 1.6
@export var water_level: float = 0.0
@export var bob_height: float = 0.15
@export var bob_speed: float = 1.0

var _player: CharacterBody3D = null
var _player_prev_process_mode: int = -1
var _time: float = 0.0
var _seat: Marker3D


func _ready() -> void:
	_seat = get_node_or_null("Seat")


func _physics_process(delta: float) -> void:
	_time += delta

	# Always bob gently on the water, boarded or not.
	global_position.y = water_level + sin(_time * bob_speed) * bob_height

	if _player == null:
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input.length() > 0.01:
		rotate_y(-input.x * turn_speed * delta)
		var forward := -global_transform.basis.z
		velocity.x = forward.x * -input.y * speed
		velocity.z = forward.z * -input.y * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta)

	move_and_slide()

	if _player != null and _seat != null:
		_player.global_position = _seat.global_position


func board(player: CharacterBody3D) -> void:
	if _player != null:
		return
	_player = player
	_player.velocity = Vector3.ZERO
	_player.set_physics_process(false)
	_player.set("interacting", true)
	if _player.has_node("CollisionShape3D"):
		_player.get_node("CollisionShape3D").disabled = true


func disembark() -> void:
	if _player == null:
		return
	var p := _player
	_player = null
	p.set("interacting", false)
	if p.has_node("CollisionShape3D"):
		p.get_node("CollisionShape3D").disabled = false
	# Step the player off to the side so they don't immediately re-board.
	p.global_position = global_position + global_transform.basis.x * 2.5 + Vector3(0, 1.0, 0)
	p.set_physics_process(true)


func _on_body_entered(body: Node3D) -> void:
	if _player != null:
		return
	if body is CharacterBody3D and body.has_method("collect_item"):
		board(body)


func _unhandled_input(event: InputEvent) -> void:
	if _player == null:
		return
	if event.is_action_pressed("jump"):
		disembark()
