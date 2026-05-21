extends Sprite3D

# Reference the main message and the new name label in the brown box
@onready var message_label = $Label3D
@onready var name_label = $CharacterName

func _ready():
	await get_tree().process_frame
	
	# Pull the player's name from your Global singleton
	var player_name = Global.current_user_name
	
	# 1. Set the Speaker's Name
	if name_label:
		name_label.text = "Seraphim" 
	
	# 2. Set the Personalized Greeting
	if message_label:
		message_label.text = "Welcome, " + player_name + ". Artéa has been dimmed by fear and confusion. You are here to rediscover the truth."
