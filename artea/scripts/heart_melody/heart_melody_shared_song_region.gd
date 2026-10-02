class_name HeartMelodySharedSongRegion
extends RefCounted

const Kit := preload("res://scripts/heart_melody/heart_nature_kit.gd")

const CENTER := Vector3(1070, 3, 0)
const RADII := Vector2(158, 114)
const STAGE := Vector3(1010, 3, 16)
const FIG_GROVE := Vector3(1090, 3, -58)
const SANCTUARY := Vector3(1170, 3, 10)
const GATE := Vector3(1208, 3, 10)
const ANCHOR_OFFSETS := [Vector3(-22, 0, 13), Vector3(0, 0, -25), Vector3(22, 0, 13)]


static func build(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "SharedSongRegion"
	parent.add_child(root)
	_build_foundation(root)
	var routes: Array = []
	for route in [
		[Vector3(885, 3, -14), Vector3(910, 3, -28), Vector3(940, 3, -18),
			Vector3(950, 3, 12), STAGE, SANCTUARY, GATE],
		[STAGE, FIG_GROVE, SANCTUARY],
	]:
		for index in route.size() - 1:
			_path(root, route[index], route[index + 1], 7.0 if route[0] == Vector3(885, 3, -14) else 4.5, routes)
	var stage_result := _build_harmony_stage(root)
	var fig_fruit := _build_fig_grove(root)
	var sanctuary_result := _build_sanctuary(root)
	_build_dressing(root)
	return {"root": root, "route_segments": routes, "anchor_cores": stage_result.anchor_cores,
		"anchor_pulses": stage_result.anchor_pulses, "orchestra_sockets": stage_result.orchestra_sockets,
		"shell_sections": stage_result.shell_sections, "stage_blooms": stage_result.stage_blooms,
		"fig_fruit": fig_fruit, "jewel": sanctuary_result.jewel,
		"shield": sanctuary_result.shield, "gate_light": sanctuary_result.gate_light}


static func _build_foundation(parent: Node3D) -> void:
	for sector in 8:
		Kit.ellipse_sector(parent, "SharedCliffSector%02d" % sector, CENTER + Vector3.DOWN * 17,
			RADII, 36.0, TAU * float(sector) / 8.0, TAU * float(sector + 1) / 8.0,
			"stone", false, 0.54, 12)
	Kit.ellipse_sector(parent, "SharedIvoryDeck", CENTER + Vector3.DOWN * 0.38,
		RADII, 0.76, 0, TAU, "ivory", false, 0.995, 72)
	Kit.ellipse_sector(parent, "SharedGrassTop", CENTER + Vector3.UP * 0.03,
		RADII * Vector2(0.91, 0.86), 0.12, 0, TAU, "grass", false, 0.995, 72)
	for z_index in 5:
		var z_fraction := -0.72 + float(z_index) * 0.36
		var half_width := RADII.x * sqrt(maxf(0.1, 1.0 - z_fraction * z_fraction))
		Kit.box_collider(parent, "SharedContinuousDeckCollision",
			Vector3(CENTER.x, CENTER.y - 0.1, CENTER.z + z_fraction * RADII.y),
			Vector3(half_width * 2.0, 0.2, RADII.y * 0.43))
	for index in 36:
		var angle := TAU * float(index) / 36.0
		var at := CENTER + Vector3(cos(angle) * 145, 0, sin(angle) * 98)
		if at.x < 934 and absf(at.z) < 28: continue
		if index % 2 == 0:
			Kit.facet(parent, "SharedEdgeRock", at + Vector3.DOWN * 1.3,
				Vector3(2.6, 3.4, 2.4), "rock")


static func _path(parent: Node3D, a: Vector3, b: Vector3, width: float, routes: Array) -> void:
	routes.append([a, b])
	var forward := (b - a).normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var slab := Kit.box(parent, "SharedPearlPath", (a + b) * 0.5 + Vector3.UP * 0.17,
		Vector3(width, 0.28, a.distance_to(b)), "path")
	slab.basis = Basis(right, Vector3.UP, forward)


static func _build_harmony_stage(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "HarmonyStage"
	parent.add_child(root)
	Kit.cylinder(root, "LivingAmphitheatre", STAGE + Vector3.UP * 0.24, 38, 0.48, "ivory", false, 24)
	Kit.cylinder_collider(root, "HarmonyStageCollision", STAGE, 38, 0.35)
	for tier in 3:
		Kit.cylinder(root, "PetalAudienceTier%02d" % tier,
			STAGE + Vector3(7 + tier * 5, 0.35 + tier * 0.35, 0), 32 - tier * 5,
			0.34, "path" if tier % 2 == 0 else "ivory", false, 20)
	var cores: Array[MeshInstance3D] = []
	var pulses: Array[MeshInstance3D] = []
	for index in 3:
		var at: Vector3 = STAGE + ANCHOR_OFFSETS[index]
		var anchor := Node3D.new()
		anchor.name = ["RhythmBeatAnchor", "PitchBeatAnchor", "DirectionBeatAnchor"][index]
		root.add_child(anchor)
		for side in [-1.0, 1.0]:
			Kit.branch(anchor, "LivingAnchorRoot", at + Vector3(side * 3.1, 0, 0),
				at + Vector3(side * 2.0, 8.0, 0), 0.62, "wood", true)
		var core := Kit.facet(anchor, "BeatAnchorCore", at + Vector3.UP * 7.0,
			Vector3(3.0, 3.8, 2.2), ["pink", "blue", "gold"][index])
		cores.append(core)
		var pulse := Kit.cylinder(anchor, "BeatTelegraph", at + Vector3.UP * 0.12,
			7.5, 0.12, "blue", false, 16)
		pulse.set_meta("anchor_index", index)
		pulses.append(pulse)
		Kit.sign_text(anchor, ["RHYTHM", "PITCH", "DIRECTION"][index], at + Vector3.UP * 11, 18)
	var sockets: Array[MeshInstance3D] = []
	var shells: Array[MeshInstance3D] = []
	var orchestra := Node3D.new()
	orchestra.name = "HarmonyFruitOrchestra"
	root.add_child(orchestra)
	Kit.cylinder(orchestra, "OrchestraDais", STAGE + Vector3.UP * 0.62, 11, 0.7, "ivory", false, 18)
	for index in 6:
		var angle := TAU * float(index) / 6.0
		var at := STAGE + Vector3(cos(angle) * 8, 2.0, sin(angle) * 8)
		var socket := Kit.facet(orchestra, "FruitSocket%02d" % index, at,
			Vector3(1.6, 1.0, 1.6), "rock")
		socket.set_meta("fruit_index", index)
		sockets.append(socket)
		var shell := Kit.facet(orchestra, "SilencingShell%02d" % index,
			STAGE + Vector3(cos(angle) * 4.2, 4.8, sin(angle) * 4.2),
			Vector3(3.3, 5.4, 2.2), "blight")
		shells.append(shell)
	var blooms: Array[MeshInstance3D] = []
	for index in 12:
		var angle := TAU * float(index) / 12.0
		var bloom := Kit.facet(root, "StageResponseBloom%02d" % index,
			STAGE + Vector3(cos(angle) * 33, 1.0, sin(angle) * 33),
			Vector3(1.8, 1.5, 1.8), "leaf")
		blooms.append(bloom)
	Kit.sign_text(root, "HARMONY STAGE\nJOIN • PLACE • CONDUCT", STAGE + Vector3(0, 16, 0), 26)
	return {"anchor_cores": cores, "anchor_pulses": pulses, "orchestra_sockets": sockets,
		"shell_sections": shells, "stage_blooms": blooms}


static func _build_fig_grove(parent: Node3D) -> Array[MeshInstance3D]:
	var root := Node3D.new()
	root.name = "HarmonyFigGrove"
	parent.add_child(root)
	Kit.cylinder(root, "FigGroveCourt", FIG_GROVE + Vector3.UP * 0.18, 18, 0.3, "ivory", false, 16)
	var fruit: Array[MeshInstance3D] = []
	for index in 6:
		var angle := TAU * float(index) / 6.0
		var base := FIG_GROVE + Vector3(cos(angle) * 9, 0, sin(angle) * 9)
		Kit.branch(root, "HarmonyFigBranch%02d" % index, base,
			base + Vector3(-cos(angle) * 2, 7.5, -sin(angle) * 2), 0.7, "wood", true)
		Kit.facet(root, "HarmonyFigLeaves%02d" % index, base + Vector3.UP * 7.4,
			Vector3(4.4, 2.5, 4.0), "leaf_light")
		var item := Kit.facet(root, "HarmonyFigFruit%02d" % index,
			base + Vector3.UP * 5.5, Vector3(1.25, 1.55, 1.25), "pink")
		item.set_meta("fruit_id", "harmony_fig")
		fruit.append(item)
	Kit.sign_text(root, "HARMONY FIGS\nSIX VOICES • ONE CHORD", FIG_GROVE + Vector3.UP * 12, 21)
	return fruit


static func _build_sanctuary(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "HarmonyJewelSanctuary"
	parent.add_child(root)
	Kit.cylinder(root, "SanctuaryCourt", SANCTUARY + Vector3.UP * 0.24, 25, 0.45, "ivory", false, 20)
	for side in [-1.0, 1.0]:
		Kit.branch(root, "SanctuaryRootArch", SANCTUARY + Vector3(-8, 0, side * 10),
			SANCTUARY + Vector3(0, 15, side * 7), 0.9, "wood", true)
		Kit.branch(root, "SanctuaryRootArch", SANCTUARY + Vector3(0, 15, side * 7),
			SANCTUARY + Vector3(8, 0, side * 10), 0.9, "wood", true)
	var jewel := Kit.facet(root, "HarmonyJewel", SANCTUARY + Vector3.UP * 9,
		Vector3(5.5, 7.0, 3.6), "blue")
	var shield := Kit.facet(root, "HarmonyShield", SANCTUARY + Vector3(9, 4, 0),
		Vector3(3.5, 5.0, 1.0), "gold")
	var gate_light := Kit.box(root, "CreatorsLightGate", GATE + Vector3.UP * 6,
		Vector3(1.0, 12.0, 14.0), "blue")
	Kit.sign_text(root, "HARMONY JEWEL SANCTUARY\nRESTORE • REFLECT • CONTINUE",
		SANCTUARY + Vector3.UP * 18, 22)
	return {"jewel": jewel, "shield": shield, "gate_light": gate_light}


static func _build_dressing(parent: Node3D) -> void:
	for index in 16:
		var angle := TAU * float(index) / 16.0
		Kit.tree(parent, CENTER + Vector3(cos(angle) * 126, 0, sin(angle) * 86),
			0.72 + float(index % 3) * 0.08)
	for index in 20:
		Kit.flower(parent, Vector3(942 + float((index * 37) % 250), 3.7,
			-72 + float((index * 29) % 142)), 0.75, ["pink", "blue", "gold"][index % 3])
