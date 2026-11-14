extends SceneTree

const OUTPUT_DIR := "res://builds/user_screenshots/galaxy_views"
const ZONES := [
	"01_world_gate_landing", "02_living_network_forest",
	"03_constellation_court", "04_hope_path_ridge",
	"05_thought_storm_arena", "06_oldest_tree_sanctuary",
]

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	current_scene = gallery
	var player := gallery.get_node_or_null("Player3D") as Node3D
	for _frame in 30:
		await process_frame
	for layer in gallery.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var floating_world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var world := floating_world.get_node("MindSparkWorldOne") as MindSparkWorldOne
	world.set_world_state("waking")
	var camera := gallery.get_node("Camera3D") as Camera3D
	camera.set_script(null)
	camera.near = 0.2
	camera.far = 8000.0
	camera.make_current()
	var centres: Array[Vector3] = []
	for zone_id in ZONES:
		centres.append(world.to_global(world.get_zone_position(zone_id)))
	var middle := (centres[0] + centres[5]) * 0.5
	var poses := [
		[middle + Vector3(0, 650, 500), middle, 64.0, "galaxy_overview.png"],
		[centres[0] + Vector3(115, 95, 150), centres[1], 67.0, "island_one.png"],
		[centres[2] + Vector3(110, 95, 155), centres[3], 65.0, "island_two.png"],
		[centres[4] + Vector3(110, 100, 170), centres[5], 65.0, "island_three.png"],
	]
	for pose in poses:
		camera.fov = pose[2]
		camera.look_at_from_position(pose[0], pose[1], Vector3.UP)
		for _frame in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s" % [OUTPUT_DIR, pose[3]]
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Galaxy screenshot failed: %s" % path)
			quit(1)
			return
		print("GALAXY_VIEW_CAPTURE: %s" % path)
	quit()
