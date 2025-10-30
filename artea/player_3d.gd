extends CharacterBody3D

@export var speed: float = 5.0
@export var input_enabled: bool = true

func set_input_enabled(v: bool) -> void:
	input_enabled = v

func _physics_process(delta: float) -> void:
	# Disable movement if input is locked (e.g. inspecting a painting)
	if not input_enabled:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Handle movement input
	var input_dir := Vector2.ZERO

	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	input_dir = input_dir.normalized()

	# Convert 2D input to 3D direction
	var move_dir := Vector3(input_dir.x, 0, input_dir.y)

	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

	move_and_slide()
