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
	"assets3D/crown_line_train/crown_line_lego_train.glb",
	"assets3D/crown_line_train/crown_line_lego_train_aged_gold_albedo.png",
	"assets3D/mind_spark/celestial_islands_v08/island_01.glb",
	"assets3D/mind_spark/celestial_islands_v11/island_02.glb",
	"assets3D/mind_spark/celestial_islands_v11/island_03.glb",
	"assets3D/mind_spark/celestial_islands_v11/island_04.glb",
	"assets3D/mind_spark/celestial_terrace_3000/celestial_terrace_3000.glb",
	"assets3D/tree_of_life/leaves/glb/artea_leaf_library.glb",
]


func _init() -> void:
	var config := ConfigFile.new()
	assert(config.load("res://export_presets.cfg") == OK,
		"Web feature parity: export_presets.cfg must load")
	var web_section := _find_web_preset(config)
	assert(not web_section.is_empty(), "Web feature parity: Web preset is missing")
	assert(str(config.get_value(web_section, "export_filter", "")) == "scenes",
		"Web pack scope: export selected playable scenes and their dependencies")
	var exported_scenes: PackedStringArray = config.get_value(
		web_section, "export_files", PackedStringArray())
	var inclusions := str(config.get_value(web_section, "include_filter", ""))
	var exclusions := str(config.get_value(web_section, "exclude_filter", ""))
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
