# Every res:// scene path written in GDScript must point at a file that exists.
#   godot --headless --path artea --script res://scripts/test_scene_paths.gd
#
# This class of bug is invisible until a player hits it, and it fails quietly:
# change_scene_to_file() on a missing path logs and does nothing, so the button
# simply appears dead. Four of these were live at once — the start screen, both
# post-login paths, and the gallery doorway — which between them made the hub
# world unreachable from a normal start.
#
# Scanning source rather than listing known paths, so a new bad path is caught
# without anyone remembering to add it here.
extends SceneTree

const SCAN_DIRS := ["res://scripts", "res://scenes"]

# Commented-out lines are not live code, and a path inside a comment is not a
# bug. Everything else is fair game.
const SCENE_PATTERN := "res://[^\"']+\\.tscn"


func _init() -> void:
	var offenders: Array[String] = []
	var checked := 0

	for dir in SCAN_DIRS:
		checked += _scan(dir, offenders)

	assert(checked > 0, "the scan actually read some scripts")

	assert(offenders.is_empty(),
		"every scene path in code must resolve to a real file, but these do "
		+ "not:\n  " + "\n  ".join(offenders))

	# The entry path into the game, specifically. This is the one that made
	# everything downstream — including the Lens of Seeing — unreachable.
	for path in [
		"res://scenes/New_Hub_World.tscn",
		"res://scenes/start_screen.tscn",
		"res://scenes/authentication.tscn",
	]:
		assert(ResourceLoader.exists(path), "%s exists" % path)

	print("scene paths: all checks passed (%d scripts scanned)" % checked)
	quit()


func _scan(dir_path: String, offenders: Array[String]) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0

	var count := 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				count += _scan(full, offenders)
		elif entry.ends_with(".gd"):
			count += 1
			_check_file(full, offenders)
		entry = dir.get_next()
	dir.list_dir_end()
	return count


func _check_file(path: String, offenders: Array[String]) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		return

	var regex := RegEx.new()
	regex.compile(SCENE_PATTERN)

	var line_number := 0
	for line in source.split("\n"):
		line_number += 1
		var trimmed := line.strip_edges()
		# Skip comments: a dead path in a commented-out line is not a bug the
		# player can hit.
		if trimmed.begins_with("#"):
			continue

		for found in regex.search_all(line):
			var scene_path := found.get_string()
			# Formatted templates are completed at runtime and are not literal
			# resource paths. Their concrete variants have their own fixtures.
			if scene_path.contains("%"):
				continue
			if not ResourceLoader.exists(scene_path):
				offenders.append("%s:%d -> %s" % [path, line_number, scene_path])
