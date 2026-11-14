extends Node

# This script handles joystick input and converts it to keyboard-like input actions
# It should be attached to a node in the scene that has access to the joystick

var joystick: Node = null
var joystick_direction: Vector2 = Vector2.ZERO
var deadzone: float = 0.2  # Minimum joystick movement to register input

func _ready():
	# Find the joystick in the scene
	joystick = find_joystick_in_scene()
	if joystick and joystick.has_signal("joystick_moved"):
		joystick.joystick_moved.connect(_on_joystick_moved)
		joystick.joystick_released.connect(_on_joystick_released)
		print("Joystick input handler connected to joystick")
	else:
		print("Warning: No joystick found in scene or joystick doesn't have required signals")

func find_joystick_in_scene() -> Node:
	# Look for the joystick in the current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		# Try to find joystick in the scene tree
		var joystick_node = current_scene.find_child("Joystick", true, false)
		if joystick_node and joystick_node.has_signal("joystick_moved"):
			return joystick_node
		
		# If not found directly, look in Control_HUD
		var control_hud = current_scene.find_child("Control", true, false)
		if control_hud:
			# Look for the Joystick instance within the Control_HUD
			for child in control_hud.get_children():
				if child.name == "Joystick" and child.has_signal("joystick_moved"):
					return child
	
	return null

func _on_joystick_moved(direction: Vector2):
	joystick_direction = direction
	
	# Convert joystick direction to input actions with deadzone
	if direction.x < -deadzone:  # Left threshold
		if not Input.is_action_pressed("move_left"):
			Input.action_press("move_left")
		Input.action_release("move_right")
	elif direction.x > deadzone:  # Right threshold
		if not Input.is_action_pressed("move_right"):
			Input.action_press("move_right")
		Input.action_release("move_left")
	else:
		# In deadzone, release both actions
		Input.action_release("move_left")
		Input.action_release("move_right")

func _on_joystick_released():
	joystick_direction = Vector2.ZERO
	Input.action_release("move_left")
	Input.action_release("move_right")

func _exit_tree():
	# Clean up input actions when the node is removed
	Input.action_release("move_left")
	Input.action_release("move_right")
