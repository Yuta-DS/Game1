extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("CONNECTED_KINGDOM_STORY_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var regions := Node3D.new()
	regions.name = "KingdomRegions3000m"
	regions.set_script(load("res://scripts/art_castle_kingdom_regions.gd"))
	world.add_child(regions)
	var story := Node3D.new()
	story.name = "ConnectedKingdomStory"
	story.set_script(load("res://scripts/art_castle_kingdom_story.gd"))
	world.add_child(story)
	await process_frame
	if not story.call("story_is_connected"):
		_fail("the three kingdom chapters are not connected to one progression")
		return
	for kingdom_id in ["mind", "heart", "creator"]:
		if int(story.call("get_checkpoint_count", kingdom_id)) != 8:
			_fail("%s story does not have eight ordered checkpoints" % kingdom_id)
			return
		if not bool(story.call("can_activate_checkpoint", kingdom_id, 0)) \
				or bool(story.call("can_activate_checkpoint", kingdom_id, 1)):
			_fail("%s story can be completed out of order" % kingdom_id)
			return
	if story.get_node_or_null("ConnectedStoryHUD") == null:
		_fail("player has no connected-story guidance")
		return
	print("CONNECTED_KINGDOM_STORY_TEST: PASS — all stories are ordered and lead to canonical kingdom activities")
	quit()
