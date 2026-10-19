extends SceneTree

# Dev-only: renders overhead and front views of the arrival island to user://.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	var world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var centre := world.to_global(Vector3(0.0, 0.0, 820.0))
	var cam := Camera3D.new()
	cam.far = 4000.0
	gallery.add_child(cam)
	var shots := {
		"top": [centre + Vector3(0, 330, 0.1), centre],
		"front": [centre + Vector3(0, 90, -260), centre + Vector3(0, 0, 40)],
		"back": [centre + Vector3(0, 90, 260), centre + Vector3(0, 0, -40)],
		"fountain": [centre + Vector3(38, 14, -110), centre + Vector3(0, 6, -60)],
		"stairs": [Vector3(0, 2.2, 6), Vector3(0, 0.4, 30)],
		"stairs_side": [Vector3(6, 1.6, 14), Vector3(0, 0.4, 22)],
	}
	for name in shots:
		cam.global_position = shots[name][0]
		cam.look_at(shots[name][1])
		cam.make_current()
		for _f in 30:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("user://arrival_%s.png" % name)
	print("saved to ", ProjectSettings.globalize_path("user://"))
	quit(0)
