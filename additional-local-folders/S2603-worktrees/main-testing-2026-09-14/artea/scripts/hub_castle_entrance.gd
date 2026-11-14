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
const PLAZA_LENGTH := 24.0
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
# The timber bridge surface is 0.39 m above the old broad terrace slab. The
# former fix raised only a small rectangle beneath the fire, which left a
# hidden step across the middle of the walking route. Lift the complete usable
# terrace surface so bridge, fire court and stair approach form one floor.
const TERRACE_SURFACE_LIFT := 0.39
# The arrival court is a walkable surface, not a stacked foundation block.
# Keep it thin so its edge matches the bridge and surrounding architecture;
# its top remains fixed at the same 67.97 m collision/render plane.
const TERRACE_SLAB_THICKNESS := 0.32

const UPPER_LENGTH := 8.4
const GRAND_STAIR_STEPS := 7
const GRAND_STAIR_RUN := 3.4     # horizontal depth of the whole flight
const TERRACE_WIDTH := 15.0      # narrower than the upper court, so it reads as an approach
# Match the established clear doorway route. The former 7.4 m span dominated
# the facade and visually covered the Art Castle door from the approach.
const CASTLE_ASCENT_WIDTH := 4.8
const CASTLE_THRESHOLD_WIDTH := 5.2
const CASTLE_ASCENT_RUN := UPPER_LENGTH
# A compact three-tread ceremony at the door. Three 0.6 m rises stay within
# the controller's safe step height and keep the visible staircase short.
const DOOR_STAIR_STEPS := 3
const DOOR_STAIR_RUN := 1.5
const DOOR_STAIR_RISE := 1.8

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
var _fire_flames: Array[Dictionary] = []
var _fire_lights: Array[OmniLight3D] = []

# Nodes that hover in place — currently the fountain's aether core. Their rest
# height is captured on the first _process so the bob is relative to wherever
# they were built.
var _floaters: Array[Node3D] = []
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

	if not is_zero_approx(_gear_speed):
		for i in _gears.size():
			var direction := 1.0 if i % 2 == 0 else -1.0
			_gears[i].rotate_y(_gear_speed * direction * delta)

	# The fountain core hovers inside its armature. Rest height is stored on the
	# node the first time it is seen, so this works no matter where it was built.
	for i in _floaters.size():
		var floater := _floaters[i]
		if not floater.has_meta("rest_y"):
			floater.set_meta("rest_y", floater.global_position.y)
		var rest_y: float = floater.get_meta("rest_y")
		floater.global_position.y = rest_y \
			+ sin(_sway_time * 1.1 + float(i) * 2.3) * 0.18
		floater.rotate_y(delta * 0.5)

	# Each low-poly flame has a slightly different rhythm. The overlapping,
	# pointed silhouettes bend and stretch independently, which reads as live
	# fire without a billboard texture or a GPU-only particle dependency.
	for flame_data in _fire_flames:
		var flame := flame_data["node"] as MeshInstance3D
		var phase := float(flame_data["phase"])
		var speed := float(flame_data["speed"])
		var base_position := flame_data["base_position"] as Vector3
		var base_scale := flame_data["base_scale"] as Vector3
		var pulse := sin(_sway_time * speed + phase)
		var cross_pulse := cos(_sway_time * (speed * 0.73) + phase * 1.31)
		flame.position = base_position + Vector3(
			cross_pulse * float(flame_data["sway"]),
			pulse * 0.07,
			sin(_sway_time * (speed * 0.61) + phase) * float(flame_data["sway"]))
		flame.scale = Vector3(base_scale.x * (1.0 - pulse * 0.10),
			base_scale.y * (1.0 + pulse * 0.18),
			base_scale.z * (1.0 - pulse * 0.10))
		flame.rotation.y += delta * (0.34 + speed * 0.05)
		flame.rotation.z = cross_pulse * 0.10

	for i in _fire_lights.size():
		var fire_light := _fire_lights[i]
		var base_energy := float(fire_light.get_meta("base_energy", 3.0))
		fire_light.light_energy = base_energy * (0.88
			+ sin(_sway_time * 8.7 + float(i) * 2.1) * 0.08
			+ sin(_sway_time * 13.1 + float(i)) * 0.04)


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

	# Keep the CharacterBody root stable, but align both the orbit camera and the
	# visible fox with the doorway's +X outward direction. NewPlayer rotates its
	# Forward input by the camera yaw; facing only RogueSkin outward left the
	# camera at PI, so Forward resolved to +Z and produced a 90-degree sideways
	# slide until the model caught up.
	var outward_yaw := atan2(OUT.x, OUT.z)
	# Camera-relative movement rotates input by the inverse camera yaw, so its
	# convention is the opposite of the visible model's world-facing yaw.
	var camera_yaw := -outward_yaw
	var camera_controller := player.get_node_or_null("CameraController") as Node3D
	if camera_controller != null:
		var camera_rotation := camera_controller.global_rotation
		camera_rotation.y = camera_yaw
		camera_controller.global_rotation = camera_rotation
	var visual := player.get_node_or_null("RogueSkin") as Node3D
	if visual != null:
		var visual_rotation := visual.global_rotation
		visual_rotation.y = outward_yaw
		visual.global_rotation = visual_rotation


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
	_build_colonnade(rig)
	_build_courtyard(rig)
	_build_gatehouse(rig)
	_build_arch(rig)
	_build_lamps(rig)
	_build_banners(rig)
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
		upper_deck - Vector3(0.0, 0.45, 0.0), _stone(STONE_MID))
	upper.name = "CastleUpperCourt"
	upper.set_meta("surface_policy", "single_collision_backed_floor_no_overlay")
	_add_box_body(upper, Vector3(UPPER_LENGTH, PLAZA_THICKNESS, PLAZA_WIDTH))

	# --- arrival terrace: where the causeway lands, one ceremonial rise below ---
	var terrace_deck := CASTLE_DOOR + OUT * (terrace_start + terrace_length * 0.5) \
		- Vector3(0.0, CEREMONIAL_RISE, 0.0)
	# One thin floor, one exact collider. The old construction used a 0.60 m base
	# slab, a separate 0.39 m wearing course, then visual brick tiles. The later
	# single-slab repair removed the overlap but retained their combined 0.99 m
	# depth. This keeps only a 0.32 m structural deck while holding its sole top
	# face at the timber bridge surface (67.97 m).
	var terrace_size := Vector3(
		terrace_length, TERRACE_SLAB_THICKNESS, TERRACE_WIDTH)
	var terrace_surface_offset := -0.15 + TERRACE_SURFACE_LIFT
	var terrace := _box(parent,
		terrace_size,
		terrace_deck + Vector3(0.0,
			terrace_surface_offset - TERRACE_SLAB_THICKNESS * 0.5, 0.0),
		_stone(STONE_MID))
	terrace.name = "CastleArrivalTerrace"
	terrace.set_meta("surface_policy", "single_collision_backed_floor_no_overlay")
	terrace.set_meta("bridge_surface_y", 67.97)
	terrace.set_meta("slab_thickness", TERRACE_SLAB_THICKNESS)
	_add_box_body(terrace, terrace_size)

	_build_grand_stair(parent)
	_build_substructure(parent, terrace_start, terrace_length)
	_build_balustrades(parent, terrace_start, terrace_length)


# The ceremonial flight from the arrival terrace up to the door court. Wide,
# shallow, and flanked by solid cheek walls — the thing that makes the door
# feel earned rather than adjacent.
func _build_grand_stair(parent: Node3D) -> void:
	var light := _stone(STONE_LIGHT)
	var dark := _stone(STONE_DARK)
	var stair_width := PLAZA_WIDTH * 0.62

	for i in GRAND_STAIR_STEPS:
		var t := (float(i) + 0.5) / float(GRAND_STAIR_STEPS)
		# Step 0 is at the TOP (nearest the door) and the flight descends
		# outward, so treads line up with the upper court's edge.
		var out_distance := UPPER_LENGTH + GRAND_STAIR_RUN * t
		var step_y := -CEREMONIAL_RISE * t
		var tread_depth := GRAND_STAIR_RUN / float(GRAND_STAIR_STEPS) + 0.55

		var step := _box(parent,
			Vector3(tread_depth, 0.42, stair_width),
			CASTLE_DOOR + OUT * out_distance
				+ Vector3(0.0, step_y - 0.25, 0.0),
			light if i % 2 == 0 else dark)
		step.name = "GrandStairTread_%02d" % i
		_add_box_body(step, Vector3(tread_depth, 0.42, stair_width))

		# A glowing tread inlay every other step, echoing the spiral stair's
		# wayfinding so the two climbs read as the same architecture.
		if i % 2 == 0:
			var inlay := _box(parent,
				Vector3(tread_depth * 0.34, 0.05, stair_width * 0.72),
				CASTLE_DOOR + OUT * out_distance
					+ Vector3(0.0, step_y - 0.02, 0.0),
				_emissive(CIRCUIT_CYAN, 1.5))
			inlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Cheek walls: solid ramps of masonry down both sides of the flight, capped
	# in brass. Without them the steps float as loose slabs.
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var lateral: float = stair_width * 0.5 + 0.55
		for i in GRAND_STAIR_STEPS:
			var t := (float(i) + 0.5) / float(GRAND_STAIR_STEPS)
			var out_distance := UPPER_LENGTH + GRAND_STAIR_RUN * t
			var step_y := -CEREMONIAL_RISE * t
			var depth := GRAND_STAIR_RUN / float(GRAND_STAIR_STEPS) + 0.6
			var height := 1.15 + (CEREMONIAL_RISE - CEREMONIAL_RISE * t) * 0.35

			var cheek := _box(parent, Vector3(depth, height, 1.1),
				CASTLE_DOOR + OUT * out_distance + ALONG * side * lateral
					+ Vector3(0.0, step_y - 0.45 + height * 0.5, 0.0), dark)
			_add_box_body(cheek, Vector3(depth, height, 1.1))

			_box(parent, Vector3(depth + 0.06, 0.2, 1.26),
				CASTLE_DOOR + OUT * out_distance + ALONG * side * lateral
					+ Vector3(0.0, step_y - 0.45 + height + 0.08, 0.0),
				_metal(BRASS))

		# A newel pillar with a lamp at the foot of each cheek wall, marking
		# the bottom of the flight from across the terrace.
		var foot := CASTLE_DOOR + OUT * (UPPER_LENGTH + GRAND_STAIR_RUN + 0.4) \
			+ ALONG * side * lateral
		var newel := _box(parent, Vector3(1.5, 2.5, 1.5),
			foot + Vector3(0.0, 0.85, 0.0), _stone(STONE_LIGHT))
		_add_box_body(newel, Vector3(1.5, 2.5, 1.5))
		_box(parent, Vector3(1.75, 0.26, 1.75),
			foot + Vector3(0.0, 2.2, 0.0), _metal(BRASS))

		var orb := MeshInstance3D.new()
		var orb_mesh := SphereMesh.new()
		orb_mesh.radius = 0.5
		orb_mesh.height = 1.2
		orb_mesh.radial_segments = 7
		orb_mesh.rings = 4
		orb.mesh = orb_mesh
		orb.material_override = _crystal(RUNE_VIOLET)
		parent.add_child(orb)
		orb.global_position = foot + Vector3(0.0, 2.95, 0.0)
		_floaters.append(orb)

		var orb_light := OmniLight3D.new()
		orb_light.light_color = Color(0.85, 0.66, 1.0)
		orb_light.light_energy = 2.4
		orb_light.omni_range = 13.0
		orb_light.shadow_enabled = false
		parent.add_child(orb_light)
		orb_light.global_position = foot + Vector3(0.0, 2.95, 0.0)


# The long rise is handled by a clean approach ramp, then the final 1.8 m is a
# short three-tread ceremonial stair sized to the Art Castle door. This keeps a
# recognisable stair at the threshold without rebuilding the oversized flight
# that hid the doorway.
func _build_castle_ascent(parent: Node3D) -> void:
	var ramp_run := CASTLE_ASCENT_RUN - DOOR_STAIR_RUN
	var ramp_rise := CASTLE_RISE - DOOR_STAIR_RISE
	var angle := -atan2(ramp_rise, ramp_run)
	var length := Vector2(ramp_run, ramp_rise).length()
	var centre := Vector3(
		CASTLE_DOOR.x + DOOR_STAIR_RUN + ramp_run * 0.5,
		UPPER_DECK_Y + ramp_rise * 0.5,
		CASTLE_DOOR.z)
	var ramp_size := Vector3(length, 0.42, CASTLE_ASCENT_WIDTH)
	var ramp := _box(parent, ramp_size, centre, _stone(STONE_DARK))
	ramp.name = "CastleAscentRamp"
	ramp.global_rotation.z = angle
	_add_box_body(ramp, ramp_size)

	# One restrained centre conduit preserves the established aether language
	# without making the smooth surface read as another run of treads.
	var surface_normal := Vector3(-sin(angle), cos(angle), 0.0)
	var inlay := _box(parent, Vector3(length * 0.88, 0.045,
		CASTLE_ASCENT_WIDTH * 0.46), centre + surface_normal * 0.235,
		_emissive(CIRCUIT_CYAN, 1.35))
	inlay.name = "CastleAscentConduit"
	inlay.global_rotation.z = angle
	inlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var edge := _box(parent, Vector3(length, 0.14, 0.28),
			centre + surface_normal * 0.29
				+ ALONG * side * (CASTLE_ASCENT_WIDTH * 0.5 + 0.12),
			_metal(BRASS))
		edge.global_rotation.z = angle

	# Three restrained stone treads finish the procession. Thin brass nosings
	# and small cyan centre inlays give them detail without turning the doorway
	# into another stack of bright blue bars.
	var tread_depth := DOOR_STAIR_RUN / float(DOOR_STAIR_STEPS)
	for i in DOOR_STAIR_STEPS:
		var surface_y := UPPER_DECK_Y + ramp_rise \
			+ DOOR_STAIR_RISE * float(i + 1) / float(DOOR_STAIR_STEPS)
		var out_distance := DOOR_STAIR_RUN - (float(i) + 0.5) * tread_depth
		var tread_size := Vector3(tread_depth + 0.12, 0.36, CASTLE_ASCENT_WIDTH)
		var tread := _box(parent, tread_size,
			CASTLE_DOOR + OUT * out_distance
				+ Vector3(0.0, surface_y - 0.18, 0.0),
			_stone(STONE_LIGHT if i % 2 == 0 else STONE_MID))
		tread.name = "CastleDoorTread_%02d" % i
		_add_box_body(tread, tread_size)

		var nosing := _box(parent,
			Vector3(0.12, 0.14, CASTLE_ASCENT_WIDTH + 0.16),
			CASTLE_DOOR + OUT * (out_distance + tread_depth * 0.48)
				+ Vector3(0.0, surface_y - 0.07, 0.0), _metal(BRASS))
		nosing.name = "CastleDoorNosing_%02d" % i

		var step_inlay := _box(parent,
			Vector3(tread_depth * 0.42, 0.045, CASTLE_ASCENT_WIDTH * 0.34),
			CASTLE_DOOR + OUT * out_distance
				+ Vector3(0.0, surface_y + 0.025, 0.0),
			_emissive(CIRCUIT_CYAN, 1.2))
		step_inlay.name = "CastleDoorInlay_%02d" % i
		step_inlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Overlap the final compact tread and the imported doorway so there is no seam at
	# the raised threshold.
	# Keep the horizontal threshold entirely BEHIND the ramp endpoint. The old
	# 1.5 m slab was centred 0.45 m outward, so 1.2 m of its vertical front face
	# projected down the 47-degree ascent. The capsule met that face while the
	# top was still ~1.3 m above its feet and became pinned despite both pieces
	# having StaticBody3D collision. Its outward edge now meets the ramp exactly;
	# the controller encounters only a walkable sub-0.65 m transition while the
	# slab continues inward beneath the imported doorway.
	var threshold_size := Vector3(1.4, 0.42, CASTLE_THRESHOLD_WIDTH)
	var threshold := _box(parent, threshold_size,
		CASTLE_THRESHOLD - OUT * 0.7 - Vector3.UP * 0.21, _stone(STONE_LIGHT))
	threshold.name = "RaisedCastleThreshold"
	_add_box_body(threshold, threshold_size)


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
	upper_skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Removed the former 1.7 m terrace skirt. Its top reached 68.63 m while the
	# real walkable plane is 67.97 m, so it rendered 0.66 m through the grounded
	# player and made the fox appear buried in the floor. The thin terrace above
	# is now the only render surface and the only collider at this location.

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

		# Terrace balustrade: baluster posts under a continuous brass rail, so
		# the player can see out over the kingdom while they walk up.
		var rail_y := 1.05
		var terrace_y := -CEREMONIAL_RISE + TERRACE_SURFACE_LIFT
		var terrace_base := _box(parent, Vector3(terrace_length, 0.4, 0.6),
			CASTLE_DOOR + OUT * (terrace_start + terrace_length * 0.5)
				+ ALONG * side * (TERRACE_WIDTH * 0.5 - 0.3)
				+ Vector3(0.0, terrace_y - 0.05, 0.0), _stone(STONE_DARK))
		terrace_base.name = "TerraceBalustradeBase_%s" % ("L" if side < 0.0 else "R")
		var terrace_rail := _box(parent, Vector3(terrace_length, 0.2, 0.75),
			CASTLE_DOOR + OUT * (terrace_start + terrace_length * 0.5)
				+ ALONG * side * (TERRACE_WIDTH * 0.5 - 0.3)
				+ Vector3(0.0, terrace_y + rail_y, 0.0), _metal(BRASS))
		terrace_rail.name = "TerraceBalustradeRail_%s" % ("L" if side < 0.0 else "R")
		_add_safety_barrier(parent,
			"TerraceSideBarrier_%s" % ("L" if side < 0.0 else "R"),
			Vector3(terrace_length, 1.45, 0.62),
			CASTLE_DOOR + OUT * (terrace_start + terrace_length * 0.5)
				+ ALONG * side * (TERRACE_WIDTH * 0.5 - 0.3)
				+ Vector3(0.0, terrace_y + 0.52, 0.0))

		var balusters := 7
		for b in balusters:
			var bt := (float(b) + 0.5) / float(balusters)
			_box(parent, Vector3(0.28, rail_y - 0.2, 0.28),
				CASTLE_DOOR + OUT * (terrace_start + terrace_length * bt)
					+ ALONG * side * (TERRACE_WIDTH * 0.5 - 0.3)
					+ Vector3(0.0, terrace_y + rail_y * 0.5 - 0.05, 0.0),
				_stone(STONE_LIGHT))

	# The two long rails left the outward edge exposed. Close that edge with
	# matching stone-and-brass returns while keeping a 5.6 m central gateway for
	# the 4.8 m timber causeway. These pieces are backed by continuous collision,
	# so the fox cannot slip between decorative balusters.
	var gate_width := 5.6
	var return_span := (TERRACE_WIDTH - gate_width) * 0.5
	var outward_x := terrace_start + terrace_length - 0.3
	var return_rail_y := 1.05
	var return_terrace_y := -CEREMONIAL_RISE + TERRACE_SURFACE_LIFT
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var lateral := gate_width * 0.5 + return_span * 0.5
		var return_centre := CASTLE_DOOR + OUT * outward_x \
			+ ALONG * side * lateral
		var return_base := _box(parent, Vector3(0.6, 0.4, return_span),
			return_centre + Vector3(0.0, return_terrace_y - 0.05, 0.0),
			_stone(STONE_DARK))
		return_base.name = "TerraceGateReturnBase_%s" % ("L" if side < 0.0 else "R")
		var return_rail := _box(parent, Vector3(0.75, 0.2, return_span),
			return_centre + Vector3(0.0, return_terrace_y + return_rail_y, 0.0),
			_metal(BRASS))
		return_rail.name = "TerraceGateReturnRail_%s" % ("L" if side < 0.0 else "R")
		_add_safety_barrier(parent,
			"TerraceGateReturnBarrier_%s" % ("L" if side < 0.0 else "R"),
			Vector3(0.62, 1.45, return_span),
			return_centre + Vector3(0.0, return_terrace_y + 0.52, 0.0))
		for post_index in 3:
			var post_t := (float(post_index) + 0.5) / 3.0
			var post_position := return_centre \
				+ ALONG * (post_t - 0.5) * return_span
			var post := _box(parent, Vector3(0.3, return_rail_y - 0.2, 0.3),
				post_position + Vector3(0.0,
					return_terrace_y + return_rail_y * 0.5 - 0.05, 0.0),
				_stone(STONE_LIGHT))
			post.name = "TerraceGateBaluster_%s_%02d" % [
				"L" if side < 0.0 else "R", post_index]


# A colonnade down both sides of the upper court.
#
# This is the piece that was missing more than any prop: vertical elements
# repeating along the walk. Without them the courtyard was a floor with objects
# scattered on it and the eye had nothing to travel along. Columns give the
# approach rhythm, frame the door, and finally put something at the player's
# own height between the tiny railings and the enormous castle.
func _build_colonnade(parent: Node3D) -> void:
	# 3 per side, not 4: with the gatehouse towers now doing more of the
	# framing work close to the door, a fourth pair of columns crowded the
	# court's short 8.4 m length into a picket fence instead of a rhythm.
	var count := 3
	var lateral := PLAZA_WIDTH * 0.5 - 1.5

	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		for i in count:
			var t := (float(i) + 0.6) / float(count + 0.4)
			var foot := CASTLE_DOOR + COURT_LEVEL + OUT * (UPPER_LENGTH * t) \
				+ ALONG * side * lateral

			# Plinth, shaft, brass collar, capital — a column with parts reads
			# as carved; a single box reads as a post.
			_box(parent, Vector3(1.5, 0.55, 1.5),
				foot + Vector3(0.0, 0.0, 0.0), _stone(STONE_DARK))

			var shaft := MeshInstance3D.new()
			var shaft_mesh := CylinderMesh.new()
			shaft_mesh.top_radius = 0.44
			shaft_mesh.bottom_radius = 0.55
			shaft_mesh.height = 5.2
			shaft_mesh.radial_segments = 8
			shaft.mesh = shaft_mesh
			shaft.material_override = _stone(STONE_LIGHT)
			parent.add_child(shaft)
			shaft.global_position = foot + Vector3(0.0, 2.9, 0.0)
			_add_cylinder_body(shaft, 0.55, 5.2)

			_box(parent, Vector3(1.05, 0.26, 1.05),
				foot + Vector3(0.0, 4.3, 0.0), _metal(BRASS))
			_box(parent, Vector3(1.3, 0.5, 1.3),
				foot + Vector3(0.0, 5.7, 0.0), _stone(STONE_LIGHT))

			# A caged aether lamp hanging off the inner face of each column, so
			# the walk is lit at the player's eye level rather than only from
			# the ground.
			var lamp_pos := foot + ALONG * side * -0.9 + Vector3(0.0, 4.6, 0.0)
			var cage := MeshInstance3D.new()
			var cage_mesh := SphereMesh.new()
			cage_mesh.radius = 0.34
			cage_mesh.height = 0.85
			cage_mesh.radial_segments = 6
			cage_mesh.rings = 3
			cage.mesh = cage_mesh
			cage.material_override = _crystal(RAIL_GLOW)
			parent.add_child(cage)
			cage.global_position = lamp_pos

			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.84, 0.56)
			lamp.light_energy = 1.6
			lamp.omni_range = 9.0
			lamp.shadow_enabled = false
			parent.add_child(lamp)
			lamp.global_position = lamp_pos

			# A short lintel spanning to the next column turns a row of posts
			# into an arcade.
			if i < count - 1:
				var next_t := (float(i) + 1.6) / float(count + 0.4)
				var span := UPPER_LENGTH * (next_t - t)
				_box(parent, Vector3(span, 0.5, 0.75),
					foot + OUT * (span * 0.5) + Vector3(0.0, 6.1, 0.0),
					_stone(STONE_MID))
				_box(parent, Vector3(span * 0.9, 0.16, 0.92),
					foot + OUT * (span * 0.5) + Vector3(0.0, 6.42, 0.0),
					_metal(BRASS))


# What turns the landing into a courtyard: something at its centre worth
# walking to, and things around its edges that imply the place is used.
#
# The plaza on its own was just paving — correct architecture, no life. An
# aether fountain anchors the middle, planters and benches line the approach,
# and standing braziers mark the walk to the door.
func _build_courtyard(parent: Node3D) -> void:
	# Everything here lives on the UPPER court, at the door's own level.
	var up := Vector3.ZERO

	# The fountain lives on the ARRIVAL TERRACE, below the grand stair — not on
	# the upper court. On the upper court it stood squarely on the axis between
	# the stair head and the doorway, so the player had to walk around their own
	# centrepiece to get in, and it hid the door on the climb. Down here it is
	# the thing the player meets when they step off the causeway, and the stair
	# and doorway beyond it stay completely clear.
	var terrace_start := UPPER_LENGTH + GRAND_STAIR_RUN
	var terrace_length := PLAZA_LENGTH - terrace_start
	var centre := CASTLE_DOOR + OUT * (terrace_start + terrace_length * 0.55) \
		- Vector3(0.0, CEREMONIAL_RISE, 0.0)

	# The requested fire replaces the old orange orb at its exact centre point.
	# Its paired side barriers organize traffic into two broad bypass lanes while
	# keeping both the bridge opening and castle-stair opening unobstructed.
	_build_fountain(parent, centre)

	# Planters and benches in matched pairs down both sides of the walk, so the
	# route to the door reads as a deliberate axis rather than open floor.
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		# Inboard of the colonnade (which stands at PLAZA_WIDTH*0.5 - 1.5). A
		# 1.0 m half-width planter against a 0.55 m column radius needs at least
		# 1.55 m of separation or the two intersect.
		var lateral: float = PLAZA_WIDTH * 0.5 - 3.4

		for slot in 2:
			var along_t: float = 0.26 + float(slot) * 0.44
			var spot := CASTLE_DOOR + OUT * (UPPER_LENGTH * along_t) \
				+ ALONG * side * lateral + up

			# Planter: a stone trough with a clipped hedge, the softest thing
			# in an otherwise entirely hard-surfaced scene.
			var trough := _box(parent, Vector3(2.0, 0.7, 2.0),
				spot + Vector3(0.0, 0.20, 0.0), _stone(STONE_LIGHT))
			_add_box_body(trough, Vector3(2.0, 0.7, 2.0))
			_box(parent, Vector3(1.7, 0.24, 1.7),
				spot + Vector3(0.0, 0.60, 0.0), _stone(BRASS.darkened(0.35)))

			var hedge := MeshInstance3D.new()
			var hedge_mesh := SphereMesh.new()
			hedge_mesh.radius = 0.95
			hedge_mesh.height = 1.5
			hedge_mesh.radial_segments = 7
			hedge_mesh.rings = 4
			hedge.mesh = hedge_mesh
			hedge.material_override = _stone(HEDGE_GREEN)
			parent.add_child(hedge)
			hedge.global_position = spot + Vector3(0.0, 1.25, 0.0)

			# A bench between the planters, facing the fountain.
			if slot == 0:
				var bench_spot := CASTLE_DOOR + OUT * (UPPER_LENGTH * 0.52) \
					+ ALONG * side * (lateral + 0.2) + up
				_box(parent, Vector3(0.5, 0.45, 2.6),
					bench_spot + Vector3(0.0, 0.05, 0.0), _stone(STONE_DARK))
				_box(parent, Vector3(1.5, 0.22, 2.9),
					bench_spot + Vector3(0.0, 0.34, 0.0), _stone(STONE_LIGHT))

		# Standing brazier marking the walk to the door: the magitech read,
		# a crystal burning in a brass basin instead of a fire.
		var brazier_spot := CASTLE_DOOR + OUT * (UPPER_LENGTH * 0.16) \
			+ ALONG * side * (PLAZA_WIDTH * 0.5 - 1.9) + up
		_box(parent, Vector3(0.55, 1.5, 0.55),
			brazier_spot + Vector3(0.0, 0.6, 0.0), _metal(BRASS))

		var basin := MeshInstance3D.new()
		var basin_mesh := CylinderMesh.new()
		basin_mesh.top_radius = 0.72
		basin_mesh.bottom_radius = 0.34
		basin_mesh.height = 0.5
		basin_mesh.radial_segments = 8
		basin.mesh = basin_mesh
		basin.material_override = _metal(BRASS)
		parent.add_child(basin)
		basin.global_position = brazier_spot + Vector3(0.0, 1.55, 0.0)

		var ember := MeshInstance3D.new()
		var ember_mesh := SphereMesh.new()
		ember_mesh.radius = 0.42
		ember_mesh.height = 0.95
		ember_mesh.radial_segments = 6
		ember_mesh.rings = 3
		ember.mesh = ember_mesh
		ember.material_override = _crystal(RAIL_GLOW)
		parent.add_child(ember)
		ember.global_position = brazier_spot + Vector3(0.0, 2.0, 0.0)

		var ember_light := OmniLight3D.new()
		ember_light.light_color = Color(1.0, 0.78, 0.45)
		ember_light.light_energy = 2.2
		ember_light.omni_range = 11.0
		ember_light.shadow_enabled = false
		parent.add_child(ember_light)
		ember_light.global_position = brazier_spot + Vector3(0.0, 2.0, 0.0)


# Preserve the authored pedestal and bowl exactly where the orange orb stood;
# only the orb itself is replaced by live fire. This avoids accumulating a new
# fireplace, paving, or barriers around an already composed castle court.
func _build_fountain(parent: Node3D, centre: Vector3) -> void:
	var fire_beacon := Node3D.new()
	fire_beacon.name = "CastleCourtyardFire"
	fire_beacon.set_meta("style", "original_orb_pedestal_live_fire_replacement")
	fire_beacon.set_meta("collision_policy", "solid_original_pedestal")
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
	bowl_mesh.top_radius = 0.92
	bowl_mesh.bottom_radius = 0.58
	bowl_mesh.height = 0.34
	bowl_mesh.radial_segments = 10
	bowl.mesh = bowl_mesh
	bowl.material_override = _metal(BRASS)
	fire_beacon.add_child(bowl)
	bowl.global_position = centre + Vector3(0.0, 1.73, 0.0)
	_add_cylinder_body(bowl, 0.88, 0.34)

	var flames := Node3D.new()
	flames.name = "CourtyardLiveFlames"
	flames.set_meta("animation", "real_time_independent_flame_sway")
	fire_beacon.add_child(flames)
	flames.global_position = centre + Vector3(0.0, 1.89, 0.0)

	var flame_specs := [
		[Vector3(-0.24, 0.43, 0.08), Vector3(0.72, 1.00, 0.72), 0.2, 5.3, 0.09, Color("ff6a1f")],
		[Vector3(0.22, 0.39, -0.10), Vector3(0.66, 0.88, 0.66), 1.4, 6.1, 0.08, Color("ff8a24")],
		[Vector3(0.02, 0.63, 0.02), Vector3(0.80, 1.28, 0.80), 2.7, 5.7, 0.11, Color("ff5a18")],
		[Vector3(-0.08, 0.45, -0.18), Vector3(0.48, 0.82, 0.48), 3.8, 7.0, 0.07, Color("ffc43d")],
		[Vector3(0.15, 0.50, 0.14), Vector3(0.44, 0.92, 0.44), 5.1, 6.6, 0.07, Color("ffd85a")],
		[Vector3(0.00, 0.36, 0.00), Vector3(0.52, 0.72, 0.52), 6.0, 7.6, 0.05, Color("fff0a0")],
	]
	for flame_index in flame_specs.size():
		var spec: Array = flame_specs[flame_index]
		var flame := MeshInstance3D.new()
		flame.name = "CourtyardFlame_%02d" % (flame_index + 1)
		var flame_mesh := CylinderMesh.new()
		flame_mesh.top_radius = 0.025
		flame_mesh.bottom_radius = 0.34
		flame_mesh.height = 0.92
		flame_mesh.radial_segments = 6
		flame.mesh = flame_mesh
		flame.material_override = _emissive(spec[5] as Color, 3.7)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.add_child(flame)
		flame.position = spec[0] as Vector3
		flame.scale = spec[1] as Vector3
		_fire_flames.append({
			"node": flame,
			"base_position": flame.position,
			"base_scale": flame.scale,
			"phase": float(spec[2]),
			"speed": float(spec[3]),
			"sway": float(spec[4]),
		})

	var core_light := OmniLight3D.new()
	core_light.name = "CourtyardFireLight"
	core_light.light_color = Color("ffb15c")
	core_light.light_energy = 4.0
	core_light.omni_range = 15.0
	core_light.shadow_enabled = false
	core_light.set_meta("base_energy", 4.0)
	fire_beacon.add_child(core_light)
	core_light.global_position = centre + Vector3(0.0, 2.48, 0.0)
	_fire_lights.append(core_light)


# Two towers flanking the door. This is what turns "a hole in a wall" into a
# gate: mass on either side, red roofs matching the village, brass machinery
# worked into the stone rather than bolted onto it.
# Scaled down and pulled tight against the door — a flanking tower reads as
# part of the castle facade when it stands shoulder to shoulder with the
# real doorway, not when it out-sizes and out-heights it a few metres out.
# The former 10.3 m towers at 1.45 m shaft radius competed with the castle's
# own mass instead of extending it; this keeps the same silhouette (shaft,
# machined band, roof, finial) at roughly two-thirds the size.
func _build_gatehouse(parent: Node3D) -> void:
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var centre := CASTLE_DOOR + DOOR_LEVEL + OUT * 0.7 + ALONG * side * 3.5

		var shaft := MeshInstance3D.new()
		var shaft_mesh := CylinderMesh.new()
		shaft_mesh.top_radius = 0.85
		shaft_mesh.bottom_radius = 1.05
		shaft_mesh.height = 5.4
		shaft_mesh.radial_segments = 8
		shaft.mesh = shaft_mesh
		shaft.material_override = _stone(STONE_LIGHT)
		parent.add_child(shaft)
		shaft.global_position = centre + Vector3(0.0, 2.3, 0.0)
		_add_cylinder_body(shaft, 1.05, 5.4)

		# Machined band: brass ring plus a rotating gear. Same object as the
		# masonry, which is the whole point of the style.
		var band := MeshInstance3D.new()
		var band_mesh := CylinderMesh.new()
		band_mesh.top_radius = 0.94
		band_mesh.bottom_radius = 0.94
		band_mesh.height = 0.34
		band_mesh.radial_segments = 8
		band.mesh = band_mesh
		band.material_override = _metal(BRASS)
		parent.add_child(band)
		band.global_position = centre + Vector3(0.0, 3.4, 0.0)

		var gear := Node3D.new()
		parent.add_child(gear)
		gear.global_position = centre + Vector3(0.0, 3.4, 0.0)
		_gears.append(gear)
		for tooth in 8:
			var angle := TAU * float(tooth) / 8.0
			var t := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(0.22, 0.19, 0.22)
			t.mesh = tm
			t.material_override = _metal(BRASS)
			t.position = Vector3(cos(angle) * 1.04, 0.0, sin(angle) * 1.04)
			gear.add_child(t)

		var roof := MeshInstance3D.new()
		var roof_mesh := CylinderMesh.new()
		roof_mesh.top_radius = 0.0
		roof_mesh.bottom_radius = 1.28
		roof_mesh.height = 1.7
		roof_mesh.radial_segments = 8
		roof.mesh = roof_mesh
		roof.material_override = _stone(ROOF_RED)
		parent.add_child(roof)
		roof.global_position = centre + Vector3(0.0, 5.85, 0.0)

		# Arrow slit, lit from within — the tower reads as occupied.
		var slit := _box(parent, Vector3(0.15, 1.1, 0.26),
			centre + OUT * 0.9 + Vector3(0.0, 2.7, 0.0), _emissive(RAIL_GLOW, 1.6))
		slit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var finial := MeshInstance3D.new()
		var finial_mesh := SphereMesh.new()
		finial_mesh.radius = 0.24
		finial_mesh.height = 0.68
		finial_mesh.radial_segments = 6
		finial_mesh.rings = 3
		finial.mesh = finial_mesh
		finial.material_override = _crystal(CIRCUIT_CYAN)
		parent.add_child(finial)
		finial.global_position = centre + Vector3(0.0, 6.9, 0.0)


# The arch over the doorway, carrying a keystone crystal. Read as magic from a
# distance, as an aether conduit up close.
func _build_arch(parent: Node3D) -> void:
	var span := 6.6
	var rise := 7.0

	for i in 9:
		var t := float(i) / 8.0
		var angle := PI * t
		var voussoir := _box(parent, Vector3(0.9, 0.85, 0.85),
			CASTLE_DOOR + DOOR_LEVEL + OUT * 0.9
				+ ALONG * (cos(angle) * span * 0.5)
				+ Vector3(0.0, 2.2 + sin(angle) * (rise - 2.2), 0.0),
			_stone(STONE_LIGHT if i % 2 == 0 else STONE_DARK))
		voussoir.rotation.x = angle

	var keystone := MeshInstance3D.new()
	var key_mesh := SphereMesh.new()
	key_mesh.radius = 0.62
	key_mesh.height = 1.75
	key_mesh.radial_segments = 6
	key_mesh.rings = 3
	keystone.mesh = key_mesh
	keystone.material_override = _crystal(RUNE_VIOLET)
	parent.add_child(keystone)
	keystone.global_position = CASTLE_DOOR + DOOR_LEVEL + OUT * 0.9 + Vector3(0.0, rise + 0.5, 0.0)

	# Conduits running the keystone's power down into the gatehouse: the visible
	# explanation for why the arch glows at all.
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var conduit := _box(parent, Vector3(0.16, 4.4, 0.16),
			CASTLE_DOOR + DOOR_LEVEL + OUT * 0.9 + ALONG * side * 3.3
				+ Vector3(0.0, 4.4, 0.0), _metal(BRASS))
		conduit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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


func _build_banners(parent: Node3D) -> void:
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var anchor := CASTLE_DOOR + DOOR_LEVEL + OUT * 1.6 + ALONG * side * 2.6 \
			+ Vector3(0.0, 5.4, 0.0)

		var pivot := Node3D.new()
		parent.add_child(pivot)
		pivot.global_position = anchor
		_banners.append(pivot)

		var cloth := MeshInstance3D.new()
		var cloth_mesh := BoxMesh.new()
		cloth_mesh.size = Vector3(0.09, 3.2, 1.5)
		cloth.mesh = cloth_mesh
		cloth.material_override = _stone(ROOF_RED)
		cloth.position = Vector3(0.0, -1.6, 0.0)
		pivot.add_child(cloth)

		# The sigil on the banner: rune shader, so it wakes with the journey
		# like every other rune surface in the project.
		var sigil := MeshInstance3D.new()
		var sigil_mesh := PlaneMesh.new()
		sigil_mesh.size = Vector2(1.1, 1.1)
		sigil.mesh = sigil_mesh
		sigil.rotation_degrees = Vector3(90.0, 0.0, 90.0)
		sigil.position = Vector3(0.09, -1.5, 0.0)
		sigil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sigil.material_override = _rune(CIRCUIT_CYAN)
		pivot.add_child(sigil)


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


# Decorative balusters remain visually open, but the safety line behind them
# must behave as one wall. A single simple box prevents capsule snagging on a
# row of tiny post colliders and closes gaps without adding another visible
# mesh to the castle composition.
func _add_safety_barrier(parent: Node3D, barrier_name: String,
		size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = barrier_name
	body.set_meta("collision_policy", "continuous_non_snag_safety_barrier")
	parent.add_child(body)
	body.global_position = position
	var shape := CollisionShape3D.new()
	shape.name = "ContinuousBarrierShape"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


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
