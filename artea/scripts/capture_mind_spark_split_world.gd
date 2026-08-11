extends SceneTree

const OUTPUT := "res://artifacts/mind_spark_five_quest_chapter.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var scene := load("res://scenes/mind_spark/mind_spark_chapter_world.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	world._on_continue()
	for _frame in 30:
		await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT)
	if error != OK:
		push_error("Mind Spark capture failed: %s" % error)
		quit(1)
		return
	print("Mind Spark capture: %s" % OUTPUT)
	quit()
