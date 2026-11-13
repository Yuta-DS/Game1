extends Control

@onready var chat_history = $VBoxContainer/ChatHistory
@onready var user_input = $VBoxContainer/HBoxContainer/UserInput
@onready var send_button = $VBoxContainer/HBoxContainer/SendButton
@onready var http_request = $HTTPRequestChatGPT
@onready var ai_counselor = $AI_Counselor
@onready var model = $MiloModel

var local_ai_enabled := false
signal chat_closed

func _ready():
	_setup_chat_backend()
	#model.load_model("")
	#ai_counselor.set_model(model)
	#var reply = ai_counselor.generate("Hello")
	#print(reply)
	#var reply3 = ai_counselor.generate("User: Hello\nAssistant:")
	#print(reply3)
	
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

func _setup_chat_backend() -> void:
	# Desktop keeps the local NobodyWho model. Web uses the Flask endpoint so
	# the browser bundle contains no native libraries or multi-gigabyte model.
	if not OS.has_feature("web") \
		and ClassDB.class_exists("NobodyWhoChat") \
		and ClassDB.class_exists("NobodyWhoModel"):
		ai_counselor.queue_free()
		model.queue_free()
		ai_counselor = ClassDB.instantiate("NobodyWhoChat")
		model = ClassDB.instantiate("NobodyWhoModel")
		ai_counselor.name = "MiloChatBackend"
		model.name = "MiloModelBackend"
		add_child(ai_counselor)
		add_child(model)
		model.model_path = "res://nobodywhomodels/gemma-2-2b-it-Q4_K_M.gguf"
		ai_counselor.set_model_node(model)
		ai_counselor.set_system_prompt(load_prompt())
		ai_counselor.start_worker()
		ai_counselor.connect("response_finished", Callable(self, "_on_ai_response"))
		local_ai_enabled = true
	elif not http_request.request_completed.is_connected(_on_http_request_completed):
		http_request.request_completed.connect(_on_http_request_completed)

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
		if local_ai_enabled:
			ai_counselor.say(message)
		else:
			send_message_to_server(message)
		user_input.text = ""

func append_to_chat(text: String):
	chat_history.text += text + "\n\n"
	chat_history.scroll_vertical = chat_history.get_line_count()

func send_message_to_server(user_message: String) -> void:
	var body = {
		"messages": [
			{"role": "system", "content": load_prompt()},
			{"role": "user", "content": user_message},
		]
	}
	var error := http_request.request(
		APIManager.AI_CHAT_URL,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	if error != OK:
		append_to_chat("Milo: I am having trouble connecting right now. Please try again.")

func _on_http_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if response_code == 200:
		var response = JSON.parse_string(body.get_string_from_utf8())
		if typeof(response) == TYPE_DICTIONARY and response.has("reply"):
			append_to_chat("Milo: " + str(response["reply"]).strip_edges())
		else:
			append_to_chat("Milo: I could not understand the server response.")
	else:
		append_to_chat("Milo: I am having trouble connecting right now. Please try again.")

func close_chat():
	emit_signal("chat_closed")

func _input(event):
	if event.is_action_pressed("ui_cancel"): # If chat closed
		close_chat()
