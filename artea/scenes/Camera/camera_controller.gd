extends Node3D

@onready var player = get_node("/root/HubWorld/NewPlayer")

@export var minLimitX: float
@export var maxLimitX: float
@export var mouseAcceleration := 0.005

func _input(event: InputEvent) -> void:
	if player.interacting:
		return
	if event is InputEventMouseMotion:
		rotateFromVector(event.relative * mouseAcceleration)

func rotateFromVector(v: Vector2):
	if v.length() == 0: return
	rotation.y -= v.x
	rotation.x -= v.y
	rotation.x = clamp(rotation.x, minLimitX, maxLimitX) 
