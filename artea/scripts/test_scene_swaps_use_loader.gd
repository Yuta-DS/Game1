extends SceneTree

# Every route into a scene outside the Core pack goes through
# scripts/scene_loader.gd (issue #31), so once the Web build is split into
# Packs there is one place to check that a scene's Pack is here before
# switching. This fails on any shipped script that swaps scenes itself -
# change_scene_to_file/packed, or building the loading screen by hand - unless
# the target is a Core scene written out literally.

# The Core pack: start screen, auth, loading screen and HUD (CONTEXT.md).
const CORE_SCENES := [
	"res://scenes/start_screen.tscn",
	"res://scenes/game_start.tscn",
	"res://scenes/authentication.tscn",
	"res://scenes/loading_scene.tscn",
	"res://scenes/Control_HUD.tscn",
	"res://scenes/Icons_HUD.tscn",
]
const LOADER_SCRIPTS := ["res://scripts/scene_loader.gd", "res://scripts/loading_scene.gd"]
# Never shipped (mirrors the Web preset's exclude_filter).
const SKIP_DIRS := ["res://addons", "res://builds", "res://demo", "res://tools", "res://artifacts"]
const SKIP_PREFIXES := ["test_", "capture_", "probe_", "diag_"]

var _direct := RegEx.create_from_string(
	"(?:change_scene_to_(?:file|packed)|ChangeSceneTo(?:File|Packed))\\s*\\(\\s*(?:\"([^\"]*)\"|'([^']*)')?")
var _hand_built := RegEx.create_from_string("next_scene_path\\s*=|NextScenePath\\s*=")
var _violations: Array[String] = []


func _init() -> void:
	_scan("res://")
	if not _violations.is_empty():
		push_error("SCENE_SWAPS_USE_LOADER_TEST: %d direct scene swap(s) outside SceneLoader:\n  %s\nRoute them through SceneLoader.change_scene() or change_scene_with_loading()." % [
			_violations.size(), "\n  ".join(_violations)])
		quit(1)
		return
	print("SCENE_SWAPS_USE_LOADER_TEST: PASS - every scene swap outside the Core pack goes through SceneLoader")
	quit()


func _scan(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		var path := dir.path_join(sub)
		if not sub.begins_with(".") and path not in SKIP_DIRS:
			_scan(path)
	for file in DirAccess.get_files_at(dir):
		var path := dir.path_join(file)
		if (file.ends_with(".gd") or file.ends_with(".cs")) and path not in LOADER_SCRIPTS \
				and not SKIP_PREFIXES.any(func(p: String) -> bool: return file.begins_with(p)):
			_check(path)


func _check(path: String) -> void:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line.begins_with("#") or line.begins_with("//"):
			continue
		var found := _direct.search(line)
		if found != null:
			var target := found.get_string(1) + found.get_string(2)
			if target not in CORE_SCENES:
				_violations.append("%s:%d  %s" % [path, i + 1, line])
		elif _hand_built.search(line) != null:
			_violations.append("%s:%d  %s" % [path, i + 1, line])
