extends Node3D

@onready var anim_player = $AnimationPlayer
@onready var player = get_node("../NewPlayer")

var player_in_range = false
var chatbot_ui = null

func look_at_player(delta):
	var target_pos = player.global_transform.origin
	var my_pos = global_transform.origin
	var direction = (target_pos - my_pos).normalized()
	
	var rotation_y = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, rotation_y, 5.0 * delta)

func _ready():
	anim_player.play("Walking")

func _on_area_3d_player_nearby(body):
	if body != null:
		player_in_range = true
		#look_at_player()
	else:
		player_in_range = false
		#end_interaction() #To be implemented

func _process(delta):
	if player_in_range:
		look_at_player(delta)
		
		if Input.is_action_just_pressed("interact"):
			open_chatbot()
			player.interacting = true

func open_chatbot():
	if chatbot_ui != null:
		return

	chatbot_ui = load("res://scenes/chatbot.tscn").instantiate()
	get_tree().current_scene.add_child(chatbot_ui)
	chatbot_ui.user_input.grab_focus()
	chatbot_ui.connect("chat_closed", Callable(self, "close_chatbot"))
	player.interacting = true

func close_chatbot():
	if chatbot_ui != null:
		chatbot_ui.queue_free()
		chatbot_ui = null
	player.interacting = false
