extends SceneTree

## Works out which files belong in an area's Pack (ADR-0001) and checks that
## every shipped reference resolves to some Pack.
##
##   godot --headless --path artea --script res://tools/pack_split.gd -- [--write] [out.json]
##
## --write is for export-web-packs.sh: it also writes res://packs.json (which
## scenes need which Pack, read by scene_loader.gd) and the presets the split
## exports with. Both are build output, put back or deleted after the export.
##
## A file goes in the Art Castle Pack only when the castle's entry scene reaches
## it and nothing in Core does. Core is everything else the Web preset ships,
## plus whatever that reaches. So a shared asset always stays in Core, and a
## castle file that Core starts using moves back to Core on the next build,
## without anyone editing a list.
##
## "Reaches" follows what the engine would actually load: ext_resources and
## preloads (ResourceLoader.get_dependencies), res:// paths written in code
## (load("res://...") strings), and class_name uses, whose script must be present
## for the using script to compile. Core naming the entry scene is not a
## dependency: that is a route into the castle, and the loader fetches the Pack
## before it follows one.
##
## Fails (exit 1) when a dependency points at a file no Pack ships: missing from
## the project, or left out by the preset's exclude_filter. That is web.txt
## Problem 1 (change_scene_to_packed receiving null in the browser) caught at
## build time instead. A path only written as a string is not checked: code
## often probes optional paths with ResourceLoader.exists first.

## Each Pack's entry scenes: the scenes the game routes into from outside it.
## ArtGallery.tscn and art_gallery_3d.tscn are the gallery's older hosts
## (painting_view.gd still returns to the first); they run the same
## art_gallery.gd and build the same galaxy, so they are castle entries too.
const PACKS := {
	"art_castle": [
		"res://scenes/art_gallery_3d_inprogress.tscn",
		"res://scenes/ArtGallery.tscn",
		"res://scenes/art_gallery_3d.tscn",
		# The galaxy on its own, for running it straight from the editor.
		"res://scenes/art_castle_floating_world.tscn",
	],
}
const WEB_PRESET := "Web"
const PRESETS_PATH := "res://export_presets.cfg"
const MANIFEST_PATH := "res://packs.json"
const TEXT_EXTENSIONS := ["gd", "tscn", "tres", "gdshader", "gdshaderinc"]
const SKIP_DIRS := [".godot", ".git", ".import"]

var _excludes: PackedStringArray = []
var _class_paths := {}  # class_name -> script path
var _edges := {}  # path -> {"deps": Array[String], "refs": Array[String]}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var write := args.has("--write")
	args.erase("--write")
	var out_path := args[0] if not args.is_empty() else ""
	_excludes = _preset_excludes()
	_load_class_paths()

	var shipped := {}
	_walk("res://", shipped)

	var errors: Array[String] = []
	var result := {"packs": {}}
	var boundary := {}
	for pack in PACKS:
		for entry in PACKS[pack]:
			boundary[entry] = true

	# Pass 1: what each Pack's entries reach that Core does not.
	var pack_reach := {}
	for pack in PACKS:
		pack_reach[pack] = _closure(PACKS[pack], {})
	var core := _core_closure(shipped, pack_reach, boundary)

	# Pass 2: files nothing outside their own folder uses (a GLB's leftover
	# extracted textures, a prototype scene and its model) are otherwise Core
	# roots of their own and ship in the first load. An area folder holding
	# Pack content that no Core file outside it reaches into goes to that Pack
	# whole.
	# ponytail: the area is the first two path segments (assets3D/tree_of_life);
	# a Core script building a path into such a folder at runtime would miss it.
	for pack in pack_reach:
		var areas := {}
		for path in pack_reach[pack]:
			if not core.has(path):
				areas[_area(path)] = true
		areas.erase("")
		for path in core:
			for target in _edges_of(path).deps + _edges_of(path).refs:
				if _area(target) != _area(path):
					areas.erase(_area(target))
		var extra: Array = []
		for path in core:
			if areas.has(_area(path)):
				extra.append(path)
		pack_reach[pack] = _closure(PACKS[pack] + extra, {})
	core = _core_closure(shipped, pack_reach, boundary)

	# PACK_WHY=res://a,res://b prints how Core reaches each file, for finding
	# what holds castle content in the first load.
	for probe in OS.get_environment("PACK_WHY").split(",", false):
		var chain := []
		var at := probe
		while at != "" and chain.size() < 40:
			chain.append(at)
			at = core.get(at, "")
		print("WHY ", " <- ".join(chain))

	for pack in pack_reach:
		var files: Array[String] = []
		for path in pack_reach[pack]:
			if not core.has(path):
				files.append(path)
		files.sort()
		result.packs[pack] = {"entries": PACKS[pack], "files": files}

	var core_files: Array = core.keys()
	core_files.sort()
	result["core"] = core_files

	# Every hard dependency of anything shipped must itself be shipped.
	var everything := core.duplicate()
	for pack in pack_reach:
		everything.merge(pack_reach[pack])
	for path in everything:
		for dep in _edges_of(path).deps:
			if not _exists(dep):
				errors.append("%s depends on %s, which does not exist" % [path, dep])
			elif _excluded(dep):
				errors.append("%s depends on %s, which the %s preset's exclude_filter leaves out of every Pack"
					% [path, dep, WEB_PRESET])
	errors.sort()
	result["errors"] = errors

	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t"))
	if write and errors.is_empty():
		_write_manifest(result.packs)
		_write_presets(result.packs)
	for pack in result.packs:
		print("PACK %s: %d files" % [pack, result.packs[pack].files.size()])
	for error in errors:
		printerr("PACK ERROR: " + error)
	quit(1 if not errors.is_empty() else 0)


## Core: the project file's paths, everything shipped that no Pack reaches, and
## all they reach. Maps each file to the one that reached it ("" for a root).
func _core_closure(shipped: Dictionary, pack_reach: Dictionary, boundary: Dictionary) -> Dictionary:
	var roots: Array[String] = _project_setting_paths()
	for path in shipped:
		var in_pack := false
		for pack in pack_reach:
			in_pack = in_pack or pack_reach[pack].has(path)
		if not in_pack:
			roots.append(path)
	return _closure(roots, boundary)


## The folder two levels down that a file sits in (assets3D/tree_of_life), or
## "" for a file nearer the root, which belongs to no area.
func _area(path: String) -> String:
	var parts := path.trim_prefix("res://").split("/")
	return "/".join(parts.slice(0, 2)) if parts.size() >= 3 else ""


## Everything `roots` reaches. Paths in `boundary` are routes into a Pack, so
## they are neither included nor followed.
var _parent := {}
func _closure(roots: Array, boundary: Dictionary) -> Dictionary:
	var seen := {}
	var stack: Array = []
	for r in roots:
		stack.append([r, ""])
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var path: String = item[0]
		if seen.has(path) or boundary.has(path) or not _exists(path) or _excluded(path):
			continue
		seen[path] = item[1]
		var edges := _edges_of(path)
		for d in edges.deps:
			stack.append([d, path])
		for d in edges.refs:
			stack.append([d, path])
	return seen


func _edges_of(path: String) -> Dictionary:
	if _edges.has(path):
		return _edges[path]
	var deps: Array[String] = []
	var refs: Array[String] = []
	if ResourceLoader.exists(path):
		for dep in ResourceLoader.get_dependencies(path):
			# "uid://...::Type::res://path", or a bare path from older formats.
			# The UID wins when it resolves, as it does when the engine loads:
			# a moved file keeps its UID while the scene's text path goes stale.
			var dep_path: String = dep.get_slice("::", 2) if dep.contains("::") else dep
			var uid := ResourceUID.text_to_id(dep.get_slice("::", 0))
			if uid != ResourceUID.INVALID_ID and ResourceUID.has_id(uid):
				dep_path = ResourceUID.get_id_path(uid)
			if dep_path != "" and not dep_path.begins_with("uid://"):
				deps.append(dep_path)
	if path.get_extension().to_lower() in TEXT_EXTENSIONS:
		var text := FileAccess.get_file_as_string(path)
		refs.append_array(_string_paths(text))
		if path.get_extension() == "gd":
			refs.append_array(_class_uses(text, path))
	_edges[path] = {"deps": deps, "refs": refs}
	return _edges[path]


## res:// paths written out in full in code. Templates ("%s", "{0}") and
## directories are not one file, so they are skipped. Whole-line comments are
## skipped too: a path named in prose is not a load.
func _string_paths(text: String) -> Array[String]:
	var found: Array[String] = []
	var regex := RegEx.create_from_string("res://[^\"'\\s)\\]]+")
	for line in text.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		for match in regex.search_all(line):
			var candidate := match.get_string()
			if candidate.contains("%") or candidate.contains("{") or candidate.ends_with("/"):
				continue
			found.append(candidate)
	return found


func _class_uses(text: String, own_path: String) -> Array[String]:
	var found: Array[String] = []
	var regex := RegEx.create_from_string("[A-Za-z_][A-Za-z0-9_]*")
	var seen := {}
	for match in regex.search_all(_code_only(text)):
		var word := match.get_string()
		if seen.has(word) or not _class_paths.has(word):
			continue
		seen[word] = true
		if _class_paths[word] != own_path:
			found.append(_class_paths[word])
	return found


## GDScript source with string literals and comments blanked out. A class
## named inside a string ("MindSparkWorldOne" as a node name) or a comment is
## not a use the compiler links, so it must not count as a dependency.
func _code_only(text: String) -> String:
	var strings_and_comments := RegEx.create_from_string(
		"\"\"\"[\\s\\S]*?\"\"\"|'''[\\s\\S]*?'''|\"(?:\\\\.|[^\"\\\\\\n])*\"|'(?:\\\\.|[^'\\\\\\n])*'|#[^\\n]*")
	return strings_and_comments.sub(text, "", true)


func _load_class_paths() -> void:
	var cache := ConfigFile.new()
	if cache.load("res://.godot/global_script_class_cache.cfg") != OK:
		return
	for entry in cache.get_value("", "list", []):
		_class_paths[String(entry["class"])] = entry["path"]


## Autoloads, the main scene, the icon, the default theme and bus layout: the
## project file names them, and Core has to carry all of them.
func _project_setting_paths() -> Array[String]:
	var text := FileAccess.get_file_as_string("res://project.godot")
	var paths: Array[String] = []
	for path in _string_paths(text):
		paths.append(path)
	return paths


func _walk(dir_path: String, out: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if sub in SKIP_DIRS:
			continue
		var child := dir_path.path_join(sub)
		# A folder holding a .gdignore is invisible to Godot, and so to the export.
		if FileAccess.file_exists(child.path_join(".gdignore")):
			continue
		_walk(child, out)
	for file in dir.get_files():
		var path := dir_path.path_join(file)
		if file.ends_with(".import") or file.ends_with(".uid") or not ResourceLoader.exists(path):
			continue
		if not _excluded(path):
			out[path] = true


## What the game needs at runtime: which entry scenes need which Pack file.
func _write_manifest(packs: Dictionary) -> void:
	var manifest := {}
	for pack in packs:
		manifest[pack] = {"file": "%s.pck" % pack, "entries": packs[pack].entries}
	FileAccess.open(MANIFEST_PATH, FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t"))


## The presets the split exports with, derived from the hand-maintained Web
## preset on every build rather than edited by hand: "Web Core" is Web without
## any Pack's files and with packs.json; "Web Pack <name>" is Web without the
## other Packs' files, and export-web-packs.sh exports it as a patch against
## Core, so what it ships is exactly what Core lacks.
##
## The Pack preset must not select only its own files: a patch records every
## base file its preset leaves out as removed, and mounting it would then delete
## those files from the running game.
func _write_presets(packs: Dictionary) -> void:
	var presets := ConfigFile.new()
	presets.load(PRESETS_PATH)
	var web := ""
	var next := 0
	for section in presets.get_sections():
		if section.ends_with(".options"):
			continue
		next = maxi(next, section.trim_prefix("preset.").to_int() + 1)
		if presets.get_value(section, "name", "") == WEB_PRESET:
			web = section
	var base_excludes: String = presets.get_value(web, "exclude_filter", "")
	_copy_preset(presets, web, "preset.%d" % next, {
		"name": "Web Core",
		"exclude_filter": _with_excluded(base_excludes, packs, ""),
		"include_filter": "%s,%s" % [presets.get_value(web, "include_filter", ""), MANIFEST_PATH.trim_prefix("res://")],
	})
	for pack in packs:
		next += 1
		_copy_preset(presets, web, "preset.%d" % next, {
			"name": "Web Pack %s" % pack,
			"exclude_filter": _with_excluded(base_excludes, packs, pack),
		})
	presets.save(PRESETS_PATH)


## `excludes` plus the files of every Pack except `keep`.
func _with_excluded(excludes: String, packs: Dictionary, keep: String) -> String:
	var parts := PackedStringArray([excludes])
	for pack in packs:
		if pack != keep:
			for path in packs[pack].files:
				parts.append(path.trim_prefix("res://"))
	return ",".join(parts)


func _copy_preset(presets: ConfigFile, from: String, to: String, overrides: Dictionary) -> void:
	for suffix in ["", ".options"]:
		for key in presets.get_section_keys(from + suffix):
			presets.set_value(to + suffix, key, presets.get_value(from + suffix, key))
	for key in overrides:
		presets.set_value(to, key, overrides[key])


func _exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


func _excluded(path: String) -> bool:
	var relative := path.trim_prefix("res://")
	for pattern in _excludes:
		if relative.match(pattern) or path.match(pattern):
			return true
	return false


func _preset_excludes() -> PackedStringArray:
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	for section in presets.get_sections():
		if section.ends_with(".options") or presets.get_value(section, "name", "") != WEB_PRESET:
			continue
		var raw: String = presets.get_value(section, "exclude_filter", "")
		var patterns := PackedStringArray()
		for pattern in raw.split(","):
			if pattern.strip_edges() != "":
				patterns.append(pattern.strip_edges())
		return patterns
	return PackedStringArray()
