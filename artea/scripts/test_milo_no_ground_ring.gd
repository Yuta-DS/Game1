extends SceneTree

const MILO_SCENE := preload("res://milo2/godot/milo2_game_character.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var milo := MILO_SCENE.instantiate() as CharacterBody3D
	root.add_child(milo)
	await process_frame
	await process_frame

	assert(milo.find_child("JourneyAura", true, false) == null,
		"Milo must not create the former gold journey ring")
	for node in milo.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		assert(not (mesh_instance.mesh is TorusMesh),
			"Milo must not contain any torus-shaped floor ring")

	var source := FileAccess.get_file_as_string("res://scripts/milo_animations.gd")
	assert(not source.contains("_build_journey_aura"),
		"the shared companion controller must not rebuild the ring in another world")
	assert(not source.contains("JourneyAura"),
		"the removed journey aura must stay absent from the shared controller")

	print("MILO_NO_GROUND_RING_TEST: PASS — no gold ring inside or outside Galaxy World")
	quit()
