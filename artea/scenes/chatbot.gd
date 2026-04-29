extends Control

@onready var chat_history = $VBoxContainer/ChatHistory
@onready var user_input = $VBoxContainer/HBoxContainer/UserInput
@onready var send_button = $VBoxContainer/HBoxContainer/SendButton
@onready var http_request = $HTTPRequestChatGPT
@onready var ai_counselor = $AI_Counselor
@onready var model = $Model

var openai_api_key = "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" # <<<<<< REPLACE with your real key
signal chat_closed

func _ready():
	# Load the .gguf model
	model.model_path = "res://nobodywhomodels/gemma-2-2b-it-Q4_K_M.gguf"
	ai_counselor.set_model_node(model)
	ai_counselor.set_system_prompt(load_prompt())
	ai_counselor.start_worker()
	
	# Connect signals
	ai_counselor.connect("response_finished", Callable(self, "_on_ai_response"))
	#model.load_model("")
	#ai_counselor.set_model(model)
	#var reply = ai_counselor.generate("Hello")
	#print(reply)
	#var reply3 = ai_counselor.generate("User: Hello\nAssistant:")
	#print(reply3)
	
	print("=== CHAT SIGNALS ===")
	for s in ai_counselor.get_signal_list():
		print(s.name)
	
	#print("=== MODEL FUNCTIONS ===")
	#for m in model.get_method_list():
		#print(m.name)
	#print("=== MODEL PROPERTIES ===")
	#for p in model.get_property_list():
		#print(p.name)
	#
		#
	#print("=== CHAT FUNCTIONS ===")
	#for m in ai_counselor.get_method_list():
		#print(m.name)
	#print("=== MODEL PROPERTIES ===")
	#for p in ai_counselor.get_property_list():
		#print(p.name)
	
	# Ensure signals are connected only once using Callables
	var pressed_callable = Callable(self, "_on_send_button_pressed")
	var submitted_callable = Callable(self, "_on_send_button_pressed")

	if not send_button.is_connected("pressed", pressed_callable):
		send_button.pressed.connect(pressed_callable)
	
	if not user_input.is_connected("text_submitted", submitted_callable):
		user_input.text_submitted.connect(submitted_callable)
		
	user_input.grab_focus()

func load_prompt() -> String:
	var file  = FileAccess.open("res://addons/nobodywho/milo_prompt.txt", FileAccess.READ)
	if file:
		return file.get_as_text()
	else:
		return "You are Milo, the Wonderful Counselor of Artea."

func _on_ai_response(response):
	append_to_chat("Milo: " + response.strip_edges())

func _on_send_button_pressed(submitted_text = ""):
	var message = submitted_text
	if message == "":
		message = user_input.text.strip_edges()
		
	if message != "":
		append_to_chat("You: " + message)
		#var reply2 = ai_counselor.generate("User: " + message + "\nAssistant:")
		#append_to_chat("Milo: " + reply2)
		ai_counselor.say(message)
		user_input.text = ""

func append_to_chat(text: String):
	chat_history.text += text + "\n\n"
	chat_history.scroll_vertical = chat_history.get_line_count()

func send_message_to_chatgpt(user_message: String) -> void:
	var url = "https://api.openai.com/v1/chat/completions"
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + openai_api_key
	]
	
	var body = {
		"model": "gpt-3.5-turbo",
		"messages": [
			{"role": "system", "content": "You are a friendly chatbot."},
			{"role": "user", "content": user_message}
		]
	}
	
	var body_json = JSON.stringify(body)
	
	var error = http_request.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		body_json
	)
	
	if error != OK:
		append_to_chat("Error sending message! Error code: " + str(error))

func _on_http_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if response_code == 200:
		var response = JSON.parse_string(body.get_string_from_utf8())
		if response:
			var reply_text = response["choices"][0]["message"]["content"]
			append_to_chat("ChatGPT: " + reply_text.strip_edges())
	else:
		append_to_chat("Request failed! Server returned: " + str(response_code))

func close_chat():
	emit_signal("chat_closed")

func _input(event):
	if event.is_action_pressed("ui_cancel"): # If chat closed
		close_chat()
