# A glowing arrow that floats above the player and points to the hub castle's
# door at the top of the stair, which leads into the Art Castle and its worlds.
#
# Milo summons it (see chatbot.gd _show_castle_arrow) after telling the player
# that new worlds await at the top of the castle. It only exists in a scene
# that has that castle door, removes itself once the player arrives, and is
# freed with the scene, so it never follows the player anywhere else.
#
# Built in layers so it reads as magic rather than a plain marker: a bright
# gold core, a soft additive glow shell that breathes, a halo ring spinning
# around the shaft, and a trail of sparkles drifting from the tail.
extends Node3D

## How high above the player's origin the arrow floats.
const HOVER_HEIGHT := 3.0
## Within this distance of the door the player has arrived; walking through
## it changes scene, which frees the arrow anyway.
const ARRIVE_DISTANCE := 8.0
const ARROW_COLOR := Color(1.0, 0.7, 0.18)
const GLOW_COLOR := Color(1.0, 0.66, 0.18)
const SPARKLE_COLOR := Color(1.0, 0.93, 0.62)
const SHAFT_LENGTH := 1.2
const SHAFT_RADIUS := 0.1
const HEAD_LENGTH := 0.8
const HEAD_RADIUS := 0.4
## How much larger the glow shell is than the core.
const GLOW_SCALE := 1.7
## Halo ring turns per second around the arrow's own axis.
const HALO_SPIN := 2.2

## World position the arrow points at. Set by whoever spawns it.
var target := Vector3.ZERO
## Optional live target. The castle drifts gently, and its door trigger moves
## with it, so the arrow follows the node rather than a fixed point.
var target_node: Node3D

var _player: Node3D
var _pivot: Node3D
var _glow: Node3D
var _glow_material: StandardMaterial3D
var _halo: Node3D
var _label: Label3D
var _time := 0.0


func _ready() -> void:
	_build_arrow()


func _process(delta: float) -> void:
	if not _resolve_player():
		visible = false
		return
	visible = true
	_time += delta
	if target_node != null and is_instance_valid(target_node):
		target = target_node.global_position

	var anchor := _player.global_position + Vector3(0.0, HOVER_HEIGHT, 0.0)
	global_position = anchor + Vector3(0.0, sin(_time * 2.4) * 0.15, 0.0)

	var to_target := target - global_position
	var distance := to_target.length()
	if distance <= ARRIVE_DISTANCE:
		queue_free()
		return
	# look_at has no valid basis when the direction lines up with UP; that only
	# happens directly beneath the door, inside the arrival radius anyway.
	if absf(to_target.normalized().dot(Vector3.UP)) < 0.98:
		_pivot.look_at(target, Vector3.UP)

	# The glow breathes and the halo spins; both are cosmetic only.
	var breath := 0.5 + 0.5 * sin(_time * 3.1)
	_glow.scale = Vector3.ONE * lerpf(0.94, 1.1, breath)
	_glow_material.albedo_color.a = lerpf(0.1, 0.24, breath)
	_halo.rotation.z = wrapf(_halo.rotation.z + delta * HALO_SPIN, -PI, PI)
	_label.text = "New worlds await\nCastle · %d m" % int(round(distance))


func _resolve_player() -> bool:
	if _player != null and is_instance_valid(_player) and _player.is_inside_tree():
		return true
	_player = null
	var manager := get_node_or_null("/root/MiloCompanionManager")
	if manager != null:
		var active: Variant = manager.get("active_player")
		if active is Node3D and is_instance_valid(active):
			_player = active
			return true
	for group_name in [&"player", &"Player"]:
		for candidate in get_tree().get_nodes_in_group(group_name):
			if candidate is CharacterBody3D:
				_player = candidate
				return true
	return false


func _build_arrow() -> void:
	# The pivot's -Z axis is what look_at aims, so the arrow is built lying
	# along -Z: cylinders stand on +Y, and -90 degrees about X turns +Y to -Z.
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)

	var core := StandardMaterial3D.new()
	core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.albedo_color = ARROW_COLOR
	core.emission_enabled = true
	core.emission = ARROW_COLOR
	core.emission_energy_multiplier = 1.2
	_add_arrow_shape(_pivot, "Core", 1.0, core)

	_glow_material = StandardMaterial3D.new()
	_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	# Drawn after the core so the overlap blends evenly instead of streaking.
	_glow_material.render_priority = 1
	_glow_material.albedo_color = Color(GLOW_COLOR, 0.25)
	_glow = Node3D.new()
	_glow.name = "Glow"
	_pivot.add_child(_glow)
	_add_arrow_shape(_glow, "Glow", GLOW_SCALE, _glow_material)

	_build_halo()
	_build_sparkles()
	_build_caption()


# Shaft behind the origin, head in front of it, both along -Z.
func _add_arrow_shape(parent: Node3D, prefix: String, girth: float,
		material: Material) -> void:
	var shaft := MeshInstance3D.new()
	shaft.name = "%sShaft" % prefix
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = SHAFT_RADIUS * girth
	shaft_mesh.bottom_radius = SHAFT_RADIUS * girth
	shaft_mesh.height = SHAFT_LENGTH
	shaft_mesh.radial_segments = 16
	shaft.mesh = shaft_mesh
	shaft.material_override = material
	shaft.rotation_degrees.x = -90.0
	shaft.position = Vector3(0.0, 0.0, SHAFT_LENGTH * 0.5)
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shaft)

	var head := MeshInstance3D.new()
	head.name = "%sHead" % prefix
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = HEAD_RADIUS * (1.0 + (girth - 1.0) * 0.45)
	head_mesh.height = HEAD_LENGTH * (1.0 + (girth - 1.0) * 0.25)
	head_mesh.radial_segments = 24
	head.mesh = head_mesh
	head.material_override = material
	head.rotation_degrees.x = -90.0
	head.position = Vector3(0.0, 0.0, -head_mesh.height * 0.5)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(head)


# A thin ring around the middle of the shaft, spun about the arrow's own axis.
func _build_halo() -> void:
	_halo = Node3D.new()
	_halo.name = "Halo"
	_halo.position = Vector3(0.0, 0.0, SHAFT_LENGTH * 0.45)
	_pivot.add_child(_halo)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(SPARKLE_COLOR, 0.8)

	var ring := MeshInstance3D.new()
	ring.name = "HaloRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.3
	ring_mesh.outer_radius = 0.36
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 8
	ring.mesh = ring_mesh
	ring.material_override = material
	# TorusMesh lies flat around +Y; stand it up around the -Z arrow axis.
	ring.rotation_degrees.x = 90.0
	# A slight tilt makes the spin visible instead of a ring turning in place.
	ring.rotation_degrees.y = 18.0
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.add_child(ring)


# Sparkles released from the tail in world space, so they trail behind as the
# arrow bobs and turns. CPU particles keep this working on the Web build.
func _build_sparkles() -> void:
	var sparkles := CPUParticles3D.new()
	sparkles.name = "Sparkles"
	sparkles.position = Vector3(0.0, 0.0, SHAFT_LENGTH)
	sparkles.local_coords = false
	sparkles.amount = 28
	sparkles.lifetime = 1.2
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 0.18
	sparkles.direction = Vector3(0.0, 0.0, 1.0)
	sparkles.spread = 30.0
	sparkles.initial_velocity_min = 0.3
	sparkles.initial_velocity_max = 0.8
	sparkles.gravity = Vector3(0.0, 0.35, 0.0)
	sparkles.scale_amount_min = 0.5
	sparkles.scale_amount_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(SPARKLE_COLOR, 1.0))
	fade.set_color(1, Color(GLOW_COLOR, 0.0))
	sparkles.color_ramp = fade

	# Tiny spheres rather than quads: they read as round motes from any angle.
	var mote := SphereMesh.new()
	mote.radius = 0.045
	mote.height = 0.09
	mote.radial_segments = 8
	mote.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	mote.material = material
	sparkles.mesh = mote
	sparkles.emitting = true
	_pivot.add_child(sparkles)


func _build_caption() -> void:
	_label = Label3D.new()
	_label.name = "Caption"
	_label.text = "New worlds await\nCastle"
	_label.position = Vector3(0.0, 0.95, 0.0)
	_label.font_size = 40
	_label.pixel_size = 0.006
	_label.outline_size = 14
	_label.modulate = Color(1.0, 0.96, 0.84)
	_label.outline_modulate = Color(0.36, 0.2, 0.03, 0.9)
	_label.line_spacing = -4.0
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 2
	add_child(_label)
