# The Art Castle's front door: an arrival plaza, and the place the player is
# returned to when they leave the gallery.
#
# Two jobs that belong together, because both are defined by one point — the
# castle's real door face at CASTLE_DOOR.
#
# 1. Arrival. change_scene_to_file rebuilds the hub from disk, so leaving the
#    gallery always dropped the player at the hub's authored start position
#    (4.6, 25.1, 0) — ground level, on the far side of the map from the castle
#    they had just walked out of, with the whole tower and stair to climb again.
#    Global.pending_spawn_point carries the intent across the scene swap and is
#    consumed here.
#
# 2. Architecture. What was there before was the bridge simply ending at an
#    invisible trigger box. This builds the thing a castle door deserves: a
#    stepped landing, a flanking gatehouse, banners, lamps and an arch, in the
#    project's established magic-and-machine language — carved stone and brass
#    as one object, never two styles side by side (same rule as
#    hub_isle_dressing.gd).
#
# Built at runtime like hub_magitech.gd and hub_castle_stairs.gd, so
# New_Hub_World.tscn stays untouched and the whole entrance can be removed by
# deleting one node.
extends Node3D

const CrystalShader := preload("res://shaders/artea_crystal.gdshader")
const RuneShader := preload("res://shaders/artea_rune_circle.gdshader")

# The spawn point name gallery exits ask for. Kept as a constant so the two
# sides of the handoff cannot drift apart via a typo in an exported string.
const SPAWN_POINT := "castle_front_door"

# The castle's real doorway, in world space. Must match
# hub_castle_stairs.CASTLE_DOOR — the causeway lands here.
#
# This is the lower entrance-axis datum retained for the court, gate and
# causeway. The actual imported doorway is CASTLE_THRESHOLD, 9.0 m higher.
const CASTLE_DOOR := Vector3(-39.8, 69.33, 27.41)

# The castle model is deliberately raised above its entrance court. The lower
# datum keeps the approach, gate and causeway where they are; this is the real
# imported doorway reached by the final central ascent.
const CASTLE_RISE := 9.0
const CASTLE_THRESHOLD := CASTLE_DOOR + Vector3.UP * CASTLE_RISE

# The door faces world +X, so the plaza extends outward along +X and its width
# runs along Z.
const OUT := Vector3.RIGHT
const ALONG := Vector3.BACK

# The courtyard is a place, not a landing strip. It was 9 x 11, barely wider
# than the doorway, which is why it read as a bare grey deck rather than
# somewhere the player has arrived.
# PLAZA_LENGTH covers BOTH tiers plus the stair between them:
#   [0 .. UPPER_LENGTH] upper court, then GRAND_STAIR_RUN, then the terrace.
# At 15.0 the terrace was left only 3.2 m deep — too cramped to arrive on and
# far too small for the fountain it carries. 24.0 gives it 12.2 m.
const PLAZA_LENGTH := 22.4 # Ends at the real bridge mouth, not a ledge beyond it.
const PLAZA_WIDTH := 19.0
const PLAZA_THICKNESS := 0.6

# The approach is TIERED, not one flat slab.
#
# A single deck meant the player stepped off the causeway and walked on the
# level straight to the door — nothing was revealed, and the courtyard read as
# a platform with props on it. Now the causeway lands on a lower arrival
# terrace, a broad ceremonial stair climbs from it, and the upper court holds
# the fountain and the door. The castle grows as you climb toward it.
#
# Measured outward from the door: [0 .. UPPER_LENGTH] is the upper court,
# then the stair, then the arrival terrace out to PLAZA_LENGTH.
#
# UPPER_DECK_Y is the lower entrance-court datum. The castle now stands above
# it at CASTLE_THRESHOLD.y, joined by _build_castle_ascent().
const UPPER_DECK_Y := CASTLE_DOOR.y

# How far the arrival terrace sits below the upper court. Made up by the
# ceremonial stair. Must equal hub_castle_stairs.CEREMONIAL_RISE, and
# CASTLE_DOOR.y - CEREMONIAL_RISE must equal hub_castle_stairs.TERRACE_DECK_Y
# — both files share one arrival level.
const CEREMONIAL_RISE := 1.6
const TERRACE_DECK_Y := UPPER_DECK_Y - CEREMONIAL_RISE

const UPPER_LENGTH := 8.4
const GRAND_STAIR_STEPS := 7
const GRAND_STAIR_RUN := 3.4     # horizontal depth of the whole flight
const TERRACE_WIDTH := 15.0      # narrower than the upper court, so it reads as an approach
const RoyalCourt := preload("res://scripts/castle_royal_courtyard.gd")
# Match the established clear doorway route. The former 7.4 m span dominated
# the facade and visually covered the Art Castle door from the approach.
const CASTLE_ASCENT_WIDTH := 4.8
const CASTLE_THRESHOLD_WIDTH := 5.2

# The imported doorway is at the top of the final ascent, not on the lower
# entrance court. Keep doorway furniture on that raised threshold while court
# furniture remains grounded on UPPER_DECK_Y. Previously both used zero here,
# leaving the arch and gatehouse nine metres below the door and visually buried
# behind the last flight of stairs.
const DOOR_LEVEL := Vector3.UP * CASTLE_RISE
const COURT_LEVEL := Vector3.ZERO

# Where the player is set down when they leave the gallery: on the UPPER court
# just outside the door, facing out over the stair, the fountain and the
# kingdom beyond. That is the view worth arriving to.
#
# Also past the castle's 16.5 m floating foundation — the door is 11.6 m from
# the castle centre, so a short step out still leaves the player standing over
# rock.
const SPAWN_OFFSET := Vector3(7.0, 1.2, 0.0)

# Shared with the stair so the entrance reads as the same construction.
const STONE_LIGHT := Color(0.46, 0.54, 0.66)
# Deck tone, deliberately darker than STONE_LIGHT. The hub's sun is strong and
# a pale deck of this size blows out to flat white.
const STONE_MID := Color(0.36, 0.43, 0.55)
const STONE_DARK := Color(0.24, 0.29, 0.39)
const BRASS := Color(0.76, 0.52, 0.20)
const ROOF_RED := Color(0.79, 0.25, 0.20)
const RAIL_GLOW := Color(1.00, 0.72, 0.30)
const CIRCUIT_CYAN := Color(0.24, 0.88, 1.00)
const RUNE_VIOLET := Color(0.72, 0.42, 1.00)
const HEDGE_GREEN := Color(0.30, 0.55, 0.28)
const WATER_BLUE := Color(0.36, 0.72, 0.92)

const STAGE_AWAKE := [0.10, 0.35, 0.58, 0.80, 1.00]
const WAKE_SECONDS := 2.5

var _crystal_materials: Array[ShaderMaterial] = []
var _rune_materials: Array[ShaderMaterial] = []
var _glow_materials: Array[StandardMaterial3D] = []
var _banners: Array[Node3D] = []
var _gears: Array[Node3D] = []

# Nodes that hover in place. Their rest height is captured on the first
# _process so the bob is relative to wherever they were built.
var _floaters: Array[Node3D] = []
var _live_flames: Array[MeshInstance3D] = []
var _gear_speed := 0.0
var _sway_time := 0.0


func _ready() -> void:
	# The castle, its stair and its bridge settle first; building after a frame
	# keeps the plaza aligned with where they actually ended up.
	await get_tree().process_frame
	await get_tree().physics_frame

	# Anchored to the same fixed CASTLE_DOOR constant the stair and bridge use,
	# rather than to the castle node: the castle has a 0.32 m idle drift, and a
	# plaza that follows it would grind against the bridge that does not.
	_build_entrance()
	apply_stage(_current_stage())

	# Placement happens after the entrance exists, so the player always lands on
	# real collision rather than falling through a plaza built a frame later.
	_apply_pending_spawn()


func _process(delta: float) -> void:
	_sway_time += delta

	# Banners breathe in the wind. Cheap (a rotation on a handful of nodes) and
	# it stops the entrance reading as a frozen diorama.
	for i in _banners.size():
		_banners[i].rotation.z = sin(_sway_time * 0.9 + float(i) * 1.7) * 0.06

	# The castle redesign frees the gears and floating orbs it does not use
	# (castle_redesign.gd _remove_piece), so skip any that are gone.
	if not is_zero_approx(_gear_speed):
		for i in _gears.size():
			if not is_instance_valid(_gears[i]):
				continue
			var direction := 1.0 if i % 2 == 0 else -1.0
			_gears[i].rotate_y(_gear_speed * direction * delta)

	# The fountain core hovers inside its armature. Rest height is stored on the
	# node the first time it is seen, so this works no matter where it was built.
	for i in _floaters.size():
		if not is_instance_valid(_floaters[i]):
			continue
		var floater := _floaters[i]
		if not floater.has_meta("rest_y"):
			floater.set_meta("rest_y", floater.global_position.y)
		var rest_y: float = floater.get_meta("rest_y")
		floater.global_position.y = rest_y \
			+ sin(_sway_time * 1.1 + float(i) * 2.3) * 0.18
		floater.rotate_y(delta * 0.5)

	# Each courtyard flame has its own height pulse and sideways lick. Keeping
	# the rest transform as metadata prevents cumulative animation drift.
	for flame in _live_flames:
		var phase: float = flame.get_meta("phase")
		var rest_position: Vector3 = flame.get_meta("rest_position")
		var base_scale: Vector3 = flame.get_meta("base_scale")
		var pulse := 1.0 + sin(_sway_time * 5.2 + phase) * 0.14
		flame.position = rest_position + Vector3(
			sin(_sway_time * 3.7 + phase) * 0.045,
			sin(_sway_time * 6.1 + phase * 1.3) * 0.075,
			cos(_sway_time * 4.1 + phase) * 0.045
		)
		flame.scale = Vector3(base_scale.x / pulse, base_scale.y * pulse, base_scale.z / pulse)
		flame.rotation.y = sin(_sway_time * 2.8 + phase) * 0.22


# --- arrival -----------------------------------------------------------

# Consumes a pending spawn request and places the player on the plaza. Only
# claims the request when it names THIS entrance, so other arrival points can
# be added later without competing for it.
func _apply_pending_spawn() -> void:
	# Global is an autoload, but this scene is also instantiated standalone by
	# the integration tests, where a missing singleton must degrade to "no
	# handoff" rather than crash. Same /root lookup the other hub systems use.
	var global := get_node_or_null("/root/Global")
	if global == null or not global.has_method("consume_spawn_point"):
		return
	if global.pending_spawn_point != SPAWN_POINT:
		return
	global.consume_spawn_point()

	var player := _find_player()
	if player == null:
		push_warning("hub_castle_entrance: no player to place at the front door")
		return

	player.velocity = Vector3.ZERO
	player.global_position = get_spawn_position()

	# Keep the CharacterBody's movement basis in world space. Face the visible
	# character and its camera toward the plaza without rotating the root.
	var outward_yaw := atan2(OUT.x, OUT.z)
	var visual := player.get_node_or_null("RogueSkin") as Node3D
	if visual != null:
		visual.global_rotation.y = outward_yaw
	var camera_controller := player.get_node_or_null("CameraController") as Node3D
	if camera_controller != null:
		camera_controller.global_rotation.y = -outward_yaw


# Public so a portal, a test, or a future fast-travel system can ask where this
# entrance puts the player without duplicating the offset maths.
func get_spawn_position() -> Vector3:
	return CASTLE_DOOR + OUT * SPAWN_OFFSET.x \
		+ Vector3(0.0, SPAWN_OFFSET.y, 0.0) + ALONG * SPAWN_OFFSET.z


func _find_player() -> CharacterBody3D:
	for group in ["player", "Player"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is CharacterBody3D:
				return node
	return get_parent().get_node_or_null("NewPlayer") as CharacterBody3D


# --- construction ------------------------------------------------------

func _build_entrance() -> void:
	var rig := Node3D.new()
	rig.name = "CastleEntrance"
	add_child(rig)

	_build_plaza(rig)
	_build_castle_ascent(rig)
	_build_court_turrets(rig)
	_build_courtyard(rig)
	_build_lamps(rig)
	_build_rune_seal(rig)


# The two decks and the ceremonial stair between them, plus the mass that
# holds them up. The old single slab hung in the air with a razor edge over
# open grass, which is most of why it read as a placeholder platform rather
# than a built place.
func _build_plaza(parent: Node3D) -> void:
	var terrace_start := UPPER_LENGTH + GRAND_STAIR_RUN
	var terrace_length := PLAZA_LENGTH - terrace_start

	# --- upper court: the level the door opens onto, flush with the real threshold ---
	var upper_deck := CASTLE_DOOR + OUT * (UPPER_LENGTH * 0.5)
	var upper := _box(parent,
		Vector3(UPPER_LENGTH, PLAZA_THICKNESS, PLAZA_WIDTH),
		upper_deck - Vector3(0.0, 0.45, 0.0), RoyalCourt.stone_material(true))
	upper.name = "CastleUpperCourt"
	upper.set_meta("preserve_castle_finish", true)
	_add_box_body(upper, Vector3(UPPER_LENGTH, PLAZA_THICKNESS, PLAZA_WIDTH))
	_pave(parent, CASTLE_DOOR, UPPER_LENGTH, PLAZA_WIDTH, 3, 5)

	# --- arrival terrace: where the causeway lands, one ceremonial rise below ---
	var terrace_deck := CASTLE_DOOR + OUT * (terrace_start + terrace_length * 0.5) \
		- Vector3(0.0, CEREMONIAL_RISE, 0.0)
	var terrace := _box(parent,
		Vector3(terrace_length, PLAZA_THICKNESS, TERRACE_WIDTH),
		Vector3(terrace_deck.x, RoyalCourt.FLOOR_Y - PLAZA_THICKNESS * 0.5, terrace_deck.z),
		RoyalCourt.stone_material(true))
	terrace.name = "CastleArrivalTerrace"
	terrace.set_meta("preserve_castle_finish", true)
	terrace.set_meta("surface_policy", "single_collision_backed_floor_no_overlay")
	_add_box_body(terrace, Vector3(terrace_length, PLAZA_THICKNESS, TERRACE_WIDTH))
	# One deck now meets the existing bridge landing at 67.97 throughout.
	# No raised receiving rectangle or decorative paver geometry sits above it.

	_build_grand_stair(parent)
	_build_substructure(parent, terrace_start, terrace_length)
	_build_balustrades(parent, terrace_start, terrace_length)


# The ceremonial flight from the arrival terrace up to the door court. Wide,
# shallow, and flanked by solid cheek walls — the thing that makes the door
# feel earned rather than adjacent.
func _build_grand_stair(parent: Node3D) -> void:
	# Regular closed risers meet the actual deck tops, not an old design datum.
	var rig := Node3D.new()
	rig.name = "RoyalCeremonialStair"
	rig.set_meta("preserve_castle_finish", true)
	parent.add_child(rig)
	rig.global_position = Vector3(CASTLE_DOOR.x, RoyalCourt.FLOOR_Y, CASTLE_DOOR.z)
	var stone := RoyalCourt.stone_material()
	var tread_material := _stone(STONE_LIGHT)
	var coping := _stone(Color("b7c7cc"))
	var upper_surface := UPPER_DECK_Y - 0.15
	var rise := upper_surface - RoyalCourt.FLOOR_Y
	var run := GRAND_STAIR_RUN / float(GRAND_STAIR_STEPS)
	var width := PLAZA_WIDTH * 0.62
	for i in GRAND_STAIR_STEPS:
		var top := rise * float(GRAND_STAIR_STEPS - i) / float(GRAND_STAIR_STEPS)
		var step := RoyalCourt.box(rig, "GrandStairTread_%02d" % i,
			Vector3(run, top + 0.35, width),
			Vector3(UPPER_LENGTH + run * (float(i) + 0.5), (top - 0.35) * 0.5, 0),
			tread_material, true)
		step.set_meta("surface_top_y", RoyalCourt.FLOOR_Y + top)
	for side: float in [-1.0, 1.0]:
		var lateral := side * (width * 0.5 + 0.3)
		var points := PackedVector3Array()
		for z: float in [lateral - 0.3, lateral + 0.3]:
			points.append(Vector3(UPPER_LENGTH, -0.35, z))
			points.append(Vector3(UPPER_LENGTH + GRAND_STAIR_RUN, -0.35, z))
			points.append(Vector3(UPPER_LENGTH + GRAND_STAIR_RUN, 1.6, z))
			points.append(Vector3(UPPER_LENGTH, rise + 1.6, z))
		var cheek := RoyalCourt.mesh(rig, "CeremonialClosedCheek", RoyalCourt.prism(points), Vector3.ZERO, stone)
		RoyalCourt.solid(cheek, cheek.mesh.create_convex_shape())
		var cap_points := PackedVector3Array()
		for z: float in [lateral - 0.3, lateral + 0.3]:
			cap_points.append(Vector3(UPPER_LENGTH, rise + 1.47, z))
			cap_points.append(Vector3(UPPER_LENGTH + GRAND_STAIR_RUN, 1.47, z))
			cap_points.append(Vector3(UPPER_LENGTH + GRAND_STAIR_RUN, 1.6, z))
			cap_points.append(Vector3(UPPER_LENGTH, rise + 1.6, z))
		RoyalCourt.mesh(rig, "CeremonialFlushCoping", RoyalCourt.prism(cap_points), Vector3.ZERO, coping)
		var foot := Vector3(UPPER_LENGTH + GRAND_STAIR_RUN - 0.10, 1.02, lateral)
		RoyalCourt.box(rig, "CeremonialFootNewel", Vector3(0.82, 2.04, 0.82), foot, stone, true)
		RoyalCourt.box(rig, "CeremonialNewelCollar", Vector3(0.82, 0.12, 0.82), foot + Vector3.UP * 0.90, coping)
		var roof := CylinderMesh.new()
		roof.top_radius = 0.0
		roof.bottom_radius = 0.64
		roof.height = 0.72
		roof.radial_segments = 4
		var red_cap := RoyalCourt.mesh(rig, "CeremonialNewelRoof", roof,
			foot + Vector3.UP * 1.38, _stone(Color("ef443d")))
		red_cap.rotation.y = PI * 0.25


# One royal flight owns both its visible treads and the player collision.
# The portal builds the matching door and frame at the same upper datum.
func _build_castle_ascent(parent: Node3D) -> void:
	preload("res://scripts/castle_royal_entry.gd").build_stair(parent)


# What holds the courtyard up. The decks previously ended in a razor edge with
# open sky underneath, so the whole thing read as an untextured platform. This
# gives them a battered foundation, corbels under the overhang, and levitation
# anchors that explain a floating court in the project's own language.
func _build_substructure(parent: Node3D, terrace_start: float,
		terrace_length: float) -> void:
	var dark := _stone(STONE_DARK)

	# Battered skirt under each deck: slightly inset and tapering, so the edge
	# reads as thickness rather than a cut.
	var upper_skirt := _box(parent,
		Vector3(UPPER_LENGTH - 0.5, 1.9, PLAZA_WIDTH - 0.5),
		CASTLE_DOOR + OUT * (UPPER_LENGTH * 0.5)
			- Vector3(0.0, 1.65, 0.0), dark)
	upper_skirt.name = "CastleUpperCourtUnderside"
	upper_skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var terrace_skirt := _box(parent,
		Vector3(terrace_length - 0.5, 1.7, TERRACE_WIDTH - 0.5),
		Vector3(CASTLE_DOOR.x + terrace_start + terrace_length * 0.5,
			RoyalCourt.FLOOR_Y - PLAZA_THICKNESS - 0.85, CASTLE_DOOR.z), dark)
	terrace_skirt.name = "CastleArrivalUnderside"
	# This skirt previously used the UPPER court datum, putting its uncollidable
	# top at 68.63 through the player's body. It must end below the real floor.
	terrace_skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Corbels marching along both long edges, under the overhang.
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		for i in 6:
			var t := (float(i) + 0.5) / 6.0
			_box(parent, Vector3(0.9, 0.85, 0.7),
				CASTLE_DOOR + OUT * (UPPER_LENGTH * t)
					+ ALONG * side * (PLAZA_WIDTH * 0.5 - 0.15)
					- Vector3(0.0, 0.95, 0.0), dark)

	# Levitation anchors beneath the terrace: brass rings around a crystal,
	# the same idiom hub_skyrail uses to hold its bridge up.
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var anchor := CASTLE_DOOR + OUT * (terrace_start + terrace_length * 0.5) \
			+ ALONG * side * (TERRACE_WIDTH * 0.32) - Vector3(0.0, 3.4, 0.0)

		var crystal := MeshInstance3D.new()
		var crystal_mesh := SphereMesh.new()
		crystal_mesh.radius = 0.85
		crystal_mesh.height = 2.6
		crystal_mesh.radial_segments = 6
		crystal_mesh.rings = 3
		crystal.mesh = crystal_mesh
		crystal.material_override = _crystal(CIRCUIT_CYAN)
		parent.add_child(crystal)
		crystal.global_position = anchor
		_floaters.append(crystal)

		var ring_host := Node3D.new()
		ring_host.name = "TerraceLevitationAnchor_%s" % ("L" if side < 0.0 else "R")
		parent.add_child(ring_host)
		ring_host.global_position = anchor
		_gears.append(ring_host)

		var ring := MeshInstance3D.new()
		ring.name = "TerraceLevitationRing_%s" % ("L" if side < 0.0 else "R")
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 1.15
		ring_mesh.outer_radius = 1.35
		ring_mesh.rings = 12
		ring_mesh.ring_segments = 5
		ring.mesh = ring_mesh
		ring.material_override = _metal(BRASS)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring_host.add_child(ring)


# Edge protection for both levels. The upper court gets a merloned parapet
# matching the castle; the terrace gets an open balustrade so the view out over
# the kingdom is not walled off.
func _build_balustrades(parent: Node3D, terrace_start: float,
		terrace_length: float) -> void:
	for side_value in [-1.0, 1.0]:
		var side: float = side_value

		# Upper court parapet.
		var edge := CASTLE_DOOR + OUT * (UPPER_LENGTH * 0.5) \
			+ ALONG * side * (PLAZA_WIDTH * 0.5 - 0.3)
		var parapet := _box(parent, Vector3(UPPER_LENGTH, 1.0, 0.55),
			edge + Vector3(0.0, 0.35, 0.0), _stone(STONE_DARK))
		parapet.name = "CastleUpperCourtSideBarrier_%s" % ("L" if side < 0.0 else "R")
		_add_box_body(parapet, Vector3(UPPER_LENGTH, 1.0, 0.55))
		_box(parent, Vector3(UPPER_LENGTH, 0.18, 0.72),
			edge + Vector3(0.0, 0.94, 0.0), _metal(BRASS))

		for m in 5:
			var mt := (float(m) + 0.5) / 5.0
			_box(parent, Vector3(0.9, 0.6, 0.6),
				CASTLE_DOOR + OUT * (UPPER_LENGTH * mt)
					+ ALONG * side * (PLAZA_WIDTH * 0.5 - 0.3)
					+ Vector3(0.0, 1.28, 0.0),
				_stone(STONE_LIGHT))

	# The arrival level uses the solid royal courtyard perimeter, built by
	# castle_redesign after the shared palette is applied. No loose balusters.

# Compact fortified turrets repeat the keep's red roofs, recessed round windows
# and dark string courses. They replace the six tall classical columns and all
# overhead lintels; the central ascent and side garden aisles stay open.
func _build_court_turrets(parent: Node3D) -> void:
	var style := preload("res://scripts/castle_reference_style.gd")
	var rig := Node3D.new()
	rig.name = "KeepCourtTurrets"
	rig.set_meta("preserve_castle_finish", true)
	rig.set_meta("style_reference", "main_castle_compact_red_turrets")
	parent.add_child(rig)
	for side: float in [-1.0, 1.0]:
		for index in 2:
			var turret := Node3D.new()
			turret.name = "CourtTurret_%s_%d" % ["L" if side < 0.0 else "R", index]
			rig.add_child(turret)
			turret.global_position = CASTLE_DOOR + Vector3(1.5 + index * 5.4, -0.15, side * 8.65)
			RoyalCourt.box(turret, "SolidTurretShaft", Vector3(1.7, 3.2, 1.7),
				Vector3(0, 1.6, 0), style.material("wall"), true)
			RoyalCourt.box(turret, "TurretFootCourse", Vector3(1.7, 0.32, 1.7),
				Vector3(0, 0.16, 0), style.material("trim"), true)
			RoyalCourt.box(turret, "TurretCrownCourse", Vector3(1.8, 0.32, 1.8),
				Vector3(0, 3.12, 0), style.material("trim"), true)
			var roof := CylinderMesh.new()
			roof.top_radius = 0.0
			roof.bottom_radius = 1.42
			roof.height = 1.35
			roof.radial_segments = 4
			var cap := RoyalCourt.mesh(turret, "TurretRedRoof", roof,
				Vector3(0, 3.955, 0), style.material("roof"))
			cap.rotation.y = PI * 0.25
			RoyalCourt.solid(cap, roof.create_convex_shape())
			style.window(turret, Vector3(0, 1.7, side * 0.862), Vector3(0, 0, side), 0.62)
			style.window(turret, Vector3(0.862, 1.7, 0), Vector3.RIGHT, 0.62)
			style.cluster(turret, Vector3(0, 0.68, side * 0.862), Vector3(0, 0, side), 0.70)


# Inlaid flagstone checker for one deck. Extracted so both levels are paved the
# same way — a single pale slab clips to flat white under the hub's sun and
# reads as untextured, which is what the first courtyard looked like.
func _pave(parent: Node3D, origin: Vector3, length: float, width: float,
		cols: int, rows: int) -> void:
	for cx in cols:
		for cz in rows:
			if (cx + cz) % 2 == 1:
				continue
			var u := (float(cx) + 0.5) / float(cols)
			var v := (float(cz) + 0.5) / float(rows)
			_box(parent,
				Vector3(length / float(cols) * 0.86, 0.08,
					width / float(rows) * 0.86),
				origin + OUT * (length * u) + ALONG * ((v - 0.5) * width)
					- Vector3(0.0, 0.11, 0.0),
				_stone(STONE_DARK))


# What turns the landing into a courtyard: something at its centre worth
# walking to, and things around its edges that imply the place is used.
#
# The plaza on its own was just paving — correct architecture, no life. An
# aether fountain anchors the middle, planters and benches line the approach,
# and standing braziers mark the walk to the door.
func _build_courtyard(parent: Node3D) -> void:
	# Keep the centre fire and all walking datums unchanged.
	_build_fountain(parent, RoyalCourt.CENTER - Vector3.UP * 0.24)
	var style := preload("res://scripts/castle_reference_style.gd")
	var garden := Node3D.new()
	garden.name = "KeepCourtHerbGarden"
	garden.set_meta("preserve_castle_finish", true)
	garden.set_meta("garden_style", "medieval_enclosed_herb_garden")
	parent.add_child(garden)
	# Reuse the roof/court's low, solid herb beds. The old anonymous hedge
	# spheres were repainted as stone by the legacy presentation pass.
	# Leave a full-width aisle between planting and the outer turret line.
	for side: float in [-1.0, 1.0]:
		for slot in 2:
			var along_t := 0.26 + float(slot) * 0.44
			var spot := CASTLE_DOOR + Vector3(UPPER_LENGTH * along_t, -0.15, side * 5.8)
			RoyalCourt.planter(garden, spot, side, style.material("wall"),
				style.material("trim"), style.material("recess"), style.material("trim"))


# The former 6.8 m fountain basin and orange orb blocked the stair sightline
# and terrace route. Replace both with a compact, animated castle brazier: no
# pool, orbit rings, broad collision disc, or solid orb masquerading as fire.
func _build_fountain(parent: Node3D, centre: Vector3) -> void:
	var fire_beacon := Node3D.new()
	fire_beacon.name = "CastleCourtyardFire"
	parent.add_child(fire_beacon)

	var pedestal := MeshInstance3D.new()
	pedestal.name = "CourtyardFirePedestal"
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.5
	pedestal_mesh.bottom_radius = 0.92
	pedestal_mesh.height = 1.35
	pedestal_mesh.radial_segments = 8
	pedestal.mesh = pedestal_mesh
	pedestal.material_override = _stone(STONE_DARK)
	fire_beacon.add_child(pedestal)
	pedestal.global_position = centre + Vector3(0.0, 0.915, 0.0)
	_add_cylinder_body(pedestal, 0.92, 1.35)

	var bowl := MeshInstance3D.new()
	bowl.name = "CourtyardFireBowl"
	var bowl_mesh := CylinderMesh.new()
	bowl_mesh.top_radius = 0.88
	bowl_mesh.bottom_radius = 0.52
	bowl_mesh.height = 0.34
	bowl_mesh.radial_segments = 10
	bowl.mesh = bowl_mesh
	bowl.material_override = _metal(BRASS)
	fire_beacon.add_child(bowl)
	bowl.global_position = centre + Vector3(0.0, 1.73, 0.0)
	_add_cylinder_body(bowl, 0.88, 0.34)

	var live_flames := Node3D.new()
	live_flames.name = "CourtyardLiveFlames"
	live_flames.set_meta("animation", "real_time_independent_flame_sway")
	fire_beacon.add_child(live_flames)

	# Seven tapered tongues read as actual fire from every approach angle. Two
	# colours and uneven heights preserve the world's low-poly visual language.
	var flame_offsets := [
		Vector3(0.0, 0.0, 0.0),
		Vector3(-0.28, -0.10, 0.08),
		Vector3(0.27, -0.05, 0.12),
		Vector3(-0.08, -0.14, -0.25),
		Vector3(0.17, -0.12, -0.22),
		Vector3(-0.32, -0.20, -0.18),
		Vector3(0.34, -0.18, -0.08),
	]
	for i in flame_offsets.size():
		var flame := MeshInstance3D.new()
		flame.name = "CourtyardFlame_%02d" % i
		var flame_mesh := CylinderMesh.new()
		flame_mesh.top_radius = 0.035
		flame_mesh.bottom_radius = 0.19 if i > 0 else 0.27
		flame_mesh.height = 0.78 + float((i * 3) % 5) * 0.12
		flame_mesh.radial_segments = 5
		flame.mesh = flame_mesh
		flame.material_override = _emissive(
			Color("ffd84a") if i % 3 == 0 else Color("ff6d1f"),
			4.2 if i % 3 == 0 else 3.5
		)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		live_flames.add_child(flame)
		flame.global_position = centre + Vector3(0.0, 2.16, 0.0) + flame_offsets[i]
		flame.set_meta("phase", float(i) * 1.37)
		flame.set_meta("rest_position", flame.position)
		flame.set_meta("base_scale", flame.scale)
		_live_flames.append(flame)

	var core_light := OmniLight3D.new()
	core_light.name = "CourtyardFireLight"
	core_light.light_color = Color("ffb15c")
	core_light.light_energy = 4.2
	core_light.omni_range = 18.0
	core_light.shadow_enabled = false
	fire_beacon.add_child(core_light)
	core_light.global_position = centre + Vector3(0.0, 2.17, 0.0)


func _build_lamps(parent: Node3D) -> void:
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var post_base := CASTLE_DOOR + COURT_LEVEL + OUT * (UPPER_LENGTH - 1.2) \
			+ ALONG * side * (PLAZA_WIDTH * 0.5 - 1.5)

		_box(parent, Vector3(0.22, 3.1, 0.22),
			post_base + Vector3(0.0, 1.25, 0.0), _metal(BRASS))

		var lantern := MeshInstance3D.new()
		var lantern_mesh := SphereMesh.new()
		lantern_mesh.radius = 0.42
		lantern_mesh.height = 1.05
		lantern_mesh.radial_segments = 6
		lantern_mesh.rings = 3
		lantern.mesh = lantern_mesh
		lantern.material_override = _crystal(RAIL_GLOW)
		parent.add_child(lantern)
		lantern.global_position = post_base + Vector3(0.0, 3.1, 0.0)

		# Unshadowed, matching every other traversal light in the hub — the
		# entrance must stay readable without adding shadow-map cost.
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.82, 0.52)
		lamp.light_energy = 2.6
		lamp.omni_range = 13.0
		lamp.shadow_enabled = false
		parent.add_child(lamp)
		lamp.global_position = post_base + Vector3(0.0, 3.1, 0.0)


# The etched circle on the threshold — the same single strongest "magic and
# science are one thing" mark the islands use (hub_isle_dressing._add_rune_disc).
func _build_rune_seal(parent: Node3D) -> void:
	var seal := MeshInstance3D.new()
	seal.name = "ThresholdSeal"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(5.2, 5.2)
	seal.mesh = mesh
	seal.material_override = _rune(RUNE_VIOLET)
	seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(seal)
	# Just above the plaza deck; coplanar would z-fight with the paving.
	seal.global_position = CASTLE_DOOR + COURT_LEVEL + OUT * (UPPER_LENGTH * 0.30) \
		- Vector3(0.0, 0.1, 0.0)


# --- journey stage -----------------------------------------------------

# Called by hub_awakening.gd along with every other castle system, so the
# entrance lights up on the same progression rather than carrying its own.
func apply_stage(stage: int) -> void:
	stage = clampi(stage, 0, STAGE_AWAKE.size() - 1)
	var intensity: float = STAGE_AWAKE[stage]
	_gear_speed = 0.08 + intensity * 0.26

	# hub_awakening applies a stage to this node by name before _ready() has
	# awaited its frame and built the meshes. Creating a tween with nothing to
	# animate raises "started with no Tweeners"; _ready re-applies the same
	# stage once the materials exist. Same guard hub_skyrail.apply_stage uses.
	if _crystal_materials.is_empty() and _rune_materials.is_empty() \
			and _glow_materials.is_empty():
		return

	var tween := create_tween().set_parallel()
	for material in _crystal_materials:
		tween.tween_method(
			func(value: float) -> void:
				material.set_shader_parameter("awake", value),
			float(material.get_shader_parameter("awake")), intensity,
			WAKE_SECONDS).set_trans(Tween.TRANS_SINE)
	for material in _rune_materials:
		tween.tween_method(
			func(value: float) -> void:
				material.set_shader_parameter("awake", value),
			float(material.get_shader_parameter("awake")), intensity,
			WAKE_SECONDS).set_trans(Tween.TRANS_SINE)
	for material in _glow_materials:
		tween.tween_property(material, "emission_energy_multiplier",
			0.4 + intensity * 1.8, WAKE_SECONDS).set_trans(Tween.TRANS_SINE)


func _current_stage() -> int:
	if not is_inside_tree():
		return 0
	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return 0
	return clampi(js.stage, 0, STAGE_AWAKE.size() - 1)


# --- primitives --------------------------------------------------------

func _box(parent: Node3D, size: Vector3, position: Vector3,
		material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = material
	parent.add_child(part)
	# Transform AFTER add_child: setting it first loses it, which is what left
	# earlier runtime structures standing on end instead of lying flat.
	part.global_position = position
	return part


func _add_box_body(host: MeshInstance3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	host.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)


func _add_cylinder_body(host: MeshInstance3D, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	host.add_child(body)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	body.add_child(shape)


func _stone(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	material.metallic = 0.0
	return material


func _metal(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.85
	material.roughness = 0.28
	return material


# Emissive but never fully dark: at stage 0 this still has to read as a lamp,
# not as a black shape against a bright sky.
func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.35)
	material.roughness = 0.25
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	_glow_materials.append(material)
	return material


func _crystal(color: Color) -> Material:
	var material := ShaderMaterial.new()
	material.shader = CrystalShader
	material.set_shader_parameter("awake", 0.0)
	material.set_shader_parameter("core_color", color)
	material.set_shader_parameter("rim_color", color.lightened(0.45))
	_crystal_materials.append(material)
	return material


func _rune(color: Color) -> Material:
	var material := ShaderMaterial.new()
	material.shader = RuneShader
	material.set_shader_parameter("awake", 0.0)
	material.set_shader_parameter("glow_color", color)
	material.set_shader_parameter("accent_color", Color(1.0, 0.82, 0.45))
	# Restrained: these are architectural surfaces read up close, not the
	# island-scale ground discs, so full brightness washes the stone out.
	material.set_shader_parameter("brightness", 0.9)
	_rune_materials.append(material)
	return material
