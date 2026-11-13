extends Node3D

## Turns a drawing into a real object the player can use.
##
## This is the story's third step made literal: "The player holds the picture in
## front of the world. The flat picture changes into a real object that can be
## used inside the game." A drawn bridge can be crossed, a drawn door opened, a
## drawn tree climbed.
##
## The drawing is read as a grid of cells. Wherever the player put paint, a
## block of solid world appears. Everything they left blank stays empty, so the
## shape that shows up really is the shape they drew.

signal became_real(cell_count: int)

## How many cells across the drawing is divided into. Higher is more faithful
## and more expensive; 24 keeps a child's drawing recognisable.
@export_range(8, 64, 1) var resolution: int = 24

## How wide the finished object stands in the world, in metres.
@export var world_width: float = 8.0

## How thick the extruded drawing is.
@export var depth: float = 1.2

## A cell counts as drawn when its average alpha passes this. Generous on
## purpose — faint marks should still become real.
@export_range(0.05, 1.0, 0.05) var ink_threshold: float = 0.15

## Adds collision so the player can stand on what they drew.
@export var solid: bool = true

var _cells_made: int = 0


## Builds the object from an image. Returns how many cells became solid, or 0
## if the drawing was empty — which is not a failure, just a blank page.
func build_from_image(image: Image) -> int:
	_clear()

	if image == null or image.is_empty():
		return 0

	# Work on a small copy: one pixel per cell.
	var grid := image.duplicate()
	grid.resize(resolution, resolution, Image.INTERPOLATE_BILINEAR)
	if grid.get_format() != Image.FORMAT_RGBA8:
		grid.convert(Image.FORMAT_RGBA8)

	var cell_size := world_width / float(resolution)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true

	var block := BoxMesh.new()
	block.size = Vector3(cell_size, cell_size, depth)
	multimesh.mesh = block

	# Collect the drawn cells first so the instance count is known.
	var drawn: Array[Dictionary] = []
	for y in resolution:
		for x in resolution:
			var pixel: Color = grid.get_pixel(x, y)
			if pixel.a < ink_threshold:
				continue
			drawn.append({"x": x, "y": y, "colour": pixel})

	if drawn.is_empty():
		return 0

	multimesh.instance_count = drawn.size()

	var half := world_width * 0.5
	for i in drawn.size():
		var cell: Dictionary = drawn[i]
		# Image rows run top to bottom; the world runs bottom to top.
		var cell_position := Vector3(
			(float(cell["x"]) + 0.5) * cell_size - half,
			(float(resolution - cell["y"]) - 0.5) * cell_size,
			0.0
		)
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, cell_position))
		multimesh.set_instance_color(i, cell["colour"])

	var renderer := MultiMeshInstance3D.new()
	renderer.name = "Shape"
	renderer.multimesh = multimesh

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.6
	material.emission_enabled = true
	material.emission_energy_multiplier = 0.25
	renderer.material_override = material
	add_child(renderer)

	if solid:
		_add_collision(drawn, cell_size, half)

	_cells_made = drawn.size()
	became_real.emit(_cells_made)
	return _cells_made


## Gives the drawing a body, so a drawn bridge really can be crossed.
##
## One box per cell would be thousands of shapes; instead each row of touching
## cells becomes a single box, which is far cheaper and just as walkable.
func _add_collision(drawn: Array[Dictionary], cell_size: float, half: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Body"

	# Group the drawn cells by row so runs can be found.
	var rows := {}
	for cell in drawn:
		var y: int = cell["y"]
		if not rows.has(y):
			rows[y] = []
		rows[y].append(int(cell["x"]))

	for y in rows:
		var xs: Array = rows[y]
		xs.sort()

		var run_start: int = xs[0]
		var run_end: int = xs[0]

		for i in range(1, xs.size()):
			if xs[i] == run_end + 1:
				run_end = xs[i]
				continue
			_add_run(body, y, run_start, run_end, cell_size, half)
			run_start = xs[i]
			run_end = xs[i]

		_add_run(body, y, run_start, run_end, cell_size, half)

	add_child(body)


func _add_run(body: StaticBody3D, y: int, from_x: int, to_x: int,
		cell_size: float, half: float) -> void:
	var width := float(to_x - from_x + 1) * cell_size

	var shape := BoxShape3D.new()
	shape.size = Vector3(width, cell_size, depth)

	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(
		(float(from_x) + float(to_x - from_x + 1) * 0.5) * cell_size - half,
		(float(resolution - y) - 0.5) * cell_size,
		0.0
	)
	body.add_child(collider)


## Loads a drawing the player saved earlier and makes it real.
func build_from_file(path: String) -> int:
	var image := Image.new()
	if image.load(path) != OK:
		push_warning("DrawnObject: could not read %s" % path)
		return 0
	return build_from_image(image)


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_cells_made = 0


func cells_made() -> int:
	return _cells_made


func is_real() -> bool:
	return _cells_made > 0
