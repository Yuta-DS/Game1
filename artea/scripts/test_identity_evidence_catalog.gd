extends SceneTree

const Quest := preload("res://scripts/mind_spark/mind_spark_world_one_quest.gd")


func _init() -> void:
	var moments := Quest.load_identity_moments()
	assert(moments.size() == 8, "Mind Spark exposes exactly eight identity moments")
	assert(moments.keys() == [0, 1, 2, 3, 4, 5, 8, 9],
		"identity evidence stays attached to the authored quest moments")
	var ids := PackedStringArray()
	var side_counts := {"E": 0, "I": 0, "S": 0, "N": 0, "T": 0, "F": 0, "J": 0, "P": 0}
	for task_index in moments:
		var moment: Dictionary = moments[task_index]
		ids.append(str(moment.id))
		side_counts[moment.side_a] += 1
		side_counts[moment.side_b] += 1
	assert(ids == PackedStringArray(["MS_ID_01", "MS_ID_02", "MS_ID_03", "MS_ID_04",
		"MS_ID_05", "MS_ID_06", "MS_ID_07", "MS_ID_08"]), "save IDs remain stable")
	for side in side_counts:
		assert(side_counts[side] == 2, "each friendly identity side receives two evidence opportunities")
	print("IDENTITY_EVIDENCE_CATALOG: PASS — eight validated, balanced, data-driven moments")
	quit()
