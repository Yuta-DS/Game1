extends Node

var current_dialogue_node := ""
var dialogue_ui = null
# Test
var data = parse_line("Art Gallery Guardian: Hello! This is where the messages from the NPCs will appear.")
var dialogue_data = {}
var current_node = ""
var current_index = 0
var waiting_for_choice = false

func _ready():
	pass


# -----------------------
# DIALOGUE SYSTEM (NEW)
# -----------------------

func start_dialogue(node_name: String):
	current_dialogue_node = node_name
	if dialogue_ui == null:
		dialogue_ui = preload("res://scenes/dialogue_ui.tscn").instantiate()
		get_tree().root.add_child(dialogue_ui)
	print("Dialogue triggered:", node_name)
	run_dialogue(node_name)


func run_dialogue(node_name: String):
	# Placeholder for now (we will replace this with parser later)
	print("Running dialogue node:", node_name)
	
	if dialogue_ui:
		#dialogue_ui.show_text("Dialogue started: " + node_name)
		#dialogue_ui.show_line("Milo Cat", "Hello There!")
		dialogue_ui.show_line(data.speaker, data.text)


func end_dialogue():
	current_dialogue_node = ""
	
	if dialogue_ui != null:
		dialogue_ui.queue_free()
		dialogue_ui = null
	
		print("Dialogue ended")
		
		
func parse_line(line: String) -> Dictionary:
	var parts = line.split(":", false, 1)

	if parts.size() == 2:
		return {
			"speaker": parts[0].strip_edges(),
			"text": parts[1].strip_edges()
		}

	return {
		"speaker": "",
		"text": line
	}

func parse_choice(line: String) -> Dictionary:
	var cleaned = line.strip_edges().substr(1).strip_edges()
	var parts = cleaned.split("->", false, 1)

	return {
		"text": parts[0].strip_edges(),
		"target": parts[1].strip_edges() if parts.size() > 1 else ""
	}


# -----------------------
# EXISTING SYSTEM (UNCHANGED)
# -----------------------

func request_pop_thoughts():
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/popThoughtsMenu.tscn"
	MusicManager._check_scene()
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free()


func request_paingting():
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/paint_tool.tscn"
	MusicManager._check_scene()
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free()


func request_art_gallery():
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/ArtGallery.tscn"
	MusicManager._check_scene()
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free()


func request_visit_website():
	OS.shell_open("https://www.louisachancreative.com/")


func request_goback_HubWorld():
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/artea_game.tscn"
	MusicManager._check_scene()
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free()


func request_Art_Therapy():
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/art_therapist_Scene.tscn"
	MusicManager._check_scene()
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free()
