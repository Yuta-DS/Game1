extends Node3D

const REQUIRED_CLIPS := [&"Milo2_Idle", &"Milo2_Walk", &"Milo2_Wave"]

var animation_player: AnimationPlayer


func _ready() -> void:
	animation_player = _find_animation_player(self)
	if animation_player != null:
		play(&"Milo2_Idle")


func play(clip: StringName, blend: float = 0.18) -> void:
	if animation_player == null or not animation_player.has_animation(clip):
		return
	if animation_player.current_animation == String(clip):
		return
	animation_player.play(clip, blend)


func has_complete_animation_set() -> bool:
	if animation_player == null:
		return false
	for clip in REQUIRED_CLIPS:
		if not animation_player.has_animation(clip):
			return false
	return true


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

