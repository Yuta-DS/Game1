extends SceneTree


const REQUIRED_WEB_RESOURCES := [
	"res://assets3D/characters/milo_villager_highpoly.glb",
	"res://assets3D/crown_line_train/crown_line_lego_train.glb",
	"res://scenes/mind_spark/mind_spark_world_one.tscn",
	"res://scenes/mind_spark/mind_spark_chapter_world.tscn",
	"res://scenes/viewfinder/crown_of_life_story.tscn",
]


func _init() -> void:
	var config := ConfigFile.new()
	assert(config.load("res://export_presets.cfg") == OK,
		"Web feature parity: export_presets.cfg must load")
	var web_section := _find_web_preset(config)
	assert(not web_section.is_empty(), "Web feature parity: Web preset is missing")
	assert(str(config.get_value(web_section, "export_filter", "")) == "all_resources",
		"Web feature parity: Web must export all project resources")
	var exclusions := str(config.get_value(web_section, "exclude_filter", ""))
	for resource_path in REQUIRED_WEB_RESOURCES:
		assert(ResourceLoader.exists(resource_path),
			"Web feature parity: required local resource is missing: %s" % resource_path)
		var project_path: String = resource_path.trim_prefix("res://")
		assert(not _matches_any_export_pattern(project_path, exclusions),
			"Web feature parity: required local resource is excluded: %s" % resource_path)
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
