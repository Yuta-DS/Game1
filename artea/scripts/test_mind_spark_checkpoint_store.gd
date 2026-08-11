extends SceneTree

const Director := preload("res://scripts/mind_spark/mind_spark_encounter_director.gd")
const Store := preload("res://scripts/mind_spark/mind_spark_checkpoint_store.gd")
const TEST_PATH := "user://test_mind_spark_checkpoint.json"


func _init() -> void:
	var store = Store.new(TEST_PATH)
	store.clear()
	var source = Director.new()
	source.configure_solo(true, Director.LENS_ALARM)
	source.start_current_encounter()
	source.perform_action("observatory.scan_signal", "solo_player")
	source.ping_solo_companion("observatory.hear_chime")
	assert(store.save(source))
	var restored = Director.new()
	var signal_count := 0
	restored.evidence_emitted.connect(func(_id: String, _payload: Dictionary): signal_count += 1)
	restored.phase_changed.connect(func(_phase: String): signal_count += 1)
	restored.completion_requested.connect(func(_id: String): signal_count += 1)
	assert(store.load_into(restored))
	assert(signal_count == 0, "restore emits no progress or reward signals")
	assert(restored.phase == source.phase and restored.current_step_index == source.current_step_index)
	assert(restored.get("_receipts").keys() == source.get("_receipts").keys())
	var corrupt := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	corrupt.store_string('{"schema_version":1,"phase":"complete"}')
	corrupt.close()
	assert(not store.load_into(Director.new()), "completion snapshots are rejected")
	source.phase = Director.PHASE_SKIPPED
	assert(store.snapshot(source).is_empty(), "skipped sessions are never checkpointed")
	assert(store.clear())
	print("MindSparkCheckpointStore: all checks passed")
	quit()
