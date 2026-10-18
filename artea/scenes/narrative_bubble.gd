extends Sprite3D

# Reference the main message and the new name label in the brown box
@onready var message_label = $Label3D
@onready var name_label = $CharacterName

const PRESENTATION_SCALE := 0.72


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var toward_camera := camera.global_position - global_position
	toward_camera.y = 0.0
	if toward_camera.length_squared() < 0.0001:
		return
	# Rotate the node, not just its texture, so both child labels keep the
	# correct reading direction and stay on the front of the parchment.
	look_at(global_position + toward_camera, Vector3.UP, true)
	scale = Vector3.ONE * PRESENTATION_SCALE

func _ready():
	await get_tree().process_frame
	
	# Pull the player's name from your Global singleton
	var player_name = Global.current_user_name
	
	# 1. Set the Speaker's Name
	if name_label:
		name_label.text = "Archangel Gabriel" 
	
	# 2. Set the Personalized Greeting
	if message_label:
		message_label.text = "Welcome, " + player_name + ". The light of Artéa has been waiting for you. Step forward, discover your true purpose, and bring your unique spark to our world!"
