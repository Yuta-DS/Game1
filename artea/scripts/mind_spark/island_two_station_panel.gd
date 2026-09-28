extends "res://scripts/mind_spark/quest_station_panel.gd"
## Shares Island One's accessible ivory/gold panel and movement lifecycle.
var station: QuestObjectBase
var distance_limit := 18.0
const GardenRules := preload("res://scripts/mind_spark/unfinished_light_rules.gd")
const Trace := preload("res://scripts/mind_spark/inspection_trace.gd")
const Replay := preload("res://scripts/mind_spark/recorder_replay.gd")
const Experiment := preload("res://scripts/mind_spark/causal_experiment.gd")
const Perspectives := preload("res://scripts/mind_spark/perspective_evidence.gd")

class RecorderDiagram extends Control:
	var presenter: Node3D
	func _process(_delta: float) -> void: queue_redraw()
	func _draw() -> void:
		var area := Rect2(8,8,maxf(100,size.x-16),132)
		draw_rect(area,Color("204644"))
		if not is_instance_valid(presenter): return
		var font := ThemeDB.fallback_font
		if presenter.elapsed < 0:
			draw_string(font,Vector2(18,42),"Arrange the strips, then replay.",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("fff0d3"))
			return
		var state := Replay.sample(presenter.playing_order,presenter.elapsed)
		draw_string(font,Vector2(18,34),"%d · %s"%[int(state.slot)+1,GardenRules.EVENTS[int(state.event)]],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("fff0d3"))
		var width := area.size.x / 3
		for i in 3:
			var x := 18+width*i
			draw_string(font,Vector2(x,67),["Beam","Flow","Shutter"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff0d3"))
			if i==0: draw_line(Vector2(x,103),Vector2(x+width*.65,87 if state.drift else 103),Color("abe4ce"),3)
			elif i==1: draw_rect(Rect2(x,92,width*.65*float(state.flow),10),Color("abe4ce"))
			else: draw_string(font,Vector2(x,105),"OPEN" if state.shutter_open else "CLOSED",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff0d3"))

class EvidenceDiagram extends Control:
	var channel := 0
	var setting := 0
	func _draw() -> void:
		var area := Rect2(20,15,maxf(80,size.x-40),110)
		draw_style_box(_background(), area.grow(8))
		for i in 5:
			var x := area.position.x + area.size.x * i / 4.0
			draw_line(Vector2(x,area.position.y),Vector2(x,area.end.y),Color("48716b"),1)
		var series := Trace.series(channel,setting)
		var copies := 1 if Trace.clarity(channel,setting) == 1 else 3
		for ghost in copies:
			var points := PackedVector2Array()
			for p in series: points.append(area.position + Vector2(p.x * area.size.x,(1-p.y)*area.size.y + (ghost-(copies-1)*.5)*8))
			draw_polyline(points,Color("b9f1d8"),2,true)
		var event := Trace.event_marker(channel,setting)
		if event >= 0:
			var marker := area.position.x + area.size.x * event
			draw_line(Vector2(marker,area.position.y),Vector2(marker,area.end.y),Color("f4cd82"),2)
	func _background() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("204644")
		style.set_corner_radius_all(5)
		return style

class ProjectionDiagram extends Control:
	var live: Array = [0, 0, 0]
	var target: Array = [2, 3, 1]
	func _draw() -> void:
		var origin := Vector2(30, 80)
		for i in 3:
			var receiver := Vector2(130 + i * 95, 32 + int(target[i]) * 24)
			var beam := Vector2(receiver.x, 32 + int(live[i]) * 24)
			draw_line(origin, beam, Color("258b80"), 3, true)
			draw_arc(receiver, 11, 0, TAU, 24, Color("80652e"), 3, true)
			draw_circle(beam, 5, Color("258b80"))
			draw_line(Vector2(receiver.x, 22), Vector2(receiver.x, 120), Color("b6c3b5"), 1)
		draw_circle(origin, 9, Color("80652e"))
const NODE_IDS := ["choose", "notice", "name"]
const NODE_TEXT := [
	"CHOOSE • Pause, then try one smaller step",
	"NOTICE • One attempt did not work",
	"NAME • I am predicting that I will always fail",
]

func open_object(object: QuestObjectBase, actor: Node3D, radius: float) -> void:
	station = object
	distance_limit = radius
	_build_shell(actor)

func _choice(caption: String, action: StringName, value: Variant = null) -> void:
	var button := Button.new()
	button.text = caption
	button.set_meta("focus_action", str(action) + str(value))
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 17)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("315b5c")
	style.border_color = Color("b39456")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	var focus_style := style.duplicate() as StyleBoxFlat
	focus_style.border_color = Color("fff4dc")
	focus_style.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus_style)
	button.add_theme_color_override("font_color", Color("fff4dc"))
	button.pressed.connect(func() -> void:
		_focus_action = str(action) + str(value)
		if player.global_position.distance_to(station.global_position) > distance_limit:
			_feedback = "Move closer to the instrument."
		else:
			if action == &"preview_recording":
				var recorder := station.get_node_or_null("ProductionRecorderBay")
				if recorder != null: recorder.call("replay_saved")
				_feedback="Replaying your saved reconstruction. No reward or progress is changed."
				_rebuild()
				return
			if action == &"reflect_garden":
				var quest := get_parent().get_node_or_null("QuestController")
				if quest != null: quest.call("complete_garden_reflection")
				_feedback = "Your discovery lights the route to Island Three."
				_rebuild()
				return
			var result := station.interact(action, value)
			_feedback = str(result.reason)
			if str(result.reason) == "reconsider_evidence":
				_feedback = station.EVIDENCE_HINTS[int(station.current_state.get("evidence_index", 0))]
			if str(result.reason) == "wrong_link_reset":
				_feedback = "Begin with what happened, then name the prediction, then choose a useful action. Your evidence is still saved."
			var world := get_parent()
			if world.has_method("_handle_object_result"):
				world._handle_object_result(station, result)
		_rebuild())
	_body.add_child(button)

func _rebuild() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	if station.get_meta("unfinished_light", false):
		_build_garden_controls()
		return
	_text(station.definition.display_name.to_upper(), 24)
	_text("ISLAND TWO • Read the broken pattern", 16)
	if not station.interaction_enabled:
		_text("This station is resting. Finish the current quest objective to power it.")
	elif bool(station.current_state.get("completed", false)):
		var completed_text: String = {
			"world_one.evidence_scanner": "Evidence secured. Carry the event plates and named fear to the Memory Atelier.",
			"world_one.memory_board": "Fair memory restored. Place its earned Spark, then verify both event plates.",
			"world_one.logic_gate": "Pattern verified. The Memory Gate is open toward the Hope Optics Gallery.",
			"world_one.perspective_lens": "Three viewpoints aligned. Carry the full pattern to the Truth Foundry.",
			"world_one.truth_bridge": "Grounded hope materialised. The path can now carry you into the Guardian Court.",
		}.get(station.save_id, "Station complete.")
		_text(completed_text)
	elif station.save_id.ends_with("evidence_scanner"):
		var index := clampi(int(station.current_state.get("evidence_index", 0)), 0, 2)
		_text("Evidence plates secured: %d / 3" % index)
		if not bool(station.current_state.get("scanned", false)):
			_text("Use the scanner to reveal the next practice-log fragment.")
			_choice("Scan evidence plate %d" % (index + 1), &"scan")
		else:
			_text('“' + station.EVIDENCE_CARDS[index] + '”', 22)
			_text("FACT = supported by this log. FEAR = an unproven prediction, not an invalid feeling.")
			_choice("FACT • The log supports this", &"fact")
			_choice("FEAR • This predicts more than the log shows", &"fear")
	elif station.save_id.ends_with("memory_board"):
		_text("Reconstruct a helpful response: observation → interpretation → action. Use the evidence you just recovered.")
		var links: Array = station.current_state.get("sequence", [])
		_text("CONNECTED: " + (" → ".join(links) if not links.is_empty() else "No links yet"), 20)
		for i in 3:
			_choice(NODE_TEXT[i], &"node", NODE_IDS[i])
		_choice("Undo the last link", &"undo")
		_choice("Clear the current pattern", &"reset")
	elif station.save_id.ends_with("logic_gate"):
		var inserted := int(station.current_state.get("progress", 0))
		_text("ARCHIVE VERIFICATION • %d / 2 EVENT PLATES" % inserted, 20)
		_text("The Memory Spark powers the engine. These plates confirm an attempt happened and another attempt followed a pause.")
		_choice("Insert verified event plate %d" % (inserted + 1), &"place_evidence")
	elif station.save_id.ends_with("perspective_lens"):
		var angle := int(station.current_state.get("angle_step", -1))
		var views := [
			"CLOSE VIEW • One attempt was difficult.",
			"PATTERN VIEW • A pause was followed by another attempt.",
			"FORWARD VIEW • The next step can use what the attempts taught.",
		]
		_text("PERSPECTIVE LABORATORY • %d / 3 VIEWS" % (angle + 1), 20)
		_text(views[angle] if angle >= 0 else "Change distance and direction without changing the recorded event.")
		_choice("Rotate to the next evidence-supported view", &"turn")
		_choice("Reset the optical sequence", &"reset")
	elif station.save_id.ends_with("truth_bridge"):
		_text("TRUTH FOUNDRY • Which statement can the repaired memory support?", 20)
		_choice("Fear • One difficult attempt proves I will always fail", &"fear")
		_choice("Fantasy • If I hope enough, every attempt will be easy", &"fantasy")
		_choice("Grounded hope • One difficult attempt can teach my next step", &"true")
	_text("No timer or lost rewards. Read, experiment, and revise.", 16)
	if not _feedback.is_empty():
		_text(_feedback, 16)
	var close := Button.new()
	close.text = "Return to the island · Esc"
	close.custom_minimum_size.y = 40
	close.pressed.connect(queue_free)
	_body.add_child(close)
	close.grab_focus()

func _build_garden_controls() -> void:
	var titles := ["Evidence inspection", "Mechanical recorder", "Causal reconstruction", "Perspective workshop", "Living light projector"]
	var index := GardenRules.IDS.find(station.save_id)
	_text(titles[index] if index >= 0 else "Garden instrument", 24)
	_text("GARDEN OF UNFINISHED LIGHT", 16)
	var s: Dictionary = station.current_state
	if index == 1:
		var diagram := RecorderDiagram.new()
		diagram.custom_minimum_size=Vector2(0,145)
		diagram.presenter=station.get_node_or_null("ProductionRecorderBay")
		_body.add_child(diagram)
	if not station.interaction_enabled:
		_text("Follow the current objective to bring this instrument online.")
	elif bool(s.get("completed", false)):
		_text("Your work is preserved. Follow the next instrument's light.")
		if index == 1: _choice("Replay the saved reconstruction", &"preview_recording")
		if index == 4:
			_text('Ari: “I still have something to learn. Now I know where to start.”')
			var result: Variant = s.get("result", {})
			_text("Approach: " + str(result.get("approach", "Previously restored") if result is Dictionary else "Previously restored"))
			_choice("Share the discovery and reveal the route to Island Three", &"reflect_garden")
	else:
		match index:
			0:
				_text('Ari: “It stopped when I touched it. Maybe I should never have tried.” Inspect what happened before deciding why.')
				var settings: Array = s.get("adjustments", [0, 0, 0])
				var found: Array = s.get("observations", [false, false, false])
				var channel := clampi(int(s.get("last_channel",0)),0,2)
				for i in 3:
					_choice(("✓ " if found[i] else "") + Trace.TITLES[i], &"channel", i)
				var diagram := EvidenceDiagram.new()
				diagram.custom_minimum_size = Vector2(0,145)
				diagram.channel = channel
				diagram.setting = int(settings[channel])
				_body.add_child(diagram)
				_text(Trace.READINGS[channel][int(settings[channel])],20)
				_text(["Horizontal: time. Vertical: beam displacement. Gold marker: Ari's later touch. Focus until the trace is single and sharp.","Horizontal: recorded time. Vertical: flow. Gold marker: shutter closure. Find the window showing which changed first.","Vertical: flow. Open the bypass in steps. The shutter releases only at the final detent."][channel],16)
				if channel > 0: _text("Shutter: " + ("OPEN" if Trace.shutter_open(channel,int(settings[channel])) else "CLOSED"),16)
				if found[channel]: _text(GardenRules.OBSERVATIONS[channel],18)
				else:
					_choice(["Turn focus control", "Advance recorder frame", "Turn bypass valve"][channel], &"adjust", channel)
					_choice("Record this observation", &"capture", channel)
			1:
				_text("Replay the recorded event. Match the strips to the evidence: drift appears first; lost flow triggers protection.")
				var order: Array = s.get("timeline", [2, 0, 1])
				for i in 3: _text("%d. %s" % [i + 1, GardenRules.EVENTS[int(order[i])]], 20)
				_choice("Exchange strips 1 and 2", &"swap", 0)
				_choice("Exchange strips 2 and 3", &"swap", 1)
				_choice("Replay reconstruction", &"replay")
			2:
				for observation in GardenRules.OBSERVATIONS: _text(observation, 16)
				_text("Test what the observations support. The cause of the earlier beam drift is still unknown.", 17)
				var models := ["The shutter is permanently jammed closed", "The protective shutter responds to cooling flow", "The shutter stays open regardless of cooling flow"]
				for i in 3: _choice(("✓ " if int(s.get("model", -1)) == i else "") + models[i], &"model", i)
				var tested: Array=s.get("tested_conditions",[false,false])
				for trial in 2:
					_choice(("✓ " if tested[trial] else "") + ["Restrict the test line", "Open the test bypass"][trial],&"trial",trial)
					var selected := int(s.get("model",-1))
					if selected>=0:
						var predicted := "OPEN" if Experiment.prediction(selected,trial) else "CLOSED"
						var measured := ("OPEN" if Experiment.outcome(trial).shutter_open else "CLOSED") if tested[trial] else "not tested"
						_text("%s — prediction: %s; observed: %s"%[Experiment.TRIAL_NAMES[trial],predicted,measured],16)
				_choice("Compare explanation with both tests", &"test")
			3:
				var view: int = int(s.get("view", 0))
				var views := Perspectives.ACCOUNTS
				var answers: Array = s.get("view_answers", [false, false, false])
				for i in 3: _choice(("✓ " if answers[i] else "") + ["Ari's experience", "Machine behaviour", "Available help"][i], &"view", i)
				_text(views[view], 21)
				_text("Each plate contributes something different. Ari's feeling is valid without being mechanical proof; help is an option, not an obligation. What does this plate add?")
				for i in [2, 0, 1]: _choice(Perspectives.CONTRIBUTIONS[i], &"interpret", i)
			4:
				_text("This is a fictional light-pattern instrument: its linked controls are a puzzle, not a simulation of real mirror optics.",16)
				_text("Choose a useful approach. Every approach can restore the garden; none promises that every future attempt will be easy.")
				for i in 3: _choice(("✓ " if int(s.get("approach", -1)) == i else "") + GardenRules.APPROACHES[i], &"approach", i)
				if s.has("approach"):
					if int(s.approach) == 1: _text("Ari holds the reference plate steady. Adjust the mirror and shutter together.", 16)
					if not bool(s.get("cooling_ready", true)): _choice("Open the cooling circulation valve", &"cooling")
					var diagram := ProjectionDiagram.new()
					diagram.custom_minimum_size = Vector2(0, 145)
					diagram.live = s.get("optics", [0, 0, 0])
					diagram.target = GardenRules.TARGETS[int(s.approach)]
					_body.add_child(diagram)
					_text("Green dots: projection. Gold circles: receivers. Four positions wrap around. Mirror also moves spread; shutter also moves the plate.", 16)
					_text("Projection %s · Receiver %s" % [str(diagram.live), str(diagram.target)], 16)
					for i in 3: _choice(["Turn mirror + spread", "Adjust shutter + plate", "Shift projection plate"][i], &"tune", i)
					_choice("Undo adjustment", &"undo")
					_choice("Project the leaf pattern", &"project")
		_choice("Reset this experiment", &"reset")
	if not _feedback.is_empty(): _text(_feedback, 17)
	_text("Untimed · mistakes do not remove evidence or rewards", 15)
	var close := Button.new()
	close.text = "Return to garden · Esc"
	close.custom_minimum_size.y = 44
	close.pressed.connect(queue_free)
	_body.add_child(close)
	var next_focus: Button
	for child in _body.get_children():
		if child is Button:
			if next_focus == null: next_focus = child
			if child.get_meta("focus_action", "") == _focus_action and not _focus_action.is_empty():
				next_focus = child
				break
	if next_focus != null: call_deferred("_focus_if_current", next_focus)

func _focus_if_current(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree() and button.is_visible_in_tree():
		button.grab_focus()
