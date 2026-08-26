extends SceneTree

const GLB_PATH := "res://assets3D/tree_processional_bridge/glb/tree_processional_bridge.glb"
const BLEND_PATH := "res://assets3D/tree_processional_bridge/blend/tree_processional_bridge.blend"
const MANIFEST_PATH := "res://assets3D/tree_processional_bridge/tree_processional_bridge_manifest.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary
	assert(not manifest.is_empty(), "Tree bridge manifest must parse")
	assert(FileAccess.file_exists(BLEND_PATH), "editable Tree bridge Blender source is missing")
	assert(ResourceLoader.exists(GLB_PATH), "Tree bridge GLB must import in Godot")
	assert(String(manifest.get("performance_profile", "")) == "laptop_cpu_low")
	assert(int(manifest.get("editable_source_modules", 0)) == 689)
	assert(int(manifest.get("runtime_mesh_groups", 0)) == 9)
	assert(int(manifest.get("runtime_triangles", 999999)) == 26116)
	assert(int(manifest.get("portal_count", 0)) == 3)
	assert(int(manifest.get("pylon_count", 0)) == 18)
	assert(int(manifest.get("rail_bay_count", 0)) == 16)
	var dimensions := manifest.get("dimensions_m", {}) as Dictionary
	assert(is_equal_approx(float(dimensions.get("length", 0.0)), 447.0))
	assert(is_equal_approx(float(dimensions.get("width", 0.0)), 62.0))
	assert(is_equal_approx(float(dimensions.get("clear_gameplay_lane", 0.0)), 42.0))
	assert(float(dimensions.get("maximum_height", 99.0)) <= 28.1)
	var components := manifest.get("component_breakdown", {}) as Dictionary
	for path in ["BRIDGE/DECK_BAY", "BRIDGE/PYLON", "BRIDGE/BOTANICAL_RAIL_BAY",
			"BRIDGE/BOUGH_PORTAL", "BRIDGE/UNDERSIDE_SUPPORT"]:
		assert(int(components.get(path, 0)) > 0,
			"editable Tree bridge hierarchy is missing %s" % path)

	var packed := load(GLB_PATH) as PackedScene
	var asset := packed.instantiate() as Node3D
	root.add_child(asset)
	await process_frame
	var meshes := asset.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() == 9, "Tree bridge GLB must contain nine semantic mesh groups")
	for group_name in ["DeckIvory", "CyanLight", "RailGold", "PortalIvory", "PortalGold"]:
		assert(asset.find_child(group_name, true, false) != null,
			"Tree bridge GLB is missing %s" % group_name)
	var bounds := _bounds(meshes)
	print("TREE_PROCESSIONAL_BLENDER_BRIDGE_BOUNDS: ", bounds.size)
	assert(absf(bounds.size.x - 62.15) < 0.05, "Tree bridge width changed from Blender")
	assert(absf(bounds.size.y - 42.696) < 0.05, "Tree bridge vertical extent changed from Blender")
	assert(absf(bounds.size.z - 447.0) < 0.5, "Tree bridge route length changed from Blender")
	print("TREE_PROCESSIONAL_BLENDER_BRIDGE_TEST: PASS — bounds=%s modules=689 groups=9 triangles=26116" % bounds.size)
	quit()


func _bounds(meshes: Array[Node]) -> AABB:
	var found := false
	var result := AABB()
	for candidate in meshes:
		var mesh_instance := candidate as MeshInstance3D
		var transformed := mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		if found:
			result = result.merge(transformed)
		else:
			result = transformed
			found = true
	return result
