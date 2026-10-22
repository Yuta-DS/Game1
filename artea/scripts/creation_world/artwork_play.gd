extends Node3D
# Things to do inside an artwork world besides looking at it: paint the ground
# in the artwork's own colours as you walk (F), and find the paint drops hidden
# around the picture. Collecting every drop sets off a celebration.
#
# creation_world.gd owns this node and listens to `message` (status line) and
# `all_drops_collected` (the celebration that wakes its painted subjects).

signal message(text: String)
signal all_drops_collected

const DROP_COUNT := 8
# Drops stay this far inside the painting's edge and this far from each other
# and from where the player starts, so they spread across the whole picture.
const DROP_EDGE_MARGIN := 3.0
const DROP_SPACING := 5.0
const DROP_CLEAR_OF_SPAWN := 4.0
const DROP_HOVER := 1.0
const DROP_RADIUS := 0.9

# One splat every this many metres walked; the oldest go once there are
# MAX_SPLATS, so painting forever can't grow the world without bound.
const SPLAT_STEP := 0.45
const MAX_SPLATS := 360
# The colour moves to the next palette colour every this many splats, so a
# long walk leaves a rainbow of the artwork's colours.
const SPLATS_PER_COLOUR := 12

var painting := false
var _player: CharacterBody3D
var _terrain: RefCounted
var _palette: Array[Color] = []
var _drops: Array[Area3D] = []
var _collected := 0
var _splats: Array[MeshInstance3D] = []
var _splat_mesh: CylinderMesh
var _splat_materials: Array[StandardMaterial3D] = []
var _splat_count := 0
var _last_splat := Vector3.INF
var _time := 0.0


func configure(player: CharacterBody3D, terrain: RefCounted, palette: Array[Color]) -> void:
	_player = player
	_terrain = terrain
	_palette = palette
	_splat_mesh = CylinderMesh.new()
	_splat_mesh.top_radius = 0.45
	_splat_mesh.bottom_radius = 0.45
	_splat_mesh.height = 0.02
	_splat_mesh.radial_segments = 14
	_splat_mesh.rings = 1
	for colour in _palette:
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.35
		_splat_materials.append(material)


func drops_remaining() -> int:
	return _drops.size()


func splat_count() -> int:
	return _splats.size()


func toggle_painting() -> void:
	painting = not painting
	_last_splat = Vector3.INF
	message.emit("Painting the ground: walk to leave colour behind you. F to stop."
		if painting else "Paint brush put away.")


func _process(delta: float) -> void:
	_time += delta
	for index in _drops.size():
		var drop := _drops[index]
		drop.rotation.y = _time * 1.6 + index
		drop.position.y = float(drop.get_meta("rest_y")) + sin(_time * 2.2 + index) * 0.18
	if painting and _player != null and _player.is_on_floor():
		var feet := _player.global_position
		if _last_splat == Vector3.INF or feet.distance_to(_last_splat) >= SPLAT_STEP:
			_last_splat = feet
			_paint_at(feet)


func _paint_at(feet: Vector3) -> void:
	if _terrain == null or _splat_materials.is_empty():
		return
	var ground := float(_terrain.height_at(feet.x, feet.z))
	if ground < float(_terrain.water_level()):
		return  # paint doesn't stay on water
	var splat := MeshInstance3D.new()
	splat.name = "PaintSplat"
	splat.mesh = _splat_mesh
	splat.material_override = _splat_materials[
		(_splat_count / SPLATS_PER_COLOUR) % _splat_materials.size()]
	splat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Lie flat on the slope, a little above it so the ground doesn't show
	# through, each blob a slightly different size and turn.
	var up: Vector3 = _terrain.normal_at(feet.x, feet.z)
	var across := up.cross(Vector3.FORWARD).normalized()
	var basis := Basis(across, up, across.cross(up)).rotated(up, randf() * TAU)
	splat.transform = Transform3D(basis.scaled(Vector3.ONE * randf_range(0.7, 1.3)),
		Vector3(feet.x, ground + 0.03, feet.z))
	add_child(splat)
	_splats.append(splat)
	_splat_count += 1
	if _splats.size() > MAX_SPLATS:
		_splats.pop_front().queue_free()


## Hides the drops. Called once the painted subjects are built: `is_clear`
## (position, radius) keeps a drop from ending up inside one of them.
func place_drops(bounds: Rect2, spawn: Vector3, world_seed: int, is_clear: Callable) -> void:
	if _terrain == null or _palette.is_empty() or not _drops.is_empty() or _collected > 0:
		return
	# Seeded by the world, so an artwork hides its drops in the same places
	# every visit.
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	var area := bounds.grow(-DROP_EDGE_MARGIN)
	var placed: Array[Vector2] = []
	var attempts := 0
	while placed.size() < DROP_COUNT and attempts < 400:
		attempts += 1
		var point := Vector2(rng.randf_range(area.position.x, area.end.x),
			rng.randf_range(area.position.y, area.end.y))
		var ground := float(_terrain.height_at(point.x, point.y))
		if ground < float(_terrain.water_level()) + 0.2:
			continue  # not under water
		if point.distance_to(Vector2(spawn.x, spawn.z)) < DROP_CLEAR_OF_SPAWN:
			continue
		if placed.any(func(other: Vector2) -> bool: return other.distance_to(point) < DROP_SPACING):
			continue
		if not is_clear.call(Vector3(point.x, ground, point.y), DROP_RADIUS):
			continue
		placed.append(point)
		_add_drop(Vector3(point.x, ground + DROP_HOVER, point.y), _palette[placed.size() % _palette.size()])


func _add_drop(at: Vector3, colour: Color) -> void:
	var drop := Area3D.new()
	drop.name = "PaintDrop"
	drop.position = at
	drop.set_meta("rest_y", at.y)
	drop.collision_layer = 0
	drop.collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = DROP_RADIUS
	shape.shape = sphere
	drop.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.32
	mesh.height = 0.8  # a drop: taller than it is wide
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 1.4
	visual.material_override = material
	drop.add_child(visual)
	drop.body_entered.connect(_on_drop_touched.bind(drop))
	add_child(drop)
	_drops.append(drop)


func _on_drop_touched(body: Node3D, drop: Area3D) -> void:
	if body != _player or not _drops.has(drop):
		return
	_drops.erase(drop)
	_collected += 1
	var tween := create_tween()
	tween.tween_property(drop, "scale", Vector3.ONE * 1.8, 0.12)
	tween.tween_property(drop, "scale", Vector3.ZERO, 0.22)
	tween.tween_callback(drop.queue_free)
	var total := _collected + _drops.size()
	if _drops.is_empty():
		_celebrate()
		message.emit("You found all %d paint drops! Your painting is celebrating." % total)
		all_drops_collected.emit()
	else:
		message.emit("Paint drop found: %d of %d." % [_collected, total])


# A burst of the artwork's colours over the player.
func _celebrate() -> void:
	if _player == null:
		return
	var burst := GPUParticles3D.new()
	burst.name = "PaintCelebration"
	burst.amount = 160
	burst.lifetime = 2.2
	burst.one_shot = true
	burst.explosiveness = 0.9
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 70.0
	process.initial_velocity_min = 5.0
	process.initial_velocity_max = 9.0
	process.gravity = Vector3(0.0, -6.0, 0.0)
	var offsets := PackedFloat32Array()
	var colours := PackedColorArray()
	for index in _palette.size():
		offsets.append(float(index) / maxf(1.0, _palette.size() - 1.0))
		colours.append(_palette[index])
	var ramp := Gradient.new()
	ramp.offsets = offsets
	ramp.colors = colours
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_initial_ramp = ramp_texture
	burst.process_material = process
	var piece := QuadMesh.new()
	piece.size = Vector2(0.18, 0.18)
	var piece_material := StandardMaterial3D.new()
	piece_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	piece_material.vertex_color_use_as_albedo = true
	piece_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	piece.material = piece_material
	burst.draw_pass_1 = piece
	burst.position = _player.global_position + Vector3.UP * 2.0
	add_child(burst)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
