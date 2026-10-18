extends Node3D

const GalaxyCivicRailing := preload("res://scripts/galaxy_civic_railing.gd")

# The Mind kingdom is a full 3 km x 3 km floating region, chunked into large
# shared meshes. Heart Melody and Creator's Light are one station platform each.

const KINGDOM_SIZE := Vector2(3000.0, 3000.0)
const LAND_CHUNK_SIZE := 570.0
const LAND_CHUNK_SPACING := 580.0
const SHELF_BRIDGE_WIDTH := 30.0
const SHELF_BRIDGE_THICKNESS := 1.2
const SHELF_BRIDGE_LANDING_LENGTH := 6.0
const SHELF_BRIDGE_MAX_SLOPE_DEGREES := 18.0
const GALLERY_CONNECTION_Z := 820.0
const CASTLE_CLEAR_BUFFER := 1600.0
const MIND_CENTER := Vector3(-3600.0, 0.0, 3940.0)
const FLOATING_STATIONS := {
	"mind": Vector3(-1900, 35, 3940),
	"heart": Vector3(1700, 35, 7640),
	"creator": Vector3(5300, 35, 3940),
}

# Heart and Creator arrive on one platform each instead of a 3 km kingdom:
# three times the fountain island's 155 m so they read from a distance.
const STATION_PLATFORM_RADIUS := 465.0
const STATION_PLATFORM_TITLES := {"heart": "HEART MELODY", "creator": "CREATOR'S LIGHT"}

const STORY_ROUTES := {
	"mind": [
		{"id": "arrival", "title": "MIND SPARK SKYBRIDGE LANDING", "position": Vector3(-2100, 2, 3940)},
		{"id": "tower_forest", "title": "COMPUTER-TOWER FOREST", "position": Vector3(-2800, 12, 3120)},
		{"id": "thought_sparks", "title": "THOUGHT SPARK CONSTELLATION", "position": Vector3(-3400, 24, 3020)},
		{"id": "fear_gate", "title": "FEAR GATE", "position": Vector3(-3850, 38, 3380)},
		{"id": "proof_gate", "title": "PROOF GATE", "position": Vector3(-4100, 54, 3900)},
		{"id": "truth_gate", "title": "WHAT ELSE IS TRUE?", "position": Vector3(-3900, 72, 4460)},
		{"id": "thought_storm", "title": "THOUGHT STORM • GENTLE RAIN", "position": Vector3(-4400, 92, 4820)},
		{"id": "finale", "title": "OLDEST TREE • STAR OF WISDOM", "position": Vector3(-4850, 118, 4400)},
	],
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
	_build_kingdom("mind", MIND_CENTER)
	# Paving in each kingdom's station colours (STATION_PALETTES in the
	# railway), deeper here because the open island floor is in full sun.
	_build_station_platform("heart", [Color("b8607f"), Color("a85272"), Color("5e2440")], _materials.pink)
	_build_station_platform("creator", [Color("c98f3c"), Color("b87d2e"), Color("5e3a12")], _materials.gold)


func get_kingdom_size(kingdom_id: String = "mind") -> Vector2:
	if STATION_PLATFORM_TITLES.has(kingdom_id):
		return Vector2.ONE * STATION_PLATFORM_RADIUS * 2.0
	return KINGDOM_SIZE


func get_kingdom_centers() -> Dictionary:
	return {"mind": MIND_CENTER, "heart": _platform_center("heart"),
		"creator": _platform_center("creator")}


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
	_materials.mind = _material(Color("23233e"), 0.82)
	_materials.mind_surface_a = _material(Color("202b43"), 0.88)
	_materials.mind_surface_b = _material(Color("29304b"), 0.84)
	_materials.mind_court = _material(Color("17263d"), 0.64, Color("1b5872"), 0.22)
	_materials.mind_edge = _material(Color("243d5a"), 0.48, Color("2bcfe3"), 0.38)
	_materials.aqua = _material(Color("39dbea"), 0.32, Color("26d7f2"), 1.5)
	_materials.purple = _material(Color("8b69d3"), 0.72, Color("7048c5"), 0.45)
	_materials.green = _material(Color("58a979"), 0.90)
	_materials.gold = _material(Color("f0c35e"), 0.42, Color("f1ac32"), 1.25)
	_materials.pink = _material(Color("ed83c1"), 0.55, Color("e45da8"), 0.7)
	_materials.blue = _material(Color("4fa9df"), 0.42, Color("39bde7"), 0.8)
	_materials.coral = _material(Color("dc735b"), 0.58, Color("d95845"), 0.45)
	_materials.canvas = _material(Color("fff9e8"), 0.96)
	_materials.silver = _material(Color("c8d4dc"), 0.30)
	_materials.glass = _material(Color(0.30, 0.90, 0.95, 0.62), 0.20, Color("59e9f4"), 1.0, true)
	_materials.wood = _material(Color("815b3d"), 0.90)


func _build_kingdom(kingdom_id: String, center: Vector3) -> void:
	var kingdom := Node3D.new()
	kingdom.name = "%sKingdom3000m" % kingdom_id.to_pascal_case()
	add_child(kingdom)
	_build_landmass(kingdom, kingdom_id, center)
	_build_boundary(kingdom, kingdom_id, center)
	var route: Array = STORY_ROUTES[kingdom_id]
	_build_story_path(kingdom, route, kingdom_id)
	for index in route.size():
		_build_checkpoint(kingdom, kingdom_id, route[index], index)
	_add_label(kingdom, "%s • 3000m × 3000m" % kingdom_id.replace("_", " ").to_upper(),
		center + Vector3(0, 230, 0), _kingdom_color(kingdom_id), 72)


## A fountain-island-sized platform where the station's access bridge lands,
## with the centre left clear (inlay ring) for the kingdom's centrepiece.
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


func _build_landmass(parent: Node3D, kingdom_id: String, center: Vector3) -> void:
	var land := Node3D.new()
	land.name = "OptimizedLandmass"
	parent.add_child(land)
	var ground_material: Material = _materials.mind if kingdom_id == "mind" else _materials.ivory
	var chunk_surfaces := {}
	# A five-by-five family of 570 m floating shelves establishes the exact
	# 3 km region while leaving narrow surreal seams and sightlines to the sky.
	for row in 5:
		for column in 5:
			var x := center.x - 1160.0 + column * LAND_CHUNK_SPACING
			var z := center.z - 1160.0 + row * LAND_CHUNK_SPACING
			var rise := sin(float(row) * 1.7 + float(column) * 0.9) * 18.0
			var deck_pos := Vector3(x, -18.0 + rise, z)
			chunk_surfaces[Vector2i(column, row)] = deck_pos + Vector3.UP * 19.0
			_add_box(land, "LandChunk_%02d_%02d" % [row, column], deck_pos,
				Vector3(LAND_CHUNK_SIZE, 38, LAND_CHUNK_SIZE), ground_material, true)
			if kingdom_id == "mind":
				var surface_material: Material = _materials.mind_surface_a if (row + column) % 2 == 0 else _materials.mind_surface_b
				_add_box(land, "MindSurface_%02d_%02d" % [row, column], deck_pos + Vector3(0, 19.2, 0),
					Vector3(566, 0.42, 566), surface_material)
				# Thin luminous seams preserve the user's shelf grid while making it
				# read as a living computer landscape instead of unfinished blocks.
				for seam_index in 3:
					var seam_offset := -170.0 + seam_index * 170.0
					_add_box(land, "MindCircuitX_%02d_%02d_%02d" % [row, column, seam_index],
						deck_pos + Vector3(0, 19.48, seam_offset), Vector3(520, 0.12, 1.25), _materials.mind_edge)
					_add_box(land, "MindCircuitZ_%02d_%02d_%02d" % [row, column, seam_index],
						deck_pos + Vector3(seam_offset, 19.48, 0), Vector3(1.25, 0.12, 520), _materials.mind_edge)
			_add_box(land, "FloatingRoot_%02d_%02d" % [row, column], deck_pos + Vector3(0, -92, 0),
				Vector3(410, 150, 410), _materials.shadow)
			if (row + column) % 2 == 0:
				var grove_height := 19.0 if kingdom_id == "mind" else 25.0
				_build_grove(land, kingdom_id, deck_pos + Vector3(0, grove_height, 0), row * 5 + column)
	_build_inter_island_bridge_grid(land, kingdom_id, chunk_surfaces)
	_build_chunk_edge_guards(land, kingdom_id, chunk_surfaces)


func _build_chunk_edge_guards(land: Node3D, kingdom_id: String,
		chunk_surfaces: Dictionary) -> void:
	# Every floating shelf has four exposed sides. The grid bridges and story
	# walks receive measured openings instead of a fence through their landings.
	var guards := Node3D.new()
	guards.name = "CivicShelfEdgeGuards"
	land.add_child(guards)
	var route_segments: Array = []
	var route: Array = STORY_ROUTES[kingdom_id]
	for index in route.size() - 1:
		var start: Vector3 = route[index].position
		var finish: Vector3 = route[index + 1].position
		var middle := (start + finish) * 0.5 \
			+ Vector3(0, 4, sin(float(index) * 1.9) * 90.0)
		route_segments.append([start, middle])
		route_segments.append([middle, finish])
	var half := LAND_CHUNK_SIZE * 0.5 - 1.6
	var side_directions: Array[Vector2i] = [Vector2i(-1, 0),
		Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for row in 5:
		for column in 5:
			var chunk := Vector2i(column, row)
			var center: Vector3 = chunk_surfaces[chunk]
			var paths: Array = []
			var passage_count := 0
			for side in 4:
				var vertical := side < 2
				var fixed := (center.x if vertical else center.z) \
					+ (-half if side % 2 == 0 else half)
				var openings: Array[Vector2] = []
				var neighbor: Vector2i = chunk + side_directions[side]
				if chunk_surfaces.has(neighbor):
					openings.append(Vector2(0.0, SHELF_BRIDGE_WIDTH * 0.5 + 3.0))
				for route_segment in route_segments:
					var first: Vector3 = route_segment[0]
					var last: Vector3 = route_segment[1]
					var first_fixed := first.x if vertical else first.z
					var last_fixed := last.x if vertical else last.z
					var delta := last_fixed - first_fixed
					if absf(delta) < 0.001:
						continue
					var progress := (fixed - first_fixed) / delta
					if progress <= 0.0 or progress >= 1.0:
						continue
					var crossing := first.lerp(last, progress)
					# An elevated story walk passes above this shelf edge, so it
					# must not leave an unfenced opening at ground level.
					if crossing.y + 2.5 > center.y + 7.0:
						continue
					var along := (crossing.z - center.z) if vertical \
						else (crossing.x - center.x)
					if absf(along) > half + 2.0:
						continue
					var length := Vector2(last.x - first.x,
						last.z - first.z).length()
					var crossing_factor := absf(delta) / maxf(0.001, length)
					var opening_half := minf(65.0,
						18.0 / maxf(0.3, crossing_factor))
					openings.append(Vector2(along, opening_half))
				passage_count += openings.size()
				var steps := ceili(half * 2.0 / 8.0)
				var current := PackedVector3Array()
				for step in steps:
					var first_along := lerpf(-half, half,
						float(step) / float(steps))
					var last_along := lerpf(-half, half,
						float(step + 1) / float(steps))
					var middle_along := (first_along + last_along) * 0.5
					var passage := false
					for opening in openings:
						if absf(middle_along - opening.x) < opening.y:
							passage = true
							break
					if passage:
						if current.size() > 1:
							paths.append(current)
						current = PackedVector3Array()
						continue
					if current.is_empty():
						current.append(_chunk_edge_point(center, vertical,
							fixed, first_along))
					var end_point := _chunk_edge_point(center, vertical,
						fixed, last_along)
					if current.size() == 1:
						current.append(end_point)
					else:
						current[1] = end_point
				if current.size() > 1:
					paths.append(current)
			var railing := GalaxyCivicRailing.build(guards,
				"ShelfGuard_%02d_%02d" % [row, column], paths)
			railing.set_meta("chunk", chunk)
			railing.set_meta("intentional_passages", passage_count)


func _chunk_edge_point(center: Vector3, vertical: bool, fixed: float,
		along: float) -> Vector3:
	return Vector3(fixed, center.y, center.z + along) if vertical \
		else Vector3(center.x + along, center.y, fixed)


func _build_inter_island_bridge_grid(land: Node3D, kingdom_id: String,
		chunk_surfaces: Dictionary) -> void:
	var grid := Node3D.new()
	grid.name = "InterIslandBridgeGrid"
	grid.set_meta("kingdom_id", kingdom_id)
	grid.set_meta("chunk_count", 25)
	grid.set_meta("minimum_connections_per_chunk", 2)
	land.add_child(grid)
	var bridge_count := 0
	for row in 5:
		for column in 5:
			var chunk := Vector2i(column, row)
			for neighbour in [Vector2i(column + 1, row), Vector2i(column, row + 1)]:
				if not chunk_surfaces.has(neighbour):
					continue
				_build_exact_shelf_bridge(grid,
					"ShelfBridge_%02d_%02d_to_%02d_%02d" % [row, column, neighbour.y, neighbour.x],
					chunk, neighbour, chunk_surfaces[chunk], chunk_surfaces[neighbour])
				bridge_count += 1
	grid.set_meta("bridge_count", bridge_count)


func _build_exact_shelf_bridge(parent: Node3D, node_name: String,
		chunk_a: Vector2i, chunk_b: Vector2i, surface_a: Vector3, surface_b: Vector3) -> void:
	var bridge := Node3D.new()
	bridge.name = node_name
	bridge.set_meta("chunk_a", chunk_a)
	bridge.set_meta("chunk_b", chunk_b)
	bridge.set_meta("surface_a_y", surface_a.y)
	bridge.set_meta("surface_b_y", surface_b.y)
	parent.add_child(bridge)
	var direction := Vector3(surface_b.x - surface_a.x, 0.0, surface_b.z - surface_a.z).normalized()
	var gap := LAND_CHUNK_SPACING - LAND_CHUNK_SIZE
	var required_run := absf(surface_b.y - surface_a.y) \
		/ tan(deg_to_rad(SHELF_BRIDGE_MAX_SLOPE_DEGREES))
	# The two level landing pieces consume part of the total run. Include them in
	# the inset calculation so the middle slope itself, not just the whole bridge,
	# stays within the player-safe angle.
	var inset := maxf(8.0,
		(required_run + SHELF_BRIDGE_LANDING_LENGTH * 2.0 - gap) * 0.5)
	var half_chunk := LAND_CHUNK_SIZE * 0.5
	var start_surface := surface_a + direction * (half_chunk - inset)
	var finish_surface := surface_b - direction * (half_chunk - inset)
	var start_landing_end := start_surface + direction * SHELF_BRIDGE_LANDING_LENGTH
	start_landing_end.y = start_surface.y
	var finish_landing_start := finish_surface - direction * SHELF_BRIDGE_LANDING_LENGTH
	finish_landing_start.y = finish_surface.y
	_add_exact_bridge_segment(bridge, "StartLanding", start_surface, start_landing_end)
	_add_exact_bridge_segment(bridge, "SlopeSpan", start_landing_end, finish_landing_start)
	_add_exact_bridge_segment(bridge, "FinishLanding", finish_landing_start, finish_surface)
	_add_shelf_bridge_guards(bridge, start_surface, finish_surface)
	bridge.set_meta("walk_start", start_surface)
	bridge.set_meta("walk_finish", finish_surface)
	bridge.set_meta("slope_degrees", rad_to_deg(atan2(
		absf(finish_landing_start.y - start_landing_end.y),
		Vector2(finish_landing_start.x - start_landing_end.x,
			finish_landing_start.z - start_landing_end.z).length())))


func _add_exact_bridge_segment(parent: Node3D, node_name: String,
		start_surface: Vector3, finish_surface: Vector3) -> void:
	var horizontal_length := Vector2(
		finish_surface.x - start_surface.x,
		finish_surface.z - start_surface.z).length()
	var slope := atan2(finish_surface.y - start_surface.y, horizontal_length)
	var top_vertical_offset := cos(slope) * SHELF_BRIDGE_THICKNESS * 0.5
	var start_center := start_surface - Vector3.UP * top_vertical_offset
	var finish_center := finish_surface - Vector3.UP * top_vertical_offset
	_add_sloped_box_between(parent, node_name, start_center, finish_center,
		Vector2(SHELF_BRIDGE_WIDTH, SHELF_BRIDGE_THICKNESS), _materials.silver, true)
	var deck := parent.get_node(node_name) as MeshInstance3D
	deck.set_meta("walk_surface_start_y", start_surface.y)
	deck.set_meta("walk_surface_finish_y", finish_surface.y)


func _add_shelf_bridge_guards(parent: Node3D, start_surface: Vector3,
		finish_surface: Vector3) -> void:
	# Keep the continuous existing collision and replace its plain glass visual
	# with the same civic railing found on the adjacent shelf edges.
	var horizontal := Vector3(
		finish_surface.x - start_surface.x, 0.0,
		finish_surface.z - start_surface.z).normalized()
	var side_axis := Vector3(horizontal.z, 0.0, -horizontal.x)
	var paths: Array = []
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var side_name := "Left" if side < 0.0 else "Right"
		var rail_offset: Vector3 = side_axis * side * (SHELF_BRIDGE_WIDTH * 0.5 - 0.6)
		var old_rail := _add_sloped_box_between(parent, "%sSafetyRail" % side_name,
			start_surface + rail_offset + Vector3.UP * 1.5,
			finish_surface + rail_offset + Vector3.UP * 1.5,
			Vector2(0.8, 2.4), _materials.glass, true)
		old_rail.visible = false
		var body := parent.get_node("%sSafetyRailCollision" % side_name) as StaticBody3D
		body.position.y += 1.5
		var shape := (body.get_child(0) as CollisionShape3D).shape as BoxShape3D
		shape.size.y = 5.4
		paths.append(PackedVector3Array([
			start_surface + rail_offset, finish_surface + rail_offset]))
	GalaxyCivicRailing.build(parent, "CivicBridgeRailing", paths, false)


func _add_sloped_box_between(parent: Node3D, node_name: String,
		start_center: Vector3, finish_center: Vector3, cross_section: Vector2,
		material: Material, collision: bool) -> MeshInstance3D:
	var direction := finish_center - start_center
	var horizontal_length := Vector2(direction.x, direction.z).length()
	var instance := _add_box(parent, node_name, start_center.lerp(finish_center, 0.5),
		Vector3(cross_section.x, cross_section.y, direction.length()), material, collision)
	instance.rotation = Vector3(
		-atan2(direction.y, horizontal_length), atan2(direction.x, direction.z), 0.0)
	if collision:
		var collision_body := parent.get_child(parent.get_child_count() - 1) as StaticBody3D
		if collision_body != null:
			collision_body.name = "%sCollision" % node_name
			collision_body.rotation = instance.rotation
	return instance


func _build_boundary(parent: Node3D, kingdom_id: String, center: Vector3) -> void:
	var boundary := Node3D.new()
	boundary.name = "ExplorationBoundary3000m"
	parent.add_child(boundary)
	var half := KINGDOM_SIZE.x * 0.5
	for index in 16:
		var side := index / 4
		var along := -half + 100.0 + float(index % 4) * ((half * 2.0 - 200.0) / 3.0)
		var point := center
		if side == 0: point += Vector3(-half, 0, along)
		elif side == 1: point += Vector3(half, 0, along)
		elif side == 2: point += Vector3(along, 0, -half)
		else: point += Vector3(along, 0, half)
		_add_cylinder(boundary, "BoundaryBeacon_%02d" % index, point + Vector3(0, 55, 0), 7, 110,
			_kingdom_material(kingdom_id), false, 10)


func _build_story_path(parent: Node3D, route: Array, kingdom_id := "") -> void:
	var path := Node3D.new()
	path.name = "ConnectedStoryPath"
	parent.add_child(path)
	for index in route.size() - 1:
		var start: Vector3 = route[index].position
		var finish: Vector3 = route[index + 1].position
		var middle := (start + finish) * 0.5 + Vector3(0, 4, sin(float(index) * 1.9) * 90.0)
		_add_walkway(path, "StoryWay_%02d_A" % index, start, middle, 30.0)
		_add_walkway(path, "StoryWay_%02d_B" % index, middle, finish, 30.0)
		_add_story_void_guards(path, "StoryWay_%02d_A" % index,
			start, middle, kingdom_id)
		_add_story_void_guards(path, "StoryWay_%02d_B" % index,
			middle, finish, kingdom_id)
		if kingdom_id == "mind":
			_add_route_seam(path, "StoryCircuit_%02d_A" % index, start, middle)
			_add_route_seam(path, "StoryCircuit_%02d_B" % index, middle, finish)


func _add_story_void_guards(parent: Node3D, node_name: String,
		start: Vector3, finish: Vector3, kingdom_id: String) -> void:
	# The story route crosses some shelf seams away from the regular bridge grid.
	# Rail only those void spans; a continuous rail would divide usable land.
	var distance := Vector2(finish.x - start.x, finish.z - start.z).length()
	var sample_count := maxi(1, ceili(distance / 4.0))
	var centre: Vector3 = get_kingdom_centers()[kingdom_id]
	var horizontal := Vector3(finish.x - start.x, 0.0,
		finish.z - start.z).normalized()
	var side_axis := Vector3(horizontal.z, 0.0, -horizontal.x)
	var paths: Array = []
	var exposed_from := -1
	for sample in sample_count + 1:
		var exposed := false
		if sample < sample_count:
			var point := start.lerp(finish,
				(float(sample) + 0.5) / float(sample_count))
			exposed = not _point_over_shelf(point, centre)
		if exposed and exposed_from < 0:
			exposed_from = sample
		elif not exposed and exposed_from >= 0:
			var first := start.lerp(finish,
				float(exposed_from) / float(sample_count)) + Vector3.UP * 2.5
			var last := start.lerp(finish,
				float(sample) / float(sample_count)) + Vector3.UP * 2.5
			if first.distance_to(last) >= 3.0:
				for side in [-1.0, 1.0]:
					var offset := side_axis * float(side) * 14.3
					paths.append(PackedVector3Array([first + offset,
						last + offset]))
			exposed_from = -1
	if not paths.is_empty():
		GalaxyCivicRailing.build(parent, node_name + "VoidGuard", paths)


func _point_over_shelf(point: Vector3, centre: Vector3) -> bool:
	var first_x := centre.x - 1160.0
	var first_z := centre.z - 1160.0
	var column := roundi((point.x - first_x) / LAND_CHUNK_SPACING)
	var row := roundi((point.z - first_z) / LAND_CHUNK_SPACING)
	if column < 0 or column >= 5 or row < 0 or row >= 5:
		return false
	var chunk_x := first_x + float(column) * LAND_CHUNK_SPACING
	var chunk_z := first_z + float(row) * LAND_CHUNK_SPACING
	return absf(point.x - chunk_x) <= LAND_CHUNK_SIZE * 0.5 \
		and absf(point.z - chunk_z) <= LAND_CHUNK_SIZE * 0.5


func _build_checkpoint(parent: Node3D, kingdom_id: String, info: Dictionary, index: int) -> void:
	var checkpoint := Node3D.new()
	checkpoint.name = "StoryCheckpoint_%02d_%s" % [index + 1, info.id]
	checkpoint.position = info.position
	checkpoint.set_meta("kingdom_id", kingdom_id)
	checkpoint.set_meta("checkpoint_id", info.id)
	checkpoint.set_meta("story_index", index)
	parent.add_child(checkpoint)
	var court_material: Material = _materials.mind_court if kingdom_id == "mind" else _materials.ivory
	_add_cylinder(checkpoint, "CheckpointCourt", Vector3(0, -2, 0), 70.0 if index < 7 else 105.0,
		5.0, court_material, true, 32)
	_add_cylinder(checkpoint, "StoryLight", Vector3(0, 2, 0), 20.0, 1.2,
		_kingdom_material(kingdom_id), false, 24)
	_add_label(checkpoint, info.title, Vector3(0, 42, 0), _kingdom_color(kingdom_id), 39)
	if kingdom_id == "mind": _decorate_mind(checkpoint, str(info.id), index)
	elif kingdom_id == "heart": _decorate_heart(checkpoint, str(info.id), index)
	else: _decorate_creator(checkpoint, str(info.id), index)


func _decorate_mind(parent: Node3D, checkpoint_id: String, index: int) -> void:
	if checkpoint_id == "tower_forest":
		for tower_index in 9:
			var angle := TAU * tower_index / 9.0
			_add_box(parent, "ComputerTree", Vector3(cos(angle) * 58, 38, sin(angle) * 58),
				Vector3(18, 70 + tower_index % 3 * 24, 18), _materials.mind, true)
			_add_cylinder(parent, "LivingVine", Vector3(cos(angle) * 55, 32, sin(angle) * 55), 2.0, 60,
				_materials.green, false, 7)
	elif checkpoint_id == "thought_sparks":
		for spark in 12:
			var angle := TAU * spark / 12.0
			_add_sphere(parent, "ThoughtSpark", Vector3(cos(angle) * (25 + spark % 3 * 10), 14 + spark % 4 * 7,
				sin(angle) * (25 + spark % 3 * 10)), Vector3.ONE * 4.5, _materials.aqua)
	elif checkpoint_id.ends_with("gate"):
		_build_gate(parent, _materials.aqua)
	elif checkpoint_id == "thought_storm":
		_add_cylinder(parent, "GentleRainBasin", Vector3(0, 1, 0), 50, 3, _materials.blue, true, 32)
		for cloud in 9:
			_add_sphere(parent, "StormCloud", Vector3((cloud % 3 - 1) * 28, 55 + cloud % 2 * 8,
				(cloud / 3 - 1) * 24), Vector3(18, 8, 13), _materials.purple)
	elif checkpoint_id == "finale":
		_build_old_tree(parent)


func _decorate_heart(parent: Node3D, checkpoint_id: String, index: int) -> void:
	var emotional_materials := [_materials.gold, _materials.coral, _materials.blue,
		_materials.purple, _materials.green, _materials.gold, _materials.pink, _materials.gold]
	if checkpoint_id == "arrival":
		# A clear east-west avenue connects the station ramp to the playable gate.
		# The old ring of solid instruments put an 18 m pillar across that route.
		for side in [-1.0, 1.0]:
			for flower in 4:
				_add_sphere(parent, "ArrivalBlossom", Vector3(-32 + flower * 18, 2, side * 17),
					Vector3(2.4, 1.5, 2.4), _materials.pink)
	elif checkpoint_id == "sadness":
		_add_cylinder(parent, "RainLake", Vector3(0, 0, 0), 54, 3, _materials.blue, true, 32)
		_add_box(parent, "GentleBoat", Vector3(0, 7, 0), Vector3(28, 5, 12), _materials.wood)
	elif checkpoint_id == "frustration":
		for drum in 7:
			var angle := TAU * drum / 7.0
			_add_cylinder(parent, "PlatformDrum", Vector3(cos(angle) * 42, 8 + drum % 3 * 7, sin(angle) * 42),
				12, 15, _materials.coral, true, 18)
	elif checkpoint_id == "fear":
		for bell in 5:
			_add_cylinder(parent, "WarningBell", Vector3(-42 + bell * 21, 18 + bell % 2 * 9, 0),
				8, 28, _materials.purple, false, 12)
	elif checkpoint_id == "peace":
		for flower in 18:
			var angle := TAU * flower / 18.0
			_add_sphere(parent, "PeaceFlower", Vector3(cos(angle) * 45, 6, sin(angle) * 45),
				Vector3(6, 3, 6), _materials.green)
	elif checkpoint_id == "finale":
		for tier in 4:
			_add_cylinder(parent, "AmphitheatreTier", Vector3(0, tier * 3, 0), 92 - tier * 16, 3,
				emotional_materials[index], true, 36)
		_add_gem(parent, "HarmonyJewel", Vector3(0, 48, 0), _materials.gold)
	elif checkpoint_id != "arrival":
		# No ring at the arrival checkpoint: the Heart station's access bridge
		# lands at its centre, and the 18 m solid drums crowded and blocked it.
		for instrument in 7:
			var angle := TAU * instrument / 7.0
			# The arrival bridge leaves the court toward +X. Keep the full
			# instrument ring, but put its opening on that walking route.
			if checkpoint_id == "arrival":
				angle += PI / 7.0
			_add_cylinder(parent, "EmotionInstrument", Vector3(cos(angle) * 42, 10, sin(angle) * 42),
				8 + instrument % 2 * 4, 18, emotional_materials[index], true, 16)


func _decorate_creator(parent: Node3D, checkpoint_id: String, _index: int) -> void:
	if checkpoint_id == "glass_seeds":
		for seed in 9:
			var angle := TAU * seed / 9.0
			_add_sphere(parent, "GlassSeed", Vector3(cos(angle) * 48, 15, sin(angle) * 48),
				Vector3(7, 14, 7), _materials.glass)
			_add_cylinder(parent, "SilverPipe", Vector3(cos(angle) * 48, 5, sin(angle) * 48), 2.5, 24,
				_materials.silver, false, 10)
	elif checkpoint_id in ["drawing", "rest_canvas"]:
		for easel in 5:
			_build_easel(parent, Vector3(-40 + easel * 20, 2, (easel % 2) * 24 - 12))
	elif checkpoint_id == "dream_door":
		_build_frame(parent, Vector3(0, 0, 0), 48, 70, _materials.gold)
		_add_walkway(parent, "DrawingBecomesBridge", Vector3(0, 1, -15), Vector3(0, 20, -120), 18)
	elif checkpoint_id == "real_garden":
		for plant in 16:
			var angle := TAU * plant / 16.0
			_add_sphere(parent, "PaintedPlant", Vector3(cos(angle) * 48, 7 + plant % 3 * 4, sin(angle) * 48),
				Vector3(8, 12, 8), _materials.pink if plant % 2 == 0 else _materials.green)
		_build_old_tree(parent, false)
	elif checkpoint_id == "perfect_blank":
		_add_box(parent, "PerfectBlankVoid", Vector3(0, 28, 0), Vector3(110, 56, 9), _materials.canvas)
		_build_frame(parent, Vector3(0, 1, -7), 70, 82, _materials.silver)
	elif checkpoint_id == "finale":
		_add_gem(parent, "CreatorsLightFlame", Vector3(0, 58, 0), _materials.gold, Vector3(18, 38, 18))
		for frame_index in 7:
			var angle := -1.2 + frame_index * 0.4
			var frame := Node3D.new()
			frame.position = Vector3(cos(angle) * 78, 0, sin(angle) * 78)
			parent.add_child(frame)
			_build_frame(frame, Vector3.ZERO, 22, 34, _materials.gold)
	else:
		for shape in 9:
			var angle := TAU * shape / 9.0
			_add_gem(parent, "FloatingShape", Vector3(cos(angle) * 48, 25 + shape % 3 * 12, sin(angle) * 48),
				_materials.glass, Vector3.ONE * (6 + shape % 3 * 2))


func _build_grove(parent: Node3D, kingdom_id: String, center: Vector3, seed: int) -> void:
	if kingdom_id == "mind":
		var tree_scenes := [
			"res://assets3D/trees/tree_1_c_color_12.tscn",
			"res://assets3D/trees/tree_2_b_color_12.tscn",
			"res://assets3D/trees/tree_3_a_color_12.tscn",
			"res://assets3D/trees/tree_4_a_color_12.tscn",
		]
		for index in 9:
			var angle := TAU * float(index) / 9.0 + seed * 0.31
			var radius := 78.0 + float(index % 3) * 42.0
			var tree := _add_asset_scene(parent, "MindLivingTree_%02d_%02d" % [seed, index],
				tree_scenes[(seed + index) % tree_scenes.size()],
				center + Vector3(cos(angle) * radius, 0, sin(angle) * radius),
				Vector3.ONE * (7.0 + float((seed + index) % 4) * 1.4))
			if tree != null:
				tree.rotation.y = angle + PI
		return
	for index in 7:
		var angle := TAU * index / 7.0 + seed * 0.31
		var radius := 80.0 + (index % 3) * 30.0
		var material: Material = _materials.purple if kingdom_id != "heart" else _materials.green
		_add_cylinder(parent, "DistantTree", center + Vector3(cos(angle) * radius, 22, sin(angle) * radius),
			5, 44 + index % 3 * 16, _materials.wood, false, 7)
		_add_sphere(parent, "DistantCanopy", center + Vector3(cos(angle) * radius, 55 + index % 3 * 16, sin(angle) * radius),
			Vector3(18, 22, 18), material)


func _add_asset_scene(parent: Node3D, node_name: String, resource_path: String,
		position_value: Vector3, scale_value: Vector3) -> Node3D:
	var packed := load(resource_path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return null
	instance.name = node_name
	instance.position = position_value
	instance.scale = scale_value
	parent.add_child(instance)
	return instance


func _add_route_seam(parent: Node3D, node_name: String, start: Vector3, finish: Vector3) -> void:
	var direction := finish - start
	var seam := _add_box(parent, node_name, (start + finish) * 0.5 + Vector3.UP * 2.65,
		Vector3(2.6, 0.24, direction.length() - 4.0), _materials.aqua)
	seam.rotation = Vector3(-atan2(direction.y, Vector2(direction.x, direction.z).length()),
		atan2(direction.x, direction.z), 0)


func _build_gate(parent: Node3D, material: Material) -> void:
	_add_box(parent, "LeftPillar", Vector3(-24, 24, 0), Vector3(10, 48, 12), _materials.ivory, true)
	_add_box(parent, "RightPillar", Vector3(24, 24, 0), Vector3(10, 48, 12), _materials.ivory, true)
	_add_box(parent, "GateLight", Vector3(0, 49, 0), Vector3(58, 8, 12), material, true)


func _build_old_tree(parent: Node3D, reward: bool = true) -> void:
	_add_cylinder(parent, "OldestTreeTrunk", Vector3(0, 34, 0), 13, 68, _materials.wood, true, 10)
	for bloom in 20:
		var angle := TAU * bloom / 20.0
		_add_sphere(parent, "AncientCanopy", Vector3(cos(angle) * (25 + bloom % 4 * 8), 75 + bloom % 3 * 12,
			sin(angle) * (25 + bloom % 4 * 8)), Vector3(17, 13, 17), _materials.purple)
	if reward:
		_add_gem(parent, "StarOfWisdom", Vector3(0, 46, -18), _materials.gold)


func _build_easel(parent: Node3D, position_value: Vector3) -> void:
	_add_box(parent, "Canvas", position_value + Vector3(0, 20, 0), Vector3(18, 24, 2), _materials.canvas)
	_add_box(parent, "EaselLeg", position_value + Vector3(-6, 7, 1), Vector3(2, 15, 2), _materials.wood)
	_add_box(parent, "EaselLeg", position_value + Vector3(6, 7, 1), Vector3(2, 15, 2), _materials.wood)


func _build_frame(parent: Node3D, position_value: Vector3, width: float, height: float, material: Material) -> void:
	_add_box(parent, "FrameLeft", position_value + Vector3(-width * 0.5, height * 0.5, 0), Vector3(6, height, 6), material, true)
	_add_box(parent, "FrameRight", position_value + Vector3(width * 0.5, height * 0.5, 0), Vector3(6, height, 6), material, true)
	_add_box(parent, "FrameTop", position_value + Vector3(0, height, 0), Vector3(width + 6, 6, 6), material, true)


func _add_walkway(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, width: float) -> void:
	var direction := finish - start
	var instance := _add_box(parent, node_name, (start + finish) * 0.5,
		Vector3(width, 5, direction.length()), _materials.ivory, true)
	var slope := -atan2(direction.y, Vector2(direction.x, direction.z).length())
	instance.rotation = Vector3(slope, atan2(direction.x, direction.z), 0)
	# Match the collision body created by _add_box.
	var collision_body := parent.get_child(parent.get_child_count() - 1) as StaticBody3D
	if collision_body != null:
		collision_body.rotation = instance.rotation


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


func _add_gem(parent: Node3D, node_name: String, position_value: Vector3, material: Material,
		scale_value: Vector3 = Vector3(10, 14, 10)) -> void:
	var gem := MeshInstance3D.new()
	gem.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0
	mesh.bottom_radius = 1
	mesh.height = 2
	mesh.radial_segments = 6
	gem.mesh = mesh
	gem.position = position_value
	gem.scale = scale_value
	gem.material_override = material
	parent.add_child(gem)


func _kingdom_material(kingdom_id: String) -> Material:
	if kingdom_id == "mind": return _materials.aqua
	if kingdom_id == "heart": return _materials.pink
	return _materials.gold


func _kingdom_color(kingdom_id: String) -> Color:
	if kingdom_id == "mind": return Color("83efff")
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
