extends CharacterBody3D

@export var speed: float = 10.0
@export var input_enabled: bool = true

# --- Visual & Animation Setup ---
@onready var animation_player = $FoxVisuals/Fox/AnimationPlayer
@onready var fox_visuals = $FoxVisuals # Reference to the container to handle rotation

const RUNNING_SPEED_THRESHOLD = 0.1 # Minimum speed to trigger the running animation
const ROTATION_SPEED = 10.0 # Speed at which the fox model rotates (adjust as needed)

func set_input_enabled(v: bool) -> void:
	input_enabled = v

func _physics_process(delta: float) -> void:
	# Disable movement if input is locked (e.g. inspecting a painting)
	if not input_enabled:
		velocity = Vector3.ZERO
		move_and_slide()
		
		# Ensure the fox is in the Idle animation when locked
		if animation_player.current_animation != "Idle":
			animation_player.play("Idle")
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

	# Convert 2D input to 3D direction (Used for velocity and rotation calculation)
	var move_dir := Vector3(input_dir.x, 0, input_dir.y)

	# Apply velocity based on input and speed
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	
	# --- ANIMATION AND ROTATION LOGIC ---
	var current_movement_length = Vector2(velocity.x, velocity.z).length()

	if current_movement_length > RUNNING_SPEED_THRESHOLD:
		# 1. Animation: Play Run
		if animation_player.current_animation != "Run":
			animation_player.play("Run")
			
		# 2. Rotation: Calculate target angle and smoothly rotate the visual model
		var target_angle = atan2(velocity.x, velocity.z) # Angle based on movement vector
		fox_visuals.rotation.y = rotate_toward(fox_visuals.rotation.y, target_angle, ROTATION_SPEED * delta)
		
	else:
		# 1. Animation: Play Idle
		if animation_player.current_animation != "Idle":
			animation_player.play("Idle")

	move_and_slide()
