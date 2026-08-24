extends SceneTree

var _failures := 0


func _init() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	var shell := FileAccess.get_file_as_string("res://web_export_shell.html")
	var compatibility := FileAccess.get_file_as_string(
		"res://scripts/web_terrain_compat.gd")

	_check(project.contains('renderer/rendering_method="gl_compatibility"'),
		"desktop/editor and Web use the same Compatibility renderer")
	_check(project.contains('renderer/rendering_method.mobile="gl_compatibility"'),
		"mobile browsers use the Compatibility renderer")
	_check(presets.contains('name="Web"')
		and presets.contains('export_filter="all_resources"'),
		"Web export packages all runtime Godot resources")
	_check(presets.contains("**/*.json") and presets.contains("**/*.txt")
		and presets.contains("dialogue/**"),
		"dynamically read data and dialogue files are explicitly packaged")
	_check(presets.contains("vram_texture_compression/for_desktop=true")
		and presets.contains("vram_texture_compression/for_mobile=true"),
		"Web textures are exported for desktop and mobile browser GPUs")
	_check(presets.contains("libterrain.web.*.wasm")
		and presets.contains("addons/terrain_3d/bin/*windows*")
		and presets.contains("addons/terrain_3d/bin/*macos*")
		and presets.contains("addons/terrain_3d/bin/*linux*"),
		"Web extension is included while incompatible native libraries are excluded")
	_check(shell.contains("background-color: #61a8e8")
		and shell.contains("Engine.getMissingFeatures"),
		"Web shell provides a daylight fallback and reports unsupported browsers")
	_check(compatibility.contains("ambient_light_energy = 1.25")
		and compatibility.contains("ambient_light_sky_contribution = 0.0")
		and compatibility.contains("REFLECTION_SOURCE_DISABLED"),
		"Web lighting has a deterministic non-black ambient fallback")

	for path in [
		"res://resources/web_hub_terrain.res",
		"res://resources/web_hub_surface_map.png",
		"res://shaders/web_terrain.gdshader",
		"res://shaders/web_water.gdshader",
		"res://shaders/web_sky_dome.gdshader",
		"res://scripts/web_grass_surface_filter.gd",
		"res://data/crown_of_life_story.json",
		"res://data/mind_spark_chapter.json",
		"res://dialogue/HubworldDialogue.dialogue",
	]:
		_check(FileAccess.file_exists(path) or ResourceLoader.exists(path),
			"required Web runtime asset exists: %s" % path)

	if _failures == 0:
		print("PASS: complete cross-platform Web export configuration")
	quit(_failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		push_error("FAIL: %s" % message)
		_failures += 1
