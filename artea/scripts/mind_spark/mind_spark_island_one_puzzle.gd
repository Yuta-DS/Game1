class_name MindSparkIslandOnePuzzle
extends Node3D

## Island One's complete, untimed tutorial puzzle. The authored architecture
## supplies the meshes; this controller owns interaction, feedback, replay and
## persistent state without taking save/heal away from the checkpoint root.

signal puzzle_solved(result: Dictionary)
signal puzzle_state_changed(state: Dictionary)

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
]
const SEED_NAMES := ["THOUGHT", "FEELING", "CHOICE"]

var state_store_path := StateStore.DEFAULT_PATH
var interaction_range := 12.0
var current_state: Dictionary = {}
var _store := StateStore.new()
var _configured := false
var _setup_complete := false
var _feedback_seconds := 0.0
var _feedback_text := ""
var _rotor_phase := 0.0


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
	_apply_state(false)
	set_process(true)


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
			prompt = "Q • REPLAY THOUGHT JOURNEY" if is_powered() and not bool(current_state.replay_active) \
				else "Q • SEND THIS UNDERSTANDING FORWARD"
			status = "AWARENESS BEARING SIGIL SECURED" if is_powered() else _status_summary()
	if _feedback_seconds > 0.0:
		status = _feedback_text
	return {"control_id": control_id, "prompt": prompt, "status": status}


func interact_nearest(player: Node3D) -> Dictionary:
	var control := nearest_control(player)
	if control == null:
		return {"accepted": false, "reason": "no_compass_control_nearby"}
	return interact_control(str(control.get_meta("control_id", "")))


func interact_control(control_id: String) -> Dictionary:
	if control_id not in CONTROL_ORDER:
		return {"accepted": false, "reason": "unknown_control"}
	if is_powered() and not bool(current_state.replay_active) and control_id == "confirm":
		_start_replay()
		return _result(true, "replay_started")
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
	return interact_control("confirm")


func _complete_round() -> void:
	var first_completion := not is_powered()
	current_state.ever_solved = true
	current_state.round_complete = true
	current_state.replay_active = false
	current_state.bearing_sigil_claimed = true
	_feedback("ROUTE STABLE • BEARING SIGIL SECURED", 8.0)
	_save()
	_apply_state(true)
	puzzle_state_changed.emit(get_puzzle_state())
	if first_completion:
		var harmony := _active_harmony()
		puzzle_solved.emit({
			"relic_id": "bearing_sigil",
			"emotional_reward_id": "awareness_sigil",
			"destination": "02_living_network_forest",
			"attempts": int(current_state.attempts),
			"thought_journey": get_thought_journey(),
			"creative_harmony": str(harmony.get("name", "CALM CONTRAST")),
			"art_science": str(harmony.get("art_science", "COMPLEMENTARY BALANCE")),
			"psychology_skill": str(harmony.get("psychology", "COGNITIVE DEFUSION")),
			"reasoning_bonus": bool(current_state.get("reasoning_bonus", false)),
			"analysis_observations": int(current_state.get("analysis_observations", 0)),
			"guardian_message": "You noticed the thought. You do not have to obey it or push it away. Let us understand what it is trying to tell you.",
		})


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
		return "UNDERSTANDING SENT FORWARD • AWARENESS BEARING SIGIL SECURED"
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
	for rotor in find_children("*GovernorRotor", "Node3D", true, false):
		(rotor as Node3D).rotation.y = _rotor_phase
	for packet in find_children("BridgeEnergyPacket_*", "MeshInstance3D", true, false):
		var mesh := packet as MeshInstance3D
		mesh.visible = is_powered()
		var phase := fposmod(_rotor_phase / TAU + float(mesh.get_meta("packet_phase", 0.0)), 1.0)
		var path_start: Vector3 = mesh.get_meta("path_start", Vector3.ZERO)
		var path_end: Vector3 = mesh.get_meta("path_end", Vector3.ZERO)
		mesh.position = path_start.lerp(path_end, phase)
	for pulse in find_children("LightBeamPulse_*", "MeshInstance3D", true, false):
		var light_pulse := pulse as MeshInstance3D
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
	var analysis_rotor := find_child("AnalysisRotor", true, false) as Node3D
	if analysis_rotor != null:
		analysis_rotor.rotation.y = _rotor_phase * 0.4
		analysis_rotor.rotation.x = sin(_rotor_phase) * 0.08


func _apply_state(animate: bool) -> void:
	if not is_inside_tree():
		return
	var prism_names := ["colour", "rhythm", "weight"]
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
		reward.visible = powered
		reward.position.y = 7.2 if powered else -2.0
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
	_apply_analysis_console_state()


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
