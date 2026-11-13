extends "res://scripts/mind_spark/world_one_object_minigame_panel.gd"

## The Observatory and Echo Garden instruments share the same keyboard, touch,
## controller, audio and responsive game board as the physical quest objects.
## The puzzle remains the authority for prerequisites, saves and rewards.
const CHALLENGES := {
	"colour_prism": {"title": "COLOUR PRISM • LIGHT ROUTE", "mode": "route",
		"instruction": "Carry a light seed through the marked stars. Play again to try another seed.",
		"route": [Vector2i(0, 2), Vector2i(1, 1), Vector2i(2, 0)],
		"hazards": [Vector2i(2, 2), Vector2i(0, 0)], "goal": 3,
		"accent": Color("eac279")},
	"rhythm_prism": {"title": "RHYTHM PRISM • LIGHT PATTERN", "mode": "rhythm",
		"instruction": "Play the direction pattern to tune the next light seed.",
		"sequence": ["left", "up", "right", "up"], "goal": 4,
		"accent": Color("af9bf1")},
	"weight_prism": {"title": "BALANCE PRISM • WEIGHT RINGS", "mode": "align",
		"instruction": "Steer the marker into each balance ring and lock it.",
		"targets": [0.22, 0.76, 0.51], "speed": 0.65, "goal": 3,
		"accent": Color("79d8c0")},
	"analysis_console": {"title": "EVIDENCE ANALYSIS • SIGNAL SCAN", "mode": "catch",
		"instruction": "Collect bright evidence and let dark static pass before comparing the composition.",
		"goal": 4, "speed": 0.52, "accent": Color("82d9e8")},
	"west_regulator": {"title": "NOTICE • PRESSURE CALIBRATION", "mode": "align",
		"instruction": "Hold the thought signal on each ring to turn the first regulator.",
		"targets": [0.27, 0.61, 0.78], "speed": 0.61, "goal": 3,
		"accent": Color("e2c178")},
	"east_regulator": {"title": "UNDERSTAND • PRESSURE CALIBRATION", "mode": "align",
		"instruction": "Give the thought space by locking the second regulator's three rings.",
		"targets": [0.70, 0.35, 0.53], "speed": 0.69, "goal": 3,
		"accent": Color("80d9c7")},
	"outer_ring": {"title": "NOTICE RING • STAR PATTERN", "mode": "rhythm",
		"instruction": "Repeat the constellation pulse to turn Notice and Understand together.",
		"sequence": ["up", "right", "left", "up"], "goal": 4,
		"accent": Color("edc570")},
	"middle_ring": {"title": "UNDERSTAND RING • STAR ROUTE", "mode": "route",
		"instruction": "Trace the safe stars to turn Understand and Choose together.",
		"route": [Vector2i(2, 2), Vector2i(1, 1), Vector2i(0, 0)],
		"hazards": [Vector2i(0, 2), Vector2i(2, 0)], "goal": 3,
		"accent": Color("8dd9e9")},
	"inner_ring": {"title": "CHOOSE RING • REVERSE PATTERN", "mode": "rhythm",
		"instruction": "Play the reverse pulse to turn Choose and Notice backward.",
		"sequence": ["right", "down", "left", "down"], "goal": 4,
		"accent": Color("b7a8f1")},
	"confirm": {"title": "SIGNAL PRISM • FINAL TEST", "mode": "dodge",
		"instruction": "Dodge the interference, then strike when the prism opens.",
		"goal": 5, "speed": 0.72, "accent": Color("f0cb78")},
	"echo_collector": {"title": "ECHO GARDEN • PRISM INSTALLATION", "mode": "route",
		"instruction": "Carry the Signal Prism through the garden's safe roots.",
		"route": [Vector2i(0, 2), Vector2i(0, 1), Vector2i(1, 0)],
		"hazards": [Vector2i(2, 2), Vector2i(2, 1)], "goal": 3,
		"accent": Color("90ddbf")},
	"echo_signal_1": {"title": "ECHO RECEIVER I • PHASE ALIGNMENT", "mode": "align",
		"instruction": "Lock three pulses to tune and capture the first echo.",
		"targets": [0.22, 0.52, 0.77], "speed": 0.62, "goal": 3,
		"accent": Color("8fd7f1")},
	"echo_signal_2": {"title": "ECHO RECEIVER II • PHASE ALIGNMENT", "mode": "align",
		"instruction": "Lock three pulses to tune and capture the second echo.",
		"targets": [0.74, 0.29, 0.56], "speed": 0.68, "goal": 3,
		"accent": Color("c5a9f3")},
	"echo_signal_3": {"title": "ECHO RECEIVER III • PHASE ALIGNMENT", "mode": "align",
		"instruction": "Lock three pulses to tune and capture the third echo.",
		"targets": [0.40, 0.79, 0.18], "speed": 0.72, "goal": 3,
		"accent": Color("e8c985")},
	"echo_question": {"title": "HELPFUL QUESTION • QUIET PATH", "mode": "route",
		"instruction": "Guide the warning through the quiet stars to one small preparation step.",
		"route": [Vector2i(0, 2), Vector2i(1, 1), Vector2i(1, 0)],
		"hazards": [Vector2i(2, 2), Vector2i(0, 1)], "goal": 3,
		"accent": Color("d4b6f0")},
	"echo_beacon": {"title": "CAUTION BEACON • STORM TEST", "mode": "dodge",
		"instruction": "Dodge the fear-static, then strike to test the prepared signal.",
		"goal": 5, "speed": 0.75, "accent": Color("86dbd7")},
}

const CLASSIFICATION_CHALLENGES := [
	{"title": "ECHO I • FACT ROUTE", "route": [Vector2i(0, 2), Vector2i(0, 1), Vector2i(0, 0)],
		"hazards": [Vector2i(2, 2), Vector2i(2, 1)]},
	{"title": "ECHO II • POSSIBILITY ROUTE", "route": [Vector2i(2, 2), Vector2i(1, 1), Vector2i(2, 0)],
		"hazards": [Vector2i(0, 2), Vector2i(0, 1)]},
	{"title": "ECHO III • UNSURE ROUTE", "route": [Vector2i(0, 2), Vector2i(1, 1), Vector2i(1, 0)],
		"hazards": [Vector2i(2, 2), Vector2i(0, 1)]},
]

var puzzle: MindSparkIslandOnePuzzle
var control_id := ""
var _classifying_echo := false
var _pending_classification := false


static func has_challenge(id: String) -> bool:
	return CHALLENGES.has(id)


func open_instrument(station: MindSparkIslandOnePuzzle, actor: Node3D,
		id: String) -> void:
	assert(has_challenge(id), "Every Island One instrument needs a playable challenge")
	puzzle = station
	player = actor
	control_id = id
	_spec = (CHALLENGES[id] as Dictionary).duplicate(true)
	if id.begins_with("echo_signal_"):
		var index := int(id.right(1)) - 1
		_classifying_echo = bool(station.current_state.echo_captured[index])
		if _classifying_echo:
			_set_classification_spec(index)
	_mode = str(_spec.mode)
	_accent = _spec.accent
	_rng.seed = hash(id)
	_reset_round()
	_duck_ambience_for_focus()
	_build_ui()
	_close.text = "Close instrument · Esc / B"


func _set_classification_spec(index: int) -> void:
	_spec.merge(CLASSIFICATION_CHALLENGES[index], true)
	_spec.mode = "route"
	_spec.goal = 3
	_spec.instruction = "%s • trace the safe stars to sort this echo as %s." % [
		puzzle.ECHO_SIGNALS[index], puzzle.ECHO_CATEGORIES[index]]
	_mode = "route"
	_classifying_echo = true


func _command(command: String) -> void:
	if command == "action" and _finished and _pending_classification:
		_pending_classification = false
		_set_classification_spec(int(control_id.right(1)) - 1)
		_title.text = str(_spec.title)
		_instruction.text = str(_spec.instruction)
		super._command(command)
		(_touch_buttons.action as Button).text = _action_caption()
		_layout()
		_close.text = "Close instrument · Esc / B"
		return
	super._command(command)


func _apply_station_reward() -> Dictionary:
	if not is_instance_valid(puzzle):
		return {"accepted": false, "reason": "instrument_unavailable"}
	if control_id.begins_with("echo_signal_"):
		var index := int(control_id.right(1)) - 1
		if _classifying_echo:
			return puzzle.station_action(control_id, "classify", index, player)
		for _turn in 8:
			if int(puzzle.current_state.echo_phases[index]) == puzzle.ECHO_PHASE_TARGETS[index]:
				break
			var tuned := puzzle.station_action(control_id, "tune", 3, player)
			if not bool(tuned.get("accepted", false)):
				return tuned
		var captured := puzzle.station_action(control_id, "capture", 0, player)
		_pending_classification = bool(captured.get("accepted", false))
		return captured
	if control_id == "echo_question":
		return puzzle.station_action(control_id, "question",
			puzzle.PROTECTIVE_QUESTION_TARGET, player)
	return puzzle.station_action(control_id, "operate", 0, player)
