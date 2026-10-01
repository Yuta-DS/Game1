extends SceneTree


const REQUIRED_WEB_RESOURCES := [
	"res://default_bus_layout.tres",
	"res://resources/web_hub_surface_map.png",
	"res://assets3D/characters/milo_exact_target_parts.glb",
	"res://assets3D/characters/fox_Normal.png",
	"res://assets3D/characters/fox_sword_diffuse.png",
	"res://assets3D/characters/fox_sword_metal.png",
	"res://assets3D/characters/fox_bow_normal.png",
	"res://assets/models/bpng.jpg",
	"res://assets/models/Pot textures_col.jpg",
	"res://assets/models/10305_picture_frame_V1_Diffuse.jpg",
	"res://assets3D/crown_line_train/crown_line_runtime_textured.glb",
	"res://assets3D/mind_spark/celestial_islands_v08/shared_paving.glb",
	"res://assets3D/mind_spark/celestial_islands_v11/island_01.glb",
	"res://assets3D/mind_spark/celestial_verdant_v12/island_02.glb",
	"res://assets3D/mind_spark/celestial_astral_v16/island_03.glb",
	"res://assets3D/mind_spark/celestial_dawn_v17/island_04.glb",
	"res://assets3D/mind_spark/celestial_islands_v11/island_05.glb",
	"res://assets3D/mind_spark/celestial_islands_v11/island_06.glb",
	"res://scenes/mind_spark/mind_spark_world_one.tscn",
	"res://scenes/mind_spark/mind_spark_chapter_world.tscn",
	"res://scenes/viewfinder/crown_of_life_story.tscn",
]

const RETIRED_WEB_RESOURCES := [
	"addons/terrain_3d/bin/libterrain.web.debug.wasm32.wasm",
	"assets3D/crown_line_train/crown_line_lego_train.glb",
	"assets3D/crown_line_train/crown_line_lego_train_aged_gold_albedo.png",
	"assets3D/mind_spark/celestial_islands_v08/island_01.glb",
	"assets3D/mind_spark/celestial_islands_v11/island_02.glb",
	"assets3D/mind_spark/celestial_islands_v11/island_03.glb",
	"assets3D/mind_spark/celestial_islands_v11/island_04.glb",
	"assets3D/mind_spark/celestial_terrace_3000/celestial_terrace_3000.glb",
	"assets3D/tree_of_life/leaves/glb/artea_leaf_library.glb",
	"assets3D/Pink_Shell_Clip_1029042716_texture.glb",
	"assets3D/Pink_Shell_Clip_1029042716_texture_0.jpg",
	"assets3D/Pink_Shell_Clip_1029042716_texture_1.jpg",
	"assets3D/Pink_Shell_Clip_1029042716_texture_2.jpg",
	"scripts/assets3D/Crescent_Moon_PNG_Clip_Art_Image.png",
]

const WEB_TEXTURE_SIZE_LIMITS := {
	"res://assets/Joystick/joyring.png.import": 256,
	"res://assets/Joystick/joyknobpng.png.import": 256,
	"res://assets3D/Crescent_Moon_PNG_Clip_Art_Image.png.import": 1024,
}


func _init() -> void:
	var config := ConfigFile.new()
	assert(config.load("res://export_presets.cfg") == OK,
		"Web feature parity: export_presets.cfg must load")
	var web_section := _find_web_preset(config)
	assert(not web_section.is_empty(), "Web feature parity: Web preset is missing")
	var web_options := "%s.options" % web_section
	assert(str(config.get_value(web_options, "html/custom_html_shell", "")) \
		== "res://web_export_shell.html",
		"Web presentation: the maintained full-viewport shell must be exported")
	assert(int(config.get_value(web_options, "html/canvas_resize_policy", -1)) == 2,
		"Web presentation: Godot adaptive canvas resizing must remain enabled")
	var shell := FileAccess.get_file_as_string("res://web_export_shell.html")
	assert(not shell.is_empty(), "Web presentation: custom HTML shell must be readable")
	assert(shell.contains("width: 100vw !important;") \
		and shell.contains("height: 100vh !important;"),
		"Web presentation: canvas CSS must fill the browser viewport")
	assert(not shell.contains("canvas.width =") and not shell.contains("canvas.height ="),
		"Web presentation: custom JS must not desynchronise Godot's WebGL viewport")
	assert(str(config.get_value(web_section, "export_filter", "")) == "scenes",
		"Web pack scope: export selected playable scenes and their dependencies")
	var exported_scenes: PackedStringArray = config.get_value(
		web_section, "export_files", PackedStringArray())
	var inclusions := str(config.get_value(web_section, "include_filter", ""))
	var exclusions := str(config.get_value(web_section, "exclude_filter", ""))
	assert(_matches_any_export_pattern(
		"addons/terrain_3d/bin/libterrain.web.release.wasm32.wasm", inclusions),
		"Web pack scope: the release Terrain3D side module must be included")
	for resource_path in REQUIRED_WEB_RESOURCES:
		assert(ResourceLoader.exists(resource_path),
			"Web feature parity: required local resource is missing: %s" % resource_path)
		var project_path: String = resource_path.trim_prefix("res://")
		assert(not _matches_any_export_pattern(project_path, exclusions),
			"Web feature parity: required local resource is excluded: %s" % resource_path)
		assert(exported_scenes.has(resource_path)
			or _matches_any_export_pattern(project_path, inclusions),
			"Web feature parity: dynamic resource is outside the scoped pack: %s" % resource_path)
	for retired_path in RETIRED_WEB_RESOURCES:
		assert(_matches_any_export_pattern(retired_path, exclusions),
			"Web pack scope: retired development asset should not ship: %s" % retired_path)
	for import_path in WEB_TEXTURE_SIZE_LIMITS:
		var import_config := ConfigFile.new()
		assert(import_config.load(import_path) == OK,
			"Web pack scope: texture import settings must load: %s" % import_path)
		var actual_limit := int(import_config.get_value("params", "process/size_limit", 0))
		assert(actual_limit == WEB_TEXTURE_SIZE_LIMITS[import_path],
			"Web pack scope: %s must retain its %d px size limit (found %d)" % [
				import_path,
				WEB_TEXTURE_SIZE_LIMITS[import_path],
				actual_limit,
			])
	print("WEB FEATURE PARITY TEST: PASS (%d required resources exported)" \
		% REQUIRED_WEB_RESOURCES.size())
	quit(0)


func _find_web_preset(config: ConfigFile) -> String:
	for section in config.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		if str(config.get_value(section, "platform", "")) == "Web":
			return section
	return ""


func _matches_any_export_pattern(path: String, exclusion_csv: String) -> bool:
	for raw_pattern in exclusion_csv.split(",", false):
		var pattern := raw_pattern.strip_edges()
		if pattern.is_empty():
			continue
		if path.match(pattern):
			return true
	return false
