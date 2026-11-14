extends SceneTree

const GLB_PATH := "res://assets3D/castle_galaxy_bridge/glb/castle_galaxy_bridge_gate.glb"
const BLEND_PATH := "res://assets3D/castle_galaxy_bridge/blend/castle_galaxy_bridge_gate.blend"
const MANIFEST_PATH := "res://assets3D/castle_galaxy_bridge/castle_galaxy_bridge_gate_manifest.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary
	assert(not manifest.is_empty(), "Blender bridge manifest must parse")
	assert(FileAccess.file_exists(BLEND_PATH), "editable Blender source must ship with the project")
	assert(ResourceLoader.exists(GLB_PATH), "runtime Blender GLB must import in Godot")
	assert(int(manifest.get("editable_source_modules", 0)) >= 1200,
		"manifest must retain a deeply editable but laptop-optimized bridge")
	assert(String(manifest.get("performance_profile", "")) == "laptop_cpu_low",
		"bridge must declare its laptop CPU graphics profile")
	assert(bool(manifest.get("laptop_cpu_optimized", false)),
		"runtime bridge must remain marked as laptop optimized")
	assert(int(manifest.get("game_triangles", 999999)) < 130000,
		"laptop profile must stay under the 130k triangle budget")
	assert(int(manifest.get("tower_body_course_count_per_tower", 0)) == 14,
		"each tower body must retain fourteen aligned masonry courses")
	assert(int(manifest.get("tower_body_chunk_count", 0)) == 70,
		"the tower cores must be broken into seventy full-depth body chunks")
	assert(int(manifest.get("hierarchy_node_count", 0)) == 26,
		"Blender source must retain the assembly and subcomponent hierarchy")
	var reference_measurements := manifest.get("front_gate_reference_measurements", {}) as Dictionary
	assert(int(reference_measurements.get("continuous_facade_outline_modules", 0)) == 1,
		"front gable outline must be one continuous glued mesh")
	assert(int(reference_measurements.get("structural_wall_halves", 0)) == 2,
		"central facade must have two structural wall halves surrounding the portal")
	assert(int(reference_measurements.get("portal_molding_layers", 0)) == 3,
		"portal must retain outer stone, inner stone, and gold molding layers")
	assert(int(reference_measurements.get("tower_roof_stages", 0)) == 2,
		"each tower must retain the measured two-stage mansard roof")
	assert(int(reference_measurements.get("shape_driven_outline_systems", 0)) == 4,
		"facade, portal, tower panels, and roofs must derive outlines from core profiles")
	assert(int(reference_measurements.get("tower_panel_outline_count", 0)) == 6,
		"all six tower panel outlines must follow their chamfered core panels")
	assert(is_equal_approx(float(reference_measurements.get("crest_side_offset_m", 0.0)), 3.9),
		"three-light crest spacing must retain the measured reference proportion")
	var hierarchy := manifest.get("editable_component_hierarchy", {}) as Dictionary
	var subcomponents := hierarchy.get("subcomponents", {}) as Dictionary
	for path in ["LEFT_GATE_TOWER/LOWER_BODY", "LEFT_GATE_TOWER/MID_BODY",
			"LEFT_GATE_TOWER/UPPER_BODY", "RIGHT_GATE_TOWER/LOWER_BODY",
			"CENTRAL_FACADE/GABLE_BODY", "BRIDGE/FASCIA_AND_ARCHES"]:
		assert(int(subcomponents.get(path, 0)) > 0,
			"editable hierarchy is missing populated component: %s" % path)
	assert(int(manifest.get("game_mesh_groups", 0)) == 13,
		"detailed bridge must stay consolidated for Web runtime")
	var dimensions := manifest.get("dimensions_m", {}) as Dictionary
	assert(is_equal_approx(float(dimensions.get("bridge_length", 0.0)), 170.0))
	assert(is_equal_approx(float(dimensions.get("bridge_width", 0.0)), 16.0))
	assert(float(dimensions.get("gate_outer_width", 0.0)) >= 42.0)
	assert(float(dimensions.get("gate_finial_height", 0.0)) >= 52.0)
	assert(float(dimensions.get("central_facade_max_height", 100.0)) <= 46.6,
		"focused gable revision must not make the central facade taller")
	assert(float(dimensions.get("clear_portal_width", 0.0)) >= 14.8)
	assert(float(dimensions.get("rear_wall_setback_in_game", 0.0)) >= 157.0)
	var color_mix := manifest.get("measured_surface_color_mix_percent", {}) as Dictionary
	assert(float(color_mix.get("sand_ivory", 0.0)) >= 58.0 \
		and float(color_mix.get("sand_ivory", 0.0)) <= 63.5,
		"warm sand/ivory must remain approximately sixty percent")
	assert(float(color_mix.get("gold", 0.0)) >= 28.0 \
		and float(color_mix.get("gold", 0.0)) <= 33.0,
		"architectural gold must remain approximately thirty percent")
	assert(float(color_mix.get("blue", 0.0)) >= 8.0 \
		and float(color_mix.get("blue", 0.0)) <= 11.0,
		"blue and cyan accents must remain approximately ten percent")

	var packed := load(GLB_PATH) as PackedScene
	var asset := packed.instantiate() as Node3D
	root.add_child(asset)
	await process_frame
	var meshes := asset.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() == 13, "GLB must contain exactly thirteen semantic mesh groups")
	var bounds := _bounds(meshes)
	assert(absf(bounds.size.x - 42.0) < 0.1, "imported gate outer width changed from Blender")
	assert(bounds.size.y > 61.0 and bounds.size.y < 62.0,
		"imported vertical extent changed from Blender")
	assert(bounds.size.z > 171.0 and bounds.size.z < 172.0,
		"imported route extent changed from Blender")
	print("CASTLE_GALAXY_BLENDER_BRIDGE_TEST: PASS — bounds=%s modules=%d groups=13" % [
		bounds.size, int(manifest.get("editable_source_modules", 0))])
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
