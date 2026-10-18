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
	if pack_needed(scene_path) != "":
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
	return ResourceLoader.exists(scene_path) or pack_needed(scene_path) != ""


## The Pack file `scene_path` is waiting on (ADR-0001), or "" when it can load
## now: it is in Core, its Pack is already mounted, or the build has no Packs.
static func pack_needed(scene_path: String) -> String:
	if ResourceLoader.exists(scene_path) or not FileAccess.file_exists(PACK_MANIFEST):
		return ""
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(PACK_MANIFEST))
	if manifest is Dictionary:
		for pack in manifest.values():
			if scene_path in pack.entries:
				return pack.file
	return ""


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
