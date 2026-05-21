extends Sprite3D

# These $ signs tell Godot to look INSIDE the spawn for the labels
@onready var message_label = $Label3D
@onready var name_label = $CharacterName

func _ready():
	await get_tree().process_frame
	var player_name = Global.current_user_name
	
	if name_label:
		name_label.text = "Counsellor" 
	
	if message_label:
		message_label.text = "The air feels different here, " + player_name + ". You should find Milo, our         Wonderful Councellor..."
