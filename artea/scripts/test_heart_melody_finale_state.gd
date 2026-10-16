extends SceneTree

const State := preload("res://scripts/heart_melody/heart_garden_state.gd")


func _init() -> void:
	var state := State.new("", false)
	_complete_heart_song(state)
	assert(state.heart_song_complete() and not state.harmony_complete())
	assert(not state.enter_beat_anchor_step(0, "sun").accepted)
	for index in 3:
		for step in State.ANCHOR_TARGETS[index]:
			assert(state.enter_beat_anchor_step(index, step).accepted)
		assert(state.data.beat_anchors[index])
	assert(state.task_complete(State.ANCHOR_TASK))
	assert(not state.place_orchestra_fruit("harmony_fig").accepted)
	state.grant_story_fruit("harmony_fig", 6, "finale.fig")
	assert(not state.place_orchestra_fruit("sun_plum").accepted)
	for fruit_id in State.ORCHESTRA_TARGET:
		assert(state.place_orchestra_fruit(fruit_id).accepted)
	for direction in ["up", "right", "left", "down"]:
		state.enter_conduct_direction(direction)
	assert(not state.confirm_orchestra().accepted)
	state.reset_conducting()
	for direction in State.CONDUCT_TARGET:
		state.enter_conduct_direction(direction)
	assert(state.confirm_orchestra().accepted)
	assert(state.harmony_complete() and state.xp() == 719)
	assert(state.data.harmony_rewards_claimed and state.data.checkpoint == "harmony_sanctuary")
	assert(State.valid(state.data))
	assert(state.confirm_orchestra().accepted and state.xp() == 719,
		"finale replay cannot duplicate XP or rewards")
	print("PASS: Beat Anchors, six-fruit orchestra, conducting finale and reward guard")
	quit()


func _complete_heart_song(state: State) -> void:
	state.grant_story_fruit("echo_berry", 3, "finale.echo")
	for index in 3: state.plant(index, "sound")
	for note in State.PHRASE: state.enter_note(note)
	state.confirm_phrase()
	for wave in State.WAVES:
		for enemy_id in wave: state.record_defeat(enemy_id)
		state.finish_wave(wave)
	state.grant_story_fruit("dew_pear", 3, "finale.dew")
	for index in 3: state.set_organ_valve(index, State.ORGAN_TARGET[index])
	state.confirm_organ()
	state.grant_story_fruit("sun_plum", 5, "finale.sun")
	for index in 5: state.set_vine_tension(index, State.VINE_TARGET[index])
	state.confirm_vines()
	state.grant_story_fruit("bell_apple", 4, "finale.bell")
	for direction in State.BELL_TARGET: state.enter_rain_bell(direction)
	state.confirm_rain_bells()
	for index in 3:
		state.set_chime_wind(index, State.CHIME_TARGET[index])
		state.strike_bridge_chime(index)
	state.grant_story_fruit("moon_melon", 3, "finale.moon")
	for channel in State.WARNING_TARGET: state.enter_warning_channel(channel)
	state.confirm_warning_path()
	for motif in State.LOOM_TARGET: state.enter_loom_motif(motif)
	state.confirm_loom()
