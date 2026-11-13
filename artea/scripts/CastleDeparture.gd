extends Node3D

## The three doorways out of the ARTÉA Castle.
##
## The game begins here. The story opens with the castle's light sleeping and
## the paths between the Mind, Heart and Creative worlds no longer connected,
## so the player starts inside the castle and the ways out open as the journey
## grows.
##
## Each doorway leads to one 3000m island. A sleeping doorway is dim and says
## which world is waiting, rather than refusing the player outright.

signal doorway_used(station_id: String)
signal doorway_sleeping(station_id: String)

@export var doorways: Array[NodePath] = []

var _journey: Node = null


func _ready() -> void:
	_journey = get_node_or_null("/root/JourneyState")

	for path in doorways:
		var door := get_node_or_null(path)
		if door == null:
			continue
		if door.has_signal("used"):
			door.used.connect(_on_doorway_used)
		if door.has_signal("refused"):
			door.refused.connect(_on_doorway_sleeping)

	if _journey and _journey.has_signal("station_unlocked"):
		_journey.station_unlocked.connect(_on_station_unlocked)

	_refresh()


func _on_station_unlocked(_station_id: String) -> void:
	_refresh()


## Lets every doorway restate whether its world is awake.
func _refresh() -> void:
	for path in doorways:
		var door := get_node_or_null(path)
		if door and door.has_method("refresh"):
			door.refresh()


func _on_doorway_used(station_id: String) -> void:
	doorway_used.emit(station_id)


func _on_doorway_sleeping(station_id: String) -> void:
	doorway_sleeping.emit(station_id)


## The world the story would like the player to visit next, for the castle to
## point at gently.
func next_world() -> String:
	return _journey.next_story_station() if _journey else ""
