class_name HeartGardenLayout
extends RefCounted

## The shared terrain and architectural shell for Heart Melody Island One.
## Quiet Meadow is deliberately lower and softer; Feeling Garden is deeper,
## brighter and carries the waterfall-facing ceremonial architecture.
const Kit := preload("res://scripts/heart_melody/heart_nature_kit.gd")
const TreeModel := preload("res://assets3D/heart_melody/island_one/glb/faceted_tree.glb")
const TreeModelA := preload("res://assets3D/heart_melody/island_one/glb/faceted_tree_a.glb")
const TreeModelB := preload("res://assets3D/heart_melody/island_one/glb/faceted_tree_b.glb")
const VineBridgeModel := preload("res://assets3D/heart_melody/island_one/glb/growing_vine_bridge.glb")

const QUIET_CENTER := Vector3(-130, 0, 0)
const QUIET_RADII := Vector2(145, 125)
const GARDEN_CENTER := Vector3(150, 2, 0)
const GARDEN_RADII := Vector2(165, 140)
# Route geometry follows the Quiet Meadow floor at y=0. The player spawn remains
# two metres above it in HeartGardenWorld so the production capsule settles
# safely; using that spawn height here created a solid stair riser across the
# first walking line.
const ARRIVAL := Vector3(-250, 0, 0)
const PLANTER_COURT := Vector3(-8, 2, 0)
const DRUM_LAWN := Vector3(175, 2, 0)
const CLEARING_A := Vector3(245, 2, -76)
const CLEARING_B := Vector3(300, 2, 66)
const OVERLOOK := Vector3(285, 3, 0)

const ROUTE := [
	ARRIVAL, Vector3(-210, 0, 18), Vector3(-170, 0, 0),
	Vector3(-135, 0, 42), Vector3(-82, 0, 20), Vector3(-30, 0, 0),
	Vector3(-55, 0, -62), PLANTER_COURT, Vector3(12, 1, 65),
	Vector3(68, 2, -34), Vector3(105, 2, 0), Vector3(160, 2, -58),
	Vector3(205, 2, 0), Vector3(160, 2, 58), Vector3(230, 2, -18),
	CLEARING_A, Vector3(270, 2, -16), CLEARING_B, OVERLOOK, Vector3(305, 3, 0),
]


static func build(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "HeartGardenLayout"
	parent.add_child(root)
	_build_district(root, "QuietMeadow", QUIET_CENTER, QUIET_RADII, 0.0, 30.0,
		GARDEN_CENTER, GARDEN_RADII, false)
	_build_district(root, "FeelingGarden", GARDEN_CENTER, GARDEN_RADII, 2.0, 40.0,
		QUIET_CENTER, QUIET_RADII, true)
	var routes: Array = []
	for index in ROUTE.size() - 1:
		_add_path(root, ROUTE[index], ROUTE[index + 1], 6.5, routes)
	for branch in [
		[Vector3(-170,0,0), Vector3(-200,0,-28), Vector3(-135,0,-45)],
		[Vector3(-82,0,20), Vector3(-55,0,-62), PLANTER_COURT, Vector3(12,1,65)],
		[Vector3(105,2,0), Vector3(160,2,-58), Vector3(205,2,0), Vector3(160,2,58)],
		[Vector3(230,2,-18), Vector3(270,2,-16), CLEARING_B],
	]:
		for index in branch.size() - 1:
			_add_path(root, branch[index], branch[index + 1], 4.0, routes)
	_build_landmark_terraces(root)
	_build_district_transition_collision(root)
	_build_perimeter(root, QUIET_CENTER, QUIET_RADII, GARDEN_CENTER, GARDEN_RADII, false)
	_build_perimeter(root, GARDEN_CENTER, GARDEN_RADII, QUIET_CENTER, QUIET_RADII, true)
	_build_waterfalls(root)
	_build_dressing(root)
	var canopy := _build_shortcut(root)
	var departure := _build_departure(root)
	_build_recovery_volume(root)
	return {"root": root, "route_segments": routes, "seed_shortcut": canopy[0],
		"seed_shortcut_blocker": canopy[1], "bridge": departure[0], "bridge_blocker": departure[1]}


static func _build_district(parent: Node3D, label: String, center: Vector3, radii: Vector2,
		top_y: float, depth: float, other_center: Vector3, other_radii: Vector2,
		is_garden: bool) -> void:
	var district := Node3D.new()
	district.name = label
	parent.add_child(district)
	for sector_index in 6:
		var sector := Node3D.new()
		sector.name = "Sector%02d" % (sector_index + 1)
		district.add_child(sector)
		var start := TAU * float(sector_index) / 6.0
		var finish := TAU * float(sector_index + 1) / 6.0
		Kit.ellipse_sector(sector, "FacetedFoundation",
			Vector3(center.x, top_y - depth * 0.5 - 0.8, center.z), radii, depth,
			start, finish, "stone", false, 0.48 if is_garden else 0.55, 14)
		sector.set_meta("heart_cull_sector", sector_index)
		sector.set_meta("district", label)
	# World One's luminous structural deck, followed by a smaller natural lawn.
	Kit.ellipse_sector(district, "IvoryDeck", Vector3(center.x, top_y - 0.4, center.z),
		radii, 0.8, 0.0, TAU, "ivory", false, 0.995, 64)
	Kit.ellipse_sector(district, "ContinuousGrassTop", Vector3(center.x, top_y + 0.03, center.z),
		radii * Vector2(0.86, 0.82), 0.12, 0.0, TAU, "grass", false, 0.995, 64)
	_add_ellipse_collision(district, center, radii, top_y)


static func _add_ellipse_collision(parent: Node3D, center: Vector3, radii: Vector2, top_y: float) -> void:
	# Broad overlapping slabs cover the whole rendered oval without radial seams.
	for z_index in 5:
		var z_fraction := -0.72 + float(z_index) * 0.36
		var half_width := radii.x * sqrt(maxf(0.10, 1.0 - z_fraction * z_fraction))
		var body := StaticBody3D.new()
		body.name = "ContinuousDeckCollision"
		body.position = Vector3(center.x, top_y - 0.10, center.z + z_fraction * radii.y)
		var collision := CollisionShape3D.new()
		var slab := BoxShape3D.new()
		# Thin support slabs keep their side faces below the capsule's step height;
		# the continuous terrace ramps own every district height transition.
		slab.size = Vector3(half_width * 2.0, 0.20, radii.y * 0.43)
		collision.shape = slab
		body.add_child(collision)
		parent.add_child(body)


static func _build_perimeter(parent: Node3D, center: Vector3, radii: Vector2,
		other_center: Vector3, other_radii: Vector2, east_exit: bool) -> void:
	var points: Array[Vector3] = []
	for index in 48:
		var angle := TAU * float(index) / 48.0
		points.append(center + Vector3(cos(angle) * (radii.x - 2.4), 0,
			sin(angle) * (radii.y - 2.4)))
	for index in points.size():
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		var middle := (a + b) * 0.5
		if _inside_ellipse(middle, other_center, other_radii, 0.91): continue
		if east_exit and middle.x > 304 and absf(middle.z) < 10: continue
		if east_exit and (middle.distance_to(CLEARING_A) < 18.0 \
				or middle.distance_to(CLEARING_B) < 18.0):
			continue
		Kit.branch(parent, "GoldRailCap", a + Vector3.UP * 1.25, b + Vector3.UP * 1.25,
			0.16, "gold", true)
		if index % 2 == 0:
			Kit.box(parent, "IvoryRailPost", a + Vector3.UP * 0.65,
				Vector3(0.80, 1.3, 0.80), "ivory", true)
		if index % 4 == 0:
			var tangent := (b - a).normalized()
			var left := middle - tangent * 3.0
			var right := middle + tangent * 3.0
			for point in [left, right]:
				Kit.box(parent, "UndercroftPier", point + Vector3(0, -3.2, 0),
					Vector3(1.5, 6.4, 1.5), "ivory")
			Kit.branch(parent, "UndercroftArch", left + Vector3(0, -0.2, 0),
				right + Vector3(0, -0.2, 0), 0.52, "ivory")
			var inward := (center - middle).normalized()
			Kit.branch(parent, "RootButtress", middle - inward * 1.4 + Vector3.DOWN * 8.5,
				middle + Vector3.UP * 0.15, 0.56, "wood")
			if index % 8 == 0:
				Kit.branch(parent, "HangingVine", middle + Vector3.UP * 0.4,
					middle + Vector3.DOWN * 5.0, 0.14, "leaf")


static func _inside_ellipse(point: Vector3, center: Vector3, radii: Vector2, scale_value: float) -> bool:
	var dx := (point.x - center.x) / (radii.x * scale_value)
	var dz := (point.z - center.z) / (radii.y * scale_value)
	return dx * dx + dz * dz < 1.0


static func _add_path(parent: Node3D, a: Vector3, b: Vector3, width: float, routes: Array) -> void:
	routes.append([a, b])
	var forward := (b - a).normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var slab := Kit.box(parent, "WarmPearlPath", (a + b) * 0.5 + Vector3.UP * 0.15,
		Vector3(width, 0.28, a.distance_to(b)), "path", false)
	slab.basis = Basis(right, forward.cross(right).normalized(), forward)
	var inlay := Kit.box(parent, "GoldLeafInlay", (a + b) * 0.5 + Vector3.UP * 0.31,
		Vector3(0.22, 0.04, maxf(0.5, a.distance_to(b) - 1.0)), "gold", false)
	inlay.basis = slab.basis
	if absf(a.y - b.y) > 0.1: _add_stair_ramp(parent, a, b, width)


static func _add_stair_ramp(parent: Node3D, a: Vector3, b: Vector3, width: float) -> void:
	var low := a if a.y < b.y else b
	var high := b if a.y < b.y else a
	var direction := Vector3(high.x - low.x, 0, high.z - low.z).normalized()
	var right := Vector3.UP.cross(direction).normalized()
	var length := Vector2(high.x - low.x, high.z - low.z).length()
	for index in 8:
		var progress := float(index + 1) / 8.0
		var height := lerpf(0.1, high.y - low.y + 0.12, progress)
		var point := low + direction * length * (float(index) + 0.5) / 8.0
		var step := Kit.box(parent, "IvoryTerraceStep", point + Vector3(0, -0.05 + height * 0.5, 0),
			Vector3(width, height, length / 8.0 + 0.14), "ivory", false)
		step.basis = Basis(right, Vector3.UP, direction)
	# A single shallow collision ramp runs through both floor slabs. Decorative
	# risers remain visible, but they cannot trap the production capsule against
	# the raised district's vertical slab edge.
	var slope := (high - low).normalized()
	var slope_right := Vector3.UP.cross(slope).normalized()
	var slope_up := slope.cross(slope_right).normalized()
	var body := StaticBody3D.new()
	body.name = "ContinuousTerraceRampCollision"
	body.position = (low + high) * 0.5 - slope_up * 0.28
	body.basis = Basis(slope_right, slope_up, slope)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.56, low.distance_to(high) + 5.0)
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


static func _build_landmark_terraces(parent: Node3D) -> void:
	for court in [["WelcomeCourt", Vector3(-210,0.16,18), 14.0, "path", 28],
		["GuardianGarden", Vector3(-200,0.16,-28), 10.0, "ivory", 20],
		["ArrivalBloomCourt", Vector3(-170,0.16,0), 8.0, "path", 16],
		["ComfortSpringCourt", Vector3(-135,0.16,42), 8.0, "path", 16],
		["SongOverlook", Vector3(-135,0.16,-45), 12.0, "ivory", 20],
		["PlanterCourt", PLANTER_COURT + Vector3.UP * 0.16, 25.0, "path", 32],
		["ListeningBlossomCourt", Vector3(105,2.16,0), 15.0, "ivory", 28],
		["DrumLawn", DRUM_LAWN + Vector3.UP * 0.16, 24.0, "path", 32],
		["EchoMothGarden", CLEARING_A + Vector3.UP * 0.16, 28.0, "blight", 32],
		["MothSlimeGarden", CLEARING_B + Vector3.UP * 0.16, 36.0, "blight", 40],
		["RestoredOverlook", OVERLOOK + Vector3.UP * 0.16, 19.0, "ivory", 28]]:
		_court(parent, court[0], court[1], float(court[2]), court[3], int(court[4]))
	for pool in [[Vector3(-210,0.28,18), 4.5], [Vector3(-135,0.28,42), 4.0],
		[Vector3(105,2.28,0), 10.5], [Vector3(230,2.28,-18), 5.0],
		[Vector3(300,2.28,66), 6.0]]:
		Kit.cylinder(parent, "LilyPool", pool[0], float(pool[1]), 0.12, "blue", false, 24)
		for index in 6:
			var angle := TAU * float(index) / 6.0
			Kit.facet(parent, "LilyPad", pool[0] + Vector3(cos(angle) * float(pool[1]) * 0.58,
				0.16, sin(angle) * float(pool[1]) * 0.58), Vector3(0.75, 0.12, 0.55), "leaf_light")
	for spec in [[PLANTER_COURT, 22.0], [Vector3(105,2,0), 13.0], [DRUM_LAWN, 21.0], [OVERLOOK, 16.0]]:
		for index in 16:
			var angle := TAU * float(index) / 16.0
			Kit.facet(parent, "PetalMosaic", spec[0] + Vector3(cos(angle) * float(spec[1]), 0.42,
				sin(angle) * float(spec[1])), Vector3(0.72, 0.18, 0.46),
				"pink" if index % 2 == 0 else "leaf_light")


static func _build_district_transition_collision(parent: Node3D) -> void:
	# The two broad districts overlap visually, but their simplified support slabs
	# differ by two metres. This wide approach lifts the player before the raised
	# slab begins, so every authored route into the planter court stays walkable.
	var slope_body := StaticBody3D.new()
	slope_body.name = "QuietToGardenSlopeCollision"
	var slope_angle := atan2(2.0, 24.0)
	var slope_normal := Vector3(-sin(slope_angle), cos(slope_angle), 0.0)
	slope_body.position = Vector3(-30.0, 1.0, 0.0) - slope_normal * 0.24
	slope_body.rotation.z = slope_angle
	var slope_collision := CollisionShape3D.new()
	var slope_shape := BoxShape3D.new()
	slope_shape.size = Vector3(24.5, 0.48, 90.0)
	slope_collision.shape = slope_shape
	slope_body.add_child(slope_collision)
	parent.add_child(slope_body)
	var landing := StaticBody3D.new()
	landing.name = "GardenTransitionLandingCollision"
	landing.position = Vector3(-11.0, 1.90, 0.0)
	var landing_collision := CollisionShape3D.new()
	var landing_shape := BoxShape3D.new()
	landing_shape.size = Vector3(15.0, 0.20, 90.0)
	landing_collision.shape = landing_shape
	landing.add_child(landing_collision)
	parent.add_child(landing)


static func _court(parent: Node3D, label: String, at: Vector3, radius: float, color: String, sides: int) -> void:
	Kit.cylinder(parent, label, at, radius, 0.28, color, false, sides)
	Kit.cylinder(parent, label + "InnerGrass", at + Vector3.UP * 0.17, radius * 0.73,
		0.12, "grass", false, sides)


static func _build_waterfalls(parent: Node3D) -> void:
	for z in [-42.0, -28.0, 28.0, 43.0]:
		var top := Vector3(294, -3.0, z)
		Kit.box(parent, "GardenWaterfall", top, Vector3(3.5, 23.0, 0.34), "blue", false)
		Kit.branch(parent, "WaterfallRoot", top + Vector3(0, 9, -2.0), top + Vector3(0, -8, 1.4), 0.30, "wood")
	for index in 8:
		Kit.facet(parent, "FloatingCliffRock", Vector3(315.0 + float(index % 2) * 3.0,
			-16.0 - float(index % 3) * 4.0, -26.0 + float(index) * 7.5), Vector3(3.0, 5.0, 3.8), "rock")


static func _build_dressing(parent: Node3D) -> void:
	var tree_points := [
		Vector3(-242,0,-48), Vector3(-232,0,54), Vector3(-210,0,-52), Vector3(-190,0,58),
		Vector3(-165,0,-62), Vector3(-145,0,66), Vector3(-118,0,-75), Vector3(-92,0,78),
		Vector3(-65,0,-82), Vector3(-38,0,88), Vector3(-10,1,-86), Vector3(18,1,92),
		Vector3(42,2,-94), Vector3(66,2,97), Vector3(92,2,-100), Vector3(125,2,104),
		Vector3(150,2,-108), Vector3(180,2,108), Vector3(212,2,-104), Vector3(235,2,102),
		Vector3(265,2,-92), Vector3(282,2,94), Vector3(304,2,-64), Vector3(310,2,48)]
	for index in tree_points.size():
		var source: PackedScene = [TreeModel, TreeModelA, TreeModelB][index % 3]
		var tree := source.instantiate() as Node3D
		tree.name = "FacetedTree%02d" % index
		tree.position = tree_points[index]
		tree.scale = Vector3.ONE * (0.90 + float(index % 4) * 0.14)
		parent.add_child(tree)
		Kit.cylinder_collider(parent, "TreeTrunkCollision%02d" % index, tree_points[index] + Vector3.UP * 2.5, 0.85, 5.0)
	for cell_x in 8:
		for cell_z in 4:
			_add_foliage_cell(parent, Vector3(-240.0 + float(cell_x) * 75.0, 0.7,
				-105.0 + float(cell_z) * 70.0), cell_x * 4 + cell_z)
	for point in [Vector3(-226,0.8,25), Vector3(-186,0.8,-34), Vector3(-137,0.8,42),
		Vector3(-76,0.8,-50), Vector3(-42,0.8,54), Vector3(5,1.8,-42), Vector3(38,2.8,52),
		Vector3(82,2.8,-54), Vector3(126,2.8,52), Vector3(218,2.8,20), Vector3(275,2.8,-42), Vector3(288,2.8,38)]:
		# These small rocks frame routes but are not architectural barriers. Keeping
		# them non-solid prevents the player capsule from being wedged between a
		# decorative facet and the nearby court or floor collision.
		Kit.facet(parent, "GardenRock", point, Vector3(2.4, 1.5, 1.9), "rock", false)


static func _add_foliage_cell(parent: Node3D, center: Vector3, seed: int) -> void:
	var bank := MultiMeshInstance3D.new()
	bank.name = "FoliageCell_%02d" % seed
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = Kit.facet_mesh(Vector3(0.78, 0.34, 0.58))
	multimesh.instance_count = 18
	for index in 18:
		var offset := Vector3(float((index * 17 + seed * 7) % 43) - 21.0, 0.0, float((index * 11 + seed * 13) % 37) - 18.0)
		multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.UP, float(index) * 0.73), center + offset))
		multimesh.set_instance_color(index, Color("eaa0b6") if index % 5 == 0 else (Color("82c8d5") if index % 7 == 0 else Color("b4cd70")))
	bank.multimesh = multimesh
	bank.material_override = Kit.material("pink")
	parent.add_child(bank)


static func _build_shortcut(parent: Node3D) -> Array:
	var shortcut := Node3D.new()
	shortcut.name = "SeedCanopyCutthrough"
	parent.add_child(shortcut)
	_add_path(shortcut, Vector3(-12, 1, 18), Vector3(102, 2, 22), 4.0, [])
	for index in 5:
		var x := 10.0 + float(index) * 19.0
		for side in [-1.0, 1.0]:
			Kit.branch(shortcut, "CanopyRoot", Vector3(x, 0.5, 22.0 + side * 2.8), Vector3(x, 6.0, 22.0 + side * 2.8), 0.42, "wood", true)
		Kit.branch(shortcut, "CanopyCrown", Vector3(x, 6.0, 19.2), Vector3(x, 6.0, 24.8), 0.42, "leaf")
	var blocker := Kit.box(parent, "SeedCanopyBarrier", Vector3(46, 2.2, 22), Vector3(1.2, 4.2, 6.6), "leaf", true)
	return [shortcut, blocker]


static func _build_departure(parent: Node3D) -> Array:
	var bridge := Node3D.new()
	bridge.name = "RestoredRootCrossing"
	parent.add_child(bridge)
	var authored := VineBridgeModel.instantiate() as Node3D
	authored.name = "AuthoredVineBridge"
	authored.position = Vector3(334, 3.2, 0)
	authored.scale = Vector3.ONE * 1.85
	bridge.add_child(authored)
	for index in 15:
		Kit.box(bridge, "IvoryRootBridgeDeck", Vector3(305 + float(index) * 4.0, 2.70, 0), Vector3(4.15, 0.55, 6.0), "ivory")
	# One continuous primitive prevents the production capsule catching on the
	# decorative plank seams and keeps both bridge thresholds flush with the lawns.
	Kit.box_collider(bridge, "ContinuousRootBridgeCollision", Vector3(335, 2.70, 0),
		Vector3(130.0, 0.55, 6.0))
	for side in [-1.0, 1.0]:
		Kit.branch(bridge, "BridgeRootRail", Vector3(305, 4.7, side * 2.45), Vector3(365, 4.7, side * 2.45), 0.32, "wood", true)
		for index in 5:
			Kit.branch(bridge, "BridgeFlowerVine", Vector3(311 + float(index) * 12.0, 4.7, side * 2.45), Vector3(311 + float(index) * 12.0, 5.9, side * 1.6), 0.16, "leaf")
	_court(parent, "RiverOverlook", Vector3(285, 3.15, 0), 19.0, "ivory", 28)
	var blocker := Kit.box(parent, "FutureRiverBarrier", Vector3(367, 5.3, 0), Vector3(1.0, 5.0, 8.0), "leaf", true)
	for side in [-1.0, 1.0]:
		Kit.branch(parent, "ClosedVineArch", Vector3(367, 3.0, side * 3.5), Vector3(367, 8.4, 0), 0.48, "wood", true)
	Kit.sign_text(parent, "RIVER VOICE", Vector3(350, 8.6, 0), 24)
	return [bridge, blocker]


static func _build_recovery_volume(parent: Node3D) -> void:
	var area := Area3D.new()
	area.name = "FallRecoveryVolume"
	area.position = Vector3(45, -21, 0)
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(760, 12, 390)
	shape.shape = box
	area.add_child(shape)
	parent.add_child(area)
