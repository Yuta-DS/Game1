extends Node3D

@onready var anim_player = $AnimationPlayer

var wave_timer := 0.0
var is_waving := false


func _ready():
	anim_player.play("Idle_3")


func _process(delta):
	# If currently waving, do nothing until it finishes
	if is_waving:
		return

	wave_timer += delta

	# Keep idle playing while waiting
	if anim_player.current_animation != "Idle_3":
		anim_player.play("Idle_3")

	# Trigger wave every 5 seconds
	if wave_timer >= 5.0:
		is_waving = true
		wave_timer = 0.0
		anim_player.play("Wave_One_Hand")


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "Wave_One_Hand":
		is_waving = false
		anim_player.play("Idle_3")
