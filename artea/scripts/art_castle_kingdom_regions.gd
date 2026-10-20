extends Node3D

# Heart Melody and Creator's Light are one station platform each. Mind Spark
# lives in World One; its old unreachable 3 km region was removed.

const GALLERY_CONNECTION_Z := 820.0
const FLOATING_STATIONS := {
	# Mind has no floating station of its own any more: this is the park-edge
	# Mind station's landing on the Mind district island, less the respawn
	# offset added in get_safe_respawn(), so falls near World One recover there.
	"mind": Vector3(-792, 2, 1640),
	"heart": Vector3(1700, 35, 7640),
	"creator": Vector3(5300, 35, 3940),
}

# Heart and Creator arrive on one platform each instead of a 3 km kingdom:
# three times the fountain island's 155 m so they read from a distance.
const STATION_PLATFORM_RADIUS := 465.0
const STATION_PLATFORM_TITLES := {"heart": "HEART MELODY", "creator": "CREATOR'S LIGHT"}

const STORY_ROUTES := {
	"heart": [
		{"id": "arrival", "title": "HEART MELODY SKYBRIDGE LANDING", "position": Vector3(1722.4, 2, 7838.7)},
		{"id": "joy", "title": "JOY GARDEN", "position": Vector3(-720, 16, 6990)},
		{"id": "frustration", "title": "FRUSTRATION DRUM TERRACES", "position": Vector3(-180, 30, 7290)},
		{"id": "sadness", "title": "SADNESS RAIN BOAT", "position": Vector3(420, 44, 7140)},
		{"id": "fear", "title": "FEAR WARNING BELLS", "position": Vector3(900, 60, 7540)},
		{"id": "peace", "title": "PEACE FLOWER MEADOW", "position": Vector3(520, 78, 8140)},
		{"id": "hope", "title": "HOPE MORNING STAGE", "position": Vector3(900, 96, 8490)},
		{"id": "finale", "title": "PERSONAL SONG • HARMONY JEWEL", "position": Vector3(300, 122, 8840)},
	],
	"creator": [
		{"id": "arrival", "title": "CREATOR'S LIGHT SKYBRIDGE LANDING", "position": Vector3(5100, 2, 3940)},
		{"id": "glass_seeds", "title": "GLASS SEED LABORATORY", "position": Vector3(2750, 18, 4490)},
		{"id": "drawing", "title": "DRAWING STUDIO", "position": Vector3(3250, 32, 4690)},
		{"id": "dream_door", "title": "DREAM DOOR WORKSHOP", "position": Vector3(3650, 48, 4190)},
		{"id": "rest_canvas", "title": "RESTING PLACE CANVAS", "position": Vector3(4200, 62, 4390)},
		{"id": "real_garden", "title": "ART-BECOMES-REAL GARDEN", "position": Vector3(4550, 82, 3840)},
		{"id": "perfect_blank", "title": "THE PERFECT BLANK", "position": Vector3(4300, 102, 3160)},
		{"id": "finale", "title": "URIEL • CREATOR'S LIGHT", "position": Vector3(4850, 126, 2740)},
	],
}

var _materials: Dictionary = {}


func _ready() -> void:
	_build_materials()
	# Paving in each kingdom's station colours (STATION_PALETTES in the
	# railway), deeper here because the open island floor is in full sun.
	_build_station_platform("heart", [Color("b8607f"), Color("a85272"), Color("5e2440")], _materials.pink)
	_build_station_platform("creator", [Color("c98f3c"), Color("b87d2e"), Color("5e3a12")], _materials.gold)


func get_kingdom_size(_kingdom_id: String = "") -> Vector2:
	return Vector2.ONE * STATION_PLATFORM_RADIUS * 2.0


func get_kingdom_centers() -> Dictionary:
	return {"heart": _platform_center("heart"), "creator": _platform_center("creator")}


## Out from the station along its access bridge; the bridge lands 15 m
## inside the rim.
func _platform_center(kingdom_id: String) -> Vector3:
	var landing: Vector3 = STORY_ROUTES[kingdom_id][0].position
	var station: Vector3 = FLOATING_STATIONS[kingdom_id]
	var away := Vector3(landing.x - station.x, 0.0, landing.z - station.z).normalized()
	return Vector3(landing.x, 0.0, landing.z) + away * (STATION_PLATFORM_RADIUS - 15.0)


func get_story_route(kingdom_id: String) -> Array:
	return (STORY_ROUTES.get(kingdom_id, []) as Array).duplicate(true)


func get_station_positions() -> Dictionary:
	return FLOATING_STATIONS.duplicate(true)


func get_safe_respawn(near_position: Vector3) -> Vector3:
	var candidates := get_station_positions()
	var best: Vector3 = Vector3(0, 5, GALLERY_CONNECTION_Z)
	var best_distance := INF
	for station_position in candidates.values():
		var horizontal := Vector2(near_position.x, near_position.z).distance_to(
			Vector2(station_position.x, station_position.z))
		if horizontal < best_distance:
			best_distance = horizontal
			# x=18 is occupied by the Crown Line platform guard. Keep recovery
			# inside the 38 m platform but clear of rails and boarding geometry.
			best = station_position + Vector3(25, 4, 0)
	return best


func _build_materials() -> void:
	_materials.gold = _material(Color("f0c35e"), 0.42, Color("f1ac32"), 1.25)
	_materials.pink = _material(Color("ed83c1"), 0.55, Color("e45da8"), 0.7)


func _paving(colors: Array, tile: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/station_surface.gdshader")
	material.set_shader_parameter("pattern", 0)
	material.set_shader_parameter("base_color", colors[0])
	material.set_shader_parameter("alt_color", colors[1])
	material.set_shader_parameter("line_color", colors[2])
	material.set_shader_parameter("tile_size", tile)
	material.set_shader_parameter("roughness_value", 0.86)
	return material


## `paving` is [light, dark, grout].
func _build_station_platform(kingdom_id: String, paving: Array, accent: Material) -> void:
	var deck_color: Color = paving[0]
	var platform := Node3D.new()
	platform.name = "%sKingdomPlatform" % kingdom_id.to_pascal_case()
	add_child(platform)
	var center := _platform_center(kingdom_id)
	platform.set_meta("centrepiece_position", center)
	var deck_material := _paving(paving, 1.6)
	# The centrepiece space is paved larger and lighter so it reads as a plaza.
	var plaza_material := _paving([deck_color.lightened(0.15), deck_color.lightened(0.05),
		paving[2]], 3.2)
	var r := STATION_PLATFORM_RADIUS
	# Stacked a few cm apart so no two tops are coplanar.
	_add_cylinder(platform, "WalkableDeck", center + Vector3(0, -1.5, 0), r, 3.0, accent, true, 64)
	_add_cylinder(platform, "DeckField", center + Vector3(0, 0.02, 0), r - 8.0, 0.04, deck_material, false, 64)
	_add_cylinder(platform, "CentrepieceInlay", center + Vector3(0, 0.06, 0), 126.0, 0.04, accent, false, 64)
	_add_cylinder(platform, "CentrepieceSpace", center + Vector3(0, 0.1, 0), 118.0, 0.04, plaza_material, false, 64)
	var underside := MeshInstance3D.new()
	underside.name = "FloatingUnderside"
	var mesh := CylinderMesh.new()
	mesh.top_radius = r * 0.94
	mesh.bottom_radius = r * 0.2
	mesh.height = 120.0
	mesh.radial_segments = 48
	underside.mesh = mesh
	underside.position = center + Vector3(0, -62.0, 0)
	underside.material_override = _material(deck_color.darkened(0.3), 0.92)
	platform.add_child(underside)
	_add_label(platform, str(STATION_PLATFORM_TITLES[kingdom_id]), center + Vector3(0, 160, 0),
		_kingdom_color(kingdom_id), 160)


func _add_label(parent: Node3D, text: String, position_value: Vector3, color: Color, font_size: int) -> void:
	var label := Label3D.new()
	label.name = "%sLabel" % text.get_slice("•", 0).to_pascal_case().replace("'", "")
	label.text = text
	label.position = position_value
	label.font_size = font_size
	label.outline_size = 10
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	parent.add_child(label)


func _add_cylinder(parent: Node3D, node_name: String, position_value: Vector3, radius: float,
		height: float, material: Material, collision: bool, segments: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = material
	parent.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		var shape_node := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		shape_node.shape = shape
		body.add_child(shape_node)
		body.position = position_value
		parent.add_child(body)
	return instance


func _kingdom_color(kingdom_id: String) -> Color:
	if kingdom_id == "heart": return Color("ffc8e8")
	return Color("ffe49a")


func _material(color: Color, roughness: float, emission: Color = Color.BLACK,
		energy: float = 0.0, transparent: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if energy > 0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
