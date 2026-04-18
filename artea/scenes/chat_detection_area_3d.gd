extends Area3D

signal player_nearby

func _on_body_entered(body):
	if body.name == "NewPlayer":
		emit_signal("player_nearby", body)
		print("Entered:", body.name)

func _on_body_exited(body):
	if body.name == "NewPlayer":
		emit_signal("player_nearby", null)
