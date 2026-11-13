extends SceneTree

const LIBRARY_PATH := "res://assets3D/tree_of_life/leaves/reference_faithful/glb/reference_faithful_leaf_library.glb"
const MANIFEST_PATH := "res://assets3D/tree_of_life/leaves/reference_faithful/reference_faithful_leaf_library.json"
const EXPECTED_OBJECTS := [
	"LivingLeafFanReferenceRelief",
	"MagicRuneLeafReferenceRelief",
	"SolarGlassScienceLeafReferenceRelief",
	"EmeraldSensorLeafReferenceRelief",
]


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("REFERENCE_FAITHFUL_LEAF_LIBRARY_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if manifest_file == null:
		_fail("manifest is missing")
		return
	var manifest = JSON.parse_string(manifest_file.get_as_text())
	if not manifest is Dictionary:
		_fail("manifest is invalid")
		return
	var leaf_records := manifest.get("leaves", {}) as Dictionary
	if leaf_records.size() != 4:
		_fail("manifest does not describe all four leaves")
		return
	for slug in leaf_records:
		var record := leaf_records[slug] as Dictionary
		if int(record.get("vertices", 0)) < 10000:
			_fail("%s has fewer than 10,000 detail points" % slug)
			return
		var individual := load("res://%s" % record.get("glb", "")) as PackedScene
		if individual == null:
			_fail("individual GLB failed to import: %s" % slug)
			return

	var packed := load(LIBRARY_PATH) as PackedScene
	if packed == null:
		_fail("combined GLB failed to import")
		return
	var library := packed.instantiate() as Node3D
	root.add_child(library)

	var total_vertices := 0
	for object_name in EXPECTED_OBJECTS:
		var mesh_instance := library.find_child(object_name, true, false) as MeshInstance3D
		if mesh_instance == null:
			_fail("combined library is missing %s" % object_name)
			return
		var leaf_vertices := 0
		var textured := false
		for surface_index in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			leaf_vertices += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var material := mesh_instance.mesh.surface_get_material(surface_index) as BaseMaterial3D
			if material != null and material.albedo_texture != null:
				textured = true
		if leaf_vertices < 10000 or not textured:
			_fail("%s lost dense geometry or its RGBA texture" % object_name)
			return
		total_vertices += leaf_vertices

	if not library.find_children("*", "CollisionObject3D", true, false).is_empty():
		_fail("visual-only leaf library unexpectedly contains collision")
		return
	print("REFERENCE_FAITHFUL_LEAF_LIBRARY_TEST: PASS — four textured leaves, %d total vertices" % total_vertices)
	quit()
