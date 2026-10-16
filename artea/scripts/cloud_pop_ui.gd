extends CanvasLayer

@onready var input_field = $"UIControl/CenterContainer/VSplitContainer/Control/Line Edit"
@onready var add_button = $"UIControl/CenterContainer/VSplitContainer/Control2/Create Cloud"
@onready var pop_thoughts_button = $"UIControl/CenterContainer/VSplitContainer/Control2/Pop Thoughts"
@onready var cloudForm = $"UIControl/AudioStreamPlayer2D"
@onready var errorLabel = $"UIControl/ErrorLabel"
@onready var cloud_spawner = get_node("/root/CloudPop3d/CloudSpawner3D")

var popping_started := false
var scene_changed := false
var held_cloud = null

# Mind Spark's default player surface is intentionally a short, authored set
# of Thought Echoes. It is not a prompt for a child to disclose something
# personal, and the same four choices are available in every audience mode.
const THOUGHT_ECHOES: Array[Dictionary] = [
	{
		"id": "learning",
		"text": "I am learning and growing.",
	},
	{
		"id": "brave_step",
		"text": "I can take one brave step.",
	},
	{
		"id": "ask_for_help",
		"text": "I can ask for help.",
	},
	{
		"id": "rest",
		"text": "I can rest and try again later.",
	},
]
const MINIMUM_THOUGHT_ECHOES := 2

# Milo's prompts are scripted and local. They never diagnose, infer a hidden
# motive, or make a claim about the player from a selected Thought Echo.
const HOLD_PROMPTS := [
	"Milo: What do you notice about this Thought Echo?",
	"Milo: You can pause here. There is nothing to solve right away.",
	"Milo: A thought can be noticed without deciding what happens next.",
	"Milo: You can let this echo drift, or choose to release it.",
	"Milo: Take your time. You can skip this kingdom whenever you need to.",
]

var grid_columns := 5
var grid_rows := 3
var cell_size_3d := Vector2(3.2, 2.2)
var available_positions: Array = []
var used_positions := []
var _selected_echo_ids: Array[String] = []
var _thought_echo_panel: PanelContainer
var _thought_echo_status: Label

func _ready():
	await get_tree().process_frame
	var cam = get_node_or_null("/root/CloudPop3d/Camera")
	if cam:
		cam.position = Vector3(0, 0, 12)
		cam.rotation_degrees = Vector3(0, 0, 0)
	MusicManager._check_scene()
	pop_thoughts_button.pressed.connect(_on_pop_thoughts_pressed)
	pop_thoughts_button.hide()
	# Keep the legacy scene controls in place for layout compatibility, but the
	# child/school default does not accept raw text from them.
	input_field.editable = false
	input_field.hide()
	add_button.hide()
	add_to_group("cloud_ui")
	_init_cloud_positions()
	_build_thought_echo_surface()

func _on_text_submitted(_text: String) -> void:
	# Kept only for compatibility with a legacy scene connection. Raw text is
	# never added as a Thought Echo or written to the player's journey.
	input_field.clear()

func _on_add_cloud_pressed() -> void:
	# See _on_text_submitted(): the default Mind Spark route is curated.
	input_field.clear()

func _on_pop_thoughts_pressed():
	if cloud_spawner.get_child_count() < MINIMUM_THOUGHT_ECHOES:
		return
	print("DEBUG: Start Popping button pressed")
	print("DEBUG: Cloud spawner has ", cloud_spawner.get_child_count(), " children")
	
	input_field.hide()
	add_button.hide()
	pop_thoughts_button.hide()
	if _thought_echo_panel != null:
		_thought_echo_panel.hide()
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


func _build_thought_echo_surface() -> void:
	_thought_echo_panel = PanelContainer.new()
	_thought_echo_panel.name = "ThoughtEchoPanel"
	_thought_echo_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_thought_echo_panel.position = Vector2(-360.0, 18.0)
	_thought_echo_panel.custom_minimum_size = Vector2(720.0, 0.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.10, 0.22, 0.92)
	style.border_color = Color(0.48, 0.72, 1.0, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(18)
	_thought_echo_panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_thought_echo_panel.add_child(box)

	var heading := Label.new()
	heading.text = "MIND SPARK • THOUGHT ECHOES"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	box.add_child(heading)

	var invitation := Label.new()
	invitation.text = "Choose two or more story cards to explore. They are not questions about you, and you can skip at any time."
	invitation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	invitation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	invitation.add_theme_font_size_override("font_size", 17)
	invitation.add_theme_color_override("font_color", Color(0.75, 0.84, 0.98))
	box.add_child(invitation)

	var choices := GridContainer.new()
	choices.name = "ThoughtEchoChoices"
	choices.columns = 2
	choices.add_theme_constant_override("h_separation", 10)
	choices.add_theme_constant_override("v_separation", 10)
	box.add_child(choices)

	for echo in THOUGHT_ECHOES:
		var choice := Button.new()
		choice.name = "ThoughtEcho_%s" % str(echo["id"])
		choice.text = str(echo["text"])
		choice.tooltip_text = "An authored Thought Echo. It is not a question about you."
		choice.custom_minimum_size = Vector2(330.0, 48.0)
		choice.add_theme_font_size_override("font_size", 17)
		choice.pressed.connect(_choose_thought_echo.bind(echo, choice))
		choices.add_child(choice)

	_thought_echo_status = Label.new()
	_thought_echo_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thought_echo_status.add_theme_font_size_override("font_size", 16)
	_thought_echo_status.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58))
	box.add_child(_thought_echo_status)
	_update_thought_echo_status()

	var skip := Button.new()
	skip.name = "SkipThoughtEchoes"
	skip.text = "Skip for now"
	skip.tooltip_text = "Return to the Art Castle without adding a Thought Echo."
	skip.custom_minimum_size = Vector2(0.0, 42.0)
	skip.add_theme_font_size_override("font_size", 16)
	skip.pressed.connect(_return_to_campaign)
	box.add_child(skip)

	$UIControl.add_child(_thought_echo_panel)


func _choose_thought_echo(echo: Dictionary, choice: Button) -> void:
	if popping_started:
		return
	var echo_id := str(echo.get("id", ""))
	var echo_text := str(echo.get("text", "")).strip_edges()
	if echo_id.is_empty() or echo_text.is_empty() or _selected_echo_ids.has(echo_id):
		return
	if not _spawn_curated_cloud(echo_text, echo_id):
		return

	_selected_echo_ids.append(echo_id)
	choice.disabled = true
	choice.text = "✓ " + echo_text
	_update_thought_echo_status()


func _update_thought_echo_status() -> void:
	if _thought_echo_status == null:
		return
	var remaining := maxi(0, MINIMUM_THOUGHT_ECHOES - _selected_echo_ids.size())
	if remaining > 0:
		_thought_echo_status.text = "Choose %d more Thought Echo%s to begin." % [
			remaining, "" if remaining == 1 else "es"]
	else:
		_thought_echo_status.text = "Your Thought Echoes are ready. Select Start Popping when you want to begin."


func _return_to_campaign() -> void:
	var campaign := get_node_or_null("/root/JourneyCampaign")
	if campaign != null and campaign.has_method("return_to_campaign"):
		campaign.call("return_to_campaign")
	else:
		get_tree().change_scene_to_file("res://scenes/art_gallery_3d_inprogress.tscn")


func _spawn_curated_cloud(echo_text: String, echo_id: String) -> bool:
	if used_positions.size() >= available_positions.size():
		errorLabel.visible = true
		errorLabel.text = "Max number of clouds reached"
		return false
	
	# Get available positions
	var possible_positions = available_positions.filter(func(pos): return not used_positions.has(pos))
	if possible_positions.is_empty():
		errorLabel.visible = true
		errorLabel.text = "No available positions left."
		return false
	
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

	# This is only reached through _choose_thought_echo(), after a deliberate
	# authored-card selection. The stable card ID lets JourneyState verify the
	# full encounter before awarding a kingdom treasure; no typed player text
	# enters the journal here.
	JourneyState.record_thought_echo(echo_text, echo_id)

	var cloud = preload("res://scenes/Cloud_3d.tscn").instantiate()
	cloud_spawner.add_child(cloud)
	cloud.global_position = Vector3(pos.x, pos.y, 0.0)
	cloud.thought_text = echo_text
	cloud.grid_position = pos
	cloudForm.play()
	
	if cloud_spawner.get_child_count() > 1:
		pop_thoughts_button.show()
	return true

# A cloud was clicked once: hold it still and let Milo ask about it.
# Clicking a different cloud releases the previous one — only one thought
# is looked at a time.
func thought_held(text: String) -> void:
	for cloud in cloud_spawner.get_children():
		if cloud.has_method("release_thought") and cloud.thought_text != text:
			cloud.release_thought()

	errorLabel.visible = true
	errorLabel.text = HOLD_PROMPTS.pick_random() + "\n(Click again to let it go.)"


func _clear_prompt() -> void:
	errorLabel.visible = false
	errorLabel.text = ""


func free_cloud_position(pos):
	used_positions.erase(pos)
	_clear_prompt()
	await get_tree().process_frame
	if cloud_spawner.get_child_count() < 2:
		pop_thoughts_button.hide()

func are_all_clouds_popped() -> bool:
	# Every cloud the player created must be resolved before the Star of Wisdom
	# can be awarded. cloud_3d.gd detaches a resolved cloud before notifying us,
	# so zero live clouds is the only honest completion condition.
	return cloud_spawner.get_child_count() == 0

func cloud_popped():
	print("=== CLOUD POPPED DEBUG ===")
	print("popping_started: ", popping_started)
	print("Clouds left: ", cloud_spawner.get_child_count())
	print("are_all_clouds_popped: ", are_all_clouds_popped())
	print("scene_changed: ", scene_changed)
	#print("Clouds remaining: ", cloud_spawner.get_child_count())
	
	_clear_prompt()

	if popping_started and are_all_clouds_popped() and not scene_changed:
		if not JourneyState.complete_mind_spark(MINIMUM_THOUGHT_ECHOES):
			errorLabel.visible = true
			errorLabel.text = "Finish two selected Thought Echoes before completing this kingdom."
			return
		print("SUCCESS: Loading completion screen!")
		scene_changed = true
		JourneyState.advance_to(1)
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
