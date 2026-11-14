extends Area2D

@export var painting_id: int 

func _ready():
	# When the player enters, store this area on the player
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited",  Callable(self, "_on_body_exited"))

func _on_body_entered(body: Node):
	if body.is_in_group("Player"):
		
		body.interacting_area = self

func _on_body_exited(body: Node):
	if body.is_in_group("Player") and body.interacting_area == self:
		body.interacting_area = null
