class_name HeartMelodyRiverRegion
extends RefCounted

const Kit := preload("res://scripts/heart_melody/heart_nature_kit.gd")

const CENTER := Vector3(520, 3, 0)
const RADII := Vector2(158, 112)
const ORGAN := Vector3(430, 3, -28)
const DEW_GROVE := Vector3(402, 3, 34)
const HARP := Vector3(525, 3, 34)
const SUN_GROVE := Vector3(500, 3, -45)
const BELL_GROVE := Vector3(610, 3, -32)
const BELLS := Vector3(642, 3, 28)


static func build(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "RiverVoiceRegion"
	parent.add_child(root)
	_build_foundation(root)
	var routes: Array = []
	for route in [
		[Vector3(365, 3, 0), Vector3(392, 3, 0), ORGAN, Vector3(475, 3, 0), HARP],
		[Vector3(392, 3, 0), DEW_GROVE], [ORGAN, SUN_GROVE],
		[HARP, BELL_GROVE], [HARP, BELLS], [BELL_GROVE, BELLS],
	]:
		for index in route.size() - 1:
			_path(root, route[index], route[index + 1], 7.0, routes)
	var result := {"root": root, "route_segments": routes}
	result.merge(_build_organ(root), true)
	result.merge(_build_harp(root), true)
	result.merge(_build_bells(root), true)
	result["fruit"] = _build_fruit_groves(root)
	_build_dressing(root)
	return result


static func _build_foundation(parent: Node3D) -> void:
	for sector in 8:
		var start := TAU * float(sector) / 8.0
		var finish := TAU * float(sector + 1) / 8.0
		Kit.ellipse_sector(parent, "RiverCliffSector%02d" % sector,
			CENTER + Vector3.DOWN * 17.5, RADII, 36.0, start, finish, "stone", false, 0.52, 12)
	Kit.ellipse_sector(parent, "RiverIvoryDeck", CENTER + Vector3.DOWN * 0.38,
		RADII, 0.76, 0, TAU, "ivory", false, 0.995, 72)
	Kit.ellipse_sector(parent, "RiverGrassTop", CENTER + Vector3.UP * 0.03,
		RADII * Vector2(0.90, 0.86), 0.12, 0, TAU, "grass", false, 0.995, 72)
	for z_index in 5:
		var z_fraction := -0.72 + float(z_index) * 0.36
		var half_width := RADII.x * sqrt(maxf(0.10, 1.0 - z_fraction * z_fraction))
		Kit.box_collider(parent, "RiverContinuousDeckCollision",
			Vector3(CENTER.x, CENTER.y - 0.1, CENTER.z + z_fraction * RADII.y),
			Vector3(half_width * 2.0, 0.2, RADII.y * 0.43))
	for index in 52:
		var angle := TAU * float(index) / 52.0
		var at := CENTER + Vector3(cos(angle) * (RADII.x - 3.0), 0, sin(angle) * (RADII.y - 3.0))
		if at.x < 378 and absf(at.z) < 14.0:
			continue
		if index % 2 == 0:
			Kit.box(parent, "RiverEdgePost", at + Vector3.UP * 0.8, Vector3(0.8, 1.6, 0.8), "ivory", true)
		if index % 4 == 0:
			Kit.facet(parent, "RiverEdgeRock", at + Vector3.DOWN * 2.0, Vector3(2.4, 3.8, 2.2), "rock")


static func _path(parent: Node3D, a: Vector3, b: Vector3, width: float, routes: Array) -> void:
	routes.append([a, b])
	var forward := (b - a).normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var path := Kit.box(parent, "RiverPearlPath", (a + b) * 0.5 + Vector3.UP * 0.17,
		Vector3(width, 0.28, a.distance_to(b)), "path")
	path.basis = Basis(right, Vector3.UP, forward)


static func _court(parent: Node3D, label: String, at: Vector3, radius: float) -> void:
	Kit.cylinder(parent, label, at + Vector3.UP * 0.16, radius, 0.28, "ivory", false, 20)
	Kit.cylinder(parent, label + "Garden", at + Vector3.UP * 0.34, radius * 0.72, 0.12, "grass", false, 20)


static func _build_organ(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "WaterfallOrganSanctuary"
	parent.add_child(root)
	_court(root, "OrganCourt", ORGAN, 23.0)
	var water: Array[MeshInstance3D] = []
	for index in 3:
		var x := ORGAN.x + float(index - 1) * 8.0
		Kit.box(root, "OrganPipe%02d" % index, Vector3(x, 8.5, ORGAN.z), Vector3(5.0, 11.0, 5.0), "ivory", true)
		Kit.facet(root, "OrganPipeCrown%02d" % index, Vector3(x, 15.0, ORGAN.z), Vector3(3.2, 2.6, 3.2), "rock")
		var ribbon := Kit.box(root, "OrganWater%02d" % index, Vector3(x, 8.0, ORGAN.z + 2.65), Vector3(2.4, 9.0, 0.28), "blue")
		water.append(ribbon)
		Kit.cylinder(root, "OrganBasin%02d" % index, Vector3(x, 3.48, ORGAN.z + 4.5), 3.3, 0.42, "blue", false, 12)
		Kit.cylinder_collider(root, "OrganPipeCollision%02d" % index, Vector3(x, 8.5, ORGAN.z), 2.6, 11.0)
	Kit.sign_text(root, "WATERFALL ORGAN\nMATCH THE THREE WATER PITCHES", ORGAN + Vector3(0, 18, 0), 23)
	return {"organ_water": water}


static func _build_harp(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "HushVineHarpSanctuary"
	parent.add_child(root)
	_court(root, "HarpCourt", HARP, 22.0)
	Kit.branch(root, "HarpLeftRoot", HARP + Vector3(-10, 0, 0), HARP + Vector3(-7, 14, 0), 1.0, "wood", true)
	Kit.branch(root, "HarpCrownRoot", HARP + Vector3(-7, 14, 0), HARP + Vector3(10, 8, 0), 0.9, "wood", true)
	Kit.branch(root, "HarpFootRoot", HARP + Vector3(-10, 0, 0), HARP + Vector3(10, 0, 0), 0.8, "wood", true)
	var strings: Array[MeshInstance3D] = []
	for index in 5:
		var x := HARP.x - 5.8 + float(index) * 3.0
		var top_y := 13.5 - float(index) * 1.05
		var string := Kit.branch(root, "HealthyVineString%02d" % index,
			Vector3(x, HARP.y + 1.0, HARP.z), Vector3(x, HARP.y + top_y, HARP.z), 0.22, "leaf_light")
		strings.append(string)
		Kit.flower(root, Vector3(x, HARP.y + 0.8, HARP.z + 0.5), 0.65, "gold")
	Kit.sign_text(root, "HUSH VINE HARP\nRELEASE EACH STRING IN RISING ORDER", HARP + Vector3(0, 17, 0), 22)
	return {"harp_strings": strings}


static func _build_bells(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "RainBoatBellLanding"
	parent.add_child(root)
	_court(root, "BellLandingCourt", BELLS, 24.0)
	var bells: Array[MeshInstance3D] = []
	var points: Array[Vector3] = [Vector3(0, 0, -10), Vector3(10, 0, 0), Vector3(0, 0, 10), Vector3(-10, 0, 0)]
	for index in 4:
		var at: Vector3 = BELLS + points[index]
		Kit.branch(root, "BellStem%02d" % index, at, at + Vector3.UP * 6.0, 0.48, "leaf", true)
		var bell := Kit.facet(root, "DirectionalBell%02d" % index, at + Vector3.UP * 7.0, Vector3(2.2, 2.0, 2.2), "gold")
		bells.append(bell)
		Kit.sign_text(root, ["N", "E", "S", "W"][index], at + Vector3.UP * 10.0, 25)
	var boat := Node3D.new()
	boat.name = "RainBoat"
	boat.position = BELLS + Vector3(22, -2.5, 0)
	root.add_child(boat)
	Kit.facet(boat, "RainBoatHull", Vector3.ZERO, Vector3(8.5, 2.2, 4.0), "wood", true)
	Kit.branch(boat, "RainBoatMast", Vector3(0, 0, 0), Vector3(0, 9, 0), 0.38, "wood")
	Kit.facet(boat, "RainBoatSail", Vector3(0, 6, 0), Vector3(0.3, 4.0, 4.0), "blue")
	Kit.sign_text(root, "RAIN BOAT BELLS\nREAD THE RIPPLE CLOCKWISE", BELLS + Vector3(0, 14, 0), 23)
	return {"rain_bells": bells, "rain_boat": boat}


static func _build_fruit_groves(parent: Node3D) -> Dictionary:
	var result := {}
	for spec in [
		["DewPearGrove", "dew_pear", DEW_GROVE, 3, "blue", "DEW PEARS • PITCH"],
		["SunPlumGrove", "sun_plum", SUN_GROVE, 5, "gold", "SUN PLUMS • TEMPO"],
		["BellAppleGrove", "bell_apple", BELL_GROVE, 4, "pink", "BELL APPLES • RESONANCE"],
	]:
		var grove := Node3D.new()
		grove.name = spec[0]
		parent.add_child(grove)
		var fruit_nodes: Array[MeshInstance3D] = []
		for index in int(spec[3]):
			var angle := TAU * float(index) / float(spec[3])
			var at: Vector3 = spec[2] + Vector3(cos(angle) * 5.5, 0, sin(angle) * 5.5)
			Kit.branch(grove, "FruitTreeStem%02d" % index, at, at + Vector3.UP * 5.5, 0.55, "wood", true)
			Kit.facet(grove, "FruitTreeCrown%02d" % index, at + Vector3.UP * 6.5, Vector3(3.5, 2.8, 3.5), "leaf")
			var fruit := Kit.facet(grove, "%sFruit%02d" % [str(spec[1]).to_pascal_case(), index], at + Vector3(0, 5.6, 2.4), Vector3(0.9, 1.15, 0.9), spec[4])
			fruit.set_meta("fruit_id", spec[1])
			fruit_nodes.append(fruit)
		Kit.sign_text(grove, spec[5], spec[2] + Vector3.UP * 11.0, 20)
		result[spec[1]] = fruit_nodes
	return result


static func _build_dressing(parent: Node3D) -> void:
	for index in 18:
		var angle := TAU * float(index) / 18.0
		var at := CENTER + Vector3(cos(angle) * 122.0, 0.4, sin(angle) * 84.0)
		if at.x < 385 and absf(at.z) < 18.0:
			continue
		Kit.tree(parent, at, 0.7 + float(index % 3) * 0.12)
	for index in 14:
		var x := 390.0 + float((index * 31) % 250)
		var z := -68.0 + float((index * 23) % 136)
		Kit.flower(parent, Vector3(x, 3.7, z), 0.55, "pink" if index % 2 == 0 else "blue")
	for z in [-42.0, 0.0, 42.0]:
		Kit.box(parent, "RiverEdgeWaterfall", Vector3(672, -6, z), Vector3(2.4, 19.0, 0.4), "blue")
