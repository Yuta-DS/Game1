extends SceneTree

const State := preload("res://scripts/heart_melody/heart_garden_state.gd")


func _init() -> void:
	var state := State.new("", false)
	_complete_feeling_garden(state)
	assert(state.complete())
	assert(state.xp() == 119)
	assert(not state.set_organ_valve(0, 1).accepted)
	state.grant_story_fruit("dew_pear", 3, "river.dew")
	assert(not state.confirm_organ().accepted)
	assert(state.data.river_attempts.organ == 1)
	for index in 3:
		state.set_organ_valve(index, State.ORGAN_TARGET[index])
	assert(state.confirm_organ().accepted)
	assert(state.data.checkpoint == "river_organ")
	state.grant_story_fruit("sun_plum", 5, "river.sun")
	for index in 5:
		state.set_vine_tension(index, State.VINE_TARGET[index])
	assert(state.confirm_vines().accepted)
	assert(state.data.checkpoint == "river_harp")
	state.grant_story_fruit("bell_apple", 4, "river.bells")
	for direction in ["north", "west", "south", "east"]:
		state.enter_rain_bell(direction)
	assert(not state.confirm_rain_bells().accepted)
	assert(state.data.river_attempts.bells == 1)
	state.revise_rain_bells(true)
	for direction in State.BELL_TARGET:
		state.enter_rain_bell(direction)
	assert(state.confirm_rain_bells().accepted)
	assert(state.river_complete())
	assert(state.xp() == 224)
	assert(state.confirm_rain_bells().accepted)
	assert(state.xp() == 224)
	assert(State.valid(state.data))
	_test_schema_two_migration()
	print("PASS: River Voice state, prerequisites, retries, rewards and migration")
	quit()


func _complete_feeling_garden(state: State) -> void:
	state.grant_story_fruit("echo_berry", 3, "intro.echo")
	for index in 3:
		state.plant(index, "sound")
	for note in State.PHRASE:
		state.enter_note(note)
	state.confirm_phrase()
	for enemy_id in State.WAVES[0]:
		state.record_defeat(enemy_id)
	state.finish_wave(State.WAVES[0])
	for enemy_id in State.WAVES[1]:
		state.record_defeat(enemy_id)
	state.finish_wave(State.WAVES[1])


func _test_schema_two_migration() -> void:
	var path := "user://heart_melody_river_migration.json"
	var legacy := State.fresh()
	legacy.schema_version = 2
	for key in ["river_organ", "hush_vines", "rain_bells", "river_attempts"]:
		legacy.erase(key)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var loaded := State.new(path, true)
	assert(loaded.load_progress())
	assert(loaded.data.schema_version == State.SCHEMA_VERSION)
	assert(loaded.data.river_organ == [0, 0, 0])
	assert(loaded.data.hush_vines == [0, 0, 0, 0, 0])
	assert(loaded.data.rain_bells.is_empty())
	assert(State.valid(loaded.data))
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bak")
