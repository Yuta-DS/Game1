extends Area3D

## The moment a kingdom's treasure is taken.
##
## Shared by every world: it stands in front of the treasure, waits until the
## kingdom says the treasure has grown, and then lets the player take it with
## the same interact key used everywhere else.

signal taken()

@export var kingdom_path: NodePath = NodePath("../..")

## The kingdom method that hands the treasure over. Each world names its own.
@export var take_method: String = "take_the_jewel"

## The kingdom method that says whether the treasure is ready to be taken.
@export var ready_method: String = "valley_is_singing"

## What the prompt calls the treasure.
@export var treasure_name: String = "the Harmony Jewel"

@onready var _kingdom: Node = get_node_or_null(kingdom_path)

var _player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _kingdom == null:
		push_warning("TreasurePickup: no kingdom at %s" % kingdom_path)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _process(_delta: float) -> void:
	if not _player_in_range or _kingdom == null:
		return
	if not Input.is_action_just_pressed("interact"):
		return
	if not _is_ready():
		return
	if _kingdom.call(take_method):
		taken.emit()


func _is_ready() -> bool:
	if _kingdom == null or not _kingdom.has_method(ready_method):
		return false
	return bool(_kingdom.call(ready_method))


func prompt() -> String:
	if not _player_in_range or not _is_ready():
		return ""
	return "Press Q to take %s" % treasure_name
