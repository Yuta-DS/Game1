extends Node

# Godot's occlusion culling isn't available while this project stays on the
# Compatibility renderer (needed for the web export), so distance-based
# visibility range is the renderer-agnostic substitute: chunks fully hidden
# by distance stop rendering instead of only relying on frustum culling.
#
# ProtonScatter chunks its output into small MultiMeshInstance3D nodes under
# scatter.output_root (one per ScatterItem per spatial chunk - see
# hub_bee_garden.gd's _collect_scatter_points for the same tree shape), so
# setting the range per chunk here works the same way it would on any other
# GeometryInstance3D.

@export var scatter_path: NodePath
@export var visibility_range_end := 70.0
@export var visibility_range_end_margin := 15.0


func _ready() -> void:
	var scatter := get_node_or_null(scatter_path)
	if scatter == null:
		return
	scatter.build_completed.connect(_apply_visibility_range.bind(scatter))
	# The scatter may have already finished building (e.g. on an in-editor
	# rebuild) before this node's _ready runs.
	if int(scatter.get("build_version")) >= 1:
		_apply_visibility_range(scatter)


func _apply_visibility_range(scatter: Node) -> void:
	var output_root := scatter.get("output_root") as Node3D
	if output_root == null:
		return
	for item_root in output_root.get_children():
		for chunk in item_root.get_children():
			var instance := chunk as GeometryInstance3D
			if instance == null:
				continue
			instance.visibility_range_end = visibility_range_end
			instance.visibility_range_end_margin = visibility_range_end_margin
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
