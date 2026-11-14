# Magic-meets-technology dressing for the sky islands.
#
# The islands' silhouettes are built by hub_sky_isles.gd; this is the layer
# that turns those shapes from primitives into places. Same design rule the
# rest of Artéa already follows (see artea_rune_circle.gdshader): read as
# magic from a distance, as machinery up close. Brass rings and gantries are
# the science half, floating crystal and rune light the magic half, and they
# are always the same object rather than two styles side by side.
#
# A helper, not a scene node: hub_sky_isles.gd calls dress_isle() while
# building each island. Kept in its own file because the detailing is longer
# than the island layout it decorates, and mixing them made both hard to read.
#
# Every material it creates is handed back so the caller can register it with
# the journey's stage system — the dressing wakes with everything else rather
# than carrying a second progress model.
extends RefCounted
class_name HubIsleDressing

const CrystalShader := preload("res://shaders/artea_crystal.gdshader")
const RuneShader := preload("res://shaders/artea_rune_circle.gdshader")

# Brass, for the machined half. Warm metal reads against the cool crystal
# light and matches the pylons hub_magitech.gd already put in the village.
const BRASS := Color(0.72, 0.52, 0.24)
const DARK_METAL := Color(0.26, 0.25, 0.31)


# Dresses one island. Returns every material and shader material that should
# respond to the journey stage, so the caller can tween them.
#
#   parent  the island's root node
#   isle_id "mind" | "heart" | "creator"
#   color   that kingdom's palette colour
#   radius  island radius, so dressing scales with the land
#
# Returns { "standard": [StandardMaterial3D...], "shader": [ShaderMaterial...],
#           "spinners": [Node3D...] }
static func dress_isle(parent: Node3D, isle_id: String, color: Color,
		radius: float) -> Dictionary:
	var out := {
		"standard": [],
		"shader": [],
		"spinners": [],
	}

	_add_rune_disc(parent, color, radius, out)
	_add_anchor_ring(parent, color, radius, out)
	_add_lamp_posts(parent, color, radius, out)
	_add_railing(parent, radius, out)

	match isle_id:
		"mind":
			_dress_mind(parent, color, out)
		"heart":
			_dress_heart(parent, color, out)
		"creator":
			_dress_creator(parent, color, out)

	return out


# --- shared dressing ---------------------------------------------------

# The etched circle every island stands on. This is the single strongest
# "magic and science are the same thing" mark in the project, and it already
# exists as a shader — reuse it rather than inventing a second language.
static func _add_rune_disc(parent: Node3D, color: Color, radius: float,
		out: Dictionary) -> void:
	var disc := MeshInstance3D.new()
	disc.name = "RuneDisc"

	var mesh := PlaneMesh.new()
	# Well inside the island rather than overhanging it. The shader is
	# additive and unshaded, so an oversized disc does not read as a mark on
	# the ground — it washes the whole island into a flat colour.
	mesh.size = Vector2(radius * 0.85, radius * 0.85)
	disc.mesh = mesh
	# The builder's mound is a squashed sphere sunk to -radius*0.12, so its
	# flat top sits near +radius*0.09, not at zero. A disc at Y~0 is buried
	# inside the rock and invisible; this clears the surface.
	disc.position.y = radius * 0.10 + 0.25
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := ShaderMaterial.new()
	material.shader = RuneShader
	material.set_shader_parameter("awake", 0.0)
	material.set_shader_parameter("glow_color", color)
	material.set_shader_parameter("accent_color", Color(1.0, 0.82, 0.45))
	# The shader defaults to 2.2, tuned for a portal circle read up close in
	# the village. Out here the disc is seen against bright sky, and at that
	# brightness it blows out the island it is drawn on.
	material.set_shader_parameter("brightness", 0.9)
	disc.material_override = material
	out["shader"].append(material)

	parent.add_child(disc)


# A brass ring standing around the island's rim, broken into segments so it
# reads as machined rather than moulded. The island looks held rather than
# merely floating.
static func _add_anchor_ring(parent: Node3D, color: Color, radius: float,
		out: Dictionary) -> void:
	var ring := Node3D.new()
	ring.name = "AnchorRing"
	parent.add_child(ring)

	var brass := StandardMaterial3D.new()
	brass.albedo_color = BRASS
	brass.metallic = 0.9
	brass.roughness = 0.35
	brass.emission_enabled = true
	brass.emission = color
	brass.emission_energy_multiplier = 0.0
	out["standard"].append(brass)

	# Everything sits on the mound's actual top, not on Y=0.
	var surface := radius * 0.10

	var segments := 12
	for i in segments:
		var angle := TAU * float(i) / float(segments)

		var strut := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.1, 2.4, 0.5)
		strut.mesh = mesh
		strut.position = Vector3(
			cos(angle) * (radius * 0.93), surface + 0.6, sin(angle) * (radius * 0.93))
		strut.rotation.y = -angle
		strut.material_override = brass
		ring.add_child(strut)


# Lamps on the rim: a brass post carrying a crystal that lights when the
# journey wakes. The machinery holds the magic up.
static func _add_lamp_posts(parent: Node3D, color: Color, radius: float,
		out: Dictionary) -> void:
	var posts := Node3D.new()
	posts.name = "Lamps"
	parent.add_child(posts)

	var brass := StandardMaterial3D.new()
	brass.albedo_color = BRASS
	brass.metallic = 0.85
	brass.roughness = 0.4
	out["standard"].append(brass)

	var surface := radius * 0.10

	var count := 6
	for i in count:
		var angle := TAU * float(i) / float(count) + 0.4

		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.16
		post_mesh.bottom_radius = 0.26
		post_mesh.height = 4.2
		post_mesh.radial_segments = 6
		post.mesh = post_mesh
		post.position = Vector3(
			cos(angle) * (radius * 0.78), surface + 2.1, sin(angle) * (radius * 0.78))
		post.material_override = brass
		posts.add_child(post)

		# The crystal the post carries.
		var shard := MeshInstance3D.new()
		var shard_mesh := SphereMesh.new()
		shard_mesh.radius = 0.55
		shard_mesh.height = 1.5
		shard_mesh.radial_segments = 6
		shard_mesh.rings = 3
		shard.mesh = shard_mesh
		shard.position = post.position + Vector3(0.0, 2.6, 0.0)
		shard.material_override = _crystal_material(color, out)
		posts.add_child(shard)


# A low railing so an island reads as somewhere meant to be stood on. Also
# the honest fix for "you can walk off the edge".
static func _add_railing(parent: Node3D, radius: float, out: Dictionary) -> void:
	var rail := Node3D.new()
	rail.name = "Railing"
	parent.add_child(rail)

	var metal := StandardMaterial3D.new()
	metal.albedo_color = DARK_METAL
	metal.metallic = 0.7
	metal.roughness = 0.5
	out["standard"].append(metal)

	var body := StaticBody3D.new()
	rail.add_child(body)

	var surface := radius * 0.10

	var segments := 24
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		var pos := Vector3(
			cos(angle) * (radius * 0.9), surface + 1.1, sin(angle) * (radius * 0.9))

		var post := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.18, 2.2, 0.18)
		post.mesh = mesh
		post.position = pos
		post.material_override = metal
		rail.add_child(post)

		# Collision so the player is actually stopped, not just warned.
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 2.6, 1.6)
		shape.shape = box
		shape.position = pos
		body.add_child(shape)


# --- per-kingdom dressing ----------------------------------------------

# Mind Spark: an orrery. Brass rings turning around a crystal core — the
# observatory's instrument, science measuring something luminous.
static func _dress_mind(parent: Node3D, color: Color, out: Dictionary) -> void:
	var orrery := Node3D.new()
	orrery.name = "Orrery"
	orrery.position = Vector3(0.0, 7.0, -4.0)
	parent.add_child(orrery)

	var brass := StandardMaterial3D.new()
	brass.albedo_color = BRASS
	brass.metallic = 0.9
	brass.roughness = 0.3
	out["standard"].append(brass)

	# Three rings on different axes so the instrument reads in the round.
	var axes := [Vector3(0, 0, 0), Vector3(PI * 0.5, 0, 0), Vector3(0, 0, PI * 0.4)]
	for i in axes.size():
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 3.0 + float(i) * 0.9
		mesh.outer_radius = 3.25 + float(i) * 0.9
		mesh.rings = 10
		mesh.ring_segments = 8
		ring.mesh = mesh
		ring.rotation = axes[i]
		ring.material_override = brass
		orrery.add_child(ring)
		out["spinners"].append(ring)

	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 1.5
	core_mesh.height = 3.6
	core_mesh.radial_segments = 6
	core_mesh.rings = 4
	core.mesh = core_mesh
	core.material_override = _crystal_material(color, out)
	orrery.add_child(core)


# Heart Melody: resonator pipes. A brass organ whose pipes hold light —
# instrument and machine at once.
static func _dress_heart(parent: Node3D, color: Color, out: Dictionary) -> void:
	var bank := Node3D.new()
	bank.name = "Resonators"
	bank.position = Vector3(-7.0, 0.0, 5.0)
	parent.add_child(bank)

	var brass := StandardMaterial3D.new()
	brass.albedo_color = BRASS
	brass.metallic = 0.9
	brass.roughness = 0.32
	out["standard"].append(brass)

	for i in 7:
		var height := 3.5 + sin(float(i) * 1.1) * 1.6 + float(i) * 0.55

		var pipe := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.42
		mesh.bottom_radius = 0.42
		mesh.height = height
		mesh.radial_segments = 8
		pipe.mesh = mesh
		pipe.position = Vector3(float(i) * 1.15, height * 0.5, 0.0)
		pipe.material_override = brass
		bank.add_child(pipe)

		# Each pipe is capped with a lit crystal bead — the note it holds.
		var bead := MeshInstance3D.new()
		var bead_mesh := SphereMesh.new()
		bead_mesh.radius = 0.36
		bead_mesh.height = 0.8
		bead_mesh.radial_segments = 6
		bead_mesh.rings = 3
		bead.mesh = bead_mesh
		bead.position = Vector3(float(i) * 1.15, height + 0.4, 0.0)
		bead.material_override = _crystal_material(color, out)
		bank.add_child(bead)


# Creator's Light: a gear flower around a crystal — the workshop's mechanism,
# machinery arranged like a bloom.
static func _dress_creator(parent: Node3D, color: Color, out: Dictionary) -> void:
	var mech := Node3D.new()
	mech.name = "GearFlower"
	mech.position = Vector3(0.0, 9.5, 0.0)
	parent.add_child(mech)

	var brass := StandardMaterial3D.new()
	brass.albedo_color = BRASS
	brass.metallic = 0.92
	brass.roughness = 0.28
	out["standard"].append(brass)

	# Two counter-turning gears, so the mechanism reads as driven.
	for i in 2:
		var gear := _gear(2.6 - float(i) * 0.7, 10 - i * 2, 0.28, brass)
		gear.position.y = float(i) * 0.9
		mech.add_child(gear)
		out["spinners"].append(gear)

	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 1.2
	core_mesh.height = 3.0
	core_mesh.radial_segments = 6
	core_mesh.rings = 4
	core.mesh = core_mesh
	core.position.y = 1.8
	core.material_override = _crystal_material(color, out)
	mech.add_child(core)


# A brass gear: a flat disc with teeth spaced around it, matching the ones
# hub_magitech.gd already builds in the village so the two read as one world.
static func _gear(radius: float, teeth: int, thickness: float,
		material: StandardMaterial3D) -> Node3D:
	var gear := Node3D.new()

	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = radius
	body_mesh.bottom_radius = radius
	body_mesh.height = thickness
	body_mesh.radial_segments = 12
	body.mesh = body_mesh
	body.material_override = material
	gear.add_child(body)

	var tooth_mesh := BoxMesh.new()
	tooth_mesh.size = Vector3(radius * 0.24, thickness, radius * 0.32)

	for i in teeth:
		var tooth := MeshInstance3D.new()
		tooth.mesh = tooth_mesh
		tooth.material_override = material
		var angle := TAU * float(i) / float(teeth)
		tooth.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		tooth.rotation.y = -angle
		gear.add_child(tooth)

	return gear


# The project's existing crystal shader, so island crystals and village
# pylon crystals are literally the same material.
static func _crystal_material(color: Color, out: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CrystalShader
	material.set_shader_parameter("awake", 0.0)
	material.set_shader_parameter("core_color", color)
	material.set_shader_parameter("rim_color", color.lightened(0.45))
	out["shader"].append(material)
	return material
