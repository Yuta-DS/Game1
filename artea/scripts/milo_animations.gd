extends Node3D

@onready var anim_player = $AnimationPlayer
@onready var player = get_node("../NewPlayer")

var player_in_range := false
var chatbot_ui = null

var wave_timer := 0.0
var first_wave := false


func _ready():
	anim_player.play("Idle_3")


func look_at_player(delta):
	var target_pos = player.global_transform.origin
	var my_pos = global_transform.origin

	var direction = (target_pos - my_pos).normalized()
	var rotation_y = atan2(direction.x, direction.z)

	rotation.y = lerp_angle(rotation.y, rotation_y, 5.0 * delta)


func _on_area_3d_player_entered(body):
	if body == player:
		player_in_range = true


func _on_area_3d_player_exited(body):
	if body == player:
		player_in_range = false
		_reset_npc_state()


func _reset_npc_state():
	# hard reset everything so nothing gets stuck
	wave_timer = 0.0
	first_wave = false
	anim_player.play("Idle_3")


func _process(delta):
	# ALWAYS face player (inside + outside range)
	look_at_player(delta)

	# OUTSIDE interaction zone: just idle tracking
	if not player_in_range:
		if anim_player.current_animation != "Idle_3":
			anim_player.play("Idle_3")
		return

	# INSIDE interaction zone: waving logic
	if not first_wave:
		anim_player.play("Wave_One_Hand")
		wave_timer = 0.0
		first_wave = true

	wave_timer += delta

	if wave_timer >= 5.0 and not player.interacting:
		anim_player.play("Wave_One_Hand")
		wave_timer = 0.0

	# interaction
	if Input.is_action_just_pressed("interact") and player_in_range:
		print("Interacting with Milo")
		open_chatbot()
		player.interacting = true


func open_chatbot():
	if chatbot_ui != null:
		return

	chatbot_ui = load("res://scenes/chatbot.tscn").instantiate()
	get_tree().current_scene.add_child(chatbot_ui)
	print("Milo opened chat")

	chatbot_ui.user_input.grab_focus()
	chatbot_ui.connect("chat_closed", Callable(self, "close_chatbot"))

	player.interacting = true


func close_chatbot():
	if chatbot_ui != null:
		chatbot_ui.queue_free()
		chatbot_ui = null

	player.interacting = false
