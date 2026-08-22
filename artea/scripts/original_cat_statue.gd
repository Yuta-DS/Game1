extends Node3D

# The legacy GLB contains root-transform animation tracks. When it is placed
# directly in the hub those tracks reset the landmark to world origin. Keep the
# historical model as a static statue and reassert its authored sign position.

func _ready() -> void:
	for animation_node in find_children("*", "AnimationPlayer", true, false):
		var animation_player := animation_node as AnimationPlayer
		animation_player.stop()
		animation_player.process_mode = Node.PROCESS_MODE_DISABLED
	_make_statue_surfaces_solid()
	global_position = Vector3(110.0, 20.0, -15.0)
	rotation_degrees = Vector3(0.0, 280.4, 0.0)
	scale = Vector3.ONE * 10.0


func _make_statue_surfaces_solid() -> void:
	# The legacy GLB contains materials authored for a glossy render. Force an
	# opaque depth-writing copy onto every statue surface so back faces, the sign
	# and nearby buildings can never show through the cat from any camera angle.
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface_index)
			if not source is BaseMaterial3D:
				continue
			var solid := source.duplicate() as BaseMaterial3D
			solid.resource_local_to_scene = true
			solid.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			solid.cull_mode = BaseMaterial3D.CULL_BACK
			solid.no_depth_test = false
			solid.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
			var opaque_colour := solid.albedo_color
			opaque_colour.a = 1.0
			solid.albedo_color = opaque_colour
			mesh_instance.set_surface_override_material(surface_index, solid)
