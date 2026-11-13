extends Node3D

## Lets the player pick up a Thought Spark, carry it to the gates, and set it
## down again — the hands of Mind Spark Kingdom.
##
## Reuses the project's existing "interact" action (Q), the same key every NPC
## already uses, so the kingdom does not teach a new control.
##
## Nothing here can fail. A thought that is not ready simply stays as it is,
## and the player is told what it still needs rather than being refused.

signal picked_up(spark: Node3D)
signal put_down(spark: Node3D)
signal not_ready_yet(spark: Node3D, gates_left: int)

## How close the player must be to pick a thought up, in metres.
@export var reach: float = 3.5

## Where a carried thought floats relative to the player.
@export var carry_offset: Vector3 = Vector3(0, 2.2, 0)

## How many gates a thought needs before it can become kinder. Kept in step
## with the kingdom's own setting.
@export var gates_per_thought: int = 3

@export var player_path: NodePath = NodePath("../NewPlayer")
@export var sparks_path: NodePath = NodePath("../ThoughtSparks")

var carried: Node3D = null

@onready var _player: Node3D = get_node_or_null(player_path)
@onready var _sparks: Node3D = get_node_or_null(sparks_path)


func _ready() -> void:
	if _player == null:
		push_warning("ThoughtCarrier: no player at %s" % player_path)


func _process(_delta: float) -> void:
	if _player == null:
		return

	# A carried thought follows the player.
	if carried:
		carried.global_position = _player.global_position + carry_offset

	if not Input.is_action_just_pressed("interact"):
		return
	if _player.get("interacting"):
		return

	if carried:
		_put_down()
	else:
		_pick_up_nearest()


func _pick_up_nearest() -> void:
	var spark := nearest_spark()
	if spark == null:
		return
	carried = spark
	spark.pick_up()
	picked_up.emit(spark)


## Setting a thought down is also how the player finishes it: if it has been
## through every gate, it becomes the kinder thought here.
func _put_down() -> void:
	var spark: Node = carried
	carried = null
	spark.release()

	if spark.can_transform(gates_per_thought):
		spark.become_kinder()
	else:
		not_ready_yet.emit(spark, gates_per_thought - spark.gates_passed.size())

	put_down.emit(spark)


## The closest thought within reach that has not already been transformed.
func nearest_spark() -> Node3D:
	if _sparks == null or _player == null:
		return null

	var best: Node3D = null
	var best_distance := reach

	for spark in _sparks.get_children():
		if not spark is Node3D or not spark.has_method("pick_up"):
			continue
		if spark.is_transformed:
			continue
		var distance: float = _player.global_position.distance_to(spark.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = spark

	return best


## A short prompt the HUD can show, in the player's own terms.
func prompt() -> String:
	if carried:
		var left: int = gates_per_thought - carried.gates_passed.size()
		if left > 0:
			return "Walk this thought through %d more question%s" % [left, "" if left == 1 else "s"]
		return "Press Q to let this thought become kinder"
	if nearest_spark():
		return "Press Q to pick up this thought"
	return ""


## Puts a carried thought down without transforming it, for scene changes.
func drop_everything() -> void:
	if carried:
		carried.release()
		carried = null
