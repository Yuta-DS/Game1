# Scattered moss on the real stair walls from the terrain footing to the crown.
# Overlay preserves the underlying materials, UVs, meshes and collision shapes.
extends RefCounted

const MossShader := preload("res://shaders/castle_stair_moss.gdshader")
const COVERAGE := 0.18 # Restrained growth: the reference keep's stone stays dominant.
const ROOTS := ["CastleStairs/CastleStair", "CastleEntrance/CastleEntrance",
	"CastleArchitecture/RoyalEntranceCourtyard"]
# Court slabs are included for their vertical fascia only. The shader's normal
# mask excludes their walking tops and horizontal undersides; no extra layer
# or collision geometry is added to the terrace.
const FULL_NAMES := ["MasonryTower", "OuterStoneParapet", "InnerStoneParapet",
	"InnerSafetyPlinth", "TerrainFittedEntryFoundation", "GroundEntryTerrainFoundation",
	"GroundEntryLeftBarrier", "GroundEntryRightBarrier", "FourDressedStones",
	"SolidPalaceWall", "StoneSocle", "ContinuousCoping", "CrownStairwellInnerReturn",
	"CrownStairwellInnerReturnCoping", "CastleArrivalTerrace", "CastleArrivalUnderside",
	"CastleUpperCourt", "CastleUpperCourtUnderside"]
const PREFIXES := ["StoneCourse_", "FoundationButtress_", "GroundEntryFoundationButtress_",
	"GroundEntryStoneNewel_", "GroundEntryBarrierAshlar_", "OuterStoneNewel_",
	"CrownParapetJointPier_", "RoundedStairwellJoint_", "RoyalStairParapet",
	"RoyalStairNewel", "DoorBalconyGuard", "DoorBalconyReturn",
	"CastleUpperCourtSideBarrier_", "CourtyardSideBarrier", "BridgeMouthReturn",
	"StairFootReturn"]

static func apply(hub: Node3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = MossShader
	material.resource_name = "Feathered moss colonies / sparse trailing fronds"
	material.set_shader_parameter("remaining_fraction", COVERAGE)
	material.render_priority = 1
	material.set_meta("castle_stair_moss", true)
	var surfaces: Array[NodePath] = []
	for path: String in ROOTS:
		var root := hub.get_node_or_null(path)
		if root == null:
			continue
		for part: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			if not part.is_visible_in_tree() or part.mesh == null or not _selected(part):
				continue
			# Never overwrite another system's visual overlay.
			if part.material_overlay != null and not part.material_overlay.get_meta("castle_stair_moss", false):
				continue
			if part.material_overlay == null:
				part.material_overlay = material
			part.set_meta("moss_policy", "wall_colour_only_no_geometry_or_collision_change")
			surfaces.append(part.get_path())
	hub.set_meta("castle_stair_moss_surfaces", surfaces)
	hub.set_meta("castle_stair_moss_extent", "terrain_foundation_to_crown_upper_castle_stair_and_terrace_sides")

static func _selected(part: MeshInstance3D) -> bool:
	var label := String(part.name)
	# Leave the keep's defining dark courses/coping and raised stone details
	# legible, rather than treating every architectural surface as green canvas.
	if "Coping" in label or "Course" in label or "Ashlar" in label \
			or label == "FourDressedStones" or label == "StoneSocle":
		return false
	if label in FULL_NAMES:
		return true
	for prefix: String in PREFIXES:
		if label.begins_with(prefix):
			return true
	return false
