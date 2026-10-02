extends SceneTree

const TEST_SAVE := "user://test_crown_finale.json"

var _original_save_path := ""
var _identity_original_save_path := ""


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
	var identity := root.get_node_or_null("/root/PlayerIdentityTracker")
	assert(identity != null, "shared identity tracker is available at the finale")
	_identity_original_save_path = identity.save_path
	identity.save_path = "user://test_crown_finale_identity.json"
	identity.clear_evidence()
	assert(identity.record_evidence("MS_ID_01", "energy", "I"))
	assert(identity.record_evidence("MS_ID_02", "information", "N"))
	assert(identity.record_evidence("MS_ID_03", "decisions", "F"))
	assert(identity.record_evidence("MS_ID_04", "structure", "P"))
	assert(identity.identity_result_code.is_empty(), "identity remains hidden before the finale")

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
	# Heart Melody's full adventure is being delivered separately from this
	# finale fixture. Seed its canonical earned reward directly, as the other
	# transit/finale integration fixtures do, without reviving the retired
	# "one emotion grants a treasure" shortcut.
	js.treasures["harmony_jewel"] = true
	js.save()
	var creation_id: String = str(js.record_creation("user://test-crown-art.png", "My Light"))
	js.complete_creator_frame_ritual(creation_id, "constellation_mural")
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _i in 50:
		await process_frame
	var crown := gallery.get_node_or_null("Player3D/CrownOfLife")
	var star := gallery.get_node_or_null("IdentityStar")
	var rainbow := gallery.find_child("RainbowGalaxyTrain", true, false)
	var star_labels := star.find_children("*", "Label3D", true, false)
	var star_label := star_labels[0] as Label3D if not star_labels.is_empty() else null
	var reveal_text := star_label.text if star_label != null else ""
	var identity_revealed: bool = identity.identity_result_code == "INFP" \
		and identity.identity_locked and identity.identity_reveal_seen \
		and reveal_text.contains("The Gentle Peacemaker") \
		and not reveal_text.contains("INFP")
	if js.stage != 4 or crown == null or star == null or rainbow == null or not identity_revealed:
		_finish(false, "finale incomplete stage=%d crown=%s star=%s train=%s identity=%s reveal=%s" % [
			js.stage, crown != null, star != null, rainbow != null,
			identity.identity_result_code, reveal_text])
		return
	_finish(true, "all three treasures create Crown, named star, Rainbow Galaxy Train, and friendly identity reveal")


func _finish(passed: bool, message: String) -> void:
	var js := root.get_node_or_null("/root/JourneyState")
	js.clear_journey()
	js.save_path = _original_save_path
	var identity := root.get_node_or_null("/root/PlayerIdentityTracker")
	if identity != null:
		identity.clear_evidence()
		identity.save_path = _identity_original_save_path
	if passed:
		print("CROWN_FINALE_TEST: PASS — %s" % message)
		quit()
	else:
		push_error("CROWN_FINALE_TEST: %s" % message)
		quit(1)
