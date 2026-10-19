extends SceneTree

const State := preload("res://scripts/heart_melody/heart_garden_state.gd")


func _init() -> void:
	var path := "user://test_heart_fruit_%d.json" % Time.get_ticks_usec()
	var legacy := State.fresh()
	legacy.schema_version = 1
	legacy.erase("quest_fruit_pouch")
	legacy.erase("fruit_inventory")
	legacy.erase("checkpoint_storage")
	legacy.erase("fruit_receipt_ids")
	legacy.erase("crafted_recipe_ids")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var state := State.new(path)
	assert(state.load_progress(), "schema-1 Heart Garden save migrates")
	assert(state.data.schema_version == State.SCHEMA_VERSION)
	assert(state.data.quest_fruit_pouch.is_empty() and state.data.fruit_inventory.is_empty())
	assert(state.grant_story_fruit("echo_berry", 3, "story.echo.intro").accepted)
	assert(state.story_fruit_count("echo_berry") == 3)
	assert(state.grant_story_fruit("echo_berry", 3, "story.echo.intro").accepted)
	assert(state.story_fruit_count("echo_berry") == 3,
		"story receipt prevents duplicate fruit")
	assert(state.grant_crafting_fruit("sun_plum", 105, "harvest.sun.1").accepted)
	assert(state.crafting_fruit_count("sun_plum") == 99)
	assert(state.checkpoint_fruit_count("sun_plum") == 6,
		"fruit overflow moves to checkpoint storage")
	assert(state.grant_crafting_fruit("echo_berry", 2, "harvest.echo.1").accepted)
	assert(state.craft_recipe("echo_nectar").accepted)
	assert(state.crafting_fruit_count("echo_berry") == 0)
	assert(state.story_fruit_count("echo_berry") == 3,
		"crafting never consumes protected story fruit")
	assert(state.craft_recipe("echo_nectar").accepted,
		"an authored recipe is a one-time receipt")
	assert(not state.craft_recipe("missing_recipe").accepted)
	assert(State.valid(state.data))
	var invalid := state.data.duplicate(true)
	invalid.fruit_inventory.sun_plum = 100
	assert(not State.valid(invalid), "inventory stack limit is enforced")
	var reloaded := State.new(path)
	assert(reloaded.load_progress())
	assert(reloaded.story_fruit_count("echo_berry") == 3)
	assert("echo_nectar" in reloaded.data.crafted_recipe_ids)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("HEART_MELODY_FRUIT_STATE: PASS — legacy migration, protected story fruit, stack overflow and recipe receipts")
	quit()
