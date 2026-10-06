extends CanvasLayer
## Accessible, untimed controls for the existing physical quest instruments.
var puzzle: MindSparkIslandOnePuzzle
var player: Node3D
var control_id := ""
var _mouse_mode: int
var _player_processing := false
var _body: VBoxContainer
var _feedback := ""
var _panel: PanelContainer
var _panel_style: StyleBoxFlat
var _scroll: ScrollContainer
var _content_width := 490.0
var _ui_scale := 1.0
var _focus_action := ""
var _prediction_enabled := false
var _predicted_phase := -1
const ACTION_TITLES := {
	"colour_prism":"Route the next light seed", "rhythm_prism":"Change the rhythm seed",
	"weight_prism":"Change the balance seed", "analysis_console":"Compare the light composition",
	"west_regulator":"Adjust the first pressure regulator", "east_regulator":"Adjust the second pressure regulator",
	"outer_ring":"Turn Notice and Understand", "middle_ring":"Turn Understand and Choose",
	"inner_ring":"Turn Choose and Notice backward", "confirm":"Verify alignment and form the Prism"}

class PhaseDial extends Control:
	var phase := 0
	var target := 0
	var ui_scale := 1.0
	func _draw() -> void:
		var safe_scale := maxf(ui_scale, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * safe_scale)
		var center := size / safe_scale * .5
		draw_circle(center, 58, Color("263c40"))
		draw_arc(center, 58, 0, TAU, 64, Color("b39456"), 3, true)
		for notch in 8:
			var point := center + Vector2.from_angle(float(notch) * TAU / 8.0 - PI / 2.0) * 46
			draw_circle(point, 5, Color("f1e5ca"))
			if notch == target:
				draw_arc(point, 9, 0, TAU, 24, Color("f5cc72"), 3, true)
		var tip := center + Vector2.from_angle(float(phase) * TAU / 8.0 - PI / 2.0) * 46
		draw_line(center, tip, Color("74d6be"), 4, true)
		draw_circle(center, 7, Color("74d6be"))

func open(station: MindSparkIslandOnePuzzle, actor: Node3D, id: String) -> void:
	puzzle = station
	control_id = id
	_build_shell(actor)

func _build_shell(actor: Node3D) -> void:
	player = actor
	_mouse_mode = Input.mouse_mode
	_player_processing = player.is_physics_processing()
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	layer = 80
	var shade := ColorRect.new()
	shade.color = Color(0.025,.045,.06,.22)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	_panel=panel
	var laboratory_theme := Theme.new()
	var font := preload("res://assets/Fonts/celestial/NunitoSans.ttf").duplicate() as FontFile
	font.multichannel_signed_distance_field=true
	laboratory_theme.default_font=font
	panel.theme=laboratory_theme
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color("f1e5ca")
	_panel_style.border_color = Color("b39456")
	panel.add_theme_stylebox_override("panel",_panel_style)
	add_child(panel)
	_scroll=ScrollContainer.new()
	_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation",9)
	_scroll.add_child(_body)
	get_viewport().size_changed.connect(_layout_panel)
	_layout_panel()
	_rebuild()

func _layout_panel(viewport_size: Vector2 = Vector2.ZERO,
		physical_size: Vector2 = Vector2.ZERO) -> void:
	if viewport_size.is_zero_approx():
		viewport_size = get_viewport().get_visible_rect().size if OS.has_feature("web") \
			else Vector2(get_window().size)
	if physical_size.is_zero_approx():
		physical_size = _quest_panel_physical_size(viewport_size)
	_ui_scale = _quest_panel_interface_scale(viewport_size, physical_size)
	scale=Vector2.ONE
	var width_px := minf(560.0, physical_size.x - 24.0)
	var top_px := 96.0 if physical_size.y > 500.0 else 12.0
	var desired_size_px := Vector2(width_px, physical_size.y - top_px - 12.0)
	var desired_size := desired_size_px * _ui_scale
	_panel.position=Vector2(physical_size.x-width_px-12.0, top_px) * _ui_scale
	_content_width=maxf(160.0,width_px-70.0) * _ui_scale
	_panel_style.set_border_width_all(maxi(2, roundi(3.0 * _ui_scale)))
	_panel_style.set_corner_radius_all(roundi(12.0 * _ui_scale))
	_panel_style.content_margin_left = 24.0 * _ui_scale
	_panel_style.content_margin_right = 24.0 * _ui_scale
	_panel_style.content_margin_top = 20.0 * _ui_scale
	_panel_style.content_margin_bottom = 20.0 * _ui_scale
	_body.add_theme_constant_override("separation", roundi(9.0 * _ui_scale))
	for child in _body.get_children():
		_scale_existing_control(child)
	_scroll.custom_minimum_size=Vector2(0,maxf(120.0 * _ui_scale,
		desired_size.y-40.0 * _ui_scale))
	_panel.size=desired_size
	_panel.set_deferred("size",desired_size)
	set_meta("quest_panel_layout", "physical_viewport_v2")
	set_meta("quest_panel_ui_scale", _ui_scale)
	set_meta("quest_panel_physical_size", physical_size)

func _scale_existing_control(control: Control) -> void:
	if control is Label:
		control.custom_minimum_size.x=_content_width
	if control.has_meta("physical_font_size"):
		control.add_theme_font_size_override("font_size",
			roundi(float(control.get_meta("physical_font_size")) * _ui_scale))
	if control.has_meta("physical_min_height"):
		control.custom_minimum_size.y = \
			float(control.get_meta("physical_min_height")) * _ui_scale
	if control is PhaseDial:
		(control as PhaseDial).ui_scale = _ui_scale
		control.queue_redraw()

func _quest_panel_physical_size(viewport_size: Vector2) -> Vector2:
	# Native and headless runs already report the drawable viewport in pixels.
	# Browser builds need the CSS viewport because a high-DPI canvas can be
	# several times larger than the screen the player is actually holding.
	if not OS.has_feature("web"):
		return viewport_size
	var display_size := Vector2(DisplayServer.window_get_size())
	var css_size := Vector2.ZERO
	var encoded := str(JavaScriptBridge.eval(
		"JSON.stringify([window.innerWidth || 0, window.innerHeight || 0])", true))
	if encoded.begins_with("["):
		var decoded: Variant = JSON.parse_string(encoded)
		if decoded is Array and decoded.size() >= 2:
			css_size = Vector2(float(decoded[0]), float(decoded[1]))
	return _select_quest_panel_physical_size(viewport_size, display_size, css_size)

func _select_quest_panel_physical_size(viewport_size: Vector2,
		display_size: Vector2, css_size: Vector2 = Vector2.ZERO) -> Vector2:
	if css_size.x >= 240.0 and css_size.y >= 240.0:
		return css_size
	if display_size.x >= 240.0 and display_size.y >= 240.0:
		return display_size
	return viewport_size

func _quest_panel_interface_scale(viewport_size: Vector2,
		physical_size: Vector2) -> float:
	if physical_size.x <= 0.0 or physical_size.y <= 0.0:
		return 1.0
	return maxf(1.0, maxf(viewport_size.x / physical_size.x,
		viewport_size.y / physical_size.y))

func _text(value: String, size: int = 18) -> void:
	var label := Label.new()
	label.text = value
	label.custom_minimum_size.x = _content_width
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color",Color("263c40"))
	label.set_meta("physical_font_size", size)
	label.add_theme_font_size_override("font_size",roundi(size * _ui_scale))
	_body.add_child(label)

func _button(title: String, action: String, value: int = 0) -> void:
	var button := Button.new()
	button.text = title
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.set_meta("focus_action",action+str(value))
	button.set_meta("physical_min_height", 44.0)
	button.set_meta("physical_font_size", 17.0)
	button.custom_minimum_size.y = 44.0 * _ui_scale
	button.add_theme_font_size_override("font_size",roundi(17.0 * _ui_scale))
	var face := StyleBoxFlat.new()
	face.bg_color = Color("315b5c")
	face.border_color = Color("b39456")
	face.set_border_width_all(maxi(1, roundi(_ui_scale)))
	face.set_corner_radius_all(roundi(5.0 * _ui_scale))
	button.add_theme_stylebox_override("normal", face)
	var hover := face.duplicate() as StyleBoxFlat
	hover.bg_color = Color("487a75")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", Color("fff4dc"))
	button.pressed.connect(func() -> void:
		_focus_action=action+str(value)
		var result := puzzle.station_action(control_id,action,value,player)
		_feedback = {"phase_mismatch":"Not aligned yet. Match the green hand to the gold circle, then capture.",
			"station_updated":"Adjustment saved. Observe what changed.",
			"interpretation_needs_revision":"Some relationships do not fit yet. Revisit the evidence and your preparation question.",
			"completed":"Echo Seed earned. Next: checkpoint and Spark relay."}.get(str(result.reason),str(result.reason).replace("_"," ").capitalize())
		if action=="tune" and _prediction_enabled and _predicted_phase>=0 and bool(result.accepted):
			var actual: int=puzzle.get_puzzle_state().echo_phases[int(control_id.right(1))-1]
			_feedback="Prediction matched. What pattern helped you?" if actual==_predicted_phase else "The hand reached notch %d, not %d. Count the steps and try another prediction."%[actual+1,_predicted_phase+1]
			_predicted_phase=-1
		_rebuild())
	_body.add_child(button)

func _rebuild() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var state := puzzle.get_puzzle_state()
	var title: String={"colour_prism":"Light Spectrum", "rhythm_prism":"Rhythm Instrument",
		"weight_prism":"Balance Instrument", "analysis_console":"Evidence Analysis",
		"west_regulator":"Notice • Pressure Control", "east_regulator":"Understand • Pressure Control",
		"outer_ring":"Notice + Understand", "middle_ring":"Understand + Choose", "inner_ring":"Choose + Notice",
		"confirm":"Signal Prism Verification", "echo_collector":"Signal Prism Collector",
		"echo_signal_1":"Echo Receiver I", "echo_signal_2":"Echo Receiver II", "echo_signal_3":"Echo Receiver III",
		"echo_question":"A Helpful Preparation", "echo_beacon":"Caution Beacon"}.get(control_id,control_id.replace("_"," "))
	_text(title,24)
	_text("No timer. Experiment, read the response, and revise your choices.",16)
	if control_id.begins_with("echo_signal_"):
		var index := int(control_id.right(1))-1
		if not bool(state.prism_installed):
			_text("The receiver has no power. Install your Signal Prism at the collector first.")
		elif not bool(state.echo_captured[index]):
			_text("Align the receiver with the source. One gear advances two notches; the other advances three. Both wrap around an eight-notch wheel.")
			var dial := PhaseDial.new()
			dial.ui_scale = _ui_scale
			dial.set_meta("physical_min_height", 130.0)
			dial.custom_minimum_size = Vector2(0,130.0 * _ui_scale)
			dial.phase = int(state.echo_phases[index])
			dial.target = puzzle.ECHO_PHASE_TARGETS[index]
			_body.add_child(dial)
			var source := ""
			var receiver := ""
			for notch in 8:
				source += "◆ " if notch == puzzle.ECHO_PHASE_TARGETS[index] else "· "
				receiver += "◆ " if notch == int(state.echo_phases[index]) else "· "
			_text("Gold circle: source • Green hand: receiver\nSOURCE     " + source + "\nRECEIVER  " + receiver,16)
			var challenge := CheckButton.new()
			challenge.text="Optional: predict before turning"
			challenge.set_meta("physical_font_size", 17.0)
			challenge.set_meta("physical_min_height", 44.0)
			challenge.custom_minimum_size.y = 44.0 * _ui_scale
			challenge.add_theme_font_size_override("font_size", roundi(17.0 * _ui_scale))
			challenge.button_pressed=_prediction_enabled
			challenge.add_theme_color_override("font_color",Color("263c40"))
			challenge.add_theme_color_override("font_hover_color",Color("263c40"))
			challenge.add_theme_color_override("font_focus_color",Color("263c40"))
			challenge.add_theme_color_override("font_pressed_color",Color("263c40"))
			challenge.toggled.connect(func(value):
				_prediction_enabled=value
				_rebuild())
			_body.add_child(challenge)
			if _prediction_enabled:
				_text("Where will your next turn land? Count clockwise from the top (notch 1). This does not affect your reward.",16)
				var prediction := OptionButton.new()
				prediction.set_meta("physical_font_size", 17.0)
				prediction.set_meta("physical_min_height", 44.0)
				prediction.custom_minimum_size.y = 44.0 * _ui_scale
				prediction.add_theme_font_size_override("font_size", roundi(17.0 * _ui_scale))
				prediction.add_item("Choose a predicted notch",-1)
				for notch in 8: prediction.add_item("Notch %d"%(notch+1),notch)
				prediction.select(_predicted_phase+1)
				prediction.item_selected.connect(func(index): _predicted_phase=index-1)
				_body.add_child(prediction)
			_button("Turn the two-notch gear (+2)","tune",2)
			_button("Turn the three-notch gear (+3)","tune",3)
			_button("Reverse the two-notch gear (−2)","tune",-2)
			_button("Capture the aligned echo","capture")
		else:
			_text('“' + puzzle.ECHO_SIGNALS[index] + '”',22)
			_text("Fact: something observed. Possibility: something that may happen. Unsure: not enough information yet.")
			for category in 3:
				_button(("✓ " if int(state.echo_classifications[index]) == category else "") + puzzle.ECHO_CATEGORIES[category],"classify",category)
	elif control_id == "echo_question":
		_text("Which question helps you prepare without treating worry as a prediction?")
		for choice in 4:
			_button(("✓ " if int(state.protective_question) == choice else "") + puzzle.PROTECTIVE_QUESTIONS[choice].capitalize(),"question",choice)
	else:
		_text(str(puzzle.prompt_for_player(player).get("status",puzzle.current_objective())))
		var action_title: String = ACTION_TITLES.get(control_id,"Operate instrument")
		if control_id == "echo_collector":
			action_title = "Install the Signal Prism" if not bool(state.prism_installed) else "Prism installed — visit the three receivers"
		elif control_id == "echo_beacon":
			action_title = "Test my interpretation"
		_button(action_title,"operate")
		if not control_id.begins_with("echo_") and not puzzle.is_signal_observatory_complete():
			_button("Undo my last adjustment","undo")
	if not _feedback.is_empty():
		_text(_feedback,16)
	var close := Button.new()
	close.text = "Close instrument  ·  Esc"
	close.set_meta("physical_min_height", 44.0)
	close.set_meta("physical_font_size", 17.0)
	close.custom_minimum_size.y = 44.0 * _ui_scale
	close.add_theme_font_size_override("font_size", roundi(17.0 * _ui_scale))
	close.pressed.connect(queue_free)
	_body.add_child(close)
	var focus: Control
	for child in _body.get_children():
		if child is Button:
			if focus==null: focus=child
			if child.get_meta("focus_action","")==_focus_action and not _focus_action.is_empty():
				focus=child
				break
	if focus!=null:
		(func():
			if is_instance_valid(focus) and focus.is_inside_tree() and not focus.is_queued_for_deletion():
				focus.grab_focus()).call_deferred()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()

func _exit_tree() -> void:
	Input.mouse_mode = _mouse_mode
	if is_instance_valid(player):
		player.set_physics_process(_player_processing)
