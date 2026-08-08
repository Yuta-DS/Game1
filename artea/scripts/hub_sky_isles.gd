# The three kingdom islands, floating in the sky above the hub village.
#
# This is the land the rails lead to. Each island carries the portal for its
# kingdom's experience, so the journey now has somewhere to *go*: the player
# boards a train at the castle station, rides up, and walks out onto Mind
# Spark, Heart Melody or Creator's Light.
#
# Ported from the Sky Isles prototype (scripts/sky_isles/) onto the real
# hub. The prototype's islands floated in an empty sky with no player on
# them; here they sit above a Terrain3D village and must be walkable, so
# every island gets a StaticBody3D collision floor.
#
# Runtime-authored like hub_magitech.gd — nothing is baked into
# New_Hub_World.tscn, so the whole sky layer can be removed by deleting one
# node.
#
# Wakes with the journey through hub_awakening's apply_stage, same as every
# other hub system. JourneyState.stage stays the only progress model.
extends Node3D

const IsleBuilderScript := "res://scripts/sky_isles/isle_builder.gd"

# preload rather than the global class name: class_name registration is not
# guaranteed to have run when this script parses, and relying on it failed
# here exactly as it did for isle_builder in the prototype.
const IsleDressing := preload("res://scripts/hub_isle_dressing.gd")

# Height band the islands occupy. The hub's ground sits at Y 15-24 and its
# tallest towers reach into the 40s, so the islands clear everything and
# read unmistakably as "up there" from the village below.
#
# Raised well clear of the village: at 78 the islands loomed directly over
# the rooftops and read as intrusions rather than as distant kingdoms. The
# X/Z positions below are also pushed outward from the portals they mirror,
# so each island sits over open ground or ocean instead of over the town.
const SKY_HEIGHT := 132.0

# Where each island sits, and which experience it holds. X/Z are placed
# roughly above that kingdom's existing portal on the ground, so the sky
# map mirrors the village map instead of contradicting it.
const ISLES := [
	{
		"id": "mind",
		"label": "Mind Spark",
		"pos": Vector3(150.0, SKY_HEIGHT + 8.0, -140.0),
		"radius": 22.0,
		"color": Color(0.45, 0.62, 1.00),      # blue/lavender — thoughts
		"scene": "res://scenes/popThoughtsMenu.tscn",
	},
	{
		"id": "heart",
		"label": "Heart Melody",
		"pos": Vector3(140.0, SKY_HEIGHT - 10.0, 130.0),
		"radius": 22.0,
		"color": Color(1.00, 0.55, 0.62),      # pink/coral — emotions
		"scene": "res://scenes/music_minigame.tscn",
	},
	{
		"id": "creator",
		"label": "Creator's Light",
		"pos": Vector3(-140.0, SKY_HEIGHT + 2.0, -70.0),
		"radius": 22.0,
		"color": Color(1.00, 0.76, 0.30),      # amber/gold — creativity
		"scene": "res://scenes/drawing_tool.tscn",
	},
]

# Staggered so the islands never bob in sync — a synchronised group reads as
# one object, not as three places.
const BOB_PHASES := [0.0, 2.1, 4.3]
const BOB_AMPLITUDE := 0.24
const BOB_PERIOD := 9.0

# Island glow per journey stage. Index = JourneyState.stage.
const STAGE_GLOW := [0.0, 0.3, 0.55, 0.8, 1.0]

const WAKE_SECONDS := 2.0

var _emissive_materials: Array[StandardMaterial3D] = []

# Crystal and rune-circle shader materials from the dressing. Driven by the
# same stage value, but through an `awake` uniform rather than emission.
var _shader_materials: Array[ShaderMaterial] = []

# Island rock. Lit by the sun rather than self-lit, so it wakes by getting
# less drab (albedo) instead of glowing, which kept the islands readable.
var _rock_materials: Array[StandardMaterial3D] = []
var _rock_base: Array[Color] = []

# Per-island state owns the exact materials and spinners belonging to that
# kingdom. This is the seam future progress logic uses for independent wakes.
var _island_states: Dictionary = {}

var _isle_nodes: Dictionary = {}
var _bob_time := 0.0
var _debug_label: Label = null


func _ready() -> void:
	# Let the hub finish building before adding to it.
	await get_tree().process_frame

	for i in ISLES.size():
		_build_isle(ISLES[i], i)

	apply_stage(_current_stage())
	_build_debug_panel()


func _process(delta: float) -> void:
	_bob_time += delta

	# Idle bob. The islands own their own vertical motion here (unlike the
	# prototype, where a world script drove it) because nothing else in the
	# hub touches these nodes.
	for i in ISLES.size():
		var isle_id: String = ISLES[i]["id"]
		if not _isle_nodes.has(isle_id):
			continue
		var node: Node3D = _isle_nodes[isle_id]
		var base_y: float = ISLES[i]["pos"].y
		node.position.y = base_y + sin(
			(_bob_time / BOB_PERIOD) * TAU + BOB_PHASES[i]) * BOB_AMPLITUDE

	# Turn only the mechanisms on vibrant islands. Each kingdom owns its speed,
	# so toggling Mind Spark never silently wakes Heart or Creator.
	for isle_id in _island_states:
		var state: Dictionary = _island_states[isle_id]
		var spin_speed: float = state["spin_speed"]
		if is_zero_approx(spin_speed):
			continue
		var spinners: Array = state["spinners"]
		for i in spinners.size():
			var spinner := spinners[i] as Node3D
			var direction := 1.0 if i % 2 == 0 else -1.35
			spinner.rotate_y(spin_speed * direction * delta)


# Called by hub_awakening.gd so the islands wake in step with the rest of
# the world rather than tracking progress separately.
func apply_stage(stage: int) -> void:
	stage = clampi(stage, 0, STAGE_GLOW.size() - 1)
	if _island_states.is_empty():
		return
	var target: float = STAGE_GLOW[stage]
	for isle_id in _island_states:
		_set_island_state(isle_id, target > 0.0, target)
	_update_debug_panel()


# Public binary state seam requested by the Castle Universe brief. Future
# progress logic can call this directly; debug controls use the same path.
func set_island_vibrant(isle_id: String, vibrant: bool) -> void:
	_set_island_state(isle_id, vibrant, 1.0 if vibrant else 0.0)
	_update_debug_panel()


func is_island_vibrant(isle_id: String) -> bool:
	if not _island_states.has(isle_id):
		return false
	var state: Dictionary = _island_states[isle_id]
	return bool(state["vibrant"])


func toggle_island(isle_id: String) -> void:
	set_island_vibrant(isle_id, not is_island_vibrant(isle_id))


func _set_island_state(isle_id: String, vibrant: bool, intensity: float) -> void:
	if not _island_states.has(isle_id):
		return
	var state: Dictionary = _island_states[isle_id]
	state["vibrant"] = vibrant
	state["spin_speed"] = intensity * 0.5
	_island_states[isle_id] = state

	var tween := create_tween().set_parallel()
	var emissive: Array = state["emissive"]
	for item in emissive:
		var material := item as StandardMaterial3D
		tween.tween_property(material, "emission_energy_multiplier",
			intensity * 1.5, WAKE_SECONDS).set_trans(Tween.TRANS_SINE)

	var rock: Array = state["rock"]
	var rock_base: Array = state["rock_base"]
	for i in rock.size():
		var material := rock[i] as StandardMaterial3D
		var base: Color = rock_base[i]
		tween.tween_property(material, "albedo_color",
			base.lightened(intensity * 0.45), WAKE_SECONDS).set_trans(Tween.TRANS_SINE)

	var shaders: Array = state["shader"]
	for item in shaders:
		var material := item as ShaderMaterial
		var from_value: float = float(material.get_shader_parameter("awake"))
		tween.tween_method(
			func(value: float) -> void: material.set_shader_parameter("awake", value),
			from_value, intensity, WAKE_SECONDS).set_trans(Tween.TRANS_SINE)


# Public: where a train should dock at this island, in world space. The rail
# network reads this so rails and islands can never drift apart.
func get_platform_pos(isle_id: String) -> Vector3:
	for isle in ISLES:
		if isle["id"] == isle_id:
			var pos: Vector3 = isle["pos"]
			var radius: float = isle["radius"]
			# Docking edge faces the castle at the origin.
			var toward_castle := (Vector3(-32.3, pos.y, -2.0) - pos)
			toward_castle.y = 0.0
			return pos + toward_castle.normalized() * (radius - 3.0) + Vector3(0, 1.2, 0)
	return Vector3.ZERO


# --- construction ------------------------------------------------------

func _build_isle(isle: Dictionary, index: int) -> void:
	var isle_id: String = isle["id"]
	var pos: Vector3 = isle["pos"]
	var radius: float = isle["radius"]
	var color: Color = isle["color"]
	var emissive_start := _emissive_materials.size()
	var shader_start := _shader_materials.size()
	var rock_start := _rock_materials.size()
	var rock_base_start := _rock_base.size()

	var root := Node3D.new()
	root.name = "SkyIsle_%s" % isle_id
	root.position = pos
	add_child(root)
	_isle_nodes[isle_id] = root

	# Island body: reuse the prototype's shared builder so these read as the
	# same world the rails came from.
	var builder: GDScript = load(IsleBuilderScript)
	if builder != null:
		# Pass our own material rather than letting the builder make one:
		# build_island() keeps its material private, so the island body would
		# never join the stage system and the rock stayed flat grey while all
		# the dressing around it lit up.
		var rock := StandardMaterial3D.new()
		rock.albedo_color = color.darkened(0.45)
		rock.roughness = 0.9
		# Rock is lit by the sun, not self-lit: it takes the island's colour
		# through albedo and leaves the glowing to the crystals and runes.
		# Giving it emission too washed the whole island into one flat tone.
		rock.emission_enabled = false
		_rock_materials.append(rock)
		_rock_base.append(rock.albedo_color)

		var body: Node3D = builder.build_island_with_material(
			radius, rock, 1, index * 7 + 3)
		root.add_child(body)
	else:
		push_warning("hub_sky_isles: isle_builder missing, island %s has no body" % isle_id)

	_build_walkable_floor(root, radius)
	_build_terrain_character(root, isle_id, color, radius)
	_build_platform(root, radius, color)
	_build_landmark(root, isle_id, color)
	_build_portal(root, isle, color)

	# Magic-meets-technology detailing: rune disc, brass anchor ring, crystal
	# lamps, railing, and the kingdom's own mechanism. Kept in its own file
	# because the dressing is longer than the layout it decorates.
	var dressing: Dictionary = IsleDressing.dress_isle(root, isle_id, color, radius)
	for material in dressing["standard"]:
		_emissive_materials.append(material)
	for material in dressing["shader"]:
		_shader_materials.append(material)

	_island_states[isle_id] = {
		"vibrant": false,
		"spin_speed": 0.0,
		"emissive": _emissive_materials.slice(emissive_start),
		"shader": _shader_materials.slice(shader_start),
		"rock": _rock_materials.slice(rock_start),
		"rock_base": _rock_base.slice(rock_base_start),
		"spinners": dressing["spinners"],
	}


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F5:
			var citadel := get_parent().get_node_or_null("LumenCitadel")
			if citadel != null and citadel.has_method("set_vibrant"):
				citadel.call("set_vibrant", not bool(citadel.call("is_vibrant")))
		KEY_F6:
			toggle_island("mind")
		KEY_F7:
			toggle_island("heart")
		KEY_F8:
			toggle_island("creator")
		KEY_F9:
			var wake_all := not (
				is_island_vibrant("mind") and is_island_vibrant("heart")
				and is_island_vibrant("creator"))
			for isle_id in ["mind", "heart", "creator"]:
				set_island_vibrant(isle_id, wake_all)
	_update_debug_panel()


func _build_debug_panel() -> void:
	if not OS.is_debug_build():
		return
	var layer := CanvasLayer.new()
	layer.name = "IslandStateDebug"
	add_child(layer)
	_debug_label = Label.new()
	_debug_label.position = Vector2(18.0, 70.0)
	_debug_label.add_theme_font_size_override("font_size", 14)
	_debug_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.76))
	_debug_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.10, 0.9))
	_debug_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(_debug_label)
	_update_debug_panel()


func _update_debug_panel() -> void:
	if _debug_label == null:
		return
	_debug_label.text = "ISLAND STATES  F5 Castle  F6 Mind  F7 Heart  F8 Creator  F9 All\nMind: %s   Heart: %s   Creator: %s" % [
		_state_word("mind"), _state_word("heart"), _state_word("creator")]


func _state_word(isle_id: String) -> String:
	return "VIBRANT" if is_island_vibrant(isle_id) else "dormant"


# A flat collision disc just under the island's visible top, so the player
# can actually walk here. The builder's mound is visual only — it ships no
# collision, and without this the player would fall straight through.
func _build_walkable_floor(parent: Node3D, radius: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"

	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius * 0.92
	cylinder.height = 2.0
	shape.shape = cylinder
	# Top of the collider meets the mound's actual surface (the builder sinks
	# its squashed sphere, so the walkable top is near +radius*0.10, not 0).
	# Half the collider's height below that puts the player's feet on rock.
	shape.position.y = radius * 0.10 - 1.0
	body.add_child(shape)

	parent.add_child(body)


# The shared island builder provides a coherent world silhouette. This second,
# cheap layer gives each kingdom the terrain character promised by the brief
# without replacing the reliable flat collision disc underneath.
func _build_terrain_character(parent: Node3D, isle_id: String, color: Color,
		radius: float) -> void:
	var terrain := Node3D.new()
	terrain.name = "TerrainCharacter_%s" % isle_id
	parent.add_child(terrain)

	match isle_id:
		"mind":
			_build_mind_cliffs(terrain, color, radius)
		"heart":
			_build_heart_hills(terrain, color, radius)
		"creator":
			_build_creator_canvas(terrain, color, radius)


func _build_mind_cliffs(parent: Node3D, color: Color, radius: float) -> void:
	var crystal_rock := _terrain_material(color.darkened(0.32))
	# An uneven crescent of crystalline cliff shards leaves the island centre
	# open for walking and gives the silhouette an analytical, faceted edge.
	for i in 8:
		var angle := lerpf(-1.2, 1.3, float(i) / 7.0) + PI
		var height := 4.0 + float((i * 5) % 4) * 1.7
		var shard := MeshInstance3D.new()
		shard.name = "CrystalCliff_%02d" % i
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 1.3 + float(i % 3) * 0.35
		mesh.height = height
		mesh.radial_segments = 5
		shard.mesh = mesh
		shard.position = Vector3(cos(angle) * radius * 0.62,
			radius * 0.10 + height * 0.42, sin(angle) * radius * 0.62)
		shard.rotation_degrees.z = -8.0 + float(i) * 2.2
		shard.material_override = crystal_rock
		parent.add_child(shard)


func _build_heart_hills(parent: Node3D, color: Color, radius: float) -> void:
	var hill_material := _terrain_material(color.darkened(0.28))
	var hill_data := [
		[Vector3(-7.5, 1.5, 5.5), Vector3(7.5, 2.3, 6.5)],
		[Vector3(7.0, 1.1, 5.5), Vector3(6.0, 1.8, 7.0)],
		[Vector3(-8.0, 0.8, -7.0), Vector3(6.5, 1.5, 5.0)],
	]
	for i in hill_data.size():
		var data: Array = hill_data[i]
		var hill := MeshInstance3D.new()
		hill.name = "SoftHill_%02d" % i
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 8
		mesh.rings = 4
		hill.mesh = mesh
		hill.position = data[0]
		hill.position.y += radius * 0.10
		hill.scale = data[1]
		hill.material_override = hill_material
		parent.add_child(hill)

	# A small reflective pool beside the bandstand. Transparency and restrained
	# emission keep it readable as water without an expensive reflection probe.
	var pool := MeshInstance3D.new()
	pool.name = "MelodyPool"
	var pool_mesh := CylinderMesh.new()
	pool_mesh.top_radius = 4.6
	pool_mesh.bottom_radius = 4.3
	pool_mesh.height = 0.10
	pool_mesh.radial_segments = 16
	pool.mesh = pool_mesh
	pool.position = Vector3(7.0, radius * 0.10 + 0.24, -5.5)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.50, 0.76, 0.96, 0.62)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.metallic = 0.45
	water.roughness = 0.12
	water.emission_enabled = true
	water.emission = Color(0.62, 0.80, 1.0)
	water.emission_energy_multiplier = 0.0
	pool.material_override = water
	_emissive_materials.append(water)
	parent.add_child(pool)


func _build_creator_canvas(parent: Node3D, color: Color, radius: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := 7
	var size := radius * 1.20
	var step := size / float(cells)
	for z in cells:
		for x in cells:
			var x0 := -size * 0.5 + float(x) * step
			var x1 := x0 + step
			var z0 := -size * 0.5 + float(z) * step
			var z1 := z0 + step
			var a := Vector3(x0, _canvas_height(x0, z0, radius), z0)
			var b := Vector3(x1, _canvas_height(x1, z0, radius), z0)
			var c := Vector3(x0, _canvas_height(x0, z1, radius), z1)
			var d := Vector3(x1, _canvas_height(x1, z1, radius), z1)
			for vertex in [a, c, b, b, c, d]:
				st.add_vertex(vertex)
	st.generate_normals()
	var canvas := MeshInstance3D.new()
	canvas.name = "CanvasHill"
	canvas.mesh = st.commit()
	canvas.material_override = _terrain_material(color.darkened(0.18))
	parent.add_child(canvas)


func _canvas_height(x: float, z: float, radius: float) -> float:
	var wave := sin(x * 0.42) * 0.34 + cos(z * 0.36) * 0.28
	var brush := sin((x + z) * 0.23) * 0.18
	return radius * 0.10 + 0.16 + wave + brush


func _terrain_material(base: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.roughness = 0.86
	_rock_materials.append(material)
	_rock_base.append(base)
	return material


# The station platform where a train docks and the player steps off.
func _build_platform(parent: Node3D, radius: float, color: Color) -> void:
	var toward_castle := (Vector3(-32.3, 0.0, -2.0) - Vector3(parent.position.x, 0.0, parent.position.z)).normalized()
	var platform_pos := toward_castle * (radius - 3.0)

	var deck := MeshInstance3D.new()
	deck.name = "Platform"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(9.0, 0.6, 7.0)
	deck.mesh = mesh
	deck.position = platform_pos + Vector3(0.0, 0.6, 0.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = color.lightened(0.25)
	material.roughness = 0.7
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.0
	deck.material_override = material
	_emissive_materials.append(material)
	parent.add_child(deck)

	# Collision for the deck so the player can stand on it when they arrive.
	var deck_body := StaticBody3D.new()
	var deck_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
	deck_shape.shape = box
	deck_body.add_child(deck_shape)
	deck_body.position = deck.position
	parent.add_child(deck_body)


# One silhouette per kingdom, so each island is recognisable at a glance
# from the village below. Kept to primitives — these are read at distance.
func _build_landmark(parent: Node3D, isle_id: String, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.0
	_emissive_materials.append(material)

	match isle_id:
		"mind":
			# Observatory towers — thin, tall, mismatched heights.
			for i in 3:
				var tower := MeshInstance3D.new()
				var mesh := CylinderMesh.new()
				mesh.top_radius = 1.1
				mesh.bottom_radius = 1.6
				mesh.height = 13.0 + float(i) * 4.0
				mesh.radial_segments = 8
				tower.mesh = mesh
				tower.position = Vector3(-4.0 + float(i) * 4.5, mesh.height * 0.5 + 0.5, 2.0)
				tower.material_override = material
				parent.add_child(tower)

				var spire := MeshInstance3D.new()
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 1.6
				cone.height = 4.5
				cone.radial_segments = 8
				spire.mesh = cone
				spire.position = tower.position + Vector3(0, mesh.height * 0.5 + 2.2, 0)
				spire.material_override = material
				parent.add_child(spire)

		"heart":
			# Bandstand: a ring of posts under a conical roof.
			for i in 6:
				var angle := TAU * float(i) / 6.0
				var post := MeshInstance3D.new()
				var mesh := CylinderMesh.new()
				mesh.top_radius = 0.35
				mesh.bottom_radius = 0.35
				mesh.height = 6.0
				mesh.radial_segments = 6
				post.mesh = mesh
				post.position = Vector3(cos(angle) * 5.0, 3.5, sin(angle) * 5.0)
				post.material_override = material
				parent.add_child(post)

			var roof := MeshInstance3D.new()
			var roof_mesh := CylinderMesh.new()
			roof_mesh.top_radius = 0.0
			roof_mesh.bottom_radius = 7.0
			roof_mesh.height = 4.0
			roof_mesh.radial_segments = 8
			roof.mesh = roof_mesh
			roof.position = Vector3(0, 8.5, 0)
			roof.material_override = material
			parent.add_child(roof)

		"creator":
			# Glass-dome studio: a faceted hemisphere on a low drum.
			var drum := MeshInstance3D.new()
			var drum_mesh := CylinderMesh.new()
			drum_mesh.top_radius = 6.0
			drum_mesh.bottom_radius = 6.5
			drum_mesh.height = 3.0
			drum_mesh.radial_segments = 8
			drum.mesh = drum_mesh
			drum.position = Vector3(0, 2.0, 0)
			drum.material_override = material
			parent.add_child(drum)

			var dome := MeshInstance3D.new()
			var dome_mesh := SphereMesh.new()
			dome_mesh.radius = 6.0
			dome_mesh.height = 8.0
			dome_mesh.radial_segments = 8
			dome_mesh.rings = 4
			dome_mesh.is_hemisphere = true
			dome.mesh = dome_mesh
			dome.position = Vector3(0, 3.5, 0)

			# Glass: same colour, but translucent so the dome reads as a
			# studio rather than a solid lump.
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(color.r, color.g, color.b, 0.45)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.roughness = 0.15
			glass.emission_enabled = true
			glass.emission = color
			glass.emission_energy_multiplier = 0.0
			dome.material_override = glass
			_emissive_materials.append(glass)
			parent.add_child(dome)


# The portal that carries the player into this kingdom's experience. Same
# Area3D + change_scene_to_file shape the hub's ground portals already use,
# so behaviour is identical to what the player has already learned.
func _build_portal(parent: Node3D, isle: Dictionary, color: Color) -> void:
	var portal := Area3D.new()
	portal.name = "Portal_%s" % isle["id"]
	portal.position = Vector3(0.0, 2.0, -8.0)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 4.0)
	shape.shape = box
	portal.add_child(shape)

	# Visible marker so the portal is not an invisible trap.
	var marker := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.6
	mesh.outer_radius = 2.2
	mesh.rings = 8
	mesh.ring_segments = 6
	marker.mesh = mesh
	marker.rotation_degrees.x = 90.0

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.0
	marker.material_override = material
	_emissive_materials.append(material)
	portal.add_child(marker)

	var target: String = isle["scene"]
	portal.body_entered.connect(func(body: Node3D) -> void:
		if body is CharacterBody3D:
			get_tree().change_scene_to_file(target))

	parent.add_child(portal)


func _current_stage() -> int:
	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return 0
	return clampi(js.stage, 0, STAGE_GLOW.size() - 1)
