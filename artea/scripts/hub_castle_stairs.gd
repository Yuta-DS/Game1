# A climbable stone tower and spiral stair reaching the floating castle.
#
# The castle hangs at Y=65.5 with its spire pointing down, over ground that
# runs 35-42 m. That is a 25-30 m gap with nothing to climb, so the castle
# reads as scenery rather than somewhere the player can go.
#
# The route is built as real architecture rather than a ribbon of floating
# steps: a tapered stone tower rises out of the hillside, and the stair winds
# up its outside face with each step anchored into the shaft. Every step has
# collision, so the player runs up it the same way they walk anywhere else in
# the hub — no teleport, no invisible ramp.
#
# Built at runtime like hub_magitech.gd and aether_atlas.gd, so
# New_Hub_World.tscn stays untouched and the whole structure can be removed by
# deleting one node.
extends Node3D

# Matches building_castle_red2 in New_Hub_World.tscn.
const CASTLE_XZ := Vector2(-51.4, 27.41)
const CASTLE_BASE_Y := 74.49

# The entrance datum remains where the approach gate/court stands. The castle
# model itself is raised 9.0 m, and hub_castle_entrance builds the final stair
# from this court to the elevated real threshold.
#
# The lower approach gate remains at 69.33. Raising the imported castle root
# to 74.49 moves its actual doorway to 78.33; the final ascent connects them.
const CASTLE_DOOR := Vector3(-39.8, 69.33, 27.41)
const CASTLE_THRESHOLD_Y := 78.33

# Outward from the door face, in world space. Everything the stair builds on
# the castle side is measured along this rather than assuming an axis.
const DOOR_OUT := Vector3.RIGHT

# Must track hub_castle_entrance exactly: the upper court now sits AT the
# entrance court (UPPER_DECK_Y = CASTLE_DOOR.y), and the arrival terrace sits
# one ceremonial rise below it. The castle itself is another 9.0 m higher.
# CEREMONIAL_RISE must equal hub_castle_entrance.CEREMONIAL_RISE — both files
# share one arrival level. The crown deck and the causeway both finish at
# TERRACE_DECK_Y so the player walks from stair to causeway to terrace on one
# continuous surface.
const CEREMONIAL_RISE := 1.6
const TERRACE_DECK_Y := CASTLE_DOOR.y - CEREMONIAL_RISE

# Horizontal extent of the courtyard, measured outward from the door. Must
# track hub_castle_entrance.PLAZA_LENGTH.
const PLAZA_LENGTH := 24.0

# The crown sits almost level with the real door. A larger gap made the final
# bridge climb sharply and left the stair visually detached from the castle.
const LANDING_GAP := 0.6

# The tower stands directly on the castle/entrance Z axis. Moving it outward
# along +X preserves foundation clearance while making the complete procession
# read as one line: spiral -> crown -> bridge -> gate -> elevated castle.
#
# X must clear the courtyard, which runs from the door (x = -39.8) out to
# x = -39.8 + PLAZA_LENGTH. With PLAZA_LENGTH at 24 that edge is x = -15.8, so
# the offset has to put the tower beyond it: -51.4 + 50 = -1.4, with the
# causeway spanning the remaining gap on the same Z coordinate.
const TOWER_OFFSET := Vector2(50.0, 0.0)

const TOWER_TOP_RADIUS := 3.0
const TOWER_BOTTOM_RADIUS := 4.0
const TOWER_SIDES := 8            # octagonal, matching the village towers

# Stair geometry.
#
# These numbers are a walkable surface first and a silhouette second. The player
# capsule is 0.5 m in radius, so the tread has to stay clear of the shaft for
# its whole height or the climb pinches: the previous build had a 6.4 m bottom
# radius on a shaft the stair orbited at 5.6 m, so the tower literally swallowed
# the lower flight and the player wedged against it a few steps up.
#
# Invariant to preserve when tuning: the tread's inner edge
# (STAIR_RADIUS - STEP_WIDTH/2) must stay outside TOWER_BOTTOM_RADIUS with room
# for the capsule. 6.5 - 1.9 = 4.6 against a 4.0 shaft leaves 0.6 m of margin.
const STAIR_RADIUS := 6.5
const STEP_WIDTH := 3.8
const STEP_DEPTH := 1.6

# Rise per tread. Kept well under the controller's MAX_STEP_HEIGHT (0.65) so
# every step is climbed by walking, never by jumping.
const STEP_RISE := 0.3
# A non-integer turn count prevents every flight, parapet and lamp from stacking
# on the exact same vertical axes. The previous three perfect turns produced
# the dense "architecture pile" visible in overhead shots.
const TURNS := 2.35

# Derived from the climb height rather than fixed, so the rise per tread stays
# constant no matter how far the castle sits above the ground. Solved in
# _build_stair() once the true height is known.
var _step_count := 96

const BRIDGE_SEGMENTS := 12       # continuous walkway from tower to castle
const BRIDGE_WIDTH := 4.8

# The Lumen Bridge's ceremonial dressing (halo arches, conduit pylons, rune
# inlays) is authored against these three numbers so it can never eat the
# route it is meant to celebrate. Every decorative piece must satisfy at least
# one of them:
#   - stand outside BRIDGE_CLEAR_HALF_WIDTH of the centreline (beyond the
#     guard walls, so the 4.8 m deck stays fully walkable), or
#   - crest above BRIDGE_CLEAR_HEADROOM over the deck surface (so nothing
#     passes through the player's capsule), or
#   - lie flush within BRIDGE_FLUSH_INLAY of the deck surface (an inlay the
#     player walks over, never a step or trip edge).
# Anything decorative is also visual-only: no _add_box_body, so a mis-sized
# ornament can never become a collision obstruction.
const BRIDGE_CLEAR_HALF_WIDTH := BRIDGE_WIDTH * 0.5   # 2.4 m each side
const BRIDGE_CLEAR_HEADROOM := 2.6                    # > the 2.4 m head datum
const BRIDGE_FLUSH_INLAY := 0.05
const LENS_GATE_HALF_WIDTH := 3.05
const BRIDGE_GUARD_HEIGHT := 1.35
# Length of each flared bridge mouth. The terrace is much wider than the
# bridge; square wall end caps made that narrowing an invisible dead stop for
# the player capsule. Angled wings now guide an off-centre approach inward.
const BRIDGE_GUARD_END_CLEARANCE := 1.4
const BRIDGE_GUARD_POST_COUNT := 5

# The Heart Melody district predates the castle stair. Its exterior row placed
# full-size homes directly against the spiral, so roofs and walls dominated the
# ascent even after their individual colliders were cleared. Remove complete
# village-building roots inside this radius; the farther district remains
# untouched and still reads as a settlement beyond the castle precinct.
const VILLAGE_BUILDING_CLEAR_RADIUS := 35.0
const VILLAGE_BUILDING_NAME_TOKENS: Array[String] = [
	"home", "house", "blacksmith", "archery", "tavern", "market",
	"church", "lumbermill", "watermill",
]

# Slate-blue castle masonry survives the hub's strong daylight and matches the
# imported citadel. The former near-white stone clipped to flat white, erasing
# tread depth and making hundreds of modeled details look untextured.
const STONE_LIGHT := Color(0.46, 0.54, 0.66)
const STONE_DARK := Color(0.24, 0.29, 0.39)
const ROOF_RED := Color(0.79, 0.25, 0.20)   # matches the village roofs
const RAIL_GLOW := Color(1.00, 0.72, 0.30)  # matches the castle lantern
const CIRCUIT_CYAN := Color(0.24, 0.88, 1.00)
const RUNE_VIOLET := Color(0.72, 0.42, 1.00)


func _ready() -> void:
	# Terrain and the castle settle first; building after a frame keeps the
	# tower aligned with where they actually ended up.
	await get_tree().process_frame
	await get_tree().physics_frame
	_build()

	# proton_scatter repopulates its output asynchronously and finishes after
	# this node's first frames, so a single clearing pass during _build() gets
	# overwritten and the offending tree grows straight back through the stair.
	# Sweep again once the scatter settles.
	for _i in 4:
		await get_tree().process_frame
		await get_tree().physics_frame
	_clear_obstructions(Vector2(CASTLE_XZ.x + TOWER_OFFSET.x, CASTLE_XZ.y + TOWER_OFFSET.y))


func _build() -> void:
	var rig := Node3D.new()
	rig.name = "CastleStair"
	add_child(rig)
	# Transforms go on AFTER add_child — setting them before the node is in the
	# tree loses them, which is what left the old district paths standing on end
	# instead of lying flat.
	rig.global_position = Vector3(CASTLE_XZ.x, 0.0, CASTLE_XZ.y)

	var base := Vector2(CASTLE_XZ.x + TOWER_OFFSET.x, CASTLE_XZ.y + TOWER_OFFSET.y)
	var ground := _ground_at(base.x, base.y)
	# The crown deck must finish level with the courtyard's arrival TERRACE,
	# which is the surface the causeway hands the player onto. Deriving it from
	# CASTLE_BASE_Y instead left the deck at y 65.4 against a terrace at 68.9 —
	# a 3.5 m wall with no way up, which is the missing connection in the
	# stair-top screenshot.
	var top_y := TERRACE_DECK_Y
	rig.set_meta("terrain_ground_y", ground)
	rig.set_meta("tower_top_y", top_y)
	rig.set_meta("tower_base", base)

	_clear_obstructions(base)
	_clear_nearby_village_buildings(base)
	_build_tower(rig, base, ground, top_y)
	_build_stair(rig, base, ground, top_y)
	_build_crown(rig, base, ground, top_y)
	_build_bridge(rig, base, top_y)


# Removes the WHOLE authored village instance, not a mesh or StaticBody child.
# That distinction matters for imported house scenes: deleting only the child
# collider can leave the roof and walls visible beside the stair, while
# deleting only the mesh can leave an invisible gameplay obstruction.
func _clear_nearby_village_buildings(base: Vector2) -> void:
	var hub_root := get_parent()
	if hub_root == null:
		return
	var district := hub_root.get_node_or_null("District_HeartMelody")
	if district == null:
		return

	for candidate in district.get_children():
		if not (candidate is Node3D):
			continue
		var building := candidate as Node3D
		var lower_name := String(building.name).to_lower()
		var is_village_building := false
		for token in VILLAGE_BUILDING_NAME_TOKENS:
			if lower_name.contains(token):
				is_village_building = true
				break
		if not is_village_building:
			continue
		var building_xz := Vector2(building.global_position.x, building.global_position.z)
		if building_xz.distance_to(base) < VILLAGE_BUILDING_CLEAR_RADIUS:
			building.queue_free()


# The hillside is dressed with scattered trees and rocks (proton_scatter), and
# the village districts stand nearby too. Neither knows anything about a stair
# and bridge that are created at runtime. A single scatter tree or a village
# house sitting in the corridor is enough to stop the climb dead, or to end up
# visibly beside/through the stair the way the outdated village house did.
#
# Rather than hand-editing the scatter output or the district layout, remove
# anything solid standing inside the FULL walking corridor — the tower's
# ground footprint, the spiral's own swept circle, and the bridge/causeway
# span out to the terrace — not just a tight ring around the tower base. Done
# before the stair is built so the geometry below is guaranteed a clear route.
#
# Never removes anything by broad category (e.g. "all StaticBody3D"). Every
# candidate is name-checked against PROTECTED_ANCESTOR_NAMES first, so the
# player, the castle/entrance/route the stair connects to, portals, the
# train/skyway systems and gameplay managers can never be swept up even if a
# future geometry change enlarges the corridor.
const PROTECTED_ANCESTOR_NAMES: Array[String] = [
	"NewPlayer", "CastleStairs", "CastleStair", "CastleEntrance",
	"CastleCrown", "CastleAtmosphere", "LumenCitadel", "AetherAtlas",
	"building_castle_red2", "CastleFoundation", "SkywayMap",
	"CrownStoryPortal", "HubLens", "Global", "CreationsSpawner",
	"Magitech", "LandmarkGlow",
]


func _clear_obstructions(base: Vector2) -> void:
	# A little wider than the treads so overhanging canopies go too.
	var stair_radius := STAIR_RADIUS + STEP_WIDTH * 0.5 + 1.5
	# The bridge's own end points, so the corridor covers the causeway too,
	# not just the spiral. Mirrors the geometry _build_bridge derives, kept in
	# terms of the same named constants so the two can't silently drift apart.
	var crown_centre := Vector3(base.x, TERRACE_DECK_Y, base.y)
	var bridge_target := Vector3(
		CASTLE_DOOR.x + PLAZA_LENGTH - 1.6, TERRACE_DECK_Y, CASTLE_DOOR.z)
	var bridge_start2 := Vector2(crown_centre.x, crown_centre.z)
	var bridge_end2 := Vector2(bridge_target.x, bridge_target.z)
	var corridor_half_width := BRIDGE_WIDTH * 0.5 + 1.5

	for body in _solid_bodies_near(get_tree().get_root(), base, stair_radius,
			bridge_start2, bridge_end2, corridor_half_width):
		body.queue_free()


# True if `node` or any of its ancestors up to the scene root is named in
# PROTECTED_ANCESTOR_NAMES. Checked before anything is queued for removal.
func _is_protected(node: Node) -> bool:
	var cursor: Node = node
	while cursor != null:
		if cursor == self or PROTECTED_ANCESTOR_NAMES.has(String(cursor.name)):
			return true
		cursor = cursor.get_parent()
	return false


# Distance from `point` to the segment `seg_a`-`seg_b`, for the bridge
# corridor check (Vector2 has no built-in segment distance).
func _distance_to_segment(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> float:
	var span := seg_b - seg_a
	var len_sq := span.length_squared()
	if len_sq < 0.0001:
		return point.distance_to(seg_a)
	var t: float = clampf((point - seg_a).dot(span) / len_sq, 0.0, 1.0)
	return point.distance_to(seg_a + span * t)


func _solid_bodies_near(node: Node, base: Vector2, stair_radius: float,
		bridge_start2: Vector2, bridge_end2: Vector2,
		corridor_half_width: float) -> Array[Node3D]:
	var hits: Array[Node3D] = []
	for child in node.get_children():
		# Never touch the stair's own parts, the castle it leads to, or any
		# other protected gameplay system — checked ahead of any geometry test.
		if _is_protected(child):
			continue
		if child is StaticBody3D and child.get_parent() is Node3D:
			var visual: Node3D = child.get_parent()
			if _is_protected(visual):
				continue
			var pos := visual.global_position
			if pos.y >= CASTLE_BASE_Y:
				continue
			var offset2 := Vector2(pos.x - base.x, pos.z - base.y)
			var in_stair_column := offset2.length() < stair_radius
			var in_bridge_corridor := _distance_to_segment(
				Vector2(pos.x, pos.z), bridge_start2, bridge_end2) < corridor_half_width
			if in_stair_column or in_bridge_corridor:
				hits.append(visual)
				continue
		hits.append_array(_solid_bodies_near(child, base, stair_radius,
			bridge_start2, bridge_end2, corridor_half_width))
	return hits


# The shaft the stair is cut into. Sunk below ground level so it grows out of
# the hillside instead of sitting on it.
func _build_tower(parent: Node3D, base: Vector2, ground: float, top_y: float) -> void:
	# The shaft is structure beneath the crown, not a pedestal in the middle of
	# the walking floor. Its old top reached 1 m above `top_y`, creating the
	# raised octagonal obstacle visible in the crown handoff render.
	var height := top_y - ground + 5.0
	var shaft := MeshInstance3D.new()
	shaft.name = "MasonryTower"
	var mesh := CylinderMesh.new()
	mesh.top_radius = TOWER_TOP_RADIUS
	mesh.bottom_radius = TOWER_BOTTOM_RADIUS
	mesh.height = height
	mesh.radial_segments = TOWER_SIDES
	shaft.mesh = mesh
	shaft.material_override = _stone(STONE_LIGHT)
	parent.add_child(shaft)
	shaft.global_position = Vector3(base.x, ground - 5.0 + height * 0.5, base.y)

	var body := StaticBody3D.new()
	shaft.add_child(body)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	# CylinderShape3D cannot taper, so this one shape has to stand in for a cone.
	# Sizing it to the *bottom* radius would push a 4 m wall right through the
	# inner edge of every tread — the tread's inner edge sits at 4.6 m, leaving
	# 0.6 m of walkway against a 1.0 m wide capsule, which is exactly where the
	# climb jammed. Sizing to the narrower top radius keeps the full tread walkable
	# for the whole height; the visual flare at the base is decorative and sits
	# below the first step, where the player never walks.
	cyl.radius = TOWER_TOP_RADIUS
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)

	# Banded courses break up the shaft the way the village towers are banded.
	var bands := int(height / 7.0)
	for i in range(1, bands + 1):
		var band := MeshInstance3D.new()
		band.name = "StoneCourse_%02d" % i
		var bm := CylinderMesh.new()
		bm.top_radius = TOWER_BOTTOM_RADIUS - (TOWER_BOTTOM_RADIUS - TOWER_TOP_RADIUS) * (float(i) / float(bands + 1)) + 0.25
		bm.bottom_radius = bm.top_radius + 0.15
		bm.height = 0.5
		bm.radial_segments = TOWER_SIDES
		band.mesh = bm
		band.material_override = _stone(STONE_DARK)
		parent.add_child(band)
		band.global_position = Vector3(base.x, ground - 4.0 + height * (float(i) / float(bands + 1)), base.y)

	_build_tower_facade(parent, base, ground, top_y)


# The spiral itself: a tread plus a riser per step, hugging the shaft.
func _build_stair(parent: Node3D, base: Vector2, ground: float, top_y: float) -> void:
	var light := _stone(STONE_LIGHT)
	var dark := _stone(STONE_DARK)
	var brass := _metal(Color(0.78, 0.52, 0.18))
	var cyan_glow := _glow(CIRCUIT_CYAN)
	var violet_glow := _glow(RUNE_VIOLET)
	var start_angle := atan2(CASTLE_XZ.y - base.y, CASTLE_XZ.x - base.x) + PI

	# Derive the tread count from the actual climb so the rise per step stays at
	# STEP_RISE regardless of terrain height. Hard-coding 96 steps meant the rise
	# silently changed with the ground, and on tall ground it exceeded what the
	# controller can step over — the stair became unclimbable by arithmetic.
	var climb := top_y - (ground + 0.4)
	_step_count = maxi(2, int(ceil(climb / STEP_RISE)))

	# Treads must overlap along the arc, or the capsule drops into the wedge
	# between two rotated boxes. Widen the tread until consecutive centres are
	# closer together than the box is deep.
	var arc_step: float = (TAU * TURNS * STAIR_RADIUS) / float(_step_count)
	var tread_depth: float = maxf(STEP_DEPTH, arc_step * 1.6)

	# A broad terrain-sunk apron guarantees a continuous first contact even
	# where the painted hillside undulates around the tower entrance.
	var entry_pos := Vector3(
		base.x + cos(start_angle) * STAIR_RADIUS,
		ground + 0.05,
		base.y + sin(start_angle) * STAIR_RADIUS)
	_build_entry_apron(parent, entry_pos, start_angle, light, brass, cyan_glow)
	_build_continuous_ascent(parent, base, ground, top_y, start_angle,
		dark, light, brass)

	for i in _step_count:
		var t := float(i) / float(_step_count - 1)
		var angle := start_angle + t * TAU * TURNS
		var y: float = lerpf(ground + 0.4, top_y, t)
		var pos := Vector3(base.x + cos(angle) * STAIR_RADIUS, y, base.y + sin(angle) * STAIR_RADIUS)

		# Tread — the surface the player runs on.
		var tread := MeshInstance3D.new()
		tread.name = "StairTread_%03d" % i
		var tm := BoxMesh.new()
		tm.size = Vector3(STEP_WIDTH, 0.34, tread_depth)
		tread.mesh = tm
		tread.material_override = light if i % 2 == 0 else dark
		parent.add_child(tread)
		tread.global_position = pos
		tread.rotation.y = -angle
		_add_box_body(tread, tm.size)

		# Riser — the vertical face under the tread. Without this the stair
		# reads as floating planks instead of steps.
		var riser := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(STEP_WIDTH, STEP_RISE + 0.3, 0.3)
		riser.mesh = rm
		riser.material_override = dark
		parent.add_child(riser)
		riser.global_position = pos + Vector3(0.0, -0.3, 0.0)
		riser.rotation.y = -angle

		# Alternating arcane circuit strips lead the eye upward like illuminated
		# wayfinding. They sit just above the tread and are intentionally visual.
		if i % 6 == 0:
			var inlay := MeshInstance3D.new()
			var inlay_mesh := BoxMesh.new()
			inlay_mesh.size = Vector3(0.13, 0.045, tread_depth * 0.76)
			inlay.mesh = inlay_mesh
			inlay.material_override = cyan_glow
			parent.add_child(inlay)
			inlay.global_position = Vector3(
				base.x + cos(angle) * (STAIR_RADIUS - STEP_WIDTH * 0.23),
				y + 0.20,
				base.y + sin(angle) * (STAIR_RADIUS - STEP_WIDTH * 0.23))
			inlay.rotation.y = -angle

		# A faceted rune medallion every half-turn breaks up the long climb and
		# doubles as progress feedback without adding HUD clutter.
		if i % 30 == 0:
			var medallion := MeshInstance3D.new()
			var medallion_mesh := TorusMesh.new()
			medallion_mesh.inner_radius = 0.34
			medallion_mesh.outer_radius = 0.48
			medallion_mesh.rings = 10
			medallion_mesh.ring_segments = 4
			medallion.mesh = medallion_mesh
			medallion.material_override = violet_glow
			parent.add_child(medallion)
			medallion.global_position = Vector3(
				base.x + cos(angle) * (STAIR_RADIUS + STEP_WIDTH * 0.5 + 0.2),
				y + 0.78,
				base.y + sin(angle) * (STAIR_RADIUS + STEP_WIDTH * 0.5 + 0.2))
			medallion.rotation_degrees = Vector3(90.0, rad_to_deg(-angle), 0.0)

		if i % 24 == 0:
			_add_lantern(parent, base, angle, y)

	# Diegetic instruction at the foot of the stair: it explicitly reassures the
	# player that this is a free-walk route, not another automatic transport.
	#
	# A large centred billboard directly on the entry radius used to face the
	# player head-on every time they looked up the stair, so the sign hung in
	# front of the treads/camera in the arrival screenshots. It's now a small
	# side plaque: pushed further out past the entry apron, off the walking
	# axis at roughly a quarter-turn, and set noticeably smaller so it reads
	# as a wayside marker rather than dominating the shot.
	var first_angle := start_angle
	var sign_angle := first_angle + 0.55
	var wayfinding := Label3D.new()
	wayfinding.name = "FreePassageSign"
	wayfinding.text = "✦ Lumen Ascent ✦\nWalk freely  •  Space to jump"
	wayfinding.font_size = 18
	wayfinding.outline_size = 6
	wayfinding.modulate = CIRCUIT_CYAN.lightened(0.25)
	wayfinding.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	wayfinding.pixel_size = 0.0065
	parent.add_child(wayfinding)
	wayfinding.global_position = Vector3(
		base.x + cos(sign_angle) * (STAIR_RADIUS + 4.2),
		ground + 2.1,
		base.y + sin(sign_angle) * (STAIR_RADIUS + 4.2))


# The old safety rail was one box per tread. Even with overlap, more than a
# hundred differently rotated boxes read as broken, stacked slats in every
# exterior view. These four watertight helical ribbons give the stair a single
# architectural silhouette while the individual treads retain the satisfying
# footfall and step rhythm.
func _build_continuous_ascent(parent: Node3D, base: Vector2, ground: float,
		top_y: float, start_angle: float, dark: Material, light: Material,
		brass: Material) -> void:
	var inner_edge := STAIR_RADIUS - STEP_WIDTH * 0.5
	var outer_edge := STAIR_RADIUS + STEP_WIDTH * 0.5

	var roadbed := _helix_band_mesh(base, ground, top_y, start_angle,
		inner_edge + 0.12, outer_edge - 0.12, -0.58, -0.12)
	_add_helix_part(parent, "AscentRoadbed", roadbed, dark, false)

	var outer_guard := _helix_band_mesh(base, ground, top_y, start_angle,
		outer_edge - 0.24, outer_edge + 0.24, 0.06, 1.40, 0.985)
	_add_helix_part(parent, "OuterContinuousGuard", outer_guard, light, true)
	var outer_cap := _helix_band_mesh(base, ground, top_y, start_angle,
		outer_edge - 0.16, outer_edge + 0.16, 1.40, 1.56, 0.985)
	_add_helix_part(parent, "OuterContinuousCap", outer_cap, brass, false)

	var inner_guard := _helix_band_mesh(base, ground, top_y, start_angle,
		inner_edge - 0.22, inner_edge + 0.22, 0.06, 1.28, 0.985)
	_add_helix_part(parent, "InnerContinuousGuard", inner_guard, dark, true)
	var inner_cap := _helix_band_mesh(base, ground, top_y, start_angle,
		inner_edge - 0.14, inner_edge + 0.14, 1.28, 1.43, 0.985)
	_add_helix_part(parent, "InnerContinuousCap", inner_cap, brass, false)

	# Close the narrow service slot behind the inner guard. The tower collider is
	# deliberately only 3.0 m wide while the guard begins around radius 4.38 m;
	# at the circular entry apron that left a player-sized pocket behind the
	# rail. A jump over the rail could put the capsule between both walls with
	# too little room to turn or climb back out. This raised, collision-backed
	# plinth follows the same helix beneath the cap, turning that slot into solid
	# architecture and giving any over-jumping player a broad surface from which
	# they can step or jump safely back onto the stair.
	var inner_plinth := _helix_band_mesh(base, ground, top_y, start_angle,
		TOWER_TOP_RADIUS - 0.05, inner_edge + 0.02, -0.05, 1.05, 0.985)
	_add_helix_part(parent, "InnerSafetyPlinth", inner_plinth, dark, true)


func _helix_band_mesh(base: Vector2, ground: float, top_y: float,
		start_angle: float, inner_radius: float, outer_radius: float,
		bottom_offset: float, top_offset: float, end_t: float = 1.0) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples := maxi(_step_count, 48)
	for i in samples:
		var t0 := end_t * float(i) / float(samples)
		var t1 := end_t * float(i + 1) / float(samples)
		var a0 := start_angle + t0 * TAU * TURNS
		var a1 := start_angle + t1 * TAU * TURNS
		var y0 := lerpf(ground + 0.4, top_y, t0)
		var y1 := lerpf(ground + 0.4, top_y, t1)

		var i0b := Vector3(base.x + cos(a0) * inner_radius,
			y0 + bottom_offset, base.y + sin(a0) * inner_radius)
		var i0t := Vector3(i0b.x, y0 + top_offset, i0b.z)
		var o0b := Vector3(base.x + cos(a0) * outer_radius,
			y0 + bottom_offset, base.y + sin(a0) * outer_radius)
		var o0t := Vector3(o0b.x, y0 + top_offset, o0b.z)
		var i1b := Vector3(base.x + cos(a1) * inner_radius,
			y1 + bottom_offset, base.y + sin(a1) * inner_radius)
		var i1t := Vector3(i1b.x, y1 + top_offset, i1b.z)
		var o1b := Vector3(base.x + cos(a1) * outer_radius,
			y1 + bottom_offset, base.y + sin(a1) * outer_radius)
		var o1t := Vector3(o1b.x, y1 + top_offset, o1b.z)

		_add_surface_quad(surface, i0t, i1t, o1t, o0t) # top
		_add_surface_quad(surface, i0b, o0b, o1b, i1b) # underside
		_add_surface_quad(surface, o0b, o0t, o1t, o1b) # outer face
		_add_surface_quad(surface, i0b, i1b, i1t, i0t) # inner face

		if i == 0:
			_add_surface_quad(surface, i0b, i0t, o0t, o0b)
		if i == samples - 1:
			_add_surface_quad(surface, i1b, o1b, o1t, i1t)

	surface.generate_normals()
	return surface.commit()


func _add_surface_quad(surface: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(d)


func _add_helix_part(parent: Node3D, part_name: String, mesh: ArrayMesh,
		material: Material, collision: bool) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	# Vertices are authored in world space to match the measured castle and
	# terrain anchors. The containing rig is offset for legacy scene reasons, so
	# inherit no transform here or the ribbon is displaced a second time.
	part.top_level = true
	part.mesh = mesh
	# Generated helix faces are viewed from above, below, inside and outside.
	# Disable culling on a private material copy so an imported winding change
	# can never make an entire guard disappear from one side of the camera.
	var two_sided := material.duplicate() as Material
	if two_sided is StandardMaterial3D:
		(two_sided as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	part.material_override = two_sided
	parent.add_child(part)
	if collision:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		part.add_child(body)
	return part


# Finished facade language for the tower: structural stone remains medieval,
# while recessed dark panels, brass frames, and crystal circuitry make the
# mechanism lifting the castle route readable from ground level.
func _build_tower_facade(parent: Node3D, base: Vector2,
		ground: float, top_y: float) -> void:
	var dark := _stone(Color(0.08, 0.12, 0.20))
	var brass := _metal(Color(0.78, 0.52, 0.18))
	var cyan := _glow(CIRCUIT_CYAN)
	var violet := _glow(RUNE_VIOLET)
	var facade_height := top_y - ground

	# Eight heavy footings visually seat the tower into the hillside.
	for side_i in TOWER_SIDES:
		var footing_angle := TAU * float(side_i) / float(TOWER_SIDES)
		var footing := MeshInstance3D.new()
		footing.name = "FoundationButtress_%02d" % side_i
		var footing_mesh := BoxMesh.new()
		footing_mesh.size = Vector3(1.35, 3.0, 2.1)
		footing.mesh = footing_mesh
		footing.material_override = _stone(STONE_DARK)
		parent.add_child(footing)
		footing.global_position = Vector3(
			base.x + cos(footing_angle) * (TOWER_BOTTOM_RADIUS + 0.55),
			ground + 0.55,
			base.y + sin(footing_angle) * (TOWER_BOTTOM_RADIUS + 0.55))
		footing.rotation.y = -footing_angle

	# Four tiers of alternating arcane windows. The panels are shallow and have
	# no collision, preserving a clean stair corridor around the shaft.
	for tier in 4:
		var y := ground + facade_height * (0.18 + float(tier) * 0.20)
		var tier_ratio := (y - ground) / maxf(facade_height, 0.1)
		var radius := lerpf(TOWER_BOTTOM_RADIUS, TOWER_TOP_RADIUS, tier_ratio) + 0.08
		for face_i in 4:
			var angle := TAU * float(face_i) / 4.0 + (PI * 0.25 if tier % 2 else 0.0)
			var panel := MeshInstance3D.new()
			panel.name = "AetherWindow_%d_%d" % [tier, face_i]
			var panel_mesh := BoxMesh.new()
			panel_mesh.size = Vector3(1.45, 2.15, 0.16)
			panel.mesh = panel_mesh
			panel.material_override = dark
			parent.add_child(panel)
			panel.global_position = Vector3(
				base.x + cos(angle) * radius, y,
				base.y + sin(angle) * radius)
			panel.rotation.y = -angle

			var frame := MeshInstance3D.new()
			var frame_mesh := TorusMesh.new()
			frame_mesh.inner_radius = 0.48
			frame_mesh.outer_radius = 0.62
			frame_mesh.rings = 12
			frame_mesh.ring_segments = 5
			frame.mesh = frame_mesh
			frame.scale = Vector3(1.0, 1.45, 1.0)
			frame.material_override = brass
			parent.add_child(frame)
			frame.global_position = panel.global_position + Vector3.UP * 0.18
			frame.rotation_degrees = Vector3(90.0, rad_to_deg(-angle), 0.0)

			var core := MeshInstance3D.new()
			var core_mesh := SphereMesh.new()
			core_mesh.radius = 0.22
			core_mesh.height = 0.72
			core_mesh.radial_segments = 6
			core_mesh.rings = 3
			core.mesh = core_mesh
			core.material_override = cyan if (tier + face_i) % 2 == 0 else violet
			parent.add_child(core)
			core.global_position = panel.global_position + Vector3.UP * 0.18


func _build_entry_apron(parent: Node3D, entry_pos: Vector3, angle: float,
		stone: Material, brass: Material, glow: Material) -> void:
	var apron := MeshInstance3D.new()
	apron.name = "GroundEntranceApron"
	var apron_mesh := CylinderMesh.new()
	apron_mesh.top_radius = 3.0
	apron_mesh.bottom_radius = 3.35
	apron_mesh.height = 0.42
	apron_mesh.radial_segments = 8
	apron.mesh = apron_mesh
	apron.material_override = stone
	parent.add_child(apron)
	apron.global_position = entry_pos

	var apron_body := StaticBody3D.new()
	apron.add_child(apron_body)
	var apron_shape := CollisionShape3D.new()
	var apron_cylinder := CylinderShape3D.new()
	apron_cylinder.radius = 3.0
	apron_cylinder.height = 0.42
	apron_shape.shape = apron_cylinder
	apron_body.add_child(apron_shape)

	# A broken-circle threshold combines a castle gate silhouette with a scanner.
	var threshold := MeshInstance3D.new()
	threshold.name = "EntranceRune"
	var threshold_mesh := TorusMesh.new()
	threshold_mesh.inner_radius = 1.55
	threshold_mesh.outer_radius = 1.78
	threshold_mesh.rings = 16
	threshold_mesh.ring_segments = 5
	threshold.mesh = threshold_mesh
	threshold.material_override = glow
	parent.add_child(threshold)
	threshold.global_position = entry_pos + Vector3.UP * 0.35

	for side_sign in [-1.0, 1.0]:
		var blade := MeshInstance3D.new()
		var blade_mesh := BoxMesh.new()
		blade_mesh.size = Vector3(0.38, 0.18, 2.4)
		blade.mesh = blade_mesh
		blade.material_override = brass
		parent.add_child(blade)
		var side := Vector3(-sin(angle), 0.0, cos(angle))
		blade.global_position = entry_pos + side * side_sign * 2.05 + Vector3.UP * 0.28
		blade.rotation.y = -angle


# The spiral's destination: a room-sized landing, not a thin ring around the
# shaft. The old deck was only TOWER_TOP_RADIUS + 1.6 (4.6 m) across — barely
# wider than the tread it grew out of, so the last step handed the player onto
# what read as a beam crossing rather than a place to stand. LANDING_RADIUS
# gives it real floor: enough that the gate and the stair mouth are two
# separate, generously spaced openings in a genuine room.
# Match the spiral's 8.4 m outer tread edge. The 9.6 m supervisor prototype
# dominated the castle approach and made the crown read as a floating plaza;
# this still fully supports the player while keeping the tower silhouette.
const LANDING_RADIUS := 8.4
const CROWN_SLAB_HEIGHT := 0.7
# `top_y` is the centre of the final 0.34 m spiral tread, so its walkable
# surface is 0.17 m higher. Keep the crown's finished floor on that same datum;
# the former `top_y + 0.5` slab centre put its surface 0.68 m above the last
# tread, just beyond the controller's reliable step-up height.
const CROWN_SURFACE_OFFSET := 0.17
# The packed player uses Godot's default 2.0 m-tall, 0.5 m-radius capsule.
# Keep substantially more than one full character height above the final
# flight, while cutting only the capsule's usable lane instead of removing the
# full 3.8 m tread width from the crown. The former full-width radial wedge is
# the oversized floor gap visible from above.
const STAIR_HEADROOM := 2.8
const STAIRWELL_LANE_HALF_WIDTH := 1.15

# Battlements and a red roof cap, so the tower top matches the village towers.
func _build_crown(parent: Node3D, base: Vector2, ground: float, top_y: float) -> void:
	var brass := _metal(Color(0.76, 0.52, 0.20))
	var cyan := _glow(CIRCUIT_CYAN)
	var violet := _glow(RUNE_VIOLET)
	var gate_dir := (Vector3(CASTLE_DOOR.x, 0.0, CASTLE_DOOR.z)
		- Vector3(base.x, 0.0, base.y)).normalized()
	var gate_angle := atan2(gate_dir.z, gate_dir.x)
	var stair_start_angle := atan2(CASTLE_XZ.y - base.y,
		CASTLE_XZ.x - base.x) + PI
	var stair_end_angle := wrapf(stair_start_angle + TAU * TURNS, -PI, PI)

	# The landing floor itself: one broad collision-backed slab, not an
	# annulus. A player capsule can stand and turn anywhere on it, not just
	# in a narrow band against the shaft.
	#
	# The old deck was a full CylinderMesh disc. The last several spiral
	# treads climb underneath its footprint (STAIR_RADIUS 6.5 is well inside
	# LANDING_RADIUS 8.4) before reaching top_y, and the slab's underside
	# (crown_surface_y - CROWN_SLAB_HEIGHT) sat barely half a metre above
	# those treads — a solid ceiling over the final flight, the "blocked
	# stair / low overhead collision" defect. A wedge sector matching the
	# stair-mouth opening (the same angle the parapet already omits) is cut
	# out of the slab so the last treads rise through open air into the
	# crown instead of tunnelling under it.
	var crown_surface_y := top_y + CROWN_SURFACE_OFFSET
	# The cutout has to be wide enough to clear every tread whose head
	# clearance would otherwise be pinched by the deck's underside, not just
	# the single final tread. Because STAIR_RADIUS + STEP_WIDTH/2 == 8.4 ==
	# LANDING_RADIUS, the outer edge of every loop of the spiral passes
	# directly under the crown's full footprint; the treads that matter are
	# every one within MIN_HEAD_CLEARANCE of the deck's underside — that
	# whole final stretch of climb (t in [1 - critical_band/climb, 1]), not a
	# single angle. The cutout's centre is offset backward from
	# stair_end_angle by half that swept range (with the endpoint itself as
	# one edge, since no tread exists past t=1), and its half-angle is sized
	# to the same swept range plus margin, so every tread in the critical
	# band — not just the last one — sits inside the opening.
	# Matches _build_stair's climb formula exactly so the swept angle lines up
	# with where the treads actually are.
	var climb := top_y - (ground + 0.4)
	var deck_bottom_y := crown_surface_y - CROWN_SLAB_HEIGHT
	var critical_band := minf(STAIR_HEADROOM + (top_y - deck_bottom_y), climb)
	var swept_angle: float = (critical_band / climb) * TAU * TURNS
	var angle_margin := 0.2
	var stairwell_half_angle: float = swept_angle * 0.5 + angle_margin
	var stairwell_centre_angle := stair_end_angle - swept_angle * 0.5
	var stairwell_inner_radius := STAIR_RADIUS - STAIRWELL_LANE_HALF_WIDTH
	var stairwell_outer_radius := STAIR_RADIUS + STAIRWELL_LANE_HALF_WIDTH
	# Authored in the deck's own local space (centred on the disc, y=0 at the
	# slab's vertical middle) rather than world space, so `deck.global_position`
	# keeps meaning the disc centre the way the plain CylinderMesh it replaces
	# always did — other code and tests read the crown surface off that point.
	var deck_mesh := _crown_deck_mesh(Vector2.ZERO, CROWN_SLAB_HEIGHT * 0.5,
		LANDING_RADIUS, CROWN_SLAB_HEIGHT, stairwell_centre_angle, stairwell_half_angle,
		stairwell_inner_radius, stairwell_outer_radius)
	var deck := MeshInstance3D.new()
	deck.name = "CrownDeck"
	deck.mesh = deck_mesh
	var deck_material := _stone(STONE_LIGHT)
	deck_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	deck.material_override = deck_material
	parent.add_child(deck)
	deck.global_position = Vector3(
		base.x, crown_surface_y - CROWN_SLAB_HEIGHT * 0.5, base.y)
	var body := StaticBody3D.new()
	deck.add_child(body)
	var shape := CollisionShape3D.new()
	shape.shape = deck_mesh.create_trimesh_shape()
	body.add_child(shape)
	# The centre/shelf fan is a disconnected coplanar surface inside the custom
	# trimesh. Godot can omit the outer part of that fan while simplifying the
	# concave collision, recreating a physical gap even though the floor renders.
	# Give the complete inner shelf one simple authoritative cylinder collider.
	var inner_floor_shape := CollisionShape3D.new()
	var inner_floor_cylinder := CylinderShape3D.new()
	inner_floor_cylinder.radius = stairwell_inner_radius
	inner_floor_cylinder.height = CROWN_SLAB_HEIGHT
	inner_floor_shape.shape = inner_floor_cylinder
	body.add_child(inner_floor_shape)
	# The outer shelf is disconnected for the same reason. Approximate its thin
	# annulus with overlapping tangent boxes; they live entirely outside the
	# player lane, so they close the side gap without narrowing the stairwell.
	const OUTER_SHELF_COLLISION_SEGMENTS := 48
	var shelf_radial_width := LANDING_RADIUS - stairwell_outer_radius
	var shelf_mid_radius := (LANDING_RADIUS + stairwell_outer_radius) * 0.5
	var shelf_tangent_length := TAU * shelf_mid_radius \
		/ float(OUTER_SHELF_COLLISION_SEGMENTS) * 1.08
	for shelf_i in OUTER_SHELF_COLLISION_SEGMENTS:
		var shelf_angle := TAU * float(shelf_i) / float(OUTER_SHELF_COLLISION_SEGMENTS)
		var shelf_shape := CollisionShape3D.new()
		var shelf_box := BoxShape3D.new()
		shelf_box.size = Vector3(shelf_radial_width, CROWN_SLAB_HEIGHT,
			shelf_tangent_length)
		shelf_shape.shape = shelf_box
		shelf_shape.position = Vector3(cos(shelf_angle) * shelf_mid_radius, 0.0,
			sin(shelf_angle) * shelf_mid_radius)
		shelf_shape.rotation.y = -shelf_angle
		body.add_child(shelf_shape)

	# A box-shaped, collision-backed threshold carries the real player capsule
	# across the generated CrownDeck's radial triangle seam and overlaps the
	# LumenBridgeLaunch. The concave deck remains the correctly cut visual floor,
	# but its centreline seam could let the capsule sink into the slab and pin it
	# against a vertical triangle edge. This authoritative apron sits on the
	# bridge sector only; the spiral stairwell opens on a different sector, so
	# its final-flight headroom stays untouched.
	var gateway_apron_size := Vector3(BRIDGE_WIDTH + 0.6, 0.28, 5.8)
	var gateway_apron_centre := Vector3(base.x, crown_surface_y - 0.14, base.y) \
		+ gate_dir * 5.8
	var gateway_apron := _oriented_box(parent, gateway_apron_size,
		gateway_apron_centre, gateway_apron_centre + gate_dir, deck_material)
	gateway_apron.name = "CrownGatewayApron"
	_add_box_body(gateway_apron, gateway_apron_size)

	# A low kerb along both open edges of the stairwell cutout, so the gap
	# reads as a deliberate opening (with a visible rim) rather than a hole
	# in the floor the player might mistake for missing geometry.
	_build_stairwell_kerb(parent, base, crown_surface_y,
		stairwell_centre_angle, stairwell_half_angle, stairwell_inner_radius,
		stairwell_outer_radius, brass)

	var parapet_length := 2.0 * (LANDING_RADIUS - 0.45) * tan(PI / float(TOWER_SIDES)) - 0.35
	for i in TOWER_SIDES:
		var angle := TAU * float(i) / float(TOWER_SIDES)
		# Continuous octagonal parapets make the crown a safe architectural room.
		# Entire sides are omitted at the stair mouth and causeway gate, giving the
		# player two unmistakable, obstruction-free openings. The stair-mouth gap
		# matches the same widened span the deck cutout uses, so the parapet
		# opening and the stairwell opening line up instead of the parapet gap
		# being narrower than the hole in the floor beneath it.
		if absf(angle_difference(angle, gate_angle)) < 0.72 \
				or absf(angle_difference(angle, stairwell_centre_angle)) < stairwell_half_angle + 0.3:
			continue
		var wall := MeshInstance3D.new()
		wall.name = "CrownParapet_%02d" % i
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(parapet_length, 0.95, 0.55)
		wall.mesh = wall_mesh
		wall.material_override = _stone(STONE_DARK)
		parent.add_child(wall)
		wall.global_position = Vector3(
			base.x + cos(angle) * (LANDING_RADIUS - 0.4),
			crown_surface_y + 0.475,
			base.y + sin(angle) * (LANDING_RADIUS - 0.4))
		wall.rotation.y = -angle + PI * 0.5
		_add_box_body(wall, wall_mesh.size)

		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(parapet_length + 0.15, 0.16, 0.72)
		cap.mesh = cap_mesh
		cap.material_override = brass
		parent.add_child(cap)
		cap.global_position = wall.global_position + Vector3.UP * 0.555
		cap.rotation.y = wall.rotation.y

	# An open Aether Lens gateway marks the route without putting a collider or
	# a camera-filling box across it. Its slender pylons stand well outside the
	# 4.8 m road edge; split brass/cyan yokes converge on a violet calibration
	# lens above player headroom.
	var gate_side := gate_dir.cross(Vector3.UP).normalized()
	var gate_centre := Vector3(base.x, crown_surface_y, base.y) \
		+ gate_dir * (LANDING_RADIUS - 0.5)
	_build_aether_lens_gate(parent, gate_centre, gate_dir, gate_side,
		"Crown", brass, cyan, violet)

	# Layered arcane circuitry turns the formerly empty arrival platform into a
	# readable destination. These pieces are low and decorative, leaving the
	# whole crown walkable while visually linking it to the Aether Court.
	for ring_index in 3:
		var rune_ring := MeshInstance3D.new()
		rune_ring.name = "CrownRuneRing_%d" % ring_index
		var rune_mesh := TorusMesh.new()
		rune_mesh.inner_radius = 1.15 + float(ring_index) * 0.72
		rune_mesh.outer_radius = rune_mesh.inner_radius + 0.10
		rune_mesh.rings = 20
		rune_mesh.ring_segments = 4
		rune_ring.mesh = rune_mesh
		rune_ring.material_override = cyan if ring_index % 2 == 0 else violet
		parent.add_child(rune_ring)
		rune_ring.global_position = Vector3(base.x, crown_surface_y + 0.03, base.y)

	for i in 4:
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var crystal := MeshInstance3D.new()
		crystal.name = "CrownCrystal_%d" % i
		var crystal_mesh := PrismMesh.new()
		crystal_mesh.size = Vector3(0.42, 1.15, 0.42)
		crystal.mesh = crystal_mesh
		crystal.material_override = cyan if i % 2 == 0 else violet
		parent.add_child(crystal)
		crystal.global_position = Vector3(
			base.x + cos(angle) * 3.65, crown_surface_y + 0.67,
			base.y + sin(angle) * 3.65)
		crystal.rotation_degrees.z = 12.0 if i % 2 == 0 else -12.0

		var crystal_base := MeshInstance3D.new()
		var base_mesh := CylinderMesh.new()
		base_mesh.top_radius = 0.42
		base_mesh.bottom_radius = 0.50
		base_mesh.height = 0.22
		base_mesh.radial_segments = 8
		crystal_base.mesh = base_mesh
		crystal_base.material_override = brass
		parent.add_child(crystal_base)
		crystal_base.global_position = Vector3(
			base.x + cos(angle) * 3.65, crown_surface_y + 0.11,
			base.y + sin(angle) * 3.65)

	# A small red pennant, echoing the castle's banners.
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.09
	pm.bottom_radius = 0.09
	pm.height = 3.2
	pole.mesh = pm
	pole.material_override = _stone(STONE_DARK)
	parent.add_child(pole)
	# Kept off the circulation axis so the crown reads as a room, not a prop
	# pile the player has to weave through.
	pole.global_position = Vector3(
		base.x - 2.2, crown_surface_y + 1.6, base.y + 1.8)

	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.6, 0.9, 0.08)
	flag.mesh = fm
	var red := StandardMaterial3D.new()
	red.albedo_color = ROOF_RED
	red.roughness = 0.9
	flag.material_override = red
	parent.add_child(flag)
	flag.global_position = pole.global_position + Vector3(0.8, 1.0, 0.0)


# Builds the crown landing slab as a full disc with one radial wedge removed,
# so the spiral stair's final flight climbs through an open stairwell instead
# of tunnelling beneath a solid ceiling. `centre_angle`/`half_angle` describe
# the same sector the parapet loop already leaves open at the stair mouth;
# `inner_radius` pulls the cut back toward the tower shaft so the opening
# matches the width of the approaching treads rather than the whole radius.
func _crown_deck_mesh(base: Vector2, surface_y: float, outer_radius: float,
		slab_height: float, centre_angle: float, half_angle: float,
		inner_radius: float, cut_outer_radius: float) -> ArrayMesh:
	var top_y := surface_y
	var bottom_y := surface_y - slab_height
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := TOWER_SIDES * 6
	var full_turn := TAU
	# Walk the full circle, skipping the wedge between the two cut angles so
	# the remaining fan of triangles forms a disc with a pie slice removed.
	var cut_start := centre_angle - half_angle
	var cut_end := centre_angle + half_angle
	var angles: Array[float] = []
	for i in range(segments + 1):
		var a: float = wrapf(cut_end + full_turn * float(i) / float(segments), -PI, PI)
		# Stop once we wrap back to the start of the cut, closing the fan.
		if i > 0 and absf(angle_difference(a, cut_start)) < (full_turn / float(segments)) * 0.5:
			angles.append(cut_start)
			break
		angles.append(a)
	if angles.size() < 2:
		angles = [cut_end, cut_start]

	for i in range(angles.size() - 1):
		var a0: float = angles[i]
		var a1: float = angles[i + 1]
		var o0t := Vector3(base.x + cos(a0) * cut_outer_radius, top_y, base.y + sin(a0) * cut_outer_radius)
		var o1t := Vector3(base.x + cos(a1) * cut_outer_radius, top_y, base.y + sin(a1) * cut_outer_radius)
		var o0b := Vector3(o0t.x, bottom_y, o0t.z)
		var o1b := Vector3(o1t.x, bottom_y, o1t.z)
		var c0t := Vector3(base.x + cos(a0) * inner_radius, top_y, base.y + sin(a0) * inner_radius)
		var c1t := Vector3(base.x + cos(a1) * inner_radius, top_y, base.y + sin(a1) * inner_radius)
		var c0b := Vector3(c0t.x, bottom_y, c0t.z)
		var c1b := Vector3(c1t.x, bottom_y, c1t.z)

		_add_surface_quad(surface, c0t, c1t, o1t, o0t)  # top ring
		_add_surface_quad(surface, o0b, o1b, c1b, c0b)  # underside

	# Restore the crown outside the player's stair lane. Previously the cut ran
	# all the way to LANDING_RADIUS, leaving a broad pie-slice hole beside the
	# character. This complete outer shelf closes that visual/gameplay gap while
	# the centred 2.3 m opening remains wider than the 1.0 m player capsule.
	for i in segments:
		var a0 := full_turn * float(i) / float(segments)
		var a1 := full_turn * float(i + 1) / float(segments)
		var i0t := Vector3(base.x + cos(a0) * cut_outer_radius,
			top_y, base.y + sin(a0) * cut_outer_radius)
		var i1t := Vector3(base.x + cos(a1) * cut_outer_radius,
			top_y, base.y + sin(a1) * cut_outer_radius)
		var o0t := Vector3(base.x + cos(a0) * outer_radius,
			top_y, base.y + sin(a0) * outer_radius)
		var o1t := Vector3(base.x + cos(a1) * outer_radius,
			top_y, base.y + sin(a1) * outer_radius)
		var i0b := Vector3(i0t.x, bottom_y, i0t.z)
		var i1b := Vector3(i1t.x, bottom_y, i1t.z)
		var o0b := Vector3(o0t.x, bottom_y, o0t.z)
		var o1b := Vector3(o1t.x, bottom_y, o1t.z)
		_add_surface_quad(surface, i0t, i1t, o1t, o0t)
		_add_surface_quad(surface, i0b, o0b, o1b, i1b)
		_add_surface_quad(surface, o0b, o0t, o1t, o1b)

	# Floor the complete centre disc inside `inner_radius`. The ring above only
	# starts at that radius; without this fan, the 3.0 m tower cap and the 3.6 m
	# crown ring leave a 0.6 m annular slot. That slot is almost exactly the
	# player's capsule diameter, so a player walking beside the rune circle can
	# drop into it and become wedged between the shaft and the deck edge. The
	# stair itself begins outside this centre disc, so filling it does not close
	# the intentional outer stairwell wedge.
	var centre_top := Vector3(base.x, top_y, base.y)
	var centre_bottom := Vector3(base.x, bottom_y, base.y)
	for i in segments:
		var a0 := full_turn * float(i) / float(segments)
		var a1 := full_turn * float(i + 1) / float(segments)
		var c0t := Vector3(base.x + cos(a0) * inner_radius,
			top_y, base.y + sin(a0) * inner_radius)
		var c1t := Vector3(base.x + cos(a1) * inner_radius,
			top_y, base.y + sin(a1) * inner_radius)
		var c0b := Vector3(c0t.x, bottom_y, c0t.z)
		var c1b := Vector3(c1t.x, bottom_y, c1t.z)
		# Reversed winding on the underside keeps both faces correctly oriented.
		surface.add_vertex(centre_top)
		surface.add_vertex(c1t)
		surface.add_vertex(c0t)
		surface.add_vertex(centre_bottom)
		surface.add_vertex(c0b)
		surface.add_vertex(c1b)

	# Cap the two straight edges of the wedge cut, and floor the small centre
	# disc bounded by inner_radius so the stairwell opening reads as a clean
	# rectangular gap rather than exposing the underside everywhere.
	for cut_angle in [cut_start, cut_end]:
		var ot := Vector3(base.x + cos(cut_angle) * cut_outer_radius, top_y, base.y + sin(cut_angle) * cut_outer_radius)
		var ob := Vector3(ot.x, bottom_y, ot.z)
		var it := Vector3(base.x + cos(cut_angle) * inner_radius, top_y, base.y + sin(cut_angle) * inner_radius)
		var ib := Vector3(it.x, bottom_y, it.z)
		if cut_angle == cut_start:
			_add_surface_quad(surface, ib, ob, ot, it)
		else:
			_add_surface_quad(surface, it, ot, ob, ib)

	surface.generate_normals()
	return surface.commit()


# A low brass kerb along the two straight edges of the stairwell cutout, so
# the opening reads as an intentional architectural gap with a visible lip
# rather than a hole in the floor.
func _build_stairwell_kerb(parent: Node3D, base: Vector2, surface_y: float,
		centre_angle: float, half_angle: float,
		inner_radius: float, cut_outer_radius: float, brass: Material) -> void:
	for sign_i in [-1.0, 1.0]:
		var edge_angle: float = centre_angle + half_angle * sign_i
		var mid_radius := (inner_radius + cut_outer_radius) * 0.5
		var kerb := MeshInstance3D.new()
		kerb.name = "StairwellKerb"
		var kerb_mesh := BoxMesh.new()
		kerb_mesh.size = Vector3(cut_outer_radius - inner_radius, 0.14, 0.16)
		kerb.mesh = kerb_mesh
		kerb.material_override = brass
		parent.add_child(kerb)
		kerb.global_position = Vector3(
			base.x + cos(edge_angle) * mid_radius,
			surface_y + 0.07,
			base.y + sin(edge_angle) * mid_radius)
		kerb.rotation.y = -edge_angle


# The causeway from the tower deck to the front-door plaza.
#
# This used to aim at CASTLE_DOOR itself, which drove a wide flat slab straight
# across the ground the entrance plaza now occupies — the bare grey deck in the
# bug screenshot, with the plaza buried underneath it. It now stops at the
# plaza's outer edge and hands the player over to that architecture, so there
# is one approach instead of two overlapping ones.
#
# It is also no longer a plain ribbon of planks: arched ribs underneath, brass
# rail stanchions, and a lit centre conductor, matching the magic/machine
# language the entrance and the trains already speak.
func _build_bridge(parent: Node3D, base: Vector2, top_y: float) -> void:
	# Both ends sit at TERRACE_DECK_Y so the causeway is a LEVEL walkway.
	#
	# It previously ran from the tower deck up to the door's own height, which
	# with the tower where it now stands meant a 3.5 m climb across a mostly
	# sideways span — a steep diagonal ramp that read as loose planks hanging in
	# the air rather than a bridge. The tower now finishes at terrace height
	# (see _build), so this only has to cross the gap, not climb it.
	#
	# The target overlaps the terrace edge slightly rather than butting against
	# it, so there is no seam for the player to fall through.
	var target := Vector3(
		CASTLE_DOOR.x + PLAZA_LENGTH - 1.6,
		TERRACE_DECK_Y,
		CASTLE_DOOR.z)
	var crown_centre := Vector3(base.x, TERRACE_DECK_Y, base.y)
	var approach_direction := (target - crown_centre).normalized()
	# Begin at the crown gateway, not at the centre of the crown. Starting the
	# causeway at the tower axis laid its rails across the whole landing—the
	# diagonal obstruction visible in the player's screenshot.
	var start := crown_centre + approach_direction * (LANDING_RADIUS - 1.0)
	var light := _stone(STONE_LIGHT)
	var dark := _stone(STONE_DARK)
	var brass := _metal(Color(0.76, 0.52, 0.20))
	var glow := _glow(RAIL_GLOW)
	# The crown already speaks cyan/violet (rune rings, crystals). The bridge
	# spoke only amber lantern, so the two halves of the same route did not look
	# like the same building. Sharing the arcane palette is what makes the span
	# read as Art Castle magitech rather than a generic stone footbridge.
	var cyan := _glow(CIRCUIT_CYAN)
	var violet := _glow(RUNE_VIOLET)
	var span := start.distance_to(target)
	var direction := (target - start).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	var segment_length := span / float(BRIDGE_SEGMENTS)

	# A solid landing where the causeway leaves the tower. Without it the first
	# plank starts half a segment out from the deck edge and the join is an
	# open hole the player drops through — the missing connection at the top of
	# the spiral stair.
	var launch := _oriented_box(parent,
		Vector3(BRIDGE_WIDTH + 2.2, 0.5, 4.0),
		start + direction * 1.4, target, light)
	launch.name = "LumenBridgeLaunch"
	_add_box_body(launch, Vector3(BRIDGE_WIDTH + 2.2, 0.5, 4.0))

	# One continuous slab running the whole span, under the segmented planks.
	# The planks alone left hairline seams between every segment and the
	# causeway read as a row of separate floating bars; this gives it a single
	# unbroken surface and one collider the player cannot slip between.
	var roadbed := _oriented_box(parent,
		Vector3(BRIDGE_WIDTH, 0.44, span + 1.0),
		start.lerp(target, 0.5), target, dark)
	roadbed.name = "LumenBridgeRoadbed"
	_add_box_body(roadbed, Vector3(BRIDGE_WIDTH, 0.44, span + 1.0))

	# A visible structural spine beneath the span. These parts deliberately
	# carry no collision: the roadbed above is the one authoritative walkable
	# surface, while the keel and field coils explain how the floating bridge is
	# held in a controlled aether suspension.
	var keel := _oriented_box(parent, Vector3(0.42, 0.48, span - 0.8),
		start.lerp(target, 0.5) - Vector3(0.0, 0.58, 0.0), target, brass)
	keel.name = "AetherBridgeKeel"
	for coil_index in 2:
		var coil := MeshInstance3D.new()
		coil.name = "AetherLevitationCoil_%d" % coil_index
		var coil_mesh := TorusMesh.new()
		coil_mesh.inner_radius = 0.72
		coil_mesh.outer_radius = 0.92
		coil_mesh.rings = 12
		coil_mesh.ring_segments = 5
		coil.mesh = coil_mesh
		coil.material_override = cyan if coil_index == 0 else violet
		parent.add_child(coil)
		coil.global_position = start.lerp(target, 0.32 + float(coil_index) * 0.36) \
			- Vector3(0.0, 1.12, 0.0)
		coil.rotation_degrees.z = 90.0

	# Three triangular tension stations transfer the road edges into the keel.
	# They are deliberately visual-only; the roadbed remains the single source
	# of traversal collision.
	for brace_index in 3:
		var brace_centre := start.lerp(target, 0.25 + float(brace_index) * 0.25)
		var keel_joint := brace_centre - Vector3(0.0, 1.75, 0.0)
		for brace_sign in [-1.0, 1.0]:
			var signed_brace: float = brace_sign
			var deck_joint := brace_centre + side * signed_brace * 2.05 \
				- Vector3(0.0, 0.34, 0.0)
			var brace := _visual_chord(parent, keel_joint, deck_joint, 0.13, dark)
			brace.name = "AetherUnderbrace_%d_%s" % [brace_index,
				"L" if signed_brace < 0.0 else "R"]

	# Collision-backed Aether Balustrades protect both sides of the complete
	# causeway. The former 0.92 m masonry strips sat only about knee-high above
	# the decorative plank surface and stopped 2.4 m before the terrace, leaving
	# the player exposed at the most important handoff. These fields extend to
	# within 0.65 m of the landing and stand 1.35 m above the deck.
	#
	# Their inner faces remain outside BRIDGE_CLEAR_HALF_WIDTH, so the full
	# 4.8 m walking road stays clear. The visible system is one architectural
	# assembly: dark-stone plinth, cyan energy field, brass cap and calibrated
	# posts. Only the field carries collision; the smaller parts are ornament.
	var guard_span := span - BRIDGE_GUARD_END_CLEARANCE * 2.0
	var guard_start := start + direction * BRIDGE_GUARD_END_CLEARANCE
	var guard_end := target - direction * BRIDGE_GUARD_END_CLEARANCE
	var guard_lateral := BRIDGE_CLEAR_HALF_WIDTH + 0.16
	var mouth_lateral := guard_lateral + 0.95
	var deck_surface_offset := 0.41
	var safety_glass := _aether_glass(CIRCUIT_CYAN)
	var rune_glass := _aether_glass(CIRCUIT_CYAN)
	rune_glass.albedo_color.a = 0.055
	rune_glass.emission_energy_multiplier = 0.18
	for side_sign in [-1.0, 1.0]:
		var signed_side: float = side_sign
		var side_label := "L" if signed_side < 0.0 else "R"
		var core_from := guard_start + side * signed_side * guard_lateral
		var core_to := guard_end + side * signed_side * guard_lateral
		var crown_mouth := start + side * signed_side * mouth_lateral
		var terrace_mouth := target + side * signed_side * mouth_lateral
		_build_causeway_guard_segment(parent, core_from, core_to,
			"%s_Core" % side_label, deck_surface_offset,
			safety_glass, dark, brass, cyan)
		_build_causeway_guard_segment(parent, crown_mouth, core_from,
			"%s_CrownWing" % side_label, deck_surface_offset,
			safety_glass, dark, brass, cyan)
		_build_causeway_guard_segment(parent, core_to, terrace_mouth,
			"%s_TerraceWing" % side_label, deck_surface_offset,
			safety_glass, dark, brass, cyan)

		for post_index in BRIDGE_GUARD_POST_COUNT:
			var post_t := float(post_index) / float(BRIDGE_GUARD_POST_COUNT - 1)
			var post_position := guard_start + direction * (guard_span * post_t) \
				+ side * signed_side * guard_lateral
			var post := _oriented_box(parent, Vector3(0.26, 1.52, 0.26),
				post_position + Vector3(0.0, deck_surface_offset + 0.76, 0.0),
				target, brass)
			post.name = "AetherSafetyPost_%s_%02d" % [
				"L" if signed_side < 0.0 else "R", post_index]
			var node := MeshInstance3D.new()
			var node_mesh := PrismMesh.new()
			node_mesh.size = Vector3(0.30, 0.42, 0.30)
			node.mesh = node_mesh
			node.material_override = cyan if post_index % 2 == 0 else violet
			parent.add_child(node)
			node.global_position = post_position + Vector3(0.0,
				deck_surface_offset + BRIDGE_GUARD_HEIGHT + 0.30, 0.0)

	_build_reference_bridge_facade(parent, guard_start, guard_end, direction, side,
		guard_span, guard_lateral, deck_surface_offset,
		dark, brass, cyan, violet, rune_glass)

	for i in BRIDGE_SEGMENTS:
		var t := (float(i) + 0.5) / float(BRIDGE_SEGMENTS)
		var p := start.lerp(target, t)
		var plank := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(BRIDGE_WIDTH, 0.38, segment_length + 0.22)
		plank.mesh = mesh
		plank.material_override = light if i % 2 == 0 else dark
		parent.add_child(plank)
		# Sits ON the continuous roadbed rather than replacing it, so the
		# banding stays decorative and the walkable surface is one solid piece.
		plank.global_position = p + Vector3(0.0, 0.22, 0.0)
		plank.look_at(target, Vector3.UP)

		# The magitech spine. This used to be a single 0.16 m amber strip laid on
		# the deck, which at any real viewing distance was invisible — the bridge
		# read as bare striped planks with no story on it at all. It is now a
		# brass channel with a recessed cyan core: the machined half of the
		# vocabulary carrying the arcane half, which is the whole Art Castle
		# fusion in one detail. Both pieces stay within BRIDGE_FLUSH_INLAY of the
		# plank surface, so this is an inlay the player walks straight over.
		var conduit_pos := p + Vector3(0.0, 0.41 + BRIDGE_FLUSH_INLAY, 0.0)
		_oriented_box(parent, Vector3(0.62, 0.08, segment_length + 0.24),
			conduit_pos, target, brass)
		var conductor := _oriented_box(parent, Vector3(0.34, 0.10, segment_length + 0.26),
			conduit_pos + Vector3(0.0, 0.01, 0.0), target, cyan)
		conductor.name = "LumenCenterConductor_%02d" % i

		# Arched stone ribs under the deck. Without these the causeway reads as
		# a floating plank — a flat slab with nothing holding it up, which is
		# most of why the old approach looked unfinished. The rib depth follows
		# a sine across the span so the underside reads as an arch, not a wall.
		if i % 4 == 2:
			var arch := sin(t * PI)
			var rib_depth := 0.8 + arch * 1.7
			var rib := _oriented_box(parent,
				Vector3(BRIDGE_WIDTH * 0.72, rib_depth, 0.72),
				p - Vector3(0.0, 0.18 + rib_depth * 0.5, 0.0), target, dark)
			rib.name = "AetherTensionRib_%d" % int(i / 4)
			rib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

			# A brass collar where each rib meets the deck: the machined half of
			# the vocabulary, worked into the masonry rather than bolted beside it.
			_oriented_box(parent, Vector3(BRIDGE_WIDTH * 0.68, 0.16, 0.66),
				p - Vector3(0.0, 0.3, 0.0), target, brass)

			# Aether lamp on alternating sides, so the causeway is lit at night
			# and the ribs are readable from below.
			var lamp_side: float = 1.0 if (i / 2) % 2 == 0 else -1.0
			var lamp_pos: Vector3 = p + side * lamp_side * (BRIDGE_WIDTH * 0.5 - 0.16)
			lamp_pos.y += 1.75
			var bulb := MeshInstance3D.new()
			var bulb_mesh := SphereMesh.new()
			bulb_mesh.radius = 0.26
			bulb_mesh.height = 0.7
			bulb_mesh.radial_segments = 6
			bulb_mesh.rings = 3
			bulb.mesh = bulb_mesh
			bulb.material_override = glow
			parent.add_child(bulb)
			bulb.global_position = lamp_pos
			# The post stays VERTICAL. _oriented_box look_at()s the far end of
			# the causeway, which is correct for planks and rails that follow
			# the span but tips a lamp post over with the slope — that is the
			# scatter of loose diagonal sticks visible along the old deck.
			var post := MeshInstance3D.new()
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.12, 0.85, 0.12)
			post.mesh = post_mesh
			post.material_override = brass
			parent.add_child(post)
			post.global_position = lamp_pos - Vector3(0.0, 0.5, 0.0)

	# The ceremonial dressing: evenly spaced rune inlays in the deck and a small
	# number of light halo arches framing the span. Kept in one place, and one
	# function, so the corridor rules above are enforced at a single point.
	_build_lumen_ceremony(parent, start, target, direction, side, span,
		brass, cyan, violet)

	# Rectangular end-cap prevents the player from falling through a rounding
	# gap where the last segmented plank meets the terrace collision.
	#
	# This used to be a full 4 m-radius disc, which projected sideways well
	# past the rail-free gate opening above and sat squarely across the
	# walking axis as an unbroken round obstruction right at the handoff.
	# Aligned to the direction of travel, it covers the same seam without
	# blocking or narrowing the route onto the terrace.
	var landing_size := Vector3(BRIDGE_WIDTH + 1.0, 0.48, 3.4)
	var landing := _oriented_box(parent, landing_size,
		target + direction * 0.5, target, light)
	landing.name = "CastleDoorLanding"
	_add_box_body(landing, landing_size)

	var beacon := OmniLight3D.new()
	beacon.light_color = RAIL_GLOW
	beacon.light_energy = 1.7
	beacon.omni_range = 10.0
	beacon.shadow_enabled = false
	parent.add_child(beacon)
	beacon.global_position = target + Vector3(0.0, 1.4, 0.0)

	# A matching open lens portal at the terrace end mirrors the crown gateway.
	# Without it the bridge only announced itself as a route
	# on the crown side and simply stopped at a bare landing pad on the
	# terrace side — reading as unfinished rather than one continuous,
	# deliberately designed Lumen Bridge.
	_build_terrace_portal(parent, target, direction, side, brass, glow)


# One collision-backed section of the Aether Balustrade. Keeping the target at
# the same height as the section centre is important: aiming an elevated wall
# at a deck-level target pitches its collider down into the walking route.
func _build_causeway_guard_segment(parent: Node3D, from: Vector3, to: Vector3,
		segment_name: String, deck_offset: float, glass: Material,
		dark: Material, brass: Material, cyan: Material) -> void:
	var length := from.distance_to(to)
	var centre := from.lerp(to, 0.5)
	var along := (to - from).normalized()
	var wall_centre := centre + Vector3.UP * (
		deck_offset + BRIDGE_GUARD_HEIGHT * 0.5)
	var wall_size := Vector3(0.18, BRIDGE_GUARD_HEIGHT, length)
	var wall := _oriented_box(parent, wall_size, wall_centre,
		wall_centre + along, glass)
	wall.name = "CausewaySafetyWall_%s" % segment_name
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_box_body(wall, wall_size)

	var plinth_centre := centre + Vector3.UP * (deck_offset + 0.19)
	var plinth := _oriented_box(parent, Vector3(0.42, 0.38, length),
		plinth_centre, plinth_centre + along, dark)
	plinth.name = "AetherSafetyPlinth_%s" % segment_name

	var cap_centre := centre + Vector3.UP * (
		deck_offset + BRIDGE_GUARD_HEIGHT + 0.08)
	var cap := _oriented_box(parent, Vector3(0.30, 0.16, length),
		cap_centre, cap_centre + along, brass)
	cap.name = "CausewayHandrail_%s" % segment_name

	var conduit_centre := centre + Vector3.UP * (
		deck_offset + BRIDGE_GUARD_HEIGHT * 0.62)
	var conduit := _oriented_box(parent, Vector3(0.10, 0.10, length),
		conduit_centre, conduit_centre + along, cyan)
	conduit.name = "AetherSafetyConduit_%s" % segment_name


# The Lumen Bridge's ceremonial layer: what makes the crown-to-gate connection
# read as Art Castle rather than as a plain stone footbridge.
#
# Three ideas, all of them visual-only (no _add_box_body anywhere in here) and
# all of them held clear of the walking corridor by the BRIDGE_CLEAR_* datums:
#
#   1. Rune inlays, evenly spaced down the deck, flush with the plank surface.
#      They are the "written" half of the magitech story and give the walk a
#      measured ceremonial cadence underfoot.
#   2. Halo arches — deliberately few (HALO_ARCH_COUNT), deliberately thin.
#      Each springs from a pylon standing OUTBOARD of the guard wall and crests
#      well above BRIDGE_CLEAR_HEADROOM, so it frames the player without ever
#      crossing the corridor. This is the strong ceremonial silhouette: from a
#      distance the bridge now has a rhythm of lit rings against the sky
#      instead of one flat unbroken bar.
#   3. Pylon crystals echoing the crown's own cyan/violet crystals, so the
#      tower top and the span are visibly the same architecture.
const HALO_ARCH_COUNT := 1
const RUNE_INLAY_COUNT := 3

func _build_lumen_ceremony(parent: Node3D, start: Vector3, target: Vector3,
		direction: Vector3, side: Vector3, span: float,
		brass: Material, cyan: Material, violet: Material) -> void:
	# --- 1. Flush rune inlays ------------------------------------------------
	# Inset from both ends so no inlay lands on the launch pad or the terrace
	# landing, where it would read as a stray plate rather than part of the run.
	for i in RUNE_INLAY_COUNT:
		var t := (float(i) + 0.5) / float(RUNE_INLAY_COUNT)
		var centre: Vector3 = start.lerp(target, t) \
			+ Vector3(0.0, 0.41 + BRIDGE_FLUSH_INLAY, 0.0)
		# A brass frame with a violet glyph bar across it: the same
		# brass-carries-arcane grammar as the centre conduit, rotated 90° so the
		# deck reads as a sequence of charged plates rather than one long pipe.
		var plate := _oriented_box(parent, Vector3(1.75, 0.07, 0.42),
			centre, target, brass)
		plate.name = "LumenRuneSeal_%d" % i
		_oriented_box(parent, Vector3(1.15, 0.09, 0.16),
			centre + Vector3(0.0, 0.01, 0.0), target, violet)
		# Two cyan pips outboard of the glyph, aligned with the edge conduits, so
		# each plate visually taps power from the rails it sits between.
		for pip_sign in [-1.0, 1.0]:
			var pip: float = pip_sign
			_oriented_box(parent, Vector3(0.22, 0.09, 0.22),
				centre + side * pip * 0.75 + Vector3(0.0, 0.01, 0.0),
				target, cyan)

	# --- 2/3. One tall pointed resonance frame -------------------------------
	# This is the third and only midspan A-frame. Together with the two
	# destination lens gates it creates the three-beat Gothic silhouette from
	# the reference without turning the short span into a tunnel.
	for arch_index in HALO_ARCH_COUNT:
		var at := (float(arch_index) + 1.0) / (float(HALO_ARCH_COUNT) + 1.0)
		var arch_centre: Vector3 = start.lerp(target, at)
		var frame := Node3D.new()
		frame.name = "MidspanResonanceFrame"
		parent.add_child(frame)
		var foot_offset := LENS_GATE_HALF_WIDTH
		var shoulder_height := 4.60
		var apex := arch_centre + Vector3(0.0, 7.15, 0.0)
		for pylon_sign in [-1.0, 1.0]:
			var pylon: float = pylon_sign
			var foot: Vector3 = arch_centre + side * pylon * foot_offset
			# This post must remain vertical. Using _oriented_box here aimed its
			# long Y axis toward the lower route target, producing the enormous
			# diagonal bars that visually barricaded the player-eye view.
			var post := MeshInstance3D.new()
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.34, shoulder_height, 0.34)
			post.mesh = post_mesh
			post.material_override = brass
			frame.add_child(post)
			post.global_position = foot + Vector3(0.0, shoulder_height * 0.5, 0.0)
			post.name = "LumenArchPylon_%d_%s" % [
				arch_index, "L" if pylon < 0.0 else "R"]
			post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var shoulder := foot + Vector3(0.0, shoulder_height, 0.0)
			var brass_yoke := _visual_chord(frame, shoulder, apex, 0.19, brass)
			brass_yoke.name = "LumenArchYoke_%s_Brass" % (
				"L" if pylon < 0.0 else "R")
			var cyan_yoke := _visual_chord(frame,
				shoulder + direction * 0.14, apex + direction * 0.14,
				0.075, cyan)
			cyan_yoke.name = "LumenArchYoke_%s_Cyan" % (
				"L" if pylon < 0.0 else "R")

		# A single keystone rune floating at the crest, alternating cyan/violet
		# down the span. This is the piece that carries at wide-shot distance.
		var keystone := MeshInstance3D.new()
		keystone.name = "LumenArchKeystone_%d" % arch_index
		var keystone_mesh := PrismMesh.new()
		keystone_mesh.size = Vector3(0.46, 0.50, 0.26)
		keystone.mesh = keystone_mesh
		keystone.material_override = violet
		frame.add_child(keystone)
		keystone.global_position = apex + Vector3(0.0, 0.28, 0.0)
		keystone.look_at(keystone.global_position + direction, Vector3.UP)

		# One soft cyan light per arch. Three lights across the span is enough
		# to make the halo rings read at night without adding a light per
		# ornament, which would be a real cost for a decorative layer.
		var arch_lamp := OmniLight3D.new()
		arch_lamp.light_color = CIRCUIT_CYAN
		arch_lamp.light_energy = 1.5
		arch_lamp.omni_range = 9.0
		arch_lamp.shadow_enabled = false
		parent.add_child(arch_lamp)
		arch_lamp.global_position = arch_centre + Vector3(0.0, 4.2, 0.0)


# Reference-driven side elevation: three transparent rune-glass bays per side
# sit over a dark inscription fascia. Crossed cyan tracery makes the safety
# field read as designed arcane glass, while one low-poly gear on each outside
# face exposes the bridge's mechanical calibration system.
func _build_reference_bridge_facade(parent: Node3D, start: Vector3,
		target: Vector3, direction: Vector3, side: Vector3,
		guard_span: float, guard_lateral: float, deck_offset: float,
		dark: Material, brass: Material, cyan: Material, violet: Material,
		glass: Material) -> void:
	const BAY_COUNT := 3
	var bay_length := guard_span / float(BAY_COUNT)
	for facade_sign in [-1.0, 1.0]:
		var signed_facade: float = facade_sign
		var facade_side := "L" if signed_facade < 0.0 else "R"
		var lateral_offset := side * signed_facade * (guard_lateral + 0.04)
		var fascia_centre := start + direction * (guard_span * 0.5) \
			+ lateral_offset + Vector3(0.0, deck_offset + 0.20, 0.0)
		var fascia := _oriented_box(parent, Vector3(0.24, 0.42, guard_span),
			fascia_centre, fascia_centre + direction, dark)
		fascia.name = "AetherRuneFascia_%s" % facade_side

		for bay_index in BAY_COUNT:
			var bay_centre := start \
				+ direction * (bay_length * (float(bay_index) + 0.5)) \
				+ lateral_offset + Vector3(0.0, deck_offset + 0.96, 0.0)
			var bay := _oriented_box(parent,
				Vector3(0.08, 0.86, bay_length - 0.16),
				bay_centre, bay_centre + direction, glass)
			bay.name = "AetherRuneGlassBay_%s_%d" % [facade_side, bay_index]

			var bay_start := start + direction * (bay_length * float(bay_index) + 0.14) \
				+ lateral_offset
			var bay_end := start + direction * (bay_length * float(bay_index + 1) - 0.14) \
				+ lateral_offset
			var trace_a := _visual_chord(parent,
				bay_start + Vector3(0.0, deck_offset + 0.58, 0.0),
				bay_end + Vector3(0.0, deck_offset + 1.31, 0.0),
				0.075, cyan)
			trace_a.name = "AetherGlassTracery_%s_%d_A" % [facade_side, bay_index]
			var trace_b := _visual_chord(parent,
				bay_start + Vector3(0.0, deck_offset + 1.31, 0.0),
				bay_end + Vector3(0.0, deck_offset + 0.58, 0.0),
				0.075, cyan)
			trace_b.name = "AetherGlassTracery_%s_%d_B" % [facade_side, bay_index]

			var rune_centre := start \
				+ direction * (bay_length * (float(bay_index) + 0.5)) \
				+ lateral_offset + side * signed_facade * 0.08 \
				+ Vector3(0.0, deck_offset + 0.20, 0.0)
			var rune := _oriented_box(parent, Vector3(0.10, 0.14, 0.48),
				rune_centre, rune_centre + direction,
				cyan if bay_index != 1 else violet)
			rune.name = "AetherFasciaRune_%s_%d" % [facade_side, bay_index]

		_build_low_poly_gear(parent,
			start + direction * (guard_span * 0.68) \
				+ side * signed_facade * (guard_lateral + 0.22) \
				+ Vector3(0.0, deck_offset + 0.47, 0.0),
			direction, side, facade_side, brass, cyan)


func _build_low_poly_gear(parent: Node3D, centre: Vector3,
		direction: Vector3, side: Vector3, gear_name: String,
		brass: Material, cyan: Material) -> void:
	var gear := Node3D.new()
	gear.name = "AetherGear_%s" % gear_name
	parent.add_child(gear)
	var hub := MeshInstance3D.new()
	hub.name = "AetherGearHub_%s" % gear_name
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.52
	hub_mesh.bottom_radius = 0.52
	hub_mesh.height = 0.12
	hub_mesh.radial_segments = 12
	hub.mesh = hub_mesh
	hub.material_override = brass
	gear.add_child(hub)
	hub.global_position = centre
	hub.rotation_degrees.x = 90.0
	var core := MeshInstance3D.new()
	core.name = "AetherGearCore_%s" % gear_name
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.17
	core_mesh.bottom_radius = 0.17
	core_mesh.height = 0.15
	core_mesh.radial_segments = 8
	core.mesh = core_mesh
	core.material_override = cyan
	gear.add_child(core)
	core.global_position = centre + side * 0.02
	core.rotation_degrees.x = 90.0
	for tooth_index in 8:
		var angle := TAU * float(tooth_index) / 8.0
		var tooth := MeshInstance3D.new()
		tooth.name = "AetherGearTooth_%s_%d" % [gear_name, tooth_index]
		var tooth_mesh := BoxMesh.new()
		tooth_mesh.size = Vector3(0.24, 0.22, 0.16)
		tooth.mesh = tooth_mesh
		tooth.material_override = brass
		gear.add_child(tooth)
		tooth.global_position = centre + direction * cos(angle) * 0.62 \
			+ Vector3.UP * sin(angle) * 0.62
		tooth.rotation.y = -atan2(direction.z, direction.x)
		tooth.rotation.z = angle


# An open Aether Lens gate at the terrace end of the causeway matches the crown
# gateway, so the whole span reads as one bright, continuous route rather than
# a gateway on one side and a bare stub on the other. It is set back from
# `target` in the rail-free mouth, with visual-only pylons outside the road edge
# and split yokes above the camera sightline.
func _build_terrace_portal(parent: Node3D, target: Vector3, direction: Vector3,
		side: Vector3, brass: Material, glow: Material) -> void:
	var portal_centre := target - direction * 1.0
	_build_aether_lens_gate(parent, portal_centre, direction, side,
		"Terrace", brass, _glow(CIRCUIT_CYAN), _glow(RUNE_VIOLET))


# Shared open gate language at both hand-offs. No part receives a collider;
# the bases sit outside the road edge and the split yokes only cross above the
# 3.4 m sightline datum, leaving player movement and the follow camera clear.
func _build_aether_lens_gate(parent: Node3D, centre: Vector3,
		direction: Vector3, side: Vector3, gate_name: String,
		brass: Material, cyan: Material, violet: Material) -> void:
	var gate := Node3D.new()
	gate.name = "%sAetherLensGate" % gate_name
	parent.add_child(gate)
	var shoulder_height := 4.60
	var apex := centre + Vector3(0.0, 7.35, 0.0)
	for gate_sign in [-1.0, 1.0]:
		var signed: float = gate_sign
		var foot := centre + side * signed * LENS_GATE_HALF_WIDTH
		var pylon := MeshInstance3D.new()
		pylon.name = "AetherLensPylon_%s_%s" % [gate_name,
			"L" if signed < 0.0 else "R"]
		var pylon_mesh := BoxMesh.new()
		pylon_mesh.size = Vector3(0.42, shoulder_height, 0.42)
		pylon.mesh = pylon_mesh
		pylon.material_override = _stone(STONE_LIGHT)
		gate.add_child(pylon)
		pylon.global_position = foot + Vector3(0.0, shoulder_height * 0.5, 0.0)

		var shoulder := foot + Vector3(0.0, shoulder_height, 0.0)
		var brass_yoke := _visual_chord(gate, shoulder, apex,
			0.19, brass)
		brass_yoke.name = "AetherLensYoke_%s_%s_Brass" % [gate_name,
			"L" if signed < 0.0 else "R"]
		var cyan_yoke := _visual_chord(gate,
			shoulder + direction * 0.13 - Vector3(0.0, 0.12, 0.0),
			apex + direction * 0.13 - Vector3(0.0, 0.12, 0.0),
			0.075, cyan)
		cyan_yoke.name = "AetherLensYoke_%s_%s_Cyan" % [gate_name,
			"L" if signed < 0.0 else "R"]

	var lens := MeshInstance3D.new()
	lens.name = "AetherLensApex_%s" % gate_name
	var lens_mesh := PrismMesh.new()
	lens_mesh.size = Vector3(0.46, 0.68, 0.30)
	lens.mesh = lens_mesh
	lens.material_override = violet
	gate.add_child(lens)
	lens.global_position = apex + Vector3(0.0, 0.14, 0.0)
	lens.look_at(lens.global_position + direction, Vector3.UP)

	# A compact astrolabe instrument is mounted outside one pylon at each
	# destination. Its crossed rings echo the observatory crown while keeping
	# the complete player/camera prism untouched.
	var astrolabe_centre := centre + side * (LENS_GATE_HALF_WIDTH + 0.65) \
		+ Vector3(0.0, 4.18, 0.0)
	for ring_index in 2:
		var ring := MeshInstance3D.new()
		ring.name = "AetherAstrolabeRing_%s_%d" % [gate_name, ring_index]
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.52
		ring_mesh.outer_radius = 0.62
		ring_mesh.rings = 12
		ring_mesh.ring_segments = 5
		ring.mesh = ring_mesh
		ring.material_override = brass if ring_index == 0 else cyan
		gate.add_child(ring)
		ring.global_position = astrolabe_centre
		ring.rotation_degrees = Vector3(0.0, 0.0, 90.0) \
			if ring_index == 0 else Vector3(55.0, 0.0, 90.0)
	var astrolabe_core := MeshInstance3D.new()
	astrolabe_core.name = "AetherAstrolabeCore_%s" % gate_name
	var astrolabe_mesh := SphereMesh.new()
	astrolabe_mesh.radius = 0.21
	astrolabe_mesh.height = 0.42
	astrolabe_mesh.radial_segments = 8
	astrolabe_mesh.rings = 4
	astrolabe_core.mesh = astrolabe_mesh
	astrolabe_core.material_override = violet
	gate.add_child(astrolabe_core)
	astrolabe_core.global_position = astrolabe_centre


func _visual_chord(parent: Node3D, from: Vector3, to: Vector3,
		thickness: float, material: Material) -> MeshInstance3D:
	var chord := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, from.distance_to(to))
	chord.mesh = mesh
	chord.material_override = material
	chord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(chord)
	chord.global_position = from.lerp(to, 0.5)
	chord.look_at(to, Vector3.UP)
	return chord


func _oriented_box(parent: Node3D, size: Vector3, position: Vector3,
		target: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = material
	parent.add_child(part)
	part.global_position = position
	part.look_at(target, Vector3.UP)
	return part


func _add_lantern(parent: Node3D, base: Vector2, angle: float, y: float) -> void:
	var r := STAIR_RADIUS + STEP_WIDTH * 0.5
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	sphere.radial_segments = 6
	sphere.rings = 3
	bulb.mesh = sphere

	var glow := StandardMaterial3D.new()
	glow.albedo_color = RAIL_GLOW
	glow.emission_enabled = true
	glow.emission = RAIL_GLOW
	glow.emission_energy_multiplier = 2.0
	bulb.material_override = glow
	parent.add_child(bulb)
	bulb.global_position = Vector3(base.x + cos(angle) * r, y + 1.5, base.y + sin(angle) * r)

	var lamp := OmniLight3D.new()
	lamp.light_color = RAIL_GLOW
	lamp.light_energy = 1.2
	lamp.omni_range = 9.0
	lamp.shadow_enabled = false
	bulb.add_child(lamp)


func _ground_at(x: float, z: float) -> float:
	# Sample Terrain3D directly. A world ray also intersects runtime station
	# decks, castle props, and roofs; that bug treated a floating platform as
	# the earth and built a two-step staircase 30 metres above the player.
	var terrain := get_parent().get_node_or_null("Environment/Terrain3D")
	if terrain != null and terrain.get("data") != null:
		var height: float = terrain.data.get_height(Vector3(x, 0.0, z))
		if not is_nan(height):
			return height

	# Defensive fallback for worlds that reuse the stair without Terrain3D.
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, 400.0, z), Vector3(x, -100.0, z))
	var hit := space.intersect_ray(query)
	return hit.position.y if hit.has("position") else 35.5


func _add_box_body(part: MeshInstance3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	part.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)


func _stone(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.76
	material.metallic = 0.06
	return material


func _metal(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = 0.82
	material.roughness = 0.3
	return material


func _glow(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 1.8
	material.roughness = 0.25
	return material


func _aether_glass(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(colour.r, colour.g, colour.b, 0.16)
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 0.42
	material.roughness = 0.12
	material.metallic = 0.05
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
