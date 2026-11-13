extends CanvasLayer
## A basic dialogue balloon for use with Dialogue Manager.

## The action to use for advancing the dialogue
@export var next_action: StringName = &"ui_accept"

## The action to use to skip typing the dialogue
@export var skip_action: StringName = &"ui_cancel"

## The dialogue resource
var resource: DialogueResource

## Temporary game states
var temporary_game_states: Array = []

## See if we are waiting for the player
var is_waiting_for_input: bool = false

## See if we are running a long mutation and should hide the balloon
var will_hide_balloon: bool = false

## A dictionary to store any ephemeral variables
var locals: Dictionary = {}

var _locale: String = TranslationServer.get_locale()

## The current line
var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			# The dialogue has finished so close the balloon
			queue_free()
	get:
		return dialogue_line

## A cooldown timer for delaying the balloon hide when encountering a mutation.
var mutation_cooldown: Timer = Timer.new()

## The base balloon anchor
@onready var balloon: Control = %Balloon

## The label showing the name of the currently speaking character
@onready var character_label: RichTextLabel = %CharacterLabel

## The label showing the currently spoken dialogue
@onready var dialogue_label: DialogueLabel = %DialogueLabel

## The menu of responses
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu

@onready var dialogue_panel: MarginContainer = balloon.get_node("MarginContainer") as MarginContainer
@onready var dialogue_margin: MarginContainer = balloon.get_node(
	"MarginContainer/PanelContainer/MarginContainer") as MarginContainer
@onready var response_template: Button = responses_menu.get_node("ResponseExample") as Button


func _ready() -> void:
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)
	_layout_for_viewport(get_viewport().get_visible_rect().size)
	get_viewport().size_changed.connect(func():
		if is_instance_valid(balloon):
			_layout_for_viewport(get_viewport().get_visible_rect().size))

	# If the responses menu doesn't have a next action set, use this one
	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)


func _layout_for_viewport(viewport_size: Vector2,
		physical_size: Vector2 = Vector2.ZERO) -> void:
	if physical_size.is_zero_approx():
		physical_size = _dialogue_physical_size(viewport_size)
	var ui_scale := _dialogue_interface_scale(viewport_size, physical_size)
	var physical_width := viewport_size.x / ui_scale
	var physical_height := viewport_size.y / ui_scale
	var phone_layout := physical_width < 700.0 or physical_height < 650.0
	if not phone_layout:
		set_meta("dialogue_layout", "authored_desktop")
		return

	# The authored balloon uses a 1710×1112 canvas. In a portrait Web viewport
	# its 20–25 px type becomes 4–6 CSS pixels. Rebuild the two bottom bands in
	# logical coordinates from readable CSS-pixel targets instead of scaling the
	# whole Control, which would also move its anchors outside the viewport.
	var portrait := physical_height >= physical_width
	var margin := (12.0 if portrait else 14.0) * ui_scale
	var gap := 8.0 * ui_scale
	var response_height := (152.0 if portrait else 94.0) * ui_scale
	var panel_height := (154.0 if portrait else 100.0) * ui_scale
	balloon.scale = Vector2.ONE
	balloon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_panel.scale = Vector2.ONE
	dialogue_panel.anchor_left = 0.0
	dialogue_panel.anchor_top = 1.0
	dialogue_panel.anchor_right = 1.0
	dialogue_panel.anchor_bottom = 1.0
	dialogue_panel.offset_left = margin
	dialogue_panel.offset_right = -margin
	dialogue_panel.offset_bottom = -(response_height + gap + margin)
	dialogue_panel.offset_top = dialogue_panel.offset_bottom - panel_height
	responses_menu.scale = Vector2.ONE
	responses_menu.anchor_left = 0.0
	responses_menu.anchor_top = 1.0
	responses_menu.anchor_right = 1.0
	responses_menu.anchor_bottom = 1.0
	responses_menu.offset_left = margin
	responses_menu.offset_right = -margin
	responses_menu.offset_bottom = -margin
	responses_menu.offset_top = -(response_height + margin)

	var character_pixels := 18.0 if portrait else 17.0
	var dialogue_pixels := 17.0 if portrait else 16.0
	var response_pixels := 16.0 if portrait else 15.0
	character_label.add_theme_font_size_override("normal_font_size",
		roundi(character_pixels * ui_scale))
	dialogue_label.add_theme_font_size_override("normal_font_size",
		roundi(dialogue_pixels * ui_scale))
	response_template.add_theme_font_size_override("font_size",
		roundi(response_pixels * ui_scale))
	response_template.custom_minimum_size.y = (48.0 if portrait else 42.0) * ui_scale
	responses_menu.add_theme_constant_override("separation", roundi(7.0 * ui_scale))
	var inner_margin := roundi((13.0 if portrait else 10.0) * ui_scale)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		dialogue_margin.add_theme_constant_override(side, inner_margin)
	set_meta("dialogue_layout", "phone_readable_v1")
	set_meta("dialogue_ui_scale", ui_scale)
	set_meta("dialogue_physical_font_pixels", dialogue_pixels)


func _dialogue_physical_size(viewport_size: Vector2) -> Vector2:
	var display_size := Vector2(DisplayServer.window_get_size())
	var css_size := Vector2.ZERO
	if OS.has_feature("web"):
		var encoded := str(JavaScriptBridge.eval(
			"JSON.stringify([window.innerWidth || 0, window.innerHeight || 0])", true))
		if encoded.begins_with("["):
			var decoded: Variant = JSON.parse_string(encoded)
			if decoded is Array and decoded.size() >= 2:
				css_size = Vector2(float(decoded[0]), float(decoded[1]))
	return _select_dialogue_physical_size(viewport_size, display_size, css_size)


func _select_dialogue_physical_size(viewport_size: Vector2, display_size: Vector2,
		css_size: Vector2 = Vector2.ZERO) -> Vector2:
	if css_size.x >= 240.0 and css_size.y >= 240.0:
		return css_size
	if display_size.x >= 240.0 and display_size.y >= 240.0:
		return display_size
	return viewport_size


func _dialogue_interface_scale(viewport_size: Vector2, physical_size: Vector2) -> float:
	if physical_size.x <= 0.0 or physical_size.y <= 0.0:
		return 1.0
	return maxf(1.0, maxf(viewport_size.x / physical_size.x,
		viewport_size.y / physical_size.y))


func _unhandled_input(_event: InputEvent) -> void:
	# Only the balloon is allowed to handle input while it's showing
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	## Detect a change of locale and update the current dialogue line to show the new language
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale() and is_instance_valid(dialogue_label):
		_locale = TranslationServer.get_locale()
		var visible_ratio = dialogue_label.visible_ratio
		self.dialogue_line = await resource.get_next_dialogue_line(dialogue_line.id)
		if visible_ratio < 1:
			dialogue_label.skip_typing()


## Start some dialogue
func start(dialogue_resource: DialogueResource, title: String, extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	resource = dialogue_resource
	self.dialogue_line = await resource.get_next_dialogue_line(title, temporary_game_states)


## Apply any changes to the balloon given a new [DialogueLine].
func apply_dialogue_line() -> void:
	mutation_cooldown.stop()

	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = tr(dialogue_line.character, "dialogue")

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	# Show our balloon
	balloon.show()
	will_hide_balloon = false

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	# Wait for input
	if dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
	elif dialogue_line.time != "":
		var time = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


## Go to the next line
func next(next_id: String) -> void:
	self.dialogue_line = await resource.get_next_dialogue_line(next_id, temporary_game_states)


#region Signals


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


func _on_mutated(_mutation: Dictionary) -> void:
	is_waiting_for_input = false
	will_hide_balloon = true
	mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	# See if we need to skip typing of the dialogue
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action)
		if mouse_was_clicked or skip_button_was_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input: return
	if dialogue_line.responses.size() > 0: return

	# When there are no response options the balloon itself is the clickable thing
	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		next(dialogue_line.next_id)
	elif event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon:
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	next(response.next_id)


#endregion
