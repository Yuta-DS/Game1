extends Node3D

# Rotate the complete sign, keeping the lettering physically in front of its
# backing at every camera angle. Fit the backing after Label3D lays out text.
func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null and global_position.distance_squared_to(camera.global_position) > 0.01:
		look_at(camera.global_position, Vector3.UP, true)
	var text := get_node("BannerText") as Label3D
	var backing := get_child(0) as MeshInstance3D
	var bounds := text.get_aabb()
	backing.mesh.size = Vector2(maxf(10.2, bounds.size.x + 0.8), maxf(2.8, bounds.size.y + 0.6))
	# Keep the entire sign above its landmark, including the rotating corners.
	position = get_meta("anchor_position") + Vector3.UP * (backing.mesh.size.y * 0.5 + 0.75)
