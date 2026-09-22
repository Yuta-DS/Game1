extends Node

const SceneLoader := preload("res://scripts/scene_loader.gd")

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
	print("Loading dialogue from: HubworldDialogue.dialogue")
	
	load_dialogue_file("res://dialogue/artea_park_dialogues.txt")
	#print("Loaded dialogue nodes:", dialogue_data.keys())
	
	#var dialogue = load("res://dialogue/HubworldDialogue.dialogue")
	#DialogueManager.get_next_dialogue_line(dialogue)


# -----------------------
# DIALOGUE SYSTEM (NEW)
# -----------------------

# Artéa's guardians are written in faith language by default — that is the
# authentic voice of the project, not a mode to opt into. Schools and
# community programs that need the same message without explicit faith
# framing select JourneyState.audience_mode = "universal", and every node
# then uses a reviewed "<node>_universal" variant.
#
# A required inclusive twin must never silently fall back to faith language.
# If an authored pair is accidentally missing at release time, route to the
# neutral, non-gating line below instead. Neutral nodes (such as Milo's
# already-neutral prompts) can remain shared without a duplicate.
#
# What changes is the naming register only. The guardians keep their role,
# their warmth, and every word of the dignity/purpose message: the Keeper of
# Wisdom says what the Everlasting Father says. Progression, treasures and
# rewards are identical in both modes, which JourneyState already guarantees
# by never reading audience_mode.
const UNIVERSAL_SUFFIX := "_universal"
const UNIVERSAL_NEUTRAL_FALLBACK := "audience_neutral_fallback"
const UNIVERSAL_REQUIRED_NODES := [
	"start_archangel_dialogue",
	"launch_music_minigame",
	"start_zephyr_dialogue",
	"launch_pop_thoughts",
	"start_patron_pallete",
	"explain_painting_tool",
	"open_collection",
	"open_painting_tool",
	"start_maestro_montclair",
	"explain_gallery",
	"open_art_gallery",
	"start_archangel_gabriel",
]


func resolve_audience_node(node_name: String) -> String:
	if node_name.ends_with(UNIVERSAL_SUFFIX):
		return node_name

	# Absolute path, so guard against being called outside the active tree.
	var js: Node = null
	if is_inside_tree():
		js = get_node_or_null("/root/JourneyState")
	if js == null or js.audience_mode != "universal":
		return node_name

	var universal := node_name + UNIVERSAL_SUFFIX
	if dialogue_data.has(universal):
		return universal
	if node_name in UNIVERSAL_REQUIRED_NODES:
		push_warning("Missing inclusive dialogue twin for %s; using neutral fallback" % node_name)
		return UNIVERSAL_NEUTRAL_FALLBACK
	return node_name

func load_dialogue_file(path: String):
	print("Attempting to open: ", path)
	print("File exists: ", FileAccess.file_exists(path))
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

		# Comment — authoring note, never shown to the player.
		if line.begins_with("#"):
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
	# Resolved here rather than only at start_dialogue() because "=>" jumps and
	# choice targets re-enter through this function. Resolving at entry alone
	# would speak the first line as the Keeper and every later line as the
	# angel.
	node_name = resolve_audience_node(node_name)
	print("Running dialogue node:", node_name)

	if not dialogue_data.has(node_name):
		push_warning("Dialogue node not found: %s" % node_name)
		# NPCs lock player movement before calling start_dialogue(). A bare
		# return here used to leave that lock active forever with no dialogue UI
		# on screen. Always run the normal cleanup path on an invalid target.
		end_dialogue()
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
		
	if active_npc != null and is_instance_valid(active_npc) \
			and active_npc.has_method("end_dialogue"):
		active_npc.end_dialogue()
		active_npc = null
	else:
		# The NPC may have been removed during a scene transition. Do not retain
		# a stale owner that can poison the next interaction.
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
	get_node("/root/JourneyCampaign").enter_kingdom("heart")

# Milo speaks to where the player actually is in the journey — and, where a
# more specific node exists, to *what they actually did* to get there.
# Falls back to the plain "milo_stage_N" node if the journey record is
# missing or no variant applies, so writing zero variants breaks nothing.
func request_milo(npc = null):
	var stage := 0
	var js = get_node_or_null("/root/JourneyState")
	if js != null:
		stage = clampi(js.stage, 0, 4)

	var node_name := "milo_stage_%d" % stage
	var variant := _milo_variant(stage, js)
	if variant != "" and dialogue_data.has(variant):
		node_name = variant

	start_dialogue(node_name, npc)


# Which node earns the moment, based on counts JourneyState already tracks.
# Returns "" when nothing distinguishes this playthrough from the default —
# the plain stage node is not a fallback to apologize for, it is correct for
# a player who has only just crossed into this stage.
func _milo_variant(stage: int, js) -> String:
	if js == null:
		return ""

	match stage:
		1:
			# Popped several thoughts in one sitting, not just the one that
			# unlocked the stage — the courage was repeated, not a fluke.
			if js.popped_count() >= 3:
				return "milo_stage_1_many"
		2:
			# Sat with more than one kind of feeling, not the same emotion
			# on repeat.
			var distinct := {}
			for e in js.emotions:
				distinct[e.get("name", "")] = true
			if distinct.size() >= 3:
				return "milo_stage_2_varied"
		3:
			if js.creations.size() >= 3:
				return "milo_stage_3_many"
		4:
			# Every recognised strength earned, not just one or two.
			if js.strengths.size() >= 3:
				return "milo_stage_4_full"

	return ""


func request_pop_thoughts():
	MusicManager._check_scene()
	get_tree().change_scene_to_file("res://scenes/popThoughtsMenu.tscn")


func request_paingting():
	MusicManager._check_scene()
	get_tree().change_scene_to_file("res://scenes/drawing_tool.tscn")


# Changed to 3D Gallery
func request_art_gallery():
	MusicManager._check_scene()
	SceneLoader.change_scene_with_loading(get_tree(), "res://scenes/art_gallery_3d_inprogress.tscn")


func request_visit_website():
	OS.shell_open("https://www.louisachancreative.com/")
	
func request_visit_workshops():
	OS.shell_open("https://www.louisachancreative.com/news/")
	
func request_visit_collection():
	OS.shell_open("https://www.louisachancreative.com/shop/")


func request_goback_HubWorld():
	print("DEBUG: Requested return")
	MusicManager._check_scene()
	var global := get_node_or_null("/root/Global")
	if global != null and global.has_method("request_spawn_at"):
		global.request_spawn_at("castle_front_door")
	SceneLoader.change_scene_with_loading(get_tree(), "res://scenes/New_Hub_World.tscn")

# LEGACY: 2D version cat therapist scene
func request_Art_Therapy():
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/art_therapist_Scene.tscn"
	MusicManager._check_scene()
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free()
