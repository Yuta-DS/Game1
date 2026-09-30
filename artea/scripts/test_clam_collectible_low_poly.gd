extends SceneTree

const CLAM_SCENE := preload("res://scenes/items/clam_collectible.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string("res://scenes/items/clam_collectible.tscn")
	assert(not source.contains("Pink_Shell_Clip_1029042716_texture.glb"),
		"The hub collectible must not pull the 8.7 MiB prototype shell into Web builds")
	var clam := CLAM_SCENE.instantiate() as Area3D
	root.add_child(clam)
	await process_frame
	var visual := clam.get_node("Clam") as Node3D
	assert(visual.get_meta("style") == "faceted low-poly shell")
	assert(bool(visual.get_meta("web_optimized", false)))
	assert(visual.find_children("*Shell*", "MeshInstance3D", true, false).size() == 4)
	assert(visual.get_node_or_null("Pearl") is MeshInstance3D)
	assert(visual.get_node_or_null("PickupGlow") is OmniLight3D)
	var collision := clam.get_node("CollisionShape3D") as CollisionShape3D
	assert(collision.shape is SphereShape3D and is_equal_approx((collision.shape as SphereShape3D).radius, 2.5))
	assert(clam.item_data != null and clam.item_data.name == "Clam")
	clam.queue_free()
	await process_frame
	print("CLAM_COLLECTIBLE_LOW_POLY: PASS — faceted shell, pearl, pickup data and collision preserved")
	quit()
