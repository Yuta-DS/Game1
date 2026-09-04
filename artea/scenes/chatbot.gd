# Milo's child-safe, offline reflection panel.
#
# Typed reflection is bounded to 280 characters and always passes through the
# authored safety matcher first. Supported desktop builds may then answer with
# the bundled local Gemma model through NobodyWho. No message is saved, logged,
# or uploaded; Web and unsupported builds retain the authored local response.
extends Control

@onready var chat_history: TextEdit = $MiloReplyCard/ChatHistory
@onready var content: VBoxContainer = $InputContent
@onready var milo_role: Label = $MiloReplyCard/MiloRole

signal chat_closed
signal companion_pose_requested(pose_name: String)
signal companion_speech_requested(spoken_text: String)
signal activity_travel_requested(activity_id: String)
signal companion_activity_state_requested(state_name: String)

# Compatibility focus target for milo_animations.gd. It may be a curated
# button or the local, bounded reflection field.
var user_input: Control

const ReflectionEngine := preload("res://scripts/MiloReflectionEngine.gd")
const WisdomEngine := preload("res://scripts/MiloWisdomEngine.gd")
const ConversationContext := preload("res://scripts/MiloConversationContext.gd")
const SupportCard := preload("res://scripts/support_card.gd")
const LOCAL_LLM_MODEL_PATH := "res://nobodywhomodels/gemma-2-2b-it-Q4_K_M.gguf"
const LOCAL_LLM_PROMPT_PATH := "res://addons/nobodywho/milo_prompt.txt"
const LOCAL_LLM_CONTEXT_LENGTH := 2048
const LOCAL_LLM_TIMEOUT_SECONDS := 120.0
const LOCAL_LLM_MAX_RESPONSE_CHARS := 720
var _reflection_engine := ReflectionEngine.new()
var _wisdom_engine := WisdomEngine.new()
var _conversation_context := ConversationContext.new()
var _message_input: LineEdit
var _message_send_button: Button
var campaign_router: Node
var _support_card: Node
var _local_llm_model: Node
var _local_llm_chat: Node
var _local_llm_response := ""
var _local_llm_generating := false
var _local_llm_request_id := 0
var _pending_authored_response: Dictionary = {}
var _pending_grounded_response: Dictionary = {}
var _pending_player_message := ""
var _last_player_message := ""
var _last_spoken_text := ""
var _spoken_full_reply := ""

const ACTIVITY_DESTINATIONS := {
	"mind": "Mind Spark Kingdom",
	"heart": "Heart Melody Kingdom",
	"creator": "Creator's Light Kingdom",
	"crown": "Crown of Life",
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
		"activity": "Would you like to revisit your current ARTÉA space and make a small celebration mark, sound, or reflection?",
		"activity_id": "crown",
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
	{
		"label": "Look back at my growth",
		"activity": "Crown of Life",
		"activity_id": "crown",
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

const UI_INK := Color(0.13, 0.10, 0.075, 1.0)
const UI_PARCHMENT := Color(0.96, 0.89, 0.72, 1.0)
const UI_NAVY := Color(0.075, 0.13, 0.24, 0.96)
const UI_NAVY_HOVER := Color(0.12, 0.22, 0.36, 0.98)
const UI_GOLD := Color(0.70, 0.52, 0.21, 0.95)
const UI_GOLD_BRIGHT := Color(0.93, 0.75, 0.36, 1.0)
const UI_BODY_FONT := preload("res://assets/Fonts/grenze/Grenze-Medium.ttf")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# This is a display transcript, not a text-input surface.
	chat_history.editable = false
	chat_history.selecting_enabled = true
	_apply_banner_theme()
	_resolve_safe_context()
	var current_scene := get_tree().current_scene
	_conversation_context.update_scene(current_scene.name if current_scene != null \
		else "unknown", _stage, _mode, "conversation", false)
	_initialize_local_llm()
	_show_choices()


func _apply_banner_theme() -> void:
	content.add_theme_constant_override("separation", 7)
	chat_history.tooltip_text = "Milo's current reply"


func configure_conversation_context(context: MiloConversationContext,
		scene_name := "unknown", activity_state := "conversation") -> void:
	if context != null:
		_conversation_context = context
	_conversation_context.update_scene(scene_name, _stage, _mode,
		activity_state.to_lower(), false)


func _process(_delta: float) -> void:
	# Web can deliver the pointer-lock event from the opening click one frame
	# late. Keep Milo's modal conversation in ordinary cursor mode throughout.
	if visible and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_chat()


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
	_speak("Wonderful Counsellor Milo · %s\n\n%s\n\nWhat would you like to talk about?" % [
		reflection["title"],
		MODE_INTROS[_mode],
	])
	_clear_choices()
	_add_message_input()


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
	_speak("Wonderful Counsellor Milo · Emotional Companion\n\nChoose words that feel closest, or return without choosing. Milo will respond to your choice—not guess what you feel.")
	_clear_choices()
	for check_in in EMOTION_CHECK_INS:
		var button := _quiet_button(str(check_in.label), _respond_to_emotion.bind(check_in))
		_choices.add_child(button)
		if user_input == null:
			user_input = button
	_add_companion_navigation()


func _respond_to_emotion(check_in: Dictionary) -> void:
	_request_companion_activity("ENCOURAGING", "encourage")
	var player_choice := str(check_in.label)
	var emotion := _emotion_from_choice(player_choice)
	_conversation_context.observe_player_message(player_choice, emotion, "")
	var response := {
		"emotion": emotion,
		"validate": str(check_in.acknowledge),
		"reflect": str(check_in.reflection),
		"strength": str(check_in.strength),
		"guidance": str(check_in.question),
		"activity": str(check_in.activity),
	}
	var natural_response := _conversation_context.naturalize_reflection(
		response, player_choice)
	_show_companion_response(
		"Emotional Companion",
		natural_response,
		str(check_in.get("activity_id", ""))
	)
	_record_conversation_exchange(player_choice, natural_response,
		_conversation_context.choose_intention("", emotion))


func _emotion_from_choice(label: String) -> String:
	var lower := label.to_lower()
	for emotion in ["worried", "stressed", "sad", "frustrated", "lonely", "proud"]:
		if lower.contains(emotion):
			return emotion
	return "unclear"


func _add_message_input() -> void:
	if not _last_player_message.is_empty():
		var player_echo := Label.new()
		player_echo.name = "PlayerLastMessage"
		player_echo.text = "YOU  •  %s" % _short_player_echo(_last_player_message)
		player_echo.custom_minimum_size = Vector2(0, 25)
		player_echo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		player_echo.add_theme_font_override("font", UI_BODY_FONT)
		player_echo.add_theme_font_size_override("font_size", 19)
		player_echo.add_theme_color_override("font_color", Color(0.23, 0.145, 0.065, 1.0))
		_choices.add_child(player_echo)

	var prompt := Label.new()
	prompt.text = "YOU  •  TYPE YOUR REPLY   ·   280 CHARACTERS MAX"
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_override("font", UI_BODY_FONT)
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_color_override("font_color", Color(0.30, 0.20, 0.105, 0.92))
	_choices.add_child(prompt)

	var row := HBoxContainer.new()
	row.name = "LocalMessageRow"
	row.add_theme_constant_override("separation", 10)
	_choices.add_child(row)
	_message_input = LineEdit.new()
	_message_input.name = "MiloMessageInput"
	_message_input.placeholder_text = "Share a thought, a question, or something you noticed…"
	_message_input.max_length = ReflectionEngine.MAX_MESSAGE_LENGTH
	_message_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_input.tooltip_text = "This message is processed locally and is not saved."
	_message_input.custom_minimum_size = Vector2(0, 48)
	_message_input.add_theme_font_override("font", UI_BODY_FONT)
	_message_input.add_theme_font_size_override("font_size", 20)
	_message_input.add_theme_color_override("font_color", UI_PARCHMENT)
	_message_input.add_theme_color_override("font_placeholder_color", Color(0.88, 0.82, 0.70, 0.86))
	_message_input.add_theme_stylebox_override("normal", _input_style(false))
	_message_input.add_theme_stylebox_override("focus", _input_style(true))
	row.add_child(_message_input)
	_message_send_button = _quiet_button("Send", _submit_message.bind(_message_input))
	_message_send_button.name = "MiloMessageSend"
	_message_send_button.custom_minimum_size = Vector2(144, 48)
	_style_send_button(_message_send_button)
	row.add_child(_message_send_button)
	_message_input.text_submitted.connect(func(_submitted_text: String) -> void:
		_submit_message(_message_input)
	)
	user_input = _message_input


func _short_player_echo(message: String) -> String:
	var clean := message.replace("\n", " ").strip_edges()
	if clean.length() <= 110:
		return clean
	var shortened := clean.left(109)
	var last_space := shortened.rfind(" ")
	if last_space > 70:
		shortened = shortened.left(last_space)
	return shortened + "…"


func _submit_message(input: LineEdit) -> void:
	if input == null:
		return
	var message := input.text.substr(0, ReflectionEngine.MAX_MESSAGE_LENGTH).strip_edges()
	input.clear()
	if message.is_empty():
		input.placeholder_text = "Write a few words for Milo first."
		input.grab_focus()
		return
	_last_player_message = message
	var response: Dictionary = _reflection_engine.reflect(message)
	if bool(response.get("urgent", false)):
		_request_companion_activity("SUPPORTING", "heart")
		_show_chat_response(
			"Get real-world help now",
			"%s\n\n%s\n\n%s\n\n%s\n\n%s" % [
				str(response.validate), str(response.reflect), str(response.strength),
				str(response.guidance), str(response.activity),
			]
		)
		_show_support()
		return
	var grounded: Dictionary = _wisdom_engine.respond(message, _mode,
		_conversation_context.snapshot())
	var topic := str(grounded.get("category", ""))
	_conversation_context.observe_player_message(message,
		str(response.get("emotion", "unclear")), topic)
	# Exact citation requests bypass generation on every platform so model prose
	# can never alter the retrieved wording or fabricate a missing verse.
	if str(grounded.get("category", "")) in ["scripture_reference", "scripture_not_found"]:
		_show_grounded_wisdom_response(grounded, message)
		return
	if _local_llm_chat != null and is_instance_valid(_local_llm_chat):
		_begin_local_llm_response(message, response, grounded)
		return
	if not grounded.is_empty() and bool(grounded.get("handled", false)):
		_show_grounded_wisdom_response(grounded, message)
		return
	_show_authored_message_response(response, message)


func _show_authored_message_response(response: Dictionary,
		player_message := "") -> void:
	_request_companion_activity("REFLECTING", "tablet")
	var natural_response := _conversation_context.naturalize_reflection(
		response, player_message)
	_show_chat_response(
		"Reflection Partner",
		natural_response
	)
	_record_conversation_exchange(player_message, natural_response,
		_conversation_context.choose_intention("", str(response.get("emotion", "unclear"))))


func _show_grounded_wisdom_response(response: Dictionary,
		player_message := "") -> void:
	_request_companion_activity("REFLECTING", "tablet")
	var grounded_text := str(response.get("text", ""))
	_show_chat_response("Wisdom Library", grounded_text)
	_record_conversation_exchange(player_message, grounded_text,
		_conversation_context.choose_intention(str(response.get("category", "")), ""))


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
		authored_response: Dictionary, grounded_response := {}) -> void:
	if _local_llm_generating:
		return
	_local_llm_generating = true
	_local_llm_response = ""
	_pending_authored_response = authored_response.duplicate(true)
	_pending_grounded_response = grounded_response.duplicate(true)
	_pending_player_message = message
	_local_llm_request_id += 1
	var request_id := _local_llm_request_id
	_request_companion_activity("LISTENING", "heart")
	chat_history.text = "Wonderful Counsellor Milo · Listening\n\nMilo is thinking with the local model…"
	_clear_choices()
	_add_message_input()
	_message_input.editable = false
	_message_input.placeholder_text = "Milo is thinking locally…"
	_message_send_button.disabled = true
	_local_llm_chat.call("say", _wisdom_engine.build_local_model_packet(
		message, grounded_response, _conversation_context.snapshot()))
	get_tree().create_timer(LOCAL_LLM_TIMEOUT_SECONDS).timeout.connect(
		_on_local_llm_timeout.bind(request_id))


func _on_local_llm_response_updated(new_token: String) -> void:
	if not _local_llm_generating:
		return
	_local_llm_response += new_token
	var preview := _clean_local_llm_response(_local_llm_response)
	if not preview.is_empty():
		chat_history.text = "Wonderful Counsellor Milo · Thinking locally\n\n%s" % preview


func _on_local_llm_response_finished(response: String) -> void:
	if not _local_llm_generating:
		return
	_local_llm_generating = false
	var clean_response := _clean_local_llm_response(response)
	if clean_response.is_empty():
		_show_pending_local_fallback()
	else:
		_request_companion_activity("REFLECTING", "tablet")
		_show_chat_response("Local Reflection", clean_response)
		var local_category := str(_pending_grounded_response.get("category", ""))
		var local_emotion := str(_pending_authored_response.get("emotion", "unclear"))
		_record_conversation_exchange(_pending_player_message, clean_response,
			_conversation_context.choose_intention(local_category, local_emotion))
	_pending_authored_response.clear()
	_pending_grounded_response.clear()
	_pending_player_message = ""


func _on_local_llm_timeout(request_id: int) -> void:
	if not _local_llm_generating or request_id != _local_llm_request_id:
		return
	_local_llm_generating = false
	if _local_llm_chat != null and _local_llm_chat.has_method("stop_generation"):
		_local_llm_chat.call("stop_generation")
	_show_pending_local_fallback()
	_pending_authored_response.clear()
	_pending_grounded_response.clear()
	_pending_player_message = ""


func _show_pending_local_fallback() -> void:
	if not _pending_grounded_response.is_empty() \
			and bool(_pending_grounded_response.get("handled", false)):
		_show_grounded_wisdom_response(_pending_grounded_response,
			_pending_player_message)
	else:
		_show_authored_message_response(_pending_authored_response,
			_pending_player_message)


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
		return "Milo is a fictional game character. Typed messages stay on this device and are not saved. Milo uses the included local Gemma model after an authored safety check and does not diagnose or replace a trusted person."
	return "Milo is a fictional game character. Typed messages stay on this device and are not saved. This build uses authored local reflections and a public-domain Bible library. Milo does not diagnose or replace a trusted person."


func is_local_llm_active() -> bool:
	return _local_llm_chat != null and is_instance_valid(_local_llm_chat)


func _show_strength_discoveries() -> void:
	_request_companion_activity("REFLECTING", "encourage")
	_speak("Wonderful Counsellor Milo · Strength Discoverer\n\nChoose something you actually did. Milo will name a possible strength without turning it into a score or reward.")
	_clear_choices()
	for discovery in STRENGTH_DISCOVERIES:
		var button := _quiet_button(str(discovery.label), _respond_to_strength.bind(discovery))
		_choices.add_child(button)
		if user_input == null:
			user_input = button
	_add_companion_navigation()


func _respond_to_strength(discovery: Dictionary) -> void:
	_request_companion_activity("ENCOURAGING", "encourage")
	_show_companion_response(
		"Strength Discoverer",
		"You chose: %s\n\nPossible strength: %s\n\n%s\n\nReflection: %s" % [
			str(discovery.label), str(discovery.strength),
			str(discovery.reflection), str(discovery.question),
		]
	)


func _show_progress_celebration() -> void:
	_request_companion_activity("CELEBRATING", "encourage")
	var progress: Dictionary = STAGE_PROGRESS.get(_stage, STAGE_PROGRESS[0])
	_show_companion_response(
		"Encourager",
		"What the journey records: %s\n\nStrength reflected in that step: %s\n\nA possible next step: %s\n\nYour progress comes from the choices you made; this reflection does not add or remove rewards." % [
			str(progress.evidence), str(progress.strength), str(progress.next),
		]
	)


func _show_activity_guides() -> void:
	_request_companion_activity("GUIDING", "map")
	_speak("Wonderful Counsellor Milo · Journey Guide\n\nChoose what would help now. Milo will suggest an ARTÉA activity without changing your progress.")
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


func _show_companion_response(title: String, message: String,
		destination_id := "") -> void:
	_speak("Wonderful Counsellor Milo · %s\n\n%s" % [title, message])
	_clear_choices()
	_add_companion_navigation(destination_id)


func _show_chat_response(title: String, message: String) -> void:
	# The speaker card already identifies Milo. Keep this surface focused on the
	# actual reply so a player can follow the same words that Milo reads aloud.
	milo_role.text = title.to_upper()
	_speak(message, message)
	_clear_choices()
	_add_message_input()


func _add_companion_navigation(destination_id := "") -> void:
	if ACTIVITY_DESTINATIONS.has(destination_id):
		var destination_name := str(ACTIVITY_DESTINATIONS[destination_id])
		var travel_button := _quiet_button(
			"Go with Milo to %s" % destination_name,
			_confirm_activity_travel.bind(destination_id))
		travel_button.name = "MiloTravel_%s" % destination_id
		_choices.add_child(travel_button)
	var back_button := _quiet_button("Back to companion paths", _show_choices)
	_choices.add_child(back_button)
	user_input = back_button
	_choices.add_child(_quiet_button("Need help", _show_support))
	_choices.add_child(_quiet_button("Close", close_chat))


func _confirm_activity_travel(destination_id: String) -> void:
	var destination_name := str(ACTIVITY_DESTINATIONS.get(destination_id, "ARTÉA activity"))
	_request_companion_activity("GUIDING", "map")
	_clear_choices()
	var campaign := _campaign()
	if destination_id != "crown" and (campaign == null \
			or not bool(campaign.call("can_enter_kingdom", destination_id))):
		var next_name := "the next available activity"
		if campaign != null and campaign.has_method("next_kingdom_id"):
			var next_id := str(campaign.call("next_kingdom_id"))
			next_name = str(ACTIVITY_DESTINATIONS.get(next_id, next_name))
		_speak("Wonderful Counsellor Milo · Journey Guide\n\n%s is still locked by your journey. Milo will not skip or invent progress. Your next available path is %s." % [
			destination_name, next_name,
		])
		_add_companion_navigation()
		return
	_speak("Wonderful Counsellor Milo · Journey Guide\n\nReady to travel to %s? Your reflection is not saved, and travelling does not award progress by itself." % destination_name)
	var confirm_button := _quiet_button("Yes, go with Milo", _travel_to_activity.bind(destination_id))
	confirm_button.name = "MiloTravelConfirm"
	_choices.add_child(confirm_button)
	user_input = confirm_button
	_choices.add_child(_quiet_button("Stay here", _show_choices))
	_choices.add_child(_quiet_button("Need help", _show_support))


func _travel_to_activity(destination_id: String) -> void:
	var campaign := _campaign()
	if campaign == null:
		_speak("Wonderful Counsellor Milo · Journey Guide\n\nThat path is unavailable right now. You can stay with Milo or continue your adventure.")
		_clear_choices()
		_add_companion_navigation()
		return
	var route_method := "start_campaign" if destination_id == "crown" else "enter_kingdom"
	if not campaign.has_method(route_method):
		return
	activity_travel_requested.emit(destination_id)
	chat_closed.emit()
	campaign.call(route_method, destination_id) if route_method == "enter_kingdom" \
		else campaign.call(route_method)


func _campaign() -> Node:
	if is_instance_valid(campaign_router):
		return campaign_router
	return get_node_or_null("/root/JourneyCampaign")


func _request_companion_activity(state_name: String, pose_name: String) -> void:
	var scene_name := "unknown"
	if get_tree().current_scene != null:
		scene_name = get_tree().current_scene.name
	_conversation_context.update_scene(scene_name, _stage, _mode,
		state_name.to_lower(), state_name.to_upper() == "SUPPORTING")
	companion_activity_state_requested.emit(state_name)
	companion_pose_requested.emit(pose_name)


func _record_conversation_exchange(player_message: String, milo_response: String,
		intention: String) -> void:
	if player_message.strip_edges().is_empty():
		return
	_conversation_context.record_exchange(player_message, milo_response, intention)


func _choose_reflection(choice: Dictionary) -> void:
	var reply := str(choice.get(_mode, choice.get("universal", "")))
	_speak("Wonderful Counsellor Milo · %s\n\n%s\n\nYou can continue your adventure whenever you are ready." % [
		str(choice.get("label", "A quiet choice")),
		reply,
	])
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
		_choices.add_theme_constant_override("separation", 4)
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
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 25)
	button.add_theme_font_override("font", UI_BODY_FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", UI_PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.tooltip_text = "This choice is local and does not change your rewards."

	var normal := StyleBoxFlat.new()
	normal.bg_color = UI_NAVY
	normal.border_color = UI_GOLD
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	normal.set_content_margin_all(5)
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = UI_NAVY_HOVER
	hover.border_color = UI_GOLD_BRIGHT
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.18, 0.13, 0.07, 0.98)
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(action)
	return button


func _style_send_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.06, 0.12, 0.18, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.03, 0.07, 0.11, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.03, 0.07, 0.11, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.80, 0.58, 0.22, 1.0)
	normal.border_color = Color(1.0, 0.91, 0.64, 1.0)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(8)
	normal.shadow_color = Color(0.10, 0.06, 0.02, 0.32)
	normal.shadow_size = 3
	normal.shadow_offset = Vector2(0, 2)
	button.add_theme_stylebox_override("normal", normal)
	var active := normal.duplicate() as StyleBoxFlat
	active.bg_color = Color(0.93, 0.75, 0.36, 1.0)
	active.border_color = Color(1.0, 0.95, 0.76, 1.0)
	button.add_theme_stylebox_override("hover", active)
	button.add_theme_stylebox_override("focus", active)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.62, 0.43, 0.15, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)


func _input_style(focused: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.06, 0.085, 0.97)
	style.border_color = UI_GOLD_BRIGHT if focused else Color(0.42, 0.32, 0.18, 0.9)
	style.set_border_width_all(2 if focused else 1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(0.10, 0.06, 0.02, 0.22)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 2)
	return style


func _show_support() -> void:
	_request_companion_activity("SUPPORTING", "heart")
	if not is_instance_valid(_support_card):
		_support_card = SupportCard.new()
		_support_card.name = "MiloSupportCard"
		add_child(_support_card)
	_support_card.call("show_card")


func _speak(text: String, spoken_text := "") -> void:
	_spoken_full_reply = text.strip_edges()
	chat_history.add_theme_font_size_override("font_size", 24)
	chat_history.text = _spoken_full_reply
	_last_spoken_text = spoken_text.strip_edges() \
		if not spoken_text.strip_edges().is_empty() else _spoken_full_reply
	companion_speech_requested.emit(_last_spoken_text)


func show_spoken_sentence(sentence: String, sentence_index: int,
		sentence_count: int, full_reply: String) -> void:
	if sentence.strip_edges().is_empty():
		return
	_spoken_full_reply = full_reply.strip_edges()
	chat_history.add_theme_font_size_override("font_size", 32)
	chat_history.text = sentence.strip_edges()
	milo_role.text = "READING  ·  %d OF %d" % [sentence_index + 1,
		maxi(sentence_count, 1)]


func finish_spoken_reply() -> void:
	chat_history.add_theme_font_size_override("font_size", 24)
	if not _spoken_full_reply.is_empty():
		chat_history.text = _spoken_full_reply
	milo_role.text = "ART SCHOLAR  ·  READY"


func replay_current_speech() -> void:
	if not _last_spoken_text.is_empty():
		companion_speech_requested.emit(_last_spoken_text)


func close_chat() -> void:
	if _local_llm_generating and _local_llm_chat != null \
			and _local_llm_chat.has_method("stop_generation"):
		_local_llm_chat.call("stop_generation")
	_local_llm_generating = false
	_local_llm_request_id += 1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	emit_signal("chat_closed")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_chat()
