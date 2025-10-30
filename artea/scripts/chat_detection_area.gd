extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.



	
signal player_nearby

func _on_body_entered(body):
	if body.name == "Player":
		emit_signal("player_nearby", body)

func _on_body_exited(body):
	if body.name == "Player":
		emit_signal("player_nearby", null)
