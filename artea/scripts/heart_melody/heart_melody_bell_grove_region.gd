class_name HeartMelodyBellGroveRegion
extends RefCounted

const Kit := preload("res://scripts/heart_melody/heart_nature_kit.gd")

const CENTER := Vector3(790, 3, 0)
const RADII := Vector2(142, 108)
const CHIMES := Vector3(700, 3, 20)
const MOON_GROVE := Vector3(748, 3, -48)
const WARNING_PATH := Vector3(795, 3, 20)
const LOOM := Vector3(885, 3, 0)


static func build(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "BellGrovePeaceGardenRegion"
	parent.add_child(root)
	_build_foundation(root)
	Kit.box(root, "BellGroveArrivalDeck", Vector3(655, 2.70, 23), Vector3(60, 0.55, 30), "ivory")
	Kit.box_collider(root, "BellGroveArrivalCollision", Vector3(655, 2.70, 23), Vector3(60, 0.55, 30))
	var routes: Array = []
	for route in [
		[Vector3(642, 3, 28), Vector3(670, 3, 18), CHIMES, Vector3(750, 3, 18), WARNING_PATH, LOOM],
		[Vector3(670, 3, 18), MOON_GROVE], [WARNING_PATH, Vector3(820, 3, -35), LOOM],
	]:
		for index in route.size() - 1:
			_path(root, route[index], route[index + 1], 7.0, routes)
	var chime_result := _build_chimes(root)
	var warning_result := _build_warning_path(root)
	var loom_result := _build_loom(root)
	var moon_fruit := _build_moon_grove(root)
	_build_dressing(root)
	return {"root": root, "route_segments": routes, "chime_heads": chime_result.chime_heads,
		"bridge_growth": chime_result.bridge_growth, "warning_pulses": warning_result,
		"loom_tracks": loom_result, "moon_fruit": moon_fruit}


static func _build_foundation(parent: Node3D) -> void:
	for sector in 8:
		Kit.ellipse_sector(parent, "PeaceCliffSector%02d" % sector, CENTER + Vector3.DOWN * 16,
			RADII, 34.0, TAU * float(sector) / 8.0, TAU * float(sector + 1) / 8.0,
			"stone", false, 0.54, 12)
	Kit.ellipse_sector(parent, "PeaceIvoryDeck", CENTER + Vector3.DOWN * 0.38, RADII,
		0.76, 0, TAU, "ivory", false, 0.995, 72)
	Kit.ellipse_sector(parent, "PeaceGrassTop", CENTER + Vector3.UP * 0.03,
		RADII * Vector2(0.90, 0.86), 0.12, 0, TAU, "grass", false, 0.995, 72)
	for z_index in 5:
		var z_fraction := -0.72 + float(z_index) * 0.36
		var half_width := RADII.x * sqrt(maxf(0.1, 1.0 - z_fraction * z_fraction))
		Kit.box_collider(parent, "PeaceContinuousDeckCollision",
			Vector3(CENTER.x, CENTER.y - 0.1, CENTER.z + z_fraction * RADII.y),
			Vector3(half_width * 2.0, 0.2, RADII.y * 0.43))
	for index in 44:
		var angle := TAU * float(index) / 44.0
		var at := CENTER + Vector3(cos(angle) * (RADII.x - 3), 0, sin(angle) * (RADII.y - 3))
		# Leave a generous break in the cliff posts where the River Voice deck
		# overlaps the new island. The opening stays wider than the visual path so
		# the production capsule cannot catch a post while the camera is turning.
		if at.x < 680 and absf(at.z - 22) < 27: continue
		if index % 2 == 0:
			Kit.box(parent, "PeaceEdgePost", at + Vector3.UP * 0.8, Vector3(0.8, 1.6, 0.8), "ivory", true)


static func _path(parent: Node3D, a: Vector3, b: Vector3, width: float, routes: Array) -> void:
	routes.append([a, b])
	var forward := (b - a).normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var slab := Kit.box(parent, "PeacePearlPath", (a + b) * 0.5 + Vector3.UP * 0.17,
		Vector3(width, 0.28, a.distance_to(b)), "path")
	slab.basis = Basis(right, Vector3.UP, forward)


static func _court(parent: Node3D, name_value: String, at: Vector3, radius: float) -> void:
	Kit.cylinder(parent, name_value, at + Vector3.UP * 0.16, radius, 0.28, "ivory", false, 20)
	Kit.cylinder(parent, name_value + "Garden", at + Vector3.UP * 0.34, radius * 0.72, 0.12, "grass", false, 20)


static func _build_chimes(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "HarmonyBridgeChimeCourt"
	parent.add_child(root)
	_court(root, "ChimeCourt", CHIMES, 25.0)
	var heads: Array[MeshInstance3D] = []
	for index in 3:
		var z := CHIMES.z + float(index - 1) * 11.0
		for side in [-1.0, 1.0]:
			Kit.branch(root, "ChimeArchRoot", Vector3(CHIMES.x - 5.5, CHIMES.y, z + side * 3.8),
				Vector3(CHIMES.x - 5.5, CHIMES.y + 10, z + side * 3.8), 0.7, "wood", true)
		Kit.branch(root, "ChimeArchCrown", Vector3(CHIMES.x - 5.5, CHIMES.y + 10, z - 3.8),
			Vector3(CHIMES.x - 5.5, CHIMES.y + 10, z + 3.8), 0.65, "wood")
		var head := Kit.facet(root, "HarmonyChime%02d" % index,
			Vector3(CHIMES.x - 5.5, CHIMES.y + 6.8, z), Vector3(1.8, 3.0, 1.8), "gold")
		heads.append(head)
	var growth: Array[Node3D] = []
	for index in 3:
		var section := Node3D.new()
		section.name = "VineBridgeGrowth%02d" % index
		root.add_child(section)
		var x := 711.0 + float(index) * 10.0
		Kit.box(section, "LivingBridgeDeck", Vector3(x, 4.1, 20), Vector3(10.2, 0.5, 7.0), "wood", true)
		for side in [-1.0, 1.0]:
			Kit.branch(section, "LivingBridgeRail", Vector3(x - 5, 5.5, 20 + side * 3),
				Vector3(x + 5, 5.5, 20 + side * 3), 0.3, "leaf", true)
		growth.append(section)
	Kit.sign_text(root, "HARMONY BRIDGE CHIMES\nAIM • WATCH THE WIND • STRIKE", CHIMES + Vector3(0, 16, 0), 22)
	return {"chime_heads": heads, "bridge_growth": growth}


static func _build_warning_path(parent: Node3D) -> Array:
	var root := Node3D.new()
	root.name = "FearWarningBellPath"
	parent.add_child(root)
	var pulses: Array[MeshInstance3D] = []
	for step in 4:
		var x := 765.0 + float(step) * 20.0
		for lane in 3:
			var z := 10.0 + float(lane) * 10.0
			var pulse := Kit.facet(root, "GroundRipple_%02d_%02d" % [step, lane],
				Vector3(x, 4.42, z), Vector3(5.4, 0.12, 3.5), "blue")
			pulse.set_meta("step", step)
			pulse.set_meta("lane", lane)
			pulses.append(pulse)
		Kit.branch(root, "WarningReed%02d" % step, Vector3(x, 3, 34), Vector3(x, 12, 34), 0.46, "leaf", true)
		Kit.facet(root, "WarningBell%02d" % step, Vector3(x, 14, 34), Vector3(2, 2.3, 2), "pink")
	Kit.flower(root, Vector3(758, 4.8, 20), 2.0, "ivory")
	Kit.sign_text(root, "WARNING BELL PATH\nMOVE THROUGH THE QUIET GAPS", WARNING_PATH + Vector3(0, 14, 0), 22)
	return pulses


static func _build_loom(parent: Node3D) -> Array:
	var root := Node3D.new()
	root.name = "HeartSongLoomSanctuary"
	parent.add_child(root)
	_court(root, "HeartSongLoomCourt", LOOM, 27.0)
	for side in [-1.0, 1.0]:
		Kit.branch(root, "LoomRootArch", LOOM + Vector3(-10, 0, side * 8),
			LOOM + Vector3(0, 14, side * 8), 0.9, "wood", true)
		Kit.branch(root, "LoomRootArch", LOOM + Vector3(0, 14, side * 8),
			LOOM + Vector3(10, 0, side * 8), 0.9, "wood", true)
	var tracks: Array[MeshInstance3D] = []
	for index in 4:
		var track := Kit.box(root, "MotifTrack%02d" % index,
			LOOM + Vector3(-6 + float(index) * 4, 5 + float(index) * 1.4, 0),
			Vector3(2.0, 0.45, 13.0), ["pink", "blue", "leaf_light", "gold"][index])
		tracks.append(track)
	Kit.facet(root, "LoomHeartLens", LOOM + Vector3(0, 10, 0), Vector3(4, 4.5, 1.2), "ivory")
	Kit.sign_text(root, "HEART SONG LOOM\nDRUM • WATER • HARP • CHIME", LOOM + Vector3(0, 17, 0), 23)
	return tracks


static func _build_moon_grove(parent: Node3D) -> Array:
	var root := Node3D.new()
	root.name = "MoonMelonPeaceGrove"
	parent.add_child(root)
	var fruits: Array[MeshInstance3D] = []
	for index in 3:
		var x := MOON_GROVE.x + float(index - 1) * 6.0
		Kit.branch(root, "MoonVine%02d" % index, Vector3(x, 3, MOON_GROVE.z),
			Vector3(x + 2, 7, MOON_GROVE.z), 0.38, "leaf", true)
		var fruit := Kit.facet(root, "MoonMelonFruit%02d" % index,
			Vector3(x + 2, 7, MOON_GROVE.z + 1.4), Vector3(1.7, 1.25, 1.45), "ivory")
		fruit.set_meta("fruit_id", "moon_melon")
		fruits.append(fruit)
	Kit.sign_text(root, "MOON MELONS\nCALM • SUSTAIN", MOON_GROVE + Vector3.UP * 11, 21)
	return fruits


static func _build_dressing(parent: Node3D) -> void:
	for index in 14:
		var angle := TAU * float(index) / 14.0
		Kit.tree(parent, CENTER + Vector3(cos(angle) * 111, 0, sin(angle) * 78),
			0.72 + float(index % 3) * 0.12)
	for index in 18:
		Kit.flower(parent, Vector3(676 + float((index * 29) % 220), 4.7,
			-62 + float((index * 17) % 124)), 0.58, "pink" if index % 2 == 0 else "leaf_light")
