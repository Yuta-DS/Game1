extends SceneTree


func _init() -> void:
	var quest := MindSparkWorldOneQuest.new()
	quest.call("_build_hud")
	var canvas := quest.get_node("MindSparkQuestHUD") as CanvasLayer
	var panel := canvas.get_node("QuestPanel") as Panel
	var compact_minimap_right := 18.0 + 286.0
	assert(panel.position.x >= compact_minimap_right + 14.0,
		"World One objective card must not cover the compact minimap")
	assert(panel.position.y <= 24.0 and panel.size == Vector2(560, 244),
		"objective card uses the compact top-row layout")
	assert(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the HUD must not block pointer input into the game")
	assert(panel.get_node("CelestialAccent") is ColorRect,
		"the finished objective card keeps a readable cyan hierarchy accent")
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert(style != null and style.corner_radius_top_left == 12 and style.shadow_size == 8,
		"objective card uses a rounded, separated production finish")
	for label in panel.find_children("*", "Label", true, false):
		assert((label as Label).mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var labels: Array[Node] = panel.find_children("*", "Label", true, false)
	for index in range(labels.size() - 1):
		var current := labels[index] as Label
		var following := labels[index + 1] as Label
		assert(current.position.y + current.size.y <= following.position.y,
			"objective card text rows must not overlap")
	quest.free()
	print("WORLD_ONE_QUEST_HUD: PASS — objective card clears the minimap, preserves input and uses finished celestial styling")
	quit()
