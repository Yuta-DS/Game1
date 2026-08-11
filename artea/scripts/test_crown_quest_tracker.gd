# Focused, save-independent quest tracker test.
#   godot --headless --path artea --script res://scripts/test_crown_quest_tracker.gd
extends SceneTree

const TrackerScript = preload("res://scripts/crown_quest_tracker.gd")


func _init() -> void:
	_test_order_and_evidence_matching()
	_test_complete_journey_and_localization()
	_test_snapshot_round_trip_and_rejection()
	print("CrownQuestTracker: all checks passed")
	quit()


func _test_order_and_evidence_matching() -> void:
	var tracker = TrackerScript.new()
	assert(tracker.is_catalog_valid(), "validated catalog loads")
	assert(tracker.current_objective()["kind"] == "prologue", "prologue is first")
	assert(not tracker.submit_evidence("thought_cloud_selected")["accepted"],
		"known task evidence is rejected out of order")
	assert(not tracker.submit_evidence("invented_event")["accepted"], "unknown evidence is rejected")
	assert(tracker.submit_evidence("story.prologue.complete")["accepted"], "explicit prologue completion advances")
	assert(tracker.current_objective()["id"] == "mind.listen.notice", "first Mind task becomes current")
	var first := tracker.submit_evidence("thought_cloud_selected")
	assert(first["accepted"] and first["completed_task_ids"] == ["mind.listen.notice"],
		"matching evidence completes only its authored task")
	var replay := tracker.submit_evidence("thought_cloud_selected")
	assert(replay["accepted"] and replay["reason"] == "already_complete",
		"replay is idempotent")
	assert(tracker.completed_tasks.size() == 1, "replay never duplicates completion")
	assert(not tracker.submit_evidence("treasure_awarded", {"value": "harmony_jewel"})["accepted"],
		"payload match cannot bypass prerequisites")
	assert(not tracker.submit_evidence("treasure_awarded", {"value": "unknown"})["accepted"],
		"unknown payload is rejected")
	assert(tracker.export_snapshot().keys().all(func(key):
		return key in ["version", "story_id", "completed_task_ids", "completed_milestone_ids"]),
		"snapshot contains progress IDs only")
	tracker = null


func _test_complete_journey_and_localization() -> void:
	var tracker = TrackerScript.new()
	assert(tracker.submit_evidence("story.prologue.complete")["accepted"])
	_complete_arc_tasks(tracker, "mind")
	assert(tracker.is_arc_complete("mind"), "Mind reward follows its receive task")
	assert(not tracker.is_arc_ready("heart"), "Heart waits for the Castle interlude")
	assert(tracker.current_objective()["id"] == "return_with_wisdom")
	assert(tracker.submit_evidence("castle.return.wisdom")["accepted"])
	assert(tracker.is_arc_ready("heart"))
	_complete_arc_tasks(tracker, "heart")
	assert(tracker.submit_evidence("castle.return.harmony")["accepted"])
	_complete_arc_tasks(tracker, "creator")
	assert(tracker.submit_evidence("castle.return.creation")["accepted"])
	assert(tracker.is_finale_ready(), "all three treasures and return unlock finale")
	var faith := tracker.localized_objective("faith")
	var universal := tracker.localized_objective("universal")
	assert(faith["kind"] == "finale" and faith["dialogue"].contains("God"),
		"faith finale presentation is authored")
	assert(universal["kind"] == "finale" and not universal["dialogue"].contains("God"),
		"universal finale presentation is independently authored")
	assert(tracker.submit_evidence("story.finale.complete")["accepted"])
	assert(tracker.is_finale_complete() and tracker.current_objective()["kind"] == "complete")
	tracker = null


func _test_snapshot_round_trip_and_rejection() -> void:
	var tracker = TrackerScript.new()
	tracker.submit_evidence("story.prologue.complete")
	tracker.submit_evidence("thought_cloud_selected")
	tracker.submit_evidence("thought_effect_selected")
	var snapshot := tracker.export_snapshot()
	var restored = TrackerScript.new()
	assert(restored.import_snapshot(snapshot), "valid plain Dictionary snapshot imports")
	assert(restored.export_snapshot() == snapshot, "snapshot round trip is exact")

	var unknown: Dictionary = snapshot.duplicate(true)
	unknown["completed_task_ids"].append("unknown.task")
	assert(not restored.import_snapshot(unknown), "unknown snapshot IDs are rejected")
	assert(restored.export_snapshot() == snapshot, "failed import leaves prior state untouched")

	var out_of_order := {
		"version": 1,
		"story_id": "crown_of_life",
		"completed_task_ids": ["heart.voices.listen"],
		"completed_milestone_ids": ["story.prologue.complete"],
	}
	assert(not restored.import_snapshot(out_of_order), "out-of-order snapshot is rejected")
	assert(restored.export_snapshot() == snapshot, "rejected snapshot cannot corrupt state")

	var detached_reward = TrackerScript.new()
	detached_reward.submit_evidence("story.prologue.complete")
	_complete_arc_tasks(detached_reward, "mind")
	var inconsistent: Dictionary = detached_reward.export_snapshot()
	inconsistent["completed_milestone_ids"].erase("treasure.star_of_wisdom")
	assert(not restored.import_snapshot(inconsistent),
		"receive task and treasure cannot be separated in an imported snapshot")

	var personal_field: Dictionary = snapshot.duplicate(true)
	personal_field["player_name"] = "Must not be retained"
	assert(restored.import_snapshot(personal_field), "unrecognized personal fields are ignored")
	assert(not restored.export_snapshot().has("player_name"), "personal content is never retained")
	tracker = null
	restored = null
	detached_reward = null


func _complete_arc_tasks(tracker, arc_id: String) -> void:
	var arc: Dictionary = tracker.catalog["kingdom_arcs"].filter(func(item): return item["id"] == arc_id)[0]
	for quest in arc["quests"]:
		for task in quest["tasks"]:
			var evidence: Dictionary = task["completion_evidence"]
			var payload := {}
			for key in evidence:
				if key not in ["type", "event"]:
					payload[key] = evidence[key]
			var result: Dictionary = tracker.submit_evidence(evidence["event"], payload)
			assert(result["accepted"], "%s evidence accepted: %s" % [task["id"], result])
			assert(tracker.is_task_complete(task["id"]), "%s completed" % task["id"])
