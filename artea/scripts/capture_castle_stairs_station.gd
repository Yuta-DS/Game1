extends SceneTree

## Renders the Art Castle stair crown and the skyrail Grand Station from the
## angles the bug screenshots were taken at, so the reported clipping, gaps and
## z-fighting can be inspected directly instead of inferred from tests.

const CROWN := Vector3(-1.4, 67.73, 27.41)
const STATION := Vector3(-22.0, 66.15, 52.0)
const GROUND_ENTRY := Vector3(5.1, 27.2, 24.4)

const SHOTS := [
	# label, camera position, look-at target
	["01_stair_from_deck", Vector3(14.0, 72.0, 40.0), CROWN],
	["02_stair_side", Vector3(24.0, 70.5, 27.41), CROWN],
	["03_stair_foot_up", Vector3(-1.4, 69.0, 46.0), Vector3(-1.4, 68.6, 27.41)],
	["04_stair_top_down", Vector3(-1.4, 78.0, 44.0), CROWN],
	["05_station_wide", Vector3(-2.0, 74.0, 72.0), STATION],
	["06_station_deck", Vector3(-22.0, 69.5, 68.0), STATION],
	["07_station_stair_junction", Vector3(6.0, 73.0, 56.0), Vector3(-12.0, 67.5, 40.0)],
	["08_crown_gate", Vector3(-14.0, 71.0, 38.0), Vector3(-6.0, 68.2, 27.41)],
	["09_grounded_medieval_entry", Vector3(13.0, 31.5, 15.0), GROUND_ENTRY],
	["10_crown_ballista", Vector3(-1.4, 73.8, 38.5), CROWN],
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	# The stair, skyrail and scatter passes all build over several frames.
	for _i in 120:
		await process_frame
		await physics_frame

	for node in hub.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false

	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.05
	camera.far = 4000.0
	hub.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts/castle_stairs_station")

	for shot in SHOTS:
		var label: String = shot[0]
		var eye: Vector3 = shot[1]
		var target: Vector3 = shot[2]
		camera.global_position = eye
		camera.look_at(target, Vector3.UP)
		for _i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://artifacts/castle_stairs_station/%s.png" % label
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("CASTLE_STATION_CAPTURE: failed %s (%s)" % [path, error_string(error)])
			quit(error)
			return
		print("CASTLE_STATION_CAPTURE: wrote %s" % path)

	print("CASTLE_STATION_CAPTURE: PASS — wrote %d shots" % SHOTS.size())
	quit()
