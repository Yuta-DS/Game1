# Milo's child-safe, offline reflection panel.
#
# Typed reflection has no length limit and always passes through the authored
# safety matcher first. Supported desktop builds may then answer with
# the bundled local Gemma model through NobodyWho. No message is saved, logged,
# or uploaded; Web and unsupported builds retain the authored local response.
extends Control

@onready var chat_history: RichTextLabel = $Panel/VBoxContainer/ChatHistory
@onready var content: VBoxContainer = $Panel/VBoxContainer
@onready var choices_scroll: ScrollContainer = $Panel/VBoxContainer/ChoicesScroll

signal chat_closed
signal companion_pose_requested(pose_name: String)
signal companion_speech_requested(spoken_text: String)
signal activity_travel_requested(activity_id: String)
signal companion_activity_state_requested(state_name: String)

# Compatibility focus target for milo_animations.gd. It may be a curated
# button or the local, bounded reflection field.
var user_input: Control

const ReflectionEngine := preload("res://scripts/MiloReflectionEngine.gd")
const SupportCard := preload("res://scripts/support_card.gd")
const CastleGuideArrow := preload("res://scripts/castle_guide_arrow.gd")
const BoldFont := preload("res://assets/Fonts/OpenDyslexic-Bold.otf")
const CASTLE_ARROW_NAME := "CastleGuideArrow"
const REPLY_TITLE_COLOR := "#9a6a1c"
const REPLY_SECTION_COLOR := "#2b4f8f"
const REPLY_HIGHLIGHT_COLOR := "#b5482f"
# Emoji in replies are drawn as icons: the Web export has no emoji font, so
# the characters themselves render blank there.
const REPLY_ICONS := {
	"✨": "res://assets/UI/icons/sparkle.svg",
	"⭐": "res://assets/UI/icons/star.svg",
	"🎉": "res://assets/UI/icons/sparkle.svg",
}
# The hub castle's door trigger (teleport_Art_Gallery.gd) in New_Hub_World.
const CASTLE_DOOR_NODE := "Art_Gallery"
const MILO_DISCLAIMER := "Milo is an AI friend, not a real counsellor. If something is really bothering you, talk to a grown-up you trust or tap Need help."
const LOCAL_LLM_MODEL_PATH := "res://nobodywhomodels/gemma-2-2b-it-Q4_K_M.gguf"
const LOCAL_LLM_PROMPT_PATH := "res://addons/nobodywho/milo_prompt.txt"
const LOCAL_LLM_CONTEXT_LENGTH := 2048
const LOCAL_LLM_TIMEOUT_SECONDS := 120.0
const LOCAL_LLM_MAX_RESPONSE_CHARS := 720

# Web ships without NobodyWho (no Web library for the native extension), so
# Web builds talk to Milo's cloud proxy instead - a Cloudflare Worker that
# holds the Gemini API key server-side and never exposes it to the browser.
# The authored safety matcher above still runs first on every platform; this
# is only reached for non-urgent messages.
const CLOUD_LLM_ENDPOINT := "https://milo-dialogue-proxy.corey-thomas99.workers.dev"
const CLOUD_LLM_TIMEOUT_SECONDS := 20.0
const CLOUD_LLM_MAX_RESPONSE_CHARS := 720

var _reflection_engine := ReflectionEngine.new()
var _message_input: LineEdit
var campaign_router: Node
var _support_card: Node
var _local_llm_model: Node
var _local_llm_chat: Node
var _local_llm_response := ""
var _local_llm_generating := false
var _local_llm_request_id := 0
var _cloud_llm_request: HTTPRequest
var _cloud_llm_generating := false
var _cloud_llm_request_id := 0
var _pending_authored_response: Dictionary = {}

const ACTIVITY_DESTINATIONS := {
	"mind": "Mind Spark Kingdom",
	"heart": "Heart Melody Kingdom",
	"creator": "Creator's Light Kingdom",
}

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
				"faith": "You get to decide what matters in your creation. I will not judge it.",
				"universal": "You get to decide what matters in your creation. I will not judge it.",
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
		"activity_id": "mind",
	},
	{
		"label": "I feel worried or unsure",
		"acknowledge": "I hear you. Worry or uncertainty can make the next step feel larger.",
		"reflection": "It sounds like not knowing what comes next may be making this moment feel harder.",
		"strength": "You are more than this moment. Naming uncertainty can show honesty and courage.",
		"question": "Let's explore this together. What is one small part you can choose, and one part you can leave for later?",
		"activity": "Would you like to visit Mind Spark, notice one thought, and choose one small hopeful response?",
		"activity_id": "mind",
	},
	{
		"label": "I feel frustrated or stuck",
		"acknowledge": "I hear you. Being stuck can be tiring.",
		"reflection": "It sounds like you have been working at something that is not moving the way you hoped.",
		"strength": "You are more than this moment. Coming back to a challenge can show persistence and flexibility.",
		"question": "Let's explore this together. Would a smaller step, a new tool, or asking someone for help make this lighter?",
		"activity": "Would you like to visit Creator's Light and make one mark without needing it to be perfect?",
		"activity_id": "creator",
	},
	{
		"label": "I feel sad or low",
		"acknowledge": "I hear you. Thank you for choosing words for a difficult feeling.",
		"reflection": "It sounds like this moment may feel heavy. You do not have to carry it alone.",
		"strength": "You are more than this moment. Reaching for a quiet check-in can show self-awareness.",
		"question": "Let's explore this together. What support would feel kind right now: company, rest, music, or a trusted person?",
		"activity": "Would you like to visit Heart Melody gently, or choose Need help to find real-world support?",
		"activity_id": "heart",
	},
	{
		"label": "I feel excited or proud",
		"acknowledge": "I hear you. That sounds like a moment worth noticing.",
		"reflection": "It sounds like something you chose or created has brought energy and pride.",
		"strength": "You are more than one achievement. Recognising progress can build confidence and gratitude.",
		"question": "Let's explore this together. What choice or effort helped create this moment?",
		"activity": "Would you like to visit Creator's Light and make a small celebration mark for the effort you want to remember?",
		"activity_id": "creator",
	},
	{
		"label": "I am not sure what I feel",
		"acknowledge": "I hear you. Not knowing is a real answer.",
		"reflection": "It sounds like the feeling may not have clear words yet, and you do not have to force a label.",
		"strength": "You are more than this uncertain moment. Making room for it can show patience and curiosity.",
		"question": "Let's explore this together. What do you notice first: energy, heaviness, stillness, or something else?",
		"activity": "Would you like to visit Heart Melody and choose a sound before choosing a feeling word?",
		"activity_id": "heart",
	},
]

# A concise, playful strength finder. Each answer points to one of four
# strengths; Milo names the one the player chose most often. It reflects only
# the player's own button presses and is never saved, scored, or rewarded.
const STRENGTHS := {
	"creativity": {
		"name": "Creativity",
		"reveal": "You love turning ideas into something new. You see possibilities other people might miss.",
		"activity_id": "creator",
	},
	"kindness": {
		"name": "Kindness",
		"reveal": "You notice how others feel and you help them feel less alone. People are lucky to have you nearby.",
		"activity_id": "heart",
	},
	"curiosity": {
		"name": "Curiosity",
		"reveal": "You love asking questions and figuring out how things work. Your wondering helps you learn and grow.",
		"activity_id": "mind",
	},
	"perseverance": {
		"name": "Perseverance",
		"reveal": "You keep going even when things are hard. Every time you try again, you grow a little stronger.",
		"activity_id": "mind",
	},
}

const STRENGTH_QUESTIONS := [
	{
		"question": "What do you enjoy doing most?",
		"answers": [
			["Making or drawing something", "creativity"],
			["Spending time with friends or family", "kindness"],
			["Learning how things work", "curiosity"],
			["Practising something until I get better", "perseverance"],
		],
	},
	{
		"question": "When a friend is having a hard day, you usually…",
		"answers": [
			["Make something to cheer them up", "creativity"],
			["Listen and stay with them", "kindness"],
			["Ask questions to understand what happened", "curiosity"],
			["Help them keep going, one step at a time", "perseverance"],
		],
	},
	{
		"question": "When something feels tricky, you…",
		"answers": [
			["Try a totally new way", "creativity"],
			["Ask someone to work on it with me", "kindness"],
			["Look for clues and figure it out", "curiosity"],
			["Keep trying until it works", "perseverance"],
		],
	},
	{
		"question": "Which adventure sounds best?",
		"answers": [
			["Painting a giant castle wall", "creativity"],
			["Helping a village get ready for a festival", "kindness"],
			["Exploring a hidden cave", "curiosity"],
			["Climbing the tallest mountain", "perseverance"],
		],
	},
	{
		"question": "What would you most like people to say about you?",
		"answers": [
			["\"You have amazing ideas!\"", "creativity"],
			["\"You always make people feel welcome.\"", "kindness"],
			["\"You ask the best questions!\"", "curiosity"],
			["\"You never give up.\"", "perseverance"],
		],
	},
]

const ACTIVITY_GUIDES := [
	{
		"label": "Work with a busy thought",
		"activity": "Mind Spark",
		"activity_id": "mind",
		"guide": "Notice one thought, test a kinder or more useful response, and keep only what helps.",
	},
	{
		"label": "Explore a feeling through sound",
		"activity": "Heart Melody",
		"activity_id": "heart",
		"guide": "Use rhythm, pitch, or quiet listening. You can explore without explaining the feeling.",
	},
	{
		"label": "Express something creatively",
		"activity": "Creator's Light",
		"activity_id": "creator",
		"guide": "Make one mark, shape, or colour choice that belongs to you. There is no perfect result.",
	},
]

# Each completed world is evidenced by its treasure in JourneyState, read
# through JourneyCampaign. Milo celebrates only what the journey recorded.
# Short world names for Milo's spoken suggestions ("Try the Mind Spark world").
const WORLD_SHORT_NAMES := {
	"mind": "Mind Spark",
	"heart": "Heart Melody",
	"creator": "Creator's Light",
}

const WORLD_STRENGTHS := {
	"mind": "Perspective",
	"heart": "Emotional awareness",
	"creator": "Creative courage",
}

var _stage := 0
var _mode := "faith"
var _choices: VBoxContainer
var _strength_question_index := 0
var _reply_plain_text := ""
var _strength_tally: Dictionary = {}


func _ready() -> void:
	# Third-person cameras stop orbiting and zooming while Milo's chat is open.
	add_to_group("camera_input_blockers")
	_resolve_safe_context()
	_initialize_local_llm()
	_initialize_cloud_llm()
	_show_choices()


func _resolve_safe_context() -> void:
	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return

	_stage = clampi(int(js.get("stage")), 0, CURATED_REFLECTIONS.size() - 1)
	if str(js.get("audience_mode")) == "universal":
		_mode = "universal"


func _show_choices() -> void:
	_request_companion_activity("GREETING", "welcome")
	var reflection: Dictionary = CURATED_REFLECTIONS.get(_stage, CURATED_REFLECTIONS[0])
	_speak("Wonderful Counsellor Milo · %s\n\nHi, I'm Milo! Choose what you'd like to do, or tell me what's on your mind. Nothing you choose here changes your progress." % [
		reflection["title"],
	])
	_clear_choices()

	var prompt := Label.new()
	prompt.text = "How can Milo walk alongside you?"
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	_choices.add_child(prompt)

	for path_spec in [
		["Discover a strength", _show_strength_discoveries],
		["Celebrate my progress", _show_progress_celebration],
		["Choose an activity", _show_activity_guides],
	]:
		var path_button := _quiet_button(path_spec[0], path_spec[1])
		_choices.add_child(path_button)
		if user_input == null:
			user_input = path_button

	_add_message_input()

	var quiet_note := Label.new()
	# One line by design: the full privacy detail lives in the tooltip.
	quiet_note.text = MILO_DISCLAIMER
	quiet_note.tooltip_text = _local_llm_privacy_note()
	quiet_note.mouse_filter = Control.MOUSE_FILTER_PASS
	quiet_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	quiet_note.add_theme_font_size_override("font_size", 14)
	quiet_note.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	_choices.add_child(quiet_note)

	_choices.add_child(_quiet_button("Need help", _show_support))
	_choices.add_child(_quiet_button("Close", close_chat))
	_focus_first_choice()


func _show_stage_reflections() -> void:
	_request_companion_activity("REFLECTING", "tablet")
	var reflection: Dictionary = CURATED_REFLECTIONS.get(_stage, CURATED_REFLECTIONS[0])
	_speak("Wonderful Counsellor Milo · Reflection Partner\n\n%s\n\nChoose a reflection, or return without answering." % str(reflection["title"]))
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
	_request_companion_activity("LISTENING", "heart")
	_speak("Wonderful Counsellor Milo · Emotional Companion\n\nChoose words that feel closest, or return without choosing. I will respond to your choice—not guess what you feel.")
	_clear_choices()
	for check_in in EMOTION_CHECK_INS:
		var button := _quiet_button(str(check_in.label), _respond_to_emotion.bind(check_in))
		_choices.add_child(button)
		if user_input == null:
			user_input = button
	_add_companion_navigation()


func _respond_to_emotion(check_in: Dictionary) -> void:
	_request_companion_activity("ENCOURAGING", "encourage")
	_show_companion_response(
		"Emotional Companion",
		"You chose: %s\n\nVALIDATE\n%s\n\nREFLECT\n%s\n\nIDENTITY & STRENGTH\n%s\n\nGENTLE GUIDANCE\n%s\n\nCONNECT TO ARTÉA\n%s" % [
			str(check_in.label), str(check_in.acknowledge),
			str(check_in.reflection), str(check_in.strength),
			str(check_in.question), str(check_in.activity),
		],
		str(check_in.get("activity_id", ""))
	)


func _add_message_input() -> void:
	var prompt := Label.new()
	prompt.text = "Or tell Milo what is on your mind:"
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	_choices.add_child(prompt)

	var row := HBoxContainer.new()
	row.name = "LocalMessageRow"
	_choices.add_child(row)
	_message_input = LineEdit.new()
	_message_input.name = "MiloMessageInput"
	_message_input.placeholder_text = "For example: Why am I always stressed?"
	# 0 = no limit. The safety matcher scans the whole message.
	_message_input.max_length = 0
	_message_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_input.tooltip_text = "This message is processed locally and is not saved."
	var field := StyleBoxFlat.new()
	field.bg_color = Color(1.0, 1.0, 1.0)
	field.border_color = Color(0.86, 0.74, 0.53)
	field.set_border_width_all(2)
	field.set_corner_radius_all(9)
	field.set_content_margin_all(8)
	_message_input.add_theme_stylebox_override("normal", field)
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = Color(0.48, 0.73, 1.0)
	_message_input.add_theme_stylebox_override("focus", field_focus)
	_message_input.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
	_message_input.add_theme_color_override("font_placeholder_color", Color(0.1, 0.1, 0.15, 0.5))
	_message_input.add_theme_color_override("caret_color", Color(0.1, 0.1, 0.15))
	row.add_child(_message_input)
	var send_button := _quiet_button("Ask Milo", _submit_message.bind(_message_input))
	send_button.name = "MiloMessageSend"
	row.add_child(send_button)
	_message_input.text_submitted.connect(func(_submitted_text: String) -> void:
		_submit_message(_message_input)
	)
	user_input = _message_input


func _submit_message(input: LineEdit) -> void:
	if input == null:
		return
	var message := input.text.strip_edges()
	input.clear()
	if message.is_empty():
		input.placeholder_text = "Write a few words first—or choose a path above."
		input.grab_focus()
		return
	var response: Dictionary = _reflection_engine.reflect(message)
	if bool(response.get("urgent", false)):
		_request_companion_activity("SUPPORTING", "heart")
		_show_companion_response(
			"Get real-world help now",
			"%s\n\n%s\n\n%s\n\n%s\n\n%s" % [
				str(response.validate), str(response.reflect), str(response.strength),
				str(response.guidance), str(response.activity),
			]
		)
		_show_support()
		return
	if _local_llm_chat != null and is_instance_valid(_local_llm_chat):
		_begin_local_llm_response(message, response)
		return
	if _cloud_llm_request != null and is_instance_valid(_cloud_llm_request):
		_begin_cloud_llm_response(message, response)
		return
	_show_authored_message_response(response)


func _show_authored_message_response(response: Dictionary) -> void:
	_request_companion_activity("REFLECTING", "tablet")
	_show_companion_response(
		"Reflection Partner",
		"VALIDATE\n%s\n\nREFLECT\n%s\n\nIDENTITY & STRENGTH\n%s\n\nGENTLE GUIDANCE\n%s\n\nCONNECT TO ARTÉA\n%s" % [
			str(response.validate), str(response.reflect), str(response.strength),
			str(response.guidance), str(response.activity),
		],
		str(response.get("activity_id", ""))
	)


func _initialize_local_llm() -> void:
	# NobodyWho is a native GDExtension in this repository. It has no Web
	# library, so Web must keep using the authored response path above.
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	if not ClassDB.class_exists("NobodyWhoModel") \
			or not ClassDB.class_exists("NobodyWhoChat"):
		return
	if not FileAccess.file_exists(LOCAL_LLM_MODEL_PATH) \
			or not FileAccess.file_exists(LOCAL_LLM_PROMPT_PATH):
		return
	var model_instance: Object = ClassDB.instantiate("NobodyWhoModel")
	var chat_instance: Object = ClassDB.instantiate("NobodyWhoChat")
	if not model_instance is Node or not chat_instance is Node:
		return
	_local_llm_model = model_instance as Node
	_local_llm_model.name = "MiloLocalGemmaModel"
	add_child(_local_llm_model)
	_local_llm_model.set("model_path", LOCAL_LLM_MODEL_PATH)
	_local_llm_model.set("use_gpu_if_available", true)
	var local_chat := chat_instance as Node
	local_chat.name = "MiloLocalGemmaChat"
	add_child(local_chat)
	local_chat.set("model_node", _local_llm_model)
	local_chat.set("system_prompt", FileAccess.get_file_as_string(
		LOCAL_LLM_PROMPT_PATH).strip_edges())
	local_chat.set("context_length", LOCAL_LLM_CONTEXT_LENGTH)
	_attach_local_llm_chat(local_chat)
	local_chat.call("start_worker")


func _attach_local_llm_chat(local_chat: Node) -> void:
	_local_llm_chat = local_chat
	var updated := Callable(self, "_on_local_llm_response_updated")
	var finished := Callable(self, "_on_local_llm_response_finished")
	if _local_llm_chat.has_signal("response_updated") \
			and not _local_llm_chat.is_connected("response_updated", updated):
		_local_llm_chat.connect("response_updated", updated)
	if _local_llm_chat.has_signal("response_finished") \
			and not _local_llm_chat.is_connected("response_finished", finished):
		_local_llm_chat.connect("response_finished", finished)


func _begin_local_llm_response(message: String,
		authored_response: Dictionary) -> void:
	if _local_llm_generating:
		return
	_local_llm_generating = true
	_local_llm_response = ""
	_pending_authored_response = authored_response.duplicate(true)
	_local_llm_request_id += 1
	var request_id := _local_llm_request_id
	_request_companion_activity("LISTENING", "heart")
	_show_reply("Wonderful Counsellor Milo · Listening\n\nI am thinking with the local model…")
	_clear_choices()
	var waiting := Label.new()
	waiting.name = "MiloLocalModelStatus"
	waiting.text = "Thinking locally… Your message stays on this device."
	waiting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	waiting.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	_choices.add_child(waiting)
	var local_close_button := _quiet_button("Close", close_chat)
	_choices.add_child(local_close_button)
	user_input = local_close_button
	_focus_first_choice()
	_local_llm_chat.call("say", message)
	get_tree().create_timer(LOCAL_LLM_TIMEOUT_SECONDS).timeout.connect(
		_on_local_llm_timeout.bind(request_id))


func _on_local_llm_response_updated(new_token: String) -> void:
	if not _local_llm_generating:
		return
	_local_llm_response += new_token
	var preview := _clean_local_llm_response(_local_llm_response)
	if not preview.is_empty():
		_show_reply("Wonderful Counsellor Milo · Thinking locally\n\n%s" % preview)


func _on_local_llm_response_finished(response: String) -> void:
	if not _local_llm_generating:
		return
	_local_llm_generating = false
	var clean_response := _clean_local_llm_response(response)
	if clean_response.is_empty():
		_show_authored_message_response(_pending_authored_response)
	else:
		_request_companion_activity("REFLECTING", "tablet")
		_show_companion_response("Local Reflection", clean_response, "", false)
	_pending_authored_response.clear()


func _on_local_llm_timeout(request_id: int) -> void:
	if not _local_llm_generating or request_id != _local_llm_request_id:
		return
	_local_llm_generating = false
	if _local_llm_chat != null and _local_llm_chat.has_method("stop_generation"):
		_local_llm_chat.call("stop_generation")
	_show_authored_message_response(_pending_authored_response)
	_pending_authored_response.clear()


func _clean_local_llm_response(source: String) -> String:
	var clean := source.strip_edges()
	for marker in ["<start_of_turn>", "<end_of_turn>", "<bos>", "<eos>",
			"assistant", "model"]:
		clean = clean.replace(marker, "")
	clean = clean.strip_edges()
	if clean.length() > LOCAL_LLM_MAX_RESPONSE_CHARS:
		clean = clean.substr(0, LOCAL_LLM_MAX_RESPONSE_CHARS).strip_edges()
		var last_space := clean.rfind(" ")
		if last_space > LOCAL_LLM_MAX_RESPONSE_CHARS / 2:
			clean = clean.left(last_space)
		clean += "…"
	return clean


func _local_llm_privacy_note() -> String:
	if _local_llm_chat != null and is_instance_valid(_local_llm_chat):
		return "Typed messages stay on this device and are not saved. Milo uses the included local Gemma model after an authored safety check."
	if is_cloud_llm_active():
		return "Typed messages pass an authored safety check, then are sent to Milo's AI service to generate a reply, and are not stored afterwards."
	return "Typed messages stay on this device and are not saved. This build uses Milo's authored local reflections."


func is_local_llm_active() -> bool:
	return _local_llm_chat != null and is_instance_valid(_local_llm_chat)


func _initialize_cloud_llm() -> void:
	# Only Web reaches here: native builds use the local model above, and this
	# never runs at all if that path is already active.
	if not OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	if _local_llm_chat != null and is_instance_valid(_local_llm_chat):
		return
	_cloud_llm_request = HTTPRequest.new()
	_cloud_llm_request.name = "MiloCloudLLMRequest"
	_cloud_llm_request.timeout = CLOUD_LLM_TIMEOUT_SECONDS
	add_child(_cloud_llm_request)
	_cloud_llm_request.request_completed.connect(_on_cloud_llm_request_completed)


func _begin_cloud_llm_response(message: String, authored_response: Dictionary) -> void:
	if _cloud_llm_generating:
		return
	_cloud_llm_generating = true
	_pending_authored_response = authored_response.duplicate(true)
	_cloud_llm_request_id += 1
	var request_id := _cloud_llm_request_id
	_request_companion_activity("LISTENING", "heart")
	_show_reply("Wonderful Counsellor Milo · Listening\n\nI am thinking…")
	_clear_choices()
	var waiting := Label.new()
	waiting.name = "MiloCloudModelStatus"
	waiting.text = "Thinking… Your message is sent to Milo's AI service to generate a reply."
	waiting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	waiting.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	_choices.add_child(waiting)
	var cloud_close_button := _quiet_button("Close", close_chat)
	_choices.add_child(cloud_close_button)
	user_input = cloud_close_button
	_focus_first_choice()

	var body := JSON.stringify({"message": message})
	var headers := ["Content-Type: application/json"]
	var error := _cloud_llm_request.request(CLOUD_LLM_ENDPOINT, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		_finish_cloud_llm(request_id, "")
		return
	get_tree().create_timer(CLOUD_LLM_TIMEOUT_SECONDS + 5.0).timeout.connect(
		_on_cloud_llm_timeout.bind(request_id))


func _on_cloud_llm_request_completed(_result: int, response_code: int,
		_headers: PackedStringArray, body: PackedByteArray) -> void:
	var request_id := _cloud_llm_request_id
	if not _cloud_llm_generating:
		return
	var reply := ""
	if response_code == 200:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary and parsed.has("reply"):
			reply = str(parsed["reply"])
	_finish_cloud_llm(request_id, reply)


func _on_cloud_llm_timeout(request_id: int) -> void:
	if not _cloud_llm_generating or request_id != _cloud_llm_request_id:
		return
	_finish_cloud_llm(request_id, "")


func _finish_cloud_llm(request_id: int, reply: String) -> void:
	if not _cloud_llm_generating or request_id != _cloud_llm_request_id:
		return
	_cloud_llm_generating = false
	var clean_reply := reply.strip_edges()
	if clean_reply.length() > CLOUD_LLM_MAX_RESPONSE_CHARS:
		clean_reply = clean_reply.substr(0, CLOUD_LLM_MAX_RESPONSE_CHARS).strip_edges()
		var last_space := clean_reply.rfind(" ")
		if last_space > CLOUD_LLM_MAX_RESPONSE_CHARS / 2:
			clean_reply = clean_reply.left(last_space)
		clean_reply += "…"
	if clean_reply.is_empty():
		_show_authored_message_response(_pending_authored_response)
	else:
		_request_companion_activity("REFLECTING", "tablet")
		_show_companion_response("Milo", clean_reply, "", false)
	_pending_authored_response.clear()


func is_cloud_llm_active() -> bool:
	return _cloud_llm_request != null and is_instance_valid(_cloud_llm_request)


func _show_strength_discoveries() -> void:
	_strength_question_index = 0
	_strength_tally.clear()
	_show_strength_question()


func _show_strength_question() -> void:
	_request_companion_activity("REFLECTING", "encourage")
	var step: Dictionary = STRENGTH_QUESTIONS[_strength_question_index]
	_speak("Wonderful Counsellor Milo · Strength Finder

Question %d of %d

%s" % [
		_strength_question_index + 1, STRENGTH_QUESTIONS.size(), str(step.question),
	])
	_clear_choices()
	for answer in step.answers:
		var button := _quiet_button(str(answer[0]), _answer_strength_question.bind(str(answer[1])))
		_choices.add_child(button)
		if user_input == null:
			user_input = button
	var back_button := _quiet_button("Back to companion paths", _show_choices)
	_choices.add_child(back_button)
	_choices.add_child(_quiet_button("Close", close_chat))
	_focus_first_choice()


func _answer_strength_question(strength_id: String) -> void:
	_strength_tally[strength_id] = int(_strength_tally.get(strength_id, 0)) + 1
	_strength_question_index += 1
	if _strength_question_index < STRENGTH_QUESTIONS.size():
		_show_strength_question()
	else:
		_reveal_strength()


func _top_strength_id() -> String:
	# Ties go to the strength listed first in STRENGTHS, so the result is stable.
	var best_id := ""
	var best_count := 0
	for strength_id in STRENGTHS:
		var count := int(_strength_tally.get(strength_id, 0))
		if count > best_count:
			best_id = strength_id
			best_count = count
	return best_id


func _reveal_strength() -> void:
	_request_companion_activity("ENCOURAGING", "encourage")
	var strength: Dictionary = STRENGTHS.get(_top_strength_id(), STRENGTHS["curiosity"])
	var world_id := str(strength.get("activity_id", ""))
	var message := "From your answers, one of your strengths is...\n\n✨ %s ✨\n\n%s\n\nTry the %s world! It is a great fit for your %s." % [
		str(strength.name), str(strength.reveal),
		str(WORLD_SHORT_NAMES.get(world_id, "next")), str(strength.name).to_lower(),
	]
	# Only the overworld has the castle the other worlds are reached through.
	if _castle_door() != null:
		message += "\n\nOther worlds also await you! Tap \"Try other worlds\" and I'll show you the way."
	_show_companion_response("Strength Finder", message, world_id)
	_add_other_worlds_button()


func _show_progress_celebration() -> void:
	_request_companion_activity("CELEBRATING", "encourage")
	var campaign := _campaign()
	var completed: Array[String] = []
	var world_ids: Array = WORLD_STRENGTHS.keys()
	if campaign != null and campaign.has_method("is_kingdom_complete"):
		for world_id in world_ids:
			if bool(campaign.call("is_kingdom_complete", world_id)):
				completed.append(world_id)
	var total := world_ids.size()

	var lines: Array[String] = []
	var next_id := ""
	if completed.is_empty():
		lines.append("You haven't completed a world yet, and that's okay! Every journey begins with one small step.")
		next_id = "mind"
	else:
		lines.append("You've completed %d of %d worlds! 🎉" % [completed.size(), total])
		for world_id in completed:
			lines.append("⭐ %s · you showed %s" % [
				str(ACTIVITY_DESTINATIONS[world_id]), str(WORLD_STRENGTHS[world_id]).to_lower(),
			])
	if completed.size() >= total:
		lines.append("You finished every world. That took real effort, and I am so proud of you. You can revisit any of them whenever you like.")
	elif next_id.is_empty() and campaign != null and campaign.has_method("next_kingdom_id"):
		next_id = str(campaign.call("next_kingdom_id"))
	if next_id in WORLD_STRENGTHS:
		lines.append("Next adventure: %s, whenever you are ready." % str(ACTIVITY_DESTINATIONS[next_id]))

	_show_companion_response("Celebrate My Progress", "\n\n".join(lines), next_id)
	if next_id in WORLD_STRENGTHS:
		_add_other_worlds_button()


# Milo has just said new worlds await at the top of the castle: point the way
# to the hub castle's door, which leads into the Art Castle and its worlds.
# Only the hub has that door, so elsewhere this does nothing.
func _show_castle_arrow() -> void:
	var castle_door := _castle_door()
	if castle_door == null:
		return
	var scene := get_tree().current_scene
	if scene.get_node_or_null(CASTLE_ARROW_NAME) != null:
		return
	var arrow := CastleGuideArrow.new()
	arrow.name = CASTLE_ARROW_NAME
	arrow.target_node = castle_door
	arrow.target = castle_door.global_position
	scene.add_child(arrow)


# The hub castle's door, or null anywhere else (the gallery is inside the
# castle already, so "the top of the castle" means nothing there).
func _castle_door() -> Area3D:
	if not is_inside_tree():
		return null
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null(CASTLE_DOOR_NODE) as Area3D


# Offered beside a world suggestion, only where the castle exists. It is placed
# straight after the travel button so the two world choices sit together.
func _add_other_worlds_button() -> void:
	if _castle_door() == null:
		return
	var button := _quiet_button("Try other worlds", _show_other_worlds)
	button.name = "MiloTryOtherWorlds"
	_choices.add_child(button)
	var after := 0
	for child in _choices.get_children():
		if child.name.begins_with("MiloTravel_"):
			after = child.get_index() + 1
			break
	_choices.move_child(button, after)


func _show_other_worlds() -> void:
	_request_companion_activity("GUIDING", "guide")
	_show_castle_arrow()
	_show_companion_response("Journey Guide",
		"New worlds await you at the top of the castle!\n\nFollow the golden arrow up the castle stair, then step through the castle door to choose your next world.")


func _show_activity_guides() -> void:
	_request_companion_activity("GUIDING", "map")
	_speak("Wonderful Counsellor Milo · Journey Guide\n\nChoose what would help now. I will suggest an ARTÉA activity without changing your progress.")
	_clear_choices()
	for guide in ACTIVITY_GUIDES:
		var button := _quiet_button(str(guide.label), _respond_with_activity.bind(guide))
		_choices.add_child(button)
		if user_input == null:
			user_input = button
	_add_companion_navigation()


func _respond_with_activity(guide: Dictionary) -> void:
	_request_companion_activity("GUIDING", "guide")
	_show_companion_response(
		"Journey Guide",
		"Suggested activity: %s\n\n%s\n\nYou can try it, choose another path, or continue your current adventure." % [
			str(guide.activity), str(guide.guide),
		],
		str(guide.get("activity_id", ""))
	)


# spoken = false shows the reply as text only (used for AI replies, which have
# no recording and shouldn't fall back to the platform voice).
func _show_companion_response(title: String, message: String,
		destination_id := "", spoken := true) -> void:
	var text := "Wonderful Counsellor Milo · %s

%s" % [title, message]
	if spoken:
		_speak(text)
	else:
		_show_reply(text)
	_clear_choices()
	_add_companion_navigation(destination_id)


func _add_companion_navigation(destination_id := "") -> void:
	if ACTIVITY_DESTINATIONS.has(destination_id):
		var destination_name := str(ACTIVITY_DESTINATIONS[destination_id])
		var travel_button := _quiet_button(
			"Go with Milo to %s" % destination_name,
			_travel_to_activity.bind(destination_id))
		travel_button.name = "MiloTravel_%s" % destination_id
		_choices.add_child(travel_button)
	_add_message_input()
	var back_button := _quiet_button("Back to companion paths", _show_choices)
	_choices.add_child(back_button)
	user_input = back_button
	_choices.add_child(_quiet_button("Need help", _show_support))
	_choices.add_child(_quiet_button("Close", close_chat))
	_focus_first_choice()


func _travel_to_activity(destination_id: String) -> void:
	var campaign := _campaign()
	if campaign == null:
		_speak("Wonderful Counsellor Milo · Journey Guide\n\nThat path is unavailable right now. You can stay with me or continue your adventure.")
		_clear_choices()
		_add_companion_navigation()
		return
	if not campaign.has_method("enter_kingdom"):
		return
	activity_travel_requested.emit(destination_id)
	chat_closed.emit()
	campaign.call("enter_kingdom", destination_id)


func _campaign() -> Node:
	if is_instance_valid(campaign_router):
		return campaign_router
	return get_node_or_null("/root/JourneyCampaign")


func _request_companion_activity(state_name: String, pose_name: String) -> void:
	companion_activity_state_requested.emit(state_name)
	companion_pose_requested.emit(pose_name)


func _choose_reflection(choice: Dictionary) -> void:
	var reply := str(choice.get(_mode, choice.get("universal", "")))
	_speak("Wonderful Counsellor Milo · %s\n\n%s\n\nYou can continue your adventure whenever you are ready." % [
		str(choice.get("label", "A quiet choice")),
		reply,
	])
	_clear_choices()
	var continue_button := _quiet_button("Continue my adventure", close_chat)
	_choices.add_child(continue_button)
	_add_message_input()
	_choices.add_child(_quiet_button("Need help", _show_support))
	_choices.add_child(_quiet_button("Close", close_chat))
	# Re-asserted after _add_message_input() so the primary action keeps
	# initial keyboard focus rather than the optional message box.
	user_input = continue_button
	_focus_first_choice()


func _focus_first_choice() -> void:
	if user_input != null and is_instance_valid(user_input):
		user_input.grab_focus()


func _clear_choices() -> void:
	user_input = null
	if _choices == null:
		_choices = VBoxContainer.new()
		_choices.name = "CuratedChoices"
		_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_choices.add_theme_constant_override("separation", 8)
		choices_scroll.add_child(_choices)
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
	button.add_theme_font_override("font", BoldFont)
	button.tooltip_text = "This choice is local and does not change your rewards."

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.26, 0.50, 0.96)
	normal.border_color = Color(0.48, 0.73, 1.0, 0.82)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)
	normal.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.36, 0.63, 0.98)
	hover.border_color = Color(0.83, 0.70, 1.0, 0.96)
	button.add_theme_stylebox_override("hover", hover)
	button.pressed.connect(action)
	return button


func _show_support() -> void:
	_request_companion_activity("SUPPORTING", "heart")
	if not is_instance_valid(_support_card):
		_support_card = SupportCard.new()
		_support_card.name = "MiloSupportCard"
		add_child(_support_card)
	_support_card.call("show_card")


func _speak(text: String) -> void:
	_show_reply(text)
	companion_speech_requested.emit(text)


func replay_current_speech() -> void:
	if not _reply_plain_text.is_empty():
		companion_speech_requested.emit(_reply_plain_text)


# Every reply is written as plain text and styled only for display, so speech
# and the transcript never diverge and no markup is ever read aloud.
func _show_reply(text: String) -> void:
	_reply_plain_text = text
	chat_history.text = _format_reply(text)
	chat_history.scroll_to_line(0)


# Layout for Milo's replies: a small gold title line, then compact paragraphs
# spaced by the panel's paragraph_separation instead of blank lines. A revealed
# strength (✨ Name ✨) is shown large, and ALL-CAPS section labels such as
# VALIDATE run inline at the start of the paragraph they introduce.
func _format_reply(text: String) -> String:
	var paragraphs: Array[String] = []
	var pending_label := ""
	var is_first_line := true
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty():
			continue
		# Typed and model text can contain "[", which would otherwise be BBCode.
		var safe := line.replace("[", "[lb]")
		if is_first_line:
			is_first_line = false
			if line.begins_with("Wonderful Counsellor Milo"):
				paragraphs.append("[font_size=15][color=%s][b]%s[/b][/color][/font_size]" % [
					REPLY_TITLE_COLOR, safe])
				continue
		if line.begins_with("✨") and line.ends_with("✨") and line.length() > 2:
			paragraphs.append("[center][font_size=28][color=%s][b]%s[/b][/color][/font_size][/center]" % [
				REPLY_HIGHLIGHT_COLOR, _with_icons(safe, 30)])
		elif _is_section_label(line):
			pending_label = safe
		else:
			if not pending_label.is_empty():
				safe = "[color=%s][b]%s[/b][/color]   %s" % [REPLY_SECTION_COLOR, pending_label, safe]
				pending_label = ""
			paragraphs.append(_with_icons(safe, 20))
	if not pending_label.is_empty():
		paragraphs.append("[color=%s][b]%s[/b][/color]" % [REPLY_SECTION_COLOR, pending_label])
	return "\n".join(paragraphs)


func _with_icons(bbcode: String, size: int) -> String:
	for glyph in REPLY_ICONS:
		bbcode = bbcode.replace(glyph, "[img=%dx%d]%s[/img]" % [size, size, REPLY_ICONS[glyph]])
	return bbcode


func _is_section_label(line: String) -> bool:
	return line.length() <= 28 and line == line.to_upper() and line != line.to_lower() \
		and not line.ends_with(".") and not line.ends_with("!") and not line.ends_with("?")


func close_chat() -> void:
	if _local_llm_generating and _local_llm_chat != null \
			and _local_llm_chat.has_method("stop_generation"):
		_local_llm_chat.call("stop_generation")
	_local_llm_generating = false
	_local_llm_request_id += 1
	if _cloud_llm_generating and _cloud_llm_request != null \
			and is_instance_valid(_cloud_llm_request):
		_cloud_llm_request.cancel_request()
	_cloud_llm_generating = false
	_cloud_llm_request_id += 1
	emit_signal("chat_closed")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_chat()
