# Island 1 — ARTÉA Castle, the central hub of Sky Isles.
#
# The biggest, busiest island: an asymmetrical patchwork castle silhouette
# (mismatched tower heights read as "built up over centuries", not designed
# in one pass), a chain/root anchor disappearing into the fog below to sell
# "floating island" rather than "island on an invisible platform", and a
# Grand Station at the base where all three rail lines (C's job) terminate.
#
# The courtyard plaza is left as empty flat ground on purpose — it is the
# GALLERY_ANCHOR, a hook point future gallery content mounts into. Nothing
# is built on it here.
#
# Runtime-authored, same convention as hub_magitech.gd: geometry goes up in
# _ready() so the only checked-in scene file is sky_isles.tscn itself.
extends Node3D

# Falls back to these if isle_builder.gd (Agent A) is not present yet when
# this script runs — lets this island be verified standalone. isle_builder's
# API is the primary path; this local copy only mirrors its low-poly-blob
# shape closely enough to sanity-check placement and scale.
const ISLE_ID := "castle"
const ISLE_POS := Vector3(0, 0, 0)
const ISLE_RADIUS := 34.0

# Dormant palette. Agent A's sky_isles_world.gd owns the canonical PALETTE
# const; these are the contract's documented castle values duplicated here
# so this file has no hard load-order dependency on world script existing.
const DORMANT_COLOR := Color(0.42, 0.40, 0.48)
const VIBRANT_COLOR := Color(0.85, 0.80, 0.92)

# Stone tones for the castle mass, independent of the island-body palette —
# the castle sits ON the island, it isn't tinted the same as the rock.
const STONE_LIGHT := Color(0.58, 0.55, 0.58)
const STONE_DARK := Color(0.40, 0.38, 0.42)
const ROOF_SLATE := Color(0.30, 0.28, 0.34)
const CHAIN_IRON := Color(0.20, 0.19, 0.22)

# World-space plaza centre, sitting on top of the island body at the castle
# courtyard. Exposed as a const (matches the "expose via const" half of the
# contract instruction) and also stamped as meta on this node so anything
# that only has a NodePath, not a script reference, can still read it.
const PLAZA_POS := Vector3(0.0, 6.4, 6.0)

var _materials: Array[StandardMaterial3D] = []
var _emissives: Array[StandardMaterial3D] = []
var _lights: Array[Light3D] = []
var _particles: Array[GPUParticles3D] = []


func _ready() -> void:
	name = "Isle_castle"

	# Metadata every other system reads (rail_network, travel_controller,
	# isle_state, sky_isles_world's bob). Set before geometry so a system
	# that reacts to child-entered-tree still sees complete meta.
	set_meta("isle_id", ISLE_ID)
	set_meta("bob_phase", 0.0)  # first island — zero phase offset is fine, A staggers the rest

	var island_root := Node3D.new()
	island_root.name = "IslandBody"
	add_child(island_root)
	island_root.position = ISLE_POS

	_build_island_body(island_root)
	_build_anchor_chain(island_root)
	_build_castle(island_root)
	_build_grand_station(island_root)
	_build_courtyard(island_root)  # GALLERY_ANCHOR lives here — empty plaza, no props

	# Camera/platform anchors are world-space (island_root sits at ISLE_POS,
	# no rotation, so local + ISLE_POS is world here).
	set_meta("platform_pos", ISLE_POS + Vector3(0.0, 2.4, ISLE_RADIUS - 3.0))
	set_meta("camera_anchor", ISLE_POS + Vector3(14.0, 16.0, ISLE_RADIUS + 10.0))
	set_meta("look_target", ISLE_POS + PLAZA_POS)


# --- island body -------------------------------------------------------

# The rock the castle stands on. A low-poly hemisphere-ish blob rather than
# a flat disc, so the island reads as a chunk of torn-off ground, not a
# coin. This mirrors isle_builder.gd's expected shape closely so swapping
# to the real helper later (once Agent A's file lands) does not shift the
# castle's footprint.
func _build_island_body(parent: Node3D) -> void:
	var builder := load("res://scripts/sky_isles/isle_builder.gd")
	if builder != null and builder.has_method("build_island"):
		# Typed explicitly: load() returns Variant, so := would infer Variant
		# and trip the project's warnings-as-errors setting.
		var body: Node3D = builder.build_island(ISLE_RADIUS, DORMANT_COLOR)
		parent.add_child(body)
		var mat := _find_first_material(body)
		if mat != null:
			_materials.append(mat)
		return

	_build_fallback_body(parent)


# Local stand-in used only when isle_builder.gd has not landed yet. Kept
# deliberately simple: a squashed low-poly sphere for the mass plus a
# tapered cone underside so the silhouette still narrows toward the chain.
func _build_fallback_body(parent: Node3D) -> void:
	var top := MeshInstance3D.new()
	var top_mesh := SphereMesh.new()
	top_mesh.radius = ISLE_RADIUS
	top_mesh.height = ISLE_RADIUS * 1.1
	top_mesh.radial_segments = 12
	top_mesh.rings = 6
	top.mesh = top_mesh
	top.position.y = 0.0
	top.scale = Vector3(1.0, 0.32, 1.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = DORMANT_COLOR
	mat.roughness = 0.95
	top.material_override = mat
	_materials.append(mat)
	parent.add_child(top)

	var under := MeshInstance3D.new()
	var under_mesh := CylinderMesh.new()
	under_mesh.top_radius = ISLE_RADIUS * 0.75
	under_mesh.bottom_radius = ISLE_RADIUS * 0.1
	under_mesh.height = ISLE_RADIUS * 0.9
	under_mesh.radial_segments = 10
	under.mesh = under_mesh
	under.position.y = -ISLE_RADIUS * 0.55
	under.material_override = mat
	parent.add_child(under)


func _find_first_material(node: Node) -> StandardMaterial3D:
	if node is MeshInstance3D and node.material_override is StandardMaterial3D:
		return node.material_override
	for child in node.get_children():
		var found := _find_first_material(child)
		if found != null:
			return found
	return null


# Chain links disappearing straight down into the fog, selling "this island
# used to be anchored to something below" without needing actual fog
# shader work (Agent A owns fog).
func _build_anchor_chain(parent: Node3D) -> void:
	var chain := Node3D.new()
	chain.name = "AnchorChain"
	parent.add_child(chain)

	var iron := StandardMaterial3D.new()
	iron.albedo_color = CHAIN_IRON
	iron.metallic = 0.6
	iron.roughness = 0.5

	var link_count := 9
	var link_h := 3.2
	var start_y := -ISLE_RADIUS * 0.95

	for i in link_count:
		var link := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.5
		mesh.outer_radius = 1.1
		mesh.rings = 6
		mesh.ring_segments = 5
		link.mesh = mesh
		link.material_override = iron
		# Alternate 90-degree twist so links visually interlock instead of
		# stacking as flat rings.
		link.rotation.x = 0.0 if i % 2 == 0 else PI * 0.5
		link.position = Vector3(0.0, start_y - float(i) * link_h, 0.0)
		chain.add_child(link)

	# A root-cluster mesh at the very bottom, fading into fog — reads as
	# torn earth/roots rather than the chain simply stopping mid-air.
	var root_mass := MeshInstance3D.new()
	var root_mesh := SphereMesh.new()
	root_mesh.radius = ISLE_RADIUS * 0.22
	root_mesh.height = ISLE_RADIUS * 0.5
	root_mesh.radial_segments = 6
	root_mesh.rings = 3
	root_mass.mesh = root_mesh
	root_mass.material_override = iron
	root_mass.position = Vector3(0.0, start_y - float(link_count) * link_h - 4.0, 0.0)
	chain.add_child(root_mass)


# --- castle mass ---------------------------------------------------------

# Asymmetrical patchwork silhouette: a cluster of boxes/cylinders at
# mismatched heights standing in for keep + wings + towers, plus a
# scattering of pipe/chimney shapes. Deliberately low-detail — the
# silhouette against the sky sells the read, not surface detail.
func _build_castle(parent: Node3D) -> void:
	var castle := Node3D.new()
	castle.name = "Castle"
	parent.add_child(castle)
	castle.position.y = 4.5  # sits proud of the island body's crown

	var stone_light := _mat(STONE_LIGHT)
	var stone_dark := _mat(STONE_DARK)
	_materials.append(stone_light)
	_materials.append(stone_dark)

	# Central keep — the tallest mass, roughly centred but offset so the
	# courtyard (south side, +Z) stays clear.
	_box(castle, Vector3(-2.0, 9.0, -4.0), Vector3(14.0, 18.0, 12.0), stone_light)
	_pyramid_roof(castle, Vector3(-2.0, 18.5, -4.0), 9.0, 5.0, ROOF_SLATE)

	# Mismatched towers — each a different height/radius, the asymmetry is
	# the whole point.
	var towers := [
		{"pos": Vector3(-11.0, 0.0, -9.0), "h": 24.0, "r": 3.4},
		{"pos": Vector3(7.0, 0.0, -11.0), "h": 15.0, "r": 2.6},
		{"pos": Vector3(-9.0, 0.0, 4.0), "h": 11.0, "r": 2.2},
		{"pos": Vector3(10.5, 0.0, 1.0), "h": 19.0, "r": 3.0},
	]
	for t in towers:
		var tower := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = t["r"]
		mesh.bottom_radius = t["r"] * 1.15
		mesh.height = t["h"]
		mesh.radial_segments = 8
		tower.mesh = mesh
		tower.material_override = stone_light if t["h"] > 16.0 else stone_dark
		tower.position = t["pos"] + Vector3(0.0, t["h"] * 0.5, 0.0)
		castle.add_child(tower)

		var cap := MeshInstance3D.new()
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = 0.0
		cap_mesh.bottom_radius = t["r"] * 1.25
		cap_mesh.height = t["r"] * 2.2
		cap_mesh.radial_segments = 8
		cap.mesh = cap_mesh
		cap.material_override = _mat(ROOF_SLATE)
		cap.position = t["pos"] + Vector3(0.0, t["h"] + t["r"] * 1.1, 0.0)
		castle.add_child(cap)

		_windows(castle, t["pos"], t["h"], t["r"])

	# Lower wing — a long low block connecting keep to the towers, breaking
	# up the silhouette so it doesn't read as "keep + four sticks".
	_box(castle, Vector3(2.0, 5.0, -9.5), Vector3(20.0, 8.0, 5.0), stone_dark)

	# Protruding pipes/chimneys — the patchwork detail called out in spec.
	_chimneys(castle)


func _windows(parent: Node3D, base: Vector3, height: float, radius: float) -> void:
	# Unlit windows for dormant start: dark, unemissive panes. isle_state.gd
	# (Agent D) flips these emissive when it drives vibrant via the
	# emissives array from state_targets().
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.08, 0.08, 0.10)
	glow.emission_enabled = true
	glow.emission = Color(1.00, 0.86, 0.55)
	glow.emission_energy_multiplier = 0.0  # dormant: off
	_emissives.append(glow)

	var rows := int(height / 5.0)
	for i in rows:
		var pane := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(radius * 0.5, 1.0, 0.15)
		pane.mesh = mesh
		pane.material_override = glow
		pane.position = base + Vector3(0.0, 2.5 + float(i) * 5.0, radius * 0.95)
		parent.add_child(pane)


func _chimneys(parent: Node3D) -> void:
	var iron := _mat(CHAIN_IRON)
	var spots := [
		Vector3(-2.0, 18.0, -1.0), Vector3(4.0, 14.0, -8.0),
		Vector3(-6.0, 13.5, -2.0), Vector3(6.0, 5.5, -10.5),
	]
	for i in spots.size():
		var pipe := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		var h: float = 3.0 + float(i % 3)
		mesh.top_radius = 0.4
		mesh.bottom_radius = 0.5
		mesh.height = h
		mesh.radial_segments = 6
		pipe.mesh = mesh
		pipe.material_override = iron
		pipe.position = spots[i] + Vector3(0.0, h * 0.5, 0.0)
		parent.add_child(pipe)


func _pyramid_roof(parent: Node3D, pos: Vector3, base_radius: float, height: float, color: Color) -> void:
	var roof := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = Vector3(base_radius * 1.6, height, base_radius * 1.6)
	roof.mesh = mesh
	roof.material_override = _mat(color)
	roof.position = pos + Vector3(0.0, height * 0.5, 0.0)
	parent.add_child(roof)


# --- grand station ---------------------------------------------------------

# Open-air platform structure at the base of the island, facing outward
# (south, +Z) so incoming rail lines from all three kingdoms have a clean
# unobstructed approach. All 3 lines (Agent C) terminate at platform_pos.
func _build_grand_station(parent: Node3D) -> void:
	var station := Node3D.new()
	station.name = "GrandStation"
	parent.add_child(station)

	var deck_pos := Vector3(0.0, 1.8, ISLE_RADIUS - 4.5)
	station.position = deck_pos

	var stone := _mat(STONE_LIGHT)
	_materials.append(stone)

	var deck := MeshInstance3D.new()
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(18.0, 1.0, 10.0)
	deck.mesh = deck_mesh
	deck.material_override = stone
	station.add_child(deck)

	# Open-air roof: posts + a flat canopy, no walls, so it reads as a
	# platform, not a building.
	var canopy_mat := _mat(STONE_DARK)
	_materials.append(canopy_mat)
	var post_positions := [
		Vector3(-8.0, 0.0, -4.0), Vector3(8.0, 0.0, -4.0),
		Vector3(-8.0, 0.0, 4.0), Vector3(8.0, 0.0, 4.0),
	]
	for p in post_positions:
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.35
		post_mesh.bottom_radius = 0.4
		post_mesh.height = 6.0
		post.mesh = post_mesh
		post.material_override = stone
		post.position = p + Vector3(0.0, 3.5, 0.0)
		station.add_child(post)

	var canopy := MeshInstance3D.new()
	var canopy_mesh := BoxMesh.new()
	canopy_mesh.size = Vector3(19.0, 0.6, 11.0)
	canopy.mesh = canopy_mesh
	canopy.material_override = canopy_mat
	canopy.position = Vector3(0.0, 6.8, 0.0)
	station.add_child(canopy)

	# Lanterns marking where trains dock. Dormant: low energy, matches the
	# unlit-windows feel; isle_state.gd scales lights up via state_targets.
	for p in post_positions:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.00, 0.82, 0.55)
		lamp.light_energy = 0.15
		lamp.omni_range = 7.0
		lamp.shadow_enabled = false
		lamp.position = p + Vector3(0.0, 6.2, 0.0)
		station.add_child(lamp)
		_lights.append(lamp)

	# Ambient dormant motes at the station — off until vibrant.
	var particles := GPUParticles3D.new()
	particles.amount = 40
	particles.lifetime = 4.0
	particles.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 20.0
	pm.gravity = Vector3(0, 0.15, 0)
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9.0, 0.2, 5.0)
	particles.process_material = pm
	var pmesh := SphereMesh.new()
	pmesh.radius = 0.06
	pmesh.height = 0.12
	pmesh.radial_segments = 4
	pmesh.rings = 2
	particles.draw_pass_1 = pmesh
	station.add_child(particles)
	_particles.append(particles)


# --- courtyard / gallery anchor ---------------------------------------

# The central plaza. Left intentionally EMPTY — no props, no meshes beyond
# flat ground — so future gallery content has a clean world-space slot to
# mount into.
#
# GALLERY_ANCHOR
# This is the GALLERY_ANCHOR: the plaza's world position is exposed via the
# PLAZA_POS const above and mirrored onto set_meta("gallery_anchor", ...)
# below so a future system can find it either by reading this script or by
# reading meta off the Isle_castle node without a script reference.
func _build_courtyard(parent: Node3D) -> void:
	var plaza := MeshInstance3D.new()
	plaza.name = "CourtyardPlaza"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 10.0
	mesh.bottom_radius = 10.0
	mesh.height = 0.4
	mesh.radial_segments = 10
	plaza.mesh = mesh

	var mat := _mat(STONE_DARK)
	_materials.append(mat)
	plaza.material_override = mat
	plaza.position = PLAZA_POS
	parent.add_child(plaza)

	# GALLERY_ANCHOR: world position exposed for future gallery hookup.
	set_meta("gallery_anchor", ISLE_POS + PLAZA_POS)


# --- shared state interface --------------------------------------------

# One rectangular mass of the castle. The silhouette is built entirely from
# these — mismatched boxes at varying heights — so this stays deliberately
# plain rather than growing bevels or trim it does not need.
func _box(parent: Node3D, pos: Vector3, size: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var block := MeshInstance3D.new()

	var mesh := BoxMesh.new()
	mesh.size = size
	block.mesh = mesh
	block.position = pos
	block.material_override = material

	parent.add_child(block)
	return block


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


# Called once by isle_state.gd (Agent D) to collect real references for the
# dormant/vibrant swap. Arrays built during _build_* above are returned
# directly, not copied, per contract.
func state_targets() -> Dictionary:
	return {
		"materials": _materials,
		"emissives": _emissives,
		"lights": _lights,
		"particles": _particles,
	}
