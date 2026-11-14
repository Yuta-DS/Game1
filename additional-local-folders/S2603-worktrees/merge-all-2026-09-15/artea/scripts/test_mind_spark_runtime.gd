# Focused runtime contract for the existing Mind Spark cloud scene.
#   godot --headless --path artea --script res://scripts/test_mind_spark_runtime.gd
#
# This test stays narrow: it protects the authored Cloud_3d scene node name
# and the invariant that completion requires zero live clouds. It reads scene
# text rather than instantiating imported art assets, so it remains usable
# while Godot's generated import cache is deliberately absent.
extends SceneTree

const CLOUD_SCENE_PATH := "res://scenes/Cloud_3d.tscn"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cloud_source := FileAccess.get_file_as_string("res://scenes/cloud_3d.gd")
	var ui_source := FileAccess.get_file_as_string("res://scripts/cloud_pop_ui.gd")
	var scene_source := FileAccess.get_file_as_string(CLOUD_SCENE_PATH)

	assert(ResourceLoader.exists(CLOUD_SCENE_PATH), "the Cloud_3d scene exists")
	assert(scene_source.contains('[node name="CLoudMesh"'),
		"the scene retains its authored CLoudMesh sprite node")
	assert(cloud_source.contains("$CLoudMesh"),
		"Cloud3d resolves the exact CLoudMesh node authored in its scene")
	assert(not cloud_source.contains("$CloudMesh"),
		"Cloud3d does not use the stale CloudMesh node path")
	assert(ui_source.contains("return cloud_spawner.get_child_count() == 0"),
		"Mind Spark only completes after zero live clouds remain")
	assert(ui_source.contains("const THOUGHT_ECHOES"),
		"Mind Spark defines an authored Thought Echo catalogue")
	for echo_id in ["learning", "brave_step", "ask_for_help", "rest"]:
		assert(ui_source.contains('"id": "%s"' % echo_id),
			"Thought Echo catalogue includes %s" % echo_id)
	assert(ui_source.contains("ThoughtEchoPanel"),
		"Mind Spark builds a visible curated Thought Echo surface")
	assert(ui_source.contains("Skip for now"),
		"Mind Spark keeps an explicit no-progress skip path")
	assert(ui_source.contains("input_field.editable = false")
		and ui_source.contains("input_field.hide()"),
		"legacy text entry is disabled and hidden by default")
	assert(not ui_source.contains("text_submitted.connect"),
		"no free-text submit signal is connected")
	assert(not ui_source.contains("input_field.text")
		and not ui_source.contains("input_field.grab_focus"),
		"legacy text content is never read or focused")
	assert(not ui_source.contains("func spawn_cloud"),
		"only the curated cloud spawning route remains")
	assert(ui_source.contains("_spawn_curated_cloud(echo_text, echo_id)")
		and ui_source.contains("JourneyState.record_thought_echo(echo_text, echo_id)"),
		"JourneyState records only deliberately selected authored cards with encounter evidence")
	assert(ui_source.contains("const MINIMUM_THOUGHT_ECHOES := 2")
		and ui_source.contains("JourneyState.complete_mind_spark(MINIMUM_THOUGHT_ECHOES)")
		and ui_source.find("JourneyState.complete_mind_spark(MINIMUM_THOUGHT_ECHOES)") > ui_source.find("are_all_clouds_popped()"),
		"Star completion is requested only from the all-clouds-resolved branch")
	for forbidden in ["HTTPRequest", "NobodyWhoChat", "NobodyWhoModel", ".say("]:
		assert(not ui_source.contains(forbidden),
			"Mind Spark does not contain %s" % forbidden)
	for inferential_phrase in ["trying to protect", "What is it afraid", "When does this thought show up"]:
		assert(not ui_source.contains(inferential_phrase),
			"hold prompts avoid inferential wording: %s" % inferential_phrase)
	assert(cloud_source.contains("parent.remove_child(self)"),
		"a resolved cloud leaves the spawner before reporting completion")
	assert(cloud_source.contains("if resolving:"),
		"a cloud cannot report completion twice during its pop animation")

	print("Mind Spark runtime: all checks passed")
	quit()
