extends SceneTree

const Art = preload("res://scripts/heart_melody/heart_art.gd")

func _initialize() -> void:
	var parent := Node3D.new()
	var flower := Art.flower(parent, Vector3(3, 0, 4), Color.PINK, 2.0)
	assert(flower.get_child_count() == 3, "A complete five-petal flower uses three surfaces")
	assert(flower.is_in_group("heart_flower") and flower.position == Vector3(3, 0, 4), "Playable identity and anchor are preserved")
	var petals := flower.get_child(1) as MeshInstance3D
	assert(is_equal_approx(petals.position.y, 1.2), "Seed-preview code can still address the petal anchor")
	var reference := Art.cone(parent, Vector3.ZERO, 1.2, 0.8, 0.28, Color.PINK, false, 5)
	assert(petals.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 5 * reference.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), "All five original petal shapes are retained")
	# Use the actual seed-preview selection rule from the garden UI.
	for child in flower.get_children():
		if child is MeshInstance3D and child.position.y > 1 and child.position.y < 1.3:
			child.material_override = Art.material(Color.BLUE)
	assert(petals.get_active_material(0).albedo_color == Color.BLUE, "A seed choice recolours the complete visible blossom")
	flower.rotation.z = 0.1
	assert(petals.get_parent() == flower, "Playing and wind move the petals with the flower")
	parent.free()
	print("HEART FLOWER RENDERING: PASS")
	quit()
