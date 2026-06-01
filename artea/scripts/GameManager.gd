extends Node

var current_dialogue_node := ""
var dialogue_ui = null
# Test
var data = parse_line("Art Gallery Guardian: Hello! This is where the messages from the NPCs will appear.")
var dialogue_data = {}
var current_node = ""
var current_index = 0
var waiting_for_choice = false
var active_npc = null

func _ready():
	randomize()
	load_dialogue_file("uid://bvpjldbikfam7")
	#print("Loaded dialogue nodes:", dialogue_data.keys())


# -----------------------
# DIALOGUE SYSTEM (NEW)
# -----------------------

func load_dialogue_file(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open dialogue file")
		return

	var current_node_name = ""
	dialogue_data.clear()

	while not file.eof_reached():
		var line = file.get_line().strip_edges()

		if line == "":
			continue

		# New node
		if line.begins_with("~"):
			current_node_name = line.substr(1).strip_edges()
			dialogue_data[current_node_name] = []
			continue

		# Store line in current node
		if current_node_name != "":
			dialogue_data[current_node_name].append(line)

func start_dialogue(node_name: String, npc = null):
	current_dialogue_node = node_name
	active_npc = npc
	if dialogue_ui == null:
		dialogue_ui = preload("res://scenes/dialogue_ui.tscn").instantiate()
		get_tree().root.add_child(dialogue_ui)
	print("Dialogue triggered:", node_name)
	run_dialogue(node_name)


func run_dialogue(node_name: String):
	print("Running dialogue node:", node_name)
	
	if not dialogue_data.has(node_name):
		print("Node not found:", node_name)
		return

	current_node = node_name
	current_index = 0

	process_next_line()
	
	#if dialogue_ui:
		#dialogue_ui.show_text("Dialogue started: " + node_name)
		#dialogue_ui.show_line("Milo Cat", "Hello There!")
		#dialogue_ui.show_line(data.speaker, data.text)

func process_next_line():
	if not dialogue_data.has(current_node):
		end_dialogue()
		return

	var lines = dialogue_data[current_node]

	if current_index >= lines.size():
		end_dialogue()
		return

	var line = lines[current_index]
	current_index += 1

	# -----------------------
	# COMMANDS
	# -----------------------

	if line.begins_with("do "):
		execute_command(line.substr(3))
		process_next_line()
		return

	if line.begins_with("=>"):
		var target = line.substr(2).strip_edges()
		if target == "END":
			end_dialogue()
		else:
			run_dialogue(target)
		return

	# -----------------------
	# CHOICES
	# -----------------------

	if line.begins_with("-"):
		show_choices()
		return

	# -----------------------
	# NORMAL DIALOGUE
	# -----------------------

	var parsed = parse_line(line)
	dialogue_ui.show_line(parsed.speaker, parsed.text)
	
func execute_command(command: String):
	print("DEBUG: MATCHING COMMAND")
	match command:
		"GameManager.request_pop_thoughts()":
			request_pop_thoughts()
		"GameManager.request_paingting()":
			request_paingting()
		"GameManager.request_art_gallery()":
			request_art_gallery()
		"GameManager.request_Art_Therapy()":
			request_Art_Therapy()
		"GameManager.request_visit_website()":
			request_visit_website()
		"GameManager.request_music_minigame()":
			request_music_minigame()
		"GameManager.request_visit_workshops()":
			request_visit_workshops()
		"GameManager.request_visit_collection()":
			request_visit_collection()
			
var current_choices = []

func show_choices():
	current_choices.clear()

	var lines = dialogue_data[current_node]

	# Step back one because we already advanced
	var i = current_index - 1

	while i < lines.size() and lines[i].begins_with("-"):
		var choice_line = lines[i]
		var next_line = lines[i + 1] if i + 1 < lines.size() else ""

		var text = choice_line.substr(1).strip_edges()
		var target = ""

		if next_line.begins_with("=>"):
			target = next_line.substr(2).strip_edges()
			i += 1

		current_choices.append({
			"text": text,
			"target": target
		})

		i += 1

	current_index = i
	waiting_for_choice = true

	dialogue_ui.show_choices(current_choices)
	
func choose(index: int):
	if not waiting_for_choice:
		return

	waiting_for_choice = false

	var choice = current_choices[index]

	if choice.target == "END":
		end_dialogue()
	else:
		run_dialogue(choice.target)

func end_dialogue():
	current_dialogue_node = ""
	current_node = ""
	current_index = 0
	waiting_for_choice = false
	
	if dialogue_ui != null:
		dialogue_ui.queue_free()
		dialogue_ui = null
		
	if active_npc != null:
		active_npc.end_dialogue()
		active_npc = null
	
		print("Dialogue ended")
		
		
func parse_line(line: String) -> Dictionary:
	var parts = line.split(":", false, 1)

	if parts.size() == 2:
		var speaker = parts[0].strip_edges()
		var text = parts[1].strip_edges()

		text = resolve_variants(text)

		return {
			"speaker": speaker,
			"text": text
		}

	return {
		"speaker": "",
		"text": resolve_variants(line)
	}

func parse_choice(line: String) -> Dictionary:
	var cleaned = line.strip_edges().substr(1).strip_edges()
	var parts = cleaned.split("->", false, 1)

	return {
		"text": parts[0].strip_edges(),
		"target": parts[1].strip_edges() if parts.size() > 1 else ""
	}

func resolve_variants(text: String) -> String:
	while text.find("[[") != -1 and text.find("]]") != -1:
		var start = text.find("[[")
		var end = text.find("]]", start)

		if end == -1:
			break

		var content = text.substr(start + 2, end - start - 2)
		var options = content.split("|")

		var choice = options[randi() % options.size()].strip_edges()

		text = text.substr(0, start) + choice + text.substr(end + 2)

	return text


# -----------------------
# EXISTING SYSTEM (UNCHANGED)
# -----------------------

func request_music_minigame():
	print("DEBUG: MUSIC MINIGAME REQUESTED")
	MusicManager._check_scene()
	get_tree().change_scene_to_file("uid://3mhecvarwvlp")

func request_pop_thoughts():
	MusicManager._check_scene()
	get_tree().change_scene_to_file("uid://ctbchsbolgvqh")


func request_paingting():
	MusicManager._check_scene()
	get_tree().change_scene_to_file("uid://cov6pyq6rp3k7")


# Changed to 3D Gallery
func request_art_gallery():
	MusicManager._check_scene()
	get_tree().change_scene_to_file("uid://cj5tghjq224it")


func request_visit_website():
	OS.shell_open("https://www.louisachancreative.com/")
	
func request_visit_workshops():
	OS.shell_open("https://www.louisachancreative.com/news/")
	
func request_visit_collection():
	OS.shell_open("https://www.louisachancreative.com/shop/")


func request_goback_HubWorld():
	print("DEBUG: Requested return")
	MusicManager._check_scene()
	get_tree().change_scene_to_file("uid://drfdo0gpexlsl")

# LEGACY: 2D version cat therapist scene
func request_Art_Therapy():
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/art_therapist_Scene.tscn"
	MusicManager._check_scene()
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free()
