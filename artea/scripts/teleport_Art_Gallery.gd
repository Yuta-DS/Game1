extends Area3D

const TARGET_SCENE_PATH = "res://scenes/art_gallery_3d_inprogress.tscn"
const CASTLE_NODE_NAME := "building_castle_red2"

# Measured from the imported castle mesh. Its root is scaled 10x and rotated
# 90 degrees in New_Hub_World, so local +Z is the visible world +X door face.
const DOOR_LOCAL_ANCHOR := Vector3(0.0, 0.38, 1.16)
const DOOR_TRIGGER_SIZE := Vector3(2.8, 7.0, 4.8)

const BRASS := Color(0.76, 0.52, 0.20)
const DOOR_GLOW := Color(1.0, 0.76, 0.32)

## The trigger now lives only at the real castle doorway, safely beyond the
## completed stair landing. Crossing that threshold should feel like walking
## into a building, so it enters automatically; trains remain explicit Q choices.
@export var require_interact := false

var _player_inside: Node3D = null
var _travelling := false
var _prompt: Label3D
var _castle: Node3D


func _ready() -> void:
	# The packed scene already carries a legacy body_entered connection. Guarding
	# both signals removes the duplicate-connect runtime error without depending
	# on whether a future scene author keeps or removes that serialized link.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	_castle = get_parent().get_node_or_null(CASTLE_NODE_NAME) as Node3D
	_configure_live_door()
	_build_door_dressing()

	if require_interact:
		_prompt = Label3D.new()
		_prompt.text = "Press Q — Art Gallery"
		_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# Drawn through geometry so the prompt cannot be hidden by the doorframe.
		_prompt.no_depth_test = true
		_prompt.modulate = Color(1.0, 0.93, 0.75)
		_prompt.outline_size = 8
		_prompt.pixel_size = 0.012
		_prompt.visible = false
		add_child(_prompt)
		_prompt.position = Vector3(0.0, 4.5, 0.0)


func _process(_delta: float) -> void:
	# LumenCitadel gives the castle a 0.32 m idle drift. Follow its imported
	# local door anchor so the interaction volume and light never lag behind.
	#
	# The whole GLOBAL transform is rewritten, not just the origin. Setting
	# global_position alone leaves this node carrying whatever rotation and
	# scale its parent contributes; under the 10x-scaled, 90-degree-rotated
	# castle that stretched the doorframe boxes into the loose diagonal brass
	# bars floating over the terrace, and skewed the trigger volume with them.
	if _castle != null:
		global_transform = Transform3D(Basis.IDENTITY,
			_castle.to_global(DOOR_LOCAL_ANCHOR))


func _configure_live_door() -> void:
	# The old Area used a scaled parent plus a translated shared collision shape,
	# which put the trigger at Y=37.2 while the castle starts at Y=65.5.
	#
	# scale/rotation are LOCAL, so clearing them does not undo a scaled parent.
	# Reset the global basis instead, matching _process.
	if _castle != null:
		global_transform = Transform3D(Basis.IDENTITY,
			_castle.to_global(DOOR_LOCAL_ANCHOR))
	else:
		global_transform = Transform3D(Basis.IDENTITY, global_position)

	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null:
		return
	collision.position = Vector3.ZERO
	collision.rotation = Vector3.ZERO
	var box := BoxShape3D.new()
	box.size = DOOR_TRIGGER_SIZE
	collision.shape = box


# A readable entrance rather than an invisible trigger: stone doorway, brass
# mechanism, a rune aperture and warm light. It deliberately stays inexpensive
# (primitive meshes, one unshadowed light) while carrying Artéa's science/magic
# language all the way to the castle door.
func _build_door_dressing() -> void:
	var rig := Node3D.new()
	rig.name = "GalleryDoorRig"
	add_child(rig)

	var brass := StandardMaterial3D.new()
	brass.albedo_color = BRASS
	brass.metallic = 0.84
	brass.roughness = 0.28

	var glow := StandardMaterial3D.new()
	glow.albedo_color = DOOR_GLOW
	glow.emission_enabled = true
	glow.emission = DOOR_GLOW
	glow.emission_energy_multiplier = 2.1
	glow.roughness = 0.2

	_add_box(rig, Vector3(0.34, 6.4, 0.42), Vector3(0.0, 0.0, -2.65), brass)
	_add_box(rig, Vector3(0.34, 6.4, 0.42), Vector3(0.0, 0.0, 2.65), brass)
	_add_box(rig, Vector3(0.34, 0.55, 5.75), Vector3(0.0, 3.2, 0.0), brass)

	var rune := MeshInstance3D.new()
	var rune_mesh := TorusMesh.new()
	rune_mesh.inner_radius = 2.15
	rune_mesh.outer_radius = 2.42
	rune_mesh.rings = 16
	rune_mesh.ring_segments = 5
	rune.mesh = rune_mesh
	rune.rotation_degrees.z = 90.0
	rune.material_override = glow
	rig.add_child(rune)

	for z in [-3.05, 3.05]:
		var crystal := MeshInstance3D.new()
		var crystal_mesh := SphereMesh.new()
		crystal_mesh.radius = 0.34
		crystal_mesh.height = 1.15
		crystal_mesh.radial_segments = 6
		crystal_mesh.rings = 3
		crystal.mesh = crystal_mesh
		crystal.position = Vector3(0.0, 2.45, z)
		crystal.material_override = glow
		rig.add_child(crystal)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(1.5, 1.0, 0.0)
	lamp.light_color = Color(1.0, 0.82, 0.52)
	lamp.light_energy = 3.2
	lamp.omni_range = 15.0
	lamp.shadow_enabled = false
	rig.add_child(lamp)


func _add_box(parent: Node3D, size: Vector3, position: Vector3,
		material: Material) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = position
	part.material_override = material
	parent.add_child(part)


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	_player_inside = body
	if not require_interact:
		_travel()
	elif _prompt:
		_prompt.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body == _player_inside:
		_player_inside = null
		if _prompt:
			_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside and require_interact and event.is_action_pressed("interact"):
		_travel()


func _travel() -> void:
	# body_entered can report twice in a frame, and the scene swap is not
	# instant, so without this guard the change is queued more than once.
	if _travelling:
		return
	_travelling = true
	# Changing the scene inside a physics callback frees this Area3D while the
	# physics server is still iterating it. Deferring runs the swap once the
	# callback has unwound.
	get_tree().change_scene_to_file.call_deferred(TARGET_SCENE_PATH)
