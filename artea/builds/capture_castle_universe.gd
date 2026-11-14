# Developer visual-check utility. Produces two 1280x720 PNG captures of the
# live world using a clean inspection camera.
extends SceneTree

# These inspection poses intentionally use the live player camera's scale:
# TERRACE_DECK_Y (67.73) + the CharacterBody landing lift (1.2) + the packed
# CameraController height (1.8).  Keeping the value explicit here prevents an
# apparently "player-height" audit view from being placed inside the raised
# court or a stair tread.
const TERRACE_PLAYER_EYE_Y := 70.73


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/New_Hub_World.tscn") as PackedScene
	var hub := packed.instantiate()
	root.add_child(hub)
	for _i in 48:
		await process_frame

	# Keep this architectural inspection deterministic. Calling the optional
	# island/citadel "vibrant" state starts unrelated two-second tween chains;
	# those can stall a standalone capture even though the castle has finished
	# building. The entrance materials are already in their authored live state.
	for _i in 12:
		await process_frame

	# Hide gameplay HUD/debug overlays so these captures inspect the world layer.
	for node in hub.find_children("*", "CanvasLayer", true, false):
		var layer := node as CanvasLayer
		layer.visible = false

	var camera := Camera3D.new()
	camera.name = "WorldCaptureCamera"
	camera.fov = 66.0
	camera.far = 900.0
	hub.add_child(camera)
	camera.make_current()

	DirAccess.make_dir_recursive_absolute("res://artifacts")
	# Generate the three primary reference-review frames first.  Besides making
	# the utility useful for a quick art-direction pass, this keeps the required
	# evidence available even on constrained machines that cannot retain all 29
	# rendered images in one long renderer session.
	await _save_angle(camera, Vector3(2.0, 81.0, 54.0),
		Vector3(-49.0, 96.0, 27.4), "res://builds/user_screenshots/castle_reference_hero.png")
	await _save_angle(camera, Vector3(-45.4, 97.3, 89.4),
		Vector3(-51.4, 96.3, 27.4), "res://builds/user_screenshots/castle_reference_side.png")
	await _save_angle(camera, Vector3(-91.4, 106.3, -8.6),
		Vector3(-51.4, 96.3, 27.4), "res://builds/user_screenshots/castle_reference_silhouette.png")
	await _save_angle(camera, Vector3(-19.0, 79.0, 55.0),
		Vector3(-43.0, 67.0, 27.4), "res://builds/user_screenshots/castle_station_angle.png")
	await _save_angle(camera, Vector3(0.0, 190.0, 340.0),
		Vector3(0.0, 135.0, 0.0), "res://builds/user_screenshots/castle_universe_wide.png")
	await _save_angle(camera, Vector3(13.0, 47.0, 13.0),
		Vector3(-1.4, 49.0, 27.4), "res://builds/user_screenshots/castle_stair_ground.png")
	await _save_angle(camera, Vector3(12.0, 73.0, 12.0),
		Vector3(-18.0, 68.5, 27.4), "res://builds/user_screenshots/castle_stair_door.png")

	# The front door from out on the plaza looking back at the castle. The door
	# is at (-39.8, 69.33, 27.41) facing +X, so the camera stands further
	# positive in x than the door face.
	# Close on the plaza itself (entrance AABB is x -40.5..-28.5, y 68..79),
	# from above the causeway so the gatehouse, arch and banners are not hidden
	# behind the castle's own foreground towers.
	await _save_angle(camera, Vector3(-20.0, 80.0, 42.0),
		Vector3(-36.0, 78.8, 27.4), "res://builds/user_screenshots/castle_front_door.png")
	# Same entrance from the side, so the gatehouse towers, arch and the
	# causeway ribs underneath are all readable in one frame.
	await _save_angle(camera, Vector3(-20.0, 80.0, 6.0),
		Vector3(-38.0, 77.0, 27.4), "res://builds/user_screenshots/castle_front_side.png")
	# Wide enough to confirm no rail passes through the castle.
	await _save_angle(camera, Vector3(20.0, 104.0, 96.0),
		Vector3(-45.0, 79.5, 30.0), "res://builds/user_screenshots/castle_rail_clearance.png")
	# Oblique mid-span detail inspection. Aim at the deck rather than either
	# portal so the 4.8 m walkable surface and both continuous guard rails stay
	# readable without a foreground pier obscuring the check.
	await _save_angle(camera, Vector3(-10.5, 72.5, 21.0),
		Vector3(-14.0, 68.25, 27.41), "res://builds/user_screenshots/castle_causeway_detail.png")
	# Player-eye checks in both directions expose any gate mass or arch segment
	# that enters the 4.8 m route or fills the follow-camera sightline.
	await _save_angle(camera, Vector3(-8.2, TERRACE_PLAYER_EYE_Y, 27.41),
		Vector3(-18.2, 72.1, 27.41), "res://builds/user_screenshots/castle_bridge_player_to_gate.png")
	await _save_angle(camera, Vector3(-18.5, TERRACE_PLAYER_EYE_Y, 27.41),
		Vector3(-8.0, 71.8, 27.41), "res://builds/user_screenshots/castle_bridge_player_to_stair.png")
	# Low oblique engineering audit: central keel, three transverse tension ribs,
	# and paired levitation coils must read as one supported bridge underside.
	await _save_angle(camera, Vector3(-12.0, 63.3, 16.0),
		Vector3(-13.0, 67.0, 27.41), "res://builds/user_screenshots/castle_bridge_underside.png")
	# Side-on player-height safety audit: the continuous cyan fields, brass caps,
	# and calibrated posts must protect both edges through the handoffs without
	# turning the bridge back into a visually solid tunnel.
	await _save_angle(camera, Vector3(-12.0, 70.6, 18.0),
		Vector3(-13.4, 68.7, 27.41), "res://builds/user_screenshots/castle_bridge_safety_balustrade.png")
	# Reference-comparison hero: the three pointed frames, layered rune glass,
	# destination instruments and mechanical side elevation in one composition.
	await _save_angle(camera, Vector3(-5.0, 75.2, 16.5),
		Vector3(-13.2, 70.0, 27.41), "res://builds/user_screenshots/castle_bridge_reference_hero.png")
	# Clean side elevation for the dark rune fascia, gear train, glass bays and
	# the under-deck load path without the destination mass filling the frame.
	await _save_angle(camera, Vector3(-20.5, 72.4, 17.5),
		Vector3(-12.8, 69.1, 27.41), "res://builds/user_screenshots/castle_bridge_reference_side.png")
	# The courtyard from just above head height on its own axis, which is how
	# the player actually sees it after stepping out of the gallery.
	await _save_angle(camera, Vector3(-24.5, 72.6, 27.4),
		Vector3(-39.0, 77.5, 27.4), "res://builds/user_screenshots/castle_courtyard.png")
	# And from above, so the fountain, planters and benches read as a plan.
	await _save_angle(camera, Vector3(-30.0, 88.0, 46.0),
		Vector3(-35.0, 70.0, 27.4), "res://builds/user_screenshots/castle_courtyard_top.png")
	# The spiral stair, to confirm the parapet reads as a wall not slats.
	await _save_angle(camera, Vector3(13.0, 62.0, 39.0),
		Vector3(-1.4, 55.0, 27.4), "res://builds/user_screenshots/castle_stair_railing.png")
	# The stair top meeting the causeway — the join the player reported as a
	# missing connection.
	await _save_angle(camera, Vector3(9.0, 78.0, 12.0),
		Vector3(-8.0, 68.5, 27.4), "res://builds/user_screenshots/castle_stair_top_join.png")
	# The causeway meeting the courtyard terrace, from above the span.
	await _save_angle(camera, Vector3(-6.0, 82.0, 40.0),
		Vector3(-22.0, 69.5, 22.0), "res://builds/user_screenshots/castle_causeway_join.png")
	# Player-eye-height view of the gate: stand on the lower arrival terrace,
	# outside the raised court and its final ascent, then look at the real
	# threshold. This exposes the ceremonial stair, door and arch as the player
	# approaches them instead of embedding the audit camera in their geometry.
	await _save_angle(camera, Vector3(-26.0, TERRACE_PLAYER_EYE_Y, 27.41),
		Vector3(-39.8, 78.33, 27.41), "res://builds/user_screenshots/castle_gate_player_height.png")
	# The spiral-to-crown handoff: the last tread opening onto the broad
	# landing, so a beam-crossing regression is visible immediately.
	await _save_angle(camera, Vector3(8.0, 72.5, 18.0),
		Vector3(-7.5, 68.4, 27.4), "res://builds/user_screenshots/castle_spiral_crown_handoff.png")
	# The crown-to-causeway gate and the causeway-to-terrace handoff, wide
	# enough to show both rail openings and confirm neither is blocked by an
	# overlapping end-cap or diagonal barrier.
	await _save_angle(camera, Vector3(7.0, 77.0, 10.0),
		Vector3(-18.0, 69.0, 27.4), "res://builds/user_screenshots/castle_causeway_handoff_wide.png")
	# The full architectural composition, wide, showing the reengineered
	# procession from spiral to gate in one frame.
	await _save_angle(camera, Vector3(4.0, 100.0, 60.0),
		Vector3(-30.0, 74.0, 25.0), "res://builds/user_screenshots/castle_procession_wide.png")
	# The new high-citadel review: one wide silhouette verifies the additional
	# vertical separation, while one close view exposes the science-and-magic
	# facade instead of hiding it inside a distant overview.
	await _save_angle(camera, Vector3(-11.0, 135.0, 2.0),
		Vector3(-49.0, 89.0, 27.4), "res://builds/user_screenshots/castle_aether_citadel.png")
	await _save_angle(camera, Vector3(-22.0, 84.0, 9.0),
		Vector3(-40.0, 78.5, 27.4), "res://builds/user_screenshots/castle_aether_facade.png")
	# Crown-specific silhouette review. The Art Castle needs to read as a true
	# observatory at a distance, not simply as a normal castle with glow added.
	await _save_angle(camera, Vector3(-18.0, 132.0, 2.0),
		Vector3(-51.4, 116.0, 27.4), "res://builds/user_screenshots/castle_observatory_crown.png")
	print("CASTLE_CAPTURE: PASS — wrote twenty-nine visual-check angles")
	quit()


func _save_angle(camera: Camera3D, position: Vector3, target: Vector3,
		path: String) -> void:
	camera.global_position = position
	camera.look_at(target, Vector3.UP)
	for _i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("CASTLE_CAPTURE: failed %s (%s)" % [path, error_string(error)])
