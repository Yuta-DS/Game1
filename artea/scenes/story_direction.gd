extends "res://scenes/narrative_bubble.gd"

func _ready():
	await get_tree().process_frame
	var player_name = Global.current_user_name
	
	if name_label:
		name_label.text = "Counsellor" 
	
	if message_label:
		message_label.text = "The air feels different here, " + player_name + ". You should find Milo, our Wonderful Councellor..."
