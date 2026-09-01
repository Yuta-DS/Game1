# The Lumen Engine Citadel is Artéa's original roaming landmark.
#
# It deliberately avoids copying any existing film castle: this is a bright,
# restorative machine-city whose science is visible. Brass mechanisms collect
# the light made by the player, while constellations map the next gentle step
# in their journey. It is built at runtime so the large hub scene stays easy
# to edit in Godot.
extends Node3D

const THOUGHTS_PORTAL := Vector3(90.3, 15.0, -83.0)
const CASTLE_NAME := "building_castle_red2"
const STAGE_COLOURS := [
	Color("415777"), # sleeping blue-grey
	Color("86b7ff"), # a thought noticed
	Color("f5a95e"), # a feeling named
	Color("d98cff"), # a creation made
	Color("ffd66e"), # a whole constellation
]

const BRASS := Color("b78242")
const INK := Color("18243d")
const GLASS := Color("86dfff")

var _castle: Node3D
var _castle_start_position := Vector3.ZERO
var _time := 0.0
var _stage := 0
var _rotors: Array[Node3D] = []
var _light_materials: Array[StandardMaterial3D] = []
var _waypoint_lights: Array[OmniLight3D] = []
var _citadel_lamp: OmniLight3D
var _castle_fill: OmniLight3D
var _foundation: Node3D
var _foundation_start_y := 0.0


func _ready() -> void:
	# The packed hub finishes instancing its large castle before we attach the
	# living machinery. This also makes the script safe when previewed alone.
	await get_tree().process_frame
	_castle = get_parent().get_node_or_null(CASTLE_NAME) as Node3D
	if _castle == null:
		push_warning("Lumen Citadel: hub castle not found")
		return

	_castle_start_position = _castle.position
	_brighten_castle_materials(_castle)
	_build_castle_foundation()
	_build_skyway()
	apply_stage(_current_stage())


func _process(delta: float) -> void:
	if _castle == null:
		return

	_time += delta
	# Architecture connected to a fixed stair and courtyard must not bob. The
	# old 0.44 m peak-to-peak movement continuously opened and closed the seam at
	# the real front door, and moved StaticBody collision under a standing
	# player. Life now comes from the engine, orbit instruments and aether cores;
	# every walkable surface remains stable.
	_castle.position = _castle_start_position
	if _foundation != null:
		_foundation.position.y = _foundation_start_y

	for i in _rotors.size():
		var direction := 1.0 if i % 2 == 0 else -1.0
		_rotors[i].rotate_y(direction * delta * (0.18 + _stage * 0.12))


# Called by hub_awakening whenever the player returns with a new discovery.
func apply_stage(stage: int) -> void:
	_stage = clampi(stage, 0, STAGE_COLOURS.size() - 1)
	var glow: Color = STAGE_COLOURS[_stage]
	# Keep the dormant science channels readable against Artéa's bright sky,
	# while preserving almost the same stage-four ceiling as the old curve.
	var energy := 0.46 + float(_stage) * 0.30

	for material in _light_materials:
		material.emission = glow
		material.emission_energy_multiplier = energy

	for i in _waypoint_lights.size():
		# The route only reveals the next destination at first. Later lights
		# make the complete journey legible as one path, rather than a menu.
		_waypoint_lights[i].visible = i <= _stage
		_waypoint_lights[i].light_color = glow

	if _citadel_lamp != null:
		_citadel_lamp.light_color = glow
		_citadel_lamp.light_energy = 0.4 + float(_stage) * 0.28
	if _castle_fill != null:
		_castle_fill.light_color = glow.lightened(0.28)
		_castle_fill.light_energy = 0.62 + float(_stage) * 0.12


func set_vibrant(vibrant: bool) -> void:
	apply_stage(4 if vibrant else 0)


func is_vibrant() -> bool:
	return _stage > 0


# --- Citadel ---------------------------------------------------------

# The imported castle previously hovered above a tapered rock island with
# dangling levitation anchors. A single giant living tree now carries the full
# silhouette from the ground into the castle floor: its trunk is the vertical
# load path, its upper roots cradle the foundation, and its ground roots make
# the support feel grown rather than suspended.
func _build_castle_foundation() -> void:
	_foundation = Node3D.new()
	_foundation.name = "CastleFoundation"
	get_parent().add_child(_foundation)
	_foundation.position = Vector3(_castle.position.x, _castle.position.y - 4.2,
		_castle.position.z)
	_foundation_start_y = _foundation.position.y

	_build_giant_tree_foundation()

	# The raised citadel's entry is a deliberate open sector, not a solid disc
	# that cuts across the final stair. These three support decks preserve safe
	# footing on the rear and flanks while leaving a 12 m-wide, collision-free
	# procession from the court to the elevated threshold.
	_add_foundation_support("FoundationRearSupport", Vector3(-2.0, 4.7, 0.0),
		Vector3(20.0, 2.0, 22.0))
	_add_foundation_support("FoundationWestSupport", Vector3(11.0, 4.7, -10.5),
		Vector3(7.0, 2.0, 7.5))
	_add_foundation_support("FoundationEastSupport", Vector3(11.0, 4.7, 10.5),
		Vector3(7.0, 2.0, 7.5))

	# GALLERY_ANCHOR — future gallery/world content can attach here without
	# depending on the imported castle's internal glTF node names.
	var gallery_anchor := Node3D.new()
	gallery_anchor.name = "GALLERY_ANCHOR"
	gallery_anchor.position = Vector3(10.5, 5.8, 0.0)
	gallery_anchor.set_meta("purpose", "future_gallery_courtyard")
	_foundation.add_child(gallery_anchor)

	var plaza := MeshInstance3D.new()
	plaza.name = "GalleryFoundationPlaza"
	var plaza_mesh := CylinderMesh.new()
	plaza_mesh.top_radius = 7.0
	plaza_mesh.bottom_radius = 7.6
	plaza_mesh.height = 0.7
	plaza_mesh.radial_segments = 10
	plaza.mesh = plaza_mesh
	plaza.position = gallery_anchor.position
	plaza.material_override = _ink_material()
	_foundation.add_child(plaza)

	_foundation.set_meta("pipe_free_foundation", true)
	_foundation.set_meta("foundation_style", "giant_living_tree")
	_foundation.set_meta("floating_undercarriage_removed", true)

	_castle_fill = OmniLight3D.new()
	_castle_fill.name = "CastleDetailFill"
	_castle_fill.position = Vector3(9.0, 18.0, 8.0)
	_castle_fill.light_color = Color(1.0, 0.78, 0.48)
	_castle_fill.light_energy = 1.05
	# Was 58.0 - a "detail fill" light doesn't need to reach the surrounding
	# terrain and village; that range put it overlapping every other castle
	# light (citadel_lamp, core_light, lens_light, both buttress lights) on
	# any mesh near the castle, stacking 5-6 lights in one fragment's lighting
	# loop under the non-clustered Compatibility renderer.
	_castle_fill.omni_range = 22.0
	_castle_fill.omni_attenuation = 1.25
	_castle_fill.shadow_enabled = false
	_castle_fill.distance_fade_enabled = true
	_castle_fill.distance_fade_begin = 45.0
	_castle_fill.distance_fade_length = 15.0
	_foundation.add_child(_castle_fill)


func _build_giant_tree_foundation() -> void:
	var tree := Node3D.new()
	tree.name = "GiantTreeFoundation"
	tree.set_meta("supports_castle_foundation", true)
	tree.set_meta("grounded_root_system", true)
	tree.set_meta("visual_style", "curved_low_poly_living_bark_with_fibres_and_leaves")
	tree.set_meta("supported_areas", ["castle_core", "gallery_block", "crystal_block"])
	_foundation.add_child(tree)

	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color("76502f")
	bark.roughness = 0.96
	var bark_light := bark.duplicate() as StandardMaterial3D
	bark_light.albedo_color = Color("9a6b3d")
	var bark_shadow := bark.duplicate() as StandardMaterial3D
	bark_shadow.albedo_color = Color("4b3426")
	var moss := StandardMaterial3D.new()
	moss.albedo_color = Color("4f8c3c")
	moss.roughness = 1.0
	var vine := StandardMaterial3D.new()
	vine.albedo_color = Color("315e32")
	vine.roughness = 0.94
	var leaf_green := StandardMaterial3D.new()
	leaf_green.albedo_color = Color("4f963f")
	leaf_green.roughness = 0.88
	var leaf_olive := leaf_green.duplicate() as StandardMaterial3D
	leaf_olive.albedo_color = Color("789b42")

	# One centred, gently bending tube now replaces the old straight cylinder.
	# Its lowest ring meets the hub terrain and its crown reaches the castle
	# underside, keeping the entire load path visible from the low player camera.
	var trunk_points: Array[Vector3] = [
		Vector3(0.0, -49.0, 0.0), Vector3(-0.8, -39.0, 0.5),
		Vector3(0.9, -28.0, -0.8), Vector3(-0.5, -17.0, 0.7),
		Vector3(0.0, -7.0, 0.0),
	]
	var trunk := _add_curved_root(tree, "TreeTrunkCore", trunk_points,
		PackedFloat32Array([10.8, 10.3, 9.1, 7.7, 6.2]), bark, 10)
	trunk.set_meta("load_path", "ground_to_castle")

	# Thick old-growth flutes fuse visually into the core. Their slow spiral and
	# alternating bark values produce the layered wood grain from the approved
	# concept while keeping one coherent trunk silhouette.
	for flute_index in 6:
		var flute_points := _spiral_offset_curve(trunk_points, 6.7,
			TAU * float(flute_index) / 6.0 + 0.12, 0.34)
		var flute := _add_curved_root(tree, "TrunkFlute_%02d" % (flute_index + 1),
			flute_points, PackedFloat32Array([2.8, 2.55, 2.15, 1.55, 0.82]),
			bark_light if flute_index % 2 == 0 else bark_shadow, 8)
		flute.set_meta("structural_trunk_flute", true)

	# Braided fibre lines sit just above the trunk surface. Alternating bark and
	# living-green strands make the requested wood-fibre language legible without
	# turning the trunk into a dense foliage column.
	for fibre_index in 8:
		var fibre_points := _spiral_offset_curve(trunk_points, 7.0,
			TAU * float(fibre_index) / 8.0, 0.72)
		var fibre := _add_curved_root(tree, "TreeFiber_Trunk_%02d" % (fibre_index + 1),
			fibre_points, PackedFloat32Array([0.46, 0.40, 0.34, 0.27, 0.18]),
			vine if fibre_index % 3 == 0 else bark_light, 6)
		fibre.set_meta("tree_fibre", true)

	_build_integrated_castle_root_crown(tree, bark, bark_light, bark_shadow, vine)

	# Six general cradle roots carry the rear and side perimeter. The two front
	# architectural areas receive their own named supports below.
	for root_index in 6:
		var angle := TAU * float(root_index) / 6.0 + 0.52
		var spread := 10.8 + float(root_index % 2) * 1.1
		var start := Vector3(cos(angle) * 3.4, -14.0, sin(angle) * 3.4)
		var points: Array[Vector3] = [
			start,
			Vector3(cos(angle + 0.10) * 4.6, -10.0, sin(angle + 0.10) * 4.6),
			Vector3(cos(angle - 0.08) * 6.8, -5.0, sin(angle - 0.08) * 6.8),
			Vector3(cos(angle + 0.05) * 9.2, 0.2, sin(angle + 0.05) * 9.2),
			Vector3(cos(angle) * spread, 4.35, sin(angle) * spread),
		]
		var cradle := _add_curved_root(tree, "CastleCradleRoot_%02d" % (root_index + 1),
			points, PackedFloat32Array([3.6, 3.2, 2.65, 1.9, 1.15]),
			bark_light if root_index % 2 == 0 else bark, 8)
		cradle.set_meta("castle_contact", true)
		_add_support_fibres(tree, "Core_%02d" % (root_index + 1), points,
			2.35, bark_shadow, vine)
		if root_index % 2 == 0:
			_add_tree_leaf_cluster(tree, "Core_%02d" % (root_index + 1),
				points[3], angle, leaf_green, leaf_olive, 5)

	_build_architecture_root_support(tree, "Gallery", -1.0,
		bark, bark_light, bark_shadow, vine, moss, leaf_green, leaf_olive)
	_build_architecture_root_support(tree, "Crystal", 1.0,
		bark, bark_light, bark_shadow, vine, moss, leaf_green, leaf_olive)
	_build_front_wall_center_supports(tree, bark, bark_light, bark_shadow, vine,
		moss, leaf_green, leaf_olive)

	# Wide buttress roots meet the hub terrain and counter the top-heavy castle.
	# Alternating lengths avoid a mechanically perfect radial star.
	for root_index in 10:
		var angle := TAU * float(root_index) / 10.0 + 0.08
		var length := 18.0 + float(root_index % 4) * 2.4
		var start := Vector3(cos(angle) * 4.2, -44.0,
			sin(angle) * 4.2)
		var elbow := Vector3(cos(angle + 0.08) * 11.5, -48.0,
			sin(angle + 0.08) * 11.5)
		var tip := Vector3(cos(angle - 0.05) * length, -49.1,
			sin(angle - 0.05) * length)
		var ground_points: Array[Vector3] = [
			start, start.lerp(elbow, 0.55) + Vector3.UP * 1.0, elbow, tip]
		var ground_root := _add_curved_root(tree,
			"GroundButtressRoot_%02d" % (root_index + 1),
			ground_points, PackedFloat32Array([4.4, 3.4, 2.5, 0.35]),
			bark_shadow if root_index % 3 == 0 else bark, 8)
		# These exposed roots read as small ground mountains. A single simplified
		# convex hull closes the underside and gives the player one continuous,
		# climbable surface instead of detailed triangle seams or a hollow arch.
		ground_root.create_convex_collision(true, true)
		var collision_bodies := ground_root.find_children(
			"*", "StaticBody3D", false, false)
		var collision_body := collision_bodies[0] as StaticBody3D \
			if not collision_bodies.is_empty() else null
		if collision_body != null:
			collision_body.name = "WalkableRootBody"
		ground_root.set_meta("walkable_ground_mound", true)
		ground_root.set_meta("closed_underside_collision", true)
		ground_root.set_meta("root_tip", tip)
		ground_root.set_meta("root_elbow", elbow)
		if root_index % 2 == 0:
			_add_tree_leaf_cluster(tree, "Ground_%02d" % (root_index + 1),
				elbow + Vector3.UP * 0.8, angle, leaf_green, leaf_olive, 3)

	# A few larger sprouts climb the trunk itself so foliage reads from ground
	# level and connects the leafy support joints into one living system.
	for trunk_leaf_index in 6:
		var leaf_angle := TAU * float(trunk_leaf_index) / 6.0 + 0.30
		var leaf_height := -35.0 + float(trunk_leaf_index) * 5.1
		_add_tree_leaf_cluster(tree, "Trunk_%02d" % (trunk_leaf_index + 1),
			Vector3(cos(leaf_angle) * 8.0, leaf_height,
				sin(leaf_angle) * 8.0), leaf_angle, leaf_green, leaf_olive, 5)

	# Sparse moss lines emphasize growth without turning the trunk bright green.
	for moss_index in 6:
		var moss_points := _spiral_offset_curve(trunk_points, 7.35,
			TAU * float(moss_index) / 6.0 + 0.42, 0.48)
		_add_curved_root(tree, "MossGrowth_%02d" % (moss_index + 1), moss_points,
			PackedFloat32Array([0.34, 0.30, 0.25, 0.18, 0.10]), moss, 5)

	tree.set_meta("curved_core_cradle_roots", 6)
	tree.set_meta("integrated_castle_root_crown", true)
	tree.set_meta("under_castle_bearing_roots", 8)
	tree.set_meta("architecture_support_zones", 2)
	tree.set_meta("front_wall_center_supports", 2)
	tree.set_meta("ground_buttress_roots", 10)
	tree.set_meta("tree_fibres_and_vines", tree.find_children(
		"TreeFiber_*", "MeshInstance3D", true, false).size())
	tree.set_meta("leaf_elements", tree.find_children(
		"TreeLeaf_*", "MeshInstance3D", true, false).size())


# The old upper roots arrived at the castle as separate narrow tips. From a low
# camera angle they looked like floating cut branches instead of one structure.
# This flared crown overlaps the ground-to-castle trunk, then spreads eight
# interlocking bearing roots across the complete underside of the main keep.
# Every branch terminates exactly against the 3.7 m foundation underside.
func _build_integrated_castle_root_crown(tree: Node3D, bark: Material,
		bark_light: Material, bark_shadow: Material, vine: Material) -> void:
	var crown := Node3D.new()
	crown.name = "IntegratedCastleRootCrown"
	crown.set_meta("load_path", "central_trunk_to_full_castle_underside")
	crown.set_meta("foundation_contact_y", 3.7)
	crown.set_meta("bearing_root_count", 8)
	tree.add_child(crown)

	var crown_points: Array[Vector3] = [
		Vector3(0.0, -12.0, 0.0),
		Vector3(0.4, -7.8, -0.3),
		Vector3(-0.35, -3.6, 0.4),
		Vector3(0.0, 0.2, 0.0),
		Vector3(0.0, 3.72, 0.0),
	]
	var trunk_crown := _add_curved_root(crown, "CastleRootCrownCore", crown_points,
		PackedFloat32Array([6.2, 6.55, 7.0, 7.6, 8.15]), bark, 12)
	trunk_crown.set_meta("continuous_with_tree_trunk", true)
	trunk_crown.set_meta("castle_contact", true)
	_add_support_fibres(crown, "CastleRootCrown", crown_points, 7.1,
		bark_shadow, vine)

	for bearing_index in 8:
		var angle := TAU * float(bearing_index) / 8.0 + PI * 0.125
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var contact_radius := 10.8 if bearing_index % 2 == 0 else 9.6
		var contact := direction * contact_radius + Vector3.UP * 3.70
		var points: Array[Vector3] = [
			direction * 3.2 + Vector3.UP * -7.4,
			direction * 4.8 + Vector3.UP * -3.4,
			direction * 7.0 + Vector3.UP * 0.2,
			direction * (contact_radius - 1.2) + Vector3.UP * 3.15,
			contact,
		]
		var bearing := _add_curved_root(crown,
			"UnderCastleBearingRoot_%02d" % (bearing_index + 1), points,
			PackedFloat32Array([3.25, 2.75, 2.05, 1.25, 0.68]),
			bark_light if bearing_index % 2 == 0 else bark_shadow, 9)
		bearing.set_meta("castle_contact", true)
		bearing.set_meta("foundation_contact", contact)
		bearing.set_meta("structural_role", "radial_under_keep_bearing")

		# A second, finer strand crosses each principal bearing. The alternating
		# direction makes the crown read as grown-together timber, not eight poles.
		var cross_direction := Vector3(cos(angle + 0.34), 0.0, sin(angle + 0.34))
		var tie_points: Array[Vector3] = [
			direction * 4.4 + Vector3.UP * -2.8,
			direction.lerp(cross_direction, 0.45) * 7.0 + Vector3.UP * 0.1,
			cross_direction * (contact_radius - 1.6) + Vector3.UP * 3.52,
		]
		var tie := _add_curved_root(crown,
			"UnderCastleCrossTie_%02d" % (bearing_index + 1), tie_points,
			PackedFloat32Array([1.15, 0.82, 0.34]), bark, 7)
		tie.set_meta("structural_role", "interwoven_crown_tie")


func _build_front_wall_center_supports(tree: Node3D, bark: Material,
		bark_light: Material, bark_shadow: Material, vine: Material, moss: Material,
		leaf_green: Material, leaf_olive: Material) -> void:
	var front_supports := Node3D.new()
	front_supports.name = "FrontWallCenterSupports"
	front_supports.set_meta("placement", "centered_under_two_front_facing_walls")
	front_supports.set_meta("separate_from_central_foundation", true)
	tree.add_child(front_supports)

	# Gallery: measured from the live ArtExploreMarker/door face at world
	# (-39.8, 82.29, 27.41). Crystal wall: the outer front arrival mass beside it
	# is centred at world (-21.9, 67.28, 27.41). Foundation-space coordinates
	# below keep both new trunks under those front centres, not under the castle's
	# old central origin at (0, 0, 0).
	var supports := [
		{
			"label": "GalleryEntrance",
			"target": Vector3(11.6, 4.15, 0.0),
			"base": Vector3(12.8, -49.0, -7.8),
			"world_target_name": "art_explore_gallery_entrance_wall",
		},
		{
			"label": "CrystalWindow",
			# Stop below the arrival terrace underside. The former target rose two
			# metres higher and the crown/grip branches pierced the walkable slab.
			"target": Vector3(29.5, -5.35, 0.0),
			"base": Vector3(30.8, -49.0, 8.2),
			"world_target_name": "outer_crystal_window_wall",
		},
	]

	for support_index in supports.size():
		var support: Dictionary = supports[support_index]
		var label := str(support.label)
		var target: Vector3 = support.target
		var base: Vector3 = support.base
		var target_name := str(support.world_target_name)
		var trunk_points: Array[Vector3] = [
			base,
			base.lerp(target, 0.20) + Vector3(-1.0, 0.0, 1.8),
			base.lerp(target, 0.43) + Vector3(1.2, 0.0, -1.4),
			base.lerp(target, 0.67) + Vector3(-0.8, 0.0, 0.9),
			base.lerp(target, 0.86) + Vector3(0.45, 0.0, -0.35),
			target,
		]
		var trunk := _add_curved_root(front_supports,
			"%sFrontCenterRoot" % label, trunk_points,
			PackedFloat32Array([5.4, 5.05, 4.5, 3.7, 2.8, 1.55]),
			bark if support_index == 0 else bark_light, 10)
		trunk.set_meta("ground_to_front_wall", true)
		trunk.set_meta("target_name", target_name)
		trunk.set_meta("target_center", target)
		trunk.set_meta("centered_support", true)
		_add_support_fibres(front_supports, "%sFrontCenter" % label,
			trunk_points, 3.35, bark_shadow, vine)
		# The crystal-side trunk now bears directly against the slab underside.
		# Its former wall-grip forks and contact leaves continued through the
		# terrace floor into the player area, so that support ends cleanly here.
		if label == "CrystalWindow":
			continue

		# A short symmetrical fork cups the wall's lower centre without covering the
		# label or either crystal window. The load-bearing trunk still terminates on
		# the exact centreline requested by the user.
		for grip_index in 2:
			var grip_side := -1.0 if grip_index == 0 else 1.0
			var grip_points: Array[Vector3] = [
				trunk_points[4],
				target + Vector3(0.15, -1.5, grip_side * 1.8),
				target + Vector3(0.10, 0.2, grip_side * 3.2),
				target + Vector3(-0.15, 2.8, grip_side * 3.7),
			]
			var grip := _add_curved_root(front_supports,
				"%sFrontWallGripRoot_%02d" % [label, grip_index + 1], grip_points,
				PackedFloat32Array([2.35, 1.85, 1.12, 0.38]),
				bark_light if grip_index == 0 else bark, 8)
			grip.set_meta("front_wall_grip", true)
			grip.set_meta("target_name", target_name)
			_add_support_fibres(front_supports,
				"%sFrontGrip_%02d" % [label, grip_index + 1], grip_points,
				1.38, bark_shadow, vine)
			_add_tree_leaf_cluster(front_supports,
				"%sFrontContact_%02d" % [label, grip_index + 1],
				grip_points[2] + Vector3(-0.4, -0.2, grip_side * 0.25),
				grip_side * 0.72, leaf_green, leaf_olive, 6)

		for foliage_index in 4:
			var point_index := foliage_index + 1
			var foliage_side := -1.0 if foliage_index % 2 == 0 else 1.0
			_add_tree_leaf_cluster(front_supports,
				"%sFrontTrunk_%02d" % [label, foliage_index + 1],
				trunk_points[point_index] + Vector3(-0.4, 0.3, foliage_side * 2.5),
				foliage_side * 0.65, leaf_green, leaf_olive, 5)

		var moss_points: Array[Vector3] = []
		for point in trunk_points:
			moss_points.append(point + Vector3(-1.45, 0.15, 0.55))
		_add_curved_root(front_supports, "TreeFiber_%sFrontMoss" % label,
			moss_points, PackedFloat32Array([0.38, 0.34, 0.28, 0.22, 0.15, 0.07]),
			moss, 6).set_meta("tree_fibre", true)


func _build_architecture_root_support(tree: Node3D, area_name: String, _side: float,
		bark: Material, bark_light: Material, bark_shadow: Material, vine: Material,
		moss: Material, leaf_green: Material, leaf_olive: Material) -> void:
	var zone := Node3D.new()
	zone.name = "%sRootSupportZone" % area_name
	# These coordinates are measured from the actual underside meshes, not inferred
	# from a camera view. GalleryFoundationPlaza is centred at (10.5, 5.8, 0),
	# while CastleUpperCourt is centred at (15.8, -1.41, 0) in Foundation space.
	var is_gallery := area_name == "Gallery"
	var target_center := Vector3(10.5, 5.45, 0.0) if is_gallery \
		else Vector3(15.8, -1.78, 0.0)
	var target_id := "gallery_foundation_plaza" if is_gallery else "castle_upper_court"
	var base_z := -8.0 if is_gallery else 8.0
	zone.set_meta("supported_area", target_id)
	zone.set_meta("ground_to_architecture", true)
	zone.set_meta("target_underside", target_center)
	zone.set_meta("root_cradle_count", 2)
	zone.set_meta("edge_grip_count", 2)
	zone.set_meta("preserves_architecture_features", true)
	tree.add_child(zone)

	# A complete secondary trunk begins at terrain height and rises directly below
	# each cantilever. This is the key visual correction: these are no longer short
	# branches attached beside the central castle trunk.
	var trunk_points: Array[Vector3] = [
		Vector3(5.6 if is_gallery else 11.8, -49.0, base_z),
		Vector3(6.4 if is_gallery else 12.6, -38.0, base_z * 0.88),
		Vector3(7.7 if is_gallery else 13.4, -27.0, base_z * 0.68),
		Vector3(8.6 if is_gallery else 14.4, -16.0, base_z * 0.42),
		Vector3(9.4 if is_gallery else 15.1, -7.0, base_z * 0.20),
		Vector3(10.0 if is_gallery else 15.5,
			0.3 if is_gallery else -5.8, 0.0),
	]
	var ground_trunk := _add_curved_root(zone,
		"%sGroundSupportTrunk" % area_name, trunk_points,
		PackedFloat32Array([5.8, 5.5, 4.9, 4.1, 3.2, 2.4]), bark, 10)
	ground_trunk.set_meta("load_path", "terrain_to_%s" % target_id)
	ground_trunk.set_meta("ground_to_architecture", true)
	_add_support_fibres(zone, "%sGroundTrunk" % area_name, trunk_points,
		3.55, bark_shadow, vine)

	for trunk_leaf_index in 4:
		var trunk_point_index := trunk_leaf_index + 1
		var leaf_side := -1.0 if trunk_leaf_index % 2 == 0 else 1.0
		_add_tree_leaf_cluster(zone,
			"%sGroundTrunk_%02d" % [area_name, trunk_leaf_index + 1],
			trunk_points[trunk_point_index] + Vector3(leaf_side * 3.0, 0.4,
				leaf_side * 1.3), leaf_side * 0.7, leaf_green, leaf_olive, 6)

	# Two forks spread from each secondary trunk into separated underside contact
	# pads. Their tips curl only just around the slab lip, keeping the blue facade,
	# gallery label, windows, and player routes open.
	var contact_span_x := 3.2 if is_gallery else 2.8
	var contact_span_z := 5.5 if is_gallery else 8.2
	var fork_start := trunk_points[trunk_points.size() - 1]
	for support_index in 2:
		var branch_side := -1.0 if support_index == 0 else 1.0
		var contact := target_center + Vector3(
			branch_side * contact_span_x, 0.0, branch_side * contact_span_z)
		var points: Array[Vector3] = [
			fork_start,
			fork_start.lerp(contact, 0.34) + Vector3(0.0, -0.7, branch_side * 0.7),
			fork_start.lerp(contact, 0.68) + Vector3(branch_side * 0.5, -0.15, 0.0),
			contact,
			contact + Vector3(branch_side * 0.25, 1.65, -branch_side * 0.35),
		]
		var root := _add_curved_root(zone,
			"%sSupportRoot_%02d" % [area_name, support_index + 1], points,
			PackedFloat32Array([2.8, 2.55, 2.05, 1.28, 0.48]),
			bark if support_index == 0 else bark_light, 9)
		root.set_meta("castle_contact", true)
		root.set_meta("supported_area", target_id)
		root.set_meta("contact_point", contact)
		_add_support_fibres(zone, "%s_%02d" % [area_name, support_index + 1],
			points, 1.75, bark_shadow, vine)
		var foliage_offset := Vector3(branch_side * 0.72, 0.55, -branch_side * 0.3)
		_add_tree_leaf_cluster(zone, "%sJoint_%02d" % [area_name, support_index + 1],
			points[2] + foliage_offset, branch_side * 0.75, leaf_green, leaf_olive, 7)
		_add_tree_leaf_cluster(zone, "%sContact_%02d" % [area_name, support_index + 1],
			contact + Vector3(branch_side * 0.5, -0.2, -branch_side * 0.4),
			branch_side * 0.75,
			leaf_green, leaf_olive, 6)
		var moss_points: Array[Vector3] = [
			points[1] + Vector3(-branch_side * 0.45, 0.25, 0.35),
			contact + Vector3(-branch_side * 0.20, -0.10, 0.42),
		]
		_add_curved_root(zone, "MossContact_%s_%02d" % [area_name, support_index + 1],
			moss_points, PackedFloat32Array([0.30, 0.12]), moss, 5)

	# A broad wooden U reads as a cradle beneath each blue mass, matching the
	# reference silhouette without placing a decorative trunk in front of it.
	var left_contact := target_center + Vector3(-contact_span_x, 0.0, -contact_span_z)
	var right_contact := target_center + Vector3(contact_span_x, 0.0, contact_span_z)
	var cradle_points: Array[Vector3] = [
		left_contact,
		target_center + Vector3(-contact_span_x * 0.55, -3.2, -contact_span_z * 0.50),
		target_center + Vector3(0.0, -4.6, 0.0),
		target_center + Vector3(contact_span_x * 0.55, -3.2, contact_span_z * 0.50),
		right_contact,
	]
	var cradle := _add_curved_root(zone, "%sUndersideCradleSweepRoot" % area_name,
		cradle_points, PackedFloat32Array([1.18, 1.65, 1.9, 1.65, 1.18]),
		bark_light, 9)
	cradle.set_meta("underside_cradle", true)
	cradle.set_meta("supported_area", target_id)
	_add_support_fibres(zone, "%sUndersideCradle" % area_name, cradle_points,
		1.25, bark_shadow, vine)


func _add_support_fibres(parent: Node3D, label: String, points: Array[Vector3],
		root_radius: float, bark_fibre: Material, vine: Material) -> void:
	for fibre_index in 3:
		var fibre_points := _spiral_offset_curve(points, root_radius,
			TAU * float(fibre_index) / 3.0 + 0.35, 0.92)
		var fibre_radii := PackedFloat32Array()
		for point_index in points.size():
			fibre_radii.append(lerpf(0.34, 0.10,
				float(point_index) / float(points.size() - 1)))
		_add_curved_root(parent, "TreeFiber_%s_%02d" % [label, fibre_index + 1],
			fibre_points, fibre_radii,
			vine if fibre_index == 2 else bark_fibre, 5)


func _add_tree_leaf_cluster(parent: Node3D, label: String, position: Vector3,
		yaw: float, green: Material, olive: Material, leaf_count: int) -> void:
	var cluster := Node3D.new()
	cluster.name = "TreeLeafCluster_%s" % label
	cluster.position = position
	cluster.rotation.y = -yaw
	parent.add_child(cluster)
	for leaf_index in leaf_count:
		var angle := TAU * float(leaf_index) / float(leaf_count)
		var leaf := _add_mesh(cluster, _sphere(0.82, 1.64),
			green if leaf_index % 2 == 0 else olive,
			Vector3(cos(angle) * 1.35, sin(angle * 1.7) * 0.58,
				sin(angle) * 1.05),
			Vector3(1.95, 0.28, 0.90),
			Vector3(0.20 * sin(angle), angle, 0.45 * cos(angle)))
		leaf.name = "TreeLeaf_%s_%02d" % [label, leaf_index + 1]


# The High Aether Citadel is a facade system, not a pile of props. Two
# outboard buttresses carry the visible vertical load at the entrance, a brass
# aperture turns the doorway into an observatory instrument, and a thin
# calibration band explains the castle's levitation without closing the route.
# All of these meshes are deliberately visual-only: the stair, threshold and
# side courts keep their authored collision and the player never encounters an
# invisible scientific-looking obstruction.
func _build_high_aether_facade() -> void:
	var facade := Node3D.new()
	facade.name = "HighAetherFacade"
	facade.set_meta("collision_policy", "visual_only_open_entry_sector")
	# The front door is 11.6 m along +X from the imported castle's centre. Keep
	# the framing just behind it and outside the 7.4 m central ascent.
	facade.position = Vector3(11.2, 0.0, 0.0)
	_foundation.add_child(facade)

	var stone := _ink_material()
	var brass := _brass_material()
	var cyan := _glow_material(Color("64dcff"))
	var violet := _glow_material(Color("c58dff"))

	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var buttress := Node3D.new()
		buttress.name = "AetherButtress_L" if side < 0.0 else "AetherButtress_R"
		buttress.position = Vector3(0.0, 7.0, side * 5.45)
		facade.add_child(buttress)

		# Dark stone establishes the Gothic mass; a brass crown and luminous
		# conductor make its engineering legible as contemporary magitech.
		_add_mesh(buttress, _box(Vector3(1.15, 7.6, 0.95)), stone, Vector3.ZERO)
		_add_mesh(buttress, _box(Vector3(1.42, 0.22, 1.24)), brass,
			Vector3(0.0, 3.68, 0.0))
		_add_mesh(buttress, _box(Vector3(0.16, 4.75, 0.16)), cyan,
			Vector3(0.64, -0.18, 0.0))
		_add_mesh(buttress, _sphere(0.42, 0.78), violet,
			Vector3(0.64, 1.7, 0.0))
		_add_mesh(buttress, _cylinder(0.46, 0.46, 0.18), brass,
			Vector3(0.64, -2.75, 0.0), Vector3.ONE, Vector3(0.0, 0.0, PI * 0.5))

		var lamp := OmniLight3D.new()
		lamp.name = "ButtressAetherLight"
		lamp.position = Vector3(1.05, 1.4, 0.0)
		lamp.light_color = Color("a5eaff")
		lamp.light_energy = 0.65
		lamp.omni_range = 10.0
		lamp.shadow_enabled = false
		lamp.distance_fade_enabled = true
		lamp.distance_fade_begin = 45.0
		lamp.distance_fade_length = 15.0
		buttress.add_child(lamp)

	# A complete aperture is scientific enough to read as a calibration device,
	# while its pointed vertical proportion still belongs to a castle. It floats
	# well above the final tread and has no collider, so it cannot become a new
	# low-ceiling version of the old crown defect.
	var aperture := Node3D.new()
	aperture.name = "ObservatoryAperture"
	aperture.position = Vector3(-0.35, 9.0, 0.0)
	facade.add_child(aperture)
	_add_mesh(aperture, _torus(4.16, 4.46), brass,
		Vector3.ZERO, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.5))
	_add_mesh(aperture, _torus(3.88, 4.02), cyan,
		Vector3.ZERO, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.5))

	# The foundation already carries the visible heavy load through its faceted
	# rock shelf and paired entrance buttresses. The science layer should be
	# lighter: one calm orbital calibration band reads as an instrument around
	# the lower towers, rather than large struts that compete with the roofline.
	var band := Node3D.new()
	band.name = "AetherCalibrationBand"
	# Its front-most point stays at least 2.4 m above the new threshold, so it
	# reads as a survey instrument rather than a beam across the player route.
	band.position = Vector3(0.0, 10.7, 0.0)
	_foundation.add_child(band)
	_add_mesh(band, _torus(11.4, 11.72), brass, Vector3.ZERO)
	_add_mesh(band, _torus(10.92, 11.08), cyan, Vector3.ZERO)
	_rotors.append(band)

	# Six deliberately placed readings preserve bilateral balance while keeping
	# the entire +/- 45 degree front sector free for the player-facing facade.
	var calibration_angles := [PI / 3.0, PI * 2.0 / 3.0, PI * 5.0 / 6.0,
		PI * 7.0 / 6.0, PI * 4.0 / 3.0, PI * 5.0 / 3.0]
	for i in calibration_angles.size():
		var angle: float = calibration_angles[i]
		var instrument := Node3D.new()
		instrument.name = "AetherCalibrationNode_%02d" % (i + 1)
		instrument.position = Vector3(cos(angle) * 11.32, 0.0, sin(angle) * 11.32)
		band.add_child(instrument)
		_add_mesh(instrument, _sphere(0.28, 0.52), violet, Vector3.ZERO)
		_add_mesh(instrument, _cylinder(0.42, 0.42, 0.12), brass,
			Vector3(0.0, -0.22, 0.0))


# This is the design move that turns an ordinary castle into the Art Castle:
# its existing central tower becomes a working celestial observatory. The
# crown is deliberately compact and axial so it strengthens the silhouette
# instead of covering the imported red roofs or becoming a separate building.
func _build_astral_observatory_crown() -> void:
	var crown := Node3D.new()
	crown.name = "AstralObservatoryCrown"
	# Source mesh inspection gives a 3.98 local-Y maximum; with the castle's 10x
	# scene scale and the foundation 4.2 m below root, the flag reaches ~44.0 m
	# in this coordinate space. Seat the crown just above it so the new identity
	# is visible in the skyline rather than hidden inside the imported roof.
	crown.position = Vector3(0.0, 44.5, 0.0)
	crown.set_meta("collision_policy", "visual_only_roof_observatory")
	_foundation.add_child(crown)

	var stone := _ink_material()
	var brass := _brass_material()
	var cyan := _glow_material(Color("64dcff"))
	var violet := _glow_material(Color("c58dff"))

	var drum := _add_mesh(crown, _cylinder(3.34, 3.6, 0.42), stone,
		Vector3(0.0, -0.34, 0.0))
	drum.name = "ObservatoryDrum"
	var brass_halo := _add_mesh(crown, _torus(3.42, 3.72), brass, Vector3.ZERO)
	brass_halo.name = "ObservatoryBrassHalo"
	var lumen_halo := _add_mesh(crown, _torus(3.06, 3.20), cyan,
		Vector3(0.0, 0.14, 0.0))
	lumen_halo.name = "ObservatoryLumenHalo"

	for i in 4:
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var fin := Node3D.new()
		fin.name = "CrownAstralFin_%d" % (i + 1)
		# These tall fins physically stitch the halo back into the conical roof.
		# They are the crown's four load-bearing telescope yokes, not little
		# decorative posts floating underneath a ring.
		fin.position = Vector3(cos(angle) * 3.46, 0.45, sin(angle) * 3.46)
		fin.rotation.y = -angle
		crown.add_child(fin)
		_add_mesh(fin, _box(Vector3(0.42, 5.2, 0.92)), brass, Vector3.ZERO)
		_add_mesh(fin, _box(Vector3(0.14, 4.36, 0.18)), cyan,
			Vector3(0.24, 0.06, 0.0))
		_add_mesh(fin, _sphere(0.32, 0.68), violet, Vector3(0.0, 2.78, 0.0))

	var lens := Node3D.new()
	lens.name = "CrownLumenLens"
	lens.position = Vector3(0.0, 2.35, 0.0)
	crown.add_child(lens)
	_add_mesh(lens, _sphere(1.0, 1.84), cyan, Vector3.ZERO)
	_add_mesh(lens, _torus(1.22, 1.42), brass, Vector3.ZERO,
		Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0))
	var lens_light := OmniLight3D.new()
	lens_light.name = "CrownLumenLight"
	lens_light.light_color = Color("a5eaff")
	lens_light.light_energy = 0.9
	lens_light.omni_range = 16.0
	lens_light.shadow_enabled = false
	lens_light.distance_fade_enabled = true
	lens_light.distance_fade_begin = 45.0
	lens_light.distance_fade_length = 15.0
	lens.add_child(lens_light)


# The reference artwork's identity comes from one readable astronomical
# machine woven through the castle silhouette, rather than many unrelated
# glowing props.  This whole assembly is visual-only and sits behind / outboard
# of the real entrance axis: the authored stair, court and door keep sole
# ownership of gameplay collision.
func _build_reference_astral_machine() -> void:
	var machine := Node3D.new()
	machine.name = "ReferenceAstralMachine"
	machine.set_meta("collision_policy", "visual_only_no_static_bodies")
	machine.set_meta("mesh_budget", 100)
	machine.set_meta("light_budget", 2)
	_foundation.add_child(machine)

	var stone := _ink_material()
	var brass := _brass_material()
	var cyan := _glow_material(Color("55e6ff"))
	var violet := _glow_material(Color("d68cff"))
	# The reference machine needs a stable cyan/violet material hierarchy even
	# before the journey awakens. Other citadel lights remain stage-driven.
	_light_materials.erase(cyan)
	_light_materials.erase(violet)
	cyan.emission_energy_multiplier = 0.86
	violet.emission_energy_multiplier = 0.72
	var panel_blue := StandardMaterial3D.new()
	panel_blue.albedo_color = Color("243c68")
	panel_blue.metallic = 0.68
	panel_blue.roughness = 0.38
	panel_blue.emission_enabled = true
	panel_blue.emission = Color("162c55")
	panel_blue.emission_energy_multiplier = 0.28

	# A 28 m measuring spire establishes the reference's dramatic vertical
	# ruler.  It is deliberately offset to the rear-west of the door and has a
	# deep, narrow section so it reads as architecture in side views as well as
	# a flat sign from the approach.
	var spire := Node3D.new()
	spire.name = "AetherMeasureSpire"
	spire.position = Vector3(-5.2, 20.0, 6.4)
	machine.add_child(spire)
	var spire_stone := stone.duplicate() as StandardMaterial3D
	spire_stone.albedo_color = Color("46587e")
	spire_stone.roughness = 0.55
	var monolith := _add_mesh(spire, _box(Vector3(4.6, 26.0, 4.2)), spire_stone,
		Vector3.ZERO)
	monolith.name = "AetherMeasureMonolith"
	var measure_face := _add_mesh(spire, _box(Vector3(4.18, 23.8, 0.18)), panel_blue,
		Vector3(0.0, 0.0, 2.14))
	measure_face.name = "AetherMeasureLayeredFace"
	for edge_index in 4:
		var edge_y := -9.4 + float(edge_index) * 6.25
		var edge := _add_mesh(spire, _box(Vector3(5.0, 0.42, 4.6)), brass,
			Vector3(0.0, edge_y, 0.0))
		edge.name = "AetherSpireBrassRail_%02d" % (edge_index + 1)
	for channel_index in 3:
		var channel := _add_mesh(spire,
			_box(Vector3(0.44, 18.0 - channel_index * 2.4, 0.30)), cyan,
			Vector3(-1.3 + channel_index * 1.3, -0.8 + channel_index * 0.7, 2.24))
		channel.name = "AetherSpireCyanChannel_%02d" % (channel_index + 1)
	var spire_base := _add_mesh(spire, _box(Vector3(5.6, 1.2, 5.2)), brass,
		Vector3(0.0, -13.55, 0.0))
	spire_base.name = "AetherSpireFoot"
	var spire_cap := _add_mesh(spire, _cylinder(1.5, 1.05, 1.5), brass,
		Vector3(0.0, 13.75, 0.0))
	spire_cap.name = "AetherSpireCrown"
	_add_astral_terminal(spire, "SpireTerminal", Vector3(0.0, 15.1, 0.0), brass, violet, 1.05)

	# The six-metre celestial core is integrated into the existing central tower
	# crown.  Three crossed instrument rings make the sphere read as a working
	# orrery from every approach angle.
	var core := Node3D.new()
	core.name = "CelestialCore"
	core.position = Vector3(0.0, 53.6, 0.0)
	machine.add_child(core)
	var core_glass := cyan.duplicate() as StandardMaterial3D
	core_glass.albedo_color = Color("7fd4f2")
	core_glass.emission = Color("55d9ff")
	core_glass.emission_energy_multiplier = 0.62
	var core_sphere := _add_mesh(core, _sphere(3.0, 6.0), core_glass, Vector3.ZERO)
	core_sphere.name = "CelestialCoreSphere"
	var core_heart := _add_mesh(core, _sphere(1.18, 2.36), violet, Vector3.ZERO)
	core_heart.name = "CelestialCoreHeart"
	for ring_index in 3:
		var ring_rotation: Vector3 = [Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0),
			Vector3(0.0, 0.0, PI * 0.5)][ring_index]
		var core_ring := _add_mesh(core, _torus(4.0, 4.34), brass,
			Vector3.ZERO, Vector3.ONE, ring_rotation)
		core_ring.name = "CelestialCoreRing_%02d" % (ring_index + 1)
	var core_stalk := _add_mesh(core, _cylinder(0.5, 0.85, 5.0), brass,
		Vector3(0.0, -5.6, 0.0))
	core_stalk.name = "CelestialCoreStalk"
	var core_light := OmniLight3D.new()
	core_light.name = "CelestialCoreLight"
	core_light.light_color = Color("9befff")
	core_light.light_energy = 0.45
	core_light.omni_range = 18.0
	core_light.shadow_enabled = false
	core_light.distance_fade_enabled = true
	core_light.distance_fade_begin = 45.0
	core_light.distance_fade_length = 15.0
	core.add_child(core_light)

	# Twin articulated skyline arms frame the tower like enormous telescope
	# yokes.  Every point remains far outside the +/-2.4 m entrance corridor.
	_build_lumen_arm(machine, 1,
		[Vector3(-3.6, 20.0, -3.4), Vector3(-3.0, 42.0, -13.2),
		Vector3(10.0, 31.0, -13.8)], brass, cyan, violet)
	_build_lumen_arm(machine, 2,
		[Vector3(-3.4, 19.0, 3.4), Vector3(-2.0, 38.0, 13.2),
		Vector3(9.0, 29.0, 13.8)], brass, violet, cyan)

	# A single slow archive cube supplies the reference's floating magical data
	# object.  Its six cyan inset faces remain legible during rotation.
	var archive := Node3D.new()
	archive.name = "FloatingArchiveCube"
	archive.position = Vector3(-2.0, 34.5, -8.6)
	archive.rotation_degrees = Vector3(18.0, 22.0, 10.0)
	machine.add_child(archive)
	var archive_body := _add_mesh(archive, _box(Vector3(5.4, 5.4, 5.4)), panel_blue,
		Vector3.ZERO)
	archive_body.name = "ArchiveCubeBody"
	var archive_glow := cyan.duplicate() as StandardMaterial3D
	archive_glow.emission_energy_multiplier = 1.05
	var face_specs := [
		[Vector3(2.76, 0.0, 0.0), Vector3(0.10, 3.6, 3.6)],
		[Vector3(-2.76, 0.0, 0.0), Vector3(0.10, 3.6, 3.6)],
		[Vector3(0.0, 2.76, 0.0), Vector3(3.6, 0.10, 3.6)],
		[Vector3(0.0, -2.76, 0.0), Vector3(3.6, 0.10, 3.6)],
		[Vector3(0.0, 0.0, 2.76), Vector3(3.6, 3.6, 0.10)],
		[Vector3(0.0, 0.0, -2.76), Vector3(3.6, 3.6, 0.10)],
	]
	for face_index in face_specs.size():
		var face := _add_mesh(archive, _box(face_specs[face_index][1]), archive_glow,
			face_specs[face_index][0])
		face.name = "ArchiveLuminousFace_%02d" % (face_index + 1)
	_rotors.append(archive)

	# An ordered script facade turns the rear elevation into a visibly working
	# computational archive.  Four stepped panels, a rune belt and a three-gear
	# train use strong low-poly shapes that remain readable from village scale.
	var script_facade := Node3D.new()
	script_facade.name = "MachineScriptFacade"
	script_facade.position = Vector3(-4.4, 13.0, -5.2)
	script_facade.rotation_degrees.y = -52.0
	machine.add_child(script_facade)
	for panel_index in 4:
		var panel := _add_mesh(script_facade,
			_box(Vector3(5.4 - panel_index * 0.24, 2.6, 0.34)), panel_blue,
			Vector3(0.0, panel_index * 2.35, 0.0))
		panel.name = "MachineScriptPanel_%02d" % (panel_index + 1)
		var script_line := _add_mesh(script_facade,
			_box(Vector3(4.3 - panel_index * 0.22, 0.18, 0.12)), cyan,
			Vector3(0.0, panel_index * 2.35, -0.22))
		script_line.name = "MachineScriptInset_%02d" % (panel_index + 1)
	var rune_belt := _add_mesh(script_facade, _box(Vector3(6.4, 0.62, 0.38)), stone,
		Vector3(0.9, -1.7, 0.0))
	rune_belt.name = "MachineRuneBelt"
	for rune_index in 5:
		var rune := _add_mesh(script_facade, _box(Vector3(0.78, 0.16, 0.12)), cyan,
			Vector3(-1.0 + rune_index * 1.25, -1.7, -0.24), Vector3.ONE,
			Vector3(0.0, 0.0, (-0.24 if rune_index % 2 == 0 else 0.24)))
		rune.name = "MachineRune_%02d" % (rune_index + 1)
	for gear_index in 3:
		_build_facade_gear(script_facade, gear_index + 1,
			Vector3(-1.6 + gear_index * 2.0, 0.1 + gear_index * 1.4, -0.95),
			1.05 - gear_index * 0.12, brass, violet)

	# Small violet terminals distribute magical charge at otherwise mechanical
	# load joints, completing the magic/science grammar without adding lights.
	for terminal_index in 4:
		var terminal_positions := [Vector3(-7.4, 6.6, -5.2),
			Vector3(-5.8, 6.2, 5.6), Vector3(4.8, 20.0, -9.4),
			Vector3(4.2, 18.5, 9.2)]
		_add_astral_terminal(machine, "JointTerminal_%02d" % (terminal_index + 1),
			terminal_positions[terminal_index], brass, violet, 0.48)


func _build_lumen_arm(parent: Node3D, index: int, points: Array,
		outer_material: Material, conductor_material: Material,
		terminal_material: Material) -> void:
	var arm := Node3D.new()
	arm.name = "LumenArm_%02d" % index
	parent.add_child(arm)
	for segment_index in 2:
		var outer := _add_beam_between(arm, points[segment_index],
			points[segment_index + 1], 0.76, outer_material)
		outer.name = "LumenArmOuterBeam_%02d_%02d" % [index, segment_index + 1]
		var conductor_offset := Vector3(0.0, 0.0,
			0.43 if (points[segment_index] as Vector3).z >= 0.0 else -0.43)
		var conductor := _add_beam_between(arm,
			(points[segment_index] as Vector3) + conductor_offset,
			(points[segment_index + 1] as Vector3) + conductor_offset,
			0.16, conductor_material)
		conductor.name = "LumenArmConductor_%02d_%02d" % [index, segment_index + 1]
		var paired_from := (points[segment_index] as Vector3) + Vector3.DOWN * 0.72
		var paired_to := (points[segment_index + 1] as Vector3) + Vector3.DOWN * 0.72
		var paired_rail := _add_beam_between(arm, paired_from, paired_to, 0.32,
			outer_material)
		paired_rail.name = "LumenArmPairedRail_%02d_%02d" % [index, segment_index + 1]
	var truss_chord := _add_beam_between(arm, points[0], points[2], 0.34,
		outer_material)
	truss_chord.name = "LumenArmTrussChord_%02d" % index
	for joint_index in points.size():
		_add_astral_terminal(arm, "LumenArmJoint_%02d_%02d" % [index, joint_index + 1],
			points[joint_index], outer_material, terminal_material,
			0.76 if joint_index == 1 else (0.86 if joint_index == 0 else 0.54))


func _add_astral_terminal(parent: Node3D, terminal_name: String, position: Vector3,
		collar_material: Material, crystal_material: Material, radius: float) -> Node3D:
	var terminal := Node3D.new()
	terminal.name = terminal_name
	terminal.position = position
	parent.add_child(terminal)
	var collar := _add_mesh(terminal, _cylinder(radius * 0.82, radius, radius * 0.45),
		collar_material, Vector3(0.0, -radius * 0.44, 0.0))
	collar.name = "%s_Collar" % terminal_name
	var crystal := _add_mesh(terminal, _sphere(radius, radius * 2.4),
		crystal_material, Vector3(0.0, radius * 0.62, 0.0))
	crystal.name = "%s_Crystal" % terminal_name
	return terminal


func _add_beam_between(parent: Node3D, from: Vector3, to: Vector3,
		thickness: float, material: Material) -> MeshInstance3D:
	var delta := to - from
	var beam := _add_mesh(parent, _box(Vector3(thickness, thickness, delta.length())),
		material, from.lerp(to, 0.5))
	beam.basis = Basis.looking_at(delta.normalized(), Vector3.UP)
	return beam


func _add_curved_root(parent: Node3D, root_name: String, points: Array[Vector3],
		radii: PackedFloat32Array, material: Material,
		radial_segments: int) -> MeshInstance3D:
	var root := _add_mesh(parent, _curved_root_mesh(points, radii, radial_segments),
		material, Vector3.ZERO)
	root.name = root_name
	return root


func _curved_root_mesh(points: Array[Vector3], radii: PackedFloat32Array,
		radial_segments: int) -> ArrayMesh:
	assert(points.size() >= 2 and points.size() == radii.size())
	var sampled := _sample_root_curve(points, radii, 4)
	var mesh_points := sampled.points as Array[Vector3]
	var mesh_radii := sampled.radii as PackedFloat32Array
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal_axis := Vector3.ZERO
	for point_index in mesh_points.size():
		var tangent: Vector3
		if point_index == 0:
			tangent = (mesh_points[1] - mesh_points[0]).normalized()
		elif point_index == mesh_points.size() - 1:
			tangent = (mesh_points[point_index] - mesh_points[point_index - 1]).normalized()
		else:
			tangent = (mesh_points[point_index + 1] - mesh_points[point_index - 1]).normalized()
		# Parallel-transport the ring frame along the curve. Rebuilding it from a
		# global axis at every point caused sudden 90-degree flips, visible as dark
		# bands across the old roots.
		if point_index == 0:
			var reference := Vector3.RIGHT if absf(tangent.dot(Vector3.UP)) > 0.88 else Vector3.UP
			normal_axis = tangent.cross(reference).normalized()
		else:
			normal_axis = normal_axis - tangent * normal_axis.dot(tangent)
			if normal_axis.length_squared() < 0.0001:
				var fallback := Vector3.RIGHT if absf(tangent.dot(Vector3.UP)) > 0.88 else Vector3.UP
				normal_axis = tangent.cross(fallback)
			normal_axis = normal_axis.normalized()
		var binormal := tangent.cross(normal_axis).normalized()
		for side_index in radial_segments:
			var angle := TAU * float(side_index) / float(radial_segments)
			var radial := normal_axis * cos(angle) + binormal * sin(angle)
			surface.set_uv(Vector2(float(side_index) / float(radial_segments),
				float(point_index) / float(mesh_points.size() - 1)))
			surface.add_vertex(mesh_points[point_index] + radial * mesh_radii[point_index])
	# Seal both ends. Open root tubes exposed flat interior wedges from oblique
	# castle views, which made otherwise connected roots appear broken or floating.
	var start_center := mesh_points.size() * radial_segments
	surface.set_uv(Vector2(0.5, 0.0))
	surface.add_vertex(mesh_points[0])
	var end_center := start_center + 1
	surface.set_uv(Vector2(0.5, 1.0))
	surface.add_vertex(mesh_points[-1])
	for ring_index in mesh_points.size() - 1:
		for side_index in radial_segments:
			var next_side := (side_index + 1) % radial_segments
			var current := ring_index * radial_segments + side_index
			var current_next := ring_index * radial_segments + next_side
			var upper := (ring_index + 1) * radial_segments + side_index
			var upper_next := (ring_index + 1) * radial_segments + next_side
			for vertex_index in [current, upper, current_next, current_next, upper, upper_next]:
				surface.add_index(vertex_index)
	var final_ring_start := (mesh_points.size() - 1) * radial_segments
	for side_index in radial_segments:
		var next_side := (side_index + 1) % radial_segments
		for vertex_index in [start_center, next_side, side_index]:
			surface.add_index(vertex_index)
		for vertex_index in [end_center, final_ring_start + side_index,
				final_ring_start + next_side]:
			surface.add_index(vertex_index)
	surface.generate_normals()
	return surface.commit() as ArrayMesh


func _sample_root_curve(points: Array[Vector3], radii: PackedFloat32Array,
		steps_per_segment: int) -> Dictionary:
	var sampled_points: Array[Vector3] = []
	var sampled_radii := PackedFloat32Array()
	for segment_index in points.size() - 1:
		var p0 := points[maxi(segment_index - 1, 0)]
		var p1 := points[segment_index]
		var p2 := points[segment_index + 1]
		var p3 := points[mini(segment_index + 2, points.size() - 1)]
		for step_index in steps_per_segment:
			var t := float(step_index) / float(steps_per_segment)
			var t2 := t * t
			var t3 := t2 * t
			var point := 0.5 * ((2.0 * p1) + (-p0 + p2) * t \
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 \
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			sampled_points.append(point)
			sampled_radii.append(lerpf(radii[segment_index], radii[segment_index + 1], t))
	sampled_points.append(points[-1])
	sampled_radii.append(radii[-1])
	return {"points": sampled_points, "radii": sampled_radii}


func _spiral_offset_curve(points: Array[Vector3], radius: float, phase: float,
		twist: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for point_index in points.size():
		var taper := lerpf(1.0, 0.38, float(point_index) / float(points.size() - 1))
		var angle := phase + float(point_index) * twist
		result.append(points[point_index] + Vector3(cos(angle) * radius * taper,
			0.22 * sin(angle * 1.7), sin(angle) * radius * taper))
	return result


func _build_facade_gear(parent: Node3D, index: int, position: Vector3,
		radius: float, brass: Material, glow: Material) -> void:
	var gear := Node3D.new()
	gear.name = "MachineFacadeGear_%02d" % index
	gear.position = position
	gear.rotation.x = PI * 0.5
	parent.add_child(gear)
	var hub := _add_mesh(gear, _cylinder(radius * 0.34, radius * 0.34, 0.42),
		glow, Vector3.ZERO)
	hub.name = "MachineGearHub_%02d" % index
	var wheel := _add_mesh(gear, _torus(radius * 0.56, radius * 0.78), brass,
		Vector3.ZERO, Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0))
	wheel.name = "MachineGearWheel_%02d" % index
	for tooth_index in 6:
		var angle := TAU * float(tooth_index) / 6.0
		var tooth := _add_mesh(gear,
			_box(Vector3(radius * 0.38, radius * 0.22, 0.46)), brass,
			Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), Vector3.ONE,
			Vector3(0.0, -angle, 0.0))
		tooth.name = "MachineGearTooth_%02d_%02d" % [index, tooth_index + 1]


func _add_foundation_support(name: String, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.position = position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_foundation.add_child(body)


# Preserve the imported albedo texture in shadow by reusing it as a very low
# emission texture. Direct sunlight still supplies shape; this only prevents the
# castle from collapsing into a single mauve silhouette against the bright sky.
func _brighten_castle_materials(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_node := child as MeshInstance3D
			if mesh_node.mesh != null:
				for surface in mesh_node.mesh.get_surface_count():
					var source := mesh_node.get_active_material(surface)
					if source is StandardMaterial3D:
						var material := source.duplicate() as StandardMaterial3D
						material.emission_enabled = true
						material.emission = Color(0.34, 0.31, 0.29)
						material.emission_energy_multiplier = 0.13
						if material.albedo_texture != null:
							material.emission_texture = material.albedo_texture
						mesh_node.set_surface_override_material(surface, material)
		_brighten_castle_materials(child)

func _build_citadel_rig() -> void:
	var rig := Node3D.new()
	rig.name = "LumenEngineRig"
	_castle.add_child(rig)

	# The undercarriage gives the authored castle a singular identity: an
	# observatory, a power plant, and a sanctuary in the same silhouette.
	var engine := Node3D.new()
	engine.name = "Heart_Engine"
	engine.position = Vector3(0.0, -0.58, 0.0)
	rig.add_child(engine)
	_add_mesh(engine, _sphere(0.62, 1.12), _glow_material(STAGE_COLOURS[0]),
		Vector3.ZERO, Vector3(1.0, 0.62, 1.0))
	_add_mesh(engine, _cylinder(0.88, 0.88, 0.18), _brass_material(),
		Vector3(0.0, -0.23, 0.0))
	_add_mesh(engine, _torus(0.34, 0.76), _brass_material(),
		Vector3(0.0, 0.02, 0.0), Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0))

	_citadel_lamp = OmniLight3D.new()
	_citadel_lamp.position = Vector3(0.0, -0.2, 0.0)
	_citadel_lamp.omni_range = 18.0
	_citadel_lamp.shadow_enabled = false
	_citadel_lamp.distance_fade_enabled = true
	_citadel_lamp.distance_fade_begin = 45.0
	_citadel_lamp.distance_fade_length = 15.0
	engine.add_child(_citadel_lamp)

	# Four articulated stabilisers read as a travelling machine, not a static
	# fantasy prop. They fold outward gently beneath the existing castle.
	for i in range(4):
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var leg := Node3D.new()
		leg.name = "Stabiliser_%d" % (i + 1)
		leg.position = Vector3(cos(angle) * 0.78, -0.42, sin(angle) * 0.78)
		leg.rotation.y = -angle
		rig.add_child(leg)
		_add_mesh(leg, _box(Vector3(0.17, 0.72, 0.18)), _brass_material(),
			Vector3(0.0, -0.35, 0.34), Vector3.ONE, Vector3(0.48, 0.0, 0.0))
		_add_mesh(leg, _box(Vector3(0.34, 0.13, 0.46)), _ink_material(),
			Vector3(0.0, -0.78, 0.62))

	# Three orbital instruments visibly turn. Their motion is intentionally
	# modest: a child-focused hub should feel wonderous, never frantic.
	for i in range(3):
		var rotor := Node3D.new()
		rotor.name = "Orbit_Instrument_%d" % (i + 1)
		rotor.position = Vector3(0.0, 0.95 + i * 0.25, 0.0)
		rotor.rotation_degrees = Vector3(28.0 + i * 19.0, i * 58.0, 0.0)
		rig.add_child(rotor)
		_add_mesh(rotor, _torus(0.48 + i * 0.14, 0.53 + i * 0.14), _brass_material(), Vector3.ZERO)
		var bead_position := Vector3(0.54 + i * 0.14, 0.0, 0.0)
		_add_mesh(rotor, _sphere(0.1, 0.1), _glow_material(STAGE_COLOURS[0]), bead_position)
		_rotors.append(rotor)

	# The castle is imported at 10x scale. Counter-scale its physical plaque so
	# it reads as entrance signage instead of a giant HUD title across the sky.
	var plaque := _add_title(rig, "LUMEN CITADEL", Vector3(0.0, 2.2, 0.0),
		Color("ffe5a1"), 34)
	plaque.scale = Vector3.ONE * 0.1


# --- Living map ------------------------------------------------------

func _build_skyway() -> void:
	var map := Node3D.new()
	map.name = "SkywayMap"
	get_parent().add_child(map)

	# A small, physical constellation is more useful than a full-screen map:
	# it literally connects the sleeping citadel to the first kingdom.
	var route := [
		Vector3(-28.0, 42.0, 22.0),
		Vector3(5.0, 39.0, 5.0),
		Vector3(35.0, 33.0, -20.0),
		Vector3(65.0, 27.0, -53.0),
		THOUGHTS_PORTAL + Vector3(0.0, 7.0, 0.0),
	]

	for i in route.size():
		var point: Vector3 = route[i]
		var star := MeshInstance3D.new()
		star.name = "Skyway_Star_%d" % (i + 1)
		star.mesh = _sphere(0.42 if i == route.size() - 1 else 0.22,
			0.42 if i == route.size() - 1 else 0.22)
		star.material_override = _glow_material(STAGE_COLOURS[0])
		star.position = point
		map.add_child(star)

		var lamp := OmniLight3D.new()
		lamp.position = point
		lamp.omni_range = 7.5
		lamp.light_energy = 0.8
		lamp.shadow_enabled = false
		map.add_child(lamp)
		_waypoint_lights.append(lamp)

		if i > 0:
			_add_route_segment(map, route[i - 1], point)

	var destination := Node3D.new()
	destination.name = "MindSparkWaypoint"
	destination.position = THOUGHTS_PORTAL + Vector3(0.0, 8.3, 0.0)
	map.add_child(destination)
	_add_mesh(destination, _torus(0.92, 1.02), _glow_material(STAGE_COLOURS[1]), Vector3.ZERO)
	_add_title(destination, "MIND SPARK KINGDOM", Vector3(0.0, 1.25, 0.0), Color("b9dfff"), 36)
	_add_title(destination, "Begin with one thought", Vector3(0.0, 0.78, 0.0), Color("eff7ff"), 22)


func _add_route_segment(parent: Node3D, from: Vector3, to: Vector3) -> void:
	# Long emissive cylinders crossed the camera as bright white cables. A
	# constellation should be read as points the eye completes, so the route is
	# now a restrained sequence of floating brass-and-blue beads.
	const BEADS := 7
	var bead_material := _glow_material(Color("789dcc"))
	for bead_index in BEADS:
		var t := (float(bead_index) + 1.0) / float(BEADS + 1)
		var bead := MeshInstance3D.new()
		bead.name = "Skyway_Bead"
		bead.mesh = _sphere(0.08, 0.08)
		bead.material_override = bead_material
		bead.position = from.lerp(to, t)
		bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Readable unique names make the generated route inspectable in Godot and
		# allow regression tests to count every bead rather than anonymous nodes.
		parent.add_child(bead, true)


# --- Tiny mesh/material helpers -------------------------------------

func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, position: Vector3,
		scale := Vector3.ONE, rotation := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = position
	part.scale = scale
	part.rotation = rotation
	parent.add_child(part)
	return part


func _add_title(parent: Node3D, title: String, position: Vector3, colour: Color,
		size: int) -> Label3D:
	var label := Label3D.new()
	label.text = title
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.font_size = size
	label.outline_size = 5
	label.modulate = colour
	label.pixel_size = 0.008
	parent.add_child(label)
	return label


func _glow_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 0.45
	material.metallic = 0.18
	material.roughness = 0.26
	_light_materials.append(material)
	return material


func _brass_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = BRASS
	material.metallic = 0.9
	material.roughness = 0.31
	return material


func _ink_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = INK
	material.metallic = 0.55
	material.roughness = 0.48
	return material


func _sphere(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


func _cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 12
	return mesh


func _torus(inner_radius: float, outer_radius: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 12
	mesh.ring_segments = 8
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _current_stage() -> int:
	var js := get_node_or_null("/root/JourneyState")
	return clampi(js.stage, 0, STAGE_COLOURS.size() - 1) if js != null else 0
