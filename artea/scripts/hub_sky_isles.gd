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
const BOB_AMPLITUDE := 0.35
const BOB_PERIOD := 9.0

# Island glow per journey stage. Index = JourneyState.stage.
const STAGE_GLOW := [0.0, 0.3, 0.55, 0.8, 1.0]

const WAKE_SECONDS := 2.0

var _emissive_materials: Array[StandardMaterial3D] = []
var _isle_nodes: Dictionary = {}
var _bob_time := 0.0


func _ready() -> void:
	# Let the hub finish building before adding to it.
	await get_tree().process_frame

	for i in ISLES.size():
		_build_isle(ISLES[i], i)

	apply_stage(_current_stage())


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


# Called by hub_awakening.gd so the islands wake in step with the rest of
# the world rather than tracking progress separately.
func apply_stage(stage: int) -> void:
	stage = clampi(stage, 0, STAGE_GLOW.size() - 1)
	if _emissive_materials.is_empty():
		return

	var target: float = STAGE_GLOW[stage]
	var tween := create_tween().set_parallel()
	for material in _emissive_materials:
		tween.tween_property(material, "emission_energy_multiplier",
			target * 1.5, WAKE_SECONDS).set_trans(Tween.TRANS_SINE)


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

	var root := Node3D.new()
	root.name = "SkyIsle_%s" % isle_id
	root.position = pos
	add_child(root)
	_isle_nodes[isle_id] = root

	# Island body: reuse the prototype's shared builder so these read as the
	# same world the rails came from.
	var builder: GDScript = load(IsleBuilderScript)
	if builder != null:
		var body: Node3D = builder.build_island(radius, color.darkened(0.35), 1, index * 7 + 3)
		root.add_child(body)
	else:
		push_warning("hub_sky_isles: isle_builder missing, island %s has no body" % isle_id)

	_build_walkable_floor(root, radius)
	_build_platform(root, radius, color)
	_build_landmark(root, isle_id, color)
	_build_portal(root, isle, color)


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
	# Sits just below the mound's surface so the player stands on the rock
	# rather than hovering above it.
	shape.position.y = -0.6
	body.add_child(shape)

	parent.add_child(body)


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
