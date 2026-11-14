extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var railway := Node3D.new()
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	var none := {"star_of_wisdom": false, "harmony_jewel": false, "creators_light": false}
	assert(railway.call("completed_destination_indices_with", none) == PackedInt32Array([0]),
		"unfinished Mind Spark is entered through its World Gate, not the train")
	var mind_complete := none.duplicate()
	mind_complete.star_of_wisdom = true
	assert(railway.call("completed_destination_indices_with", mind_complete) == PackedInt32Array([0, 1]),
		"Star of Wisdom adds Mind Spark to the completed-world destination list")
	var heart_complete := mind_complete.duplicate()
	heart_complete.harmony_jewel = true
	assert(railway.call("completed_destination_indices_with", heart_complete) == PackedInt32Array([0, 1, 2]))
	var all_complete := heart_complete.duplicate()
	all_complete.creators_light = true
	assert(railway.call("completed_destination_indices_with", all_complete) == PackedInt32Array([0, 1, 2, 3]))
	railway.free()
	print("MindSparkCompletedTrainPolicy: all checks passed")
	quit()
