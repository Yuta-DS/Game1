class_name HeartGardenLayout
extends RefCounted

const Kit := preload("res://scripts/heart_melody/heart_nature_kit.gd")
const TreeModel := preload("res://assets3D/heart_melody/island_one/glb/faceted_tree.glb")
const TreeModelA := preload("res://assets3D/heart_melody/island_one/glb/faceted_tree_a.glb")
const TreeModelB := preload("res://assets3D/heart_melody/island_one/glb/faceted_tree_b.glb")
const VineBridgeModel := preload("res://assets3D/heart_melody/island_one/glb/growing_vine_bridge.glb")

const QUIET_CENTER := Vector3(-43, 0, 0)
const QUIET_RADII := Vector2(53, 48)
const GARDEN_CENTER := Vector3(42, 0, 0)
const GARDEN_RADII := Vector2(60, 52)
const ROUTE := [
	Vector3(-88, 0, 0), Vector3(-72, 0, 0), Vector3(-58, 0, 0),
	Vector3(-40, 0, 0), Vector3(-10, 0, 0), Vector3(10, 0, 0),
	Vector3(38, 0, 0), Vector3(50, 0, -5), Vector3(58, 0, -20),
	Vector3(66, 0, -5), Vector3(74, 0, 18), Vector3(84, 0, 7),
	Vector3(94, 0, 0),
]


static func build(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "HeartGardenLayout"
	parent.add_child(root)
	_build_district(root, "QuietMeadow", QUIET_CENTER, QUIET_RADII, 0.0, 12.0, GARDEN_CENTER, GARDEN_RADII)
	_build_district(root, "FeelingGarden", GARDEN_CENTER, GARDEN_RADII, 0.0, 14.0, QUIET_CENTER, QUIET_RADII)
	var routes: Array = []
	for index in ROUTE.size() - 1:
		_add_path(root, ROUTE[index], ROUTE[index + 1], 4.0, routes)
	for branch in [
		[Vector3(-72, 0, 0), Vector3(-62, 0, -10), Vector3(-56, 0, -11)],
		[Vector3(-58, 0, 0), Vector3(-38, 0, -19), Vector3(-6, 0, -8),
			Vector3(-24, 0, 19), Vector3(-48, 0, 18), Vector3(-58, 0, 0)],
		[Vector3(10, 0, 0), Vector3(24, 0, -16), Vector3(38, 0, 0),
			Vector3(24, 0, 16), Vector3(10, 0, 0)],
	]:
		for index in branch.size() - 1:
			_add_path(root, branch[index], branch[index + 1], 3.0, routes)
	_build_clearings(root)
	_build_perimeter(root, QUIET_CENTER, QUIET_RADII, GARDEN_CENTER, GARDEN_RADII, false)
	_build_perimeter(root, GARDEN_CENTER, GARDEN_RADII, QUIET_CENTER, QUIET_RADII, true)
	_build_dressing(root)
	var canopy := _build_shortcut(root)
	var departure := _build_departure(root)
	_build_recovery_volume(root)
	return {
		"root": root,
		"route_segments": routes,
		"seed_shortcut": canopy[0],
		"seed_shortcut_blocker": canopy[1],
		"bridge": departure[0],
		"bridge_blocker": departure[1],
	}


static func _build_district(parent: Node3D, label: String, center: Vector3, radii: Vector2,
		top_y: float, depth: float, other_center: Vector3, other_radii: Vector2) -> void:
	var district := Node3D.new()
	district.name = label
	parent.add_child(district)
	for sector_index in 6:
		var sector := Node3D.new()
		sector.name = "Sector%02d" % (sector_index + 1)
		district.add_child(sector)
		var start := TAU * float(sector_index) / 6.0
		var finish := TAU * float(sector_index + 1) / 6.0
		var horizontal_center := Vector3(center.x, 0, center.z)
		Kit.ellipse_sector(sector, "FacetedFoundation", horizontal_center + Vector3(0, top_y - depth * 0.5 - 0.6, 0),
			radii, depth, start, finish, "stone", false, 0.57, 10)
		sector.set_meta("heart_cull_sector", sector_index)
		sector.set_meta("district", label)
	Kit.ellipse_sector(district, "ContinuousGrassTop", Vector3(center.x, top_y - 0.2, center.z),
		radii, 0.4, 0.0, TAU, "grass", false, 0.99, 48)
	_add_ellipse_collision(district, center, radii, top_y)


static func _add_ellipse_collision(parent: Node3D, center: Vector3, radii: Vector2, top_y: float) -> void:
	var body := StaticBody3D.new()
	body.name = "ContinuousDeckCollision"
	var collision := CollisionShape3D.new()
	var floor_hull := BoxShape3D.new()
	# The box spans the full visible diameter. The authored ellipse railing keeps
	# the inaccessible rectangular corners outside the playable boundary.
	floor_hull.size = Vector3(radii.x * 2.0, 1.0, radii.y * 2.0)
	body.position = Vector3(center.x, top_y - 0.5, center.z)
	collision.shape = floor_hull
	body.add_child(collision)
	parent.add_child(body)


static func _build_perimeter(parent: Node3D, center: Vector3, radii: Vector2,
		other_center: Vector3, other_radii: Vector2, east_exit: bool) -> void:
	var points: Array[Vector3] = []
	for index in 36:
		var angle := TAU * float(index) / 36.0
		points.append(center + Vector3(cos(angle) * (radii.x - 2.2), 0,
			sin(angle) * (radii.y - 2.2)))
	for index in points.size():
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		var middle := (a + b) * 0.5
		if _inside_ellipse(middle, other_center, other_radii, 0.91):
			continue
		if east_exit and middle.x > 91 and absf(middle.z) < 8:
			continue
		Kit.branch(parent, "GoldRail", a + Vector3.UP * 1.2, b + Vector3.UP * 1.2, 0.16, "gold", true)
		Kit.box(parent, "IvoryRailPost", a + Vector3.UP * 0.65, Vector3(0.72, 1.3, 0.72), "ivory", true)
		if index % 3 == 0:
			var inward := (center - middle).normalized()
			var left := middle + (b - a).normalized() * 1.15
			var right := middle - (b - a).normalized() * 1.15
			for point in [left, right]:
				Kit.box(parent, "ArchPier", point + Vector3.UP * 1.5, Vector3(0.55, 3.0, 0.55), "ivory")
			Kit.branch(parent, "ArchCrown", left + Vector3.UP * 3.0, right + Vector3.UP * 3.0, 0.32, "ivory")
			Kit.branch(parent, "RootButtress", middle - inward + Vector3.DOWN * 5.0,
				middle + Vector3.UP * 0.2, 0.34, "wood")


static func _inside_ellipse(point: Vector3, center: Vector3, radii: Vector2, scale_value: float) -> bool:
	var dx := (point.x - center.x) / (radii.x * scale_value)
	var dz := (point.z - center.z) / (radii.y * scale_value)
	return dx * dx + dz * dz < 1.0


static func _add_path(parent: Node3D, a: Vector3, b: Vector3, width: float, routes: Array) -> void:
	routes.append([a, b])
	var is_transition_ramp := absf(a.y - b.y) > 0.1
	var slab := Kit.box(parent, "PetalPath", (a + b) * 0.5 + Vector3.UP * 0.10,
		Vector3(width, 0.18, a.distance_to(b)), "path", false)
	var forward := (b - a).normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var path_up := forward.cross(right).normalized()
	slab.basis = Basis(right, path_up, forward)
	if is_transition_ramp:
		_add_stair_ramp(parent, a, b, width)


static func _add_stair_ramp(parent: Node3D, a: Vector3, b: Vector3, width: float) -> void:
	width = maxf(width, 4.0)
	var low := a if a.y < b.y else b
	var high := b if a.y < b.y else a
	var direction := Vector3(high.x - low.x, 0, high.z - low.z)
	var length := direction.length()
	direction = direction.normalized()
	var right := Vector3.UP.cross(direction).normalized()
	var steps := 6
	var step_length := length / float(steps)
	for index in steps:
		var top_y := lerpf(low.y, high.y, float(index + 1) / steps)
		var height := top_y - low.y + 0.08
		var centre := Vector3(low.x, low.y - 0.04 + height * 0.5, low.z) \
			+ direction * step_length * (float(index) + 0.5)
		var step := Kit.box(parent, "IvoryRampStep", centre,
			Vector3(width, height, step_length + 0.12), "path", true)
		step.basis = Basis(right, Vector3.UP, direction)


static func _build_clearings(parent: Node3D) -> void:
	Kit.cylinder(parent, "PlanterCourt", Vector3(-25, 0.10, 0), 23, 0.16, "path", false, 24)
	Kit.cylinder(parent, "DrumLawn", Vector3(27, 0.10, 0), 20, 0.16, "path", false, 24)
	Kit.cylinder(parent, "EchoMothClearing", Vector3(58, 0.12, -20), 14, 0.20, "path", false, 20)
	Kit.cylinder(parent, "MothSlimeClearing", Vector3(74, 0.12, 18), 14, 0.20, "path", false, 20)
	Kit.cylinder(parent, "QuietPool", Vector3(-68, 0.12, 25), 6.5, 0.16, "blue", false, 16)
	for court in [[Vector3(-25,0,0), 21.0], [Vector3(27,0,0), 18.0]]:
		for index in 16:
			if index in [0, 4, 8, 12]: continue
			var angle := TAU * float(index) / 16.0
			var point: Vector3 = court[0] + Vector3(cos(angle) * court[1], 0.36,
				sin(angle) * court[1])
			Kit.facet(parent, "CourtPetalBorder", point, Vector3(0.55, 0.28, 0.4),
				"pink" if index % 2 == 0 else "leaf_light")
	for clearing in [Vector3(58, 0.15, -20), Vector3(74, 0.15, 18)]:
		for index in 12:
			var angle := TAU * float(index) / 12.0
			var radius := 12.5
			Kit.facet(parent, "RecoveryPetal", clearing + Vector3(cos(angle) * radius, 0.35,
				sin(angle) * radius), Vector3(0.8, 0.35, 0.5), "leaf_light")


static func _build_dressing(parent: Node3D) -> void:
	var tree_points := [
		Vector3(-84, 0, -28), Vector3(-78, 0, 31), Vector3(-61, 0, -38),
		Vector3(-48, 0, 38), Vector3(-25, 0, -40), Vector3(-5, 0.6, 39),
		Vector3(15, 0.6, -42), Vector3(34, 0.6, 40), Vector3(51, 0.6, -42),
		Vector3(67, 0.6, 42), Vector3(86, 0.6, -31), Vector3(90, 0.6, 28),
	]
	for index in tree_points.size():
		var source: PackedScene = [TreeModel, TreeModelA, TreeModelB][index % 3]
		var tree := source.instantiate() as Node3D
		tree.name = "FacetedTree%02d" % index
		tree.position = tree_points[index]
		tree.scale = Vector3.ONE * (0.75 + float(index % 3) * 0.12)
		parent.add_child(tree)
		Kit.cylinder_collider(parent, "TreeTrunkCollision%02d" % index,
			tree_points[index] + Vector3.UP * 2.1, 0.7, 4.2)
	var garden_bank := MultiMeshInstance3D.new()
	garden_bank.name = "SparseGardenDressing"
	var garden_multimesh := MultiMesh.new()
	garden_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	garden_multimesh.use_colors = true
	garden_multimesh.mesh = Kit.facet_mesh(Vector3(0.65, 0.3, 0.5))
	garden_multimesh.instance_count = 18
	for index in 18:
		var angle := TAU * float(index) / 18.0
		var centre := QUIET_CENTER if index < 8 else GARDEN_CENTER
		var radii := QUIET_RADII if index < 8 else GARDEN_RADII
		var at := centre + Vector3(cos(angle) * radii.x * 0.76, 0.7,
			sin(angle) * radii.y * 0.76)
		garden_multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, at))
		garden_multimesh.set_instance_color(index,
			Color("eaa0b6") if index % 3 == 0 else Color("b4cd70"))
	garden_bank.multimesh = garden_multimesh
	garden_bank.material_override = Kit.material("ivory")
	parent.add_child(garden_bank)
	for point in [Vector3(-82, 1.2, 24), Vector3(-64, 1.2, -34), Vector3(-8, 1.4, 37),
		Vector3(16, 1.4, -38), Vector3(51, 1.4, 38), Vector3(88, 1.4, 24)]:
		Kit.facet(parent, "GardenRock", point, Vector3(1.8, 1.3, 1.5), "rock", true)


static func _build_shortcut(parent: Node3D) -> Array:
	var shortcut := Node3D.new()
	shortcut.name = "SeedCanopyCutthrough"
	parent.add_child(shortcut)
	_add_path(shortcut, Vector3(-41, 0, 6), Vector3(7, 0, 10), 3.0, [])
	for side in [-1.0, 1.0]:
		Kit.branch(shortcut, "CanopyRoot", Vector3(-17, 0, 8.0 + side * 1.8),
			Vector3(-17, 4.5, 8.0 + side * 1.8), 0.34, "wood", true)
	Kit.branch(shortcut, "CanopyCrown", Vector3(-17, 4.5, 6.2), Vector3(-17, 4.5, 9.8), 0.34, "leaf")
	var blocker := Kit.box(parent, "SeedCanopyBarrier", Vector3(-17, 1.6, 8),
		Vector3(0.7, 3.2, 4.2), "leaf", true)
	return [shortcut, blocker]


static func _build_departure(parent: Node3D) -> Array:
	var bridge := Node3D.new()
	bridge.name = "RestoredRootCrossing"
	parent.add_child(bridge)
	var authored := VineBridgeModel.instantiate() as Node3D
	authored.name = "AuthoredVineBridge"
	authored.position = Vector3(101.5, 0.6, 0)
	authored.scale = Vector3.ONE * 0.6
	bridge.add_child(authored)
	for index in 8:
		Kit.box(bridge, "RootBridgeDeck", Vector3(95 + index * 2.0, 0.6, 0),
			Vector3(2.1, 0.45, 4.0), "wood", true)
	for side in [-1.0, 1.0]:
		Kit.branch(bridge, "BridgeRoot", Vector3(94, 2.1, side * 1.9),
			Vector3(110, 2.1, side * 1.9), 0.24, "wood", true)
	Kit.cylinder(parent, "RiverOverlook", Vector3(116, 0.0, 0), 7, 1.2, "grass", true, 16)
	var blocker := Kit.box(parent, "FutureRiverBarrier", Vector3(122, 2.5, 0),
		Vector3(0.8, 5.0, 8.0), "leaf", true)
	for side in [-1.0, 1.0]:
		Kit.branch(parent, "ClosedVineArch", Vector3(122, 0.6, side * 3.4),
			Vector3(122, 5.2, 0), 0.38, "wood", true)
	Kit.sign_text(parent, "RIVER SONG\nCOMING NEXT", Vector3(116, 4.2, 0), 24)
	return [bridge, blocker]


static func _build_recovery_volume(parent: Node3D) -> void:
	var area := Area3D.new()
	area.name = "FallRecoveryVolume"
	area.position = Vector3(10, -18, 0)
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(260, 8, 170)
	shape.shape = box
	area.add_child(shape)
	parent.add_child(area)
