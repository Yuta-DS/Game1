# Hub portal into the connected Crown of Life campaign.
#
# Built at runtime and added as a child of HubWorld (same convention as
# hub_lens.gd, hub_castle_entrance.gd, ...) so New_Hub_World.tscn only needs
# one bare Node3D with this script attached — the portal geometry itself stays
# out of the scene file.
#
# Visibly labelled and starts the Castle Galaxy journey on simple proximity:
# no prompt to read, no button to find.
extends Node3D

const SceneLoader := preload("res://scripts/scene_loader.gd")

const STORY_SCENE_PATH := "res://scenes/viewfinder/crown_of_life_story.tscn"
const CAMPAIGN_HOME_SCENE := "res://scenes/art_gallery_3d_inprogress.tscn"
const LABEL_TEXT := "Crown of Life Adventure • Begin Journey"

# Placed near the castle door plaza, clear of the causeway and any Cuttable
# geometry — a small, safe, walkable spot the player passes naturally.
const PORTAL_POSITION := Vector3(-30.0, 25.2, 20.0)

var _entered := false


func _ready() -> void:
	_build_portal()


func _build_portal() -> void:
	var rig := Node3D.new()
	rig.name = "CrownStoryPortalRig"
	add_child(rig)
	rig.position = PORTAL_POSITION

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.1
	torus.outer_radius = 1.4
	torus.rings = 24
	torus.ring_segments = 10
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffd76a")
	material.emission_enabled = true
	material.emission = Color("ffd76a")
	material.emission_energy_multiplier = 1.6
	material.metallic = 0.4
	material.roughness = 0.25
	ring.material_override = material
	ring.position.y = 1.4
	rig.add_child(ring)

	var glow := OmniLight3D.new()
	glow.light_color = Color("ffe9a8")
	glow.light_energy = 1.2
	glow.omni_range = 8.0
	glow.position.y = 1.4
	rig.add_child(glow)

	var label := Label3D.new()
	label.text = LABEL_TEXT
	label.font_size = 30
	label.outline_size = 9
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.6
	rig.add_child(label)

	var area := Area3D.new()
	area.name = "CrownStoryPortalArea"
	# Never Cuttable — this is a hub navigation trigger, not story geometry.
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 2.2
	cylinder.height = 3.0
	shape.shape = cylinder
	area.add_child(shape)
	area.position.y = 1.5
	rig.add_child(area)
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _entered:
		return
	if not (body is CharacterBody3D):
		return
	_entered = true
	# The real connected campaign starts in the Art Castle Galaxy. The Lens
	# story remains available through the JourneyCampaign guided-story route
	# for a future optional journal entry, but is no longer a competing route.
	var campaign := get_node_or_null("/root/JourneyCampaign")
	if campaign != null and campaign.has_method("start_campaign"):
		campaign.call("start_campaign")
	else:
		# Supports an isolated scene harness without restoring the legacy hub
		# route. Normal game launches always use the campaign autoload above.
		SceneLoader.change_scene_with_loading(get_tree(), CAMPAIGN_HOME_SCENE)
