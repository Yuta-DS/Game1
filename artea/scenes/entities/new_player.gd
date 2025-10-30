extends CharacterBody3D

#This is the jump function
@export var jump_height : float = 2.25
@export var jump_time_to_peak : float = 0.4
@export var jump_time_to_descent : float = 0.25
@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

@export var baseSpeed := 4.0
@export var runSpeed := 6.0

@onready var camera = $CameraController/Camera3D

var movementInput := Vector2.ZERO

func _physics_process(delta: float) -> void:
	
	#velocity = Vector3(movementInput.x, 0, movementInput.y) * baseSpeed
	moveLogic(delta)
	jumpLogic(delta)
	
	move_and_slide()

func jumpLogic(delta) -> void:
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = -jump_velocity
	else:
		$RogueSkin/AnimationPlayer.current_animation = 'Jump'
		$RogueSkin/AnimationPlayer.current_animation = 'ToucheGround'
		
	var gravity = jump_gravity if velocity.y > 0.0 else fall_gravity


	velocity.y -= gravity * delta

	
func moveLogic(delta) -> void:
		movementInput = Input.get_vector("move_left", "move_right", "move_forward", "move_backward").rotated(-camera.global_rotation.y)
		var velocity2D = Vector2(velocity.x, velocity.z)
		var isRunning: bool = Input.is_action_pressed("run")
		
		if movementInput != Vector2.ZERO:
			var speed = runSpeed if isRunning else baseSpeed
			velocity2D += movementInput * speed * delta * 3
			velocity2D = velocity2D.limit_length(speed)
			velocity.x = velocity2D.x
			velocity.z = velocity2D.y
			$RogueSkin/AnimationPlayer.current_animation = 'Run'
			var targetAngle = -movementInput.angle() + PI/2
			$RogueSkin.rotation.y = rotate_toward($RogueSkin.rotation.y, targetAngle, 6.0 * delta)
		else:
			velocity2D = velocity2D.move_toward(Vector2.ZERO, baseSpeed * 10.0 * delta)
			velocity.x = velocity2D.x
			velocity.z = velocity2D.y
			$RogueSkin/AnimationPlayer.current_animation = 'Idle'
			
			

	
	
