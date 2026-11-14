extends MultiMeshInstance3D

@export var area_size: Vector3 = Vector3(500, 250, 150)
@export var count: int = 50
@export var despawn_time: float = 15.0

var timers: Array = []

func _ready():
	multimesh.instance_count = count
	multimesh.visible_instance_count = count

	timers.resize(count)

	for i in range(count):
		_spawn_instance(i)
		# Randomize initial lifetimes so not all respawn together
		timers[i] = randf_range(0.0, despawn_time)
		

func _process(delta):
	for i in range(count):
		timers[i] -= delta
		if timers[i] <= 0:
			_spawn_instance(i)
			# Reset timer when respawned
			timers[i] = randf_range(despawn_time * 0.8, despawn_time * 1.5)

func _spawn_instance(i):
	var pos = Vector3(
		randf_range(-area_size.x/2, area_size.x/2),
		randf_range(0, area_size.y),
		randf_range(-area_size.z/2, area_size.z/2)
	)
	var transform = Transform3D()
	transform.origin = pos
	multimesh.set_instance_transform(i, transform)

	# Each Color() channel is used by INSTANCE_CUSTOM in the shader
	var seed_x = randf() # for offset_time
	var seed_y = randf() # for wave shape
	var seed_z = randf() # for loop radius
	multimesh.set_instance_custom_data(i, Color(seed_x, seed_y, seed_z, 1.0))
