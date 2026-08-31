extends "res://scripts/milo_animations.gd"

# Gameplay compatibility for the independent Milo 2 asset. The established
# companion controller still owns chat, speech, following and interaction, while
# this adapter translates its legacy clip requests into Milo 2's authored set.


func _ready() -> void:
	set_meta("milo_generation", 2)
	set_meta("milo_visual_variant", "independent_reference_build_gameplay")
	super._ready()


func get_milo_generation() -> int:
	return 2


func _play_animation(animation_name: String) -> void:
	if anim_player == null:
		return
	var requested := animation_name.to_lower()
	var clip := &"Milo2_Idle"
	var speed := 1.0
	if "walk" in requested:
		clip = &"Milo2_Walk"
		speed = 0.86
	elif "wave" in requested or "celebrat" in requested:
		clip = &"Milo2_Wave"
		speed = 0.82
	if not anim_player.has_animation(clip):
		return
	if anim_player.current_animation == String(clip):
		return
	anim_player.play(clip, 0.20, speed)

