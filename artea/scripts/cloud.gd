extends Node2D

#  NODE REFERENCES 
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label = $Label
@onready var cloudPoof = $AudioStreamPlayer2D

#  EXPORTED VARIABLES 
@export var thought_text: String = ""  # The message the cloud will display

#  INTERNAL STATE 
var grid_position: Vector2  # Position reference used for UI coordination

# FLOATING MOVEMENT CONFIG
var floating := false
var float_timer := 0.0
var base_y := 0.0
var float_amplitude := 10.0
var float_speed := 2.0
var move_direction := Vector2.ZERO
var move_speed := 0.0
var speed_min := 20.0
var speed_max := 60.0
var edge_bounce_smoothness := 0.2
var movement_style := ""  # "horizontal", "vertical", "diagonal", or "free"


func _ready():
	sprite.play("forming")
	await sprite.animation_finished
	sprite.play("steady")
	
	
	label.text = thought_text		# Assign the thought message
	label.add_theme_color_override("font_color", get_vivid_color())
	
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("shadow_color", Color(0, 0, 0, 0.5))
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 2)
	add_to_group("active_clouds")
	
func get_vivid_color() -> Color:
	var allowed_hues = [0.0, 0.1, 0.15, 0.3, 0.55, 0.7, 0.85]  # Red, orange, pink, green, blue, violet
	var hue = allowed_hues[randi() % allowed_hues.size()]
	return Color.from_hsv(hue, 0.9, 1.0)
	
# Cloud Pop behaviour
func pop_cloud():
	sprite.play("popping")
	cloudPoof.play()
	await sprite.animation_finished

	var ui = get_tree().get_first_node_in_group("cloud_ui")
	if ui and ui.has_method("free_cloud_position"):
		call_deferred("_notify_ui_and_free", ui)

	if ui and ui.has_method("cloud_popped"):
		ui.cloud_popped()

	await get_tree().create_timer(0.1).timeout
	queue_free()

func _notify_ui_and_free(ui):
	ui.free_cloud_position(grid_position)
	queue_free()

# USER INTERACTION 
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		pop_cloud()

# START FLOATING/WANDERING 
func start_wandering():
	floating = true
	base_y = position.y
	float_timer = randf() * TAU

	# Randomize speed and float characteristics
	move_speed = randf_range(speed_min, speed_max)
	float_amplitude = randf_range(5.0, 15.0)
	float_speed = randf_range(1.5, 3.0)

	# Choose movement style
	var styles = ["horizontal", "vertical", "diagonal", "free"]
	movement_style = styles[randi() % styles.size()]

	# Direction based on style
	match movement_style:
		"horizontal":
			move_direction = Vector2(randf_range(0.8, 1.0) * (-1 if randf() > 0.5 else 1), 0)
		"vertical":
			move_direction = Vector2(0, randf_range(0.8, 1.0) * (-1 if randf() > 0.5 else 1))
		"diagonal":
			var x_dir = 1 if randf() > 0.5 else -1
			var y_dir = 1 if randf() > 0.5 else -1
			move_direction = Vector2(x_dir, y_dir).normalized()
		"free":
			move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

	set_process(true)

#  FLOATING AND MOVEMENT LOGIC 
func _process(delta):
	if not floating:
		return

	float_timer += delta
	var vertical_offset = sin(float_timer * float_speed) * float_amplitude

	if movement_style != "vertical":
		position.y = base_y + vertical_offset

	var screen_size = get_viewport_rect().size
	var new_position = position + move_direction * move_speed * delta
	var will_hit_edge = false

	# X-axis boundary check
	if new_position.x < 0:
		new_position.x = lerp(0.0, position.x, edge_bounce_smoothness)
		move_direction.x = abs(move_direction.x)
		will_hit_edge = true
	elif new_position.x > screen_size.x:
		new_position.x = lerp(screen_size.x, position.x, edge_bounce_smoothness)
		move_direction.x = -abs(move_direction.x)
		will_hit_edge = true

	# Y-axis boundary check
	if new_position.y < 0:
		new_position.y = lerp(0.0, position.y, edge_bounce_smoothness)
		move_direction.y = abs(move_direction.y)
		base_y = clamp(new_position.y, 0, screen_size.y)
		will_hit_edge = true
	elif new_position.y > screen_size.y:
		new_position.y = lerp(screen_size.y, position.y, edge_bounce_smoothness)
		move_direction.y = -abs(move_direction.y)
		base_y = clamp(new_position.y, 0, screen_size.y)
		will_hit_edge = true

	position = new_position

	# Apply bouncing and small randomization
	if will_hit_edge:
		match movement_style:
			"horizontal":
				move_direction.y = 0
				move_direction.x = sign(move_direction.x) * randf_range(0.8, 1.0)
			"vertical":
				move_direction.x = 0
				move_direction.y = sign(move_direction.y) * randf_range(0.8, 1.0)
			"diagonal":
				var x_dir = sign(move_direction.x) * randf_range(0.7, 1.0)
				var y_dir = sign(move_direction.y) * randf_range(0.7, 1.0)
				move_direction = Vector2(x_dir, y_dir).normalized()
			"free":
				move_direction = move_direction.rotated(randf_range(-0.3, 0.3)).normalized()

		# Randomize speed slightly after bounce
		if randf() < 0.3:
			move_speed = randf_range(speed_min, speed_max)
