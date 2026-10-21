extends Node3D

# Connects the large explorable regions to the canonical Crown of Life
# activities. Exploration records runtime checkpoints only; JourneyState and
# JourneyCampaign remain the sole authorities for earned treasures.

const INTERACTION_RANGE := 75.0
# Mind's story checkpoints lived in its old 3 km region, which was removed;
# Mind Spark's story now runs in World One.
const KINGDOM_ORDER := ["heart", "creator"]
const INTRO_LINES := {
	"heart": "Raphael: Every feeling needs a safe place in the music.",
	"creator": "Uriel: Make one small mark, and the world will answer.",
}
const COMPLETION_LINES := {
	"heart": "Your emotion sounds are ready to become a Personal Song. Enter the activity to discover the Harmony Jewel.",
	"creator": "Your unfinished picture is enough to begin. Enter the activity to discover the Creator's Light.",
}

var _regions: Node3D
var _player: CharacterBody3D
var _routes: Dictionary = {}
var _progress := {"heart": 0, "creator": 0}
var _active_kingdom := ""
var _prompt: Label
var _story: Label


func _ready() -> void:
	_regions = get_node_or_null("../KingdomRegions3000m") as Node3D
	_player = get_node_or_null("../../Player3D") as CharacterBody3D
	if _regions == null:
		push_warning("ConnectedKingdomStory: 3000m kingdom regions are unavailable")
		return
	for kingdom_id in KINGDOM_ORDER:
		_routes[kingdom_id] = _regions.call("get_story_route", kingdom_id)
	_build_hud()


func _process(_delta: float) -> void:
	if _player == null or _regions == null:
		return
	_active_kingdom = _closest_kingdom()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if _active_kingdom.is_empty() or _player == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		var expected := int(_progress[_active_kingdom])
		var route: Array = _routes[_active_kingdom]
		if expected >= route.size():
			return
		var checkpoint: Dictionary = route[expected]
		if _distance_to(checkpoint.position) <= INTERACTION_RANGE:
			_activate_checkpoint(_active_kingdom, expected)
			get_viewport().set_input_as_handled()


func get_progress(kingdom_id: String) -> int:
	return int(_progress.get(kingdom_id, 0))


func get_checkpoint_count(kingdom_id: String) -> int:
	return (_routes.get(kingdom_id, []) as Array).size()


func can_activate_checkpoint(kingdom_id: String, checkpoint_index: int) -> bool:
	return KINGDOM_ORDER.has(kingdom_id) and checkpoint_index == int(_progress.get(kingdom_id, -1)) \
		and checkpoint_index < get_checkpoint_count(kingdom_id)


func story_is_connected() -> bool:
	return get_checkpoint_count("heart") == 8 and get_checkpoint_count("creator") == 8


func _closest_kingdom() -> String:
	var best_id := ""
	var best_distance := INF
	var centers: Dictionary = _regions.call("get_kingdom_centers")
	for kingdom_id in KINGDOM_ORDER:
		var distance := _distance_to(centers[kingdom_id])
		if distance < 1650.0 and distance < best_distance:
			best_distance = distance
			best_id = kingdom_id
	return best_id


func _update_hud() -> void:
	if _prompt == null:
		return
	if _active_kingdom.is_empty():
		_prompt.text = "CROWN JOURNEY • Ride the Rainbow Galaxy Train to a kingdom"
		_story.text = "Mind → Heart → Creator → Crown of Life"
		return
	var route: Array = _routes[_active_kingdom]
	var expected := int(_progress[_active_kingdom])
	if expected >= route.size():
		_prompt.text = "SANCTUARY READY • The story activity awaits"
		_story.text = COMPLETION_LINES[_active_kingdom]
		return
	var checkpoint: Dictionary = route[expected]
	var close := _distance_to(checkpoint.position) <= INTERACTION_RANGE
	_prompt.text = ("Q • DISCOVER " if close else "FOLLOW THE GLOWING STORY PATH TO ") + str(checkpoint.title)
	_story.text = INTRO_LINES[_active_kingdom] if expected == 0 else \
		"Chapter %d of %d • %s" % [expected + 1, route.size(), checkpoint.title]


func _activate_checkpoint(kingdom_id: String, checkpoint_index: int) -> void:
	if not can_activate_checkpoint(kingdom_id, checkpoint_index):
		return
	var route: Array = _routes[kingdom_id]
	var checkpoint: Dictionary = route[checkpoint_index]
	_progress[kingdom_id] = checkpoint_index + 1
	_illuminate_checkpoint(kingdom_id, checkpoint_index)
	if checkpoint_index == route.size() - 1:
		_story.text = COMPLETION_LINES[kingdom_id]
		_launch_canonical_activity.call_deferred(kingdom_id)
	else:
		_story.text = "Discovered: %s • The next light has awakened." % checkpoint.title


func _launch_canonical_activity(kingdom_id: String) -> void:
	var campaign := get_node_or_null("/root/JourneyCampaign")
	if campaign != null and campaign.has_method("enter_kingdom"):
		campaign.call("enter_kingdom", kingdom_id)


func _illuminate_checkpoint(kingdom_id: String, checkpoint_index: int) -> void:
	var kingdom_root := _regions.get_node_or_null("%sKingdom3000m" % kingdom_id.to_pascal_case())
	if kingdom_root == null:
		return
	var checkpoint := kingdom_root.get_node_or_null("StoryCheckpoint_%02d_%s" % [checkpoint_index + 1,
		str((_routes[kingdom_id] as Array)[checkpoint_index].id)]) as Node3D
	if checkpoint == null:
		return
	var light := OmniLight3D.new()
	light.name = "DiscoveredStoryLight"
	light.position = Vector3(0, 28, 0)
	light.light_color = Color("fff0a8")
	light.light_energy = 8.0
	light.omni_range = 95.0
	checkpoint.add_child(light)


func _distance_to(local_position: Vector3) -> float:
	return _player.global_position.distance_to(get_parent().to_global(local_position))


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ConnectedStoryHUD"
	add_child(canvas)
	# Story state remains available to the quest journal and world interactions,
	# but no longer draws a second large text panel over the left of gameplay.
	_prompt = Label.new()
	_prompt.name = "HiddenStoryPrompt"
	_prompt.visible = false
	canvas.add_child(_prompt)
	_story = Label.new()
	_story.name = "HiddenStoryStatus"
	_story.visible = false
	canvas.add_child(_story)
