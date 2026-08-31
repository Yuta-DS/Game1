extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	var manager_source := FileAccess.get_file_as_string("res://scripts/MiloCompanionManager.gd")
	var hub_source := FileAccess.get_file_as_string("res://scenes/New_Hub_World.tscn")
	var gameplay_path := "res://milo2/godot/milo2_game_character.tscn"
	_expect(manager_source.contains(gameplay_path), "companion manager does not spawn finalized Milo 2")
	_expect(hub_source.contains(gameplay_path), "live hub does not instance finalized Milo 2")
	_expect(hub_source.contains("Milo2Gameplay"), "live Milo still uses the legacy node identity")
	_expect(not hub_source.contains("Milo_Animations2"), "legacy Milo node remains in the live hub")
	_expect(not hub_source.contains("OriginalCatStatue"), "old Milo statue remains in the live hub")
	_expect(not hub_source.contains("res://meshy ai/Milo_Animations.glb"),
		"old Milo model remains referenced by the live hub")
	_expect(not manager_source.contains("preload(\"res://scenes/milo_animations.tscn\")"),
		"companion manager still spawns Milo 1")
	_expect(manager_source.contains("_remove_legacy_milos(scene)"),
		"companion manager does not purge legacy Milo instances")

	var packed := load(gameplay_path) as PackedScene
	_expect(packed != null, "Milo 2 gameplay scene failed to load")
	if packed != null:
		var milo := packed.instantiate() as CharacterBody3D
		root.add_child(milo)
		await process_frame
		_expect(milo != null, "Milo 2 gameplay root is not a CharacterBody3D")
		if milo != null:
			_expect(int(milo.call("get_milo_generation")) == 2, "gameplay Milo is not generation 2")
			_expect(milo.has_method("set_companion_player"), "Milo 2 lost companion following")
			_expect(milo.has_method("open_chatbot"), "Milo 2 lost chat interaction")
			_expect(milo.get_node_or_null("Model") != null, "finalized Milo 2 model is missing")
			var prompt := milo.get_node_or_null("InteractionPrompt") as Label3D
			_expect(prompt != null and prompt.text == "Press Q to chat with Milo",
				"Milo 2 does not expose the established Q chat prompt")
			milo.call("_play_animation", "Cane_Walk")
			await process_frame
			var player := _find_animation_player(milo)
			_expect(player != null and player.current_animation == "Milo2_Walk",
				"legacy gameplay walk requests do not resolve to Milo 2's authored walk " +
				"(player=%s, current=%s, clips=%s)" % [
					str(player.get_path()) if player != null else "missing",
					player.current_animation if player != null else "missing",
					str(player.get_animation_list()) if player != null else "missing",
				])
			milo.queue_free()
			await process_frame

	if failures.is_empty():
		print("MILO2_GAME_INTEGRATION_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("MILO2_GAME_INTEGRATION_TEST: FAIL (%d)" % failures.size())
		quit(1)


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
