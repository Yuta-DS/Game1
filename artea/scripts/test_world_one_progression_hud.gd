extends SceneTree

const ProgressionScript := preload("res://scripts/world_one_progression.gd")
const HUDScript := preload("res://scripts/mind_spark/world_one_progression_hud.gd")
const TEST_PATH := "user://test_world_one_progression_hud.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := ProgressionScript.new()
	root.add_child(state)
	state.configure_save_path(TEST_PATH, false)
	state.clear_progress()
	state.call("_load_catalog")
	state.grant_quest_reward("world_one.checkpoint.landing")
	state.grant_quest_reward("world_one.path_projector")
	var hud := HUDScript.new()
	hud.progression = state
	root.add_child(hud)
	await process_frame
	assert(hud.is_in_group("world_one_progression_hud"),
		"the field kit claims World One's inventory action from the legacy panel")
	assert(hud.get_node("ProgressSummary") != null)
	assert(hud.get_node("ProgressionInventory") != null)
	assert(hud.get("_tab_bar").get_child_count() == 5,
		"the field kit exposes Equipment, Materials, Crafting, Quest Items and Collection")
	hud.set_open(true)
	assert(hud.is_open() and hud.mouse_filter == Control.MOUSE_FILTER_STOP)
	hud.call("_select_tab", "Materials")
	await process_frame
	var content := hud.get("_content") as VBoxContainer
	assert(content.get_child_count() > 0, "the material inventory renders collected rewards")
	hud.set_open(false)
	assert(not hud.is_open())
	state.clear_progress()
	hud.queue_free()
	state.queue_free()
	await process_frame
	print("WORLD_ONE_PROGRESSION_HUD: PASS — five-tab field kit opens, renders rewards and closes safely")
	quit()
