# Flat coloured stone strips linking the village core to the three new
# kingdom-adjacent districts (Mind Spark, Creator's Light, Heart Melody).
#
# Built at runtime, same convention as hub_magitech.gd and aether_atlas.gd:
# nothing is authored into New_Hub_World.tscn, so the path network can be
# retuned or removed by deleting one node. Purely decorative ground
# dressing — no collision, so it never interferes with player movement.
extends Node3D

const PATH_WIDTH := 3.0
const PATH_HEIGHT := 0.04  # lifted a hair above terrain to avoid z-fighting

# Each route is a polyline from the village core toward a district anchor.
# Points are hand-placed along existing flat ground (Y 19-24 band) rather
# than terrain-sampled, matching how the buildings in this same infill pass
# were placed.
const ROUTES := [
	{
		"name": "MindSpark",
		"color": Color(0.31, 0.53, 0.86, 0.85),
		"points": [
			Vector3(107.4, 19.2, 12.3),
			Vector3(104, 19.5, -30),
			Vector3(96, 20.0, -60),
			Vector3(96, 20.3, -80),
		],
	},
	{
		"name": "CreatorsLight",
		"color": Color(0.66, 0.33, 0.79, 0.85),
		"points": [
			Vector3(60.0, 21.0, 16.9),
			Vector3(55, 22.1, 32),
			Vector3(48, 23.5, 44),
			Vector3(46, 23.9, 52),
		],
	},
	{
		"name": "HeartMelody",
		"color": Color(0.95, 0.55, 0.30, 0.85),
		"points": [
			Vector3(55.0, 22.6, 55.3),
			Vector3(65, 22.2, 55),
			Vector3(75, 21.5, 55),
			Vector3(82, 21.8, 55),
		],
	},
]


func _ready() -> void:
	for route in ROUTES:
		_build_route(route)


func _build_route(route: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Path_%s" % route["name"]
	add_child(holder)

	var material := StandardMaterial3D.new()
	material.albedo_color = route["color"]
	material.roughness = 0.95
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var points: Array = route["points"]
	for i in range(points.size() - 1):
		var from: Vector3 = points[i]
		var to: Vector3 = points[i + 1]
		var segment := MeshInstance3D.new()

		var mesh := BoxMesh.new()
		mesh.size = Vector3(PATH_WIDTH, PATH_HEIGHT, from.distance_to(to))
		segment.mesh = mesh
		segment.material_override = material

		segment.position = (from + to) * 0.5
		holder.add_child(segment)
		segment.look_at(to, Vector3.UP)
		segment.rotate_object_local(Vector3.RIGHT, PI * 0.5)
