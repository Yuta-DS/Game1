extends Area3D

## The way back, standing on every island.
##
## The player arrives from the ARTÉA Castle and can always return to it. The
## gateway is never locked — the story never traps anyone in a world, and a
## player who wants to leave a kingdom and come back later is allowed to.

signal returning_to_castle()

## Where this gateway sends the player.
@export_file("*.tscn") var destination: String = "res://scenes/crown_chamber.tscn"

@export var label_text: String = "Back to the ARTÉA Castle"

@onready var _light: OmniLight3D = get_node_or_null("Glow")
@onready var _label: Label3D = get_node_or_null("Label")

var _player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _label:
		_label.text = label_text


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = true
	_brighten(true)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = false
	_brighten(false)


func _process(_delta: float) -> void:
	if not _player_in_range:
		return
	if not Input.is_action_just_pressed("interact"):
		return
	returning_to_castle.emit()
	get_tree().change_scene_to_file(destination)


func _brighten(near: bool) -> void:
	if _light == null:
		return
	var tween := create_tween()
	tween.tween_property(_light, "light_energy", 5.0 if near else 2.0, 0.4)


func prompt() -> String:
	return "Press Q to travel back to the castle" if _player_in_range else ""
