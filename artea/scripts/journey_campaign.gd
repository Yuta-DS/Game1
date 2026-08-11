# Canonical route and return context for the Crown of Life journey.
#
# This autoload deliberately owns no player progress or personal data. The
# existing JourneyState is still the only place a thought, emotion, artwork,
# strength, or treasure can be recorded. Campaign routing only asks whether a
# verified treasure has already been earned, then takes the player to the
# corresponding real kingdom and back to the Art Castle Galaxy.
extends Node

signal kingdom_entered(kingdom_id: String)
signal returned_to_castle

const CAMPAIGN_HOME_SCENE := "res://scenes/art_gallery_3d_inprogress.tscn"
const OPTIONAL_GUIDED_STORY_SCENE := "res://scenes/viewfinder/crown_of_life_story.tscn"
const QUEST_JOURNAL_SCENE := "res://scenes/crown_quest_journal.tscn"

const CAMPAIGN_ORDER := ["mind", "heart", "creator"]

# The three standalone experiences remain the canonical playable kingdoms.
# Do not replace these routes with the short Lens story: that story is a
# separate optional guided experience and must never fabricate mini-game data.
const KINGDOMS := {
	"mind": {
		"label": "Mind Spark Kingdom",
		"scene_path": "res://scenes/popThoughtsMenu.tscn",
		"treasure": "star_of_wisdom",
		"requires": [],
	},
	"heart": {
		"label": "Heart Melody Kingdom",
		"scene_path": "res://scenes/music_minigame.tscn",
		"treasure": "harmony_jewel",
		"requires": ["star_of_wisdom"],
	},
	"creator": {
		"label": "Creator's Light Kingdom",
		"scene_path": "res://scenes/drawing_tool.tscn",
		"treasure": "creators_light",
		"requires": ["star_of_wisdom", "harmony_jewel"],
	},
}

# Runtime-only context. It is intentionally not written to the journey save:
# closing the game should return a player to the Castle, never resume a scene
# or infer an unfinished reflection.
var active_kingdom_id := ""

# Tests and local harnesses can inject an isolated JourneyState instance. At
# runtime this remains null and the autoload resolves /root/JourneyState.
var journey_state: Node = null


func get_kingdom(kingdom_id: String) -> Dictionary:
	var kingdom: Variant = KINGDOMS.get(kingdom_id, {})
	return kingdom.duplicate(true) if kingdom is Dictionary else {}


func kingdom_scene_path(kingdom_id: String) -> String:
	return str(get_kingdom(kingdom_id).get("scene_path", ""))


func can_enter_kingdom(kingdom_id: String) -> bool:
	return can_enter_kingdom_with(kingdom_id, _journey_state())


# Pure route policy seam. It never calls JourneyState mutators, so tests can
# prove that navigation itself cannot award a treasure or invent a reflection.
func can_enter_kingdom_with(kingdom_id: String, state: Node = null) -> bool:
	var kingdom := get_kingdom(kingdom_id)
	if kingdom.is_empty():
		return false
	for treasure_id in kingdom.get("requires", []):
		if state == null or not state.has_method("has_treasure"):
			return false
		if not bool(state.call("has_treasure", str(treasure_id))):
			return false
	return true


func is_kingdom_complete(kingdom_id: String, state: Node = null) -> bool:
	if state == null:
		state = _journey_state()
	var kingdom := get_kingdom(kingdom_id)
	var treasure_id := str(kingdom.get("treasure", ""))
	if treasure_id.is_empty() or state == null or not state.has_method("has_treasure"):
		return false
	return bool(state.call("has_treasure", treasure_id))


func next_kingdom_id(state: Node = null) -> String:
	if state == null:
		state = _journey_state()
	for kingdom_id in CAMPAIGN_ORDER:
		if not is_kingdom_complete(kingdom_id, state):
			return kingdom_id
	return ""


func portal_status(kingdom_id: String) -> String:
	var kingdom := get_kingdom(kingdom_id)
	if kingdom.is_empty():
		return "CROWN JOURNEY\nROUTE UNAVAILABLE"
	var state := _journey_state()
	if is_kingdom_complete(kingdom_id, state):
		return "CROWN JOURNEY\nREVISIT %s" % str(kingdom["label"]).to_upper()
	if can_enter_kingdom_with(kingdom_id, state):
		return "CROWN JOURNEY\nENTER %s" % str(kingdom["label"]).to_upper()
	var next_id := next_kingdom_id(state)
	var next_label := str(get_kingdom(next_id).get("label", "the next light"))
	return "CROWN JOURNEY\nFOLLOW THE LIGHT TO %s" % next_label.to_upper()


func enter_kingdom(kingdom_id: String, scene_tree: SceneTree = null) -> bool:
	if not can_enter_kingdom(kingdom_id):
		return false
	var scene_path := kingdom_scene_path(kingdom_id)
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_error("JourneyCampaign: missing kingdom scene for %s" % kingdom_id)
		return false
	var tree := _scene_tree(scene_tree)
	if tree == null:
		return false
	var result := tree.change_scene_to_file(scene_path)
	if result != OK:
		push_error("JourneyCampaign: could not enter %s" % kingdom_id)
		return false
	active_kingdom_id = kingdom_id
	kingdom_entered.emit(kingdom_id)
	return true


func start_campaign(scene_tree: SceneTree = null) -> bool:
	active_kingdom_id = ""
	return _change_scene(CAMPAIGN_HOME_SCENE, scene_tree)


func return_to_campaign(scene_tree: SceneTree = null) -> bool:
	active_kingdom_id = ""
	var returned := _change_scene(CAMPAIGN_HOME_SCENE, scene_tree)
	if returned:
		returned_to_castle.emit()
	return returned


func open_quest_journal(scene_tree: SceneTree = null) -> bool:
	return _change_scene(QUEST_JOURNAL_SCENE, scene_tree)


# Retained as an explicit route for an eventual quest-journal entry. The hub
# portal starts the connected campaign; it no longer hides it behind a parallel
# simplified path.
func open_guided_lens_story(scene_tree: SceneTree = null) -> bool:
	return _change_scene(OPTIONAL_GUIDED_STORY_SCENE, scene_tree)


func _change_scene(scene_path: String, scene_tree: SceneTree = null) -> bool:
	if not ResourceLoader.exists(scene_path):
		push_error("JourneyCampaign: missing scene %s" % scene_path)
		return false
	var tree := _scene_tree(scene_tree)
	if tree == null:
		return false
	return tree.change_scene_to_file(scene_path) == OK


func _scene_tree(scene_tree: SceneTree) -> SceneTree:
	return scene_tree if scene_tree != null else get_tree()


func _journey_state() -> Node:
	if is_instance_valid(journey_state):
		return journey_state
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/JourneyState")
