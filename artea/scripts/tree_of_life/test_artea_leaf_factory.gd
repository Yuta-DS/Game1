extends SceneTree

const LeafFactory := preload("res://scripts/tree_of_life/artea_leaf_factory.gd")

const EXPECTED_MINIMUM_COMPONENTS := {
	LeafFactory.LeafType.LIVING_FAN: 420,
	LeafFactory.LeafType.MAGIC_RUNE: 70,
	LeafFactory.LeafType.SOLAR_GLASS: 64,
	LeafFactory.LeafType.EMERALD_SENSOR: 50,
}


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("ARTEA_LEAF_FACTORY_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var total_components := 0
	for leaf_type in EXPECTED_MINIMUM_COMPONENTS:
		var leaf := LeafFactory.create_leaf(leaf_type)
		root.add_child(leaf)
		var component_count := int(leaf.get_meta("editable_component_count", 0))
		if component_count < int(EXPECTED_MINIMUM_COMPONENTS[leaf_type]):
			_fail("%s has only %d components" % [leaf.get_meta("leaf_type", "unknown"), component_count])
			return
		if not leaf.find_children("*", "CollisionObject3D", true, false).is_empty():
			_fail("decorative leaf unexpectedly contains collision")
			return
		var meshes := leaf.find_children("*", "MeshInstance3D", true, false)
		for mesh in meshes:
			if not (mesh as MeshInstance3D).get_meta("editable_leaf_component", false):
				_fail("unnamed/non-editable component found under %s" % leaf.name)
				return
		total_components += component_count
		leaf.queue_free()
	await process_frame
	print("ARTEA_LEAF_FACTORY_TEST: PASS — four native Godot leaf types, %d separately named mesh components" % total_components)
	quit()
