# Diagnostic-only: loads the real hub scene, waits for scatter + stair build
# to settle, then dumps every solid body within 20 m of the stair tower base
# so the house/rock intersecting the screenshot can be identified by name and
# transform instead of guessed at from tscn math.
extends SceneTree


func _run() -> void:
	var hub: Node = (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)

	for _i in 40:
		await process_frame
		await physics_frame

	var base := Vector2(-1.4, 27.41)
	var hits: Array = []
	_scan(root, base, 20.0, hits)
	hits.sort_custom(func(a, b): return a[1] < b[1])
	for h in hits:
		print("%-40s dist=%6.2f  pos=%s" % [h[0], h[1], h[2]])
	print("TOTAL: %d bodies within 20m" % hits.size())
	quit()


func _scan(node: Node, base: Vector2, radius: float, hits: Array) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			var visual: Node3D = child.get_parent() if child.get_parent() is Node3D else child
			var gp: Vector3 = visual.global_position
			var offset := Vector2(gp.x - base.x, gp.z - base.y)
			if offset.length() < radius:
				hits.append([visual.get_path(), offset.length(), gp])
		_scan(child, base, radius, hits)


func _init() -> void:
	call_deferred("_run")
