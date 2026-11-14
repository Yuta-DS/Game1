extends Node3D

const Art = preload("res://scripts/heart_melody/heart_art.gd")
## Just beyond the edge of the Heart kingdom's pink floor (whose rim is about
## 40 m past the island's far lobe at the old x = 1400), a short bridge away.
const ISLAND_ORIGIN := Vector3(1250, 45, 8000)
## The bridge begins in the clearing at the heart of the melody maze, on the
## music circle's north stage where its grand piano stood: the route runs from
## the station, through the maze, then over the hedges to the island.
const WALK_START := Vector3(1772.81, 0.22, 8223.87)
const WALK_EXIT_CONTROL := Vector3(1641, 0, 8152)
const WALK_ARRIVE_CONTROL := Vector3(1482, 0, 7988)
## Where the bridge meets the island's edge (local x = -92), through an
## opening in its fence exactly the bridge's width (Art.STATION_OPENING).
const WALK_LAND := Vector3(1342, 45, 7988)
const WALK_SAMPLES := 64
## The climb is finished by this fraction of the way along.
const WALK_CLIMB_END := 0.62
## The round plaza sits wholly inside the island's fence.
const LANDING_CENTRE := Vector3(1332, 45, 7988)
const LANDING_RADIUS := 10.0
const WALK_FINISH := Vector3(1320, 45, 7988)
var player: CharacterBody3D
var island: Node3D
var barrier: StaticBody3D
## The bridge's centre line from the station court to the landing, used by
## Milo's escort and the walking tests.
var walk_points := PackedVector3Array()
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
	for i in WALK_SAMPLES + 1:
		var t := float(i) / WALK_SAMPLES
		var u := 1.0 - t
		var flat := WALK_START * u * u * u + WALK_EXIT_CONTROL * 3.0 * u * u * t 			+ WALK_ARRIVE_CONTROL * 3.0 * u * t * t + WALK_LAND * t * t * t
		flat.y = lerpf(WALK_START.y, WALK_LAND.y, smoothstep(0.0, WALK_CLIMB_END, t))
		walk_points.append(flat)
	# The deck runs on past the island's edge to beneath the plaza, so the
	# round plaza meets the planks with no gap; the rails stop at the fence.
	walk_points.append(LANDING_CENTRE + Vector3.RIGHT * 4.0)
	_build_walk_path(path, walk_points, 2.0, WALK_LAND.distance_to(walk_points[-1]))
	# Each bridge rail turns in to meet the end of the island's fence exactly.
	var side := (walk_points[-2] - walk_points[-3]).cross(Vector3.UP)
	side.y = 0
	side = side.normalized() * 6.0
	for end in Art.station_opening_ends():
		var fence_end := Vector3(ISLAND_ORIGIN.x - end.x, ISLAND_ORIGIN.y, ISLAND_ORIGIN.z - end.z)
		var rail_end := WALK_LAND + (side if side.dot(fence_end - WALK_LAND) > 0 else -side)
		Art.rail(path, rail_end, fence_end)
	# A thin slab lying on the turf over the deck end and the start of the main
	# path (local 0.025-0.07), a few centimetres proud so neither flickers.
	var landing := Art.cone(path, LANDING_CENTRE + Vector3.UP * 0.06, LANDING_RADIUS, LANDING_RADIUS, 0.08, Color("cdb990"), true, 32)
	landing.name = "ArrivalLanding"
	var direction := (walk_points[2] - walk_points[0]).normalized()
	var lock_mesh := Art.box(self, WALK_START + direction * 12 + Vector3.UP * 2.0,
		Vector3(12, 4, 0.5), Color("bc8cab"), true)
	lock_mesh.look_at(to_global(lock_mesh.position + direction))
	barrier = lock_mesh.get_child(0)
	_update_lock()

func _process(_delta: float) -> void:
	var unlocked: bool = get_node("/root/JourneyCampaign").can_enter_kingdom("heart_melody")
	if unlocked != _unlocked:
		_update_lock()

func _update_lock() -> void:
	_unlocked = get_node("/root/JourneyCampaign").can_enter_kingdom("heart_melody")
	barrier.get_parent().visible = not _unlocked
	for shape in barrier.get_children():
		if shape is CollisionShape3D:
			shape.set_deferred("disabled", _unlocked)

# A walk along a polyline: one continuous deck, railed along both sides except
# for the clearances kept open at its ends.
func _build_walk_path(parent: Node3D, points: PackedVector3Array, entry_clearance: float, exit_clearance: float) -> void:
	var sides := PackedVector3Array()
	for i in points.size():
		var ahead := points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
		ahead.y = 0
		sides.append(ahead.normalized().cross(Vector3.UP).normalized())
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lift := Vector3.UP * 0.025
	for i in points.size() - 1:
		var a := points[i] - sides[i] * 6.0
		var b := points[i] + sides[i] * 6.0
		var c := points[i + 1] + sides[i + 1] * 6.0
		var d := points[i + 1] - sides[i + 1] * 6.0
		# Slightly above adjacent floors so overlapping arrival surfaces do not flicker.
		for vertex in [a, c, b, a, d, c]: surface.add_vertex(vertex + lift)
		# The underside closes the deck, so it is solid seen from below too.
		for vertex in [a, b, c, a, c, d]: surface.add_vertex(vertex + lift - Vector3.UP)
		# Fascias give the deck thickness without introducing raised collision lips.
		var edges := [[b, c], [d, a]]
		if i == 0: edges.append([a, b])
		if i == points.size() - 2: edges.append([c, d])
		for edge in edges:
			var top_a: Vector3 = edge[0] + lift
			var top_b: Vector3 = edge[1] + lift
			for vertex in [top_a, top_b, top_b - Vector3.UP, top_a, top_b - Vector3.UP, top_a - Vector3.UP]:
				surface.add_vertex(vertex)
	surface.generate_normals()
	Art.mesh(parent, surface.commit(), Vector3.ZERO, Color("bdac90"), true)
	var length := 0.0
	var distances := PackedFloat32Array([0.0])
	for i in range(1, points.size()):
		length += points[i].distance_to(points[i - 1])
		distances.append(length)
	for sign_value in [-1.0, 1.0]:
		for i in points.size() - 1:
			if distances[i + 1] <= entry_clearance or distances[i] >= length - exit_clearance: continue
			var from := points[i].lerp(points[i + 1], clampf((entry_clearance - distances[i]) / (distances[i + 1] - distances[i]), 0.0, 1.0))
			var to := points[i].lerp(points[i + 1], clampf((length - exit_clearance - distances[i]) / (distances[i + 1] - distances[i]), 0.0, 1.0))
			var side: Vector3 = (sides[i] + sides[i + 1]).normalized() * sign_value * 6.0
			Art.rail(parent, from + side, to + side)
	var flowers := maxi(2, int(length / 9.0))
	for index in flowers + 1:
		var at := length * index / flowers
		if at < entry_clearance or at > length - exit_clearance: continue
		var i := 0
		while i < distances.size() - 2 and distances[i + 1] < at: i += 1
		var point := points[i].lerp(points[i + 1], (at - distances[i]) / maxf(distances[i + 1] - distances[i], 0.001))
		for sign_value in [-1.0, 1.0]:
			Art.flower(parent, point + sides[i] * sign_value * 4.8 + Vector3.UP * 0.025, Color("df9fb7"), 1.1)

