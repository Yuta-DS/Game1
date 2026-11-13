extends Node3D

## Lays a kingdom's content out across its 3000m island.
##
## A 3000m island is big enough that scattering the story beats across it would
## leave the player walking through empty ground between them. So content is
## grouped into districts: a landing district where the player arrives, a middle
## ring where the work happens, and a far point for the treasure.
##
## Everything is dropped onto the island's real surface, so nothing floats or
## sinks when the terrain changes.

## The island this kingdom stands on.
@export var island_path: NodePath = NodePath("../Island")

## Where each named node should stand: bearing in degrees clockwise from north,
## and distance from the island's centre in metres. Anything not listed is left
## exactly where the scene put it.
##
## Filled in by each kingdom scene.
@export var placements: Dictionary = {}

## How far above the ground each node sits, by name. Defaults to 0.
@export var lift: Dictionary = {}

## Nodes are looked up from here.
@export var content_root: NodePath = NodePath("..")

var _island: Node3D = null


func _ready() -> void:
	_island = get_node_or_null(island_path)
	if _island == null:
		push_warning("IslandDistricts: no island at %s" % island_path)
		return
	# The island builds its surface in its own _ready, so wait a frame.
	await get_tree().process_frame
	place_everything()


## Moves every listed node onto its spot on the island.
func place_everything() -> void:
	var root := get_node_or_null(content_root)
	if root == null or _island == null:
		return

	for node_path in placements:
		var node: Node3D = root.get_node_or_null(NodePath(node_path))
		if node == null:
			continue

		var spot: Vector2 = placements[node_path]
		var ground: Vector3 = _island.point_at(spot.x, spot.y)
		var height: float = lift.get(node_path, 0.0)
		node.position = ground + Vector3(0, height, 0)


## Drops a single node onto the island wherever it already stands, keeping its
## horizontal position. Useful for things placed by hand in the editor.
func settle(node: Node3D, height_above_ground: float = 0.0) -> void:
	if _island == null or node == null:
		return
	var ground: float = _island.height_at(node.position.x, node.position.z)
	node.position.y = ground + height_above_ground


## Where the player should arrive on this island.
func landing_point(bearing: float, distance: float, height: float = 2.0) -> Vector3:
	if _island == null:
		return Vector3(0, height, distance)
	return _island.point_at(bearing, distance) + Vector3(0, height, 0)
