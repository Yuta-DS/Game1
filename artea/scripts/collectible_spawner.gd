extends Node3D

## Spawns collectibles in a random area
## Each collectible is a full instance with working Area3D and scripts

@export var collectible_scene: PackedScene
@export var spawn_count: int = 10
@export var spawn_area_size: Vector2 = Vector2(50, 50) # X and Z
@export var min_distance_between: float = 3.0
@export var raycast_from_height: float = 50.0 # Cast ray down from this height
@export var raycast_max_distance: float = 100.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	print("CollectibleSpawner starting at position: ", global_position)
	print("Spawn area size: ", spawn_area_size)
	print("Trying to spawn ", spawn_count, " items...")
	spawn_collectibles()

func spawn_collectibles() -> void:
	if not collectible_scene:
		push_error("No collectible scene assigned to spawner!")
		return
	
	print("Collectible scene loaded: ", collectible_scene.resource_path)
	
	var spawned_positions: Array[Vector3] = []
	var attempts = 0
	var max_attempts = spawn_count * 10
	
	while spawned_positions.size() < spawn_count and attempts < max_attempts:
		attempts += 1
		
		if attempts % 10 == 0:
			print("Spawn attempts: ", attempts, " / Spawned: ", spawned_positions.size())
		
		# Random position in spawn area
		var random_x = randf_range(-spawn_area_size.x / 2, spawn_area_size.x / 2)
		var random_z = randf_range(-spawn_area_size.y / 2, spawn_area_size.y / 2)
		var test_pos = global_position + Vector3(random_x, raycast_from_height, random_z)
		
		# Check if too close to other spawned items
		var too_close = false
		for pos in spawned_positions:
			if test_pos.distance_to(pos) < min_distance_between:
				too_close = true
				break
		
		if too_close:
			continue
		
		# Raycast down to find ground
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			test_pos,
			test_pos + Vector3.DOWN * raycast_max_distance
		)
		query.collision_mask = 1 # Only check terrain/ground layer
		
		var result = space_state.intersect_ray(query)
		if result:
			# Spawn collectible at ground position
			var collectible = collectible_scene.instantiate()
			get_tree().root.add_child(collectible)
			collectible.global_position = result.position + Vector3(0, 0.5, 0) # Slight offset above ground
			spawned_positions.append(result.position)
			print("Spawned collectible at: ", result.position)
		else:
			print("Raycast missed at position: ", test_pos)
	
	print("Finished spawning! Total spawned: ", spawned_positions.size(), " / ", spawn_count)
	print("Total attempts: ", attempts)

# Editor tool to visualize spawn area
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	
	if not collectible_scene:
		warnings.append("No collectible scene assigned. Set the collectible_scene property.")
	
	return warnings

