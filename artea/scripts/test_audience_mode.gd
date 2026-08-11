# Self-check for faith/universal audience mode. Run headless:
#   godot --headless --path artea --script res://scripts/test_audience_mode.gd
#
# The load-bearing guarantee is the last section: switching mode must never
# change what the player can discover or earn. Everything else is naming.
extends SceneTree

const DIALOGUE_PATH := "res://dialogue/artea_park_dialogues.txt"
const FAITH_TEST_SAVE := "user://test_audience_mode_faith.json"
const UNIVERSAL_TEST_SAVE := "user://test_audience_mode_universal.json"

# Every faith-named node that must have a universal twin. Milo is absent on
# purpose: his lines carry no faith naming, so he is already correct in both
# modes and does not need a duplicate to maintain.
const NEEDS_UNIVERSAL := [
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

# Naming that must not survive into universal mode.
const FAITH_TERMS := [
	"archangel",
	"everlasting father",
	"uriel",
	"raphael",
	"gabriel",
	"prince of peace",
]


func _init() -> void:
	_test_dialogue_nodes()
	_test_guardian_labels()
	_test_mode_never_gates_progress()
	print("audience mode: all checks passed")
	quit()


# --- dialogue -------------------------------------------------------

func _test_dialogue_nodes() -> void:
	var nodes := _parse_nodes(DIALOGUE_PATH)
	assert(nodes.has("audience_neutral_fallback"),
		"inclusive dialogue has an authored neutral fallback")
	var neutral_fallback := "\n".join(nodes["audience_neutral_fallback"]).to_lower()
	for term in FAITH_TERMS:
		assert(not neutral_fallback.contains(term),
			"neutral fallback must not contain '%s'" % term)

	for node_name in NEEDS_UNIVERSAL:
		assert(nodes.has(node_name),
			"faith node %s exists" % node_name)
		assert(nodes.has(node_name + "_universal"),
			"universal twin exists for %s" % node_name)

	# The universal nodes must not reintroduce the naming they exist to avoid.
	for node_name in nodes:
		if not node_name.ends_with("_universal"):
			continue
		var body: String = "\n".join(nodes[node_name]).to_lower()
		for term in FAITH_TERMS:
			assert(not body.contains(term),
				"universal node %s must not contain '%s'" % [node_name, term])

	# Regression: the gallery guardian was authored "Price of Peace" in every
	# faith node. Catch a re-typo rather than trusting a one-off fix.
	var faith_text := ""
	for node_name in nodes:
		faith_text += "\n".join(nodes[node_name])
	assert(not faith_text.to_lower().contains("price of peace"),
		"gallery guardian is 'Prince of Peace', not 'Price'")


# Mirrors GameManager.load_dialogue_file's parsing rules.
func _parse_nodes(path: String) -> Dictionary:
	assert(FileAccess.file_exists(path), "dialogue file exists")
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "dialogue file opens")

	var nodes := {}
	var current := ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("~"):
			current = line.substr(1).strip_edges()
			nodes[current] = []
			continue
		if current != "":
			nodes[current].append(line)
	return nodes


# --- island plaques -------------------------------------------------

func _test_guardian_labels() -> void:
	var IslesScript = load("res://scripts/hub_sky_isles.gd")
	var isles = IslesScript.new()

	for isle in IslesScript.ISLES:
		assert(isle.has("guardian_universal"),
			"island %s has a universal guardian name" % isle["id"])
		var universal: String = isle["guardian_universal"].to_lower()
		for term in FAITH_TERMS:
			assert(not universal.contains(term),
				"universal guardian for %s must not contain '%s'" % [isle["id"], term])
		# The role survives the rename — that is the whole design.
		assert(universal.contains("keeper"),
			"universal guardian for %s keeps its keeper role" % isle["id"])

	# Outside the tree there is no /root/JourneyState, so the label falls back
	# to faith naming rather than erroring. A plaque that cannot resolve the
	# mode must still render Artéa's default voice.
	for isle in IslesScript.ISLES:
		assert(isles._guardian_label(isle) == isle["guardian"],
			"guardian label falls back to faith naming with no JourneyState")

	isles.free()


# --- the guarantee that matters -------------------------------------

func _test_mode_never_gates_progress() -> void:
	var JourneyStateScript = load("res://scripts/JourneyState.gd")

	var faith = JourneyStateScript.new()
	var universal = JourneyStateScript.new()
	# This test must never create, change, or erase a player's real
	# user://journey.json. JourneyState record_* methods persist immediately.
	faith.save_path = FAITH_TEST_SAVE
	faith.clear_journey()
	universal.save_path = UNIVERSAL_TEST_SAVE
	universal.clear_journey()
	universal.set_audience_mode("universal")
	assert(universal.audience_mode == "universal", "mode switch takes effect")

	# Same actions in both modes.
	for js in [faith, universal]:
		js.record_thought_echo("I am learning and growing", "learning")
		js.record_thought_echo("I can take one brave step", "brave_step")
		js.mark_popped("I am learning and growing")
		js.mark_popped("I can take one brave step")
		js.complete_mind_spark(2)
		js.record_emotion("hope", Color(0.4, 0.8, 0.6))
		var creation_id: String = str(js.record_creation("user://art/a.png", "my world"))
		js.complete_creator_frame_ritual(creation_id, "constellation_mural")

	assert(faith.treasure_count() == universal.treasure_count(),
		"both modes award the same number of treasures")
	assert(faith.has_all_treasures() and universal.has_all_treasures(),
		"both modes complete the Crown of Life")
	assert(faith.strengths.size() == universal.strengths.size(),
		"both modes grant the same strengths")

	for treasure_id in faith.treasures:
		assert(faith.has_treasure(treasure_id) == universal.has_treasure(treasure_id),
			"treasure %s is mode-independent" % treasure_id)

	faith.advance_to(4)
	universal.advance_to(4)
	assert(faith.stage == universal.stage,
		"both modes reach the same final stage")

	# An unknown mode must not silently become a third behaviour.
	universal.set_audience_mode("nonsense")
	assert(universal.audience_mode == "universal",
		"an invalid mode is rejected, not applied")

	faith.clear_journey()
	universal.clear_journey()
