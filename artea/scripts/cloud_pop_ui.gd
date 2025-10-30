extends Control

# Varaiable declaration & initialization
@onready var input_field = $"CenterContainer/VSplitContainer/Control/Line Edit"
@onready var add_button = $"CenterContainer/VSplitContainer/Control2/Create Cloud"
@onready var cloud_spawner =$"CanvasLayer/Cloud Spawner"
@onready var pop_thoughts_button = $"CenterContainer/VSplitContainer/Control2/Pop Thoughts"
@onready var cloudForm = $AudioStreamPlayer2D
@onready var errorLabel = $ErrorLabel
var popping_started := false
var popped_count := 0
var total_clouds := 0


func _ready():
	# Wait till the parent process finish before checking scene
	await get_tree().process_frame
	MusicManager._check_scene()
	
	pop_thoughts_button.pressed.connect(_on_pop_thoughts_pressed)
	pop_thoughts_button.hide()
	add_button.pressed.connect(_on_add_cloud_pressed)
	
	var screen_width := get_viewport_rect().size.x
	@warning_ignore("shadowed_variable")
	var total_grid_width := grid_columns * cell_size.x
	@warning_ignore("unused_variable")
	var spawner_x_offset := (screen_width - total_grid_width) / 2
	cloud_spawner.position = Vector2((screen_width - total_grid_width) / 2 + 60, 0)  # Center the spawner itself
	add_to_group("cloud_ui")  # Add to group so cloud.gd can find them
	_init_cloud_positions()

	
# Adding cloud function
func _on_add_cloud_pressed():
	var text = input_field.text.strip_edges()
	if text != "":
		spawn_cloud(text)
		input_field.clear()
		
# Start popping clouds
func _on_pop_thoughts_pressed() -> void:
	input_field.hide()
	add_button.hide()
	pop_thoughts_button.hide()
	popping_started = true
	# Activate all clouds to start wandering
	for cloud in cloud_spawner.get_children():
		if cloud.has_method("start_wandering"):
			cloud.start_wandering()

# Places the cloud in order for organization
# Used chatgpt to help centering the clouds initials
var grid_columns := 5
var grid_rows := 3
var cell_size := Vector2(240, 140)  # Spaced out
var window_width := 1280
var total_grid_width := grid_columns * cell_size.x  # = 1200
var available_positions: Array = []

func _init_cloud_positions():
	available_positions.clear()

	var screen_width := get_viewport_rect().size.x
	@warning_ignore("shadowed_variable")
	var total_grid_width := grid_columns * cell_size.x
	var grid_origin := Vector2((screen_width - total_grid_width) / 2, 160)

	for row in range(grid_rows):
		for col in range(grid_columns):
			var pos = grid_origin + Vector2(col * cell_size.x, row * cell_size.y)
			available_positions.append(pos)
	available_positions.shuffle()

var used_positions := []

func spawn_cloud(text: String):
	if used_positions.size() >= available_positions.size():
		errorLabel.visible = true
		errorLabel.text="Max number of clouds reached"
		return
	
	var possible_positions = available_positions.filter(func(pos): return not used_positions.has(pos))
	if possible_positions.is_empty():
		errorLabel.visible = true
		errorLabel.text="No available positions left."
		return

	var pos = possible_positions.pick_random()
	used_positions.append(pos)

	var cloud = preload("res://scenes/cloud.tscn").instantiate()
	cloud.thought_text = text
	cloud.grid_position = pos  # Track grid position for later reuse
	cloud.position = pos
	cloud.add_to_group("cloud_ui")
	cloud_spawner.add_child(cloud)
	cloudForm.play()
	
	if cloud_spawner.get_child_count() > 1:
		pop_thoughts_button.show()


# Checks if spawning will overlap
func is_cloud_overlapping(cloud: Node2D) -> bool:
	var area: Area2D = cloud.get_node("Area2D")
	var overlapping = area.get_overlapping_areas()
	for other in overlapping:
		if other.get_parent() != cloud:
			return true
	return false

# Reclaim positions when clouds are popped
func free_cloud_position(pos: Vector2):
	used_positions.erase(pos)
	
	# Erase and hide the error text after pop
	errorLabel.visible = false
	errorLabel.text = ""
	
	await get_tree().process_frame  # Wait for the queued cloud to actually be freed

	if cloud_spawner.get_child_count() < 2:
		pop_thoughts_button.hide()


func are_all_clouds_popped() -> bool:
	return cloud_spawner.get_child_count() <= 2

var scene_changed := false

func cloud_popped():
	if popping_started and are_all_clouds_popped() and !scene_changed:
		scene_changed = true
		await get_tree().create_timer(1.0).timeout  
		get_tree().change_scene_to_file("res://scenes/cloudPopFinish.tscn")
