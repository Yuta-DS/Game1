class_name MindSparkWorldGate
extends Area3D

signal travelled(destination_world_local: Vector3)

@export var destination_world_local := Vector3.ZERO
@export var gate_enabled := true
@export var prompt_text := "Q • ENTER MIND SPARK"

var _player_inside: CharacterBody3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_enabled()


func set_gate_enabled(enabled: bool) -> void:
	gate_enabled = enabled
	_apply_enabled()


func teleport_player(player: CharacterBody3D) -> bool:
	if not gate_enabled or player == null:
		return false
	var floating_world := _find_floating_world()
	if floating_world == null:
		return false
	player.global_position = floating_world.to_global(destination_world_local)
	player.velocity = Vector3.ZERO
	travelled.emit(destination_world_local)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside != null and event.is_action_pressed("interact") and teleport_player(_player_inside):
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.is_in_group("Player"):
		_player_inside = body
		$Prompt.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body == _player_inside:
		_player_inside = null
		$Prompt.visible = false


func _find_floating_world() -> Node3D:
	var current: Node = self
	while current != null:
		if current.name == "ArtCastleFloatingWorld" or current.has_method("get_kingdom_exploration_size"):
			return current as Node3D
		current = current.get_parent()
	return null


func _apply_enabled() -> void:
	monitoring = gate_enabled
	$Prompt.text = prompt_text if gate_enabled else "WORLD GATE • COMPLETE THE CURRENT QUEST"
	$Portal.visible = gate_enabled
	$Light.visible = gate_enabled

