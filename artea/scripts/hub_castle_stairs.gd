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

const BlenderCrownParapetScene := preload(
	"res://assets3D/castle_rooftop_parapet/glb/castle_rooftop_parapet.glb")
const CrownGarden := preload("res://scripts/castle_rooftop_garden.gd")
const RoyalTerrace := preload("res://scripts/castle_royal_terrace.gd")
const RoyalFountain := preload("res://scripts/castle_royal_fountain.gd")

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
const BLENDER_PARAPET_PANEL_LENGTH := 6.236

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
# The visible tread/riser lane and the single collision road must tuck slightly
# beneath the inner faces of both helical guards. Stopping short used to leave a
# continuous daylight/collision slot beside each barrier: a jumping capsule or
# a loose object could settle into it and become wedged. A small hidden overlap
# closes that slot without letting the visible tread ends pass through the wall.
const INNER_GUARD_HALF_WIDTH := 0.22
const OUTER_GUARD_HALF_WIDTH := 0.24
const TREAD_GUARD_OVERLAP := 0.10
const TREAD_INNER_RADIUS := STAIR_RADIUS - STEP_WIDTH * 0.5 \
	+ INNER_GUARD_HALF_WIDTH - TREAD_GUARD_OVERLAP
const TREAD_OUTER_RADIUS := STAIR_RADIUS + STEP_WIDTH * 0.5 \
	- OUTER_GUARD_HALF_WIDTH + TREAD_GUARD_OVERLAP
const TREAD_CLEAR_WIDTH := TREAD_OUTER_RADIUS - TREAD_INNER_RADIUS
const TREAD_CENTRE_RADIUS := (TREAD_INNER_RADIUS + TREAD_OUTER_RADIUS) * 0.5
# The exterior stair wall needs to swallow the stepped tread ends, not merely
# touch their tips. 0.35 m of overlap hides the white zig-zag from outside
# while retaining clearance for the packed player's 0.5 m capsule in the
# tested outer walking lane.
const OUTER_BARRIER_TREAD_OVERLAP := 0.35
const OUTER_BARRIER_INNER_RADIUS := TREAD_OUTER_RADIUS \
	- OUTER_BARRIER_TREAD_OVERLAP
const OUTER_BARRIER_TOP_OFFSET := 1.75
# A real parapet is thick enough to read as masonry without becoming a second
# walkable floor. The previous 1.64 m cap dominated the stair and exposed a
# broad empty ledge in overhead views.
const OUTER_PARAPET_OUTER_RADIUS := STAIR_RADIUS + STEP_WIDTH * 0.5 + 0.32
const OUTER_PARAPET_WIDTH := OUTER_PARAPET_OUTER_RADIUS \
	- OUTER_BARRIER_INNER_RADIUS
# Keep the collision road tucked beneath the guard, but stop the rendered step
# boxes before the wall's inner face. The old shared radius made every white
# tread physically pass 0.35 m through the blue parapet in exterior views.
# Rectangular tread corners sit slightly farther from the tower than the centre
# of their outer edge. A 0.16 m setback clears that diagonal projection at the
# widest generated tread depth, eliminating the last thin white clips.
const VISIBLE_TREAD_WALL_CLEARANCE := 0.16
const VISIBLE_TREAD_OUTER_RADIUS := OUTER_BARRIER_INNER_RADIUS \
	- VISIBLE_TREAD_WALL_CLEARANCE
# The hidden walk surface still overlaps the inner guard by 0.10 m so there is
# no collision slot. The rendered tread, riser and nosing must not share that
# overlap: it made the white stair boxes visibly pass through the tower-side
# parapet. A shallow setback leaves room for a dressed stone skirting course.
const INNER_BARRIER_LANE_FACE_RADIUS := STAIR_RADIUS - STEP_WIDTH * 0.5 \
	+ INNER_GUARD_HALF_WIDTH
const VISIBLE_TREAD_INNER_CLEARANCE := 0.12
const VISIBLE_TREAD_INNER_RADIUS := INNER_BARRIER_LANE_FACE_RADIUS \
	+ VISIBLE_TREAD_INNER_CLEARANCE
const VISIBLE_TREAD_WIDTH := VISIBLE_TREAD_OUTER_RADIUS \
	- VISIBLE_TREAD_INNER_RADIUS
const VISIBLE_TREAD_CENTRE_RADIUS := (VISIBLE_TREAD_INNER_RADIUS \
	+ VISIBLE_TREAD_OUTER_RADIUS) * 0.5
# Shared centre datum for the terrain-level first tread and every continuous
# helix around it. Keeping this in one place prevents the guard, roadbed and
# walking surface from starting above the visible stair again.
const FIRST_TREAD_CENTRE_OFFSET := 0.17
# Straight approach edges meet the guard faces, unlike rectangular treads on
# a curve which need corner clearance. Bury 2 cm of paving under each wall.
const ENTRY_FLOOR_INNER := INNER_BARRIER_LANE_FACE_RADIUS - 0.02
const ENTRY_FLOOR_OUTER := OUTER_BARRIER_INNER_RADIUS + 0.02
const ENTRY_FLOOR_WIDTH := ENTRY_FLOOR_OUTER - ENTRY_FLOOR_INNER
const ENTRY_FLOOR_CENTRE := (ENTRY_FLOOR_INNER + ENTRY_FLOOR_OUTER) * 0.5
# The grounded castle flight now owns the lead-in. Starting the curved guards
# before the true spiral used to sweep them across that straight approach and
# create an invisible pinch point, so the helical guards begin at tread zero.
const GUARD_ENTRY_LEAD_T := 0.0
# The first grounded flight is closed down to the actual sloped Terrain3D
# surface. Past this point the stair visibly becomes the tower's spiral rather
# than pretending the entire elevated ascent is part of the hillside.
const ENTRY_FOUNDATION_END_T := 0.20
# A short grounded flight reaches back onto the real hillside. The tower-centre
# terrain datum is substantially higher than the land at the stair mouth, so a
# nominally grounded first spiral tread can still demand a jump from the player.
const GROUND_ENTRY_RUN := 6.0

# Rise per tread. Kept well under the controller's MAX_STEP_HEIGHT (0.65) so
# every step is climbed by walking, never by jumping.
const STEP_RISE := 0.3
# A non-integer turn count prevents every flight, parapet and lamp from stacking
# on the exact same vertical axes. The previous three perfect turns produced
# the dense "architecture pile" visible in overhead shots.
const TURNS := 2.35
const ReferenceStyle := preload("res://scripts/castle_reference_style.gd")

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

# The stair now uses the same value hierarchy as the nearby red-roof castle kit:
# pale blue-grey limestone faces, darker course joints and saturated red roof
# caps. The earlier navy/black ribbons read as modern racetrack rails.
const STONE_LIGHT := Color("9aabb2")
const STONE_DARK := Color("687f91")
const STONE_COURSE := Color("c7d2d2")
const ROOF_RED := Color("ef443d")   # matches the village and castle roofs
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
	#
	# This must stay a plain, angle-independent cylinder rather than tracking the
	# guard's radius: it exists at every angle for the tower's whole height, so
	# widening it out to the guard's own footprint (tried and reverted — commit
	# 17cb6ab) makes it overlap the guard's collision continuously along the
	# *entire* spiral, not just near the pocket that needed closing. A player
	# standing anywhere on the inner rail then has their capsule touching two
	# overlapping solids — a smooth cylinder and the guard's faceted trimesh — at
	# a sharp seam, which is what froze movement when jumping onto the railing.
	# The pocket behind the rail is closed instead by InnerSafetyPlinth, a
	# helix-shaped fill that only overlaps the guard where the guard actually is.
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
		bm.height = 1.10
		bm.radial_segments = TOWER_SIDES
		band.mesh = bm
		band.material_override = _stone(STONE_DARK)
		parent.add_child(band)
		band.global_position = Vector3(base.x, ground - 4.0 + height * (float(i) / float(bands + 1)), base.y)
		# A shallow dressed lip above the darker belt repeats the keep's stepped
		# storey courses. Both stay inside the inner stair guard, not in the lane.
		var lip := MeshInstance3D.new()
		lip.name = "KeepCourseLip_%02d" % i
		var lip_mesh := CylinderMesh.new()
		lip_mesh.top_radius = bm.top_radius - 0.04
		lip_mesh.bottom_radius = bm.top_radius + 0.05
		lip_mesh.height = 0.18
		lip_mesh.radial_segments = TOWER_SIDES
		lip.mesh = lip_mesh
		lip.material_override = ReferenceStyle.material("block")
		parent.add_child(lip)
		lip.global_position = band.global_position + Vector3.UP * 0.63

	_build_tower_facade(parent, base, ground, top_y)


# The spiral itself: a tread plus a riser per step, hugging the shaft.
func _build_stair(parent: Node3D, base: Vector2, ground: float, top_y: float) -> void:
	var light := _stone(STONE_LIGHT)
	var dark := _stone(STONE_DARK)
	var start_angle := atan2(CASTLE_XZ.y - base.y, CASTLE_XZ.x - base.x) + PI

	# Derive the tread count from the actual climb so the rise per step stays at
	# STEP_RISE regardless of terrain height. Hard-coding 96 steps meant the rise
	# silently changed with the ground, and on tall ground it exceeded what the
	# controller can step over — the stair became unclimbable by arithmetic.
	# The first visible tread now rests directly on terrain. The old +0.4 datum
	# needed a large circular apron to hide the gap, which looked like a ring
	# blocking the staircase in the supplied screenshot.
	var first_tread_y := ground + FIRST_TREAD_CENTRE_OFFSET
	var climb := top_y - first_tread_y
	_step_count = maxi(2, int(ceil(climb / STEP_RISE)))

	# Treads must overlap along the arc, or the capsule drops into the wedge
	# between two rotated boxes. Widen the tread until consecutive centres are
	# closer together than the box is deep.
	var arc_step: float = (TAU * TURNS * STAIR_RADIUS) / float(_step_count)
	var tread_depth: float = maxf(STEP_DEPTH, arc_step * 1.6)
	parent.set_meta("stair_tread_inner_radius", TREAD_INNER_RADIUS)
	parent.set_meta("stair_tread_outer_radius", TREAD_OUTER_RADIUS)
	parent.set_meta("inner_guard_lane_face_radius",
		INNER_BARRIER_LANE_FACE_RADIUS)
	parent.set_meta("outer_guard_lane_face_radius",
		OUTER_BARRIER_INNER_RADIUS)
	parent.set_meta("stair_guard_surface_overlap", TREAD_GUARD_OVERLAP)
	parent.set_meta("outer_barrier_tread_overlap", OUTER_BARRIER_TREAD_OVERLAP)
	parent.set_meta("outer_parapet_width", OUTER_PARAPET_WIDTH)
	parent.set_meta("visible_tread_outer_radius", VISIBLE_TREAD_OUTER_RADIUS)
	parent.set_meta("visible_tread_inner_radius", VISIBLE_TREAD_INNER_RADIUS)
	parent.set_meta("visible_tread_wall_clearance", VISIBLE_TREAD_WALL_CLEARANCE)
	parent.set_meta("visible_tread_inner_clearance", VISIBLE_TREAD_INNER_CLEARANCE)
	parent.set_meta("stair_lane_has_no_barrier_gap", true)

	_build_continuous_ascent(parent, base, ground, top_y, start_angle,
		dark, light)
	_build_grounded_castle_entry(parent, base, first_tread_y, start_angle,
		light, dark)

	for i in _step_count:
		var t := float(i) / float(_step_count - 1)
		var angle := start_angle + t * TAU * TURNS
		var y: float = lerpf(first_tread_y, top_y, t)
		var pos := Vector3(base.x + cos(angle) * VISIBLE_TREAD_CENTRE_RADIUS, y,
			base.y + sin(angle) * VISIBLE_TREAD_CENTRE_RADIUS)

		# Tread — the surface the player runs on.
		var tread := MeshInstance3D.new()
		tread.name = "StairTread_%03d" % i
		var tm := BoxMesh.new()
		tm.size = Vector3(VISIBLE_TREAD_WIDTH, 0.34, tread_depth)
		tread.mesh = tm
		# Keep the flight in one castle-stone family. The former light/dark
		# checkerboard made the long ascent read like temporary debug geometry.
		tread.material_override = light
		parent.add_child(tread)
		tread.global_position = pos
		tread.rotation.y = -angle
		# Collision belongs to the continuous AscentRoadbed. Per-tread rotated
		# boxes overlap into diagonal walls along the inside of the spiral.

		# Riser — the vertical face under the tread. Without this the stair
		# reads as floating planks instead of steps.
		var riser := MeshInstance3D.new()
		riser.name = "StairRiser_%03d" % i
		var rm := BoxMesh.new()
		rm.size = Vector3(VISIBLE_TREAD_WIDTH, STEP_RISE + 0.3, 0.3)
		riser.mesh = rm
		riser.material_override = dark
		parent.add_child(riser)
		riser.global_position = pos + Vector3(0.0, -0.3, 0.0)
		riser.rotation.y = -angle

		# A restrained nosing course gives every tread a finished leading edge
		# without adding collision ridges that could catch the player capsule.
		var tangent := Vector3(-sin(angle), 0.0, cos(angle))
		var nosing := MeshInstance3D.new()
		nosing.name = "StairStoneNosing_%03d" % i
		var nosing_mesh := BoxMesh.new()
		nosing_mesh.size = Vector3(VISIBLE_TREAD_WIDTH, 0.08, 0.13)
		nosing.mesh = nosing_mesh
		nosing.material_override = _stone(STONE_COURSE)
		parent.add_child(nosing)
		nosing.global_position = pos + tangent * (tread_depth * 0.5 - 0.055) \
			+ Vector3.UP * 0.205
		nosing.rotation.y = -angle
		nosing.set_meta("visual_only", true)

		if i % 24 == 0:
			_add_castle_stair_torch(parent, base, angle, y, i)

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
	wayfinding.text = "HIGH KEEP\nCastle stair"
	wayfinding.font_size = 18
	wayfinding.outline_size = 6
	wayfinding.modulate = Color(0.92, 0.78, 0.54)
	wayfinding.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	wayfinding.pixel_size = 0.0065
	parent.add_child(wayfinding)
	wayfinding.global_position = Vector3(
		base.x + cos(sign_angle) * (STAIR_RADIUS + 4.2),
		ground + 2.1,
		base.y + sin(sign_angle) * (STAIR_RADIUS + 4.2))


# Builds a real walkable connection from the hillside to the first spiral
# tread. The former collision ramp was hidden beneath chunky visual steps, so
# the player moved smoothly while the architecture looked uneven and artificial.
# One visible, collision-backed promenade now owns the whole straight route:
# there are no riser seams to snag a capsule and the visible ground matches the
# surface the player actually stands on.
func _build_grounded_castle_entry(parent: Node3D, base: Vector2,
		first_tread_y: float, start_angle: float, light: Material,
		dark: Material) -> void:
	var entry := Node3D.new()
	entry.name = "GroundedCastleEntry"
	parent.add_child(entry)
	var radial := Vector3(cos(start_angle), 0.0, sin(start_angle))
	var forward := Vector3(-sin(start_angle), 0.0, cos(start_angle))
	var first_centre := Vector3(base.x, first_tread_y, base.y) \
		+ radial * TREAD_CENTRE_RADIUS
	var first_surface_y := first_tread_y + 0.17
	var far_centre := first_centre - forward * GROUND_ENTRY_RUN
	var far_ground := -INF
	for lane_fraction in [-0.48, 0.0, 0.48]:
		var lane_point: Vector3 = far_centre + radial * (TREAD_CLEAR_WIDTH * lane_fraction)
		far_ground = maxf(far_ground, _ground_at(lane_point.x, lane_point.z))
	var entry_surface_y := minf(first_surface_y - 0.04, far_ground + 0.08)
	entry.set_meta("terrain_surface_y", far_ground)
	var ramp_start := Vector3(far_centre.x, entry_surface_y - 0.15, far_centre.z)
	var ramp_end := Vector3(first_centre.x, first_surface_y - 0.15, first_centre.z)
	var ramp_length := ramp_start.distance_to(ramp_end) + 0.36
	var visible_centre_shift := radial * (ENTRY_FLOOR_CENTRE - TREAD_CENTRE_RADIUS)
	var ramp := _oriented_box(entry,
		Vector3(ENTRY_FLOOR_WIDTH, 0.30, ramp_length),
		ramp_start.lerp(ramp_end, 0.5) + visible_centre_shift,
		ramp_end + visible_centre_shift, light)
	ramp.name = "GroundEntryWalkSurface"
	ramp.set_meta("smooth_straight_route", true)
	ramp.set_meta("floor_edges_seated_in_masonry", true)
	var paving := ShaderMaterial.new()
	paving.shader = load("res://shaders/castle_courtyard_stone.gdshader")
	paving.set_shader_parameter("paving", true)
	ramp.material_override = paving
	ramp.set_meta("preserve_castle_finish", true)
	var ramp_collision := _oriented_box(entry,
		Vector3(TREAD_CLEAR_WIDTH, 0.30, ramp_length),
		ramp_start.lerp(ramp_end, 0.5), ramp_end, dark)
	ramp_collision.name = "GroundEntryWalkCollision"
	_add_box_body(ramp_collision, (ramp_collision.mesh as BoxMesh).size)
	ramp_collision.visible = false
	ramp_collision.set_meta("authoritative_collision_surface", true)
	entry.set_meta("visible_surface_outer_radius", ENTRY_FLOOR_OUTER)
	entry.set_meta("visible_surface_inner_radius", ENTRY_FLOOR_INNER)
	entry.set_meta("surface_start", Vector3(far_centre.x, entry_surface_y, far_centre.z))
	entry.set_meta("surface_end", Vector3(first_centre.x, first_surface_y, first_centre.z))
	_build_ground_entry_foundation(entry, radial, far_centre, first_centre,
		entry_surface_y, first_surface_y, dark)
	_decorate_ground_entry_brick_courses(entry, radial, far_centre, first_centre,
		entry_surface_y, first_surface_y)

	# Both capitals use the entrance floor datum. Only their buried feet follow
	# terrain, so the hillside cannot leave the two rooflines at different heights.
	for side_sign in [-1.0, 1.0]:
		var radius := INNER_BARRIER_LANE_FACE_RADIUS - 0.40 if side_sign < 0 else OUTER_BARRIER_INNER_RADIUS + 0.40
		var post_centre: Vector3 = far_centre + radial * (radius - TREAD_CENTRE_RADIUS)
		var post_ground := _ground_at(post_centre.x, post_centre.z)
		var post_bottom := minf(post_ground - 0.3, entry_surface_y - 0.30)
		var post_top := entry_surface_y + 1.78
		var post_position := Vector3(post_centre.x, (post_bottom + post_top) * 0.5, post_centre.z)
		var post := _oriented_box(entry, Vector3(0.74, post_top - post_bottom, 0.74),
			post_position, post_position + forward, ReferenceStyle.material("wall"))
		post.name = "GroundEntryStoneNewel_%s" % ("Left" if side_sign < 0.0 else "Right")
		_add_box_body(post, (post.mesh as BoxMesh).size)
		var capital_position := Vector3(post_centre.x, post_top, post_centre.z)
		var capital := _oriented_box(entry, Vector3(0.80, 0.20, 0.80), capital_position,
			capital_position + forward, ReferenceStyle.material("trim"))
		capital.name = "GroundEntryPierCapital_%s" % ("Left" if side_sign < 0 else "Right")
		_add_box_body(capital, (capital.mesh as BoxMesh).size)
		var window := ReferenceStyle.window(entry, Vector3.ZERO, -forward, 0.32)
		window.global_position = Vector3(post_centre.x, entry_surface_y + 1.19, post_centre.z) - forward * 0.375
		var roof := MeshInstance3D.new()
		roof.name = "GroundEntryRedRoof_%s" % ("Left" if side_sign < 0.0 else "Right")
		var roof_mesh := CylinderMesh.new()
		roof_mesh.top_radius = 0.0
		roof_mesh.bottom_radius = 0.58
		roof_mesh.height = 0.72
		roof_mesh.radial_segments = 4
		roof.mesh = roof_mesh
		roof.material_override = ReferenceStyle.material("roof")
		entry.add_child(roof)
		roof.global_position = capital_position + Vector3.UP * 0.46
		roof.rotation.y = PI * 0.25
		var roof_body := StaticBody3D.new()
		roof.add_child(roof_body)
		var roof_shape := CollisionShape3D.new()
		roof_shape.shape = roof_mesh.create_convex_shape()
		roof_body.add_child(roof_shape)
	_build_ground_entry_balustrades(entry, radial, far_centre,
		first_centre, entry_surface_y, first_surface_y, light)
	entry.set_meta("walkable_from_terrain", true)
	entry.set_meta("barriers_join_spiral", true)
	entry.set_meta("collision_surface_continuous", true)
	entry.set_meta("terrain_gap_closed", true)


# Closed stonework under the straight approach. Its upper edge follows the
# walk surface and its lower vertices are buried into the sampled Terrain3D
# hillside, so uneven grass can never reveal the former floating-floor gap.
func _build_ground_entry_foundation(parent: Node3D, radial: Vector3,
		far_centre: Vector3, first_centre: Vector3,
		entry_surface_y: float, first_surface_y: float,
		material: Material) -> void:
	const SAMPLES := 18
	const BURY_DEPTH := 0.30
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner_edge := STAIR_RADIUS - STEP_WIDTH * 0.5 - INNER_GUARD_HALF_WIDTH
	var half_width := (OUTER_PARAPET_OUTER_RADIUS - inner_edge) * 0.5
	var foundation_shift := radial * ((OUTER_PARAPET_OUTER_RADIUS + inner_edge) * 0.5 - TREAD_CENTRE_RADIUS)
	far_centre += foundation_shift
	first_centre += foundation_shift
	for sample_index in SAMPLES:
		var t0 := float(sample_index) / float(SAMPLES)
		var t1 := float(sample_index + 1) / float(SAMPLES)
		var centre0 := far_centre.lerp(first_centre, t0)
		var centre1 := far_centre.lerp(first_centre, t1)
		var top_y0 := lerpf(entry_surface_y, first_surface_y, t0) - 0.30
		var top_y1 := lerpf(entry_surface_y, first_surface_y, t1) - 0.30
		var left0 := centre0 - radial * half_width
		var right0 := centre0 + radial * half_width
		var left1 := centre1 - radial * half_width
		var right1 := centre1 + radial * half_width
		var left_top0 := Vector3(left0.x, top_y0, left0.z)
		var right_top0 := Vector3(right0.x, top_y0, right0.z)
		var left_top1 := Vector3(left1.x, top_y1, left1.z)
		var right_top1 := Vector3(right1.x, top_y1, right1.z)
		var left_bottom0 := Vector3(left0.x,
			minf(top_y0 - 0.08, _ground_at(left0.x, left0.z) - BURY_DEPTH), left0.z)
		var right_bottom0 := Vector3(right0.x,
			minf(top_y0 - 0.08, _ground_at(right0.x, right0.z) - BURY_DEPTH), right0.z)
		var left_bottom1 := Vector3(left1.x,
			minf(top_y1 - 0.08, _ground_at(left1.x, left1.z) - BURY_DEPTH), left1.z)
		var right_bottom1 := Vector3(right1.x,
			minf(top_y1 - 0.08, _ground_at(right1.x, right1.z) - BURY_DEPTH), right1.z)
		_add_surface_quad(surface, left_top0, right_top0, right_top1, left_top1)
		_add_surface_quad(surface, left_bottom0, left_top0, left_top1, left_bottom1)
		_add_surface_quad(surface, right_top0, right_bottom0, right_bottom1, right_top1)
		_add_surface_quad(surface, left_bottom0, left_bottom1,
			right_bottom1, right_bottom0)
		if sample_index == 0:
			_add_surface_quad(surface, left_bottom0, right_bottom0,
				right_top0, left_top0)
		if sample_index == SAMPLES - 1:
			_add_surface_quad(surface, left_bottom1, left_top1,
				right_top1, right_bottom1)
	surface.generate_normals()
	var foundation := _add_helix_part(parent, "GroundEntryTerrainFoundation",
		surface.commit(), material, true)
	foundation.set_meta("terrain_fitted", true)
	foundation.set_meta("buried_depth", BURY_DEPTH)
	foundation.set_meta("solid_foundation", true)
	_decorate_ground_entry_foundation(parent, radial, far_centre, first_centre,
		entry_surface_y, first_surface_y, half_width)


# Medieval blind arches and shallow buttresses break up the necessary solid
# retaining wall without reopening a gameplay gap beneath the promenade.
func _decorate_ground_entry_foundation(parent: Node3D, radial: Vector3,
		far_centre: Vector3, first_centre: Vector3,
		entry_surface_y: float, first_surface_y: float,
		half_width: float) -> void:
	var course := _stone(STONE_COURSE)
	for side_sign_value in [-1.0, 1.0]:
		var side_sign: float = side_sign_value
		var side_normal: Vector3 = radial * side_sign
		for buttress_index in 2:
			var t := 0.10 + float(buttress_index) * 0.80
			var path_centre := far_centre.lerp(first_centre, t)
			var side_point: Vector3 = path_centre + side_normal * (half_width + 0.035)
			var top_y := lerpf(entry_surface_y, first_surface_y, t) - 0.26
			var bottom_y := _ground_at(side_point.x, side_point.z) - 0.12
			var height := maxf(0.30, top_y - bottom_y)
			var buttress_position := Vector3(side_point.x,
				bottom_y + height * 0.5, side_point.z)
			var buttress := _oriented_box(parent,
				Vector3(0.38, height, 0.10), buttress_position,
				buttress_position + side_normal, course)
			buttress.name = "GroundEntryFoundationButtress_%s_%02d" % [
				"L" if side_sign < 0.0 else "R", buttress_index]
			_add_box_body(buttress, (buttress.mesh as BoxMesh).size)

		for recess_index in 3:
			var t := (float(recess_index) + 0.5) / 3.0
			var path_centre := far_centre.lerp(first_centre, t)
			var side_point: Vector3 = path_centre + side_normal * (half_width + 0.012)
			var top_y := lerpf(entry_surface_y, first_surface_y, t) - 0.38
			var bottom_y := _ground_at(side_point.x, side_point.z) + 0.12
			var available_height := top_y - bottom_y
			if available_height < 0.72:
				continue
			var recess_height := minf(1.55, available_height - 0.12)
			var recess_centre := Vector3(side_point.x,
				bottom_y + recess_height * 0.5, side_point.z)
			var window_size := recess_height / 2.0
			var window := ReferenceStyle.window(parent, Vector3.ZERO, side_normal, window_size)
			window.global_position = Vector3(recess_centre.x, bottom_y + window_size, recess_centre.z)


# Shallow staggered blocks carry the spiral's restrained blue-grey masonry down
# to the terrain entrance. They sit outside the solid retaining mesh and never
# receive collision, so the promenade remains a single snag-free route.
func _decorate_ground_entry_brick_courses(parent: Node3D, radial: Vector3,
		far_centre: Vector3, first_centre: Vector3,
		entry_surface_y: float, first_surface_y: float) -> void:
	var half_width := TREAD_CLEAR_WIDTH * 0.5 + 0.285
	for side: float in [-1, 1]:
		for index in 2:
			var t := (float(index) + 0.5) / 2.0
			var centre := far_centre.lerp(first_centre, t) + radial * side * half_width
			centre.y = lerpf(entry_surface_y, first_surface_y, t) - 0.45
			if centre.y - 0.25 < _ground_at(centre.x, centre.z):
				continue
			var patch := ReferenceStyle.cluster(parent, Vector3.ZERO, radial * side, 0.8)
			patch.global_position = centre

# One closed, outward-wound wall per side, with a dressed coping surface.
# All faces and the collider come from the same mesh. Vertical end cuts match
# the first spiral cross-section exactly; no tilted-box gaps or wire rails.
func _build_ground_entry_balustrades(parent: Node3D, radial: Vector3,
		far_centre: Vector3, first_centre: Vector3,
		entry_surface_y: float, first_surface_y: float, _material: Material) -> void:
	for side_index in 2:
		var inner := side_index == 0
		var lo := STAIR_RADIUS - STEP_WIDTH * 0.5 - INNER_GUARD_HALF_WIDTH if inner else OUTER_BARRIER_INNER_RADIUS
		var hi := INNER_BARRIER_LANE_FACE_RADIUS if inner else OUTER_PARAPET_OUTER_RADIUS
		var shift := radial * ((lo + hi) * 0.5 - TREAD_CENTRE_RADIUS)
		var from := far_centre + shift
		var to := first_centre + shift
		from.y = entry_surface_y
		to.y = first_surface_y
		var end_height := 1.28 - 0.17 if inner else OUTER_BARRIER_TOP_OFFSET - 0.17
		var mesh := _entry_wall_mesh(from, to, radial, hi - lo, 1.15, end_height)
		var wall := MeshInstance3D.new()
		wall.name = "GroundEntry%sBarrier" % ("Inner" if inner else "Outer")
		wall.top_level = true
		parent.add_child(wall)
		wall.mesh = mesh
		wall.set_meta("preserve_castle_finish", true)
		wall.set_meta("continuous_solid_ground_to_spiral_guard", true)
		wall.set_meta("lane_face_radius", hi if inner else lo)
		var body := StaticBody3D.new()
		wall.add_child(body)
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		for t: float in [0.25, 0.68]:
			var normal := -radial if inner else radial
			var face := far_centre.lerp(first_centre, t) + radial * ((lo if inner else hi) - TREAD_CENTRE_RADIUS)
			face.y = lerpf(entry_surface_y, first_surface_y, t) + 0.40
			var patch := ReferenceStyle.cluster(parent, Vector3.ZERO, normal, 0.65)
			patch.global_position = face + normal * 0.006


func _entry_wall_mesh(from: Vector3, to: Vector3, radial: Vector3,
		width: float, start_height: float, end_height: float) -> ArrayMesh:
	var corners: Array[Vector3] = [from - radial * width * 0.5, from + radial * width * 0.5,
		to + radial * width * 0.5, to - radial * width * 0.5]
	var bottom: Array[Vector3] = []
	var split: Array[Vector3] = []
	var top: Array[Vector3] = []
	for i in 4:
		var h := start_height if i < 2 else end_height
		bottom.append(corners[i] - Vector3.UP * 0.32)
		split.append(corners[i] + Vector3.UP * (h - 0.18))
		top.append(corners[i] + Vector3.UP * h)
	var masonry := SurfaceTool.new()
	masonry.begin(Mesh.PRIMITIVE_TRIANGLES)
	masonry.set_material(ReferenceStyle.material("wall"))
	var coping := SurfaceTool.new()
	coping.begin(Mesh.PRIMITIVE_TRIANGLES)
	coping.set_material(ReferenceStyle.material("trim"))
	for i in 4:
		var j := (i + 1) % 4
		_add_surface_quad(masonry, bottom[i], bottom[j], split[j], split[i])
		_add_surface_quad(coping, split[i], split[j], top[j], top[i])
	_add_surface_quad(masonry, bottom[3], bottom[2], bottom[1], bottom[0])
	_add_surface_quad(coping, top[0], top[1], top[2], top[3])
	masonry.generate_normals()
	coping.generate_normals()
	var mesh := masonry.commit()
	coping.commit(mesh)
	return mesh


# The old safety rail was one box per tread. Even with overlap, more than a
# hundred differently rotated boxes read as broken, stacked slats in every
# exterior view. These four watertight helical ribbons give the stair a single
# architectural silhouette while the individual treads retain the satisfying
# footfall and step rhythm.
func _build_continuous_ascent(parent: Node3D, base: Vector2, ground: float,
		top_y: float, start_angle: float, dark: Material, light: Material) -> void:
	var inner_edge := STAIR_RADIUS - STEP_WIDTH * 0.5
	var outer_edge := STAIR_RADIUS + STEP_WIDTH * 0.5

	# One continuous walking surface sits 2 cm beneath the visible tread tops.
	# The old collision used a separate rotated box for every
	# tread. Near the inside of the curve, a later box overlaps the preceding
	# one far enough for its leading side to become a diagonal wall; the player
	# could stand on the stair but could not advance (most visibly on the final
	# flight below the crown). A single helix has no transverse box edges to snag
	# the capsule, while the individual meshes preserve the stepped look.
	# The architectural roadbed is also the finished stone soffit seen from below.
	# It reaches beyond every visible riser and sits beneath their -0.60 m bottom,
	# hiding the layered tread geometry behind one clean medieval surface. Its
	# boundary faces remain visual-only; the separate top sheet owns collision.
	# Both radial faces are buried well inside adjacent masonry. The former
	# 3-6 cm contact left each lit vertical face exposed as a white crescent when
	# viewed from below. Real stone newel stairs read as one mass: the soffit
	# disappears into the inner newel/plinth and the outer enclosing wall.
	const INNER_SOFFIT_MASONRY_OVERLAP := 0.18
	const OUTER_SOFFIT_MASONRY_OVERLAP := OUTER_PARAPET_WIDTH
	var roadbed_inner_radius := TREAD_INNER_RADIUS - 0.06
	var roadbed_outer_radius := OUTER_BARRIER_INNER_RADIUS \
		+ OUTER_SOFFIT_MASONRY_OVERLAP
	var roadbed := _helix_band_mesh(base, ground, top_y, start_angle,
		roadbed_inner_radius, roadbed_outer_radius,
		-0.74, -0.12, 1.0, GUARD_ENTRY_LEAD_T, false, false)
	var roadbed_part := _add_helix_part(parent, "AscentRoadbed",
		roadbed, dark, false)
	roadbed_part.set_meta("finished_stone_soffit", true)
	roadbed_part.set_meta("covers_riser_bottoms", true)
	roadbed_part.set_meta("soffit_bottom_offset", -0.74)
	roadbed_part.set_meta("outer_masonry_overlap", OUTER_SOFFIT_MASONRY_OVERLAP)
	roadbed_part.set_meta("radial_faces_buried_and_omitted", true)
	roadbed_part.set_meta("shared_outer_soffit_edge", true)
	var walk_surface := _helix_walk_surface_mesh(base, ground, top_y, start_angle,
		TREAD_INNER_RADIUS, TREAD_OUTER_RADIUS, 0.15)
	var walk_surface_part := _add_helix_part(parent, "AscentWalkSurface",
		walk_surface, dark, true)
	walk_surface_part.visible = false
	walk_surface_part.set_meta("collision_only", true)

	var outer_guard := _helix_band_mesh(base, ground, top_y, start_angle,
		OUTER_BARRIER_INNER_RADIUS,
		outer_edge + OUTER_GUARD_HALF_WIDTH, -0.62,
		OUTER_BARRIER_TOP_OFFSET, 1.0,
		GUARD_ENTRY_LEAD_T)
	var outer_guard_part := _add_helix_part(parent, "OuterContinuousGuard",
		outer_guard, light, true)
	outer_guard_part.set_meta("bottom_offset", -0.62)
	outer_guard_part.set_meta("collision_only", true)
	outer_guard_part.visible = false
	var outer_parapet := _helix_band_mesh(base, ground, top_y, start_angle,
		OUTER_BARRIER_INNER_RADIUS,
		OUTER_PARAPET_OUTER_RADIUS, -0.74, OUTER_BARRIER_TOP_OFFSET, 1.0,
		GUARD_ENTRY_LEAD_T, true, true, false, false)
	var outer_parapet_part := _add_helix_part(parent, "OuterStoneParapet",
		outer_parapet, dark, false)
	outer_parapet_part.set_meta("castle_palette_role", "shadow_stone_parapet")
	outer_parapet_part.set_meta("full_height_closed_barrier", true)
	outer_parapet_part.set_meta("covers_tread_edges", true)
	outer_parapet_part.set_meta("tread_overlap", OUTER_BARRIER_TREAD_OVERLAP)
	# The soffit now owns the entire underside. Matching edge samples and no
	# second bottom face eliminate the bright, overlapping crescent below it.
	outer_parapet_part.set_meta("underside_owned_by_soffit", true)
	outer_parapet_part.set_meta("top_owned_by_coping", true)
	_build_outer_parapet_masonry(parent, base, ground, top_y, start_angle,
		OUTER_PARAPET_OUTER_RADIUS)

	var inner_guard := _helix_band_mesh(base, ground, top_y, start_angle,
		inner_edge - INNER_GUARD_HALF_WIDTH,
		inner_edge + INNER_GUARD_HALF_WIDTH, 0.06, 1.28, 1.0,
		GUARD_ENTRY_LEAD_T)
	var inner_guard_part := _add_helix_part(parent, "InnerContinuousGuard",
		inner_guard, dark, true)
	inner_guard_part.set_meta("collision_only", true)
	inner_guard_part.visible = false
	var inner_parapet := _helix_band_mesh(base, ground, top_y, start_angle,
		inner_edge - INNER_GUARD_HALF_WIDTH,
		inner_edge + INNER_GUARD_HALF_WIDTH, -0.10, 1.28, 1.0,
		GUARD_ENTRY_LEAD_T, true, true, true, false)
	var inner_parapet_part := _add_helix_part(parent, "InnerStoneParapet",
		inner_parapet, dark, false)
	inner_parapet_part.set_meta("castle_palette_role", "shadow_stone_parapet")
	inner_parapet_part.set_meta("full_height_closed_barrier", true)
	inner_parapet_part.set_meta("covers_tread_edges", true)
	inner_parapet_part.set_meta("top_owned_by_coping", true)
	_build_inner_parapet_masonry(parent, base, ground, top_y, start_angle,
		inner_edge - INNER_GUARD_HALF_WIDTH)
	# Finish the stair-facing foot of the inner parapet with one restrained
	# projecting stone course. It meets the shortened tread ends cleanly and
	# hides the construction seam without becoming a collision ridge.
	var inner_skirting := _helix_band_mesh(base, ground, top_y, start_angle,
		INNER_BARRIER_LANE_FACE_RADIUS + 0.02,
		VISIBLE_TREAD_INNER_RADIUS + 0.01, -0.08, 0.20, 1.0,
		GUARD_ENTRY_LEAD_T)
	var inner_skirting_part := _add_helix_part(parent,
		"InnerParapetLaneSkirting", inner_skirting,
		_stone(STONE_COURSE), false)
	inner_skirting_part.set_meta("visual_only", true)
	inner_skirting_part.set_meta("closes_visible_tread_seam", true)

	# Both guard rails are closed, boxy collision volumes (top + bottom + inner +
	# outer faces) — the same cross-section AscentRoadbed used before
	# AscentWalkSurface was split out. A capsule that ends up on top of a guard
	# (jumping the rail is exactly the scenario InnerSafetyPlinth exists to
	# survive) catches on the internal edges between that box's own faces when
	# it tries to walk, and simply freezes. diag_stair_rail_stand.gd reproduces
	# this on plain, otherwise-unmodified guard geometry (t=0.10, nowhere near
	# the crown or the pillar), so this is pre-existing and not caused by any of
	# the crown/pillar work above. The guard boxes themselves must stay
	# collision-backed — they are the wall stopping a player on the walkway from
	# passing through to the drop beyond — but a separate single-face top sheet,
	# floating a small gap above each guard's cap the way AscentWalkSurface
	# floats above AscentRoadbed, gives a player who lands up there a smooth
	# surface with no internal seam to snag on.
	#
	# Standing on either walk surface puts a player roughly 1.3-1.5 m higher
	# than a tread walker, but _build_crown only guarantees STAIR_HEADROOM above
	# tread height when it cuts CrownDeck's stairwell opening — so unclamped,
	# the same diagnostic caught a player pinned between this surface and
	# CrownDeck's underside around t=0.9, well before reaching the crown.
	# Clamping to the same headroom below the crown floor's underside makes the
	# surface duck down as it approaches the crown, preserving that clearance
	# for the taller stance instead of assuming tread-height is all that matters.
	var crown_floor_underside := top_y + CROWN_SURFACE_OFFSET - CROWN_SLAB_HEIGHT
	var guard_walk_ceiling := crown_floor_underside - STAIR_HEADROOM
	var outer_guard_walk_surface := _helix_walk_surface_mesh(base, ground, top_y,
		start_angle, outer_edge - OUTER_GUARD_HALF_WIDTH,
		outer_edge + OUTER_GUARD_HALF_WIDTH, 1.60, guard_walk_ceiling)
	var outer_guard_walk_part := _add_helix_part(parent, "OuterGuardWalkSurface",
		outer_guard_walk_surface, brass, true)
	outer_guard_walk_part.visible = false
	outer_guard_walk_part.set_meta("collision_only", true)

	var inner_guard_walk_surface := _helix_walk_surface_mesh(base, ground, top_y,
		start_angle, inner_edge - INNER_GUARD_HALF_WIDTH,
		inner_edge + INNER_GUARD_HALF_WIDTH, 1.47, guard_walk_ceiling)
	var inner_guard_walk_part := _add_helix_part(parent, "InnerGuardWalkSurface",
		inner_guard_walk_surface, brass, true)
	inner_guard_walk_part.visible = false
	inner_guard_walk_part.set_meta("collision_only", true)

	# Close the narrow service slot behind the inner guard. The tower collider is
	# deliberately only 3.0 m wide while the guard begins around radius 4.38 m;
	# at the circular entry apron that left a player-sized pocket behind the
	# rail. A jump over the rail could put the capsule between both walls with
	# too little room to turn or climb back out. This raised, collision-backed
	# plinth follows the same helix beneath the cap, turning that slot into solid
	# architecture and giving any over-jumping player a broad surface from which
	# they can step or jump safely back onto the stair.
	var inner_plinth_outer_radius := roadbed_inner_radius \
		+ INNER_SOFFIT_MASONRY_OVERLAP
	var inner_plinth := _helix_band_mesh(base, ground, top_y, start_angle,
		TOWER_TOP_RADIUS - 0.05, inner_plinth_outer_radius, -0.78, 1.05, 1.0,
		GUARD_ENTRY_LEAD_T)
	var inner_plinth_part := _add_helix_part(parent, "InnerSafetyPlinth",
		inner_plinth, dark, false)
	inner_plinth_part.set_meta("integrated_stone_newel_mass", true)
	inner_plinth_part.set_meta("soffit_overlap", INNER_SOFFIT_MASONRY_OVERLAP)
	# Preserve the narrower, previously proven safety volume. The dressed stone
	# can overlap the soffit visually, but collision must not follow that overlap
	# into the inside walking lane at the crown.
	var inner_plinth_collision_mesh := _helix_band_mesh(base, ground, top_y,
		start_angle, TOWER_TOP_RADIUS - 0.05, inner_edge + 0.02,
		-0.05, 1.05, 0.96, GUARD_ENTRY_LEAD_T)
	var inner_plinth_body := StaticBody3D.new()
	inner_plinth_body.name = "InnerSafetyPlinthBody"
	inner_plinth_part.add_child(inner_plinth_body)
	var inner_plinth_shape := CollisionShape3D.new()
	inner_plinth_shape.name = "InnerSafetyPlinthShape"
	inner_plinth_shape.shape = inner_plinth_collision_mesh.create_trimesh_shape()
	inner_plinth_body.add_child(inner_plinth_shape)

	var entry_foundation_mesh := _terrain_fitted_entry_foundation_mesh(base,
		ground, top_y, start_angle, TOWER_BOTTOM_RADIUS - 0.05,
		OUTER_PARAPET_OUTER_RADIUS)
	var entry_foundation := _add_helix_part(parent,
		"TerrainFittedEntryFoundation", entry_foundation_mesh, light, true)
	entry_foundation.set_meta("terrain_fitted", true)
	entry_foundation.set_meta("foundation_end_t", ENTRY_FOUNDATION_END_T)
	_build_foundation_toe(parent, base, ground, top_y, start_angle)

	_build_medieval_stair_details(parent, base, ground, top_y, start_angle,
		OUTER_PARAPET_OUTER_RADIUS)


# Sparse raised patches repeat the original castle tower's stone language.
# The whole facing remains outside the solid guard and is visual-only.
func _build_outer_parapet_masonry(parent: Node3D, base: Vector2,
		ground: float, top_y: float, start_angle: float,
		outer_face_radius: float) -> void:
	var masonry := Node3D.new()
	masonry.name = "OuterParapetMasonry"
	masonry.set_meta("visual_only", true)
	masonry.set_meta("style", "reference_tower_sparse_masonry")
	masonry.set_meta("preserve_castle_finish", true)
	parent.add_child(masonry)
	# Retain the solid continuous shell, with occasional raised stone patches.
	# These replace (rather than overlay) the former 440-brick wallpaper.
	for index in 26:
		var t := (float(index) + 0.5) / 26.0
		var angle := start_angle + t * TAU * TURNS
		var radial := Vector3(cos(angle), 0, sin(angle))
		var at := Vector3(base.x, lerpf(ground, top_y, t) + 0.34, base.y) \
			+ radial * (outer_face_radius + 0.006)
		var patch := ReferenceStyle.cluster(masonry, Vector3.ZERO, radial, 1.15)
		patch.global_position = at

	# One slightly projecting coping course gives the brick wall a finished top.
	var coping_mesh := _helix_band_mesh(base, ground, top_y, start_angle,
		OUTER_BARRIER_INNER_RADIUS, outer_face_radius + 0.035,
		1.50, OUTER_BARRIER_TOP_OFFSET, 1.0, GUARD_ENTRY_LEAD_T, false, true, true, true, false)
	var coping := _add_helix_part(masonry, "OuterParapetBrickCoping",
		coping_mesh, ReferenceStyle.material("trim"), false)
	coping.set_meta("visual_only", true)


# The player sees the inner wall for the entire climb, so it receives the same
# restrained bond as the exterior at a smaller scale. A plain inner ribbon next
# to a detailed outer facade made the stair look only half modelled.
func _build_inner_parapet_masonry(parent: Node3D, base: Vector2,
		ground: float, top_y: float, start_angle: float,
		inner_face_radius: float) -> void:
	var masonry := Node3D.new()
	masonry.name = "InnerParapetMasonry"
	masonry.set_meta("visual_only", true)
	masonry.set_meta("style", "reference_tower_sparse_masonry")
	masonry.set_meta("preserve_castle_finish", true)
	parent.add_child(masonry)
	for index in 22:
		var t := (float(index) + 0.5) / 22.0
		var angle := start_angle + t * TAU * TURNS
		var radial := Vector3(cos(angle), 0, sin(angle))
		var patch := ReferenceStyle.cluster(masonry, Vector3.ZERO, -radial, 0.7)
		patch.global_position = Vector3(base.x, lerpf(ground, top_y, t) + 0.52, base.y) \
			+ radial * (inner_face_radius - 0.004)
	var coping_mesh := _helix_band_mesh(base, ground, top_y, start_angle,
		inner_face_radius - 0.025, INNER_BARRIER_LANE_FACE_RADIUS,
		1.04, 1.28, 1.0, GUARD_ENTRY_LEAD_T, true, false, true, true, false)
	var coping := _add_helix_part(masonry, "InnerParapetBrickCoping",
		coping_mesh, ReferenceStyle.material("trim"), false)
	coping.set_meta("visual_only", true)


func _terrain_fitted_entry_foundation_mesh(base: Vector2, ground: float,
		top_y: float, start_angle: float, inner_radius: float,
		outer_radius: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SAMPLES := 40
	for sample_index in SAMPLES:
		var t0 := lerpf(GUARD_ENTRY_LEAD_T, ENTRY_FOUNDATION_END_T,
			float(sample_index) / float(SAMPLES))
		var t1 := lerpf(GUARD_ENTRY_LEAD_T, ENTRY_FOUNDATION_END_T,
			float(sample_index + 1) / float(SAMPLES))
		var corners0 := _terrain_foundation_cross_section(base, ground, top_y,
			start_angle, inner_radius, outer_radius, t0)
		var corners1 := _terrain_foundation_cross_section(base, ground, top_y,
			start_angle, inner_radius, outer_radius, t1)
		var i0t: Vector3 = corners0[0]
		var o0t: Vector3 = corners0[1]
		var i0b: Vector3 = corners0[2]
		var o0b: Vector3 = corners0[3]
		var i1t: Vector3 = corners1[0]
		var o1t: Vector3 = corners1[1]
		var i1b: Vector3 = corners1[2]
		var o1b: Vector3 = corners1[3]
		# Same corrected winding as _helix_band_mesh (see diag_helix_winding.gd) —
		# this function was independently authored with the same original
		# (wrong) vertex order, which put the foundation's own top-facing
		# surface pointing down at the base of the stairs.
		_add_surface_quad(surface, o0t, o1t, i1t, i0t)
		_add_surface_quad(surface, i0b, i1b, o1b, o0b)
		_add_surface_quad(surface, o1b, o1t, o0t, o0b)
		_add_surface_quad(surface, i0t, i1t, i1b, i0b)
		if sample_index == 0:
			_add_surface_quad(surface, o0b, o0t, i0t, i0b)
		if sample_index == SAMPLES - 1:
			_add_surface_quad(surface, i1t, o1t, o1b, i1b)
	surface.generate_normals()
	var result := surface.commit()
	result.set_meta("legacy_inward_helix_winding", true)
	return result


func _terrain_foundation_cross_section(base: Vector2, ground: float,
		top_y: float, start_angle: float, inner_radius: float,
		outer_radius: float, t: float) -> Array[Vector3]:
	var clamped_t := maxf(t, 0.0)
	var angle := start_angle + t * TAU * TURNS
	var inner_xz := Vector2(base.x + cos(angle) * inner_radius,
		base.y + sin(angle) * inner_radius)
	var outer_xz := Vector2(base.x + cos(angle) * outer_radius,
		base.y + sin(angle) * outer_radius)
	var stair_underside := lerpf(ground + FIRST_TREAD_CENTRE_OFFSET,
		top_y, clamped_t) - 0.74
	# Each edge follows its own local Terrain3D sample and is buried enough to
	# survive interpolation between sections. A single global lowest point made
	# the opposite end stretch into the long triangular spike in the screenshot.
	var bottom_inner_xz := base + Vector2(cos(angle), sin(angle)) * (inner_radius - 0.10)
	var bottom_outer_xz := base + Vector2(cos(angle), sin(angle)) * (outer_radius + 0.18)
	var inner_bottom := _ground_at(bottom_inner_xz.x, bottom_inner_xz.y) - 0.32
	var outer_bottom := _ground_at(bottom_outer_xz.x, bottom_outer_xz.y) - 0.32
	# The buried start can sit above the mathematical stair underside on a steep
	# patch. Collapse that cross-section into the ground instead of inverting it.
	var inner_top := maxf(stair_underside, inner_bottom + 0.03)
	var outer_top := maxf(stair_underside, outer_bottom + 0.03)
	return [
		Vector3(inner_xz.x, inner_top, inner_xz.y),
		Vector3(outer_xz.x, outer_top, outer_xz.y),
		Vector3(bottom_inner_xz.x, inner_bottom, bottom_inner_xz.y),
		Vector3(bottom_outer_xz.x, outer_bottom, bottom_outer_xz.y),
	]


# A grounded dressed toe gives the retaining wall a substantial lower edge,
# instead of a knife-thin curtain terminating in the grass. It stays outboard
# of the guard and cannot form a ridge in the player's walking lane.
func _build_foundation_toe(parent: Node3D, base: Vector2, _ground: float,
		_top_y: float, start_angle: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 40:
		var rings: Array = []
		for j in 2:
			var t := ENTRY_FOUNDATION_END_T * float(i + j) / 40.0
			var angle := start_angle + t * TAU * TURNS
			var points: Array[Vector3] = []
			for r: float in [OUTER_PARAPET_OUTER_RADIUS - 0.04, OUTER_PARAPET_OUTER_RADIUS + 0.24]:
				var xz := base + Vector2(cos(angle), sin(angle)) * r
				var y := _ground_at(xz.x, xz.y)
				points.append(Vector3(xz.x, y - 0.34, xz.y))
				points.append(Vector3(xz.x, y + 0.14, xz.y))
			rings.append(points)
		var a: Array = rings[0]
		var b: Array = rings[1]
		_add_surface_quad(surface, a[1], a[3], b[3], b[1])
		_add_surface_quad(surface, a[0], b[0], b[2], a[2])
		_add_surface_quad(surface, a[2], b[2], b[3], a[3])
		_add_surface_quad(surface, a[0], a[1], b[1], b[0])
		if i == 0:
			_add_surface_quad(surface, a[0], a[2], a[3], a[1])
		if i == 39:
			_add_surface_quad(surface, b[0], b[1], b[3], b[2])
	surface.generate_normals()
	var toe := _add_helix_part(parent, "GroundedFoundationToeCourse", surface.commit(), ReferenceStyle.material("trim"), true)
	toe.set_meta("preserve_castle_finish", true)


# Visual-only medieval dressing replaces the unrelated green fibre stripes.
# Repeated newels and red caps give the long curve a readable castle rhythm.
# The former underside corbels were removed because their ends projected below
# the soffit as a row of exposed rectangular teeth. The continuous stone body
# now remains uninterrupted from every low camera angle.
func _build_medieval_stair_details(parent: Node3D, base: Vector2, ground: float,
		top_y: float, start_angle: float, outer_edge: float) -> void:
	var details := Node3D.new()
	details.name = "MedievalStairDetails"
	details.set_meta("render_family", "red_village_hexagons_castle")
	details.set_meta("collision_policy", "solid_keep_details_outside_continuous_guard_lane")
	details.set_meta("preserve_castle_finish", true)
	parent.add_child(details)
	# Fewer, substantial piers replace the thin floating needle posts. Leave the
	# last approach to the crown clear of roofs beneath its overhanging slab.
	const DETAIL_COUNT := 12
	for detail_index in DETAIL_COUNT:
		var t := lerpf(0.015, 0.88, float(detail_index) / float(DETAIL_COUNT - 1))
		var angle := start_angle + t * TAU * TURNS
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := Vector3(radial.z, 0.0, -radial.x)
		var stair_y := lerpf(ground + FIRST_TREAD_CENTRE_OFFSET, top_y, t)
		var pier := Node3D.new()
		pier.name = "KeepStairPier_%02d" % detail_index
		details.add_child(pier)
		pier.global_position = Vector3(base.x, stair_y, base.y) + radial * (outer_edge - 0.31)
		pier.basis = Basis(tangent, Vector3.UP, radial)
		pier.set_meta("stair_progress", t)
		var newel := ReferenceStyle.box(pier, "OuterStoneNewel_%02d" % detail_index,
			Vector3(0.66, 1.60, 0.66), Vector3(0, 1.50, 0), "wall")
		newel.name = "OuterStoneNewel_%02d" % detail_index
		_add_box_body(newel, (newel.mesh as BoxMesh).size)
		newel.set_meta("visual_only", false)
		var capital := ReferenceStyle.box(pier, "KeepPierCapital", Vector3(0.74, 0.20, 0.74),
			Vector3(0, 2.24, 0), "trim")
		_add_box_body(capital, (capital.mesh as BoxMesh).size)
		capital.set_meta("visual_only", false)
		ReferenceStyle.window(pier, Vector3(0, 1.94, 0.335), Vector3.BACK, 0.23)
		var roof := MeshInstance3D.new()
		roof.name = "NewelRedRoof_%02d" % detail_index
		var roof_mesh := CylinderMesh.new()
		roof_mesh.top_radius = 0.0
		roof_mesh.bottom_radius = 0.53
		roof_mesh.height = 0.70
		roof_mesh.radial_segments = 4
		roof.mesh = roof_mesh
		roof.material_override = ReferenceStyle.material("roof")
		pier.add_child(roof)
		roof.position = Vector3(0, 2.69, 0)
		roof.rotation.y = PI * 0.25
		var roof_body := StaticBody3D.new()
		roof.add_child(roof_body)
		var roof_shape := CollisionShape3D.new()
		roof_shape.shape = roof_mesh.create_convex_shape()
		roof_body.add_child(roof_shape)
		# Low, solid crenels sit on the continuous guard: no gaps are cut into
		# the safety wall and no foothold is introduced at tread height.
		if detail_index == DETAIL_COUNT - 1:
			continue
		for fraction: float in [0.36, 0.72]:
			var mt := t + (0.88 - 0.015) / float(DETAIL_COUNT - 1) * fraction
			var ma := start_angle + mt * TAU * TURNS
			var mr := Vector3(cos(ma), 0, sin(ma))
			var merlon := ReferenceStyle.box(details, "KeepSpiralMerlon_%02d_%d" % [detail_index, int(fraction * 100)],
				Vector3(0.94, 0.64, 0.56), Vector3.ZERO, "wall")
			merlon.global_position = Vector3(base.x, lerpf(ground + FIRST_TREAD_CENTRE_OFFSET, top_y, mt) + 1.89, base.y) \
				+ mr * ((OUTER_BARRIER_INNER_RADIUS + outer_edge) * 0.5)
			merlon.basis = Basis(Vector3(mr.z, 0, -mr.x), Vector3.UP, mr)
			merlon.set_meta("stair_progress", mt)
			merlon.set_meta("visual_only", false)
			_add_box_body(merlon, (merlon.mesh as BoxMesh).size)

func _helix_band_mesh(base: Vector2, ground: float, top_y: float,
		start_angle: float, inner_radius: float, outer_radius: float,
		bottom_offset: float, top_offset: float, end_t: float = 1.0,
		start_t: float = 0.0, include_inner_face: bool = true,
		include_outer_face: bool = true, include_bottom_face: bool = true,
		include_top_face: bool = true, include_end_faces: bool = true) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Twice the tread count keeps the long parapet curve visually round while
	# retaining the deliberately low-poly castle character in its masonry detail.
	var samples := maxi(_step_count * 2, 96)
	for i in samples:
		var t0 := lerpf(start_t, end_t, float(i) / float(samples))
		var t1 := lerpf(start_t, end_t, float(i + 1) / float(samples))
		var a0 := start_angle + t0 * TAU * TURNS
		var a1 := start_angle + t1 * TAU * TURNS
		var y0 := lerpf(ground + FIRST_TREAD_CENTRE_OFFSET, top_y, maxf(t0, 0.0))
		var y1 := lerpf(ground + FIRST_TREAD_CENTRE_OFFSET, top_y, maxf(t1, 0.0))
		# Clamping both faces to a shared ceiling (rather than just the top)
		# lets a band run all the way to t=1 without its top face poking through
		# solid geometry above it (e.g. the crown floor): once y0/y1 + the
		# offsets would exceed the ceiling, the band flattens toward zero height
		# instead of inverting.
		var bottom0 := minf(y0 + bottom_offset, ceiling_y)
		var top0 := minf(y0 + top_offset, ceiling_y)
		var bottom1 := minf(y1 + bottom_offset, ceiling_y)
		var top1 := minf(y1 + top_offset, ceiling_y)

		var i0b := Vector3(base.x + cos(a0) * inner_radius,
			bottom0, base.y + sin(a0) * inner_radius)
		var i0t := Vector3(i0b.x, top0, i0b.z)
		var o0b := Vector3(base.x + cos(a0) * outer_radius,
			bottom0, base.y + sin(a0) * outer_radius)
		var o0t := Vector3(o0b.x, top0, o0b.z)
		var i1b := Vector3(base.x + cos(a1) * inner_radius,
			bottom1, base.y + sin(a1) * inner_radius)
		var i1t := Vector3(i1b.x, top1, i1b.z)
		var o1b := Vector3(base.x + cos(a1) * outer_radius,
			bottom1, base.y + sin(a1) * outer_radius)
		var o1t := Vector3(o1b.x, top1, o1b.z)

		if include_top_face:
			_add_surface_quad(surface, i0t, i1t, o1t, o0t) # top
		if include_bottom_face:
			_add_surface_quad(surface, i0b, o0b, o1b, i1b) # underside
		if include_outer_face:
			_add_surface_quad(surface, o0b, o0t, o1t, o1b) # outer face
		if include_inner_face:
			_add_surface_quad(surface, i0b, i1b, i1t, i0t) # inner face

		if include_end_faces and i == 0:
			_add_surface_quad(surface, i0b, i0t, o0t, o0b)
		if include_end_faces and i == samples - 1:
			_add_surface_quad(surface, i1b, o1b, o1t, i1t)

	surface.generate_normals()
	var result := surface.commit()
	result.set_meta("legacy_inward_helix_winding", true)
	return result


# Collision-only top sheet for the spiral. It deliberately has no vertical
# boundary or end faces: the continuous guards contain the player, and omitting
# those faces prevents the capsule from snagging on a segmented curve.
func _helix_walk_surface_mesh(base: Vector2, ground: float, top_y: float,
		start_angle: float, inner_radius: float, outer_radius: float,
		top_offset: float, ceiling_y: float = INF) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples := maxi(_step_count, 48)
	for i in samples:
		var t0 := float(i) / float(samples)
		var t1 := float(i + 1) / float(samples)
		var a0 := start_angle + t0 * TAU * TURNS
		var a1 := start_angle + t1 * TAU * TURNS
		# Clamped to a ceiling for surfaces that stand a player well above tread
		# height (see the guard-rail walk surfaces in _build_continuous_ascent):
		# the crown floor's cutout only guarantees STAIR_HEADROOM above the
		# *tread*, so a taller standing height needs its own surface to duck
		# down and preserve that same clearance as it nears the crown.
		var y0 := minf(lerpf(ground + FIRST_TREAD_CENTRE_OFFSET, top_y, t0) + top_offset, ceiling_y)
		var y1 := minf(lerpf(ground + FIRST_TREAD_CENTRE_OFFSET, top_y, t1) + top_offset, ceiling_y)
		var i0 := Vector3(base.x + cos(a0) * inner_radius, y0,
			base.y + sin(a0) * inner_radius)
		var o0 := Vector3(base.x + cos(a0) * outer_radius, y0,
			base.y + sin(a0) * outer_radius)
		var i1 := Vector3(base.x + cos(a1) * inner_radius, y1,
			base.y + sin(a1) * inner_radius)
		var o1 := Vector3(base.x + cos(a1) * outer_radius, y1,
			base.y + sin(a1) * outer_radius)
		# Godot treats clockwise vertices as the front face. This order makes the
		# walk surface collide from above; the reverse order is only a back face
		# and lets the character fall through.
		_add_surface_quad(surface, o0, o1, i1, i0)
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


func _tapered_landing_mesh(length: float, outer_width: float,
		inner_width: float, height: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_length := length * 0.5
	var half_height := height * 0.5
	# Local +X points toward the spiral's outer edge after look_at(); local Z is
	# the walking direction. Wider outer corners overlap the final tread, while
	# the narrow inner pair disappear cleanly into the crown floor.
	var outer_left := Vector3(half_length, half_height, -outer_width * 0.5)
	var outer_right := Vector3(half_length, half_height, outer_width * 0.5)
	var inner_left := Vector3(-half_length, half_height, -inner_width * 0.5)
	var inner_right := Vector3(-half_length, half_height, inner_width * 0.5)
	var outer_left_bottom := Vector3(outer_left.x, -half_height, outer_left.z)
	var outer_right_bottom := Vector3(outer_right.x, -half_height, outer_right.z)
	var inner_left_bottom := Vector3(inner_left.x, -half_height, inner_left.z)
	var inner_right_bottom := Vector3(inner_right.x, -half_height, inner_right.z)
	# Verified empirically (diag_crown_disc_winding.gd): all six faces of this
	# mesh were backwards — every one of them tested opposite to its intended
	# direction (top pointed down, the two ends and two sides all pointed
	# inward instead of outward). Each call below is simply the reverse of the
	# original argument order, which flips every face at once.
	_add_surface_quad(surface, outer_right, inner_right, inner_left, outer_left)
	_add_surface_quad(surface, inner_left_bottom, inner_right_bottom,
		outer_right_bottom, outer_left_bottom)
	_add_surface_quad(surface, outer_left, inner_left,
		inner_left_bottom, outer_left_bottom)
	_add_surface_quad(surface, outer_right_bottom, inner_right_bottom,
		inner_right, outer_right)
	_add_surface_quad(surface, outer_right_bottom, outer_right,
		outer_left, outer_left_bottom)
	_add_surface_quad(surface, inner_right, inner_right_bottom,
		inner_left_bottom, inner_left)
	surface.generate_normals()
	return surface.commit() as ArrayMesh


func _add_helix_part(parent: Node3D, part_name: String, mesh: ArrayMesh,
		material: Material, collision: bool) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	# Vertices are authored in world space to match the measured castle and
	# terrain anchors. The containing rig is offset for legacy scene reasons, so
	# inherit no transform here or the ribbon is displaced a second time.
	part.top_level = true
	# The legacy band winding points into the solid. Correct the outer guard
	# too: inward collision faces can trap a capsule during a sideways reversal.
	# The separate upward-wound walking sheet is not a band and stays unchanged.
	if mesh.get_meta("legacy_inward_helix_winding", false) and (not collision \
			or part_name in ["OuterContinuousGuard", "TerrainFittedEntryFoundation"]):
		var arrays := mesh.surface_get_arrays(0)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in normals.size():
			normals[index] = -normals[index]
		arrays[Mesh.ARRAY_NORMAL] = normals
		var indices := PackedInt32Array()
		for index in range(0, (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 3):
			indices.append_array(PackedInt32Array([index, index + 2, index + 1]))
		arrays[Mesh.ARRAY_INDEX] = indices
		var outward := ArrayMesh.new()
		outward.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		outward.set_meta("outward_visual_helix", true)
		mesh = outward
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


# Finished facade language for the tower: octagonal buttresses, pale masonry
# courses and rounded recessed windows repeat the nearby castle towers. Everything
# here is shallow and visual-only, leaving the central shaft collider authoritative.
func _build_tower_facade(parent: Node3D, base: Vector2,
		ground: float, top_y: float) -> void:
	var facade_height := top_y - ground

	# One solid, battered octagonal plinth replaces eight exposed block props.
	# Its terrain-fitted feet are buried; its upper edge seats in the first belt.
	var plinth_surface := SurfaceTool.new()
	plinth_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plinth_top := ground + 2.10
	for side in TOWER_SIDES:
		var a := TAU * float(side) / TOWER_SIDES
		var b := TAU * float(side + 1) / TOWER_SIDES
		var at := Vector3(base.x + cos(a) * 4.04, plinth_top, base.y + sin(a) * 4.04)
		var bt := Vector3(base.x + cos(b) * 4.04, plinth_top, base.y + sin(b) * 4.04)
		var ab := Vector3(base.x + cos(a) * 4.20, 0, base.y + sin(a) * 4.20)
		var bb := Vector3(base.x + cos(b) * 4.20, 0, base.y + sin(b) * 4.20)
		ab.y = minf(plinth_top - 0.30, _ground_at(ab.x, ab.z) - 0.35)
		bb.y = minf(plinth_top - 0.30, _ground_at(bb.x, bb.z) - 0.35)
		_add_surface_quad(plinth_surface, ab, bb, bt, at)
		var centre_top := Vector3(base.x, plinth_top, base.y)
		var centre_bottom := Vector3(base.x, ground - 6.0, base.y)
		for p: Vector3 in [centre_top, at, bt, centre_bottom, bb, ab]:
			plinth_surface.add_vertex(p)
	plinth_surface.generate_normals()
	var plinth := _add_helix_part(parent, "GroundedKeepPlinth", plinth_surface.commit(), ReferenceStyle.material("wall"), true)
	plinth.set_meta("terrain_fitted", true)

	# Round arches sit on the octagonal faces, not the cylinder vertices. Match
	# the reference tower's dark inset, thick frame and occasional raised blocks.
	var shaft_height := facade_height + 5.0
	var band_count := int(shaft_height / 7.0)
	var dressing := Node3D.new()
	dressing.name = "KeepTowerDressing"
	dressing.set_meta("preserve_castle_finish", true)
	parent.add_child(dressing)
	for tier in 5:
		# Centre each window between the actual structural bands; the previous
		# independently spaced tiers let band edges cut across the arch openings.
		var y := ground - 4.0 + shaft_height * (float(tier) + 1.5) / float(band_count + 1)
		var tier_ratio := (y - ground + 5.0) / shaft_height
		var radius := lerpf(TOWER_BOTTOM_RADIUS, TOWER_TOP_RADIUS, tier_ratio) * cos(PI / 8) + 0.035
		# Slender dressed corner piers break up the plain shaft like the keep.
		# All vertices remain behind the inner guard; these are shallow wall
		# dressing, not new obstacles in the climb or the safety-plinth route.
		var corner_radius := lerpf(TOWER_BOTTOM_RADIUS, TOWER_TOP_RADIUS, tier_ratio)
		var pier_height := shaft_height / float(band_count + 1) - 1.00
		for corner in TOWER_SIDES:
			var ca := TAU * float(corner) / float(TOWER_SIDES)
			var cr := Vector3(cos(ca), 0, sin(ca))
			var trim := ReferenceStyle.box(dressing, "KeepCornerDressing_%d_%d" % [tier, corner],
				Vector3(0.25, pier_height, 0.22), Vector3.ZERO, "block")
			trim.global_position = Vector3(base.x, y, base.y) + cr * (corner_radius - 0.035)
			# Match the shaft taper so the strip seats into the masonry at both ends.
			var up := (Vector3.UP - cr / shaft_height).normalized()
			trim.basis = Basis(Vector3(cr.z, 0, -cr.x), up, Vector3(cr.z, 0, -cr.x).cross(up))
		for face_i in 4:
			var angle := PI / 8 + TAU * float(face_i) / 4.0 + (PI * 0.25 if tier % 2 else 0.0)
			var radial := Vector3(cos(angle), 0.0, sin(angle))
			var centre := Vector3(base.x, y, base.y) + radial * radius
			var window := ReferenceStyle.window(parent, Vector3.ZERO, radial, 1.15)
			window.global_position = centre
			var patch := ReferenceStyle.cluster(parent, Vector3.ZERO, radial, 1.1)
			patch.global_position = centre + Vector3.UP * 2.4 + Vector3(radial.z, 0, -radial.x) * 0.42 \
				- radial * (2.4 / facade_height)
		# Two red pennants on the intervening faces repeat the keep's banners,
		# rather than adding a new colour or repeating a window on every face.
		for banner_i in 2:
			var ba := PI / 8 + PI / 4 + float(banner_i) * PI + (PI * 0.25 if tier % 2 else 0.0)
			var br := Vector3(cos(ba), 0, sin(ba))
			var banner := MeshInstance3D.new()
			banner.name = "KeepTowerPennant_%d_%d" % [tier, banner_i]
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var points := [Vector3(-0.32, 1.12, 0), Vector3(0.32, 1.12, 0),
				Vector3(0.32, -0.63, 0), Vector3(0, -1.02, 0), Vector3(-0.32, -0.63, 0)]
			for triangle in [[0, 1, 2], [0, 2, 3], [0, 3, 4]]:
				for vertex in triangle:
					surface.add_vertex(points[vertex])
			surface.generate_normals()
			banner.mesh = surface.commit()
			banner.material_override = ReferenceStyle.material("roof")
			dressing.add_child(banner)
			banner.global_position = Vector3(base.x, y + 0.15, base.y) + br * (radius + 0.045)
			var bt := Vector3(br.z, 0, -br.x)
			var bu := (Vector3.UP - br * cos(PI / 8) / shaft_height).normalized()
			banner.basis = Basis(bt, bu, bt.cross(bu))


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
const CROWN_SLAB_HEIGHT := 0.42
const CROWN_PARAPET_HEIGHT := 1.60
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
# The walkable centre can naturally drift about 0.85 m toward either guard.
# Add the 0.5 m capsule radius plus a small tolerance so the crown's inner and
# outer floor shelves do not pinch the player at the final-tread handoff.
const STAIRWELL_LANE_HALF_WIDTH := 1.5

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
	parent.set_meta("crown_stairwell_centre_angle", stairwell_centre_angle)
	parent.set_meta("crown_stairwell_half_angle", stairwell_half_angle)
	parent.set_meta("crown_stair_arrival_angle", stair_end_angle)
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
	# The centre fan can disappear visually on some renderers even though its
	# collision remains, exposing the dark octagonal tower cap below the roof.
	# Use one zero-thickness, upward-facing stone disc to keep this a single clean
	# roof plane without adding a raised rim or duplicate collision.
	var centre_finish := MeshInstance3D.new()
	# Include `Deck` in the semantic name so the global castle palette pass uses
	# the exact same pale walking-surface material as CrownDeck.
	centre_finish.name = "CrownDeckCentreStoneFinish"
	var centre_finish_mesh := CylinderMesh.new()
	centre_finish_mesh.top_radius = stairwell_inner_radius
	centre_finish_mesh.bottom_radius = stairwell_inner_radius
	# A near-zero side wall avoids introducing a new visible circular course.
	centre_finish_mesh.height = 0.0002
	centre_finish_mesh.radial_segments = 64
	centre_finish.mesh = centre_finish_mesh
	var centre_finish_material := _stone(STONE_LIGHT)
	centre_finish_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	centre_finish.material_override = centre_finish_material
	parent.add_child(centre_finish)
	centre_finish.global_position = Vector3(base.x, crown_surface_y + 0.0001, base.y)
	centre_finish.set_meta("visual_only", true)
	centre_finish.set_meta("covers_exposed_tower_cap", true)
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
	# The middle annulus previously relied only on the concave render mesh. On
	# compatibility/Web physics, some top triangles resolve from their underside,
	# letting the player settle 42 cm into the visible roof after hitting a wall.
	# Overlapping tangent boxes make every walkable sector authoritative while
	# deliberately preserving the full headroom wedge above the final flight.
	const MIDDLE_FLOOR_COLLISION_SEGMENTS := 48
	var middle_floor_width := stairwell_outer_radius - stairwell_inner_radius
	var middle_floor_radius := (stairwell_outer_radius
		+ stairwell_inner_radius) * 0.5
	var middle_floor_tangent := TAU * middle_floor_radius \
		/ float(MIDDLE_FLOOR_COLLISION_SEGMENTS) * 1.10
	var middle_segment_half_angle := PI / float(MIDDLE_FLOOR_COLLISION_SEGMENTS)
	for middle_i in MIDDLE_FLOOR_COLLISION_SEGMENTS:
		var middle_angle := TAU * float(middle_i) \
			/ float(MIDDLE_FLOOR_COLLISION_SEGMENTS)
		if absf(angle_difference(middle_angle, stairwell_centre_angle)) \
				< stairwell_half_angle + middle_segment_half_angle:
			continue
		var middle_shape := CollisionShape3D.new()
		var middle_box := BoxShape3D.new()
		middle_box.size = Vector3(middle_floor_width, CROWN_SLAB_HEIGHT,
			middle_floor_tangent)
		middle_shape.shape = middle_box
		middle_shape.position = Vector3(
			cos(middle_angle) * middle_floor_radius, 0.0,
			sin(middle_angle) * middle_floor_radius)
		middle_shape.rotation.y = -middle_angle
		body.add_child(middle_shape)

	# A simple box floor owns the high-speed handoff from the final spiral tread
	# into the crown room. The custom CrownDeck is a concave mesh with a radial
	# cut: at sprint speed the capsule can reach its cut edge before floor snap
	# settles it, read that bevel as a wall, and remain pinned even though the
	# route looks open. This apron begins at the final tread (so it never becomes
	# a ceiling over the lower flight), spans the full capsule-width lane, and
	# reaches inward past the cut edge onto the authoritative centre floor.
	var stair_end_radial := Vector3(cos(stair_end_angle), 0.0,
		sin(stair_end_angle))
	var stair_end_tangent := Vector3(-stair_end_radial.z, 0.0,
		stair_end_radial.x)
	# Keep one simple collider for reliable high-speed movement, but do not render
	# that oversized rectangle. Its old 4.0 m tangential width projected far past
	# the 3.46 m stair lane and was the loose block visible over the final steps.
	# Keep a generous invisible collider under the fitted landing so players remain
	# supported while entering from either side of the curved final tread.
	var handoff_size := Vector3(4.9, 0.28, 4.0)
	var handoff_centre := Vector3(base.x, crown_surface_y - 0.14, base.y) \
		+ stair_end_radial * 5.7 + stair_end_tangent * 2.0
	var handoff := _oriented_box(parent, handoff_size, handoff_centre,
		handoff_centre + stair_end_tangent, deck_material)
	handoff.name = "CrownStairHandoff"
	_add_box_body(handoff, handoff_size)
	handoff.visible = false
	handoff.set_meta("collision_only", true)

	# A tapered masonry tongue now owns the visible transition. Its broad end
	# matches the final tread while the inner end narrows into the crown floor,
	# so the join reads as a deliberate landing instead of a rotated box dropped
	# across the stairwell. The hidden box above remains the gameplay authority.
	var handoff_visual := MeshInstance3D.new()
	handoff_visual.name = "CastleCrownStairLanding"
	handoff_visual.mesh = _tapered_landing_mesh(4.9,
		TREAD_CLEAR_WIDTH + 0.10, TREAD_CLEAR_WIDTH - 0.52, 0.18)
	var handoff_material := deck_material.duplicate() as StandardMaterial3D
	handoff_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	handoff_visual.material_override = handoff_material
	parent.add_child(handoff_visual)
	handoff_visual.global_position = Vector3(handoff_centre.x,
		crown_surface_y - 0.09, handoff_centre.z)
	handoff_visual.look_at(handoff_visual.global_position + stair_end_tangent,
		Vector3.UP)
	handoff_visual.set_meta("visual_role", "fitted_spiral_to_crown_transition")
	_build_crown_arrival_court(parent, base, crown_surface_y, stair_end_radial,
		stair_end_tangent, deck_material, brass, cyan, violet)
	_build_crown_floor_finish(parent, base, crown_surface_y, deck_material)
	_build_crown_underside_supports(parent, base, crown_surface_y,
		gate_angle, stairwell_centre_angle, stairwell_half_angle)

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
	_build_crown_stair_arrival_guards(parent, base, crown_surface_y,
		stair_end_radial, stair_end_tangent)

	var parapet_length := 2.0 * (LANDING_RADIUS - 0.45) * tan(PI / float(TOWER_SIDES)) - 0.35
	var parapet_side_enabled: Array[bool] = []
	var stair_parapet_side: int = wrapi(roundi(stair_end_angle
		/ (TAU / float(TOWER_SIDES))), 0, TOWER_SIDES)
	for i in TOWER_SIDES:
		var angle := TAU * float(i) / float(TOWER_SIDES)
		# Continuous octagonal parapets make the crown a safe architectural room.
		# Entire sides are omitted at the stair mouth and causeway gate, giving the
		# player two unmistakable, obstruction-free openings. The stair-mouth gap
		# matches the same widened span the deck cutout uses, so the parapet
		# opening and the stairwell opening line up instead of the parapet gap
		# being narrower than the hole in the floor beneath it.
		# Only the bridge keeps one complete octagonal panel open. At the stair,
		# splitting a single panel around the exact arrival lane closes the huge
		# three-panel fall gap without blocking the usable stair width.
		var is_gate_opening: bool = absf(
			angle_difference(angle, gate_angle)) < 0.72
		var is_stair_arrival_panel: bool = i == stair_parapet_side
		var side_enabled: bool = not is_gate_opening \
			and not is_stair_arrival_panel
		parapet_side_enabled.append(side_enabled)
		if is_stair_arrival_panel:
			_build_crown_split_arrival_parapet(parent, base, crown_surface_y,
				angle, stair_end_angle, parapet_length, i)
			continue
		if not side_enabled:
			continue
		var wall := MeshInstance3D.new()
		wall.name = "CrownParapet_%02d" % i
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(parapet_length, CROWN_PARAPET_HEIGHT, 0.64)
		wall.mesh = wall_mesh
		wall.material_override = _stone(STONE_DARK)
		parent.add_child(wall)
		wall.global_position = Vector3(
			base.x + cos(angle) * (LANDING_RADIUS - 0.4),
			# Sink the simple collider 9 cm into the slab. An exact wall/floor seam
			# can hold a sprinting capsule between two contact normals.
			crown_surface_y + CROWN_PARAPET_HEIGHT * 0.5 - 0.09,
			base.y + sin(angle) * (LANDING_RADIUS - 0.4))
		wall.rotation.y = -angle + PI * 0.5
		_add_box_body(wall, wall_mesh.size)
		_decorate_crown_parapet_wall(wall, parapet_length, i)

		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(parapet_length + 0.15, 0.16, 0.72)
		cap.mesh = cap_mesh
		cap.material_override = brass
		parent.add_child(cap)
		cap.global_position = wall.global_position + Vector3.UP * 0.555
		cap.rotation.y = wall.rotation.y

		# Blender owns the presentation mesh; the hidden procedural wall remains
		# the simple, snag-free authoritative collision volume.
		var blender_panel := BlenderCrownParapetScene.instantiate() as Node3D
		if blender_panel != null:
			blender_panel.name = "BlenderCrownParapetPanel_%02d" % i
			parent.add_child(blender_panel)
			blender_panel.global_position = Vector3(
				wall.global_position.x, crown_surface_y, wall.global_position.z)
			blender_panel.rotation.y = wall.rotation.y
			blender_panel.scale.y = CROWN_PARAPET_HEIGHT / 1.18
			blender_panel.set_meta("source_blend",
				"res://assets3D/castle_rooftop_parapet/blend/castle_rooftop_parapet.blend")
			blender_panel.set_meta("collision_policy",
				"visual_only_over_procedural_godot_wall")
			wall.visible = false
			cap.visible = false

	# Compact masonry piers close the dark slots between adjacent octagonal wall
	# panels. Piers are omitted where both neighbouring sides are intentionally
	# open, so the stair mouth and bridge gate remain full-width clear routes.
	var parapet_mid_radius := LANDING_RADIUS - 0.4
	var parapet_corner_radius := parapet_mid_radius / cos(PI / float(TOWER_SIDES))
	for corner_index in TOWER_SIDES:
		var left_side := corner_index
		var right_side := (corner_index + 1) % TOWER_SIDES
		if not parapet_side_enabled[left_side] and not parapet_side_enabled[right_side]:
			continue
		var corner_angle := TAU * (float(corner_index) + 0.5) \
			/ float(TOWER_SIDES)
		var pier := MeshInstance3D.new()
		pier.name = "CrownParapetJointPier_%02d" % corner_index
		var pier_mesh := CylinderMesh.new()
		pier_mesh.top_radius = 0.34
		pier_mesh.bottom_radius = 0.34
		pier_mesh.height = CROWN_PARAPET_HEIGHT - 0.14
		pier_mesh.radial_segments = 24
		pier.mesh = pier_mesh
		pier.material_override = _stone(STONE_DARK)
		parent.add_child(pier)
		pier.global_position = Vector3(
			base.x + cos(corner_angle) * parapet_corner_radius,
			crown_surface_y + pier_mesh.height * 0.5,
			base.y + sin(corner_angle) * parapet_corner_radius)
		pier.rotation.y = -corner_angle
		_add_crown_round_joint_collision(pier, 0.34, CROWN_PARAPET_HEIGHT, 0.07)
		pier.set_meta("closes_parapet_panel_joint", true)
		pier.set_meta("rounded_masonry_joint", true)
		pier.set_meta("design_language", "restrained_medieval_castle_masonry")
		var pier_cap := MeshInstance3D.new()
		pier_cap.name = "CrownParapetJointPierCap_%02d" % corner_index
		var pier_cap_mesh := CylinderMesh.new()
		pier_cap_mesh.top_radius = 0.37
		pier_cap_mesh.bottom_radius = 0.41
		pier_cap_mesh.height = 0.14
		pier_cap_mesh.radial_segments = 24
		pier_cap.mesh = pier_cap_mesh
		pier_cap.material_override = _stone(Color("8399a6"))
		parent.add_child(pier_cap)
		pier_cap.global_position = pier.global_position \
			+ Vector3.UP * (pier_mesh.height * 0.5 + 0.07)
		pier_cap.rotation.y = pier.rotation.y
		pier_cap.set_meta("visual_only", true)
		pier_cap.set_meta("castle_stone_coping", true)

	# Keep the bridge mouth open. The former Aether Lens frame introduced tall
	# diagonal beams and floating rings into an otherwise medieval silhouette;
	# the crown parapet, timber bridge and red-roof newels now mark the route.

	_build_castle_fountain(parent, base, crown_surface_y, gate_dir,
		stair_end_radial)
	CrownGarden.build(parent, Vector3(base.x, crown_surface_y, base.y))
	RoyalTerrace.build(parent, Vector3(base.x, crown_surface_y, base.y))


func _build_crown_split_arrival_parapet(parent: Node3D, base: Vector2,
		surface_y: float, panel_angle: float, arrival_angle: float,
		panel_length: float, panel_index: int) -> void:
	# The arrival is oblique to this octagonal side. Include the outer running
	# lane and capsule radius through its turn, not just the tread's width.
	const CLEAR_OPENING_WIDTH := 4.65
	const MIN_FINISHED_WING := 0.55
	var radius := LANDING_RADIUS - 0.4
	var panel_centre := Vector3(base.x + cos(panel_angle) * radius,
		surface_y, base.y + sin(panel_angle) * radius)
	var tangent := Vector3(-sin(panel_angle), 0.0, cos(panel_angle))
	var arrival_point := Vector3(base.x + cos(arrival_angle) * radius,
		surface_y, base.y + sin(arrival_angle) * radius)
	var opening_centre := clampf((arrival_point - panel_centre).dot(tangent),
		-panel_length * 0.5 + CLEAR_OPENING_WIDTH * 0.5 + MIN_FINISHED_WING,
		panel_length * 0.5 - CLEAR_OPENING_WIDTH * 0.5 - MIN_FINISHED_WING)
	var ranges := [
		Vector2(-panel_length * 0.5,
			opening_centre - CLEAR_OPENING_WIDTH * 0.5),
		Vector2(opening_centre + CLEAR_OPENING_WIDTH * 0.5,
			panel_length * 0.5),
	]
	for wing_index in ranges.size():
		var wing_range: Vector2 = ranges[wing_index]
		var wing_length := wing_range.y - wing_range.x
		if wing_length < 0.38:
			continue
		var wing_centre := panel_centre + tangent * (wing_range.x + wing_range.y) * 0.5
		_build_crown_blender_parapet_segment(parent, wing_centre,
			panel_angle, wing_length, "CrownStairArrivalWing_%02d_%s" % [
				panel_index, "L" if wing_index == 0 else "R"])


func _build_crown_blender_parapet_segment(parent: Node3D, floor_centre: Vector3,
		panel_angle: float, segment_length: float, segment_name: String) -> void:
	# One clean box owns collision. The scaled Blender assembly supplies the
	# staggered ashlar, mortar recess, finished quoins, and separate capstones.
	var collision_wall := MeshInstance3D.new()
	collision_wall.name = "%sCollision" % segment_name
	var collision_mesh := BoxMesh.new()
	collision_mesh.size = Vector3(segment_length, CROWN_PARAPET_HEIGHT, 0.64)
	collision_wall.mesh = collision_mesh
	collision_wall.visible = false
	parent.add_child(collision_wall)
	collision_wall.global_position = floor_centre \
		+ Vector3.UP * (CROWN_PARAPET_HEIGHT * 0.5 - 0.09)
	collision_wall.rotation.y = -panel_angle + PI * 0.5
	_add_box_body(collision_wall, collision_mesh.size)
	collision_wall.set_meta("collision_only", true)
	collision_wall.set_meta("continuous_rooftop_fall_barrier", true)

	var visual := BlenderCrownParapetScene.instantiate() as Node3D
	if visual == null:
		return
	visual.name = segment_name
	parent.add_child(visual)
	visual.global_position = floor_centre
	visual.rotation.y = -panel_angle + PI * 0.5
	visual.scale.x = segment_length / BLENDER_PARAPET_PANEL_LENGTH
	visual.scale.y = CROWN_PARAPET_HEIGHT / 1.18
	visual.set_meta("source_blend",
		"res://assets3D/castle_rooftop_parapet/blend/castle_rooftop_parapet.blend")
	visual.set_meta("collision_policy", "visual_only_over_procedural_godot_wall")
	visual.set_meta("fitted_without_overlap", true)


func _build_crown_stair_arrival_guards(parent: Node3D, base: Vector2,
		surface_y: float, radial: Vector3, tangent: Vector3) -> void:
	# Continue the helix guards just far enough to block a sideways step into the
	# opening, then stop before the landing fans inward. A long corridor here
	# pinches the inner running lane against the crown handoff.
	# The exposed outer return runs to the fitted perimeter wing. The inner side
	# remains open after its curved newel, so this added length cannot pinch the
	# player's natural inward fan onto the roof.
	const GUARD_LENGTH := 2.25
	const GUARD_DEPTH := 0.38
	const GUARD_HEIGHT := 1.18
	var lane_half_width := TREAD_CLEAR_WIDTH * 0.5 + 0.22
	# The inner edge already has the continuous curved return and arrival newel.
	# A second straight inner guard intersects the natural inward fan from the
	# final tread. Only the exposed outer/right edge needs this rooftop return.
	for side_index in 1:
		var side_sign := 1.0
		var centre := Vector3(base.x, surface_y, base.y) \
			+ radial * (STAIR_RADIUS + side_sign * lane_half_width) \
			+ tangent * (GUARD_LENGTH * 0.5 + 0.18)
		var angle := atan2(tangent.z, tangent.x)
		var guard := _oriented_box(parent,
			Vector3(GUARD_DEPTH, GUARD_HEIGHT, GUARD_LENGTH),
			centre + Vector3.UP * (GUARD_HEIGHT * 0.5 - 0.09),
			centre + Vector3.UP * (GUARD_HEIGHT * 0.5 - 0.09) + tangent,
			_stone(STONE_DARK))
		guard.name = "CrownStairArrivalGuard_Outer"
		guard.visible = false
		_add_box_body(guard, Vector3(GUARD_DEPTH, GUARD_HEIGHT, GUARD_LENGTH))
		guard.set_meta("collision_only", true)
		guard.set_meta("continuous_from_stair_to_rooftop", true)

		var visual := BlenderCrownParapetScene.instantiate() as Node3D
		if visual == null:
			continue
		visual.name = "BlenderCrownStairArrivalGuard_Outer"
		parent.add_child(visual)
		visual.global_position = centre
		visual.rotation.y = -angle
		visual.scale = Vector3(GUARD_LENGTH / BLENDER_PARAPET_PANEL_LENGTH,
			1.0, GUARD_DEPTH / 0.64)
		visual.set_meta("collision_policy", "visual_only_over_procedural_godot_wall")
		visual.set_meta("fitted_without_overlap", true)


# Replace the military display with a solid, animated palace-garden fountain.
func _build_castle_fountain(parent: Node3D, base: Vector2,
		surface_y: float, gate_dir: Vector3, stair_dir: Vector3) -> void:
	var outward := (gate_dir + stair_dir).normalized()
	if outward.length_squared() < 0.5:
		outward = Vector3(0.0, 0.0, -1.0)
	RoyalFountain.build(parent, Vector3(base.x, surface_y, base.y), outward)


# The finished roof is intentionally one uninterrupted castle-stone surface.
# Earlier concentric torus courses and radial box joints produced the bright
# white circles and black spokes reported in overhead views. The garden
# fountain and masonry perimeter carry the visual focus without raised line work or
# collision ridges.
func _build_crown_floor_finish(parent: Node3D, base: Vector2,
		surface_y: float, _deck_material: Material) -> void:
	var finish := Node3D.new()
	finish.name = "CrownMasonryFinish"
	finish.set_meta("visual_only", true)
	finish.set_meta("clean_uninterrupted_roof_surface", true)
	finish.set_meta("concentric_and_radial_lines_removed", true)
	parent.add_child(finish)
	finish.set_meta("roof_centre", Vector3(base.x, surface_y, base.y))

# The crown underside deliberately carries no hanging brackets or segmented
# fascia. Its closed deck mesh is the finished soffit, producing one continuous
# castle-stone surface around the intentional stairwell opening.
func _build_crown_underside_supports(parent: Node3D, _base: Vector2,
		_surface_y: float, _gate_angle: float, _stairwell_angle: float,
		_stairwell_half_angle: float) -> void:
	var vaulting := Node3D.new()
	vaulting.name = "CrownUndersideVaulting"
	vaulting.set_meta("finished_beneath_surface", true)
	vaulting.set_meta("collision_policy", "visual_only_below_crown_floor")
	vaulting.set_meta("uninterrupted_stone_soffit", true)
	parent.add_child(vaulting)


func _decorate_crown_parapet_wall(wall: MeshInstance3D,
		wall_length: float, side_index: int) -> void:
	var brick_material := _stone(Color("8399a6"))
	for face_value in [-1.0, 1.0]:
		var face: float = face_value
		for row in 2:
			var columns := 5
			var pitch := wall_length / float(columns)
			var stagger := pitch * 0.5 if row % 2 else 0.0
			for column in columns:
				var x := -wall_length * 0.5 + pitch * (float(column) + 0.5) + stagger
				if x > wall_length * 0.5 - 0.12:
					continue
				var brick := MeshInstance3D.new()
				brick.name = "CrownParapetBrick_%02d_%s_%d_%d" % [
					side_index, "I" if face < 0.0 else "O", row, column]
				var brick_mesh := BoxMesh.new()
				brick_mesh.size = Vector3(pitch * 0.88, 0.38, 0.06)
				brick.mesh = brick_mesh
				brick.material_override = brick_material
				wall.add_child(brick)
				brick.position = Vector3(x, -0.20 + float(row) * 0.42,
					face * 0.305)
				brick.set_meta("visual_only", true)


# A proper arrival room at the top of the spiral. The earlier crown was a
# circular slab with scattered props, so the stair mouth looked like a hole in
# a roof and gave no architectural cue for where to walk next. This open
# observatory vestibule turns the safe handoff floor into an intentional piece
# of architecture: a dark processional carpet, paired stone/brass pylons and a
# split arch that frames the crown without putting a lintel across the camera.
# The plinth+pylon posts are solid (a player could stand inside them); the
# collar/yoke/lumen arching overhead and the apex lens stay visual-only,
# since those sit above head height and were never the walkable footprint.
func _build_crown_arrival_court(parent: Node3D, base: Vector2,
		surface_y: float, radial: Vector3, forward: Vector3,
		_deck_material: Material, _brass: Material, _cyan: Material,
		_violet: Material) -> void:
	var court := Node3D.new()
	court.name = "CrownArrivalCourt"
	court.set_meta("design_language", "restrained_medieval_castle_masonry")
	court.set_meta("collision_policy", "flush_visuals_outside_player_lane")
	parent.add_child(court)

	var origin := Vector3(base.x, surface_y, base.y) \
		+ radial * 5.7 + forward * 2.0
	var carpet_position := origin + Vector3.UP * 0.017
	var carpet := _oriented_box(court, Vector3(3.45, 0.035, 3.55),
		carpet_position, carpet_position + forward, _stone(STONE_DARK))
	carpet.name = "CrownArrivalCarpet"
	carpet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	carpet.set_meta("flush_detail", true)

	var threshold := _oriented_box(court, Vector3(3.7, 0.055, 0.34),
		Vector3(base.x, surface_y + 0.027, base.y) + radial * STAIR_RADIUS
			+ forward * 0.18,
		Vector3(base.x, surface_y + 0.027, base.y) + radial * STAIR_RADIUS
			+ forward, _stone(Color("748b99")))
	threshold.name = "CrownArrivalThreshold"
	threshold.set_meta("flush_detail", true)

	# Paired square gateposts with red pyramidal caps repeat the castle and
	# village towers. They replace the glowing pylons, floating lens and split
	# metal yokes that made this one landing look like a different building.
	for signed_value in [-1.0, 1.0]:
		var signed: float = signed_value
		var pylon_base := origin + radial * signed * 2.18 + forward * 0.15
		var side_name := "Inner" if signed < 0.0 else "Outer"

		var plinth_position := pylon_base + Vector3.UP * 0.16
		var plinth := _oriented_box(court, Vector3(0.92, 0.32, 0.92),
			plinth_position, plinth_position + forward,
			_stone(STONE_DARK))
		plinth.name = "CrownArrivalPlinth_%s" % ("Inner" if signed < 0.0 else "Outer")

		var pylon_position := pylon_base + Vector3.UP * 0.96
		var pylon := _oriented_box(court, Vector3(0.66, 1.28, 0.66),
			pylon_position, pylon_position + forward,
			_stone(STONE_LIGHT))
		pylon.name = "CrownArrivalPylon_%s" % side_name

		var cap_position := pylon_base + Vector3.UP * 1.66
		var cap := _oriented_box(court, Vector3(0.88, 0.18, 0.88),
			cap_position, cap_position + forward,
			_stone(Color("748b99")))
		cap.name = "CrownArrivalCap_%s" % side_name

		var roof := MeshInstance3D.new()
		roof.name = "CrownArrivalRoof_%s" % side_name
		var roof_mesh := CylinderMesh.new()
		roof_mesh.top_radius = 0.04
		roof_mesh.bottom_radius = 0.59
		roof_mesh.height = 0.72
		roof_mesh.radial_segments = 4
		roof.mesh = roof_mesh
		roof.material_override = _stone(ROOF_RED)
		court.add_child(roof)
		roof.global_position = pylon_base + Vector3.UP * 2.10
		roof.rotation.y = -atan2(forward.z, forward.x) + PI * 0.25

		for course_index in 1:
			var course_position := pylon_base + Vector3.UP * 0.92
			var course := _oriented_box(court, Vector3(0.72, 0.08, 0.72),
				course_position, course_position + forward,
				_stone(Color("8399a6")))
			course.name = "CrownArrivalAshlarCourse_%s_%d" % [side_name, course_index]


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

		# Winding corrected to match _helix_band_mesh's fix (diag_helix_winding.gd)
		# — this ring was independently authored with the same original (wrong)
		# vertex order, leaving the crown platform's top face pointing down.
		_add_surface_quad(surface, o0t, o1t, c1t, c0t)  # top ring
		_add_surface_quad(surface, c0b, c1b, o1b, o0b)  # underside

	# The stairwell opening is a pie slice missing from the ring above. Its two
	# straight edges get a cap below (at cut_start/cut_end), but the slab has
	# real thickness (slab_height), and the two CURVED edges of that opening —
	# where the solid centre disc's outer rim (inner_radius) and the outer
	# shelf's inner rim (cut_outer_radius) meet the open hole — had no cap at
	# all: bare slab thickness with no face, rather than a wrong one. That is
	# what read as "inverted"/see-through from inside the stairwell looking at
	# the platform's inner edge. Winding verified empirically
	# (diag_crown_disc_winding.gd).
	var wedge_span := cut_end - cut_start
	var wedge_segments := maxi(1, roundi(float(segments) * absf(wedge_span) / full_turn))
	for i in wedge_segments:
		var wa0 := lerpf(cut_start, cut_end, float(i) / float(wedge_segments))
		var wa1 := lerpf(cut_start, cut_end, float(i + 1) / float(wedge_segments))
		var inner0t := Vector3(base.x + cos(wa0) * inner_radius, top_y, base.y + sin(wa0) * inner_radius)
		var inner1t := Vector3(base.x + cos(wa1) * inner_radius, top_y, base.y + sin(wa1) * inner_radius)
		var inner0b := Vector3(inner0t.x, bottom_y, inner0t.z)
		var inner1b := Vector3(inner1t.x, bottom_y, inner1t.z)
		_add_surface_quad(surface, inner1t, inner0t, inner0b, inner1b)

		var outer0t := Vector3(base.x + cos(wa0) * cut_outer_radius, top_y, base.y + sin(wa0) * cut_outer_radius)
		var outer1t := Vector3(base.x + cos(wa1) * cut_outer_radius, top_y, base.y + sin(wa1) * cut_outer_radius)
		var outer0b := Vector3(outer0t.x, bottom_y, outer0t.z)
		var outer1b := Vector3(outer1t.x, bottom_y, outer1t.z)
		_add_surface_quad(surface, outer0t, outer1t, outer1b, outer0b)

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
		# Same winding correction as the top ring above and _helix_band_mesh.
		_add_surface_quad(surface, o0t, o1t, i1t, i0t)
		_add_surface_quad(surface, i0b, i1b, o1b, o0b)
		_add_surface_quad(surface, o1b, o1t, o0t, o0b)

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
		# Verified empirically (diag_crown_disc_winding.gd): (centre, c1, c0) was
		# backwards — normal pointed straight down (0,-1,0) instead of up. Same
		# root-cause mistake as _helix_band_mesh, just in a triangle fan instead
		# of a quad strip. Swapped to (centre, c0, c1), and the underside swapped
		# to match so the two faces stay correctly opposed.
		surface.add_vertex(centre_top)
		surface.add_vertex(c0t)
		surface.add_vertex(c1t)
		surface.add_vertex(centre_bottom)
		surface.add_vertex(c1b)
		surface.add_vertex(c0b)

	# Cap the two straight edges of the wedge cut, and floor the small centre
	# disc bounded by inner_radius so the stairwell opening reads as a clean
	# rectangular gap rather than exposing the underside everywhere.
	for cut_angle in [cut_start, cut_end]:
		var ot := Vector3(base.x + cos(cut_angle) * cut_outer_radius, top_y, base.y + sin(cut_angle) * cut_outer_radius)
		var ob := Vector3(ot.x, bottom_y, ot.z)
		var it := Vector3(base.x + cos(cut_angle) * inner_radius, top_y, base.y + sin(cut_angle) * inner_radius)
		var ib := Vector3(it.x, bottom_y, it.z)
		# Verified empirically (diag_crown_disc_winding.gd): both caps faced
		# outward, away from the open stairwell, instead of inward toward where
		# the player actually stands. Swapping which branch uses which order
		# fixes both (each is the reverse of the other, so this is exactly a
		# winding flip for both).
		if cut_angle == cut_start:
			_add_surface_quad(surface, it, ot, ob, ib)
		else:
			_add_surface_quad(surface, ib, ob, ot, it)

	surface.generate_normals()
	return surface.commit()


# Full-height masonry balustrades protect the two straight stairwell edges. The
# former 14 cm brass kerbs merely outlined a dangerous-looking hole and left the
# wedge cuts visually raw. These walls remain on the cut boundary, outside the
# clear stair lane, and their simple boxes provide dependable collision.
func _build_stairwell_kerb(parent: Node3D, base: Vector2, surface_y: float,
		centre_angle: float, half_angle: float,
		inner_radius: float, cut_outer_radius: float, _brass: Material) -> void:
	for sign_i in [-1.0, 1.0]:
		var edge_angle: float = centre_angle + half_angle * sign_i
		# The positive edge is the actual final-tread arrival line. It needs a
		# short inner newel, not a wall across the radial walking lane.
		var wall_length := cut_outer_radius - inner_radius + 0.24 \
			if sign_i < 0.0 else 0.72
		var mid_radius := inner_radius - 0.24 + wall_length * 0.5 \
			if sign_i < 0.0 else inner_radius - 0.55
		var solid_side_offset := Vector3(-sin(edge_angle), 0.0, cos(edge_angle)) \
			* float(sign_i) * 0.34
		var wall := MeshInstance3D.new()
		wall.name = "StairwellStoneBalustrade_%s" % ("L" if sign_i < 0.0 else "R")
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(wall_length, 1.08, 0.28)
		wall.mesh = wall_mesh
		wall.material_override = _stone(STONE_DARK)
		parent.add_child(wall)
		wall.global_position = Vector3(
			base.x + cos(edge_angle) * mid_radius,
			surface_y + 0.54,
			base.y + sin(edge_angle) * mid_radius) + solid_side_offset
		wall.rotation.y = -edge_angle
		_add_box_body(wall, wall_mesh.size)
		_decorate_stairwell_balustrade(wall, wall_length, sign_i)
		var cap := MeshInstance3D.new()
		cap.name = "StairwellBalustradeCoping_%s" % ("L" if sign_i < 0.0 else "R")
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(wall_length + 0.14, 0.14, 0.42)
		cap.mesh = cap_mesh
		cap.material_override = _stone(Color("8399a6"))
		parent.add_child(cap)
		cap.global_position = wall.global_position + Vector3.UP * 0.61
		cap.rotation.y = wall.rotation.y
		cap.set_meta("castle_stone_coping", true)

	# Complete the protected inner edge of the stairwell with a curved masonry
	# return. The final-tread side remains open for walking, while this return
	# joins the long balustrade to the arrival newel and makes the opening read as
	# one deliberately framed castle stair rather than disconnected rail pieces.
	_build_crown_stairwell_inner_return(parent, base, surface_y,
		centre_angle - half_angle, centre_angle + half_angle, inner_radius)


func _build_crown_stairwell_inner_return(parent: Node3D, base: Vector2,
		surface_y: float, start_angle: float, end_angle: float,
		centre_radius: float) -> void:
	const WALL_HALF_WIDTH := 0.18
	const WALL_HEIGHT := 1.08
	const COPING_OVERHANG := 0.08
	const COPING_HEIGHT := 0.14
	# Keep the whole wall on the roof side of the cutout. The lower flight must
	# retain its full inner walking lane and headroom. Extend the ends into the
	# straight edge wall/newel so there is no exposed slot at either junction.
	centre_radius -= WALL_HALF_WIDTH
	start_angle -= 0.08
	end_angle += 0.08
	var roof_origin := Vector3(base.x, surface_y, base.y)
	# Geometry is LOCAL to roof_origin. Previously world-space vertices inherited
	# CastleStair's translated parent too, placing the entire return off the roof.
	var wall_mesh := _crown_arc_wall_mesh(Vector2.ZERO, start_angle, end_angle,
		centre_radius - WALL_HALF_WIDTH, centre_radius + WALL_HALF_WIDTH,
		-0.09, WALL_HEIGHT)
	var wall := MeshInstance3D.new()
	wall.name = "CrownStairwellInnerReturn"
	wall.mesh = wall_mesh
	var wall_material := _stone(STONE_DARK)
	wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	wall.material_override = wall_material
	parent.add_child(wall)
	wall.global_position = roof_origin
	var body := StaticBody3D.new()
	wall.add_child(body)
	# Closed convex cells provide reliable two-sided contacts without exposing
	# mortar or capstone edges to the capsule. The slight overlap seals joints.
	var collision_segments := maxi(12, int(ceil((end_angle - start_angle) * 16.0)))
	for segment in collision_segments:
		var angle0 := lerpf(start_angle, end_angle,
			float(segment) / float(collision_segments)) - 0.001
		var angle1 := lerpf(start_angle, end_angle,
			float(segment + 1) / float(collision_segments)) + 0.001
		var points := PackedVector3Array()
		for angle: float in [angle0, angle1]:
			for radius: float in [centre_radius - WALL_HALF_WIDTH,
					centre_radius + WALL_HALF_WIDTH]:
				for height: float in [-0.09, WALL_HEIGHT + COPING_HEIGHT]:
					points.append(Vector3(cos(angle) * radius, height, sin(angle) * radius))
		var shape := CollisionShape3D.new()
		var convex := ConvexPolygonShape3D.new()
		convex.points = points
		shape.shape = convex
		body.add_child(shape)
	wall.set_meta("continuous_stairwell_barrier", true)
	wall.set_meta("design_language", "restrained_medieval_castle_masonry")
	wall.set_meta("collision_policy", "smooth_closed_convex_cells")
	wall.set_meta("palace_wall_profile", {"radius": centre_radius,
		"start_angle": start_angle, "end_angle": end_angle,
		"height": WALL_HEIGHT, "half_width": WALL_HALF_WIDTH})
	# Rounded newels bury the former square end faces and soften the angle where
	# the curved guard meets each straight return, without narrowing the mouth.
	for joint_index in 2:
		var joint_angle := start_angle if joint_index == 0 else end_angle
		var joint := MeshInstance3D.new()
		joint.name = "RoundedStairwellJoint_%d" % joint_index
		var joint_mesh := CylinderMesh.new()
		joint_mesh.top_radius = 0.25
		joint_mesh.bottom_radius = 0.25
		joint_mesh.height = WALL_HEIGHT
		joint_mesh.radial_segments = 24
		joint.mesh = joint_mesh
		joint.material_override = _stone(STONE_DARK)
		wall.add_child(joint)
		joint.position = Vector3(cos(joint_angle) * centre_radius,
			WALL_HEIGHT * 0.5, sin(joint_angle) * centre_radius)
		_add_crown_round_joint_collision(joint, 0.25,
			WALL_HEIGHT + COPING_HEIGHT, COPING_HEIGHT * 0.5)
		joint.set_meta("rounded_masonry_joint", true)
		var cap := MeshInstance3D.new()
		cap.name = "RoundedStairwellParapetCoping_%d" % joint_index
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = 0.29
		cap_mesh.bottom_radius = 0.33
		cap_mesh.height = COPING_HEIGHT
		cap_mesh.radial_segments = 24
		cap.mesh = cap_mesh
		cap.material_override = _stone(STONE_LIGHT)
		joint.add_child(cap)
		cap.position.y = WALL_HEIGHT * 0.5 + COPING_HEIGHT * 0.5
		cap.set_meta("castle_stone_coping", true)

	var coping_mesh := _crown_arc_wall_mesh(Vector2.ZERO, start_angle, end_angle,
		centre_radius - WALL_HALF_WIDTH - COPING_OVERHANG,
		centre_radius + WALL_HALF_WIDTH + COPING_OVERHANG,
		WALL_HEIGHT, WALL_HEIGHT + COPING_HEIGHT)
	var coping := MeshInstance3D.new()
	coping.name = "CrownStairwellInnerReturnCoping"
	coping.mesh = coping_mesh
	var coping_material := _stone(Color("8399a6"))
	coping_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	coping.material_override = coping_material
	parent.add_child(coping)
	coping.global_position = roof_origin
	coping.set_meta("visual_only", true)
	coping.set_meta("castle_stone_coping", true)

	# Staggered ashlar faces on both sides match the straight stairwell
	# balustrades without introducing high-contrast floor lines or collision.
	const ROWS := 2
	const COLUMNS := 9
	var span := end_angle - start_angle
	for row in ROWS:
		var stagger := 0.5 if row % 2 else 0.0
		for column in COLUMNS:
			var cell_start := (float(column) + stagger) / float(COLUMNS)
			var cell_end := minf((float(column + 1) + stagger)
				/ float(COLUMNS), 1.0)
			if cell_start >= 1.0:
				continue
			var brick_margin := (cell_end - cell_start) * 0.07
			for face_sign in [-1.0, 1.0]:
				var face: float = face_sign
				var face_radius: float = centre_radius + face * WALL_HALF_WIDTH
				var brick_inner: float = face_radius + 0.006 \
					if face > 0.0 else face_radius - 0.045
				var brick_outer: float = face_radius + 0.045 \
					if face > 0.0 else face_radius - 0.006
				var brick_mesh := _crown_arc_wall_mesh(Vector2.ZERO,
					start_angle + span * (cell_start + brick_margin),
					start_angle + span * (cell_end - brick_margin),
					brick_inner, brick_outer,
					0.10 + float(row) * 0.43,
					0.48 + float(row) * 0.43)
				var brick := MeshInstance3D.new()
				brick.name = "CrownStairwellReturnBrick_%s_%d_%d" % [
					"Inner" if face < 0.0 else "Outer", row, column]
				brick.mesh = brick_mesh
				var brick_material := _stone(Color("8399a6"))
				brick_material.cull_mode = BaseMaterial3D.CULL_DISABLED
				brick.material_override = brick_material
				parent.add_child(brick)
				brick.global_position = roof_origin
				brick.set_meta("visual_only", true)


func _crown_arc_wall_mesh(base: Vector2, start_angle: float, end_angle: float,
		inner_radius: float, outer_radius: float,
		bottom_y: float, top_y: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Keep top/side edges crisp like the neighboring cut-stone parapets rather
	# than averaging their normals into a swollen, tube-like coping profile.
	surface.set_smooth_group(-1)
	var span := end_angle - start_angle
	var segments := maxi(4, int(ceil(absf(span) * 32.0)))
	for segment in segments:
		var angle0 := lerpf(start_angle, end_angle,
			float(segment) / float(segments))
		var angle1 := lerpf(start_angle, end_angle,
			float(segment + 1) / float(segments))
		var i0b := Vector3(base.x + cos(angle0) * inner_radius,
			bottom_y, base.y + sin(angle0) * inner_radius)
		var i1b := Vector3(base.x + cos(angle1) * inner_radius,
			bottom_y, base.y + sin(angle1) * inner_radius)
		var o0b := Vector3(base.x + cos(angle0) * outer_radius,
			bottom_y, base.y + sin(angle0) * outer_radius)
		var o1b := Vector3(base.x + cos(angle1) * outer_radius,
			bottom_y, base.y + sin(angle1) * outer_radius)
		var i0t := Vector3(i0b.x, top_y, i0b.z)
		var i1t := Vector3(i1b.x, top_y, i1b.z)
		var o0t := Vector3(o0b.x, top_y, o0b.z)
		var o1t := Vector3(o1b.x, top_y, o1b.z)
		_add_surface_quad(surface, i0t, i1t, o1t, o0t)
		_add_surface_quad(surface, i0b, o0b, o1b, i1b)
		_add_surface_quad(surface, i0b, i1b, i1t, i0t)
		_add_surface_quad(surface, o0b, o0t, o1t, o1b)
		if segment == 0:
			_add_surface_quad(surface, i0b, i0t, o0t, o0b)
		if segment == segments - 1:
			_add_surface_quad(surface, i1b, o1b, o1t, i1t)
	surface.generate_normals()
	return surface.commit()


func _add_crown_round_joint_collision(mesh: MeshInstance3D, radius: float,
		height: float, centre_y: float) -> void:
	var body := StaticBody3D.new()
	mesh.add_child(body)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	shape.position.y = centre_y
	body.add_child(shape)


func _decorate_stairwell_balustrade(wall: MeshInstance3D,
		wall_length: float, sign_i: int) -> void:
	var brick_material := _stone(Color("8399a6"))
	for face_value in [-1.0, 1.0]:
		var face: float = face_value
		for row in 2:
			var columns := maxi(1, int(ceil(wall_length / 0.78)))
			var pitch := wall_length / float(columns)
			for column in columns:
				var brick := MeshInstance3D.new()
				brick.name = "StairwellBrick_%s_%s_%d_%d" % [
					"L" if sign_i < 0 else "R",
					"I" if face < 0.0 else "O", row, column]
				var mesh := BoxMesh.new()
				mesh.size = Vector3(pitch * 0.86, 0.38, 0.06)
				brick.mesh = mesh
				brick.material_override = brick_material
				wall.add_child(brick)
				brick.position = Vector3(-wall_length * 0.5
					+ pitch * (float(column) + 0.5),
					-0.20 + float(row) * 0.42, face * 0.17)
				brick.set_meta("visual_only", true)


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
		plank.name = "LumenBridgeSurfacePlank_%02d" % i
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
		var conduit := _oriented_box(parent,
			Vector3(0.62, 0.08, segment_length + 0.24), conduit_pos, target, brass)
		conduit.name = "LumenBridgeConduit_%02d" % i
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
			var collar := _oriented_box(parent,
				Vector3(BRIDGE_WIDTH * 0.68, 0.16, 0.66),
				p - Vector3(0.0, 0.3, 0.0), target, brass)
			collar.name = "AetherTensionCollar_%d" % int(i / 4)

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
	HubLightFade.apply(beacon)
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
		HubLightFade.apply(arch_lamp)
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
func _build_terrace_portal(_parent: Node3D, _target: Vector3, _direction: Vector3,
		_side: Vector3, _brass: Material, _glow_material: Material) -> void:
	# Intentionally open. The timber bridge rails and castle gatehouse already
	# frame this handoff; a second tall technology portal mixed styles and
	# crowded the camera without contributing collision or navigation.
	pass


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


# Adds a box collider as a child of `mesh_instance`, sized/oriented to match
# it exactly (inherits the mesh's own transform).
func _add_box_collision(mesh_instance: MeshInstance3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	mesh_instance.add_child(body)


# Adds a cylinder collider as a child of `mesh_instance`, matching it exactly.
func _add_cylinder_collision(mesh_instance: MeshInstance3D, radius: float,
		height: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)
	mesh_instance.add_child(body)


func _add_castle_stair_torch(parent: Node3D, base: Vector2, angle: float,
		y: float, index: int) -> void:
	var torch := Node3D.new()
	torch.name = "CastleStairTorch_%03d" % index
	parent.add_child(torch)
	var radial := Vector3(cos(angle), 0.0, sin(angle))
	var tangent := Vector3(-radial.z, 0.0, radial.x)
	var anchor := Vector3(base.x, y, base.y) \
		+ radial * (STAIR_RADIUS + STEP_WIDTH * 0.5 + 0.34)
	var oak := _stone(Color(0.29, 0.16, 0.07))
	var iron := _metal(Color(0.11, 0.12, 0.14))
	var flame_material := StandardMaterial3D.new()
	flame_material.albedo_color = Color(1.0, 0.48, 0.08)
	flame_material.emission_enabled = true
	flame_material.emission = Color(1.0, 0.19, 0.025)
	flame_material.emission_energy_multiplier = 2.2

	var bracket := _visual_chord(torch,
		anchor + radial * 0.02 + Vector3.UP * 0.56,
		anchor + radial * 0.58 + Vector3.UP * 0.92, 0.13, oak)
	bracket.name = "TorchWoodBracket"
	var basket := MeshInstance3D.new()
	basket.name = "TorchIronBasket"
	var basket_mesh := CylinderMesh.new()
	basket_mesh.top_radius = 0.27
	basket_mesh.bottom_radius = 0.18
	basket_mesh.height = 0.34
	basket_mesh.radial_segments = 6
	basket.mesh = basket_mesh
	basket.material_override = iron
	torch.add_child(basket)
	basket.global_position = anchor + radial * 0.62 + Vector3.UP * 1.06
	var flame := MeshInstance3D.new()
	flame.name = "TorchFlame"
	var flame_mesh := PrismMesh.new()
	flame_mesh.size = Vector3(0.30, 0.72, 0.30)
	flame.mesh = flame_mesh
	flame.material_override = flame_material
	torch.add_child(flame)
	flame.global_position = basket.global_position + Vector3.UP * 0.47
	flame.rotation.y = atan2(tangent.z, tangent.x)
	torch.set_meta("visual_only", true)


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
	HubLightFade.apply(lamp)
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

	# Defensive fallback for worlds that reuse the stair without Terrain3D --
	# which, on Web, is every world: Terrain3D is freed there entirely before
	# this generator runs, so this is not a rare defensive path there, it is
	# the only ground query Web ever gets. Mask to the one layer that is
	# actually ground (see WebTerrainCompat above) rather than trying to
	# exclude every possible thing the ray could otherwise land on -- this
	# stair climbs a hillside dotted with decorative rock meshes and its own
	# already-built architecture, any of which a blind ray could mistake for
	# the earth.
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, 400.0, z), Vector3(x, -100.0, z))
	query.collision_mask = WebTerrainCompat.WEB_TERRAIN_SCATTER_LAYER
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
