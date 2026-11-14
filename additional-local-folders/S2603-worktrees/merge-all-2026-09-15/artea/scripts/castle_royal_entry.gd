# One dimensional contract for the royal stair, its stone portal and oak door.
# Treads own both their visible top and collision; there is no hidden ramp.
extends RefCounted

const Court := preload("res://scripts/castle_royal_courtyard.gd")
const Garden := preload("res://scripts/castle_rooftop_garden.gd")
const ReferenceStyle := preload("res://scripts/castle_reference_style.gd")
const TOP := Vector3(-39.8, 78.33, 27.41)
const FOOT := Vector3(-31.4, 69.18, 27.41)
const WIDTH := 4.8
const STEPS := 18
const RUN := 8.4
const RISE := 9.15
const GUARD_WIDTH := 0.74


static func build_stair(parent: Node3D) -> void:
	var rig := Node3D.new()
	rig.name = "RoyalCastleStair"
	parent.add_child(rig)
	rig.global_position = FOOT
	rig.set_meta("preserve_castle_finish", true)
	rig.set_meta("walk_surface_policy", "visible_treads_are_physical_treads")
	var stone := Court.stone_material()
	var tread_stone := Court.stone_material()
	tread_stone.set_shader_parameter("dressed_treads", true)
	var light := ReferenceStyle.material("trim")
	var red := ReferenceStyle.material("roof")
	var gold := Garden._material(Color("bba36b"))
	var depth := RUN / STEPS
	var rise := RISE / STEPS
	for index in STEPS:
		var top_y := rise * (index + 1)
		var tread := Court.box(rig, "RoyalTread_%02d" % index,
			Vector3(depth, rise + 0.9, WIDTH),
			Vector3(-depth * (index + 0.5), top_y - (rise + 0.9) * 0.5, 0), tread_stone, true)
		tread.set_meta("walk_surface_y", FOOT.y + top_y)
	# Continuous closed soffit: its high edge remains below every stair block.
	var soffit := _sloping_band(rig, "RoyalStairSoffit", -0.9, RISE - 0.9,
		0.70, WIDTH, 0, stone, true)
	soffit.set_meta("finished_stone_soffit", true)
	for side: float in [-1.0, 1.0]:
		var z := side * (WIDTH * 0.5 + GUARD_WIDTH * 0.5)
		# A single straight inner face per side; no merlons or brick colliders
		# interrupt the walking lane. The height also encloses the highest riser.
		_sloping_band(rig, "RoyalStairParapet", 1.49, RISE + 1.49,
			3.09, GUARD_WIDTH, z, stone, true)
		_sloping_band(rig, "RoyalStairCoping", 1.65, RISE + 1.65,
			0.16, GUARD_WIDTH, z, light, true)
		for end_index in 2:
			var at := Vector3(-RUN * end_index, RISE * end_index, side * 2.97)
			Court.box(rig, "RoyalStairNewel", Vector3(0.96, 1.84, 1.14),
				at + Vector3(0, 0.82, 0), stone, true)
			Court.box(rig, "NewelCapital", Vector3(0.96, 0.18, 1.14),
				at + Vector3(0, 1.83, 0), light)
			var cap := CylinderMesh.new()
			cap.top_radius = 0
			cap.bottom_radius = 0.73
			cap.height = 0.82
			cap.radial_segments = 4
			Court.mesh(rig, "NewelRedRoof", cap, at + Vector3(0, 2.33, 0), red).rotation.y = PI / 4
		for index in 3:
			var t := (index + 0.5) / 3.0
			ReferenceStyle.cluster(rig, Vector3(-RUN * t, RISE * t - 0.15, side * 3.145),
				Vector3(0, 0, side), 0.9)
			var plaque := Node3D.new()
			rig.add_child(plaque)
			plaque.position = Vector3(-RUN * t, RISE * t + 0.70, side * 3.15)
			plaque.rotation.y = -side * PI / 2
			Court.box(plaque, "AscentRoyalShield", Vector3(0.025, 0.62, 0.48), Vector3.ZERO, red)
			Court.crown(plaque, Vector3(0.025, 0, 0), gold, 0.30)
	# Threshold is entirely behind the top riser, never extending into the lane.
	Court.box(rig, "RoyalDoorLanding", Vector3(1.5, 0.65, 4.8),
		Vector3(-RUN - 0.75, RISE - 0.325, 0), ReferenceStyle.material("floor"), true)
	# The commander stands beside the doorway on an actual supported balcony.
	for side: float in [-1.0, 1.0]:
		Court.box(rig, "RoyalDoorSideLanding", Vector3(5.05, 0.65, 2.5),
			Vector3(-RUN + 1.075, RISE - 0.325, side * 3.65), stone, true)
		Court.wall(rig, "DoorBalconyGuard", Vector3(5.05, 1.65, 0.6),
			Vector3(-RUN + 1.075, RISE + 0.825, side * 4.60), stone, light)
		Court.wall(rig, "DoorBalconyReturn", Vector3(0.6, 1.65, 2.5),
			Vector3(-RUN + 3.30, RISE + 0.825, side * 3.65), stone, light)


static func _sloping_band(parent: Node3D, label: String, low: float, high: float,
		depth: float, width: float, z: float, material: Material, collision: bool) -> MeshInstance3D:
	var points := PackedVector3Array()
	for lateral: float in [z - width * 0.5, z + width * 0.5]:
		for p: Vector2 in [Vector2(0, low), Vector2(-RUN, high),
			Vector2(-RUN, high - depth), Vector2(0, low - depth)]:
			points.append(Vector3(p.x, p.y, lateral))
	var part := Court.mesh(parent, label, Court.prism(points), Vector3.ZERO, material)
	if collision:
		Court.solid(part, part.mesh.create_convex_shape())
	return part


static func build_door(parent: Node3D) -> void:
	var rig := Node3D.new()
	rig.name = "GalleryDoorRig"
	parent.add_child(rig)
	# The portal follows the measured imported anchor, 4 cm below our threshold.
	rig.position.y = 0.04
	rig.set_meta("preserve_castle_finish", true)
	var stone := Court.stone_material()
	var light := ReferenceStyle.material("trim")
	var oak := Garden._material(Color("70492f"))
	var oak_light := Garden._material(Color("865939"))
	var iron := Garden._material(Color("34434d"))
	var gold := Garden._material(Color("bba36b"))
	var red := ReferenceStyle.material("roof")
	# Two recessed oak leaves with tops cut to the same pointed arch as the frame.
	# A closed door remains solid in explicit-interaction mode. The existing
	# auto-entry trigger is in front of it, preserving the gallery handoff.
	for side: float in [-1.0, 1.0]:
		for board_index in 6:
			var za := side * (0.018 + board_index * 0.39)
			var zb := side * (0.018 + (board_index + 1) * 0.39)
			var polygon := PackedVector3Array()
			for x: float in [-0.18, 0.14]:
				for p: Vector2 in [Vector2(za, 0.0), Vector2(zb, 0.0),
					Vector2(zb, _arch_y(absf(zb), 2.4)), Vector2(za, _arch_y(absf(za), 2.4))]:
					polygon.append(Vector3(x, p.y, p.x))
			var board := Court.mesh(rig, "RoyalOakBoard", Court.prism(polygon), Vector3.ZERO,
				oak if board_index % 2 == 0 else oak_light)
			Court.solid(board, board.mesh.create_convex_shape())
		for height: float in [0.8, 2.8, 4.5]:
			Court.box(rig, "ForgedDoorStrap", Vector3(0.055, 0.16, 2.18),
				Vector3(0.168, height, side * 1.20), iron)
			for stud in 5:
				var pin := SphereMesh.new()
				pin.radius = 0.045
				pin.height = 0.09
				pin.radial_segments = 6
				pin.rings = 3
				Court.mesh(rig, "DoorBrassRivet", pin, Vector3(0.20, height, side * (0.30 + stud * 0.44)), gold)
		Court.box(rig, "KnockerPlate", Vector3(0.06, 0.54, 0.34), Vector3(0.17, 2.05, side * 0.40), iron)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.15
		ring.outer_radius = 0.205
		ring.rings = 20
		ring.ring_segments = 6
		Court.mesh(rig, "RoyalRingKnocker", ring, Vector3(0.245, 1.99, side * 0.40), gold).rotation.z = PI / 2
		# Jambs are full depth, with recessed architrave and grounded corner piers.
		Court.box(rig, "RoyalDoorJamb", Vector3(0.95, 4.8, 0.62), Vector3(0.08, 2.4, side * 2.71), stone, true)
		Court.box(rig, "JambInnerMoulding", Vector3(0.12, 4.8, 0.12), Vector3(0.60, 2.4, side * 2.46), light)
		Court.box(rig, "JambFoot", Vector3(1.08, 0.34, 0.80), Vector3(0.08, 0.17, side * 2.80), light, true)
		Court.box(rig, "JambImpost", Vector3(1.08, 0.22, 0.80), Vector3(0.08, 4.75, side * 2.80), light)
		var tower_z := side * 3.65
		Court.box(rig, "RoyalPortalPier", Vector3(1.85, 6.33, 1.5), Vector3(-0.20, 3.165, tower_z), stone, true)
		Court.box(rig, "PortalPierCapital", Vector3(1.85, 0.22, 1.5), Vector3(-0.20, 6.44, tower_z), light)
		var roof := CylinderMesh.new()
		roof.bottom_radius = 1.18
		roof.top_radius = 0
		roof.height = 1.75
		roof.radial_segments = 4
		Court.mesh(rig, "PortalPierRedRoof", roof, Vector3(-0.20, 7.425, tower_z), red).rotation.y = PI / 4
		Court.box(rig, "RoyalBanner", Vector3(0.04, 1.85, 0.65), Vector3(0.748, 4.4, tower_z), red)
		Court.crown(rig, Vector3(0.775, 4.65, tower_z), gold, 0.40)
		_lantern(rig, Vector3(1.0, 2.4, tower_z), iron, gold)
	# Cut arch stones, rather than rotated boxes with gaps between them.
	for side: float in [-1.0, 1.0]:
		for index in 12:
			var u0 := float(index) / 12.0
			var u1 := float(index + 1) / 12.0
			var points := PackedVector3Array()
			for x: float in [-0.395, 0.555]:
				for p: Vector2 in [Vector2(side * 2.4 * u0, _arch_y(2.4 * u0, 2.4)),
					Vector2(side * 2.4 * u1, _arch_y(2.4 * u1, 2.4)),
					Vector2(side * 3.02 * u1, _arch_y(3.02 * u1, 3.02) + 0.06),
					Vector2(side * 3.02 * u0, _arch_y(3.02 * u0, 3.02) + 0.06)]:
					points.append(Vector3(x, p.y, p.x))
			var block := Court.mesh(rig, "RoyalArchVoussoir", Court.prism(points), Vector3.ZERO,
				light)
			Court.solid(block, block.mesh.create_convex_shape())
	Court.box(rig, "ArchKeystone", Vector3(0.15, 0.55, 0.43), Vector3(0.63, 8.18, 0), light)
	Court.crown(rig, Vector3(0.716, 8.18, 0), gold, 0.28)


static func _arch_y(z: float, radius: float) -> float:
	# Round-headed arch matches the reference windows. Door boards and all
	# frame stones share this same curve, leaving no pointed/rounded mismatch.
	return 4.8 + radius * 1.10 * sqrt(maxf(0.0, 1.0 - pow(z / radius, 2)))


static func _lantern(parent: Node3D, at: Vector3, iron: Material, gold: Material) -> void:
	Court.box(parent, "LanternBracket", Vector3(0.40, 0.12, 0.12), at - Vector3(0.2, 0, 0), iron)
	Court.box(parent, "LanternHousing", Vector3(0.32, 0.65, 0.40), at + Vector3(0, 0.34, 0), iron)
	var amber := Garden._material(Color("ffc771"))
	amber.emission_enabled = true
	amber.emission = Color("ffac48")
	amber.emission_energy_multiplier = 0.7
	Court.box(parent, "LanternWindow", Vector3(0.016, 0.43, 0.25), at + Vector3(0.168, 0.34, 0), amber)
	Court.box(parent, "LanternCrossbar", Vector3(0.02, 0.035, 0.27), at + Vector3(0.183, 0.34, 0), gold)
	var lamp := OmniLight3D.new()
	lamp.position = at + Vector3(0.35, 0.34, 0)
	lamp.light_color = Color("ffd395")
	lamp.light_energy = 0.7
	lamp.omni_range = 3.0
	lamp.shadow_enabled = false
	parent.add_child(lamp)
