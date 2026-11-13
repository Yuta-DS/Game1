@tool
extends Node3D

## Builds a 3000m island floating in the castle galaxy.
##
## The three kingdoms are islands inside the ARTÉA Castle's living universe, so
## each one is an edged landmass surrounded by starfield rather than a plane
## that runs on forever. The shape is generated rather than sculpted by hand so
## all three read as siblings.
##
## Content sits in districts near the landing point. The far reaches are for
## looking at, not for walking across to reach the next story beat.

signal island_ready(size: float)

## How wide the island is, corner to corner, in metres.
@export var island_size: float = 3000.0:
	set(value):
		island_size = value
		_rebuild()

## Cells across the island mesh. 60 keeps a 3000m island at 50m per cell, which
## is enough for rolling ground without a heavy mesh.
@export_range(16, 160, 1) var grid: int = 60:
	set(value):
		grid = value
		_rebuild()

## How high the hills rise.
@export var relief: float = 90.0:
	set(value):
		relief = value
		_rebuild()

## How far in from the edge the ground starts falling away into the galaxy.
@export_range(0.05, 0.5, 0.01) var shore_falloff: float = 0.22:
	set(value):
		shore_falloff = value
		_rebuild()

## Changes the hills without changing the island's outline.
@export var terrain_seed: int = 1:
	set(value):
		terrain_seed = value
		_rebuild()

@export var ground_colour: Color = Color(0.18, 0.2, 0.3):
	set(value):
		ground_colour = value
		_rebuild()

## Adds a collider so the player can walk the island. Off in the editor, since
## a 60x60 trimesh is slow to rebuild while tweaking.
@export var walkable: bool = true

var _mesh: MeshInstance3D = null
var _body: StaticBody3D = null
var _noise: FastNoiseLite = null


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return

	_clear()

	_noise = FastNoiseLite.new()
	_noise.seed = terrain_seed
	_noise.frequency = 0.9 / island_size
	_noise.fractal_octaves = 4

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half := island_size * 0.5
	var step := island_size / float(grid)

	for z in grid:
		for x in grid:
			var corners := [
				Vector2(x, z), Vector2(x + 1, z),
				Vector2(x + 1, z + 1), Vector2(x, z + 1),
			]
			var points: Array[Vector3] = []
			for corner in corners:
				var world_x: float = corner.x * step - half
				var world_z: float = corner.y * step - half
				points.append(Vector3(world_x, height_at(world_x, world_z), world_z))

			# Two triangles per cell, wound so the surface faces up.
			_add_triangle(surface, points[0], points[2], points[1])
			_add_triangle(surface, points[0], points[3], points[2])

	surface.generate_normals()

	var material := StandardMaterial3D.new()
	material.albedo_color = ground_colour
	material.roughness = 0.95
	material.vertex_color_use_as_albedo = true
	surface.set_material(material)

	_mesh = MeshInstance3D.new()
	_mesh.name = "Surface"
	_mesh.mesh = surface.commit()
	add_child(_mesh)

	if walkable and not Engine.is_editor_hint():
		_body = StaticBody3D.new()
		_body.name = "Body"
		var collider := CollisionShape3D.new()
		collider.shape = _mesh.mesh.create_trimesh_shape()
		_body.add_child(collider)
		add_child(_body)

	island_ready.emit(island_size)


## The island's surface height at a world position.
##
## Hills come from noise, then everything is pulled down towards the rim so the
## island has a real edge and the galaxy shows underneath.
func height_at(world_x: float, world_z: float) -> float:
	if _noise == null:
		return 0.0

	var half := island_size * 0.5
	var hills := _noise.get_noise_2d(world_x, world_z) * relief

	# 0 at the centre, 1 at the rim.
	var from_centre := Vector2(world_x, world_z).length() / half
	var shore_starts := 1.0 - shore_falloff

	# The island domes gently upward towards the middle, so the player stands on
	# high ground and can see out over the rim into the galaxy rather than being
	# walled in by their own horizon.
	var dome := pow(clampf(1.0 - from_centre, 0.0, 1.0), 1.5) * relief * 2.4

	# The districts sit in the middle of the island, so the hills there are
	# smoothed away. The player gets open ground to work on and a clear line of
	# sight out to the rim and the galaxy beyond.
	var district_radius := 700.0 / half
	if from_centre < district_radius:
		var settle: float = smoothstep(0.0, 1.0, from_centre / district_radius)
		hills *= 0.15 + 0.85 * settle

	# Beyond the districts the land settles again, so no far ridge rises above
	# the player's eyeline and hides the galaxy.
	hills *= 1.0 - smoothstep(district_radius, 1.0, from_centre) * 0.75

	if from_centre <= shore_starts:
		return hills + dome

	var over := (from_centre - shore_starts) / shore_falloff
	# Past the rim the ground drops away into the stars.
	return lerp(hills + dome, -relief * 5.0, clampf(over, 0.0, 1.0) ** 1.3)


## True when a position is on solid ground rather than out over the edge.
func is_on_island(world_x: float, world_z: float) -> bool:
	return height_at(world_x, world_z) > -relief


## A place to stand at a given bearing and distance from the island's centre,
## already sitting on the ground. Districts use this to lay themselves out.
func point_at(bearing_degrees: float, distance: float) -> Vector3:
	var angle := deg_to_rad(bearing_degrees)
	var x := sin(angle) * distance
	var z := -cos(angle) * distance
	return Vector3(x, height_at(x, z), z)


func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for point in [a, b, c]:
		surface.set_color(_colour_at(point))
		surface.add_vertex(point)


## Higher ground catches more light, and the shore fades towards the galaxy, so
## the island reads as a place rather than a flat sheet.
func _colour_at(point: Vector3) -> Color:
	var high := clampf(inverse_lerp(-relief, relief, point.y), 0.0, 1.0)
	var lit := ground_colour.lightened(high * 0.28)
	if point.y < -relief * 0.5:
		lit = lit.darkened(0.55)
	return lit


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_mesh = null
	_body = null
