extends Node3D

## Simple spawner that places collectibles at a fixed Y height
## Perfect for placing items on relatively flat terrain

@export var collectible_scene: PackedScene
@export var spawn_count: int = 20
@export var spawn_area_size: Vector2 = Vector2(100, 100) # X and Z
@export var spawn_height: float = 20.0 # Y position where items spawn
@export var min_distance_between: float = 3.0
@export var use_raycast: bool = true # Try to place on ground using raycast
@export var raycast_height_offset: float = 50.0 # How high to start raycast from spawn_height

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	call_deferred("spawn_collectibles")

func spawn_collectibles() -> void:
	if not collectible_scene:
		push_error("No collectible scene assigned!")
		return
	
	print("Spawning ", spawn_count, " collectibles around ", global_position)
	
	var spawned_count = 0
	var attempts = 0
	var max_attempts = spawn_count * 20
	var spawned_positions: Array[Vector3] = []
	
	while spawned_count < spawn_count and attempts < max_attempts:
		attempts += 1
		
		# Random position in spawn area
		var random_x = randf_range(-spawn_area_size.x / 2, spawn_area_size.x / 2)
		var random_z = randf_range(-spawn_area_size.y / 2, spawn_area_size.y / 2)
		var spawn_pos = global_position + Vector3(random_x, spawn_height, random_z)
		
		# Check if too close to other spawned items
		var too_close = false
		for pos in spawned_positions:
			if spawn_pos.distance_to(pos) < min_distance_between:
				too_close = true
				break
		
		if too_close:
			continue
		
		# Optionally raycast down to find actual ground position
		var final_pos = spawn_pos
		if use_raycast:
			var space_state = get_world_3d().direct_space_state
			var ray_start = spawn_pos + Vector3(0, raycast_height_offset, 0)
			var ray_end = spawn_pos + Vector3(0, -raycast_height_offset, 0)
			var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
			query.collision_mask = 0xFFFFFFFF # Check all layers
			
			var result = space_state.intersect_ray(query)
			if result:
				final_pos = result.position + Vector3(0, 0.5, 0) # Slight offset above ground
		
		# Spawn the collectible
		var collectible = collectible_scene.instantiate()
		get_parent().add_child(collectible)
		collectible.global_position = final_pos
		
		spawned_positions.append(final_pos)
		spawned_count += 1
	
	print("Successfully spawned ", spawned_count, " collectibles in ", attempts, " attempts")
