extends Area3D

## Standing before the Perfect Blank.
##
## The empty space tells the player nothing is ready and nothing is good
## enough. Pressing interact does not argue with it — it places one unfinished
## picture anyway. That is the answer the story wants.

signal answered()

@export var kingdom_path: NodePath = NodePath("../..")

@onready var _kingdom: Node = get_node_or_null(kingdom_path)

var _player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


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
	if _kingdom.answer_the_perfect_blank():
		answered.emit()


func prompt() -> String:
	if not _player_in_range or _kingdom == null:
		return ""
	if _kingdom.blank_answered():
		return ""
	if not _kingdom.perfect_blank_is_open():
		return ""
	return "Press Q to place one unfinished picture anyway"
