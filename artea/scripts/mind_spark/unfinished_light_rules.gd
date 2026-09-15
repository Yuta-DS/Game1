extends RefCounted
## Persistent, untimed investigation rules shared by world instruments and UI.
const IDS := ["world_one.evidence_scanner", "world_one.memory_board", "world_one.logic_gate", "world_one.perspective_lens", "world_one.truth_bridge"]
const OBSERVATIONS := [
	"The beam drifted BEFORE Ari touched the control.",
	"Cooling fell before the protective shutter closed.",
	"Opening the test valve restores flow and releases the shutter."]
const EVENTS := ["Beam begins drifting", "Cooling flow falls", "Protective shutter closes"]
const SCANNER_TARGETS := [2, 1, 3]
const STATE_VERSION := 2
const APPROACHES := ["Test a smaller bed", "Work with Ari", "Restore cooling first"]
const TARGETS := [[2, 3, 1], [1, 2, 3], [3, 1, 2]]

static func use(station: Node, action: StringName, value: Variant) -> Array:
	var s: Dictionary = station.current_state
	var id: String = station.save_id
	s["garden_state_version"] = STATE_VERSION
	if action == &"reset":
		for key in ["adjustments", "timeline", "model", "view", "view_answers", "optics", "history", "approach", "cooling_ready", "experiment", "replay_serial", "last_channel", "trial", "tested_conditions"]:
			s.erase(key)
		return feedback(station, "Experiment reset. Your verified observations remain saved.")
	match id:
		"world_one.evidence_scanner":
			if action == &"channel" and value is int and value >= 0 and value < 3:
				s.last_channel = value
				return feedback(station, "Inspect this instrument, adjust, then record what you can observe.")
			var settings: Array = s.get("adjustments", [0, 0, 0])
			var found: Array = s.get("observations", [false, false, false])
			if action == &"adjust" and value is int and value >= 0 and value < 3:
				settings[value] = (int(settings[value]) + 1) % 4
				s.adjustments = settings
				s.last_channel = value
				return feedback(station, "Inspect the live reading, then capture the observation.")
			if action == &"capture" and value is int and value >= 0 and value < 3:
				s.last_channel = value
				if settings[value] != SCANNER_TARGETS[value]:
					return feedback(station, "Reading obscured. Adjust this channel until its trace is clear.", false)
				found[value] = true
				s.observations = found
				if found.all(func(v): return v): return finish(station, {"observations": OBSERVATIONS})
				return feedback(station, OBSERVATIONS[value])
		"world_one.memory_board":
			var timeline: Array = s.get("timeline", [2, 0, 1]).map(func(v): return int(v))
			if action == &"swap" and value is int and value >= 0 and value < 2:
				var held: int = timeline[value]
				timeline[value] = timeline[value + 1]
				timeline[value + 1] = held
				s.timeline = timeline
				return feedback(station, "Strips moved. Replay to compare with the recorder.")
			if action == &"replay":
				s.replay_serial = int(s.get("replay_serial", 0)) + 1
				if timeline != [0, 1, 2]: return feedback(station, "The shutdown follows the loss of flow; drift was visible earlier. Revise the mismatched strips.", false)
				return finish(station, {"timeline": timeline, "spark_awarded": true})
		"world_one.logic_gate":
			if action == &"trial" and value is int and value>=0 and value<2:
				s.trial=value
				var tested: Array=s.get("tested_conditions",[false,false])
				tested[value]=true
				s.tested_conditions=tested
				return feedback(station,"Measured flow is low; the shutter closes." if value==0 else "Measured flow is restored; the shutter opens.")
			if action == &"model" and value is int and value >= 0 and value < 3:
				s.model = value
				return feedback(station, "Model selected. Run it against all three observations.")
			if action == &"test":
				var tested: Array=s.get("tested_conditions",[false,false])
				if not tested.all(func(v):return v): return feedback(station,"Test both the restricted line and the open bypass before comparing your explanation.",false)
				s.experiment = int(s.get("model", -1))
				if s.experiment < 0: return feedback(station,"Choose an explanation to compare with the measurements.",false)
				if s.experiment != 1: return feedback(station, "The shutter closed with restricted flow, then opened with the bypass. An always-open or permanently-closed model cannot explain both measurements.", false)
				return finish(station, {"model": "flow_loss_protective_shutdown"})
		"world_one.perspective_lens":
			if action == &"view" and value is int and value >= 0 and value < 3:
				s.view = value
				return feedback(station, "Observe this perspective, then identify what it contributes.")
			if action == &"interpret" and value is int and value >= 0 and value < 3:
				var view: int = int(s.get("view", 0))
				if value != view: return feedback(station, "That belongs to a different viewpoint. A feeling, a mechanism and an offer of help contribute different information.", false)
				var answers: Array = s.get("view_answers", [false, false, false])
				answers[view] = true
				s.view_answers = answers
				if answers.all(func(v): return v): return finish(station, {"perspectives": 3})
				return feedback(station, "Perspective recorded. Explore another view.")
		"world_one.truth_bridge":
			if action == &"approach" and value is int and value >= 0 and value < 3:
				s.approach = value
				s.optics = [0, 0, 3] if value == 1 else [0, 0, 0]
				s.cooling_ready = value != 2
				s.history = []
				return feedback(station, APPROACHES[value] + ". Match the receiver pattern by adjusting the coupled controls.")
			if not s.has("approach"): return feedback(station, "Choose a supported approach first.", false)
			if action == &"cooling":
				s.cooling_ready = true
				return feedback(station, "Cooling circulation restored. The protective shutter is released.")
			if not bool(s.get("cooling_ready", true)):
				return feedback(station, "Restore the cooling flow before operating this approach.", false)
			var optics: Array = s.get("optics", [0, 0, 0]).map(func(v): return int(v))
			var history: Array = s.get("history", [])
			if action == &"tune" and value is int and value >= 0 and value < 3:
				history.append(optics.duplicate())
				if history.size() > 64: history.pop_front()
				optics[value] = (int(optics[value]) + 1) % 4
				if value == 0: optics[1] = (int(optics[1]) + 1) % 4
				if value == 1: optics[2] = (int(optics[2]) + 1) % 4
				if int(s.approach) == 1: optics[2] = 3 # Ari holds the reference plate.
				s.optics = optics
				s.history = history
				return feedback(station, "Projection updated. Mirror also changes spread; shutter also shifts the plate.")
			if action == &"undo" and not history.is_empty():
				s.optics = history.pop_back()
				s.history = history
				return feedback(station, "Last adjustment undone.")
			if action == &"project":
				if optics != TARGETS[int(s.approach)]: return feedback(station, "Some leaf veins miss their receivers. Compare the live projection with the target; nothing is lost.", false)
				return finish(station, {"approach": APPROACHES[int(s.approach)], "garden_restored": true})
	return feedback(station, "Choose an instrument control.", false)

static func feedback(station: Node, message: String, accepted := true) -> Array:
	station.current_state["garden_feedback"] = message
	station.call("_save_and_feedback", message, "◆" if accepted else "?")
	return [accepted, message]

static func finish(station: Node, result: Dictionary) -> Array:
	station.current_state["garden_feedback"] = "Investigation saved. Follow the next lit instrument."
	return [true, station.call("_complete", result)]
