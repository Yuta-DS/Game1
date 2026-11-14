# Sky Isles click-to-travel: the headline traversal mechanic. Clicking a
# train or a station rides the camera along that line's rail curve to the
# destination island and hands control back there.
#
# Routing decision — HUB-AND-SPOKE ONLY, no kingdom-to-kingdom pathing:
# rail_network.gd only ever builds three lines (castle<->mind, castle<->heart,
# castle<->creator per CONTRACT.md); there is no direct kingdom<->kingdom
# curve to ride. Rather than silently stitching two tween legs together
# end-to-end (which would need to synthesize a mid-flight camera snap at the
# castle platform that nothing in the contract specifies the look of), a
# kingdom->kingdom travel_to() call is DISALLOWED with a clear push_warning
# explaining the caller must route via "castle" first. This matches how a
# real hub-and-spoke railway works: you change trains at the hub, you don't
# get a one-ticket through service between spokes. Callers (debug panel,
# future gameplay) that want kingdom->kingdom simply issue two travel_to()
# calls in sequence, using travel_finished as the cue for the second leg.
#
# Orbit-camera handoff: sky_isles_world.gd's _update_camera_transform() only
# ever runs from _ready() and from _unhandled_input() (drag/zoom). It never
# runs on a timer or _process, so as long as this script consumes the input
# events that would trigger it while a ride is in progress, the orbit rig
# simply never gets called mid-ride — nothing to fight. Concretely:
#   - _lock_input() sets _travel_active = true and this script's own
#     _unhandled_input marks mouse-button/motion/wheel events as handled
#     (set_input_as_handled) whenever a ride is active, which prevents them
#     from reaching sky_isles_world.gd's own _unhandled_input at all (Godot
#     delivers _unhandled_input to nodes in the same pass; once an event is
#     marked handled, later handlers in that pass skip it).
#   - During the ride this script drives $CameraRig's position directly
#     every frame from the sampled curve transform, exactly the same
#     property _update_camera_transform() writes, so there is only ever one
#     writer active at a time.
#   - On arrival, the rig is left parked at camera_anchor and the orbit
#     state (_orbit_yaw/_orbit_pitch/_orbit_distance) is NOT touched by this
#     script — sky_isles_world.gd still owns those fields. Since nothing
#     recomputes the rig position from them until the next drag/zoom input,
#     the camera stays exactly where travel left it until the player next
#     orbits, at which point the orbit rig recentres around world origin
#     from its last stored yaw/pitch/distance — an acceptable, documented
#     handoff, not a crash or a snap.
#
# Runtime-authored per CONTRACT.md rule 2; this node has no children of its
# own besides what it builds.
extends Node3D

signal travel_started(from_id: String, to_id: String)
signal travel_finished(isle_id: String)

const RIDE_SECONDS := 4.0
const KINGDOM_IDS := ["mind", "heart", "creator"]

# How close (screen pixels) a click needs to land to an island's platform_pos
# projection to count as "clicked the station". Islands have no collision
# bodies (isle_castle.gd / isle_kingdoms.gd are pure MeshInstance3D, per
# CONTRACT.md's "runtime authoring only" + performance budget — no physics
# bodies were part of either agent's brief), so a physics raycast can never
# hit a station the way it hits a train's Area3D. Screen-space proximity to
# the known platform_pos is a self-contained substitute that needs no other
# file touched.
const STATION_CLICK_PIXELS := 48.0

var _world: Node = null
var _rail: Node = null
var _camera_rig: Node3D = null

var _current_isle: String = "castle"
var _travel_active: bool = false


func _ready() -> void:
	# Sibling nodes (rail_network, and the world root itself) may not have
	# finished their own _ready() yet depending on scene tree build order.
	# Wait a couple of frames and re-resolve lazily on click rather than
	# hard-failing if something is still missing.
	await get_tree().process_frame
	await get_tree().process_frame
	_resolve_refs()


# owner/parent rather than get_tree().current_scene, which is null when the
# scene is instantiated manually (test harnesses, loading screens,
# sub-viewports) instead of loaded as the main scene — this exact bug has
# already cost this project two rounds of rework.
func _find_root() -> Node:
	return owner if owner != null else get_parent()


func _resolve_refs() -> void:
	var root := _find_root()
	if root == null:
		return
	_world = root
	_rail = _find_descendant(root, "RailNetwork")
	_camera_rig = _find_descendant(root, "CameraRig") as Node3D


# Depth-first search by node name, matching isle_state.gd's pattern — islands
# (and other systems) can sit at any depth under the world root (kingdom
# islands are children of "Isles2") without this script needing to know the
# scene's shape.
func _find_descendant(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for child in node.get_children():
		var hit := _find_descendant(child, target)
		if hit != null:
			return hit
	return null


func _find_isle(isle_id: String) -> Node3D:
	var root := _find_root()
	if root == null:
		return null
	var node := root.find_child("Isle_%s" % isle_id, true, false)
	return node as Node3D


# --- input / picking -------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _travel_active:
		# Swallow orbit-camera input while a ride is in progress so
		# sky_isles_world.gd's drag/zoom handlers never see it and never call
		# _update_camera_transform() to fight this script's own writes to
		# CameraRig. See the handoff note in the file header.
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_try_pick(mb.position)


func _try_pick(screen_pos: Vector2) -> void:
	if _rail == null or _world == null:
		_resolve_refs()
		if _rail == null or _world == null:
			return

	var camera: Camera3D = null
	if _world.has_method("get_camera"):
		camera = _world.get_camera()
	if camera == null:
		return

	var picked_id: String = _pick_train(camera, screen_pos)
	if picked_id.is_empty():
		picked_id = _pick_station(camera, screen_pos)

	if not picked_id.is_empty():
		travel_to(picked_id)


# Physics raycast against the train Area3Ds rail_network.gd already builds
# with input_ray_pickable = true and isle_id/is_train meta (see
# rail_network.gd's _build_train). Implemented here rather than relying on
# Godot's built-in viewport physics-picking (Area3D.input_event signal)
# because that requires the Viewport's physics_object_picking flag to be on,
# which is a project/scene setting this file is not allowed to touch —
# a manual PhysicsDirectSpaceState3D query works regardless of that flag.
func _pick_train(camera: Camera3D, screen_pos: Vector2) -> String:
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return ""

	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var to: Vector3 = from + dir * 500.0

	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = true
	params.collide_with_bodies = false

	var result: Dictionary = space_state.intersect_ray(params)
	if result.is_empty():
		return ""

	var collider: Object = result.get("collider", null)
	if collider == null:
		return ""

	# The train's ClickArea carries the meta directly; walk a couple of
	# parents up as a safety net in case the hit collider is a child shape
	# owner rather than the Area3D itself.
	var node: Node = collider as Node
	var depth := 0
	while node != null and depth < 4:
		if node.has_meta("is_train") and node.has_meta("isle_id"):
			var isle_id: String = node.get_meta("isle_id")
			return isle_id
		node = node.get_parent()
		depth += 1

	return ""


# Screen-space proximity fallback for "clicked a station" — see the
# STATION_CLICK_PIXELS comment for why this can't be a physics raycast.
# Checks every kingdom platform (the castle's Grand Station never needs to be
# a *destination* click target since travel always returns there as a leg
# endpoint, but including it costs nothing and lets a future two-leg UI treat
# it symmetrically) and picks the closest under the pixel threshold that is
# also in front of the camera.
func _pick_station(camera: Camera3D, screen_pos: Vector2) -> String:
	var best_id := ""
	var best_dist := STATION_CLICK_PIXELS

	for isle_id in KINGDOM_IDS + ["castle"]:
		var isle := _find_isle(isle_id)
		if isle == null or not isle.has_meta("platform_pos"):
			continue
		var platform_pos: Vector3 = isle.get_meta("platform_pos")

		if camera.is_position_behind(platform_pos):
			continue

		var screen_point: Vector2 = camera.unproject_position(platform_pos)
		var dist: float = screen_point.distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best_id = isle_id

	return best_id


# --- public API --------------------------------------------------------

# Rides the camera along the named kingdom line's curve and hands control to
# that island's camera_anchor. Re-entrancy guard: a call while a ride is
# already active is ignored outright (not queued) — the CONTRACT only
# requires that a second call not corrupt state, and dropping it cleanly
# (rather than guessing at queueing semantics nobody specified) is the
# smallest correct behaviour.
func travel_to(isle_id: String) -> void:
	if _travel_active:
		push_warning("travel_controller: travel_to('%s') ignored, ride already in progress" % isle_id)
		return

	if _rail == null or _world == null:
		_resolve_refs()
		if _rail == null or _world == null:
			push_warning("travel_controller: world/rail refs not ready, cannot travel")
			return

	if isle_id == _current_isle:
		push_warning("travel_controller: already at '%s'" % isle_id)
		return

	# Hub-and-spoke only — see file header for the routing decision. A line
	# is identified by its kingdom-side isle_id in rail_network's API
	# (get_curve("mind") etc.), so the only two legal moves are
	# castle -> kingdom and kingdom -> castle.
	var line_id: String = ""
	if _current_isle == "castle" and KINGDOM_IDS.has(isle_id):
		line_id = isle_id
	elif isle_id == "castle" and KINGDOM_IDS.has(_current_isle):
		line_id = _current_isle
	else:
		push_warning(
			"travel_controller: no direct rail from '%s' to '%s' — this is a hub-and-spoke network, route via 'castle' with two travel_to() calls" % [_current_isle, isle_id]
		)
		return

	if not _rail.has_method("has_line") or not _rail.call("has_line", line_id):
		push_warning("travel_controller: line '%s' is not built yet" % line_id)
		return

	var curve: Curve3D = _rail.call("get_curve", line_id)
	if curve == null:
		push_warning("travel_controller: no curve for line '%s'" % line_id)
		return

	var dest_isle := _find_isle(isle_id)
	if dest_isle == null or not dest_isle.has_meta("camera_anchor") or not dest_isle.has_meta("look_target"):
		push_warning("travel_controller: destination island '%s' missing anchor meta" % isle_id)
		return

	if _camera_rig == null:
		_resolve_refs()
		if _camera_rig == null:
			push_warning("travel_controller: CameraRig not found")
			return

	var camera: Camera3D = null
	if _world.has_method("get_camera"):
		camera = _world.get_camera()
	if camera == null:
		push_warning("travel_controller: world camera not available")
		return

	var from_id: String = _current_isle
	# Riding forward along the curve (t: 0->1) matches rail_network's own
	# convention of building each line from -> to with t=0 at the "from"
	# island; travel castle->kingdom rides 0->1, kingdom->castle rides 1->0.
	var forward: bool = (from_id == "castle")

	_travel_active = true
	travel_started.emit(from_id, isle_id)

	var anchor: Vector3 = dest_isle.get_meta("camera_anchor")
	var look_target: Vector3 = dest_isle.get_meta("look_target")

	await _ride_curve(curve, forward, camera)

	# Release control at the destination's authored anchor/look_target,
	# exactly (not wherever the curve's last sample happened to land) — the
	# curve ride is the transition, the anchor is the ground truth resting
	# pose per CONTRACT.md.
	_camera_rig.global_position = anchor
	camera.look_at(look_target, Vector3.UP)

	_current_isle = isle_id
	_travel_active = false
	travel_finished.emit(isle_id)


# Tweens a single float "t" from 0->1 (or 1->0 for the return leg) over
# RIDE_SECONDS with TRANS_SINE/EASE_IN_OUT per CONTRACT.md, sampling the
# curve every step so the camera follows the rail's actual shape (including
# its sag) rather than a straight lerp between endpoints.
func _ride_curve(curve: Curve3D, forward: bool, camera: Camera3D) -> void:
	var progress := {"t": 0.0 if forward else 1.0}
	var target_t: float = 1.0 if forward else 0.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(t: float) -> void: _on_ride_step(curve, t, camera),
		progress["t"],
		target_t,
		RIDE_SECONDS
	)
	await tween.finished


func _on_ride_step(curve: Curve3D, t: float, camera: Camera3D) -> void:
	if _camera_rig == null:
		return
	var length: float = curve.get_baked_length()
	var pos: Vector3 = curve.sample_baked(clampf(t, 0.0, 1.0) * length)
	# Ride a little above the rail itself so the camera isn't clipping
	# through the tube geometry it's following.
	pos.y += 3.0

	# OrbitCamera sits at local (0,0,0) under CameraRig (see sky_isles.tscn —
	# no position override on OrbitCamera), the same relationship
	# sky_isles_world.gd's own _update_camera_transform() relies on when it
	# only ever writes rig.position and lets the camera inherit it. Moving
	# only the rig here — never the camera directly — keeps that contract
	# intact so control can be handed back cleanly after the ride.
	_camera_rig.global_position = pos

	# Look slightly ahead along the direction of travel so the ride reads as
	# "riding the train forward", not "sliding sideways down the wire".
	var ahead_dist: float = clampf(t, 0.0, 1.0) * length + 4.0
	var look_pos: Vector3 = curve.sample_baked(clampf(ahead_dist, 0.0, length))
	look_pos.y += 3.0
	if look_pos.distance_to(pos) > 0.01:
		camera.look_at(look_pos, Vector3.UP)
