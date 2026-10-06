extends Node3D
## Only tagged animal roots animate; meshes never become independent creatures.

var _time := 0.0
var _creatures: Array[Node3D] = []
var _origins: Dictionary = {}


func _ready() -> void:
	for node in get_node("SeaLife").find_children("*", "Node3D", true, false):
		var extras: Dictionary = node.get_meta("extras", {})
		if extras.has("creature_kind"):
			node.set_meta("creature_kind", extras["creature_kind"])
			_creatures.append(node)
			_origins[node] = node.transform
	call_deferred("_bind_shallow_water")


func _bind_shallow_water() -> void:
	var water := get_node_or_null("../Environment/Water/MeshInstance3D") as MeshInstance3D
	if water == null:
		return
	var ocean := water.get_parent()
	var center := to_global(Vector3(0, 0, 3))
	if ocean.has_method("configure_harbour"):
		ocean.call("configure_harbour", Vector2(center.x, center.z), 20.0)
		return
	var source := water.get_active_material(0) as ShaderMaterial
	if source == null:
		return
	var material := source.duplicate() as ShaderMaterial
	material.set_shader_parameter("harbour_center", Vector2(center.x, center.z))
	material.set_shader_parameter("harbour_clear_radius", 20.0)
	water.material_override = material


func _process(delta: float) -> void:
	_time += delta
	for index in _creatures.size():
		var animal := _creatures[index]
		var origin: Transform3D = _origins[animal]
		var kind: String = animal.get_meta("creature_kind")
		var phase := _time * (0.45 + (index % 4) * 0.07) + index * 1.7
		animal.transform = origin
		match kind:
			"fish":
				var radius := 0.55
				if "School" in animal.name:
					# Shared motion preserves the school spacing and heading.
					phase = _time * 0.55
					radius = 0.28
				if "Seahorse" in animal.name:
					animal.position.y += sin(phase) * 0.045
					continue
				animal.position += Vector3(cos(phase) * radius, sin(phase * 1.8) * 0.035,
					sin(phase) * radius * 0.62)
				animal.rotation.y = atan2(-cos(phase) * 0.62, -sin(phase))
				animal.rotation.z = sin(phase * 2.0) * 0.04
			"crabs":
				animal.position.x += sin(phase * 1.5) * 0.08
				animal.rotation.y += sin(phase) * 0.08
			"jellyfish":
				animal.position.y += sin(phase) * 0.06
				animal.scale = origin.basis.get_scale() * (1.0 + sin(phase) * 0.045)
			"turtles":
				animal.position += Vector3(sin(phase) * 0.35, sin(phase) * 0.035, 0)
			# Shells, oysters and rooted sea mushrooms stay on their rock beds.


func creature_counts() -> Dictionary:
	var counts := {"fish": 0, "crabs": 0, "shells": 0, "oysters": 0,
		"sea_mushrooms": 0, "jellyfish": 0, "starfish": 0, "turtles": 0}
	for animal in _creatures:
		var kind: String = animal.get_meta("creature_kind")
		counts[kind] += 1
	return counts
