extends Sprite3D

@onready var message_label = $Label3D

func _ready():
	await get_tree().process_frame
	
	# Pull from the pre-existing global variable
	var player_name = Global.current_user_name
	
	if message_label:
		message_label.text = "Welcome Seeker, " + player_name + ". Your journey through Artéa begins now."
