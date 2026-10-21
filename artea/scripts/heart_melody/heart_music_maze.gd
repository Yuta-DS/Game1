extends Node3D

## A connected hedge maze around the existing free-play circle. One broad
## clearing contains the musical fountain; the raised island walk stays clear.
const Art = preload("res://scripts/heart_melody/heart_art.gd")
const HedgeShader = preload("res://shaders/heart_hedge.gdshader")
const SIDE := 23
const CELL := 32.0
const HEIGHT := 6.0
const THICKNESS := 3.0
const FOUNTAIN_CELL := Vector2i(11, 4)
const ENTRANCE := Vector2i(11, 0)
const MUSIC_EXIT := Vector2i(11, 6)
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var passages: Dictionary = {}
var walls: Array[Dictionary] = []
var completed := false
var _player: CharacterBody3D
var _hud: Label

func cell_position(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - SIDE / 2) * CELL, 0, (cell.y - SIDE / 2) * CELL)

func fountain_position() -> Vector3:
	return cell_position(FOUNTAIN_CELL)

func entrance_position() -> Vector3:
	return cell_position(ENTRANCE) - Vector3(0, 0, CELL * 0.75)

func _ready() -> void:
	_generate()
	_build()
	var layer := CanvasLayer.new()
	layer.layer = 32
	add_child(layer)
	_hud = Label.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# Keep the maze objective above the spoken-guidance subtitle panel.
	_hud.offset_top = -305
	_hud.offset_bottom = -265
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_theme_font_size_override("font_size", 24)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 5)
	_hud.hide()
	layer.add_child(_hud)

func _generate() -> void:
	for z in SIDE:
		for x in SIDE:
			var cell := Vector2i(x, z)
			var point := cell_position(cell)
			if Vector2(point.x, point.z).length() > 405.0: continue
			# A full margin around the existing ring, its stages and circulation.
			if Vector2(point.x, point.z).length() < 155.0: continue
			# An open promenade reaches the instruments without requiring the
			# player to solve the maze. Hedges frame it rather than block it.
			if cell.x == 14 and cell.y <= 7: continue
			passages[cell] = []
	var rng := RandomNumberGenerator.new()
	# Chosen so the fountain is a real search from both ways in: 38 cells from
	# the entrance and 28 from the Music Circle exit. The old seed ran almost
	# straight to it (11 and 4).
	rng.seed = 1199
	var stack: Array[Vector2i] = [ENTRANCE]
	var visited := {ENTRANCE: true}
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var choices: Array[Vector2i] = []
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if passages.has(next) and not visited.has(next): choices.append(next)
		if choices.is_empty():
			stack.pop_back()
			continue
		var next := choices[rng.randi_range(0, choices.size() - 1)]
		passages[current].append(next)
		passages[next].append(current)
		visited[next] = true
		stack.append(next)
	# Remove internal hedges from the nine-cell fountain court. The fountain
	# leaves more than a full walking lane on every side.
	for cell in passages:
		if not _clearing(cell): continue
		for direction in DIRECTIONS:
			var next: Vector2i = cell + direction
			if passages.has(next) and _clearing(next) and not passages[cell].has(next):
				passages[cell].append(next)
				passages[next].append(cell)

func _clearing(cell: Vector2i) -> bool:
	return absi(cell.x - FOUNTAIN_CELL.x) <= 1 and absi(cell.y - FOUNTAIN_CELL.y) <= 1

func _build() -> void:
	for cell in passages:
		for direction in DIRECTIONS:
			var next: Vector2i = cell + direction
			if passages[cell].has(next): continue
			if passages.has(next) and (direction == Vector2i.LEFT or direction == Vector2i.UP): continue
			if cell == ENTRANCE and direction == Vector2i.UP: continue
			if cell == MUSIC_EXIT and direction == Vector2i.DOWN: continue
			var point := cell_position(cell) + Vector3(direction.x, 0, direction.y) * CELL * 0.5
			var size := Vector3(THICKNESS, HEIGHT, CELL + THICKNESS) if direction.x != 0 else Vector3(CELL + THICKNESS, HEIGHT, THICKNESS)
			walls.append({"position": point + Vector3.UP * HEIGHT * 0.5, "size": size})
	var hedge_mesh := BoxMesh.new()
	hedge_mesh.size = Vector3.ONE
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = hedge_mesh
	batch.instance_count = walls.size()
	var body := StaticBody3D.new()
	body.name = "SolidHedges"
	add_child(body)
	for index in walls.size():
		var wall: Dictionary = walls[index]
		batch.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(wall.size), wall.position))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall.size
		shape.shape = box
		shape.position = wall.position
		body.add_child(shape)
	var hedges := MultiMeshInstance3D.new()
	hedges.name = "TrimmedGreenHedges"
	hedges.multimesh = batch
	hedges.material_override = _hedge_material(Color("4f823c"))
	add_child(hedges)
	# A lighter top gives the trimmed hedges depth without hundreds of draws.
	var tops := MultiMesh.new()
	tops.transform_format = MultiMesh.TRANSFORM_3D
	tops.mesh = hedge_mesh
	tops.instance_count = walls.size()
	for index in walls.size():
		var wall: Dictionary = walls[index]
		var size: Vector3 = wall.size
		size.y = 0.35
		tops.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(size), wall.position + Vector3.UP * (HEIGHT * 0.5 - 0.15)))
	var caps := MultiMeshInstance3D.new()
	caps.name = "SunlitHedgeTops"
	caps.multimesh = tops
	caps.material_override = _hedge_material(Color("77a958"))
	add_child(caps)
	Art.label(self, "MELODY HEDGE MAZE\nFind the singing fountain\nQ inside the maze: return to entrance", entrance_position() + Vector3.UP * 12, 36)
	Art.label(self, "MUSIC CIRCLE\nFree-play instruments this way", cell_position(MUSIC_EXIT) + Vector3(0, 9, 20), 28)
	Art.label(self, "MUSIC CIRCLE\nOpen promenade · no maze required", Vector3(96, 12, -390), 32)
	Art.label(self, "THE SINGING FOUNTAIN\nYou found the heart of the maze", fountain_position() + Vector3.UP * 23, 32)

func _hedge_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = HedgeShader
	material.set_shader_parameter("hedge_color", color)
	return material

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("Player")
		if not players.is_empty(): _player = players[0] as CharacterBody3D
	if not is_instance_valid(_player): return
	var local := to_local(_player.global_position)
	var cell := Vector2i(roundi(local.x / CELL) + SIDE / 2, roundi(local.z / CELL) + SIDE / 2)
	var inside := passages.has(cell) and absf(local.y) < 12.0
	_hud.visible = inside
	if inside and Vector2(local.x - fountain_position().x, local.z - fountain_position().z).length() < 38.0:
		completed = true
	_hud.text = ("Fountain found! Enjoy its music" if completed else "Melody Maze · Follow the passages to the singing fountain") + " · Q: return to entrance"

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_hud) and _hud.visible and is_instance_valid(_player) and _player.input_enabled and event.is_action_pressed("interact"):
		_player.global_position = to_global(entrance_position() + Vector3.UP * 0.5)
		_player.velocity = Vector3.ZERO
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# The companion also uses Q for conversation. A visible maze-return
	# prompt takes priority, so that emergency exit is always available.
	if event.is_action_pressed("interact"):
		_unhandled_input(event)

func route_to(goal: Vector2i) -> Array[Vector2i]:
	# Used by route QA as well as any future in-game hint display.
	var queue: Array[Vector2i] = [ENTRANCE]
	var previous := {ENTRANCE: ENTRANCE}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == goal: break
		for next in passages[cell]:
			if not previous.has(next):
				previous[next] = cell
				queue.append(next)
	var route: Array[Vector2i] = []
	if not previous.has(goal): return route
	var step := goal
	while step != ENTRANCE:
		route.push_front(step)
		step = previous[step]
	route.push_front(ENTRANCE)
	return route
