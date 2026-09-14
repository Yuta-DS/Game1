extends SceneTree

const TEST_SAVE := "user://test_crown_finale.json"
const TEST_IDENTITY_SAVE := "user://test_crown_finale_identity.json"
const RESULT_CAPTURE := "res://artifacts/identity_system_test/accepted_identity_result.png"

var _original_save_path := ""
var _original_identity_save_path := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var js := root.get_node_or_null("/root/JourneyState")
	if js == null:
		push_error("CROWN_FINALE_TEST: JourneyState missing")
		quit(1)
		return
	_original_save_path = js.save_path
	js.save_path = TEST_SAVE
	js.clear_journey()
	var identity := root.get_node_or_null("/root/PlayerIdentityTracker")
	assert(identity != null, "PlayerIdentityTracker autoload is required")
	_original_identity_save_path = identity.save_path
	identity.save_path = TEST_IDENTITY_SAVE
	identity.clear_evidence()
	assert(identity.record_evidence("MS_ID_01", "energy", "E", "mind_spark"))
	assert(identity.record_evidence("MS_ID_02", "information", "N", "mind_spark"))
	assert(identity.record_evidence("MS_ID_03", "decisions", "F", "mind_spark"))
	assert(identity.record_evidence("MS_ID_04", "structure", "P", "mind_spark"))

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
	# The Heart campaign now owns its separate v2 completion state. This test
	# isolates the downstream Art Castle ceremony after that reward is saved.
	js.treasures["harmony_jewel"] = true
	var creation_id: String = str(js.record_creation("user://test-crown-art.png", "My Light"))
	assert(js.complete_creator_frame_ritual(creation_id, "constellation_mural"))
	js.advance_to(4)
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _i in 50:
		await process_frame
	var crown := gallery.get_node_or_null("Player3D/CrownOfLife")
	var star := gallery.get_node_or_null("IdentityStar")
	var rainbow := gallery.find_child("RainbowGalaxyTrain", true, false)
	var identity_panel := gallery.find_child("IdentityFinalePanel", true, false)
	var accept := gallery.find_child("AcceptIdentityButton", true, false) as Button
	if js.stage != 4 or crown == null or star == null or rainbow == null \
			or identity_panel == null or accept == null:
		_finish(false, "finale incomplete stage=%d crown=%s star=%s train=%s" % [
			js.stage, crown != null, star != null, rainbow != null])
		return
	assert(not identity.identity_locked, "the friendly identity remains a preview until accepted")
	accept.pressed.emit()
	assert(identity.identity_locked and identity.identity_result_code == "ENFP")
	assert(identity.friendly_identity_name() == "The Joyful Creator")
	var star_labels := star.find_children("*", "Label3D", true, false)
	var star_label: Label3D = null
	if not star_labels.is_empty():
		star_label = star_labels[0] as Label3D
	assert(star_label != null and star_label.text.contains("THE JOYFUL CREATOR"),
		"the accepted friendly identity appears on the Art Castle Identity Star")
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
			"res://artifacts/identity_system_test"))
		for _frame in 6:
			await process_frame
		var capture_error := root.get_texture().get_image().save_png(RESULT_CAPTURE)
		assert(capture_error == OK, "accepted identity result screenshot is written")
		print("CROWN_FINALE_CAPTURE: %s" % RESULT_CAPTURE)
	_finish(true, "all three treasures create Crown, accepted friendly identity, named star, and Rainbow Galaxy Train")


func _finish(passed: bool, message: String) -> void:
	var js := root.get_node_or_null("/root/JourneyState")
	js.clear_journey()
	js.save_path = _original_save_path
	var identity := root.get_node_or_null("/root/PlayerIdentityTracker")
	if identity != null:
		identity.clear_evidence()
		identity.save_path = _original_identity_save_path
	if passed:
		print("CROWN_FINALE_TEST: PASS — %s" % message)
		quit()
	else:
		push_error("CROWN_FINALE_TEST: %s" % message)
		quit(1)
