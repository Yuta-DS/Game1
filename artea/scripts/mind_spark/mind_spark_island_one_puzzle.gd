class_name MindSparkIslandOnePuzzle
extends Node3D

## Island One's complete, untimed tutorial puzzle. The authored architecture
## supplies the meshes; this controller owns interaction, feedback, replay and
## persistent state without taking save/heal away from the checkpoint root.

signal puzzle_solved(result: Dictionary)
signal puzzle_state_changed(state: Dictionary)
signal quest_completed(quest_id: String, reward: Dictionary)

const StateStore := preload("res://scripts/mind_spark/quest_objects/quest_object_state_store.gd")
const SAVE_ID := "world_one.island_one_aether_compass"
const REGULATOR_TARGETS := [1, 2]
const HARMONY_PROFILES := [
	{"id": "calm_contrast", "name": "CALM CONTRAST", "regulators": [1, 2],
		"seed_pattern": [0, 1, 2],
		"targets": [1, 0, 5], "art_science": "COMPLEMENTARY BALANCE",
		"psychology": "COGNITIVE DEFUSION",
		"clue": "WARM LIGHT HOLDS THE CENTRE • COOL LIGHT MAKES SPACE"},
	{"id": "curious_counterpoint", "name": "CURIOUS COUNTERPOINT", "regulators": [2, 1],
		"seed_pattern": [1, 2, 0],
		"targets": [5, 5, 0], "art_science": "RHYTHMIC COUNTERPOINT",
		"psychology": "ATTENTIONAL FLEXIBILITY",
		"clue": "REPEAT A RHYTHM • THEN LET ONE VOICE ANSWER DIFFERENTLY"},
	{"id": "courageous_asymmetry", "name": "COURAGEOUS ASYMMETRY", "regulators": [2, 2],
		"seed_pattern": [2, 0, 1],
		"targets": [4, 5, 5], "art_science": "DYNAMIC ASYMMETRY",
		"psychology": "COGNITIVE REAPPRAISAL",
		"clue": "THE COMPOSITION MAY LEAN • ITS VISUAL WEIGHT MUST STILL BALANCE"},
]
const CONSTELLATION_DIRECTIONS := [
	"NORTH", "NORTHEAST", "EAST", "SOUTHEAST",
	"SOUTH", "SOUTHWEST", "WEST", "NORTHWEST",
]
const AUTHORED_THOUGHT := "What if I get it wrong?"
const THOUGHT_CATEGORIES := [
	"UNREAD", "WORRY", "CURIOSITY", "FEAR", "DREAM", "HOPE", "DOUBT", "COURAGE",
]
const THOUGHT_EFFECTS := [
	"I CAN PAUSE AND OBSERVE", "EVERYTHING FEELS URGENT", "I NOTICE A PATTERN",
	"MY ATTENTION NARROWS", "A POSSIBILITY OPENS", "NOT SURE YET",
	"I NEED MORE EVIDENCE", "I CAN HOLD TWO IDEAS",
]
const GROUNDED_RESPONSES := [
	"I CAN PAUSE AND LOOK AGAIN", "I CAN TAKE ONE SMALL STEP",
	"MISTAKES CAN HELP ME LEARN", "I CAN ASK FOR HELP",
	"I CAN TEST ANOTHER COMPOSITION", "I CAN CHOOSE A HOPEFUL RESPONSE",
	"I CAN GATHER MORE EVIDENCE", "I CAN CREATE A NEW WAY FORWARD",
]
const CONTROL_ORDER := [
	"colour_prism", "rhythm_prism", "weight_prism", "analysis_console",
	"west_regulator", "east_regulator", "outer_ring", "middle_ring", "inner_ring", "confirm",
	"echo_collector", "echo_signal_1", "echo_signal_2", "echo_signal_3",
	"echo_question", "echo_beacon",
]
const SEED_NAMES := ["THOUGHT", "FEELING", "CHOICE"]
const ECHO_CATEGORIES := ["FACT", "POSSIBILITY", "UNSURE"]
const ECHO_TARGETS := [0, 1, 2]
const ECHO_PHASE_TARGETS := [3, 6, 1]
const ECHO_SIGNALS := [
	"I PRACTICED ONE STEP YESTERDAY",
	"I MIGHT NEED ANOTHER ATTEMPT",
	"I DO NOT YET KNOW HOW THE FINAL PATTERN WILL FEEL",
]
const PROTECTIVE_QUESTIONS := [
	"HOW CAN I MAKE SURE NOTHING EVER GOES WRONG?",
	"SHOULD I AVOID THE MACHINE COMPLETELY?",
	"WHAT ONE SMALL PREPARATION WOULD HELP?",
	"DOES THIS WORRY PROVE I CANNOT CONTINUE?",
]
const PROTECTIVE_QUESTION_TARGET := 2

var state_store_path := StateStore.DEFAULT_PATH
var interaction_range := 12.0
var current_state: Dictionary = {}
var _store := StateStore.new()
var _configured := false
var _setup_complete := false
var _feedback_seconds := 0.0
var _feedback_text := ""
var _rotor_phase := 0.0
var _adjustment_history: Array[Dictionary] = []
var _governor_rotors: Array[Node3D] = []
var _bridge_energy_packets: Array[MeshInstance3D] = []
var _light_beam_pulses: Array[MeshInstance3D] = []
var _echo_root_pulses: Array[MeshInstance3D] = []
var _analysis_rotor: Node3D


func configure(custom_store_path: String, scale_factor: float) -> void:
	state_store_path = custom_store_path
	interaction_range = maxf(6.0, 12.0 * scale_factor)
	_configured = true
	if is_node_ready():
		_setup()


func _ready() -> void:
	if _configured:
		_setup()


func _setup() -> void:
	if _setup_complete:
		return
	_setup_complete = true
	_store = StateStore.new(state_store_path)
	current_state = _default_state()
	var restored := _store.load_object(SAVE_ID)
	if not restored.is_empty():
		current_state.merge(restored, true)
		# Preserve partially collected legacy saves without asking players to
		# repeat earned work. New games require installation and separate capture.
		if not restored.has("echo_captured"):
			var count := int(restored.get("echo_collected",0))
			current_state.echo_captured = [count > 0,count > 1,count > 2]
			current_state.prism_installed = count > 0 or bool(restored.get("echo_garden_complete",false))
	_cache_animation_nodes()
	_apply_state(false)
	set_process(true)


func _cache_animation_nodes() -> void:
	## The arrival hierarchy contains thousands of authored parts. Recursively
	## searching it four times per rendered frame caused a shared Web CPU cost in
	## every district. These animated pieces are all constructed before configure,
	## so resolve them once and keep their inspectable nodes intact.
	_governor_rotors.clear()
	_bridge_energy_packets.clear()
	_light_beam_pulses.clear()
	_echo_root_pulses.clear()
	for candidate in find_children("*GovernorRotor", "Node3D", true, false):
		_governor_rotors.append(candidate as Node3D)
	for candidate in find_children("BridgeEnergyPacket_*", "MeshInstance3D", true, false):
		_bridge_energy_packets.append(candidate as MeshInstance3D)
	for candidate in find_children("LightBeamPulse_*", "MeshInstance3D", true, false):
		_light_beam_pulses.append(candidate as MeshInstance3D)
	for candidate in find_children("EchoRootPulse_*", "MeshInstance3D", true, false):
		_echo_root_pulses.append(candidate as MeshInstance3D)
	_analysis_rotor = find_child("AnalysisRotor", true, false) as Node3D
	set_meta("cached_visual_animation_node_count", _governor_rotors.size()
		+ _bridge_energy_packets.size() + _light_beam_pulses.size()
		+ _echo_root_pulses.size() + int(_analysis_rotor != null))
	set_meta("per_frame_scene_tree_searches", 0)


func _default_state() -> Dictionary:
	return {
		"colour_prism": -1,
		"rhythm_prism": -1,
		"weight_prism": -1,
		"west_regulator": 0,
		"east_regulator": 0,
		"outer_ring": 0,
		"middle_ring": 0,
		"inner_ring": 0,
		"analysis_observations": 0,
		"composition_analyzed": false,
		"reasoning_bonus": false,
		"attempts": 0,
		"constellation_turns": 0,
		"ever_solved": false,
		"round_complete": false,
		"replay_active": false,
		"bearing_sigil_claimed": false,
		"signal_observatory_complete": false,
		"signal_prism_claimed": false,
		"echo_collected": 0,
		"prism_installed": false,
		"echo_captured": [false,false,false],
		"echo_phases": [0,0,0],
		"echo_classifications": [-1, -1, -1],
		"protective_question": -1,
		"echo_attempts": 0,
		"echo_garden_complete": false,
		"echo_seed_claimed": false,
	}


func get_puzzle_state() -> Dictionary:
	return current_state.duplicate(true)


func get_thought_journey() -> Dictionary:
	## Only authored catalog text is returned. Island One never asks for or stores
	## a player's private thought in order to teach the skill.
	var harmony := _active_harmony()
	return {
		"thought": AUTHORED_THOUGHT,
		"category": THOUGHT_CATEGORIES[int(current_state.outer_ring)],
		"effect": THOUGHT_EFFECTS[int(current_state.middle_ring)],
		"response": GROUNDED_RESPONSES[int(current_state.inner_ring)],
		"harmony": str(harmony.get("name", "UNSELECTED")),
		"art_science": str(harmony.get("art_science", "OBSERVATION")),
		"psychology_skill": str(harmony.get("psychology", "AWARENESS")),
		"analysis_used": bool(current_state.get("composition_analyzed", false)),
		"reasoning_bonus": bool(current_state.get("reasoning_bonus", false)),
		"light_seed_composition": [
			SEED_NAMES[int(current_state.colour_prism)] if int(current_state.colour_prism) >= 0 else "EMPTY",
			SEED_NAMES[int(current_state.rhythm_prism)] if int(current_state.rhythm_prism) >= 0 else "EMPTY",
			SEED_NAMES[int(current_state.weight_prism)] if int(current_state.weight_prism) >= 0 else "EMPTY",
		],
		"message": "You noticed a thought, understood its signal, and chose a truthful next step.",
	}


func is_powered() -> bool:
	return bool(current_state.get("ever_solved", false))


func is_signal_observatory_complete() -> bool:
	return bool(current_state.get("signal_observatory_complete", false))


func is_echo_garden_complete() -> bool:
	return bool(current_state.get("echo_garden_complete", false))


func current_quest_id() -> String:
	return "quest.echo_forest" if is_signal_observatory_complete() else "quest.signal_observatory"


func current_task_id() -> String:
	if not is_signal_observatory_complete():
		if not _light_lab_ready():
			return "signal.route_composition"
		if not bool(current_state.get("composition_analyzed", false)):
			return "signal.analyze_evidence"
		if not _regulators_ready():
			return "signal.balance_pressure"
		if not _rings_ready():
			return "signal.align_constellation"
		return "signal.form_prism"
	if is_echo_garden_complete():
		return "archive.complete"
	if not bool(current_state.get("prism_installed",false)):
		return "archive.install_prism"
	if int(current_state.get("echo_collected", 0)) < 3:
		return "archive.collect_signals"
	if (current_state.get("echo_classifications", [-1, -1, -1]) as Array).has(-1):
		return "archive.sort_fact_possibility"
	if int(current_state.get("protective_question", -1)) < 0:
		return "archive.find_protective_question"
	return "archive.power_beacon"


func current_objective() -> String:
	match current_task_id():
		"signal.route_composition":
			return "Route Thought, Feeling, and Choice through three different light instruments."
		"signal.analyze_evidence":
			return "Use the analysis console to compare the completed light composition."
		"signal.balance_pressure":
			return "Match both pressure regulators to the discovered harmony."
		"signal.align_constellation":
			return "Plan the coupled rings until Notice, Understand, and Choose meet their targets."
		"signal.form_prism":
			return "Verify the aligned observatory and form the Signal Prism to open the Living Research Garden."
		"archive.collect_signals":
			return "Visit each echo receiver. Match its source phase with the +2 and +3 gears, then capture the echo."
		"archive.install_prism":
			return "Pass through the open garden gate. Install the Signal Prism at the garden collector to power its three receivers."
		"archive.sort_fact_possibility":
			return "Classify every authored echo as Fact, Possibility, or Unsure."
		"archive.find_protective_question":
			return "Turn the warning into one useful question that supports a small next step."
		"archive.power_beacon":
			return "Test all four relationships at the Caution Beacon; revise any that do not hold."
		"archive.complete":
			return "Echo Seed secured. Finish the checkpoint and Thought Spark relay to continue to Island Two."
	return "Observe what changes in the island machine."


func current_target_control_id() -> String:
	match current_task_id():
		"signal.route_composition": return "colour_prism"
		"signal.analyze_evidence": return "analysis_console"
		"signal.balance_pressure": return "west_regulator"
		"signal.align_constellation": return "outer_ring"
		"signal.form_prism": return "confirm"
		"archive.install_prism": return "echo_collector"
		"archive.collect_signals":
			for i in 3:
				if not bool(current_state.echo_captured[i]):
					return "echo_signal_%d" % (i+1)
		"archive.sort_fact_possibility":
			var classifications: Array = current_state.get("echo_classifications", [-1, -1, -1])
			for index in classifications.size():
				if int(classifications[index]) < 0:
					return "echo_signal_%d" % (index + 1)
		"archive.find_protective_question": return "echo_question"
		"archive.power_beacon": return "echo_beacon"
	return ""


func nearest_control(player: Node3D) -> Node3D:
	if player == null:
		return null
	var nearest: Node3D
	var nearest_distance := interaction_range
	for control_id in CONTROL_ORDER:
		var control := get_node_or_null("PuzzleControls/PuzzleControl_%s" % control_id) as Node3D
		if control == null:
			continue
		var distance := player.global_position.distance_to(control.global_position)
		if distance < nearest_distance:
			nearest = control
			nearest_distance = distance
	return nearest


func prompt_for_player(player: Node3D) -> Dictionary:
	var control := nearest_control(player)
	if control == null:
		return {}
	var control_id := str(control.get_meta("control_id", ""))
	var prompt := "Q • OPERATE"
	var status := _status_summary()
	match control_id:
		"colour_prism", "rhythm_prism", "weight_prism":
			var current_seed := int(current_state.get(control_id, -1))
			prompt = "Q • ROUTE THE NEXT LIGHT SEED"
			status = "%s • CURRENT SEED: %s • USE EACH SEED ONCE" % [
				control_id.replace("_prism", "").to_upper(),
				"EMPTY" if current_seed < 0 else SEED_NAMES[current_seed]]
		"analysis_console":
			prompt = "Q • ANALYZE THE LIGHT COMPOSITION"
			status = _analysis_console_preview()
		"west_regulator":
			prompt = "Q • HOLD THE THOUGHT SIGNAL STEADY"
			status = "NOTICE • A THOUGHT IS VISITING: “%s”" % AUTHORED_THOUGHT
		"east_regulator":
			prompt = "Q • MAKE SPACE AROUND THE SIGNAL"
			status = "STEADY THE MACHINE • THIS THOUGHT IS NOT YOUR IDENTITY • %d / 2" \
				% int(current_state.east_regulator)
		"outer_ring":
			prompt = "Q • COMPOSE NOTICE + UNDERSTAND"
			status = "NOTICE %s • TARGET %s • UNDERSTAND MOVES TWO STEPS" % [
				CONSTELLATION_DIRECTIONS[int(current_state.outer_ring)],
				CONSTELLATION_DIRECTIONS[_active_ring_targets()[0]]]
		"middle_ring":
			prompt = "Q • COMPOSE UNDERSTAND + CHOOSE"
			status = "UNDERSTAND %s • TARGET %s • CHOOSE MOVES TWO STEPS" % [
				CONSTELLATION_DIRECTIONS[int(current_state.middle_ring)],
				CONSTELLATION_DIRECTIONS[_active_ring_targets()[1]]]
		"inner_ring":
			prompt = "Q • TURN CHOOSE + NOTICE BACKWARD"
			status = "CHOOSE %s • TARGET %s • NOTICE REVERSES TWO STEPS" % [
				CONSTELLATION_DIRECTIONS[int(current_state.inner_ring)],
				CONSTELLATION_DIRECTIONS[_active_ring_targets()[2]]]
		"confirm":
			prompt = "Q • REPLAY THOUGHT JOURNEY" if is_echo_garden_complete() and not bool(current_state.replay_active) \
				else ("Q • SIGNAL PRISM SECURED" if is_signal_observatory_complete() \
				else "Q • FORM THE SIGNAL PRISM")
			status = "SIGNAL PRISM SECURED • CARRY ITS LIGHT TO THE ECHO GARDEN" \
				if is_signal_observatory_complete() else _status_summary()
		"echo_collector":
			prompt = "Q • INSTALL PRISM / LISTEN FOR AN ECHO"
			status = "SIGNAL PRISM REQUIRED" if not is_signal_observatory_complete() else \
				"SLOW SIGNAL ECHOES COLLECTED • %d / 3" % int(current_state.echo_collected)
		"echo_signal_1", "echo_signal_2", "echo_signal_3":
			var signal_index := int(control_id.get_slice("_", 2)) - 1
			var classification := int((current_state.echo_classifications as Array)[signal_index])
			prompt = "Q • CLASSIFY THIS ECHO"
			status = "%s • %s" % [ECHO_SIGNALS[signal_index],
				"UNCLASSIFIED" if classification < 0 else ECHO_CATEGORIES[classification]]
		"echo_question":
			var question_index := int(current_state.protective_question)
			prompt = "Q • SHAPE A HELPFUL QUESTION"
			status = "CHOOSE A QUESTION" if question_index < 0 else PROTECTIVE_QUESTIONS[question_index]
		"echo_beacon":
			prompt = "Q • TEST THE CAUTION BEACON"
			status = _echo_status_summary()
	if _feedback_seconds > 0.0:
		status = _feedback_text
	return {"control_id": control_id, "prompt": "Q • OPEN " + control_id.replace("_"," ").to_upper(), "status": status}


func interact_nearest(player: Node3D) -> Dictionary:
	var control := nearest_control(player)
	if control == null:
		return {"accepted": false, "reason": "no_compass_control_nearby"}
	return interact_control(str(control.get_meta("control_id", "")))


func interact_control(control_id: String) -> Dictionary:
	if control_id not in CONTROL_ORDER:
		return {"accepted": false, "reason": "unknown_control"}
	if is_echo_garden_complete() and not bool(current_state.replay_active) and control_id == "confirm":
		_start_replay()
		return _result(true, "replay_started")
	if control_id.begins_with("echo_"):
		return _interact_echo_control(control_id)
	if is_signal_observatory_complete():
		_feedback("THE SIGNAL PRISM IS STABLE • FOLLOW ITS LIGHT TO THE ECHO GARDEN")
		return _result(false, "signal_observatory_complete")
	if control_id in ["colour_prism","rhythm_prism","weight_prism","west_regulator","east_regulator","outer_ring","middle_ring","inner_ring"]:
		_adjustment_history.append(current_state.duplicate(true))
		if _adjustment_history.size() > 32:
			_adjustment_history.pop_front()
	if control_id in ["colour_prism", "rhythm_prism", "weight_prism"]:
		current_state[control_id] = (int(current_state.get(control_id, -1)) + 1) % 3
		current_state.composition_analyzed = false
		current_state.reasoning_bonus = false
		var seed_harmony := _seed_harmony()
		_feedback("LIGHT COMPOSITION DISCOVERED • %s" % str(seed_harmony.name) \
			if not seed_harmony.is_empty() else "ROUTE THOUGHT • FEELING • CHOICE ONCE EACH")
	elif control_id == "analysis_console":
		_analyze_composition()
		return _result(true, "composition_analyzed" if bool(current_state.composition_analyzed) \
			else "analysis_feedback")
	elif control_id in ["west_regulator", "east_regulator"]:
		if not bool(current_state.get("composition_analyzed", false)):
			_feedback("ANALYZE THE LIGHT COMPOSITION BEFORE ADJUSTING ITS PRESSURE")
			return _result(false, "analysis_first")
		current_state[control_id] = (int(current_state.get(control_id, 0)) + 1) % 3
		var harmony := _active_harmony()
		_feedback("PRESSURE STABLE • %s" % str(harmony.name) if _regulators_ready() \
			else "MATCH THE TWO PRESSURES TO THE DISCOVERED LIGHT COMPOSITION")
	elif control_id in ["outer_ring", "middle_ring", "inner_ring"]:
		if not _light_lab_ready():
			_feedback("ROUTE THE THREE LIGHT SEEDS THROUGH THE GARDEN FIRST")
			return _result(false, "light_lab_first")
		if not bool(current_state.get("composition_analyzed", false)):
			_feedback("USE THE ANALYSIS CONSOLE BEFORE COMPOSING THE CONSTELLATION")
			return _result(false, "analysis_first")
		if not _regulators_ready():
			_feedback("NOTICE AND STEADY THE THOUGHT SIGNAL FIRST")
			return _result(false, "regulators_first")
		_turn_coupled_constellation(control_id)
		current_state.constellation_turns = int(current_state.get("constellation_turns", 0)) + 1
		_feedback(_ring_feedback(control_id))
	elif control_id == "confirm":
		if not _light_lab_ready():
			_feedback("THE LIVING LIGHT COMPOSITION IS NOT COMPLETE")
			return _result(false, "light_lab_first")
		if not bool(current_state.get("composition_analyzed", false)):
			_feedback("THE COMPOSITION NEEDS EVIDENCE BEFORE IT CAN MOVE FORWARD")
			return _result(false, "analysis_first")
		if not _regulators_ready():
			_feedback("THE THOUGHT NEEDS TO BE NOTICED BEFORE IT CAN MOVE FORWARD")
			return _result(false, "regulators_first")
		if _rings_ready():
			_complete_round()
			return _result(true, "completed")
		current_state.attempts = int(current_state.get("attempts", 0)) + 1
		_feedback("%d / 3 STEPS READY • NOTICE, UNDERSTAND, THEN CHOOSE" % _correct_ring_count(), 5.0)
		_save()
		_apply_state(true)
		return _result(true, "alignment_incomplete")
	_save()
	_apply_state(true)
	puzzle_state_changed.emit(get_puzzle_state())
	return _result(true, "control_changed")


func solve_for_test() -> Dictionary:
	current_state.colour_prism = 0
	current_state.rhythm_prism = 1
	current_state.weight_prism = 2
	current_state.composition_analyzed = true
	current_state.reasoning_bonus = true
	current_state.west_regulator = REGULATOR_TARGETS[0]
	current_state.east_regulator = REGULATOR_TARGETS[1]
	var targets := _active_ring_targets()
	current_state.outer_ring = targets[0]
	current_state.middle_ring = targets[1]
	current_state.inner_ring = targets[2]
	interact_control("confirm")
	return solve_echo_for_test()


func solve_echo_for_test() -> Dictionary:
	if not is_signal_observatory_complete():
		return _result(false, "signal_prism_required")
	current_state.echo_collected = 3
	current_state.prism_installed = true
	current_state.echo_captured = [true,true,true]
	current_state.echo_phases = ECHO_PHASE_TARGETS.duplicate()
	current_state.echo_classifications = ECHO_TARGETS.duplicate()
	current_state.protective_question = PROTECTIVE_QUESTION_TARGET
	return interact_control("echo_beacon")


func _complete_round() -> void:
	var first_completion := not is_signal_observatory_complete()
	current_state.signal_observatory_complete = true
	current_state.signal_prism_claimed = true
	current_state.round_complete = true
	current_state.replay_active = false
	_feedback("SIGNAL UNDERSTOOD • SIGNAL PRISM FORMED • ECHO GARDEN AWAKENING", 8.0)
	_save()
	_apply_state(true)
	puzzle_state_changed.emit(get_puzzle_state())
	if first_completion:
		var harmony := _active_harmony()
		quest_completed.emit("quest.signal_observatory", {
			"relic_id": "signal_prism",
			"emotional_reward_id": "awareness_sigil",
			"destination": "island_one.echo_garden",
			"attempts": int(current_state.attempts),
			"thought_journey": get_thought_journey(),
			"creative_harmony": str(harmony.get("name", "CALM CONTRAST")),
			"art_science": str(harmony.get("art_science", "COMPLEMENTARY BALANCE")),
			"psychology_skill": str(harmony.get("psychology", "COGNITIVE DEFUSION")),
			"reasoning_bonus": bool(current_state.get("reasoning_bonus", false)),
			"analysis_observations": int(current_state.get("analysis_observations", 0)),
			"guardian_message": "You noticed the thought. You do not have to obey it or push it away. Let us understand what it is trying to tell you.",
		})


func _interact_echo_control(control_id: String) -> Dictionary:
	if not is_signal_observatory_complete():
		_feedback("THE ECHO GARDEN NEEDS THE SIGNAL PRISM FROM THE OBSERVATORY")
		return _result(false, "signal_prism_required")
	if is_echo_garden_complete():
		_feedback("THE ECHO SEED IS SAFE • THE HEAVENLY GATE NOW CARRIES ITS LIGHT")
		return _result(false, "echo_garden_complete")
	if control_id == "echo_collector":
		if bool(current_state.prism_installed):
			return _result(false,"visit_echo_receivers")
		current_state.prism_installed = true
		_feedback("PRISM INSTALLED • THREE RECEIVERS AWAKE • VISIT EACH RECEIVER",6.0)
	elif control_id in ["echo_signal_1", "echo_signal_2", "echo_signal_3"]:
		if not bool(current_state.echo_captured[int(control_id.right(1))-1]):
			_feedback("LISTEN TO ALL THREE SLOW SIGNAL ECHOES BEFORE SORTING THEM")
			return _result(false, "collect_echoes_first")
		var signal_index := int(control_id.get_slice("_", 2)) - 1
		var classifications: Array = current_state.echo_classifications
		classifications[signal_index] = (int(classifications[signal_index]) + 1) % ECHO_CATEGORIES.size()
		current_state.echo_classifications = classifications
		_feedback("%s • %s" % [ECHO_SIGNALS[signal_index], ECHO_CATEGORIES[int(classifications[signal_index])]])
	elif control_id == "echo_question":
		if int(current_state.echo_collected) < 3:
			_feedback("LET THE THREE ECHOES ARRIVE BEFORE INTERPRETING THEIR WARNING")
			return _result(false, "collect_echoes_first")
		current_state.protective_question = (int(current_state.protective_question) + 1) \
			% PROTECTIVE_QUESTIONS.size()
		_feedback(PROTECTIVE_QUESTIONS[int(current_state.protective_question)], 5.0)
	elif control_id == "echo_beacon":
		if int(current_state.echo_collected) < 3:
			_feedback("THE BEACON NEEDS ALL THREE ECHOES")
			return _result(false, "collect_echoes_first")
		if (current_state.echo_classifications as Array).has(-1) or int(current_state.protective_question) < 0:
			_feedback("COMPLETE THE THREE CLASSIFICATIONS AND SHAPE ONE HELPFUL QUESTION")
			return _result(false, "interpretation_incomplete")
		var correct_relations := _correct_echo_relation_count()
		if correct_relations < 4:
			current_state.echo_attempts = int(current_state.echo_attempts) + 1
			_feedback("%d / 4 RELATIONSHIPS HOLD • REVISIT CERTAINTY, POSSIBILITY, AND THE QUESTION" \
				% correct_relations, 6.0)
			_save()
			_apply_state(true)
			return _result(true, "interpretation_needs_revision")
		_complete_echo_garden()
		return _result(true, "completed")
	_save()
	_apply_state(true)
	puzzle_state_changed.emit(get_puzzle_state())
	return _result(true, "control_changed")


func station_action(control_id: String, action: String, value: int = 0, player: Node3D = null) -> Dictionary:
	var control := get_node_or_null("PuzzleControls/PuzzleControl_%s" % control_id) as Node3D
	if control == null or (player != null and player.global_position.distance_to(control.global_position) > interaction_range):
		return _result(false,"out_of_range")
	if action == "operate":
		return interact_control(control_id)
	if action == "undo":
		if is_signal_observatory_complete() or _adjustment_history.is_empty():
			return _result(false,"nothing_to_undo")
		current_state = _adjustment_history.pop_back()
		_feedback("LAST ADJUSTMENT REVERSED • TRY ANOTHER COMPOSITION")
	elif control_id.begins_with("echo_signal_"):
		if not is_signal_observatory_complete() or not bool(current_state.prism_installed):
			return _result(false,"install_prism_first")
		if is_echo_garden_complete():
			return _result(false,"echo_garden_complete")
		var index := int(control_id.right(1))-1
		if action == "tune" and value in [2,3,-2,-3] and not bool(current_state.echo_captured[index]):
			current_state.echo_phases[index] = posmod(int(current_state.echo_phases[index])+value,8)
		elif action == "capture":
			if bool(current_state.echo_captured[index]):
				return _result(false,"echo_already_captured")
			if int(current_state.echo_phases[index]) != ECHO_PHASE_TARGETS[index]:
				_feedback("PHASES DO NOT MEET • TWO-STEP AND THREE-STEP GEARS CAN COMBINE",6.0)
				return _result(false,"phase_mismatch")
			current_state.echo_captured[index] = true
			current_state.echo_collected = (current_state.echo_captured as Array).count(true)
			_feedback("ECHO CAPTURED • READ ITS EVIDENCE BEFORE CHOOSING A CATEGORY",6.0)
		elif action == "classify" and value in [0,1,2] and bool(current_state.echo_captured[index]):
			current_state.echo_classifications[index] = value
		else:
			return _result(false,"capture_echo_first")
	elif control_id == "echo_question" and action == "question" and value in [0,1,2,3]:
		if int(current_state.echo_collected) != 3 or is_echo_garden_complete():
			return _result(false,"collect_echoes_first")
		current_state.protective_question = value
	else:
		return _result(false,"unknown_action")
	_save()
	_apply_state(true)
	puzzle_state_changed.emit(get_puzzle_state())
	return _result(true,"station_updated")


func capture_echoes_for_test() -> void:
	assert(interact_control("echo_collector").accepted)
	for index in 3:
		var id := "echo_signal_%d" % (index+1)
		# Exercise the same two gears and capture action used by the panel.
		for _turn in 8:
			if int(current_state.echo_phases[index]) == ECHO_PHASE_TARGETS[index]:
				break
			assert(station_action(id,"tune",3).accepted)
		assert(station_action(id,"capture").accepted)


func _correct_echo_relation_count() -> int:
	var count := 0
	var classifications: Array = current_state.echo_classifications
	for index in ECHO_TARGETS.size():
		count += int(int(classifications[index]) == ECHO_TARGETS[index])
	count += int(int(current_state.protective_question) == PROTECTIVE_QUESTION_TARGET)
	return count


func _complete_echo_garden() -> void:
	var first_completion := not is_echo_garden_complete()
	current_state.echo_garden_complete = true
	current_state.echo_seed_claimed = true
	current_state.ever_solved = true
	current_state.bearing_sigil_claimed = true
	current_state.replay_active = false
	_feedback("ECHO SEED FORMED • SAVE AT THE CHECKPOINT, THEN COMPLETE THE SPARK RELAY FOR ISLAND TWO", 9.0)
	_save()
	_apply_state(true)
	puzzle_state_changed.emit(get_puzzle_state())
	if first_completion:
		var reward := {
			"relic_id": "echo_seed",
			"prerequisite_relic_id": "signal_prism",
			"emotional_reward_id": "protective_wisdom",
			"destination": "island_two.living_relay",
			"attempts": int(current_state.echo_attempts),
			"guardian_message": "Fear may carry a question without predicting the future. You found the useful question and chose a grounded next step.",
		}
		quest_completed.emit("quest.echo_forest", reward)
		puzzle_solved.emit(reward)


func _start_replay() -> void:
	current_state.colour_prism = -1
	current_state.rhythm_prism = -1
	current_state.weight_prism = -1
	current_state.west_regulator = 0
	current_state.east_regulator = 0
	current_state.outer_ring = 0
	current_state.middle_ring = 0
	current_state.inner_ring = 0
	current_state.analysis_observations = 0
	current_state.composition_analyzed = false
	current_state.reasoning_bonus = false
	current_state.round_complete = false
	current_state.replay_active = true
	current_state.signal_observatory_complete = false
	current_state.signal_prism_claimed = false
	current_state.echo_collected = 0
	current_state.prism_installed = false
	current_state.echo_captured = [false,false,false]
	current_state.echo_phases = [0,0,0]
	_adjustment_history.clear()
	current_state.echo_classifications = [-1, -1, -1]
	current_state.protective_question = -1
	current_state.echo_attempts = 0
	current_state.echo_garden_complete = false
	current_state.echo_seed_claimed = false
	_feedback("REPLAY STARTED • RELIC AND STAR GATE POWER RETAINED", 5.0)
	_save()
	_apply_state(true)
	puzzle_state_changed.emit(get_puzzle_state())


func _regulators_ready() -> bool:
	var harmony := _active_harmony()
	return not harmony.is_empty() \
		and harmony.regulators == [int(current_state.west_regulator), int(current_state.east_regulator)]


func _light_lab_ready() -> bool:
	return not _seed_harmony().is_empty()


func _seed_harmony() -> Dictionary:
	var pattern := [int(current_state.get("colour_prism", -1)),
		int(current_state.get("rhythm_prism", -1)), int(current_state.get("weight_prism", -1))]
	for profile in HARMONY_PROFILES:
		if profile.seed_pattern == pattern:
			return profile
	return {}


func _analyze_composition() -> void:
	var values := [int(current_state.get("colour_prism", -1)),
		int(current_state.get("rhythm_prism", -1)), int(current_state.get("weight_prism", -1))]
	current_state.analysis_observations = int(current_state.get("analysis_observations", 0)) + 1
	var selected := 0
	var unique := {}
	for value in values:
		if value >= 0:
			selected += 1
			unique[value] = true
	if selected < 3:
		_feedback("ANALYSIS • %d / 3 INSTRUMENTS ACTIVE • COMPLETE THE EXPERIMENT BEFORE JUDGING IT" % selected, 5.0)
	elif unique.size() < 3:
		_feedback("ANALYSIS • ONE SIGNAL REPEATS • A LIVING COMPOSITION NEEDS THOUGHT, FEELING AND CHOICE", 6.0)
	else:
		var harmony := _seed_harmony()
		current_state.composition_analyzed = not harmony.is_empty()
		current_state.reasoning_bonus = not harmony.is_empty()
		_feedback("PATTERN RECOGNIZED • %s • %s • NOW TEST ITS PRESSURE" % [
			str(harmony.name), str(harmony.clue)], 7.0)
	_save()
	_apply_state(true)
	puzzle_state_changed.emit(get_puzzle_state())


func _analysis_console_preview() -> String:
	if bool(current_state.get("composition_analyzed", false)):
		return "ANALYZED • %s • THE CONSOLE WILL NOT CHOOSE THE PRESSURE FOR YOU" % str(_active_harmony().name)
	var values := [int(current_state.get("colour_prism", -1)),
		int(current_state.get("rhythm_prism", -1)), int(current_state.get("weight_prism", -1))]
	var selected := 0
	for value in values:
		selected += int(value >= 0)
	return "COMPARE CAUSE AND EFFECT • %d / 3 INSTRUMENTS ACTIVE" % selected


func _active_harmony() -> Dictionary:
	return _seed_harmony()


func _active_ring_targets() -> Array:
	var harmony := _active_harmony()
	return harmony.targets if not harmony.is_empty() else HARMONY_PROFILES[0].targets


func _rings_ready() -> bool:
	var targets := _active_ring_targets()
	return int(current_state.outer_ring) == targets[0] \
		and int(current_state.middle_ring) == targets[1] \
		and int(current_state.inner_ring) == targets[2]


func _correct_ring_count() -> int:
	var targets := _active_ring_targets()
	return int(int(current_state.outer_ring) == targets[0]) \
		+ int(int(current_state.middle_ring) == targets[1]) \
		+ int(int(current_state.inner_ring) == targets[2])


func _turn_coupled_constellation(control_id: String) -> void:
	## Every input moves two rings, creating a compact spatial logic puzzle. It
	## remains untimed and fully observable, so experimentation is safe.
	match control_id:
		"outer_ring":
			current_state.outer_ring = (int(current_state.outer_ring) + 1) % 8
			current_state.middle_ring = (int(current_state.middle_ring) + 2) % 8
		"middle_ring":
			current_state.middle_ring = (int(current_state.middle_ring) + 1) % 8
			current_state.inner_ring = (int(current_state.inner_ring) + 2) % 8
		"inner_ring":
			current_state.inner_ring = (int(current_state.inner_ring) + 1) % 8
			current_state.outer_ring = posmod(int(current_state.outer_ring) - 2, 8)


func _ring_feedback(control_id: String) -> String:
	match control_id:
		"outer_ring":
			return "NOTICE +1 • UNDERSTAND +2 • OBSERVE THE RHYTHM"
		"middle_ring":
			return "UNDERSTAND +1 • CHOOSE +2 • PLAN THE COUNTERPOINT"
		"inner_ring":
			return "CHOOSE +1 • NOTICE −2 • REBALANCE THE WHOLE COMPOSITION"
	return "THE THOUGHT JOURNEY CONTINUES"


func _status_summary() -> String:
	if is_powered() and not bool(current_state.replay_active):
		return "ISLAND ONE AWAKE • SIGNAL PRISM + ECHO SEED SECURED"
	if is_signal_observatory_complete():
		return "SIGNAL PRISM SECURED • FOLLOW ITS LIGHT TO THE ECHO GARDEN"
	if not _light_lab_ready():
		return "LIVING LIGHT LAB • ROUTE THOUGHT, FEELING AND CHOICE WITHOUT DUPLICATION"
	if not bool(current_state.get("composition_analyzed", false)):
		return "%s DISCOVERED • USE THE ANALYSIS CONSOLE TO STUDY THE RELATIONSHIP" % str(_active_harmony().name)
	if not _regulators_ready():
		return "%s DISCOVERED • NOW MATCH ITS TWO LIGHT PRESSURES" % str(_active_harmony().name)
	if not _rings_ready():
		var harmony := _active_harmony()
		return "%s • %s • %s" % [str(harmony.name), str(harmony.art_science), str(harmony.clue)]
	return "CONSTELLATION ALIGNED • SEND THIS UNDERSTANDING TO THE STAR GATE"


func _echo_status_summary() -> String:
	if not is_signal_observatory_complete():
		return "LOCKED • SIGNAL PRISM REQUIRED"
	if is_echo_garden_complete():
		return "CAUTION BEACON ACTIVE • ECHO SEED SECURED"
	if int(current_state.echo_collected) < 3:
		return "LISTEN WITHOUT CHASING • %d / 3 ECHOES RESTING" % int(current_state.echo_collected)
	var classified := 0
	for value in current_state.echo_classifications as Array:
		classified += int(int(value) >= 0)
	if classified < 3:
		return "SORT CERTAINTY CAREFULLY • %d / 3 ECHOES CLASSIFIED" % classified
	if int(current_state.protective_question) < 0:
		return "TRANSLATE THE WARNING INTO ONE USEFUL QUESTION"
	return "INTERPRETATION READY • TEST ALL FOUR RELATIONSHIPS"


func _save() -> bool:
	return _store.save_object(SAVE_ID, current_state)


func _feedback(message: String, duration := 3.5) -> void:
	_feedback_text = message
	_feedback_seconds = duration


func _result(accepted: bool, reason: String) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "state": get_puzzle_state()}


func _process(delta: float) -> void:
	_feedback_seconds = maxf(0.0, _feedback_seconds - delta)
	_rotor_phase = fposmod(_rotor_phase + delta * (1.8 if is_powered() else 0.32), TAU)
	# Web island streaming hides this whole controller outside Island One. Keep
	# state time moving, but do not animate invisible visual-only descendants.
	if not is_visible_in_tree():
		return
	var powered := is_powered()
	for rotor in _governor_rotors:
		if not is_instance_valid(rotor):
			continue
		rotor.rotation.y = _rotor_phase
	for mesh in _bridge_energy_packets:
		if not is_instance_valid(mesh):
			continue
		mesh.visible = powered
		var phase := fposmod(_rotor_phase / TAU + float(mesh.get_meta("packet_phase", 0.0)), 1.0)
		var path_start: Vector3 = mesh.get_meta("path_start", Vector3.ZERO)
		var path_end: Vector3 = mesh.get_meta("path_end", Vector3.ZERO)
		mesh.position = path_start.lerp(path_end, phase)
	for light_pulse in _light_beam_pulses:
		if not is_instance_valid(light_pulse):
			continue
		var source_prism := str(light_pulse.get_meta("source_prism", ""))
		var selected_seed := int(current_state.get("%s_prism" % source_prism, -1))
		var pulse_seed := int(light_pulse.get_meta("seed_index", -2))
		light_pulse.visible = selected_seed == pulse_seed
		if light_pulse.visible:
			var pulse_phase := fposmod(_rotor_phase / TAU * 0.72 \
				+ float(light_pulse.get_meta("pulse_offset", 0.0)), 1.0)
			var pulse_start: Vector3 = light_pulse.get_meta("path_start", Vector3.ZERO)
			var pulse_end: Vector3 = light_pulse.get_meta("path_end", Vector3.ZERO)
			light_pulse.position = pulse_start.lerp(pulse_end, pulse_phase)
	for root_pulse in _echo_root_pulses:
		if not is_instance_valid(root_pulse):
			continue
		var route_index := int(root_pulse.get_meta("route_index", -1))
		root_pulse.visible = _echo_route_active(route_index)
		if root_pulse.visible:
			var echo_phase := fposmod(_rotor_phase / TAU * 0.58 \
				+ float(root_pulse.get_meta("pulse_offset", 0.0)), 1.0)
			var echo_start: Vector3 = root_pulse.get_meta("path_start", Vector3.ZERO)
			var echo_end: Vector3 = root_pulse.get_meta("path_end", Vector3.ZERO)
			root_pulse.position = echo_start.lerp(echo_end, echo_phase)
	if is_instance_valid(_analysis_rotor):
		_analysis_rotor.rotation.y = _rotor_phase * 0.4
		_analysis_rotor.rotation.x = sin(_rotor_phase) * 0.08


func _apply_state(animate: bool) -> void:
	if not is_inside_tree():
		return
	var prism_names := ["colour", "rhythm", "weight"]
	for art in find_children("HeavenlyQuestInstrument", "Node3D", true, false):
		art.call("apply_puzzle_state", current_state, animate)
	var weight_art := find_child("WeightPrismBenchmark", true, false) as Node3D
	if weight_art != null:
		weight_art.call("set_choice", int(current_state.get("weight_prism", -1)), animate)
	var prism_values := [int(current_state.get("colour_prism", -1)),
		int(current_state.get("rhythm_prism", -1)), int(current_state.get("weight_prism", -1))]
	for prism_index in 3:
		var rotor := find_child("LightPrismRotor_%s" % prism_names[prism_index], true, false) as Node3D
		var seed_value: int = prism_values[prism_index]
		var carousel := find_child("SeedCarousel_%s" % prism_names[prism_index], true, false) as Node3D
		var shutter := find_child("PrismEmitterShutter_%s" % prism_names[prism_index], true, false) as Node3D
		var lock_piston := find_child("PrismLockPiston_%s" % prism_names[prism_index], true, false) as Node3D
		if rotor != null:
			var prism_rotation := 0.0 if seed_value < 0 else float(seed_value) * TAU / 3.0
			if animate:
				create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
					.tween_property(rotor, "rotation:y", prism_rotation, 0.42)
			else:
				rotor.rotation.y = prism_rotation
			if carousel != null:
				var carousel_rotation := -prism_rotation
				if animate:
					create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) \
						.tween_property(carousel, "rotation:y", carousel_rotation, 0.52)
				else:
					carousel.rotation.y = carousel_rotation
			if shutter != null:
				shutter.rotation.x = prism_rotation * 0.5
			if lock_piston != null:
				var lock_height := 2.35 if seed_value < 0 else 2.72
				if animate:
					create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT) \
						.tween_property(lock_piston, "position:y", lock_height, 0.34)
				else:
					lock_piston.position.y = lock_height
		var seed_core := find_child("LightSeedCore_%s" % prism_names[prism_index], true, false) as MeshInstance3D
		if seed_core != null:
			seed_core.material_override = _light_seed_material(seed_value)
		for possible_seed in 3:
			var socket_lamp := find_child("SeedSocketLamp_%s_%d" % [prism_names[prism_index], possible_seed],
				true, false) as MeshInstance3D
			if socket_lamp != null:
				socket_lamp.material_override = _light_seed_material(possible_seed,
					seed_value == possible_seed)
		for possible_seed in 3:
			for beam in find_children("LightBeam_%s_%d_*" % [prism_names[prism_index], possible_seed],
					"MeshInstance3D", true, false):
				(beam as MeshInstance3D).visible = seed_value == possible_seed
	var ready_halo := find_child("LivingLightCompositionReadyHalo", true, false) as Node3D
	if ready_halo != null:
		ready_halo.visible = _light_lab_ready()
	var values := [int(current_state.outer_ring), int(current_state.middle_ring), int(current_state.inner_ring)]
	var targets := _active_ring_targets()
	var ring_names := ["OuterCompassRing", "MiddleCompassRing", "InnerCompassRing"]
	for index in 3:
		var ring := get_node_or_null("CompassMachine/%s" % ring_names[index]) as Node3D
		if ring != null:
			var target_rotation := float(values[index]) * PI * 0.25
			if animate:
				create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) \
					.tween_property(ring, "rotation:y", target_rotation, 0.28)
			else:
				ring.rotation.y = target_rotation
			var correct: bool = int(values[index]) == int(targets[index])
			# Preserve the ivory teeth and brass body. Only rune plaques communicate
			# state, keeping the solved machine luxurious instead of uniformly neon.
			for segment in ring.find_children("*Rune_*", "MeshInstance3D", true, false):
				(segment as MeshInstance3D).material_override = _feedback_material(correct, is_powered())
	var target_names := ["NOTICE", "UNDERSTAND", "CHOOSE"]
	for index in 3:
		var actual := find_child("ConstellationActual_%s" % target_names[index], true, false) as Node3D
		if actual == null:
			continue
		var actual_rotation := -float(values[index]) * PI * 0.25
		if animate:
			create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
				.tween_property(actual, "rotation:z", actual_rotation, 0.38)
		else:
			actual.rotation.z = actual_rotation
		var correct: bool = int(values[index]) == int(targets[index])
		for jewel in actual.find_children("*", "MeshInstance3D", true, false):
			(jewel as MeshInstance3D).material_override = _feedback_material(correct, is_powered())
		var target := find_child("ConstellationTarget_%s" % target_names[index], true, false) as Node3D
		if target != null:
			target.rotation.z = -float(targets[index]) * PI * 0.25
	_apply_gauge("WestPressureGauge", int(current_state.west_regulator), REGULATOR_TARGETS[0])
	_apply_gauge("EastPressureGauge", int(current_state.east_regulator), REGULATOR_TARGETS[1])
	var powered := is_powered()
	for node_name in ["SolvedRouteProjection", "BridgePowerSocketGlow"]:
		var node := find_child(node_name, true, false) as Node3D
		if node != null:
			node.visible = powered
	var reward := find_child("BearingSigilReward", true, false) as Node3D
	if reward != null:
		reward.visible = is_signal_observatory_complete()
		reward.position.y = 7.2 if is_signal_observatory_complete() else -2.0
		reward.set_meta("reward_id", "signal_prism")
	var status := find_child("CompassInstructionDisplay", true, false) as Label3D
	if status != null:
		status.text = _status_summary()
	var thought_label := find_child("AuthoredThoughtText", true, false) as Label3D
	if thought_label != null:
		thought_label.text = "A THOUGHT IS VISITING\n“%s”" % AUTHORED_THOUGHT
	var journey_label := find_child("ThoughtJourneyDisplay", true, false) as Label3D
	if journey_label != null:
		var journey := get_thought_journey()
		journey_label.text = "%s  →  %s  →  %s" % [journey.category, journey.effect, journey.response]
	var harmony_label := find_child("HarmonyReadingDisplay", true, false) as Label3D
	if harmony_label != null:
		var harmony := _active_harmony()
		harmony_label.text = "SEEK A HARMONY\nLIGHT • RHYTHM • VISUAL WEIGHT" if harmony.is_empty() \
			else "%s\n%s • %s" % [harmony.name, harmony.art_science, harmony.psychology]
	var transformed := find_child("TransformedThoughtGlow", true, false) as Node3D
	if transformed != null:
		transformed.visible = powered
	for bloom in find_children("HeavenlyBloom_*", "MeshInstance3D", true, false):
		(bloom as MeshInstance3D).scale = Vector3(1.95, 0.90, 1.95) if powered else Vector3(1.6, 0.72, 1.6)
	_apply_echo_garden_state(animate)
	_apply_analysis_console_state()
	_apply_quest_identity_state()
	_apply_environment_status()


func _apply_environment_status() -> void:
	# The architecture communicates progression at long range: the gatehouse is
	# available from the start, the observatory masts answer after analysis, and
	# the crown lights only when the Signal Prism has been secured.
	var available := find_child("StatusAvailable", true, false) as Node3D
	if available != null:
		available.visible = true
	var analyzed := find_child("StatusAnalyzed", true, false) as Node3D
	if analyzed != null:
		analyzed.visible = bool(current_state.get("composition_analyzed", false)) \
			or is_signal_observatory_complete()
	var complete := find_child("StatusComplete", true, false) as Node3D
	if complete != null:
		complete.visible = is_signal_observatory_complete()


func _apply_echo_garden_state(animate: bool) -> void:
	var signal_ready := is_signal_observatory_complete()
	var collected := int(current_state.get("echo_collected", 0))
	var installed_prism := find_child("InstalledSignalPrism", true, false) as Node3D
	if installed_prism != null:
		installed_prism.visible = bool(current_state.get("prism_installed",false))
	for index in 3:
		var listening := find_child("EchoListeningOrb_%02d" % (index + 1), true, false) as Node3D
		if listening != null:
			listening.visible = bool(current_state.prism_installed) and not bool(current_state.echo_captured[index])
			listening.rotation.y = float(current_state.echo_phases[index])*TAU/8.0
		var resting := find_child("RestingEchoOrb_%02d" % (index + 1), true, false) as Node3D
		if resting != null:
			resting.visible = bool(current_state.echo_captured[index])
	var classifications: Array = current_state.get("echo_classifications", [-1, -1, -1])
	for station_index in 3:
		var selected := int(classifications[station_index])
		var signal_label := find_child("EchoSignalText_%02d" % (station_index + 1),
			true, false) as Label3D
		if signal_label != null:
			signal_label.text = "ECHO %d\n%s" % [station_index + 1, ECHO_SIGNALS[station_index]]
		var category_label := find_child("EchoCategoryReading_%02d" % (station_index + 1),
			true, false) as Label3D
		if category_label != null:
			category_label.text = "FACT • POSSIBILITY • UNSURE\nSELECTED: %s" % (
				"UNCLASSIFIED" if selected < 0 else ECHO_CATEGORIES[selected])
		for category_index in 3:
			var jewel := find_child("EchoCategoryJewel_%02d_%02d" % [station_index + 1, category_index + 1],
				true, false) as MeshInstance3D
			if jewel != null:
				jewel.material_override = _feedback_material(category_index == selected,
					is_echo_garden_complete()) if category_index == selected else \
					_light_seed_material(category_index, false)
	var pointer := find_child("ProtectiveQuestionPointer", true, false) as Node3D
	if pointer != null:
		var question_index := int(current_state.get("protective_question", -1))
		var target_rotation := 0.0 if question_index < 0 else float(question_index) * PI * 0.5
		if animate:
			create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
				.tween_property(pointer, "rotation:z", target_rotation, 0.38)
		else:
			pointer.rotation.z = target_rotation
	var question_reading := find_child("ProtectiveQuestionReading", true, false) as Label3D
	if question_reading != null:
		var selected_question := int(current_state.get("protective_question", -1))
		question_reading.text = "CHOOSE A USEFUL QUESTION" if selected_question < 0 else \
			PROTECTIVE_QUESTIONS[selected_question]
	var beacon_lens := find_child("CautionBeaconLens", true, false) as MeshInstance3D
	if beacon_lens != null:
		beacon_lens.material_override = _feedback_material(is_echo_garden_complete(),
			is_echo_garden_complete())
	var beacon_light := find_child("CautionBeaconLight", true, false) as Light3D
	if beacon_light != null:
		beacon_light.light_energy = 3.4 if is_echo_garden_complete() else (1.0 if signal_ready else 0.15)
	var echo_seed := find_child("EchoSeedReward", true, false) as Node3D
	if echo_seed != null:
		echo_seed.visible = is_echo_garden_complete()
		var target_y := 14.0 if is_echo_garden_complete() else -3.0
		if animate and is_echo_garden_complete():
			create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
				.tween_property(echo_seed, "position:y", target_y, 0.8)
		else:
			echo_seed.position.y = target_y
	var active_guidance_chapter := _active_guidance_chapter()
	for guide_light in find_children("GuidanceLight_*", "MeshInstance3D", true, false):
		var marker := guide_light as MeshInstance3D
		marker.visible = is_echo_garden_complete() or (
			signal_ready and int(marker.get_meta("guidance_chapter", -1)) == active_guidance_chapter)
	for echo_pulse in find_children("EchoRootPulse_*", "MeshInstance3D", true, false):
		var root_pulse := echo_pulse as MeshInstance3D
		root_pulse.visible = _echo_route_active(int(root_pulse.get_meta("route_index", -1)))
	var objective_display := find_child("EchoGardenObjectiveDisplay", true, false) as Label3D
	if objective_display != null:
		objective_display.text = current_objective() if signal_ready else \
			"THE SIGNAL PRISM WILL REVEAL THE ECHO GARDEN"


func _active_guidance_chapter() -> int:
	match current_task_id():
		"archive.install_prism", "archive.collect_signals": return 0
		"archive.sort_fact_possibility": return 1
		"archive.find_protective_question": return 2
		"archive.power_beacon": return 3
	return -1


func _echo_route_active(route_index: int) -> bool:
	if not is_signal_observatory_complete():
		return false
	if is_echo_garden_complete():
		return true
	if route_index == 0:
		return true
	if route_index in [1, 2, 3]:
		return int(current_state.get("echo_collected", 0)) >= route_index
	if route_index == 4:
		return not (current_state.get("echo_classifications", [-1, -1, -1]) as Array).has(-1)
	if route_index == 5:
		return int(current_state.get("protective_question", -1)) >= 0
	return false


func _apply_analysis_console_state() -> void:
	var console := find_child("AetherAnalysisConsoleModel", true, false) as Node3D
	if console == null:
		return
	var analyzed := bool(current_state.get("composition_analyzed", false))
	var heart := console.find_child("AnalysisHeartLens", true, false) as MeshInstance3D
	if heart != null:
		heart.material_override = _feedback_material(analyzed, is_powered())
	var seed_values := [int(current_state.get("colour_prism", -1)),
		int(current_state.get("rhythm_prism", -1)), int(current_state.get("weight_prism", -1))]
	for index in 3:
		var evidence_lamp := console.find_child("EvidenceLamp_%d" % (index + 1), true, false) as MeshInstance3D
		if evidence_lamp != null:
			evidence_lamp.material_override = _light_seed_material(seed_values[index], seed_values[index] >= 0)
	var analysis_light := find_child("AetherAnalysisConsoleLight", true, false) as Light3D
	if analysis_light != null:
		analysis_light.light_energy = 3.1 if is_powered() else (2.0 if analyzed else 1.15)


func _apply_quest_identity_state() -> void:
	var target_id := current_target_control_id()
	for control_id: String in CONTROL_ORDER:
		var control := find_child("PuzzleControl_%s" % control_id, true, false) as Node3D
		if control == null:
			continue
		var core := control.find_child("QuestStateCore", true, false) as MeshInstance3D
		if core == null:
			continue
		var complete: bool = _quest_control_is_complete(control_id)
		var is_target: bool = control_id == target_id
		if is_powered():
			core.material_override = _feedback_material(true, true)
		elif complete:
			core.material_override = _feedback_material(true, false)
		elif is_target:
			core.material_override = _light_seed_material(2, true)
		else:
			core.material_override = _light_seed_material(-1, false)
		var authored_scale: Vector3 = core.get_meta("authored_scale", core.scale)
		core.scale = authored_scale * (1.34 if is_target and not complete else 1.0)
		core.set_meta("visual_state", "powered" if is_powered() else (
			"complete" if complete else ("current" if is_target else "inactive")))
		var crown := core.get_parent() as Node3D
		if control_id in ["outer_ring", "middle_ring", "inner_ring"]:
			var selected := ["outer_ring", "middle_ring", "inner_ring"].find(control_id)
			var marker := crown.get_node_or_null("OrbitIndex_%02d" % (selected + 1)) as Node3D
			if marker != null:
				var angle := float(current_state.get(control_id, 0)) * TAU / 8.0
				var radius := 1.14 - float(selected) * 0.34
				marker.position = Vector3(sin(angle) * radius, cos(angle) * radius, -0.80)
				marker.rotation.z = -angle
		if control_id == "echo_question":
			var choice := int(current_state.get("protective_question", -1))
			for index in 4:
				var card := crown.get_node_or_null("QuestionChoice_%02d" % (index + 1)) as MeshInstance3D
				if card != null:
					card.position.z = -0.80 if index == choice else -0.64
		if control_id == "echo_collector":
			var count := int(current_state.get("echo_collected", 0))
			for index in 3:
				var echo := crown.get_node_or_null("CollectorEcho_%02d" % (index + 1)) as MeshInstance3D
				if echo != null:
					echo.material_override = _feedback_material(index < count, is_powered())


func _quest_control_is_complete(control_id: String) -> bool:
	match control_id:
		"colour_prism", "rhythm_prism", "weight_prism":
			return int(current_state.get(control_id, -1)) >= 0
		"analysis_console":
			return bool(current_state.get("composition_analyzed", false))
		"west_regulator":
			return int(current_state.get("west_regulator", 0)) == REGULATOR_TARGETS[0]
		"east_regulator":
			return int(current_state.get("east_regulator", 0)) == REGULATOR_TARGETS[1]
		"outer_ring", "middle_ring", "inner_ring":
			var ring_ids := ["outer_ring", "middle_ring", "inner_ring"]
			var ring_index := ring_ids.find(control_id)
			return int(current_state.get(control_id, 0)) == int(_active_ring_targets()[ring_index])
		"confirm":
			return is_signal_observatory_complete()
		"echo_collector":
			return int(current_state.get("echo_collected", 0)) >= 3
		"echo_signal_1", "echo_signal_2", "echo_signal_3":
			var echo_index := int(control_id.right(1)) - 1
			var classifications: Array = current_state.get("echo_classifications", [-1, -1, -1])
			return echo_index >= 0 and echo_index < classifications.size() \
				and int(classifications[echo_index]) >= 0
		"echo_question":
			return int(current_state.get("protective_question", -1)) >= 0
		"echo_beacon":
			return is_echo_garden_complete()
	return false


func _apply_gauge(gauge_name: String, value: int, target: int) -> void:
	var gauge := find_child(gauge_name, true, false) as Node3D
	if gauge == null:
		return
	var needle := gauge.get_node_or_null("PressureNeedle") as Node3D
	if needle != null:
		needle.rotation.z = deg_to_rad(-55.0 + float(value) * 55.0)
	var lamp := gauge.get_node_or_null("GaugeStateLamp") as MeshInstance3D
	if lamp != null:
		lamp.material_override = _feedback_material(value == target, is_powered())


func _feedback_material(correct: bool, powered: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	if powered:
		material.albedo_color = Color("d8b866")
		material.emission = Color("ffd778")
	elif correct:
		material.albedo_color = Color("68bdb6")
		material.emission = Color("8fe8dc")
	else:
		material.albedo_color = Color("b58a54")
		material.emission = Color("c68445")
	material.emission_enabled = true
	material.emission_energy_multiplier = 1.25 if powered or correct else 0.35
	material.roughness = 0.28
	material.metallic = 0.52
	return material


func _light_seed_material(seed_index: int, active := true) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var colors := [Color("68d9e1"), Color("c49be8"), Color("ffd778")]
	var color: Color = Color("e9e0c9") if seed_index < 0 else colors[seed_index]
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.18 if seed_index < 0 else (2.4 if active else 0.28)
	material.roughness = 0.20
	material.metallic = 0.25
	return material
