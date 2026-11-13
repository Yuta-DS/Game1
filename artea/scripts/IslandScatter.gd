extends Node3D

## Scatters scenery across an island so 3000m of ground has something on it.
##
## Uses a MultiMesh, so thousands of props cost one draw call each rather than
## thousands of nodes. Everything is placed on the island's real surface and
## kept clear of the districts, so scenery never grows through a gate or a
## guardian.

## The island to scatter across.
@export var island_path: NodePath = NodePath("../Island")

## What to scatter. Each entry is one MultiMesh layer.
##
## Keys: mesh (Mesh), count (int), min_scale, max_scale, colour (Color),
## emission (float), keep_out (float, metres around the island centre),
## min_distance / max_distance from the centre.
@export var layers: Array[Dictionary] = []

## Same layout every run, so a kingdom looks the same each time it is entered.
@export var scatter_seed: int = 7

## Districts sit near the centre; scenery stays out of their way.
@export var district_clearance: float = 420.0

## Nothing is scattered within this distance of the landing point, so the player
## never arrives inside a tree.
@export var landing_clearance: float = 35.0

## Where the player arrives, in island space. Bearing degrees, distance metres.
@export var landing_spot: Vector2 = Vector2(180.0, 88.0)

var _island: Node3D = null


func _ready() -> void:
	_island = get_node_or_null(island_path)
	if _island == null:
		push_warning("IslandScatter: no island at %s" % island_path)
		return
	# The island builds its surface in its own _ready.
	await get_tree().process_frame
	scatter()


func scatter() -> void:
	for child in get_children():
		child.queue_free()

	if _island == null:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed

	for layer in layers:
		_scatter_layer(layer, rng)


func _scatter_layer(layer: Dictionary, rng: RandomNumberGenerator) -> void:
	var mesh: Mesh = _mesh_for(layer)
	if mesh == null:
		return

	var wanted: int = int(layer.get("count", 100))
	var near: float = float(layer.get("min_distance", district_clearance))
	var far: float = float(layer.get("max_distance", 1350.0))
	var low: float = float(layer.get("min_scale", 0.8))
	var high: float = float(layer.get("max_scale", 1.4))

	var placements: Array[Transform3D] = []
	var tries := 0

	# Rejection sampling: keep drawing points until enough land on real ground.
	while placements.size() < wanted and tries < wanted * 12:
		tries += 1

		var bearing := rng.randf() * TAU
		# Square-rooted radius spreads props evenly rather than crowding the
		# middle of the ring.
		var t := sqrt(rng.randf())
		var distance: float = lerp(near, far, t)

		var x := sin(bearing) * distance
		var z := -cos(bearing) * distance

		if not _island.is_on_island(x, z):
			continue

		# Keep the landing point clear.
		if _too_close_to_landing(x, z):
			continue

		var y: float = _island.height_at(x, z)
		# Nothing grows on the slopes falling away into the galaxy.
		if y < -float(layer.get("lowest_ground", 60.0)):
			continue

		var scale: float = rng.randf_range(low, high)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
		placements.append(Transform3D(basis, Vector3(x, y, z)))

	if placements.is_empty():
		return

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = placements.size()
	for i in placements.size():
		multimesh.set_instance_transform(i, placements[i])

	var renderer := MultiMeshInstance3D.new()
	renderer.name = str(layer.get("name", "Scatter"))
	renderer.multimesh = multimesh

	if _keeps_own_material(layer):
		add_child(renderer)
		return

	var material := StandardMaterial3D.new()
	material.albedo_color = layer.get("colour", Color(0.4, 0.45, 0.5))
	material.roughness = 0.85
	var glow: float = float(layer.get("emission", 0.0))
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = layer.get("emission_colour", material.albedo_color)
		material.emission_energy_multiplier = glow
	renderer.material_override = material

	add_child(renderer)


## True when a spot would put scenery on top of where the player arrives.
func _too_close_to_landing(x: float, z: float) -> bool:
	if landing_clearance <= 0.0 or _island == null:
		return false
	var landing: Vector3 = _island.point_at(landing_spot.x, landing_spot.y)
	return Vector2(x - landing.x, z - landing.z).length() < landing_clearance


## A layer may name a raw Mesh, or a PackedScene whose model holds one. The
## art in this project ships as scenes wrapping glTF, so both are accepted.
func _mesh_for(layer: Dictionary) -> Mesh:
	var direct = layer.get("mesh")
	if direct is Mesh:
		return direct

	var packed = layer.get("scene")
	if packed is PackedScene:
		# `Dictionary.get()` returns Variant, so spell out the instantiated
		# node's type rather than asking the parser to infer through Variant.
		var probe: Node = (packed as PackedScene).instantiate()
		var found: Mesh = null
		for node in probe.find_children("*", "MeshInstance3D", true, false):
			if node.mesh != null:
				found = node.mesh
				break
		probe.free()
		return found

	return null


## Keeps a prop's own material instead of overriding it, so real art keeps its
## textures while primitives still get a tinted colour.
func _keeps_own_material(layer: Dictionary) -> bool:
	return layer.has("scene") and not layer.has("colour")


## How many props ended up on the island, for tests.
func prop_count() -> int:
	var total := 0
	for child in get_children():
		if child is MultiMeshInstance3D and child.multimesh:
			total += child.multimesh.instance_count
	return total
