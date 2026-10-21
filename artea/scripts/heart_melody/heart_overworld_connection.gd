extends Node3D

const Art = preload("res://scripts/heart_melody/heart_art.gd")
const ISLAND_ORIGIN := Vector3(1400, 45, 8000)
const WALK_START := Vector3(1722.4, 0.20, 7838.7)
const WALK_TURN := Vector3(1504, 45, 7988)
const WALK_FINISH := Vector3(1470, 45, 7988)
var player: CharacterBody3D
var island: Node3D
var barrier: StaticBody3D
var lock_label: Label3D
var _unlocked := false

func _ready() -> void:
	island = load("res://scenes/heart_melody/heart_melody_world.tscn").instantiate()
	island.name = "HeartMelodyIslandOne"
	island.position = ISLAND_ORIGIN
	island.rotation.y = PI
	island.embedded_in_overworld = true
	island.overworld_player = player
	add_child(island)
	var path := Node3D.new()
	path.name = "Station03GardenWalk"
	add_child(path)
	# Top surfaces meet the arrival court and island floor with overlap. A
	# single collision-backed slope has no risers or seams requiring a jump.
	var approach := WALK_START - WALK_TURN
	approach.y = 0
	approach = WALK_TURN + approach.normalized() * 16.0
	_build_walk_segment(path, WALK_START, approach, 10.0, 12.0)
	_build_walk_segment(path, approach, WALK_TURN, 0.0, 12.0)
	_build_walk_segment(path, WALK_TURN, WALK_FINISH, 6.0, 0.0)
	Art.box(path, WALK_TURN - Vector3.UP * 0.5, Vector3(20, 1, 20), Color("bdac90"), true)
	var direction := (WALK_TURN - WALK_START).normalized()
	Art.label(self, "03 · HEART MELODY\nStraight ahead: instruments & singing fountain maze\nRaised flower path: Melody World Garden islands", WALK_START + Vector3(0, 12, 0), 32)
	var lock_mesh := Art.box(self, WALK_START + direction * 12 + Vector3.UP * 2.0,
		Vector3(12, 4, 0.5), Color("bc8cab"), true)
	lock_mesh.look_at(to_global(lock_mesh.position + direction))
	barrier = lock_mesh.get_child(0)
	lock_label = Art.label(self, "HEART MELODY PATH OPEN\nNo other world is required", WALK_START + Vector3(0, 7, -8), 28)
	_update_lock()

func _process(_delta: float) -> void:
	var unlocked: bool = get_node("/root/JourneyCampaign").can_enter_kingdom("heart_melody")
	if unlocked != _unlocked:
		_update_lock()

func _update_lock() -> void:
	_unlocked = get_node("/root/JourneyCampaign").can_enter_kingdom("heart_melody")
	barrier.get_parent().visible = not _unlocked
	lock_label.visible = false
	for shape in barrier.get_children():
		if shape is CollisionShape3D:
			shape.set_deferred("disabled", _unlocked)

func _build_walk_segment(parent: Node3D, start: Vector3, finish: Vector3, entry_clearance: float, exit_clearance: float) -> void:
	var direction := (finish - start).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := start - side * 6.0
	var b := start + side * 6.0
	var c := finish + side * 6.0
	var d := finish - side * 6.0
	# Slightly above adjacent floors so overlapping arrival surfaces do not flicker.
	for vertex in [a, c, b, a, d, c]: surface.add_vertex(vertex + Vector3.UP * 0.025)
	# Fascias give the slope thickness without introducing raised collision lips.
	for edge in [[a, b], [b, c], [c, d], [d, a]]:
		var top_a: Vector3 = edge[0] + Vector3.UP * 0.025
		var top_b: Vector3 = edge[1] + Vector3.UP * 0.025
		for vertex in [top_a, top_b, top_b - Vector3.UP, top_a, top_b - Vector3.UP, top_a - Vector3.UP]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	Art.mesh(parent, surface.commit(), Vector3.ZERO, Color("bdac90"), true)
	var rail_start := start + direction * entry_clearance
	var rail_finish := finish - direction * exit_clearance
	for sign_value in [-1.0, 1.0]:
		var rail := Art.box(parent, (rail_start + rail_finish) * 0.5 + side * sign_value * 6.0 + Vector3.UP,
			Vector3(0.4, 1.6, rail_start.distance_to(rail_finish)), Color("816e5a"), true)
		rail.look_at(to_global(rail_finish + side * sign_value * 6.0 + Vector3.UP))
		for index in 7:
			var point := rail_start.lerp(rail_finish, float(index) / 6.0)
			Art.flower(parent, point + side * sign_value * 4.8 + Vector3.UP * 0.025, Color("df9fb7"), 1.1)
