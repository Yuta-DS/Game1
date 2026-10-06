extends SceneTree

const IdentityTracker := preload("res://scripts/player_identity_tracker.gd")
const TEST_SAVE := "user://test_player_identity_tracker.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var tracker := IdentityTracker.new()
	tracker.save_path = TEST_SAVE
	root.add_child(tracker)
	await process_frame
	assert(tracker.preview_identity().is_empty(),
		"identity cannot be inferred before every axis has explicit evidence")
	var records := [
		["MS_ID_01", "energy", "E", "quest.signal_observatory", "wake_two_roots"],
		["MS_ID_02", "information", "N", "quest.echo_forest", "collect_two_sparks"],
		["MS_ID_03", "decisions", "F", "quest.cross_seam_relay", "scan_fact_fear"],
		["MS_ID_04", "structure", "P", "quest.cross_seam_relay", "restore_memory"],
	]
	for item in records:
		assert(tracker.record_evidence(item[0], item[1], item[2], "mind_spark", {
			"canonical_quest_id": item[3], "task_id": item[4],
			"source": "optional_post_task_reflection",
		}))
	assert(tracker.record_evidence("MS_ID_01", "energy", "I", "mind_spark"),
		"replaying an existing evidence ID is idempotent")
	assert(int(tracker.identity_axis_counts.E) == 1 and int(tracker.identity_axis_counts.I) == 0,
		"only the first explicit answer counts")
	assert(tracker.evidence_for_world("mind_spark").size() == 4)
	assert(tracker.evidence_for_quest("quest.cross_seam_relay").size() == 2)
	assert(tracker.preview_identity() == "ENFP")
	assert(tracker.friendly_identity_name("ENFP") == "The Joyful Creator")
	assert(not tracker.identity_locked and tracker.identity_result_code.is_empty(),
		"previewing never locks or publishes the result")
	assert(tracker.finalize_identity() == "ENFP" and tracker.identity_locked,
		"the Art Castle acceptance action locks the friendly result")
	assert(not tracker.record_evidence("HM_ID_01", "energy", "I", "heart_melody"),
		"evidence cannot change after the finale result is accepted")
	tracker.mark_reveal_seen()
	tracker.load_evidence()
	assert(tracker.identity_locked and tracker.identity_reveal_seen)
	assert(tracker.identity_answer_history.size() == 4 \
		and str(tracker.identity_answer_history[2].canonical_quest_id) == "quest.cross_seam_relay",
		"save/reload preserves quest and task provenance")
	print("PLAYER_IDENTITY_TRACKER: PASS — optional quest evidence, first-answer lock, preview, acceptance and reload")
	tracker.queue_free()
	await process_frame
	_cleanup()
	quit()


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
