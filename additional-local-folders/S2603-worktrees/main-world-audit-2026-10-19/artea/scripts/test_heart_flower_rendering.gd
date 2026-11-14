extends SceneTree

const Art = preload("res://scripts/heart_melody/heart_art.gd")

func _initialize() -> void:
	var parent := Node3D.new()
	var flower := Art.flower(parent, Vector3(3, 0, 4), Color.PINK, 2.0)
	assert(flower.get_child_count() == 7, "A complete flower retains its original five individual petals")
	assert(flower.is_in_group("heart_flower") and flower.position == Vector3(3, 0, 4), "Playable identity and anchor are preserved")
	var petals := flower.get_child(1) as MeshInstance3D
	assert(is_equal_approx(petals.position.y, 1.2), "Seed-preview code can still address the petal anchor")
	# Use the actual seed-preview selection rule from the garden UI.
	for child in flower.get_children():
		if child is MeshInstance3D and child.position.y > 1 and child.position.y < 1.3:
			child.material_override = Art.material(Color.BLUE)
	for index in range(1, 6):
		assert(flower.get_child(index).get_active_material(0).albedo_color == Color.BLUE, "A seed choice recolours every original petal")
	flower.rotation.z = 0.1
	assert(petals.get_parent() == flower, "Playing and wind move the petals with the flower")
	parent.free()
	print("HEART FLOWER RENDERING: PASS")
	quit()
