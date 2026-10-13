extends SceneTree

# Lists every scripted line Milo can say in the chat panel, with the file name
# milo_animations.gd looks for, so they can be recorded in his greeting voice.
# Run: godot --headless --path artea --script res://tools/list_milo_lines.gd
# Writes assets/audio/milo/lines/milo_lines_to_record.tsv. Save each recording
# as assets/audio/milo/lines/<file> (Ogg Vorbis) and it plays instead of TTS.

const ChatbotScene := preload("res://scenes/chatbot.tscn")
const Milo := preload("res://scripts/milo_animations.gd")
const OUT := "res://assets/audio/milo/lines/milo_lines_to_record.tsv"
# Main menu -> strength finder -> five answers -> Try other worlds is deepest.
const MAX_DEPTH := 7


class FakeCampaign extends Node:
	func next_kingdom_id() -> String:
		return "mind"

	func enter_kingdom(_id: String, _tree: SceneTree = null) -> bool:
		return true

	func start_campaign() -> bool:
		return true


var _lines := {}
var _last := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var chat := ChatbotScene.instantiate()
	chat.campaign_router = FakeCampaign.new()
	root.add_child(chat.campaign_router)
	root.add_child(chat)
	await process_frame
	chat.companion_speech_requested.connect(_on_speech)
	await _walk(chat)
	# The hub's castle door adds "Try other worlds" and longer reveal lines, so
	# walk again with a stand-in door (chat._castle_door() looks it up by name).
	var hub := Node3D.new()
	var door := Area3D.new()
	door.name = chat.CASTLE_DOOR_NODE
	hub.add_child(door)
	root.add_child(hub)
	current_scene = hub
	await _walk(chat)
	var fake = chat.campaign_router
	# "Path unavailable" only shows with no campaign at all, so hide the
	# JourneyCampaign autoload that chat._campaign() falls back to.
	chat.campaign_router = null
	var autoload := root.get_node_or_null("JourneyCampaign")
	if autoload != null:
		autoload.name = "JourneyCampaignHidden"
	chat._travel_to_activity("mind")
	if autoload != null:
		autoload.name = "JourneyCampaign"
	chat.campaign_router = fake
	# The main menu's title is the only reachable line that varies by stage.
	for stage in chat.CURATED_REFLECTIONS:
		chat._stage = stage
		chat._show_choices()
	var keys := _lines.keys()
	keys.sort()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_line("file\tline")
	for spoken in keys:
		f.store_line("%s\t%s" % [Milo.recorded_line_path(spoken).get_file(), spoken])
	f.close()
	assert(keys.size() > 10, "the walk should reach the scripted menus")
	print("MILO_LINES: %d lines -> %s" % [keys.size(), OUT])
	quit()


func _on_speech(text: String) -> void:
	_last = text
	_lines[Milo._spoken_version(text)] = true


# Breadth-first walk over the choice buttons, replaying each path from the
# main menu so button callbacks see the same state a player would.
func _walk(chat: Control) -> void:
	var queue: Array = [[]]
	var seen := {}
	while not queue.is_empty():
		var path: Array = queue.pop_front()
		chat._strength_tally.clear()
		chat._strength_question_index = 0
		chat._show_choices()
		for label in path:
			var button := _button(chat, label)
			if button == null:
				break
			button.pressed.emit()
		var labels := _labels(chat)
		var tally: Array = chat.STRENGTHS.keys().map(
			func(k): return chat._strength_tally.get(k, 0))
		var key := "%s|%s|%s" % [_last, ",".join(labels), tally]
		if path.size() < MAX_DEPTH and not seen.has(key):
			seen[key] = true
			for label in labels:
				queue.append(path + [label])
		await process_frame  # let queue_free() clear the old buttons


func _choices(chat: Control) -> Node:
	return chat.get_node("Panel/VBoxContainer/ChoicesScroll/CuratedChoices")


# Close, travel, and free-text input never lead to more scripted lines.
func _labels(chat: Control) -> Array:
	var labels := []
	for child in _choices(chat).get_children():
		if child is Button and child.text != "Close" \
				and not child.name.begins_with("MiloTravel_"):
			labels.append(child.text)
	return labels


func _button(chat: Control, label: String) -> Button:
	for child in _choices(chat).get_children():
		if child is Button and child.text == label:
			return child
	return null
