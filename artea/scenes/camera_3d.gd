extends Camera3D

@export var player_path: NodePath
@export var follow_offset: Vector3 = Vector3(0, 10, 10) # height + distance

func _process(delta: float) -> void:
	var player = get_node(player_path)
	if player:
		global_transform.origin = player.global_transform.origin + follow_offset
		look_at(player.global_transform.origin, Vector3.UP)
