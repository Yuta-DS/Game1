extends CanvasLayer

@onready var input_field = $"UIControl/CenterContainer/VSplitContainer/Control/Line Edit"
@onready var add_button = $"UIControl/CenterContainer/VSplitContainer/Control2/Create Cloud"
@onready var pop_thoughts_button = $"UIControl/CenterContainer/VSplitContainer/Control2/Pop Thoughts"
@onready var cloudForm = $"UIControl/AudioStreamPlayer2D"
@onready var errorLabel = $"UIControl/ErrorLabel"
@onready var cloud_spawner = get_node("/root/CloudPop3d/CloudSpawner3D")

var popping_started := false
var scene_changed := false

var grid_columns := 5
var grid_rows := 3
var cell_size_3d := Vector2(3.2, 2.2)
var available_positions: Array = []
var used_positions := []

func _ready():
	await get_tree().process_frame
	var cam = get_node_or_null("/root/CloudPop3d/Camera")
	if cam:
		cam.position = Vector3(0, 0, 12)
		cam.rotation_degrees = Vector3(0, 0, 0)
	MusicManager._check_scene()
	pop_thoughts_button.pressed.connect(_on_pop_thoughts_pressed)
	pop_thoughts_button.hide()
	add_button.pressed.connect(_on_add_cloud_pressed)
	add_to_group("cloud_ui")
	_init_cloud_positions()
	input_field.grab_focus()
	input_field.text_submitted.connect(_on_text_submitted)

func _on_text_submitted(text: String):
	if text.strip_edges() != "":
		spawn_cloud(text.strip_edges())
		input_field.clear()
		input_field.grab_focus()

func _on_add_cloud_pressed():
	var text = input_field.text.strip_edges()
	if text != "":
		spawn_cloud(text)
		input_field.clear()
		input_field.grab_focus()

func _on_pop_thoughts_pressed():
	print("DEBUG: Start Popping button pressed")
	print("DEBUG: Cloud spawner has ", cloud_spawner.get_child_count(), " children")
	
	input_field.hide()
	add_button.hide()
	pop_thoughts_button.hide()
	popping_started = true
	
	for cloud in cloud_spawner.get_children():
		print("DEBUG: Cloud found: ", cloud)
		if cloud.has_method("start_wandering"):
			print("DEBUG: Calling start_wandering on cloud")
			cloud.start_wandering()

func _init_cloud_positions():
	available_positions.clear()
	
	# Spread across wider area
	var positions = [
		Vector2(-8, 5), Vector2(0, 5), Vector2(8, 5),
		Vector2(-7, 3.5), Vector2(0, 3.5), Vector2(7, 3.5),
		Vector2(-6, 2), Vector2(0, 2), Vector2(6, 2),
		Vector2(-5, 0.5), Vector2(0, 0.5), Vector2(5, 0.5),
	]
	
	for pos in positions:
		available_positions.append(pos)
	
	# DON'T shuffle - use in order
	# Mix of positions - some high, some middle, some low
	#var positions = [
		# Top positions (sky)
	#	Vector2(-3, 5), Vector2(0, 5), Vector2(3, 5),
	#	Vector2(-2, 4.5), Vector2(2, 4.5),
		# Middle positions
	#	Vector2(-3, 3), Vector2(0, 3), Vector2(3, 3),
	#	Vector2(-2, 2.5), Vector2(2, 2.5),
		# Bottom positions (above ground)
	#	Vector2(-3, 1.5), Vector2(0, 1.5), Vector2(3, 1.5),
	#	Vector2(-2, 1), Vector2(2, 1),
	#]
	
	#for pos in positions:
	#	available_positions.append(pos)
	#available_positions.shuffle()

func spawn_cloud(text: String):
	if used_positions.size() >= available_positions.size():
		errorLabel.visible = true
		errorLabel.text = "Max number of clouds reached"
		return
	
	# Get available positions
	var possible_positions = available_positions.filter(func(pos): return not used_positions.has(pos))
	if possible_positions.is_empty():
		errorLabel.visible = true
		errorLabel.text = "No available positions left."
		return
	
	# Try positions until we find one that doesn't overlap
	var pos = null
	var max_attempts = 10
	
	for attempt in range(max_attempts):
		var test_pos = possible_positions.pick_random()
		var overlapping = false
		
		# Check against existing clouds
		for cloud in cloud_spawner.get_children():
			var distance = cloud.global_position.distance_to(Vector3(test_pos.x, test_pos.y, 0))
			if distance < 2.5:  # Minimum distance between clouds
				overlapping = true
				break
		
		if not overlapping:
			pos = test_pos
			break
	
	if pos == null:
		pos = possible_positions[0]  # Fallback
	
	used_positions.append(pos)
	
	var cloud = preload("res://scenes/Cloud_3d.tscn").instantiate()
	cloud_spawner.add_child(cloud)
	cloud.global_position = Vector3(pos.x, pos.y, 0.0)
	cloud.thought_text = text
	cloud.grid_position = pos
	cloudForm.play()
	
	if cloud_spawner.get_child_count() > 1:
		pop_thoughts_button.show()

func free_cloud_position(pos):
	used_positions.erase(pos)
	errorLabel.visible = false
	errorLabel.text = ""
	await get_tree().process_frame
	if cloud_spawner.get_child_count() < 2:
		pop_thoughts_button.hide()

func are_all_clouds_popped() -> bool:
	return cloud_spawner.get_child_count() <= 2

func cloud_popped():
	print("=== CLOUD POPPED DEBUG ===")
	print("popping_started: ", popping_started)
	print("Clouds left: ", cloud_spawner.get_child_count())
	print("are_all_clouds_popped: ", are_all_clouds_popped())
	print("scene_changed: ", scene_changed)
	#print("Clouds remaining: ", cloud_spawner.get_child_count())
	
	if popping_started and are_all_clouds_popped() and not scene_changed:
		print("SUCCESS: Loading completion screen!")
		scene_changed = true
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/cloudPopFinish.tscn")
	else:
		print("FAILED: Conditions not met")
		
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Get mouse position
		var mouse_pos = get_viewport().get_mouse_position()
		
		# Check each cloud
		for cloud in cloud_spawner.get_children():
			if cloud.has_method("check_click"):
				# Convert cloud's 3D position to 2D screen position
				var camera = get_node("/root/CloudPop3d/Camera")
				if camera:
					var cloud_pos_2d = camera.unproject_position(cloud.global_position)
					var distance = cloud_pos_2d.distance_to(mouse_pos)
					# If click is close to cloud (within 100 pixels)
					if distance < 100:
						cloud.check_click()
						break
