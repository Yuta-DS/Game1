extends SceneTree
const Progress = preload("res://scripts/heart_melody/heart_progress.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("FAIL: " + label)

func run() -> void:
	var state = Progress.new()
	state.path = "user://heart_safety_test.json"
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(state.path + suffix))
	for i in 3: check(state.plant(i, 6), "plant commits")
	state.edit_phrase([0, 2])
	var reload = Progress.new()
	reload.path = state.path
	reload.load_progress()
	check(reload.data.phrase == [0, 2] and reload.data.planters.size() == 3, "partial reload preserves independent planters and phrase")
	state.edit_phrase([0, 2, 1])
	state.solve()
	state.clear_wave(1)
	state.path = "res://missing_directory/invalid.json"
	check(not state.clear_wave(2), "completion write can fail")
	check(state.data.complete and not state.committed.complete and state.data.xp == 119, "failed completion stays in session without granting route")
	state.path = reload.path
	check(state.commit(), "retry commits entire reward transaction")
	check(state.clear_wave(2) and state.data.xp == 119, "retry receipts are idempotent")
	reload.load_progress()
	check(reload.data.complete and reload.data.xp == 119, "completed transaction reloads")
	state.path = "res://missing_directory/invalid.json"
	state.plant(0, 1)
	check(state.committed.complete and state.dirty, "failed cosmetic save cannot close an earned crossing")
	for mutation in [
		{"waves": [2]}, {"waves": [1, 1, 2]}, {"waves": [1, 3]},
		{"tasks": []}, {"campaign_version": 99}, {"schema": {}},
		{"planters": {"0": 1.5, "1": 6, "2": 6}},
		{"checkpoint": "arrival"}, {"receipts": {"quest_one": 80}, "xp": 80},
		{"solved": false}, {"phrase": [0, 2.5, 1]}, {"complete": false}]:
		var bad: Dictionary = reload.data.duplicate(true)
		bad.merge(mutation, true)
		check(not Progress.valid(bad), "reject inconsistent save " + str(mutation))
	check(not state.edit_phrase(["0"]), "reject nonnumeric input")
	var file := FileAccess.open(reload.path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	reload.load_progress()
	check(reload.data.complete and reload.dirty and not reload.recovery_message.is_empty(), "backup recovery is visible and retryable")
	check(reload.commit(), "recovered backup repairs primary")
	print("HEART SAVE SAFETY: all checks passed" if failures.is_empty() else "HEART SAVE SAFETY FAILURES: " + str(failures))
	quit(0 if failures.is_empty() else 1)
