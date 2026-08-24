# Milo's child-safe, offline reflection panel.
#
# This scene deliberately accepts no free text, starts no model worker and
# makes no network request. Every line is authored below, keyed only by the
# current journey stage and the facilitator-selected audience register.
extends Control

@onready var chat_history: TextEdit = $VBoxContainer/ChatHistory
@onready var content: VBoxContainer = $VBoxContainer

signal chat_closed
signal companion_pose_requested(pose_name: String)

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

# Wonderful Counsellor Milo stays a guided, non-clinical companion.  Players
# name their own experience through authored choices; Milo never guesses a
# hidden emotion from artwork, colour, behaviour or personal text.
const EMOTION_CHECK_INS := [
	{
		"label": "I feel stressed or overwhelmed",
		"acknowledge": "I hear you. It sounds like you have been carrying a lot.",
		"reflection": "Feeling stressed does not mean you are weak. Sometimes it means your mind and heart have been working hard to cope.",
		"strength": "You are more than this moment. Naming the pressure can show honesty, courage, and self-awareness.",
		"question": "Let's explore this together. What is one thought or responsibility that feels heaviest right now?",
		"activity": "Would you like to visit the Mind Spark Kingdom and explore a kinder, more useful response to that thought?",
	},
	{
		"label": "I feel worried or unsure",
		"acknowledge": "I hear you. Worry or uncertainty can make the next step feel larger.",
		"reflection": "It sounds like not knowing what comes next may be making this moment feel harder.",
		"strength": "You are more than this moment. Naming uncertainty can show honesty and courage.",
		"question": "Let's explore this together. What is one small part you can choose, and one part you can leave for later?",
		"activity": "Would you like to visit Mind Spark, notice one thought, and choose one small hopeful response?",
	},
	{
		"label": "I feel frustrated or stuck",
		"acknowledge": "I hear you. Being stuck can be tiring.",
		"reflection": "It sounds like you have been working at something that is not moving the way you hoped.",
		"strength": "You are more than this moment. Coming back to a challenge can show persistence and flexibility.",
		"question": "Let's explore this together. Would a smaller step, a new tool, or asking someone for help make this lighter?",
		"activity": "Would you like to visit Creator's Light and make one mark without needing it to be perfect?",
	},
	{
		"label": "I feel sad or low",
		"acknowledge": "I hear you. Thank you for choosing words for a difficult feeling.",
		"reflection": "It sounds like this moment may feel heavy. You do not have to carry it alone.",
		"strength": "You are more than this moment. Reaching for a quiet check-in can show self-awareness.",
		"question": "Let's explore this together. What support would feel kind right now: company, rest, music, or a trusted person?",
		"activity": "Would you like to visit Heart Melody gently, or choose Need help to find real-world support?",
	},
	{
		"label": "I feel excited or proud",
		"acknowledge": "I hear you. That sounds like a moment worth noticing.",
		"reflection": "It sounds like something you chose or created has brought energy and pride.",
		"strength": "You are more than one achievement. Recognising progress can build confidence and gratitude.",
		"question": "Let's explore this together. What choice or effort helped create this moment?",
		"activity": "Would you like to revisit your current ARTÉA space and make a small celebration mark, sound, or reflection?",
	},
	{
		"label": "I am not sure what I feel",
		"acknowledge": "I hear you. Not knowing is a real answer.",
		"reflection": "It sounds like the feeling may not have clear words yet, and you do not have to force a label.",
		"strength": "You are more than this uncertain moment. Making room for it can show patience and curiosity.",
		"question": "Let's explore this together. What do you notice first: energy, heaviness, stillness, or something else?",
		"activity": "Would you like to visit Heart Melody and choose a sound before choosing a feeling word?",
	},
]

const STRENGTH_DISCOVERIES := [
	{
		"label": "I kept trying",
		"strength": "Perseverance",
		"reflection": "You continued even when the result was not immediate.",
		"question": "What helped you return for one more step?",
	},
	{
		"label": "I asked for help",
		"strength": "Connection",
		"reflection": "Asking for support can be a wise and courageous choice.",
		"question": "Who or what helped the task feel more possible?",
	},
	{
		"label": "I made or imagined something",
		"strength": "Creativity",
		"reflection": "You turned an idea into something you could explore.",
		"question": "Which part feels most like your own voice?",
	},
	{
		"label": "I noticed what was happening inside",
		"strength": "Self-awareness",
		"reflection": "Pausing to notice can help you choose your next step with care.",
		"question": "What did noticing help you understand or choose?",
	},
]

const ACTIVITY_GUIDES := [
	{
		"label": "Work with a busy thought",
		"activity": "Mind Spark",
		"guide": "Notice one thought, test a kinder or more useful response, and keep only what helps.",
	},
	{
		"label": "Explore a feeling through sound",
		"activity": "Heart Melody",
		"guide": "Use rhythm, pitch, or quiet listening. You can explore without explaining the feeling.",
	},
	{
		"label": "Express something creatively",
		"activity": "Creator's Light",
		"guide": "Make one mark, shape, or colour choice that belongs to you. There is no perfect result.",
	},
	{
		"label": "Look back at my growth",
		"activity": "Crown of Life",
		"guide": "Review choices and discoveries already recorded by your journey, without adding a new reward.",
	},
]

const STAGE_PROGRESS := {
	0: {
		"evidence": "You arrived and made space for a first choice.",
		"strength": "Curiosity",
		"next": "Explore at your own pace and choose one small beginning.",
	},
	1: {
		"evidence": "You reached Mind Spark and practised meeting a thought with choice.",
		"strength": "Perspective",
		"next": "Notice which response helps you take the next grounded step.",
	},
	2: {
		"evidence": "You continued into Heart Melody and explored experience through sound.",
		"strength": "Emotional awareness",
		"next": "Let a rhythm or quiet moment show you what you want to carry forward.",
	},
	3: {
		"evidence": "You reached Creator's Light and gave an idea a visible form.",
		"strength": "Creative courage",
		"next": "Choose one part of your creation that feels meaningful to you.",
	},
	4: {
		"evidence": "You brought discoveries from across the journey toward the Crown of Life.",
		"strength": "Integration",
		"next": "Pause to recognise how your choices, not perfection, shaped the journey.",
	},
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
	companion_pose_requested.emit("welcome")
	var reflection: Dictionary = CURATED_REFLECTIONS.get(_stage, CURATED_REFLECTIONS[0])
	chat_history.text = "Wonderful Counsellor Milo · %s\n\n%s\n\nChoose one, or skip. Nothing you choose here changes your progress." % [
		reflection["title"],
		MODE_INTROS[_mode],
	]
	_clear_choices()

	var prompt := Label.new()
	prompt.text = "How can Milo walk alongside you?"
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", Color(0.86, 0.91, 1.0))
	_choices.add_child(prompt)

	for path_spec in [
		["Check in with a feeling", _show_emotion_check_ins],
		["Reflect with Milo", _show_stage_reflections],
		["Discover a strength", _show_strength_discoveries],
		["Celebrate my progress", _show_progress_celebration],
		["Choose an ARTÉA activity", _show_activity_guides],
	]:
		var path_button := _quiet_button(path_spec[0], path_spec[1])
		_choices.add_child(path_button)
		if user_input == null:
			user_input = path_button

	var quiet_note := Label.new()
	quiet_note.text = "Milo responds only to choices you make and progress the game already knows. He does not diagnose, analyse artwork, or replace a trusted person."
	quiet_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiet_note.add_theme_font_size_override("font_size", 14)
	quiet_note.add_theme_color_override("font_color", Color(0.70, 0.78, 0.92))
	_choices.add_child(quiet_note)

	_choices.add_child(_choice_button(SKIP_CHOICE))
	_choices.add_child(_quiet_button("Need help", _show_support))
	_choices.add_child(_quiet_button("Close", close_chat))


func _show_stage_reflections() -> void:
	companion_pose_requested.emit("tablet")
	var reflection: Dictionary = CURATED_REFLECTIONS.get(_stage, CURATED_REFLECTIONS[0])
	chat_history.text = "Wonderful Counsellor Milo · Reflection Partner\n\n%s\n\nChoose a reflection, or return without answering." % str(reflection["title"])
	_clear_choices()

	for choice in reflection["choices"]:
		var choice_button := _choice_button(choice)
		_choices.add_child(choice_button)
		if user_input == null:
			user_input = choice_button
	var skip_button := _choice_button(SKIP_CHOICE)
	_choices.add_child(skip_button)
	if user_input == null:
		user_input = skip_button

	_add_companion_navigation()


func _show_emotion_check_ins() -> void:
	companion_pose_requested.emit("heart")
	chat_history.text = "Wonderful Counsellor Milo · Emotional Companion\n\nChoose words that feel closest, or return without choosing. Milo will respond to your choice—not guess what you feel."
	_clear_choices()
	for check_in in EMOTION_CHECK_INS:
		var button := _quiet_button(str(check_in.label), _respond_to_emotion.bind(check_in))
		_choices.add_child(button)
		if user_input == null:
			user_input = button
	_add_companion_navigation()


func _respond_to_emotion(check_in: Dictionary) -> void:
	companion_pose_requested.emit("encourage")
	_show_companion_response(
		"Emotional Companion",
		"You chose: %s\n\nVALIDATE\n%s\n\nREFLECT\n%s\n\nIDENTITY & STRENGTH\n%s\n\nGENTLE GUIDANCE\n%s\n\nCONNECT TO ARTÉA\n%s" % [
			str(check_in.label), str(check_in.acknowledge),
			str(check_in.reflection), str(check_in.strength),
			str(check_in.question), str(check_in.activity),
		]
	)


func _show_strength_discoveries() -> void:
	companion_pose_requested.emit("encourage")
	chat_history.text = "Wonderful Counsellor Milo · Strength Discoverer\n\nChoose something you actually did. Milo will name a possible strength without turning it into a score or reward."
	_clear_choices()
	for discovery in STRENGTH_DISCOVERIES:
		var button := _quiet_button(str(discovery.label), _respond_to_strength.bind(discovery))
		_choices.add_child(button)
		if user_input == null:
			user_input = button
	_add_companion_navigation()


func _respond_to_strength(discovery: Dictionary) -> void:
	_show_companion_response(
		"Strength Discoverer",
		"You chose: %s\n\nPossible strength: %s\n\n%s\n\nReflection: %s" % [
			str(discovery.label), str(discovery.strength),
			str(discovery.reflection), str(discovery.question),
		]
	)


func _show_progress_celebration() -> void:
	companion_pose_requested.emit("encourage")
	var progress: Dictionary = STAGE_PROGRESS.get(_stage, STAGE_PROGRESS[0])
	_show_companion_response(
		"Encourager",
		"What the journey records: %s\n\nStrength reflected in that step: %s\n\nA possible next step: %s\n\nYour progress comes from the choices you made; this reflection does not add or remove rewards." % [
			str(progress.evidence), str(progress.strength), str(progress.next),
		]
	)


func _show_activity_guides() -> void:
	companion_pose_requested.emit("map")
	chat_history.text = "Wonderful Counsellor Milo · Journey Guide\n\nChoose what would help now. Milo will suggest an ARTÉA activity without changing your progress."
	_clear_choices()
	for guide in ACTIVITY_GUIDES:
		var button := _quiet_button(str(guide.label), _respond_with_activity.bind(guide))
		_choices.add_child(button)
		if user_input == null:
			user_input = button
	_add_companion_navigation()


func _respond_with_activity(guide: Dictionary) -> void:
	companion_pose_requested.emit("guide")
	_show_companion_response(
		"Journey Guide",
		"Suggested activity: %s\n\n%s\n\nYou can try it, choose another path, or continue your current adventure." % [
			str(guide.activity), str(guide.guide),
		]
	)


func _show_companion_response(title: String, message: String) -> void:
	chat_history.text = "Wonderful Counsellor Milo · %s\n\n%s" % [title, message]
	_clear_choices()
	_add_companion_navigation()


func _add_companion_navigation() -> void:
	var back_button := _quiet_button("Back to companion paths", _show_choices)
	_choices.add_child(back_button)
	user_input = back_button
	_choices.add_child(_quiet_button("Need help", _show_support))
	_choices.add_child(_quiet_button("Close", close_chat))


func _choose_reflection(choice: Dictionary) -> void:
	var reply := str(choice.get(_mode, choice.get("universal", "")))
	chat_history.text = "Wonderful Counsellor Milo · %s\n\n%s\n\nYou can continue your adventure whenever you are ready." % [
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
	user_input = null
	if _choices == null:
		_choices = VBoxContainer.new()
		_choices.name = "CuratedChoices"
		_choices.add_theme_constant_override("separation", 8)
		content.add_child(_choices)
		return

	for child in _choices.get_children():
		_choices.remove_child(child)
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
