# Self-check for the journey's UI safeguards and the hub creation easels.
# Run headless:
#   godot --headless --script res://scripts/test_journey_ui.gd
#
# These three scripts build their UI in code and are the parts a player's
# safety depends on, so they are worth testing without a running game.
extends SceneTree

const SupportCard := preload("res://scripts/support_card.gd")
const JourneyPrivacy := preload("res://scripts/journey_privacy.gd")
const HubCreations := preload("res://scripts/hub_creations.gd")

var _failures := 0

# The real journey.json, stashed while the tests scribble over it.
var _saved_journey := ""


func _init() -> void:
	# Nodes added during _init() do not run _ready() until the tree processes
	# a frame, and every script here builds its UI in _ready().
	await process_frame

	_stash_real_journey()

	await _test_support_card()
	await _test_privacy_panel()
	_test_easel_spots()
	await _test_creations_spawn()

	_restore_real_journey()

	if _failures > 0:
		push_error("journey UI: %d check(s) failed" % _failures)
		quit(1)
		return

	print("journey UI: all checks passed")
	quit()


# These tests drive the real JourneyState autoload, because that is what the
# panels resolve through /root/JourneyState — a locally constructed instance
# gets renamed by the autoload's name and is never seen. That means the tests
# write to the real save file, so it is stashed and put back afterwards.
func _stash_real_journey() -> void:
	var path: String = load("res://scripts/JourneyState.gd").new().SAVE_PATH
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null:
		_saved_journey = file.get_as_text()


func _restore_real_journey() -> void:
	var js := _journey()
	if js:
		js.clear_journey()

	if _saved_journey.is_empty():
		return

	var path: String = js.SAVE_PATH if js else "user://journey.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(_saved_journey)


func _journey() -> Node:
	return root.get_node_or_null("/root/JourneyState")


func _check(condition: bool, what: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAILED: %s" % what)


# --- support card ----------------------------------------------------

func _test_support_card() -> void:
	# Every listed resource needs all four fields — a row missing its number
	# is the exact failure that matters here.
	for r in SupportCard.RESOURCES:
		for key in ["region", "name", "contact", "note"]:
			_check(r.has(key) and not str(r[key]).strip_edges().is_empty(),
				"resource '%s' has non-empty %s" % [r.get("name", "?"), key])

	_check(SupportCard.RESOURCES.size() >= 2, "more than one region covered")

	# The card must say plainly that the game is not a therapist.
	_check(SupportCard.INTRO.to_lower().contains("not a therapist"),
		"intro disclaims being a therapist")

	var card = SupportCard.new()
	root.add_child(card)
	await process_frame

	# Starts hidden, opens on request. A card that renders on boot would
	# ambush every player.
	var layer: CanvasLayer = _find_child_of_type(card, "CanvasLayer")
	_check(layer != null, "support card built a CanvasLayer")
	if layer:
		_check(not layer.visible, "support card starts hidden")
		card.show_card()
		_check(layer.visible, "show_card() reveals it")
		# Sits above the ceremony panel (layer 10) so nothing covers it.
		_check(layer.layer > 10, "support card renders above the ceremony")

	card.free()


# --- privacy panel ---------------------------------------------------

func _test_privacy_panel() -> void:
	var js = _journey()
	_check(js != null, "JourneyState autoload is available")
	if js == null:
		return
	js.clear_journey()

	var panel = JourneyPrivacy.new()
	root.add_child(panel)
	await process_frame

	var layer: CanvasLayer = _find_child_of_type(panel, "CanvasLayer")
	_check(layer != null, "privacy panel built a CanvasLayer")
	if layer:
		_check(not layer.visible, "privacy panel starts hidden")

	# Empty journey: nothing to erase, so the button is not offered.
	panel.show_panel()
	_check(panel._delete_button.disabled, "erase disabled with empty journey")
	_check(panel._summary.text.contains("not remembering"),
		"empty journey says so plainly")

	# With a journey, the summary counts what is held — and never quotes the
	# thought text back at the player.
	js.record_thought("I'm not good enough")
	js.mark_popped("I'm not good enough")
	js.record_emotion("sad", Color(0.2, 0.4, 0.9))
	panel.show_panel()

	_check(not panel._delete_button.disabled, "erase enabled once there is a journey")
	_check(panel._summary.text.contains("1 thought you wrote"),
		"singular thought is not '1 thoughts'")
	_check(not panel._summary.text.contains("not good enough"),
		"summary never re-displays the player's thought text")

	# Confirmation is required, and only the confirm button actually erases.
	_check(not panel._confirm_box.visible, "confirmation hidden until asked")
	panel._on_delete_pressed()
	_check(panel._confirm_box.visible, "delete press asks for confirmation")

	panel._on_cancel_pressed()
	_check(js.has_journey(), "cancelling keeps the journey")

	panel._on_delete_pressed()
	panel._on_confirm_pressed()
	_check(not js.has_journey(), "confirming erases the journey")
	_check(js.stage == 0, "erasing resets the stage")
	_check(panel._status.text == JourneyPrivacy.DONE, "erasure is confirmed to the player")

	panel.free()
	js.clear_journey()


# --- hub easels ------------------------------------------------------

func _test_easel_spots() -> void:
	# Spots are offsets from Milo's plaza. The hub's ground sits well above
	# Y=0, so an anchor at origin height would bury every canvas.
	_check(HubCreations.ANCHOR.y > 1.0, "easel anchor is at village ground height")

	var seen := {}
	for spot in HubCreations.EASEL_SPOTS:
		_check(spot.has("offset") and spot.has("yaw"), "spot has offset and yaw")
		var key := str(spot["offset"])
		_check(not seen.has(key), "no two easels share a position")
		seen[key] = true


# Creations whose PNG is gone must be skipped, not crash the hub.
func _test_creations_spawn() -> void:
	var js = _journey()
	if js == null:
		return
	js.clear_journey()

	var real_path := "user://test_easel.png"
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.3, 0.4))
	_check(image.save_png(real_path) == OK, "test artwork written")

	js.record_creation(real_path, "storm")
	js.record_creation("user://gone_missing.png", "deleted by the player")

	var host := Node3D.new()
	root.add_child(host)
	var spawner = HubCreations.new()
	host.add_child(spawner)

	# _ready() awaits a frame before spawning.
	await process_frame
	await process_frame

	var holder := host.get_node_or_null("PlayerCreations")
	_check(holder != null, "spawner added a PlayerCreations holder")
	if holder:
		_check(holder.get_child_count() == 1,
			"only the creation whose file exists is raised (got %d)"
			% holder.get_child_count())
		_check(holder.find_child("EnterArtworkWorld", true, false) != null,
			"each player-created castle easel can open its semantic 3D world")

	host.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(real_path))
	js.clear_journey()


func _find_child_of_type(node: Node, type_name: String) -> Node:
	for child in node.get_children():
		if child.is_class(type_name):
			return child
	return null
