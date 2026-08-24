extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/New_Hub_World.tscn") as PackedScene
	if packed == null:
		push_error("AETHER_ATLAS_REMOVAL: hub scene failed to load")
		quit(1)
		return

	var hub := packed.instantiate()
	root.add_child(hub)
	await process_frame

	if hub.get_node_or_null("AetherAtlas") != null:
		push_error("AETHER_ATLAS_REMOVAL: AetherAtlas still exists in the live hub")
		quit(1)
		return

	print("AETHER_ATLAS_REMOVAL: PASS — disc, rings, lights, and labels cannot spawn")
	quit()
