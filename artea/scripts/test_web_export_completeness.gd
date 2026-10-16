extends SceneTree

var _failures := 0


func _init() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var presets := ConfigFile.new()
	var preset_error := presets.load("res://export_presets.cfg")
	var web_section := ""
	if preset_error == OK:
		for section in presets.get_sections():
			if str(presets.get_value(section, "name", "")) == "Web":
				web_section = section
				break
	var web_files: PackedStringArray = presets.get_value(web_section,
		"export_files", PackedStringArray())
	var web_includes := str(presets.get_value(web_section, "include_filter", ""))
	var web_excludes := str(presets.get_value(web_section, "exclude_filter", ""))
	var web_options := web_section + ".options"
	var shell := FileAccess.get_file_as_string("res://web_export_shell.html")
	var compatibility := FileAccess.get_file_as_string(
		"res://scripts/web_terrain_compat.gd")

	_check(project.contains('renderer/rendering_method="gl_compatibility"'),
		"desktop/editor and Web use the same Compatibility renderer")
	_check(project.contains('renderer/rendering_method.mobile="gl_compatibility"'),
		"mobile browsers use the Compatibility renderer")
	_check(not web_section.is_empty()
		and str(presets.get_value(web_section, "export_filter", "")) == "scenes"
		and web_files.has("res://scenes/start_screen.tscn")
		and web_files.has("res://scenes/art_gallery_3d_inprogress.tscn")
		and web_files.has("res://scenes/mind_spark/mind_spark_world_one.tscn")
		and web_files.has("res://scenes/creation_world.tscn"),
		"selected Web preset includes the startup, gallery, Galaxy World, and creation scenes")
	_check(web_includes.contains("data/*.json")
		and web_includes.contains("data/scripture/**")
		and web_includes.contains("dialogue/**"),
		"dynamically read data and dialogue files are explicitly packaged")
	_check(web_includes.contains("shaders/**")
		and web_includes.contains("resources/**")
		and web_includes.contains("addons/proton_scatter/src/**")
		and web_includes.contains("assets3D/characters/**")
		and web_includes.contains("assets3D/coastal_harbour/**")
		and web_includes.contains("assets3D/castle_rooftop_parapet/**")
		and web_includes.contains("scenes/**")
		and web_includes.contains("assets3D/royal_garden/**"),
		"hub and World One runtime resources are explicitly packaged")
	_check(bool(presets.get_value(web_options, "vram_texture_compression/for_desktop", false))
		and bool(presets.get_value(web_options, "vram_texture_compression/for_mobile", false)),
		"selected Web preset exports desktop and mobile compressed textures")
	_check(web_includes.contains("addons/terrain_3d/bin/libterrain.web.release.wasm32.wasm")
		and web_excludes.contains("addons/terrain_3d/bin/libterrain.web.debug.wasm32.wasm")
		and web_excludes.contains("addons/terrain_3d/bin/*windows*")
		and web_excludes.contains("addons/terrain_3d/bin/*macos*")
		and web_excludes.contains("addons/terrain_3d/bin/*linux*"),
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
		print("PASS: selected Web export configuration")
	quit(_failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		push_error("FAIL: %s" % message)
		_failures += 1
