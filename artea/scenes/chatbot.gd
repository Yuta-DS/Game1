extends Control

@onready var chat_history: TextEdit = $VBoxContainer/ChatHistory
@onready var user_input: LineEdit = $VBoxContainer/HBoxContainer/UserInput
@onready var send_button: Button = $VBoxContainer/HBoxContainer/SendButton
@onready var ai_counselor: Node = $AI_Counselor
@onready var model: Node = $MiloModel

const PROMPT_PATH := "res://dialogue/milo_prompt.txt"

var local_llm_available := false
var request_in_progress := false
var conversation: Array = []

signal chat_closed


func _ready() -> void:
	var prompt := load_prompt()
	conversation.append({"role": "system", "content": prompt})

	# NobodyWho remains the preferred offline desktop provider. The same UI and
	# prompt use the server provider when the native extension is unavailable.
	if ClassDB.can_instantiate("NobodyWhoModel") and ClassDB.can_instantiate("NobodyWhoChat"):
		model.queue_free()
		ai_counselor.queue_free()
		model = ClassDB.instantiate("NobodyWhoModel")
		model.name = "MiloModel"
		add_child(model)
		ai_counselor = ClassDB.instantiate("NobodyWhoChat")
		ai_counselor.name = "AI_Counselor"
		add_child(ai_counselor)
		model.model_path = "res://nobodywhomodels/gemma-2-2b-it-Q4_K_M.gguf"
		ai_counselor.set_model_node(model)
		ai_counselor.set_system_prompt(prompt)
		ai_counselor.start_worker()
		ai_counselor.connect("response_finished", Callable(self, "_on_ai_response"))
		local_llm_available = true

	if not send_button.pressed.is_connected(_on_send_button_pressed):
		send_button.pressed.connect(_on_send_button_pressed)
	if not user_input.text_submitted.is_connected(_on_send_button_pressed):
		user_input.text_submitted.connect(_on_send_button_pressed)
	user_input.grab_focus()


func load_prompt() -> String:
	var file := FileAccess.open(PROMPT_PATH, FileAccess.READ)
	if file:
		return file.get_as_text()
	return "You are Milo, the Wonderful Counselor of Artea."


func _on_send_button_pressed(submitted_text := "") -> void:
	if request_in_progress:
		return
	var message := submitted_text.strip_edges()
	if message.is_empty():
		message = user_input.text.strip_edges()
	if message.is_empty():
		return

	append_to_chat("You: " + message)
	conversation.append({"role": "user", "content": message})
	user_input.text = ""
	_set_waiting(true)
	if local_llm_available:
		ai_counselor.say(message)
	else:
		APIManager.chat(conversation, _on_server_response)


func _on_ai_response(response) -> void:
	var reply := str(response).strip_edges()
	conversation.append({"role": "assistant", "content": reply})
	append_to_chat("Milo: " + reply)
	_set_waiting(false)


func _on_server_response(success: bool, response: String) -> void:
	if success:
		conversation.append({"role": "assistant", "content": response})
		append_to_chat("Milo: " + response.strip_edges())
	else:
		append_to_chat("Milo: " + response)
	_set_waiting(false)


func _set_waiting(waiting: bool) -> void:
	request_in_progress = waiting
	send_button.disabled = waiting
	user_input.editable = not waiting
	if not waiting:
		user_input.grab_focus()


func append_to_chat(text: String) -> void:
	chat_history.text += text + "\n\n"
	chat_history.scroll_vertical = chat_history.get_line_count()


func close_chat() -> void:
	chat_closed.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_chat()
