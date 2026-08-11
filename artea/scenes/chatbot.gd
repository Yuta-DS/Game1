# Milo's child-safe, offline reflection panel.
#
# This scene deliberately accepts no free text, starts no model worker and
# makes no network request. Every line is authored below, keyed only by the
# current journey stage and the facilitator-selected audience register.
extends Control

@onready var chat_history: TextEdit = $VBoxContainer/ChatHistory
@onready var content: VBoxContainer = $VBoxContainer

signal chat_closed

# Compatibility focus target for milo_animations.gd. It points to a curated
# button, never to an editable text-entry control.
var user_input: Button

const MODE_INTROS := {
	"faith": "Faith Journey · Choose one small star to follow, or skip this quiet moment.",
	"universal": "Inclusive Journey · Choose one small star to follow, or skip this quiet moment.",
}

# Each choice is evidence-free: it reacts only to a deliberate button press,
# never to artwork, colour, music, an inferred emotion, or personal text.
# A skipped reflection is an equal, non-rewarding path through the experience.
const CURATED_REFLECTIONS := {
	0: {
		"title": "A quiet first step",
		"choices": [
			{
				"label": "Take one small step",
				"faith": "You can begin at your own pace. The next small step is enough for now.",
				"universal": "You can begin at your own pace. The next small step is enough for now.",
			},
			{
				"label": "Look around first",
				"faith": "You can explore before choosing a path. There is nothing to get right here.",
				"universal": "You can explore before choosing a path. There is nothing to get right here.",
			},
		],
	},
	1: {
		"title": "Mind Spark",
		"choices": [
			{
				"label": "Practise a hopeful thought",
				"faith": "You chose words to practise. You may keep them, choose another, or carry on.",
				"universal": "You chose words to practise. You may keep them, choose another, or carry on.",
			},
			{
				"label": "Notice, then move on",
				"faith": "You do not have to explain a thought to continue your adventure.",
				"universal": "You do not have to explain a thought to continue your adventure.",
			},
		],
	},
	2: {
		"title": "Heart Melody",
		"choices": [
			{
				"label": "Give a feeling a sound",
				"faith": "You can name a feeling without having to explain it. Let the music be what you choose.",
				"universal": "You can name a feeling without having to explain it. Let the music be what you choose.",
			},
			{
				"label": "Keep listening",
				"faith": "You can listen quietly, change the sound, or move on when you are ready.",
				"universal": "You can listen quietly, change the sound, or move on when you are ready.",
			},
		],
	},
	3: {
		"title": "Creator's Light",
		"choices": [
			{
				"label": "Make a new mark",
				"faith": "Your artwork belongs to you. There is no right way to make it.",
				"universal": "Your artwork belongs to you. There is no right way to make it.",
			},
			{
				"label": "Choose what I like",
				"faith": "You get to decide what matters in your creation. Milo will not judge it.",
				"universal": "You get to decide what matters in your creation. Milo will not judge it.",
			},
		],
	},
	4: {
		"title": "Crown of Life",
		"choices": [
			{
				"label": "Celebrate a discovery",
				"faith": "The Crown can remind you of the gifts you explored on this faith journey.",
				"universal": "The Crown celebrates the choices and discoveries you made in this journey.",
			},
			{
				"label": "Continue to the castle",
				"faith": "You can continue whenever you are ready. Your next step is yours to choose.",
				"universal": "You can continue whenever you are ready. Your next step is yours to choose.",
			},
		],
	},
}

const SKIP_CHOICE := {
	"label": "Skip this reflection",
	"faith": "That is okay. Skipping this moment does not change your journey.",
	"universal": "That is okay. Skipping this moment does not change your journey.",
}

var _stage := 0
var _mode := "faith"
var _choices: VBoxContainer


func _ready() -> void:
	# This is a display transcript, not a text-input surface.
	chat_history.editable = false
	chat_history.selecting_enabled = true
	_resolve_safe_context()
	_show_choices()


func _resolve_safe_context() -> void:
	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return

	_stage = clampi(int(js.get("stage")), 0, CURATED_REFLECTIONS.size() - 1)
	if str(js.get("audience_mode")) == "universal":
		_mode = "universal"


func _show_choices() -> void:
	var reflection: Dictionary = CURATED_REFLECTIONS.get(_stage, CURATED_REFLECTIONS[0])
	chat_history.text = "Milo · %s\n\n%s\n\nChoose one, or skip. Nothing you choose here changes your progress." % [
		reflection["title"],
		MODE_INTROS[_mode],
	]
	_clear_choices()

	var prompt := Label.new()
	prompt.text = "Choose a star path"
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", Color(0.86, 0.91, 1.0))
	_choices.add_child(prompt)

	for choice in reflection["choices"]:
		var choice_button := _choice_button(choice)
		_choices.add_child(choice_button)
		if user_input == null:
			user_input = choice_button
	var skip_button := _choice_button(SKIP_CHOICE)
	_choices.add_child(skip_button)
	if user_input == null:
		user_input = skip_button

	var quiet_note := Label.new()
	quiet_note.text = "Milo uses only these local, guided choices. Your artwork and colours are not analysed."
	quiet_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiet_note.add_theme_font_size_override("font_size", 14)
	quiet_note.add_theme_color_override("font_color", Color(0.70, 0.78, 0.92))
	_choices.add_child(quiet_note)

	_choices.add_child(_quiet_button("Need help", _show_support))
	_choices.add_child(_quiet_button("Close", close_chat))


func _choose_reflection(choice: Dictionary) -> void:
	var reply := str(choice.get(_mode, choice.get("universal", "")))
	chat_history.text = "Milo · %s\n\n%s\n\nYou can continue your adventure whenever you are ready." % [
		str(choice.get("label", "A quiet choice")),
		reply,
	]
	_clear_choices()
	var continue_button := _quiet_button("Continue my adventure", close_chat)
	_choices.add_child(continue_button)
	user_input = continue_button
	_choices.add_child(_quiet_button("Need help", _show_support))
	_choices.add_child(_quiet_button("Close", close_chat))


func _clear_choices() -> void:
	if _choices == null:
		_choices = VBoxContainer.new()
		_choices.name = "CuratedChoices"
		_choices.add_theme_constant_override("separation", 8)
		content.add_child(_choices)
		return

	for child in _choices.get_children():
		child.queue_free()


func _choice_button(choice: Dictionary) -> Button:
	var button := _quiet_button(str(choice.get("label", "Continue")), _choose_reflection.bind(choice))
	button.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	return button


func _quiet_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.add_theme_font_size_override("font_size", 17)
	button.tooltip_text = "This choice is local and does not change your rewards."

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.16, 0.32, 0.94)
	normal.border_color = Color(0.48, 0.73, 1.0, 0.82)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)
	normal.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.28, 0.49, 0.98)
	hover.border_color = Color(0.83, 0.70, 1.0, 0.96)
	button.add_theme_stylebox_override("hover", hover)
	button.pressed.connect(action)
	return button


func _show_support() -> void:
	var safeguards := get_node_or_null("/root/JourneySafeguards")
	if safeguards != null and safeguards.has_method("show_support"):
		safeguards.show_support()


func close_chat() -> void:
	emit_signal("chat_closed")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_chat()
