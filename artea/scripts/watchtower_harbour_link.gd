@tool
extends Node3D
## Collision follows the Blender-authored floors and rails, including angled spans.

func _ready() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var extras: Dictionary = mesh.get_meta("extras", {})
		if not extras.get("harbour_collision", false):
			continue
		if mesh.get_node_or_null("HarbourCollision") != null:
			continue
		var body := StaticBody3D.new()
		body.name = "HarbourCollision"
		body.collision_layer = 1
		body.collision_mask = 1
		var collider := CollisionShape3D.new()
		collider.shape = mesh.mesh.create_trimesh_shape()
		body.add_child(collider)
		mesh.add_child(body)
