# Identifies which node owns the loose diagonal brass bars scattered over the
# castle terrace, instead of guessing from renders.
#
# Lists every mesh whose world position falls in the causeway/plaza volume,
# together with the top-level hub child it belongs to.
extends SceneTree

const MIN := Vector3(-42.0, 66.0, 14.0)
const MAX := Vector3(-26.0, 78.0, 40.0)


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _i in 40:
		await process_frame

	var owners := {}
	for node in hub.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var p := mi.global_position
		if p.x < MIN.x or p.x > MAX.x: continue
		if p.y < MIN.y or p.y > MAX.y: continue
		if p.z < MIN.z or p.z > MAX.z: continue

		# Walk up to the direct child of the hub root, which is the system.
		var top: Node = mi
		while top.get_parent() != null and top.get_parent() != hub:
			top = top.get_parent()
		var key := String(top.name)
		if not owners.has(key):
			owners[key] = 0
		owners[key] += 1

	print("PROBE: meshes inside the castle terrace volume, by owning system:")
	for key in owners:
		print("PROBE:   %-28s %d" % [key, owners[key]])

	# The clutter reads as small brass bars roughly 1-2 m long, lying at odd
	# angles. List every mesh in the volume matching that description, with its
	# full node path and world basis, so the owner is identified rather than
	# guessed at from a render.
	print("PROBE: --- small non-axis-aligned meshes in the volume ---")
	var shown := 0
	for node in hub.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var p := mi.global_position
		if p.x < MIN.x or p.x > MAX.x: continue
		if p.y < MIN.y or p.y > MAX.y: continue
		if p.z < MIN.z or p.z > MAX.z: continue
		if mi.mesh == null: continue
		var size := mi.mesh.get_aabb().size
		var longest: float = maxf(size.x, maxf(size.y, size.z))
		if longest > 3.0:
			continue
		# Axis-aligned boxes are fine; the offenders are rotated.
		var b := mi.global_transform.basis
		var tilted := absf(b.y.normalized().dot(Vector3.UP)) < 0.97
		if not tilted:
			continue
		print("PROBE: %s  mesh=%s size=%s up=%s"
			% [hub.get_path_to(mi), mi.mesh.get_class(), size,
				b.y.normalized()])
		shown += 1
		if shown >= 18:
			break
	quit()


func _init() -> void:
	call_deferred("_run")
