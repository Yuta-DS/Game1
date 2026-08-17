extends SceneTree

const LEAF_PATH := "res://assets3D/tree_of_life/leaves/reference_faithful/glb/living_leaf_fan_reference_faithful.glb"
const MANIFEST_PATH := "res://assets3D/tree_of_life/leaves/reference_faithful/living_leaf_fan_reference_faithful.json"


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("REFERENCE_FAITHFUL_LIVING_LEAF_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if manifest_file == null:
		_fail("manifest is missing")
		return
	var manifest = JSON.parse_string(manifest_file.get_as_text())
	if not manifest is Dictionary or int(manifest.get("vertex_count", 0)) < 10000:
		_fail("manifest does not guarantee at least 10,000 detail points")
		return

	var packed := load(LEAF_PATH) as PackedScene
	if packed == null:
		_fail("GLB could not be imported")
		return
	var leaf := packed.instantiate() as Node3D
	root.add_child(leaf)

	var meshes := leaf.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 1:
		_fail("expected one dense textured relief mesh, found %d" % meshes.size())
		return
	var mesh_instance := meshes[0] as MeshInstance3D
	var vertex_count := 0
	var textured := false
	for surface_index in mesh_instance.mesh.get_surface_count():
		var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
		vertex_count += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var material := mesh_instance.mesh.surface_get_material(surface_index) as BaseMaterial3D
		if material != null and material.albedo_texture != null and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			textured = true
	if vertex_count < 10000:
		_fail("imported mesh has only %d vertices" % vertex_count)
		return
	if not textured:
		_fail("RGBA leaf texture or transparency was lost during GLB import")
		return
	if not leaf.find_children("*", "CollisionObject3D", true, false).is_empty():
		_fail("standalone visual asset unexpectedly contains collision")
		return

	print("REFERENCE_FAITHFUL_LIVING_LEAF_TEST: PASS — %d vertices with RGBA texture" % vertex_count)
	quit()
