extends Area3D

## The storm at the centre of Mind Spark, and the star that grows once it is
## gentle.
##
## The story is firm that the player does not fight the storm: they slow it
## down, look at one thought at a time, and find a hopeful path through it. So
## pressing interact here does not attack anything — it takes one more honest
## look.

signal looked_at_one_thought(thoughts_left: int)
signal star_taken()

@export var kingdom_path: NodePath = NodePath("..")
@export var player_path: NodePath = NodePath("../NewPlayer")

@onready var _kingdom: Node = get_node_or_null(kingdom_path)
@onready var _player: Node3D = get_node_or_null(player_path)

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
	if _player and _player.get("interacting"):
		return

	# Once the storm is gentle, the same key takes the star.
	if _kingdom.storm_is_calm():
		if _kingdom.take_the_star():
			star_taken.emit()
		return

	if _kingdom.slow_the_storm():
		looked_at_one_thought.emit(_kingdom.storm_thoughts_left())


func prompt() -> String:
	if not _player_in_range or _kingdom == null:
		return ""
	if not _kingdom.forest_is_lit():
		return "The storm is too loud to approach yet"
	if _kingdom.storm_is_calm():
		return "Press Q to take the Star of Wisdom" if not _kingdom.treasure_taken() else ""
	return "Press Q to look at one thought inside the storm"
