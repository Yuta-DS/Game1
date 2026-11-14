extends RefCounted

## The one way into another scene.
##
## Every route into a scene outside the Core pack comes through here, so there
## is a single place to ask "is that scene's Pack here yet?" once the Web build
## is split into Packs (ADR-0001). test_scene_swaps_use_loader.gd fails on any
## new direct swap.
##
## change_scene_with_loading() is for heavy scenes. change_scene_to_file()
## parses and builds the entire target scene synchronously, so the game sits
## frozen on its last rendered frame until that finishes. For the Art Castle
## that is several seconds with nothing on screen to show the game is still
## alive, which reads as a crash. loading_scene.gd threads the load behind a
## progress bar instead. change_scene() swaps directly, for light scenes where a
## loading screen would only flash.
##
## A failed switch is logged and shown on screen (report_failure). In a browser
## the log is invisible, so a failure used to look like the game hanging
## (web.txt Problem 4).
##
## Callers preload this script as a const rather than reaching it through an
## autoload or a class_name: the headless `--script` test harnesses run
## without the project's autoloads registered, and without the
## editor-generated global class cache, so either of those would stop the
## calling scripts from compiling there.

const LOADING_SCENE = "res://scenes/loading_scene.tscn"
# Written into Web builds by tools/export-web-packs.sh: which entry scenes live
# in which area Pack. Desktop builds and the editor have no file and no Packs.
const PACK_MANIFEST := "res://packs.json"
# Above every HUD layer (the highest is 100) so the incoming scene's minimap
# and inventory icons can't draw over the loading screen before it is ready,
# and below the failure message (128).
const LOADING_LAYER := 120
const FAILURE_MESSAGE_SECONDS := 8.0
const FAILURE_GROUP := "scene_switch_failed"


static func change_scene(tree: SceneTree, scene_path: String) -> bool:
	if tree == null:
		return false
	# A scene whose Pack has not been fetched yet needs the loading screen to
	# download it, however light the scene itself is.
	if not packs_needed(scene_path).is_empty():
		return change_scene_with_loading(tree, scene_path)
	if not ResourceLoader.exists(scene_path):
		report_failure(tree, scene_path, "scene file missing")
		return false
	var err := tree.change_scene_to_file(scene_path)
	if err != OK:
		report_failure(tree, scene_path, error_string(err))
		return false
	return true


static func change_scene_with_loading(tree: SceneTree, scene_path: String) -> bool:
	if tree == null:
		return false
	if not can_open(scene_path):
		report_failure(tree, scene_path, "scene file missing")
		return false
	# Loaded at call time, not preloaded: loading_scene.gd references the
	# MusicManager autoload, so compiling it early would break any caller that
	# is itself compiled before the autoloads exist.
	var packed := load(LOADING_SCENE) as PackedScene
	if packed == null:
		push_warning("SceneLoader: loading screen unavailable, swapping to %s directly" % scene_path)
		return change_scene(tree, scene_path)
	var loading_screen := packed.instantiate()
	loading_screen.next_scene_path = scene_path
	var layer := CanvasLayer.new()
	layer.name = "LoadingLayer"
	layer.layer = LOADING_LAYER
	layer.add_child(loading_screen)
	loading_screen.tree_exited.connect(layer.queue_free)
	tree.root.add_child(layer)
	# The loading screen lives under root, so freeing the outgoing scene here
	# leaves it on screen driving the threaded load.
	if tree.current_scene != null:
		tree.current_scene.queue_free()
	return true


## Whether `scene_path` can be opened: it is here, or its Pack can be fetched.
## Use this, not ResourceLoader.exists, to decide whether a route is open: a
## Pack's scenes do not exist until the loading screen has fetched the Pack.
static func can_open(scene_path: String) -> bool:
	return ResourceLoader.exists(scene_path) or not packs_needed(scene_path).is_empty()


## The Pack files `scene_path` is waiting on (ADR-0001), in mounting order;
## empty when it can load now: it is in Core, its Pack is already mounted, or
## the build has no Packs.
static func packs_needed(scene_path: String) -> PackedStringArray:
	var needed := PackedStringArray()
	if ResourceLoader.exists(scene_path) or not FileAccess.file_exists(PACK_MANIFEST):
		return needed
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(PACK_MANIFEST))
	if not manifest is Dictionary:
		return needed
	for pack in manifest.values():
		if scene_path in pack.entries:
			# Shared packs first: the area's own files depend on them. One
			# mounted along with another area already is not fetched again.
			for shared in pack.requires:
				var probe: String = manifest[shared].probe
				if not ResourceLoader.exists(probe) and not FileAccess.file_exists(probe):
					needed.append(manifest[shared].file)
			needed.append(pack.file)
	return needed


## Downloads one Pack file through the page's loader (arteaPacks, in
## pck-loader.js) and mounts it. `on_progress(loaded, total)` is called while it
## downloads. Returns "" once mounted, or why not. Web only: other builds have
## no Packs, so packs_needed never asks for one.
static func fetch_pack(tree: SceneTree, file: String, on_progress := Callable()) -> String:
	var local := "/tmp/artea_packs/" + file
	var key := JSON.stringify(file)
	JavaScriptBridge.eval("arteaPacks.fetch(%s, %s)" % [key, JSON.stringify(local)])
	while true:
		var state = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(arteaPacks.state[%s])" % key)))
		if not state is Dictionary or state.error != "":
			return "download failed: %s" % (state.error if state is Dictionary else "no loader")
		if state.done:
			break
		if state.total > 0 and on_progress.is_valid():
			on_progress.call(float(state.loaded), float(state.total))
		await tree.process_frame
	if not ProjectSettings.load_resource_pack(local):
		return "couldn't open the downloaded %s" % file
	return ""


## Mounts whatever Packs `scene_path` is waiting on, for a scene opened inside
## the current one instead of through the loading screen (the Creator studio's
## easels open the drawing tool, which lives in the creators_light Pack).
## Returns "" once it can be loaded, or why not.
static func mount_packs_for(tree: SceneTree, scene_path: String, on_progress := Callable()) -> String:
	for file in packs_needed(scene_path):
		var error: String = await fetch_pack(tree, file, on_progress)
		if not error.is_empty():
			return error
	return ""


## Every Pack file not yet mounted, most likely needed first, for downloading
## in the background once the Hub is playable (issue #38). The journey decides
## the order: the Art Castle, where the campaign goes from the Hub; then the
## Kingdoms in campaign order, from the player's next unfinished one; then the
## optional Crown of Life story; then any other area. Each area's Shared packs
## come just before it.
static func prefetch_order(tree: SceneTree) -> PackedStringArray:
	var scenes: Array[String] = []
	var campaign := tree.root.get_node_or_null("/root/JourneyCampaign")
	if campaign != null:
		var journey: Dictionary = campaign.get_script().get_script_constant_map()
		scenes.append(journey.CAMPAIGN_HOME_SCENE)
		var kingdoms: Array = journey.CAMPAIGN_ORDER
		var next := maxi(0, kingdoms.find(campaign.call("next_kingdom_id")))
		for i in kingdoms.size():
			scenes.append(campaign.call("kingdom_scene_path", kingdoms[(next + i) % kingdoms.size()]))
		scenes.append(journey.OPTIONAL_GUIDED_STORY_SCENE)
	if FileAccess.file_exists(PACK_MANIFEST):
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(PACK_MANIFEST))
		for pack in (manifest.values() if manifest is Dictionary else []):
			scenes.append_array(pack.entries)
	var order := PackedStringArray()
	for scene in scenes:
		for file in packs_needed(scene):
			if not file in order:
				order.append(file)
	return order


## Logs a scene switch that failed and puts a message on screen for a while.
## The message hangs off the root, so it stays up whichever scene is showing.
static func report_failure(tree: SceneTree, scene_path: String, reason: String) -> void:
	push_error("SceneLoader: could not open %s (%s)" % [scene_path, reason])
	if tree == null or tree.root == null:
		return
	# One message at a time: a newer failure replaces the one on screen.
	for old in tree.get_nodes_in_group(FAILURE_GROUP):
		old.queue_free()
	var layer := CanvasLayer.new()
	layer.name = "SceneSwitchFailed"
	layer.add_to_group(FAILURE_GROUP)
	layer.layer = 128
	var label := Label.new()
	label.text = "Couldn't open %s. Please try again." % scene_path.get_file().get_basename()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.05, 0.05, 0.85)
	panel.set_content_margin_all(12.0)
	panel.set_corner_radius_all(6)
	label.add_theme_stylebox_override("normal", panel)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.position.y = 24.0
	layer.add_child(label)
	# Deferred: a failure can be reported while the tree is busy adding or
	# removing nodes (from a _ready() or a body_entered signal).
	tree.root.add_child.call_deferred(layer)
	tree.create_timer(FAILURE_MESSAGE_SECONDS).timeout.connect(layer.queue_free)
