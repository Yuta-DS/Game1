extends SceneTree

const LeafLibraryScene := preload("res://assets3D/tree_of_life/leaves/glb/artea_leaf_library.glb")
const MANIFEST_PATH := "res://assets3D/tree_of_life/leaves/leaf_library_manifest.json"
const EXPECTED_ROOTS := [
	"LivingLeafFan", "MagicRuneLeaf", "SolarGlassScienceLeaf", "EmeraldSensorLeaf",
]


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("ARTEA_BLENDER_LEAF_LIBRARY_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_fail("leaf-only manifest is missing")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("leaf-only manifest is invalid")
		return
	var manifest := parsed as Dictionary
	if manifest.get("scope", "") != "leaves_only_no_tree_geometry" \
			or bool(manifest.get("tree_files_modified", true)):
		_fail("manifest does not preserve the leaf-only scope")
		return
	var leaves := manifest.get("leaves", {}) as Dictionary
	if leaves.size() != 4:
		_fail("manifest does not contain four leaf types")
		return
	for leaf_type in leaves:
		var count := int((leaves[leaf_type] as Dictionary).get("vertices", 0))
		if count < 10000:
			_fail("%s has %d editable vertices" % [leaf_type, count])
			return
	var individual_glbs := manifest.get("individual_game_glbs", {}) as Dictionary
	if individual_glbs.size() != 4:
		_fail("manifest does not expose four individual GLBs")
		return
	for leaf_type in individual_glbs:
		var resource_path := "res://%s" % str(individual_glbs[leaf_type])
		var individual_scene := load(resource_path) as PackedScene
		if individual_scene == null:
			_fail("individual leaf cannot be imported: %s" % resource_path)
			return
		var individual := individual_scene.instantiate() as Node3D
		if individual == null or individual.find_children("*", "MeshInstance3D", true, false).size() < 8:
			_fail("individual leaf is not componentized: %s" % leaf_type)
			return
		individual.free()

	var library := LeafLibraryScene.instantiate() as Node3D
	root.add_child(library)
	for root_name in EXPECTED_ROOTS:
		var leaf_root := library.find_child(root_name, true, false)
		if leaf_root == null:
			_fail("imported GLB is missing %s" % root_name)
			return
	if not library.find_children("*", "CollisionObject3D", true, false).is_empty():
		_fail("standalone leaves unexpectedly contain collision")
		return
	var meshes := library.find_children("*", "MeshInstance3D", true, false)
	if library.find_children("LivingFan_Leaflet_*", "MeshInstance3D", true, false).size() != 7:
		_fail("Living Leaf Fan does not expose seven separate small-leaf blade objects")
		return
	var living_texture_found := false
	for leaflet in library.find_children("LivingFan_Leaflet_*", "MeshInstance3D", true, false):
		var mesh_instance := leaflet as MeshInstance3D
		for surface_index in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if material != null and material.albedo_texture != null:
				living_texture_found = true
	if not living_texture_found:
		_fail("Living Leaf Fan lost its olive albedo texture during GLB import")
		return
	for branch_name in ["LivingFan_CrystalVeins", "LivingFan_EnergyPetioles"]:
		var branch_mesh := library.find_child(branch_name, true, false) as MeshInstance3D
		if branch_mesh == null:
			_fail("Living Leaf Fan is missing textured branch module %s" % branch_name)
			return
		var branch_material := branch_mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if branch_material == null or branch_material.albedo_texture == null:
			_fail("%s lost its teal branch texture during GLB import" % branch_name)
			return
	print("ARTEA_BLENDER_LEAF_LIBRARY_TEST: PASS — four standalone leaves, %d reusable Godot mesh modules" % meshes.size())
	quit()
