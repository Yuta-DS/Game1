extends CharacterBody3D

const speed = 3
var current_state = IDLE
var is_roaming = true
var is_chatting = false
var dir = Vector3.RIGHT
var start_pos

const GRAVITY_CONSTANT = 10.0 # A simpler gravity value
const FRICTION = 10.0 # Adjust this value: higher means a faster stop
@onready var gravity_force : float = GRAVITY_CONSTANT


enum {
	IDLE,
	NEW_DIR,
	MOVE
}

var player

func _ready():
	randomize()
	start_pos = position
	$Timer.start()
	
func jumpLogic(delta) -> void:
	if !is_on_floor():
		velocity.y -= gravity_force * delta # Apply gravity
	else:
		velocity.y = 0.0 # Reset vertical velocity when grounded
	
func _physics_process(delta):
	jumpLogic(delta)
	if current_state == 0 or current_state == 1:
		$Rogue/AnimationPlayer.play("Idle")
	elif current_state == 2 and !is_chatting:
		$Rogue/AnimationPlayer.play("Walking_A")
	if is_chatting:
		# If chatting, stop all horizontal movement immediately
		apply_friction(delta) # Or: velocity.x = 0.0; velocity.z = 0.0
		$Rogue/AnimationPlayer.play("Idle")
		# Exit the roaming logic, but continue to the end for move_and_slide()
	elif is_roaming:
		match current_state:
			IDLE: 
				apply_friction(delta)
			NEW_DIR:
				apply_friction(delta)
				dir = choose([Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK])
			MOVE:
				move(delta)
		
	move_and_slide()
				
func choose(array):
	array.shuffle()
	return array[0]
	
func move(delta):
	# Calculate the horizontal movement (x and z axes)
	if !is_chatting:
		var target_velocity_xz = Vector3(dir.x, 0, dir.z) * speed
		
		# Move velocity towards the target velocity (for smoother movement)
		velocity.x = lerp(velocity.x, target_velocity_xz.x, 5.0 * delta)
		velocity.z = lerp(velocity.z, target_velocity_xz.z, 5.0 * delta)
		# Optional: make the character look in the direction of travel
		if velocity.length_squared() > 0.1:
			var look_dir = -Vector3(velocity.x, 0, velocity.z).normalized()
			look_at(global_position + look_dir, Vector3.UP)

func apply_friction(delta):
	# Calculate the target velocity for stopping (which is (0, 0))
	var target_velocity_xz = Vector3.ZERO
	
	# Smoothly reduce the current velocity towards zero
	velocity.x = lerp(velocity.x, target_velocity_xz.x, FRICTION * delta)
	velocity.z = lerp(velocity.z, target_velocity_xz.z, FRICTION * delta)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.has_method("NewPlayer"):
		player = body
		is_chatting = true

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.has_method("NewPlayer"):
		is_chatting = false


func _on_timer_timeout() -> void:
	# Set a new random wait time
	$Timer.wait_time = choose ([0.5, 5, 1.5])
	
	# Choose the next state for the NPC
	current_state = choose([NEW_DIR, MOVE, IDLE])
	# Always ensure the timer is restarted for the new wait_time
	$Timer.start()
	
