# Attaches the Lens of Seeing to the hub world.
#
# Built at runtime and added as a child of HubWorld, matching the convention
# every other hub system follows (hub_magitech.gd, hub_castle_crown.gd, ...) —
# New_Hub_World.tscn stays untouched, so this can be removed cleanly and the
# scene diff stays empty.
#
# Two jobs:
#   1. find the player's camera and hang the lens off it
#   2. decide which of the hub's props are cuttable
#
# The second is the one with teeth. Cutting is opt-in per prop and must stay
# that way: Terrain3D is a streamed clipmap and ProtonScatter output is
# MultiMesh, neither of which has a per-instance mesh to cut
# (ViewFinder.txt §6.8). Tagging the world indiscriminately would fight the
# addons and, at best, do nothing.
extends Node3D

const ControllerScript := preload("res://scripts/viewfinder/lens_controller.gd")
const FrustumCutterScript := preload("res://scripts/viewfinder/frustum_cutter.gd")
const MeshCutterScript := preload("res://scripts/viewfinder/mesh_cutter.gd")

# Subtrees whose children are considered. Everything else in the hub is off
# limits by omission — terrain, ProtonScatter output, the rails and trains.
const CUTTABLE_ROOTS := ["Environment/mountains"]

# Individual top-level props, by name prefix. The village buildings are .glb
# instances with real mesh geometry and their own collision — the same shape
# of prop as the rocks, and the ones the player actually walks among, so
# without these the lens has nothing to frame anywhere they spend time.
const CUTTABLE_PREFIXES := ["building_"]

# Never cuttable, whatever else matches.
#
# The hub castle is the Castle Universe's anchor: hub_lumen_citadel,
# hub_castle_crown, hub_castle_entrance, the Gallery door trigger and the
# skyrail station all attach to it or measure from it. Slicing it would take
# the finale down with it. It is over the triangle budget too, so it would be
# refused anyway — but the refusal must be intentional and not a coincidence
# of its poly count.
const NEVER_CUTTABLE := ["building_castle_red2"]

# Props with more triangles than the cutter's budget are skipped rather than
# tagged and then refused at the moment the player presses the shutter. A
# refusal that only appears after framing reads as the mechanic being broken.
const TRIANGLE_BUDGET := MeshCutterScript.MAX_CUTTABLE_TRIANGLES

# The journey stage at which the lens becomes available. The three kingdoms
# come first: the Lens generalises what they teach, so handing it over before
# any of them have been played gives the player a tool with nothing to say.
const UNLOCK_STAGE := 1

var _controller: Node3D
var _tagged: Array[Node3D] = []


func _ready() -> void:
	# Let the hub finish building before reaching into it.
	await get_tree().process_frame

	if not _is_unlocked():
		return

	_tag_cuttable_props()
	_attach_to_player()


func _is_unlocked() -> bool:
	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return true
	return int(js.stage) >= UNLOCK_STAGE


# How many props were made cuttable. Public so a test can assert the tagging
# actually found something rather than silently matching nothing.
func tagged_count() -> int:
	return _tagged.size()


func controller() -> Node3D:
	return _controller


func _attach_to_player() -> void:
	var player := _find_player()
	if player == null:
		push_warning("hub_lens: no player found, the lens is not available")
		return

	var camera := _find_camera(player)
	if camera == null:
		push_warning("hub_lens: the player has no Camera3D, the lens is not available")
		return

	_controller = ControllerScript.new()
	_controller.name = "LensController"
	_controller.camera = camera
	# The controller is the capture point, so a held seeing must ride with the
	# view, not with the player's feet — parented to the camera it follows the
	# look direction as well as the position.
	camera.add_child(_controller)


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	for player in players:
		if player is Node3D:
			return player
	# The group is how NewPlayer.tscn identifies itself; fall back to the name
	# used in New_Hub_World.tscn in case the group is ever dropped.
	var named := get_parent().get_node_or_null("NewPlayer")
	return named as Node3D


static func _find_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found != null:
			return found
	return null


# Put the hub's discrete rock props on the Cuttable layer.
#
# These are .glb instances with real MeshInstance3D geometry and their own
# collision — exactly the shape of prop the cutter handles well, and the only
# thing in the hub that qualifies.
func _tag_cuttable_props() -> void:
	var hub := get_parent()
	if hub == null:
		return

	for path in CUTTABLE_ROOTS:
		var branch := hub.get_node_or_null(path)
		if branch == null:
			continue
		for child in branch.get_children():
			if child is Node3D:
				_tag_prop(child)

	# Top-level village props, matched by name.
	for child in hub.get_children():
		if child is Node3D and _is_taggable_by_name(String(child.name)):
			_tag_prop(child)


func _is_taggable_by_name(node_name: String) -> bool:
	if node_name in NEVER_CUTTABLE:
		return false
	for prefix in CUTTABLE_PREFIXES:
		if node_name.begins_with(prefix):
			return true
	return false


func _tag_prop(prop: Node3D) -> void:
	var mesh_instance := FrustumCutterScript._find_mesh_instance(prop)
	if mesh_instance == null or mesh_instance.mesh == null:
		return

	# Skip anything the cutter would refuse anyway, so the player never frames
	# a prop that turns out to be uncuttable at the shutter.
	if mesh_instance.mesh.get_faces().size() / 3 > TRIANGLE_BUDGET:
		return

	var body := _find_body(prop)
	if body == null:
		return

	# Added to the existing layer rather than replacing it: these rocks are
	# world collision the player already walks into, and clearing that would
	# let them fall through the mountains.
	body.collision_layer |= FrustumCutterScript.CUTTABLE_MASK
	_tagged.append(body)


static func _find_body(node: Node) -> CollisionObject3D:
	if node is CollisionObject3D:
		return node
	for child in node.get_children():
		var found := _find_body(child)
		if found != null:
			return found
	return null
