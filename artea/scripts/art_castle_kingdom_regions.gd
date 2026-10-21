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

# Same idle-bob convention as hub_sky_isles.gd's floating islands: a time
# accumulator plus sin() against a stored base Y, so each part drifts
# without permanently displacing its authored position. Phases borrowed from
# hub_sky_isles.gd's BOB_PHASES so the frame/canvas/brush never bob in sync -
# a synchronised group reads as one object, not three independent parts.
const CREATOR_CENTREPIECE_BOB_AMPLITUDE := 2.0
const CREATOR_CENTREPIECE_BOB_PERIOD := 9.0
const CREATOR_CENTREPIECE_BOB_PHASES := [0.0, 2.1, 4.3]
var _bob_time := 0.0
var _creator_bob_parts: Array[Dictionary] = []


func _ready() -> void:
	_build_materials()
	# Paving in each kingdom's station colours (STATION_PALETTES in the
	# railway), deeper here because the open island floor is in full sun.
	_build_station_platform("heart", [Color("b8607f"), Color("a85272"), Color("5e2440")], _materials.pink)
	_build_station_platform("creator", [Color("c98f3c"), Color("b87d2e"), Color("5e3a12")], _materials.gold)


func _process(delta: float) -> void:
	if _creator_bob_parts.is_empty():
		return
	_bob_time += delta
	for part in _creator_bob_parts:
		var node: Node3D = part.node
		node.position.y = part.base_y + sin(
			(_bob_time / CREATOR_CENTREPIECE_BOB_PERIOD) * TAU + part.phase) \
			* CREATOR_CENTREPIECE_BOB_AMPLITUDE


## Registers a node for the idle bob, remembering its authored Y so repeated
## calls (across reloads) never compound an offset onto an offset.
func _register_creator_bob(node: Node3D) -> void:
	var phase: float = CREATOR_CENTREPIECE_BOB_PHASES[_creator_bob_parts.size() % CREATOR_CENTREPIECE_BOB_PHASES.size()]
	_creator_bob_parts.append({"node": node, "base_y": node.position.y, "phase": phase})


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
	_materials.ivory = _material(Color("e8e5ef"), 0.84)
	_materials.shadow = _material(Color("8587a2"), 0.94)
	_materials.canvas = _material(Color("fff9e8"), 0.96)
	_materials.wood = _material(Color("815b3d"), 0.90)
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
	if kingdom_id == "heart":
		_build_heart_court(platform, center, r - 8.0, [deck_material, accent, plaza_material])
		var maze := Node3D.new()
		maze.name = "HeartMusicMaze"
		maze.position = center + Vector3.UP * 0.20
		maze.set_script(preload("res://scripts/heart_melody/heart_music_maze.gd"))
		platform.add_child(maze)
		var garden := Node3D.new()
		garden.name = "HeartArrivalGarden"
		garden.set_script(preload("res://scripts/heart_melody/heart_arrival_garden.gd"))
		garden.fountain_position = center + maze.fountain_position() + Vector3.UP * 0.20
		platform.add_child(garden)
		var music_circle := Node3D.new()
		music_circle.name = "HeartMusicCircle"
		music_circle.position = center + Vector3.UP * 0.20
		music_circle.set_script(preload("res://scripts/heart_melody/heart_music_circle.gd"))
		platform.add_child(music_circle)
	else:
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
	if kingdom_id == "creator":
		_build_creator_centrepiece(platform, center)


func _build_heart_court(parent: Node3D, center: Vector3, radius: float, materials: Array) -> void:
	# Adjacent annuli share exact boundaries. Unlike stacked disks, there are
	# no coplanar tops for the long-range Web camera's depth buffer to fight over.
	var mesh := ArrayMesh.new()
	var radii := [radius, 126.0, 118.0, 0.0]
	for ring in 3:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in 96:
			var a0 := float(index) * TAU / 96.0
			var a1 := float(index + 1) * TAU / 96.0
			var outer0 := Vector3(cos(a0) * radii[ring], 0.20, sin(a0) * radii[ring])
			var outer1 := Vector3(cos(a1) * radii[ring], 0.20, sin(a1) * radii[ring])
			var inner0 := Vector3(cos(a0) * radii[ring + 1], 0.20, sin(a0) * radii[ring + 1])
			var inner1 := Vector3(cos(a1) * radii[ring + 1], 0.20, sin(a1) * radii[ring + 1])
			for point in [outer0, outer1, inner1, outer0, inner1, inner0]:
				surface.add_vertex(point)
		surface.generate_normals()
		surface.set_material(materials[ring])
		surface.commit(mesh)
	var court := MeshInstance3D.new()
	court.name = "ContinuousHeartPaving"
	court.mesh = mesh
	court.position = center
	parent.add_child(court)
	court.create_trimesh_collision()


## The plaza _build_station_platform reserves (CentrepieceSpace, 118 m
## radius) was never filled in. A single oversized easel and canvas,
## hovering clear of its dais — this kingdom's own drawing mechanic (see
## art_castle_floating_world.gd's player-painted easels) made into the one
## landmark you see on arrival, rather than a new symbol.
func _build_creator_centrepiece(parent: Node3D, center: Vector3) -> void:
	_add_cylinder(parent, "CentrepieceDais", center + Vector3(0, 4, 0), 50.0, 8.0,
		_materials.ivory, false, 24)
	# A gold glow pooling under the easel reads as "lit from within" rather
	# than just "gold-coloured", and sells the hover gap above the dais.
	_add_cylinder(parent, "CentrepieceGlow", center + Vector3(0, 9, 0), 42.0, 0.3,
		_material(Color("f1ac32"), 0.3, Color("f1ac32"), 1.4), false, 24)

	# _platform_center's own "away" vector (station -> landing -> centre) is
	# the line the player actually walks in on. For "creator" that line runs
	# along X, not Z. Face the canvas's local -Z (its painted side) straight
	# down +away, back at the station itself, then add a slight backward
	# lean (local +X) so the whole easel reads as propped up, not bolt
	# upright.
	var landing: Vector3 = STORY_ROUTES["creator"][0].position
	var station: Vector3 = FLOATING_STATIONS["creator"]
	var away := Vector3(landing.x - station.x, 0.0, landing.z - station.z).normalized()
	var easel := Node3D.new()
	easel.name = "CreatorCentrepieceEasel"
	easel.position = center + Vector3(0, 30, 0)
	easel.rotation.y = atan2(away.x, away.z)
	easel.rotation.x = deg_to_rad(20.0)
	# A little further from the arrival line than the first pass, so players
	# meet the dais before they meet the easel itself.
	easel.position += easel.transform.basis.z * 15.0
	parent.add_child(easel)

	# Easel frame, canvas, and brush/paint-trails are three separate groups
	# (not easel itself) so each can bob on its own phase instead of
	# floating as one rigid unit.
	var easel_frame := Node3D.new()
	easel_frame.name = "CreatorCentrepieceEaselFrame"
	easel.add_child(easel_frame)
	_register_creator_bob(easel_frame)

	# Local -Z faces the station; the rear leg sits on the far local +Z side,
	# behind the canvas, where it stays hidden from that approach. Easel
	# sized at 80% of the first pass.
	for side in [-1.0, 1.0]:
		var leg := _add_box(easel_frame, "CentrepieceEaselLeg", Vector3(side * 22, 40, -5),
			Vector3(7, 80, 7), _materials.wood)
		leg.rotation.z = deg_to_rad(side * 7.0)
	var rear := _add_box(easel_frame, "CentrepieceEaselRearLeg", Vector3(0, 37, 16),
		Vector3(7, 74, 7), _materials.wood)
	rear.rotation.x = deg_to_rad(-14.0)
	_add_box(easel_frame, "CentrepieceEaselCrossbar", Vector3(0, 59, -5), Vector3(62, 6, 6), _materials.wood)
	# The rear leg sat 21 units behind the crossbar with nothing bridging
	# them, so the pieces read as separate floating boxes instead of one
	# easel. A diagonal brace ties the rear leg to the crossbar, the way a
	# real easel's back brace does.
	var brace_start := Vector3(0, 66, 13)
	var brace_finish := Vector3(0, 59, -5)
	var brace_dir := brace_finish - brace_start
	var brace := _add_box(easel_frame, "CentrepieceEaselBrace", (brace_start + brace_finish) * 0.5,
		Vector3(5, 5, brace_dir.length()), _materials.wood)
	brace.rotation = Vector3(-atan2(brace_dir.y, Vector2(brace_dir.x, brace_dir.z).length()),
		atan2(brace_dir.x, brace_dir.z), 0)

	# The canvas floats straight up off the crossbar (local Y) rather than
	# out toward the viewer (local Z), tilted a touch to one side so it
	# doesn't read as a flat cutout. Canvas and frame share one group so the
	# tilt carries both together.
	var canvas_group := Node3D.new()
	canvas_group.name = "CentrepieceCanvasGroup"
	# z=-5 sat flush with the crossbar/legs plane and clipped into them;
	# pulled forward (local -Z, toward the station) to clear the easel.
	canvas_group.position = Vector3(0, 105, -20)
	canvas_group.rotation.z = deg_to_rad(6.0)
	canvas_group.rotation.x = deg_to_rad(25.0)
	easel.add_child(canvas_group)
	_register_creator_bob(canvas_group)
	_add_box(canvas_group, "CentrepieceCanvas", Vector3.ZERO, Vector3(70, 90, 4), _materials.canvas)
	_build_frame(canvas_group, Vector3(0, -45, 0), 70, 90, _materials.gold)

	# Brush and paint trails share canvas_group's exact transform but sit in
	# their own sibling group (not nested under canvas_group) so they can
	# bob on a third, independent phase.
	var brush_group := Node3D.new()
	brush_group.name = "CreatorCentrepieceBrushGroup"
	brush_group.position = canvas_group.position
	brush_group.rotation = canvas_group.rotation
	easel.add_child(brush_group)
	_register_creator_bob(brush_group)

	# The brush floats tip-down, clear of the canvas.
	var brush_x := 8.0
	var brush_z := -57.0
	_add_sphere(brush_group, "CentrepieceBrushTip", Vector3(brush_x, 10, brush_z),
		Vector3(3.08, 4.9, 3.08), _materials.shadow)
	_add_box(brush_group, "CentrepieceBrushFerrule", Vector3(brush_x, 17, brush_z),
		Vector3(5.04, 7.0, 5.04), _materials.shadow)
	_add_box(brush_group, "CentrepieceBrushHandle", Vector3(brush_x, 28, brush_z),
		Vector3(4.2, 25.2, 4.2), _materials.wood)

	# A short paint trail that continues down past the tip (the direction the
	# brush is already pointing), then curves back upward. Still plain
	# spheres — no per-blob rotation, just a position lerp and a uniform
	# scale — but the two curve points are rotated 30 degrees further
	# downward around the tip (local X axis) before the curve is built.
	var trail_start := Vector3(brush_x, 8.0, brush_z)
	var trail_tilt := deg_to_rad(30.0)
	var bulge_rel := Vector3(15.0, -26.0, 10.0)
	var turn_rel := Vector3(28.0, -2.0, 22.0)
	bulge_rel = Vector3(bulge_rel.x, bulge_rel.y * cos(trail_tilt) - bulge_rel.z * sin(trail_tilt),
		bulge_rel.y * sin(trail_tilt) + bulge_rel.z * cos(trail_tilt))
	turn_rel = Vector3(turn_rel.x, turn_rel.y * cos(trail_tilt) - turn_rel.z * sin(trail_tilt),
		turn_rel.y * sin(trail_tilt) + turn_rel.z * cos(trail_tilt))
	var trail_bulge := trail_start + bulge_rel
	var trail_turn := trail_start + turn_rel
	_build_paint_curve(brush_group, "CentrepiecePaintTrail", trail_start, trail_bulge, trail_turn,
		12, 3.2, 1.3, _materials.gold)

	# A few loose paint-curve flourishes scattered around the canvas corners,
	# same technique — pushed further out from the frame and bigger than the
	# first pass so they read as their own flourish, not crowding the canvas.
	_build_paint_curve(brush_group, "CentrepieceCornerCurveA",
		Vector3(40.0, 54.0, -4.0), Vector3(72.0, 44.0, -14.0), Vector3(62.0, 23.0, -24.0),
		12, 5.8, 1.8, _materials.gold)
	_build_paint_curve(brush_group, "CentrepieceCornerCurveB",
		Vector3(-38.0, -51.0, -4.0), Vector3(-69.0, -38.0, -17.0), Vector3(-52.0, -16.0, -27.0),
		12, 5.8, 1.8, _materials.gold)


## A short curved paint streak as a chain of plain, non-rotated spheres —
## safe and cheap, so every paint-curve decoration in this kingdom reuses it
## instead of its own rotated/tapered geometry.
func _build_paint_curve(parent: Node3D, name_prefix: String, start: Vector3, control: Vector3,
		finish: Vector3, blob_count: int, scale_start: float, scale_end: float,
		material: Material) -> void:
	for step in blob_count:
		var t := float(step + 1) / float(blob_count)
		var point: Vector3 = start.lerp(control, t).lerp(control.lerp(finish, t), t)
		_add_sphere(parent, "%s_%d" % [name_prefix, step], point,
			Vector3.ONE * lerp(scale_start, scale_end, t), material)


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


func _add_box(parent: Node3D, node_name: String, position_value: Vector3, size: Vector3,
		material: Material, collision := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = material
	parent.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		body.position = position_value
		parent.add_child(body)
	return instance


func _add_sphere(parent: Node3D, node_name: String, position_value: Vector3, scale_value: Vector3,
		material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 8
	mesh.rings = 4
	instance.mesh = mesh
	instance.position = position_value
	instance.scale = scale_value
	instance.material_override = material
	parent.add_child(instance)


func _build_frame(parent: Node3D, position_value: Vector3, width: float, height: float, material: Material) -> void:
	_add_box(parent, "FrameLeft", position_value + Vector3(-width * 0.5, height * 0.5, 0), Vector3(6, height, 6), material, true)
	_add_box(parent, "FrameRight", position_value + Vector3(width * 0.5, height * 0.5, 0), Vector3(6, height, 6), material, true)
	_add_box(parent, "FrameTop", position_value + Vector3(0, height, 0), Vector3(width + 6, 6, 6), material, true)
