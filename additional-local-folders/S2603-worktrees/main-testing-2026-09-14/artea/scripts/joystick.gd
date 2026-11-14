extends Control

signal joystick_moved(direction: Vector2)
signal joystick_released

@onready var joystick_ring = $JoystickRing
@onready var joystick_knob = $JoystickKnob
@onready var joystick_button = $JoystickButton

var joystick_radius: float = 60.0  # Adjusted for 150x150 joystick
var joystick_center: Vector2
var is_dragging: bool = false
var touch_id: int = -1

func _ready():
	# Calculate the center of the joystick ring
	joystick_center = Vector2(75, 75)  # Center of 150x150 joystick
	# Position the knob at the center initially
	reset_joystick()
	
	# Connect button signals
	joystick_button.button_down.connect(_on_button_pressed)
	joystick_button.button_up.connect(_on_button_released)

func _on_button_pressed():
	# Get mouse position relative to joystick
	var mouse_pos = get_local_mouse_position()
	var distance = mouse_pos.distance_to(joystick_center)
	
	if distance <= joystick_radius and not is_dragging:
		is_dragging = true
		update_joystick_position(mouse_pos)

func _on_button_released():
	if is_dragging:
		is_dragging = false
		reset_joystick()
		joystick_released.emit()

func _gui_input(event):
	# Handle mouse motion while dragging
	if event is InputEventMouseMotion and is_dragging:
		var local_mouse_pos = event.position
		update_joystick_position(local_mouse_pos)

func _input(event):
	# Handle touch input (for mobile devices)
	if event is InputEventScreenTouch:
		if event.pressed:
			# For touch input, we'll use a simpler approach
			# Check if touch is roughly within joystick bounds
			var touch_pos = event.position
			var joystick_global_pos = global_position
			var local_touch_pos = touch_pos - joystick_global_pos
			var distance = local_touch_pos.distance_to(joystick_center)
			
			if distance <= joystick_radius and touch_id == -1:
				touch_id = event.index
				is_dragging = true
				update_joystick_position(local_touch_pos)
		else:
			# Release joystick
			if event.index == touch_id:
				touch_id = -1
				is_dragging = false
				reset_joystick()
				joystick_released.emit()
	
	elif event is InputEventScreenDrag:
		if event.index == touch_id and is_dragging:
			# For drag input, use the same approach
			var drag_pos = event.position
			var joystick_global_pos = global_position
			var local_drag_pos = drag_pos - joystick_global_pos
			update_joystick_position(local_drag_pos)

func update_joystick_position(input_pos: Vector2):
	var direction = input_pos - joystick_center
	var distance = direction.length()
	
	# Clamp to joystick radius
	if distance > joystick_radius:
		direction = direction.normalized() * joystick_radius
	
	# Update knob position - center the knob on the calculated position
	joystick_knob.position = joystick_center + direction - joystick_knob.size / 2
	
	# Calculate normalized direction (-1 to 1)
	var normalized_direction = direction / joystick_radius
	
	# Emit signal with direction
	joystick_moved.emit(normalized_direction)

func reset_joystick():
	# Center the knob properly - calculate the center position
	var knob_size = joystick_knob.size
	var center_x = joystick_center.x - knob_size.x / 2
	var center_y = joystick_center.y - knob_size.y / 2
	joystick_knob.position = Vector2(center_x, center_y)
	joystick_moved.emit(Vector2.ZERO)
