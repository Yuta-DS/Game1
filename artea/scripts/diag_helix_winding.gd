# One-off diagnostic: compares the actual generated normal direction of
# _helix_band_mesh's "top" face against _helix_walk_surface_mesh's top face
# (known-correct — AscentWalkSurface already works in game) for the same
# footprint. Prints both normals so the winding question is settled by Godot
# itself instead of hand arithmetic.
extends SceneTree

const HubCastleStairs = preload("res://scripts/hub_castle_stairs.gd")


func _run() -> void:
	var stairs := HubCastleStairs.new()

	var walk_mesh: ArrayMesh = stairs.call(
		"_helix_walk_surface_mesh", Vector2.ZERO, 0.0, 10.0, 0.0, 4.0, 8.0, 0.0)
	var band_mesh: ArrayMesh = stairs.call(
		"_helix_band_mesh", Vector2.ZERO, 0.0, 10.0, 0.0, 4.0, 8.0, -0.1, 0.0)

	var walk_arrays := walk_mesh.surface_get_arrays(0)
	var walk_normals: PackedVector3Array = walk_arrays[Mesh.ARRAY_NORMAL]
	print("walk_surface (known-correct, faces up) first normal: ", walk_normals[0])

	var band_arrays := band_mesh.surface_get_arrays(0)
	var band_normals: PackedVector3Array = band_arrays[Mesh.ARRAY_NORMAL]
	# Surface order in _helix_band_mesh per segment: top(6 verts: 2 tris),
	# underside(6), outer face(6), inner face(6) = 24 verts/segment.
	print("band top face first normal (should match walk_surface if correct): ", band_normals[0])
	print("band underside face first normal (should be opposite of top): ", band_normals[6])
	print("band outer face first normal (should point away from Y axis, +X-ish here): ", band_normals[12])
	print("band inner face first normal (should point toward Y axis, -X-ish here): ", band_normals[18])

	quit(0)


func _init() -> void:
	call_deferred("_run")
