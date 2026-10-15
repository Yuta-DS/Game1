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

# web_terrain_compat.gd's baked ground replacement (WebTerrainCollision) is
# the only thing in the project that sets this bit. _ground_at()'s raycast
# fallback below allowlists it: NewPlayer's CharacterBody3D has no collision
# layer/mask override of its own, so it runs on Godot's plain default (layer
# 1, mask 1) -- moving this file's own architecture to a different layer to
# exclude it from that ray would have made the player fall straight through
# all of it. Allowlisting the one thing that is actually ground sidesteps
# that entirely: it works no matter what layer everything else is on, and
# handles decorative mountain rock and any other stray prop the same way.
const WebTerrainCompat := preload("res://scripts/web_terrain_compat.gd")
const HubLightFade := preload("res://scripts/hub_light_fade.gd")

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
# Shared centre datum for the terrain-level first tread and every continuous
# helix around it. Keeping this in one place prevents the guard, roadbed and
# walking surface from starting above the visible stair again.
const FIRST_TREAD_CENTRE_OFFSET := 0.17
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
		STAIR_RADIUS - STEP_WIDTH * 0.5 + INNER_GUARD_HALF_WIDTH)
	parent.set_meta("outer_guard_lane_face_radius",
		STAIR_RADIUS + STEP_WIDTH * 0.5 - OUTER_GUARD_HALF_WIDTH)
	parent.set_meta("stair_guard_surface_overlap", TREAD_GUARD_OVERLAP)
	parent.set_meta("stair_lane_has_no_barrier_gap", true)

	_build_continuous_ascent(parent, base, ground, top_y, start_angle,
		dark, light, brass)
	_build_grounded_castle_entry(parent, base, first_tread_y, start_angle,
		light, dark)

	for i in _step_count:
		var t := float(i) / float(_step_count - 1)
		var angle := start_angle + t * TAU * TURNS
		var y: float = lerpf(first_tread_y, top_y, t)
		var pos := Vector3(base.x + cos(angle) * TREAD_CENTRE_RADIUS, y,
			base.y + sin(angle) * TREAD_CENTRE_RADIUS)

		# Tread — the surface the player runs on.
		var tread := MeshInstance3D.new()
		tread.name = "StairTread_%03d" % i
		var tm := BoxMesh.new()
		tm.size = Vector3(TREAD_CLEAR_WIDTH, 0.34, tread_depth)
		tread.mesh = tm
		tread.material_override = light if i % 2 == 0 else dark
		parent.add_child(tread)
		tread.global_position = pos
		tread.rotation.y = -angle
		# Collision belongs to the continuous AscentRoadbed. Per-tread rotated
		# boxes overlap into diagonal walls along the inside of the spiral.

		# Riser — the vertical face under the tread. Without this the stair
		# reads as floating planks instead of steps.
		var riser := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(TREAD_CLEAR_WIDTH, STEP_RISE + 0.3, 0.3)
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
	# The far-lane sampling above only checks ground height at the very end of
	# the run, then this box draws one straight line to the first tread. On a
	# hillside that dips below that straight line anywhere in between, the
	# walkway floats with a visible gap underneath. Re-sample the ground along
	# the whole run and deepen the slab so its underside always reaches it,
	# without moving the walkable top surface anyone is already using.
	#
	# Only trust Terrain3D itself for these extra samples. _ground_at() falls
	# back to a bare world ray when Terrain3D is absent -- true on Web, which
	# frees the node entirely -- and that ray has no way to tell the ground
	# apart from a nearby stair tread, wall, or roof (see its own comment).
	# 27 new raycasts along this run made that misread far more likely than the
	# two or three the rest of this function already relied on, which is
	# exactly what produced a Web-only shape once this landed. Skipping the
	# deepening on Web leaves its geometry exactly as it was before this fix;
	# only desktop, where the height data is real, gets the deeper slab.
	var terrain_present := get_parent().get_node_or_null("Environment/Terrain3D") != null
	var ramp_underside_clearance := 0.0
	if terrain_present:
		var ramp_ground_samples := 8
		for step in range(ramp_ground_samples + 1):
			var t: float = float(step) / ramp_ground_samples
			var sample_point: Vector3 = ramp_start.lerp(ramp_end, t)
			for lane_fraction in [-0.48, 0.0, 0.48]:
				var lane_point: Vector3 = sample_point + radial * (TREAD_CLEAR_WIDTH * lane_fraction)
				var ground_here := _ground_at(lane_point.x, lane_point.z)
				ramp_underside_clearance = maxf(ramp_underside_clearance, sample_point.y - ground_here)
	var ramp_extra_depth := ramp_underside_clearance + 0.15 if terrain_present else 0.0
	var ramp_height := 0.30 + ramp_extra_depth
	var ramp_centre := ramp_start.lerp(ramp_end, 0.5) - Vector3(0.0, ramp_extra_depth * 0.5, 0.0)
	var ramp := _oriented_box(entry,
		Vector3(TREAD_CLEAR_WIDTH, ramp_height, ramp_length),
		ramp_centre, ramp_end, light)
	ramp.name = "GroundEntryWalkSurface"
	_add_box_body(ramp, (ramp.mesh as BoxMesh).size)
	ramp.set_meta("smooth_straight_route", true)
	ramp.set_meta("authoritative_collision_surface", true)
	entry.set_meta("surface_start", Vector3(far_centre.x, entry_surface_y, far_centre.z))
	entry.set_meta("surface_end", Vector3(first_centre.x, first_surface_y, first_centre.z))

	# Paired stone newels frame the first step without narrowing the route.
	for side_sign in [-1.0, 1.0]:
		var post_centre: Vector3 = far_centre + radial * side_sign * (TREAD_CLEAR_WIDTH * 0.5 + 0.34)
		var post_ground := _ground_at(post_centre.x, post_centre.z)
		var post_position := Vector3(post_centre.x, post_ground + 0.66, post_centre.z)
		var post := _oriented_box(entry, Vector3(0.52, 1.45, 0.52),
			post_position, post_position + forward, dark)
		post.name = "GroundEntryStoneNewel_%s" % ("Left" if side_sign < 0.0 else "Right")
	_build_ground_entry_balustrades(entry, radial, far_centre,
		first_centre, entry_surface_y, first_surface_y, light)
	entry.set_meta("walkable_from_terrain", true)
	entry.set_meta("barriers_join_spiral", true)
	entry.set_meta("collision_surface_continuous", true)


# Low retaining walls give the straight ground promenade a finished silhouette
# and carry both spiral barriers into the hillside. Each side is one continuous
# sloped piece; the former segmented boxes visibly kinked and left unnecessary
# joins. They remain visual-only and outboard of the authoritative promenade,
# so neither wall nor its cap can catch the player or a loose prop.
func _build_ground_entry_balustrades(parent: Node3D, radial: Vector3,
		far_centre: Vector3, first_centre: Vector3,
		entry_surface_y: float, first_surface_y: float, material: Material) -> void:
	const WALL_HEIGHT := 0.92
	const WALL_THICKNESS := 0.34
	var brass := _metal(Color(0.78, 0.52, 0.18))
	for side_index in 2:
		var side_name := "Inner" if side_index == 0 else "Outer"
		var guard_radius := STAIR_RADIUS - STEP_WIDTH * 0.5 \
			if side_index == 0 else STAIR_RADIUS + STEP_WIDTH * 0.5
		var lateral_offset := guard_radius - STAIR_RADIUS
		var from := far_centre + radial * lateral_offset
		var to := first_centre + radial * lateral_offset
		from.y = entry_surface_y + WALL_HEIGHT * 0.5 - 0.04
		to.y = first_surface_y + WALL_HEIGHT * 0.5 - 0.04
		var centre := from.lerp(to, 0.5)
		var wall := _oriented_box(parent,
			Vector3(WALL_THICKNESS, WALL_HEIGHT, from.distance_to(to) + 0.10),
			centre, to, material)
		wall.name = "GroundEntry%sBarrier" % side_name
		wall.set_meta("visual_only", true)
		wall.set_meta("continuous_slope", true)
		var cap_from := from + Vector3.UP * (WALL_HEIGHT * 0.5)
		var cap_to := to + Vector3.UP * (WALL_HEIGHT * 0.5)
		var cap := _visual_chord(parent, cap_from, cap_to, 0.12, brass)
		cap.name = "GroundEntry%sBarrierCap" % side_name
		cap.set_meta("visual_only", true)


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

	# One continuous walking surface sits 2 cm beneath the visible tread tops.
	# The old collision used a separate rotated box for every
	# tread. Near the inside of the curve, a later box overlaps the preceding
	# one far enough for its leading side to become a diagonal wall; the player
	# could stand on the stair but could not advance (most visibly on the final
	# flight below the crown). A single helix has no transverse box edges to snag
	# the capsule, while the individual meshes preserve the stepped look.
	# The architectural roadbed stays a closed visual volume. Its vertical inner
	# and outer faces are intentionally not part of collision because a capsule
	# travelling around a curve can catch those segmented boundary faces.
	var roadbed := _helix_band_mesh(base, ground, top_y, start_angle,
		TREAD_INNER_RADIUS, TREAD_OUTER_RADIUS, -0.58, -0.12)
	_add_helix_part(parent, "AscentRoadbed", roadbed, dark, false)
	var walk_surface := _helix_walk_surface_mesh(base, ground, top_y, start_angle,
		TREAD_INNER_RADIUS, TREAD_OUTER_RADIUS, 0.15)
	_add_helix_part(parent, "AscentWalkSurface", walk_surface, dark, true)

	var outer_guard := _helix_band_mesh(base, ground, top_y, start_angle,
		outer_edge - OUTER_GUARD_HALF_WIDTH,
		outer_edge + OUTER_GUARD_HALF_WIDTH, -0.62, 1.40, 1.0,
		GUARD_ENTRY_LEAD_T)
	var outer_guard_part := _add_helix_part(parent, "OuterContinuousGuard",
		outer_guard, light, true)
	outer_guard_part.set_meta("bottom_offset", -0.62)
	var outer_cap := _helix_band_mesh(base, ground, top_y, start_angle,
		outer_edge - 0.16, outer_edge + 0.16, 1.40, 1.56, 1.0,
		GUARD_ENTRY_LEAD_T)
	_add_helix_part(parent, "OuterContinuousCap", outer_cap, brass, false)

	var inner_guard := _helix_band_mesh(base, ground, top_y, start_angle,
		inner_edge - INNER_GUARD_HALF_WIDTH,
		inner_edge + INNER_GUARD_HALF_WIDTH, 0.06, 1.28, 1.0,
		GUARD_ENTRY_LEAD_T)
	_add_helix_part(parent, "InnerContinuousGuard", inner_guard, dark, true)
	var inner_cap := _helix_band_mesh(base, ground, top_y, start_angle,
		inner_edge - 0.14, inner_edge + 0.14, 1.28, 1.43, 1.0,
		GUARD_ENTRY_LEAD_T)
	_add_helix_part(parent, "InnerContinuousCap", inner_cap, brass, false)

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
	#
	# end_t previously stopped at 0.96 instead of running the full climb, because
	# a flat top_offset of 1.05 m eventually pokes through CrownDeck's solid
	# centre disc (see _build_crown/_crown_deck_mesh, which floors every angle at
	# this plinth's radius once close enough to the crown) and becomes a solid
	# pillar sitting directly in the final tread-to-crown walking path. That left
	# the last stretch of climb with a rail but no floor behind it: jumping the
	# rail there dropped a player through open space onto nothing short of a much
	# lower turn of the spiral.
	#
	# Clamping the top face to the crown floor's underside (tried and reverted)
	# fixed the fall-through but let the top face converge onto the *bottom*
	# face too, right where they touch the underside: two zero-thickness,
	# opposite-facing quads sitting exactly coincident with CrownDeck itself,
	# which z-fights and reads as an "inverted" patch only visible from below,
	# and gave the player a paper-thin ledge to snag on entering the crown.
	# Instead, end_t is solved so the band's TOP face stops a real clearance gap
	# short of the underside — never touching CrownDeck, never degenerating —
	# and the small remainder of the climb needs no filler at all: by that point
	# the rising spiral itself is close enough to the fixed-height crown floor
	# that there is no longer room for a player-sized pocket to exist there.
	const CROWN_CLEARANCE_GAP := 0.15
	var plinth_climb := top_y - (ground + FIRST_TREAD_CENTRE_OFFSET)
	var plinth_ceiling := crown_floor_underside - CROWN_CLEARANCE_GAP
	var plinth_end_t: float = clampf(
		1.0 - (top_y + 1.05 - plinth_ceiling) / plinth_climb,
		GUARD_ENTRY_LEAD_T, 1.0)
	var inner_plinth := _helix_band_mesh(base, ground, top_y, start_angle,
		TOWER_TOP_RADIUS - 0.05, inner_edge + 0.02, -0.05, 1.05, plinth_end_t,
		GUARD_ENTRY_LEAD_T)
	_add_helix_part(parent, "InnerSafetyPlinth", inner_plinth, dark, true)

	var entry_foundation_mesh := _terrain_fitted_entry_foundation_mesh(base,
		ground, top_y, start_angle, TOWER_BOTTOM_RADIUS - 0.05,
		outer_edge + OUTER_GUARD_HALF_WIDTH)
	var entry_foundation := _add_helix_part(parent,
		"TerrainFittedEntryFoundation", entry_foundation_mesh, light, true)
	entry_foundation.set_meta("terrain_fitted", true)
	entry_foundation.set_meta("foundation_end_t", ENTRY_FOUNDATION_END_T)

	_build_low_poly_stair_growth(parent, base, ground, top_y, start_angle,
		outer_edge)


# Closed low-poly wedge under the first flight. Every bottom corner samples the
# terrain independently, so a hillside that slopes across the stair width can
# never leave the broad floating gap produced by one centre-point datum.
func _terrain_fitted_entry_foundation_mesh(base: Vector2, ground: float,
		top_y: float, start_angle: float, inner_radius: float,
		outer_radius: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SAMPLES := 28
	# Use the lowest measured terrain point as one buried datum. Independent
	# bottoms can interpolate over a small hollow and expose a daylight seam even
	# though both sampled endpoints touch soil.
	var foundation_floor := ground
	for floor_index in SAMPLES + 1:
		var floor_t := lerpf(GUARD_ENTRY_LEAD_T, ENTRY_FOUNDATION_END_T,
			float(floor_index) / float(SAMPLES))
		var floor_angle := start_angle + floor_t * TAU * TURNS
		for floor_radius_value in [inner_radius, outer_radius]:
			var floor_radius: float = float(floor_radius_value)
			var floor_x: float = base.x + cos(floor_angle) * floor_radius
			var floor_z: float = base.y + sin(floor_angle) * floor_radius
			foundation_floor = minf(foundation_floor, _ground_at(floor_x, floor_z))
	foundation_floor -= 0.35
	for sample_index in SAMPLES:
		var t0 := lerpf(GUARD_ENTRY_LEAD_T, ENTRY_FOUNDATION_END_T,
			float(sample_index) / float(SAMPLES))
		var t1 := lerpf(GUARD_ENTRY_LEAD_T, ENTRY_FOUNDATION_END_T,
			float(sample_index + 1) / float(SAMPLES))
		var corners0 := _terrain_foundation_cross_section(base, ground, top_y,
			start_angle, inner_radius, outer_radius, t0, foundation_floor)
		var corners1 := _terrain_foundation_cross_section(base, ground, top_y,
			start_angle, inner_radius, outer_radius, t1, foundation_floor)
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
	return surface.commit()


func _terrain_foundation_cross_section(base: Vector2, ground: float,
		top_y: float, start_angle: float, inner_radius: float,
		outer_radius: float, t: float, foundation_floor: float) -> Array[Vector3]:
	var clamped_t := maxf(t, 0.0)
	var angle := start_angle + t * TAU * TURNS
	var inner_xz := Vector2(base.x + cos(angle) * inner_radius,
		base.y + sin(angle) * inner_radius)
	var outer_xz := Vector2(base.x + cos(angle) * outer_radius,
		base.y + sin(angle) * outer_radius)
	var stair_underside := lerpf(ground + FIRST_TREAD_CENTRE_OFFSET,
		top_y, clamped_t) - 0.58
	var inner_bottom := foundation_floor
	var outer_bottom := foundation_floor
	# The buried start can sit above the mathematical stair underside on a steep
	# patch. Collapse that cross-section into the ground instead of inverting it.
	var inner_top := maxf(stair_underside, inner_bottom + 0.03)
	var outer_top := maxf(stair_underside, outer_bottom + 0.03)
	return [
		Vector3(inner_xz.x, inner_top, inner_xz.y),
		Vector3(outer_xz.x, outer_top, outer_xz.y),
		Vector3(inner_xz.x, inner_bottom, inner_xz.y),
		Vector3(outer_xz.x, outer_bottom, outer_xz.y),
	]


# Visual-only low-poly tree fibres reclaim the outside of the castle ascent.
# They sit beyond the outer guard's finished face, so no branch, leaf or hidden
# collider can enter the player's stair lane.
func _build_low_poly_stair_growth(parent: Node3D, base: Vector2, ground: float,
		top_y: float, start_angle: float, outer_edge: float) -> void:
	var growth := Node3D.new()
	growth.name = "LowPolyStairGrowth"
	parent.add_child(growth)
	var bark := _stone(Color(0.30, 0.19, 0.08))
	var young_bark := _stone(Color(0.22, 0.34, 0.10))
	var leaf_green := _stone(Color(0.24, 0.52, 0.12))
	var leaf_light := _stone(Color(0.42, 0.67, 0.18))
	const FIBRE_COUNT := 2
	const FIBRE_SEGMENTS := 44
	# Straight low-poly chords cut slightly inward between points on a curve.
	# This offset includes that chord depth, keeping the complete fibre visible
	# above the curved outer face instead of burying its middle in the masonry.
	var fibre_radius := outer_edge + OUTER_GUARD_HALF_WIDTH + 0.34
	for fibre_index in FIBRE_COUNT:
		var phase := float(fibre_index) * PI
		for segment_index in FIBRE_SEGMENTS:
			var t0 := lerpf(-0.02, 1.0,
				float(segment_index) / float(FIBRE_SEGMENTS))
			var t1 := lerpf(-0.02, 1.0,
				float(segment_index + 1) / float(FIBRE_SEGMENTS))
			var point0 := _stair_growth_point(base, ground, top_y, start_angle,
				fibre_radius + float(fibre_index) * 0.07, t0, phase)
			var point1 := _stair_growth_point(base, ground, top_y, start_angle,
				fibre_radius + float(fibre_index) * 0.07, t1, phase)
			var fibre := _visual_chord(growth, point0, point1,
				0.16 if fibre_index == 0 else 0.12,
				bark if fibre_index == 0 else young_bark)
			fibre.name = "StairTreeFiber_%d_%02d" % [fibre_index, segment_index]

			if segment_index % 5 == 2:
				var leaf := MeshInstance3D.new()
				leaf.name = "StairTreeLeaf_%d_%02d" % [fibre_index, segment_index]
				var leaf_mesh := PrismMesh.new()
				leaf_mesh.size = Vector3(0.44, 0.70, 0.16)
				leaf.mesh = leaf_mesh
				leaf.material_override = leaf_green if (
					segment_index + fibre_index) % 2 == 0 else leaf_light
				growth.add_child(leaf)
				var middle := point0.lerp(point1, 0.5)
				var radial := Vector3(middle.x - base.x, 0.0,
					middle.z - base.y).normalized()
				leaf.global_position = middle + radial * 0.28 + Vector3.UP * 0.12
				leaf.look_at(leaf.global_position + radial, Vector3.UP)
				leaf.rotation.z += deg_to_rad(-24.0 if fibre_index == 0 else 24.0)


func _stair_growth_point(base: Vector2, ground: float, top_y: float,
		start_angle: float, radius: float, t: float, phase: float) -> Vector3:
	var clamped_t := maxf(t, 0.0)
	var angle := start_angle + t * TAU * TURNS
	var stair_y := lerpf(ground + FIRST_TREAD_CENTRE_OFFSET, top_y, clamped_t)
	var weave_height := 0.48 + sin(t * TAU * 5.0 + phase) * 0.27
	return Vector3(base.x + cos(angle) * radius, stair_y + weave_height,
		base.y + sin(angle) * radius)


func _helix_band_mesh(base: Vector2, ground: float, top_y: float,
		start_angle: float, inner_radius: float, outer_radius: float,
		bottom_offset: float, top_offset: float, end_t: float = 1.0,
		start_t: float = 0.0, ceiling_y: float = INF) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples := maxi(_step_count, 48)
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

		# Verified empirically against _helix_walk_surface_mesh's proven-correct
		# up-facing order (see diag_helix_winding.gd): the four orders below were
		# all backwards — top's generated normal pointed down (-Y) instead of up,
		# and outer face pointed inward instead of away from the tower axis. That
		# is a pre-existing bug in every guard, cap, roadbed, and plinth built
		# from this function (all of them use it), not something introduced this
		# session — it explains both the "inverted, only visible from underneath"
		# look reported everywhere along the stairway and is a very plausible
		# contributor to the capsule-snagging collision behaviour, since
		# inconsistently wound trimesh faces are exactly what makes
		# ConcavePolygonShape3D collision resolution unreliable.
		_add_surface_quad(surface, o0t, o1t, i1t, i0t) # top
		_add_surface_quad(surface, i0b, i1b, o1b, o0b) # underside
		_add_surface_quad(surface, o1b, o1t, o0t, o0b) # outer face
		_add_surface_quad(surface, i0t, i1t, i1b, i0b) # inner face

		if i == 0:
			_add_surface_quad(surface, o0b, o0t, i0t, i0b)
		if i == samples - 1:
			_add_surface_quad(surface, i1t, o1t, o1b, i1b)

	surface.generate_normals()
	return surface.commit()


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


# Finished facade language for the tower: structural stone remains castle,
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
		# Sit flat on a face of the shaft cone (ground - 5 .. top_y). Godot puts
		# the octagon's corners at multiples of 45 deg, so faces are offset by
		# half a side and lie at the apothem; + 0.08 is half the panel depth.
		var tier_ratio := (y - (ground - 5.0)) / maxf(facade_height + 5.0, 0.1)
		var radius := lerpf(TOWER_BOTTOM_RADIUS, TOWER_TOP_RADIUS, tier_ratio) \
			* cos(PI / float(TOWER_SIDES)) + 0.08
		for face_i in 4:
			var angle := TAU * float(face_i) / 4.0 + (PI * 0.25 if tier % 2 else 0.0) \
				+ PI / float(TOWER_SIDES)
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
			# + PI/2 turns the 1.45 m width along the wall and the 0.16 m depth
			# outward; at -angle alone the panel stuck out of the wall like a fin.
			panel.rotation.y = -angle + PI * 0.5

			var frame := MeshInstance3D.new()
			frame.name = "AetherWindowFrame_%d_%d" % [tier, face_i]
			var frame_mesh := TorusMesh.new()
			frame_mesh.inner_radius = 0.48
			frame_mesh.outer_radius = 0.62
			frame_mesh.rings = 12
			frame_mesh.ring_segments = 5
			frame.mesh = frame_mesh
			frame.scale = Vector3(1.0, 1.45, 1.0)
			frame.material_override = brass
			parent.add_child(frame)
			# Ring sits on the panel's outer face with its axis pointing outward.
			frame.global_position = panel.global_position + Vector3.UP * 0.18 \
				+ Vector3(cos(angle), 0.0, sin(angle)) * 0.08
			frame.rotation_degrees = Vector3(90.0, rad_to_deg(-angle + PI * 0.5), 0.0)

			var core := MeshInstance3D.new()
			core.name = "AetherWindowCore_%d_%d" % [tier, face_i]
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
const CROWN_SLAB_HEIGHT := 0.42
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
		crown_surface_y - 0.11, handoff_centre.z)  # 2 cm under the deck: no z-fight
	handoff_visual.look_at(handoff_visual.global_position + stair_end_tangent,
		Vector3.UP)
	handoff_visual.set_meta("visual_role", "fitted_spiral_to_crown_transition")
	_build_crown_arrival_court(parent, base, crown_surface_y, stair_end_radial,
		stair_end_tangent, deck_material, brass, cyan, violet)

	# A box-shaped, collision-backed threshold carries the real player capsule
	# across the generated CrownDeck's radial triangle seam and overlaps the
	# LumenBridgeLaunch. The concave deck remains the correctly cut visual floor,
	# but its centreline seam could let the capsule sink into the slab and pin it
	# against a vertical triangle edge. This authoritative apron sits on the
	# bridge sector only; the spiral stairwell opens on a different sector, so
	# its final-flight headroom stays untouched.
	var gateway_apron_size := Vector3(BRIDGE_WIDTH + 0.6, 0.28, 5.8)
	# Top sits 2 cm under the CrownDeck surface; flush, the two z-fought.
	var gateway_apron_centre := Vector3(base.x, crown_surface_y - 0.16, base.y) \
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
		deck_material: Material, brass: Material, cyan: Material,
		violet: Material) -> void:
	var court := Node3D.new()
	court.name = "CrownArrivalCourt"
	parent.add_child(court)

	var origin := Vector3(base.x, surface_y, base.y) \
		+ radial * 5.7 + forward * 2.0
	var carpet := _oriented_box(court, Vector3(3.45, 0.07, 3.55),
		origin + Vector3.UP * 0.035, origin + forward, _stone(STONE_DARK))
	carpet.name = "CrownArrivalCarpet"
	carpet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var threshold := _oriented_box(court, Vector3(3.7, 0.10, 0.34),
		Vector3(base.x, surface_y + 0.05, base.y) + radial * STAIR_RADIUS
			+ forward * 0.18,
		Vector3(base.x, surface_y + 0.05, base.y) + radial * STAIR_RADIUS
			+ forward, brass)
	threshold.name = "CrownArrivalThreshold"

	var apex := origin + forward * 0.18 + Vector3.UP * 4.45
	for signed_value in [-1.0, 1.0]:
		var signed: float = signed_value
		var pylon_base := origin + radial * signed * 2.15 + forward * 0.15

		var plinth := MeshInstance3D.new()
		plinth.name = "CrownArrivalPlinth_%s" % ("Inner" if signed < 0.0 else "Outer")
		var plinth_mesh := CylinderMesh.new()
		plinth_mesh.top_radius = 0.52
		plinth_mesh.bottom_radius = 0.64
		plinth_mesh.height = 0.34
		plinth_mesh.radial_segments = 8
		plinth.mesh = plinth_mesh
		plinth.material_override = deck_material
		court.add_child(plinth)
		plinth.global_position = pylon_base + Vector3.UP * 0.17
		_add_cylinder_collision(plinth, 0.64, 0.34)

		var pylon := MeshInstance3D.new()
		pylon.name = "CrownArrivalPylon_%s" % ("Inner" if signed < 0.0 else "Outer")
		var pylon_mesh := CylinderMesh.new()
		pylon_mesh.top_radius = 0.30
		pylon_mesh.bottom_radius = 0.40
		pylon_mesh.height = 3.15
		pylon_mesh.radial_segments = 8
		pylon.mesh = pylon_mesh
		pylon.material_override = _stone(STONE_LIGHT)
		court.add_child(pylon)
		pylon.global_position = pylon_base + Vector3.UP * 1.74
		# Solid ground-level post; the collar/yoke/lumen arching overhead and the
		# apex lens stay collision-free (this is the "outside the capsule lane"
		# part the class doc comment above refers to).
		_add_cylinder_collision(pylon, 0.40, 3.15)

		var collar := MeshInstance3D.new()
		collar.name = "CrownArrivalCollar_%s" % ("Inner" if signed < 0.0 else "Outer")
		var collar_mesh := TorusMesh.new()
		collar_mesh.inner_radius = 0.34
		collar_mesh.outer_radius = 0.45
		collar_mesh.rings = 10
		collar_mesh.ring_segments = 4
		collar.mesh = collar_mesh
		collar.material_override = brass
		court.add_child(collar)
		collar.global_position = pylon_base + Vector3.UP * 2.55

		var shoulder := pylon_base + Vector3.UP * 3.32
		var yoke := _visual_chord(court, shoulder, apex, 0.20, brass)
		yoke.name = "CrownArrivalYoke_%s" % ("Inner" if signed < 0.0 else "Outer")
		var lumen := _visual_chord(court,
			shoulder + forward * 0.12 - Vector3.UP * 0.10,
			apex + forward * 0.12 - Vector3.UP * 0.10, 0.07, cyan)
		lumen.name = "CrownArrivalLumen_%s" % ("Inner" if signed < 0.0 else "Outer")

	var crown_lens := MeshInstance3D.new()
	crown_lens.name = "CrownArrivalLens"
	var lens_mesh := PrismMesh.new()
	lens_mesh.size = Vector3(0.48, 0.78, 0.32)
	crown_lens.mesh = lens_mesh
	crown_lens.material_override = violet
	court.add_child(crown_lens)
	crown_lens.global_position = apex + Vector3.UP * 0.12
	crown_lens.look_at(crown_lens.global_position + forward, Vector3.UP)

	# Flush guide lights visually lead away from the stair. They never become
	# bumps because they remain within the same 7 cm inlay band as the carpet.
	for guide_index in 3:
		var guide := MeshInstance3D.new()
		guide.name = "CrownArrivalGuide_%d" % guide_index
		var guide_mesh := BoxMesh.new()
		guide_mesh.size = Vector3(0.22, 0.075, 0.42)
		guide.mesh = guide_mesh
		guide.material_override = cyan if guide_index % 2 == 0 else violet
		court.add_child(guide)
		guide.global_position = origin - forward * 1.15 \
			+ forward * float(guide_index) * 1.05 + Vector3.UP * 0.04
		guide.look_at(guide.global_position + forward, Vector3.UP)
		guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
	# One shared angular grid for the ring, outer shelf and centre disc. Each used
	# to start at a different angle, so their vertices missed along the shared
	# circles and T-junction cracks let the terrain show through the floor.
	var wedge_span := cut_end - cut_start
	var wedge_segments := maxi(1, roundi(float(segments) * absf(wedge_span) / full_turn))
	var full_angles: Array[float] = angles.duplicate()
	for i in range(1, wedge_segments + 1):
		full_angles.append(lerpf(cut_start, cut_end, float(i) / float(wedge_segments)))

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
	for i in range(full_angles.size() - 1):
		var a0: float = full_angles[i]
		var a1: float = full_angles[i + 1]
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
	for i in range(full_angles.size() - 1):
		var a0: float = full_angles[i]
		var a1: float = full_angles[i + 1]
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
	# 0.40 tall keeps the top 4 cm under the terrace (67.97) and roadbed (67.95);
	# at 0.48 it sat exactly on the terrace plane and z-fought (striped floor).
	var landing_size := Vector3(BRIDGE_WIDTH + 1.0, 0.40, 3.4)
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
