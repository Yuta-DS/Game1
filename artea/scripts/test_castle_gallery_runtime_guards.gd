extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var animator := preload("res://scripts/mind_spark/mind_spark_island_detail_animator.gd").new()
	var removed := Node3D.new()
	animator._packets.append(removed)
	animator._orbiters.append(removed)
	removed.free()
	# This used to raise a freed-instance script exception on every frame.
	animator._process(0.1)
	assert(is_equal_approx(animator._elapsed, 0.1))
	animator.free()
	var manager = load("res://scenes/GalleryManager.gd").new()
	var frame := Sprite3D.new()
	for texture: Texture2D in manager.PLACEHOLDERS:
		manager.one_placeholder(frame, texture)
		assert(frame.texture != null and frame.texture.get_width() == 512 and frame.texture.get_height() == 512,
			"imported gallery textures are decoded before resizing")
	frame.free()
	manager.free()
	print("CASTLE_GALLERY_GUARDS: PASS — removed animation details skipped; all imported gallery placeholders resized")
	quit(0)
