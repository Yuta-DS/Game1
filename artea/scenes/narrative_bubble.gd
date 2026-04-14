extends Sprite3D

@export var float_speed := 2.0
@export var float_amplitude := 0.1

var time := 0.0
@onready var start_y = position.y

func _process(delta):
	time += delta
	# This creates a smooth bobbing motion
	position.y = start_y + sin(time * float_speed) * float_amplitude
