# Third-person spring-arm camera.
#
# Yaw turns freely through a full circle; pitch is limited only near the
# poles, where looking exactly straight up or down leaves the arm's basis
# degenerate and the view snaps.
extends Node3D

# Looked up by path in the hub, but this scene is also instanced in worlds
# whose root is not HubWorld. Resolved defensively so the camera never hard
# -fails on a scene that happens to be arranged differently.
@onready var player: Node = _find_player()

# Kept as exports so a scene can still narrow the range, but they now default
# to the full usable sphere. The hub previously authored -0.8/-0.1, roughly
# -46 to -6 degrees, which pinned the view downward — the sky islands were
# literally unlookable-at.
@export var minLimitX: float = -1.45   # ~-83 degrees, near straight down
@export var maxLimitX: float = 1.45    # ~+83 degrees, near straight up
@export var mouseAcceleration := 0.005

func _input(event: InputEvent) -> void:
	# The player may be absent (or still loading) in non-hub scenes; only
	# block input when there is a player and it is mid-interaction.
	if player != null and "interacting" in player and player.interacting:
		return
	if event is InputEventMouseMotion:
		rotateFromVector(event.relative * mouseAcceleration)

func rotateFromVector(v: Vector2):
	if v.length() == 0: return
	# Wrapped rather than accumulated: yaw turns through a full circle in
	# both directions without drifting into large float values over a session.
	rotation.y = wrapf(rotation.y - v.x, -PI, PI)
	rotation.x = clamp(rotation.x - v.y, minLimitX, maxLimitX)


func _find_player() -> Node:
	var byGroup := get_tree().get_nodes_in_group("player")
	if byGroup.size() > 0:
		return byGroup[0]
	# The camera hangs off the player in NewPlayer.tscn, so walking up is a
	# reliable fallback when the group is missing.
	var node := get_parent()
	while node != null:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null 
