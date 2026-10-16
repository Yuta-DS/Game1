extends SceneTree

const TEST_SAVE := "user://test_crown_finale.json"

var _original_save_path := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var js := root.get_node_or_null("/root/JourneyState")
	if js == null:
		push_error("CROWN_FINALE_TEST: JourneyState missing")
		quit(1)
		return
	_original_save_path = js.save_path
	js.save_path = TEST_SAVE
	js.clear_journey()

	# A partial journey must remain an invitation, never a premature crown.
	js.record_thought_echo("I am learning and growing.", "learning")
	js.mark_popped("I am learning and growing.")
	js.advance_to(4)
	if js.stage == 4:
		_finish(false, "partial journey unlocked Crown stage")
		return

	# Complete each canonical kingdom through its real evidence seam. Optional
	# Lens chapters are intentionally unable to seed the Crown finale.
	js.record_thought_echo("I can take one brave step.", "brave_step")
	js.mark_popped("I can take one brave step.")
	assert(js.complete_mind_spark(2), "full curated Mind encounter awards its Star")
	js.record_emotion("hope", Color("8fd3ff"))
	var creation_id: String = str(js.record_creation("user://test-crown-art.png", "My Light"))
	js.complete_creator_frame_ritual(creation_id, "constellation_mural")
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _i in 50:
		await process_frame
	var crown := gallery.get_node_or_null("Player3D/CrownOfLife")
	var star := gallery.get_node_or_null("IdentityStar")
	var rainbow := gallery.find_child("RainbowGalaxyTrain", true, false)
	if js.stage != 4 or crown == null or star == null or rainbow == null:
		_finish(false, "finale incomplete stage=%d crown=%s star=%s train=%s" % [
			js.stage, crown != null, star != null, rainbow != null])
		return
	_finish(true, "all three treasures create Crown, named star, and Rainbow Galaxy Train")


func _finish(passed: bool, message: String) -> void:
	var js := root.get_node_or_null("/root/JourneyState")
	js.clear_journey()
	js.save_path = _original_save_path
	if passed:
		print("CROWN_FINALE_TEST: PASS — %s" % message)
		quit()
	else:
		push_error("CROWN_FINALE_TEST: %s" % message)
		quit(1)
