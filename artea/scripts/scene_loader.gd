extends RefCounted

## Shared "swap scenes behind the loading screen" helper.
##
## change_scene_to_file() parses and builds the entire target scene
## synchronously, so the game sits frozen on its last rendered frame until
## that finishes. For the Art Castle that is several seconds with nothing on
## screen to show the game is still alive, which reads as a crash.
## loading_scene.gd already threads the load behind a progress bar, so every
## route into a heavy scene goes through here instead of swapping directly.
##
## Callers preload this script as a const rather than reaching it through an
## autoload or a class_name: the headless `--script` test harnesses run
## without the project's autoloads registered, and without the
## editor-generated global class cache, so either of those would stop the
## calling scripts from compiling there.

const LOADING_SCENE = "res://scenes/loading_scene.tscn"


static func change_scene_with_loading(tree: SceneTree, scene_path: String) -> bool:
	if tree == null:
		return false
	if not ResourceLoader.exists(scene_path):
		push_error("SceneLoader: cannot load missing scene %s" % scene_path)
		return false
	# Loaded at call time, not preloaded: loading_scene.gd references the
	# MusicManager autoload, so compiling it early would break any caller that
	# is itself compiled before the autoloads exist.
	var packed := load(LOADING_SCENE) as PackedScene
	if packed == null:
		push_warning("SceneLoader: loading screen unavailable, swapping to %s directly" % scene_path)
		return tree.change_scene_to_file(scene_path) == OK
	var loading_screen := packed.instantiate()
	loading_screen.next_scene_path = scene_path
	tree.root.add_child(loading_screen)
	# The loading screen lives under root, so freeing the outgoing scene here
	# leaves it on screen driving the threaded load.
	if tree.current_scene != null:
		tree.current_scene.queue_free()
	return true
