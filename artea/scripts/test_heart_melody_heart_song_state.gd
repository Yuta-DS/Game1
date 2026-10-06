extends SceneTree

const State := preload("res://scripts/heart_melody/heart_garden_state.gd")


func _init() -> void:
	var state := State.new("", false)
	_complete_river(state)
	assert(state.river_complete() and state.xp() == 224)
	for index in 3:
		state.set_chime_wind(index, State.CHIME_TARGET[index])
		assert(state.strike_bridge_chime(index).accepted)
	assert(state.task_complete(State.CHIME_TASK))
	assert(state.data.checkpoint == "chime_bridge")
	assert(not state.enter_warning_channel("left").accepted)
	state.grant_story_fruit("moon_melon", 3, "heart.moon")
	for channel in ["right", "centre", "left", "centre"]:
		state.enter_warning_channel(channel)
	assert(not state.confirm_warning_path().accepted)
	state.revise_warning_path(true)
	for channel in State.WARNING_TARGET:
		state.enter_warning_channel(channel)
	assert(state.confirm_warning_path().accepted)
	for motif in ["chime", "harp", "water", "drum"]:
		state.enter_loom_motif(motif)
	assert(not state.confirm_loom().accepted)
	state.revise_loom(true)
	for motif in State.LOOM_TARGET:
		state.enter_loom_motif(motif)
	assert(state.confirm_loom().accepted)
	assert(state.heart_song_complete() and state.xp() == 354)
	assert(State.valid(state.data))
	assert(state.confirm_loom().accepted and state.xp() == 354)
	print("PASS: Bridge Chimes, Warning Bell Path and Heart Song Loom state and rewards")
	quit()


func _complete_river(state: State) -> void:
	state.grant_story_fruit("echo_berry", 3, "base.echo")
	for index in 3: state.plant(index, "sound")
	for note in State.PHRASE: state.enter_note(note)
	state.confirm_phrase()
	for wave in State.WAVES:
		for enemy_id in wave: state.record_defeat(enemy_id)
		state.finish_wave(wave)
	state.grant_story_fruit("dew_pear", 3, "base.dew")
	for index in 3: state.set_organ_valve(index, State.ORGAN_TARGET[index])
	state.confirm_organ()
	state.grant_story_fruit("sun_plum", 5, "base.sun")
	for index in 5: state.set_vine_tension(index, State.VINE_TARGET[index])
	state.confirm_vines()
	state.grant_story_fruit("bell_apple", 4, "base.bell")
	for direction in State.BELL_TARGET: state.enter_rain_bell(direction)
	state.confirm_rain_bells()
