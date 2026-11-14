# Self-check for the audience-mode dialogue resolver. Run headless:
#   godot --headless --path artea --script res://scripts/test_audience_resolver.gd
#
# Checks the resolver's rules against the real dialogue file.
#
# GameManager itself is deliberately NOT instantiated here: it preloads
# dialogue_ui.tscn and loading_scene.tscn, which reference the GameManager and
# MusicManager singletons by name, and those singletons do not exist in a
# --script run. Booting the full autoload set instead pulls in Firebase and
# audio and never finishes (the same reason test_castle_universe.gd stalls).
#
# So this mirrors resolve_audience_node's rules over the same parsed data.
# test_audience_mode.gd asserts the file has the twins; this asserts the
# redirect logic over them is correct. If resolve_audience_node changes, the
# rules below must change with it.
extends SceneTree

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

var _mode := "faith"
var _dialogue_data := {}


func _init() -> void:
	_dialogue_data = _parse("res://dialogue/artea_park_dialogues.txt")
	assert(not _dialogue_data.is_empty(), "dialogue file parsed")

	var gm_source := FileAccess.get_file_as_string("res://scripts/GameManager.gd")
	assert(gm_source.contains("func resolve_audience_node"),
		"GameManager still defines resolve_audience_node")
	# run_dialogue is the chokepoint every jump and choice re-enters through.
	assert(gm_source.contains("node_name = resolve_audience_node(node_name)"),
		"run_dialogue still resolves the node it was handed")

	# --- faith mode is the default and changes nothing ---
	_mode = "faith"
	assert(_resolve("start_zephyr_dialogue") == "start_zephyr_dialogue",
		"faith mode plays the authored node")
	for node_name in _dialogue_data.keys():
		assert(_resolve(node_name) == node_name,
			"faith mode never redirects (%s)" % node_name)

	# --- universal mode redirects ---
	_mode = "universal"
	assert(_resolve("start_zephyr_dialogue") == "start_zephyr_dialogue_universal",
		"universal mode redirects")

	# Every redirect must land on a node that actually exists, or the
	# conversation dead-ends at "Node not found" in front of a child.
	for node_name in _dialogue_data.keys():
		var resolved: String = _resolve(node_name)
		assert(_dialogue_data.has(resolved),
			"resolved node %s exists for %s" % [resolved, node_name])

	# --- shared neutral nodes remain shared ---
	assert(_resolve("milo_stage_0") == "milo_stage_0",
		"Milo needs no twin and must not be redirected away")

	# --- missing required twins fail closed to reviewed neutral language ---
	var required := "start_zephyr_dialogue"
	var twin := required + UNIVERSAL_SUFFIX
	var saved_twin = _dialogue_data[twin]
	_dialogue_data.erase(twin)
	assert(_resolve(required) == UNIVERSAL_NEUTRAL_FALLBACK,
		"a missing inclusive required node uses neutral fallback, never faith text")
	_dialogue_data[twin] = saved_twin

	# --- already-universal nodes are not suffixed twice ---
	assert(_resolve("start_zephyr_dialogue_universal")
		== "start_zephyr_dialogue_universal", "no double suffix")

	# --- an unknown node stays unknown, in both modes ---
	assert(_resolve("no_such_node") == "no_such_node",
		"unknown nodes are passed through untouched")

	# --- choice targets resolve too, not just conversation openers ---
	# This is what run_dialogue() sees when the player picks an option; if it
	# did not resolve, the first line would be the Keeper and the rest angels.
	assert(_resolve("open_painting_tool") == "open_painting_tool_universal",
		"jump targets resolve")

	print("audience resolver: all checks passed")
	quit()


# Mirrors GameManager.resolve_audience_node.
func _resolve(node_name: String) -> String:
	if node_name.ends_with(UNIVERSAL_SUFFIX):
		return node_name
	if _mode != "universal":
		return node_name
	var universal := node_name + UNIVERSAL_SUFFIX
	if _dialogue_data.has(universal):
		return universal
	if node_name in UNIVERSAL_REQUIRED_NODES:
		return UNIVERSAL_NEUTRAL_FALLBACK
	return node_name


# Mirrors GameManager.load_dialogue_file's parsing rules.
func _parse(path: String) -> Dictionary:
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
