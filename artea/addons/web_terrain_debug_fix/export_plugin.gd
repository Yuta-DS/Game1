@tool
extends EditorExportPlugin

# terrain_3d correctly ships libterrain.web.debug.wasm32.wasm next to index.html
# in a debug Web export, but Godot's generated JS loader requests
# libterrain.web.release.wasm32.wasm instead - a 404 that stalls loadDylibs
# forever (this is what makes the editor's one-click Web run hang on a black
# screen, since that button always does a debug export). GDExtension shared
# objects bypass _export_file(), so this can't be fixed by intercepting that
# hook - instead, after export, copy the debug wasm to also exist under the
# release filename in the actual output directory.

const DEBUG_LIB_NAME := "libterrain.web.debug.wasm32.wasm"
const RELEASE_LIB_NAME := "libterrain.web.release.wasm32.wasm"

var _out_dir: String = ""
var _is_debug_export: bool = false
var _is_web_export: bool = false

func _get_name() -> String:
	return "TerrainWebDebugFix"

func _export_begin(features: PackedStringArray, is_debug: bool, path: String, _flags: int) -> void:
	_out_dir = path.get_base_dir()
	_is_debug_export = is_debug
	_is_web_export = features.has("web")

func _export_end() -> void:
	if not _is_web_export or not _is_debug_export or _out_dir.is_empty():
		return
	var debug_file := _out_dir.path_join(DEBUG_LIB_NAME)
	var release_file := _out_dir.path_join(RELEASE_LIB_NAME)
	if FileAccess.file_exists(debug_file) and not FileAccess.file_exists(release_file):
		DirAccess.copy_absolute(debug_file, release_file)
