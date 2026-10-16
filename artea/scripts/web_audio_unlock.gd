extends Node

var _unlocked := false


func _ready() -> void:
	set_process_input(OS.get_name() == "Web")


func _input(event: InputEvent) -> void:
	if _unlocked or not _is_unlock_interaction(event):
		return
	_unlocked = true
	call_deferred("_retry_autoplay_streams")


func _is_unlock_interaction(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton:
		return event.pressed
	return false


func _retry_autoplay_streams() -> void:
	# Godot resumes its browser AudioContext in response to the input event.
	# Retry only autoplay nodes that are still stopped; already-playing streams,
	# positional settings, buses, volumes, loops, and attenuation stay untouched.
	_retry_in_branch(get_tree().root)


func _retry_in_branch(node: Node) -> void:
	if node is AudioStreamPlayer:
		_retry_player(node)
	elif node is AudioStreamPlayer2D:
		_retry_player(node)
	elif node is AudioStreamPlayer3D:
		_retry_player(node)
	for child in node.get_children():
		_retry_in_branch(child)


func _retry_player(player: Node) -> void:
	if player.stream and player.autoplay and not player.playing:
		player.play()
