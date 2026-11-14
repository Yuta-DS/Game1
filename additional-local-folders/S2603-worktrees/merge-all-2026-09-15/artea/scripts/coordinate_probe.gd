extends Node
## Debug tool for the 3D hub worlds.
##
## Press F12 in-game to snapshot the player's position plus the nearest named
## buildings/assets in the current scene. Walks the scene tree instead of
## raycasting against physics colliders, so it works on art assets that have
## no CollisionShape3D. Output goes to the console, to tools/coordinate_log.txt,
## and to an on-screen overlay so it's visible without opening the console.

const LOG_PATH := "res://tools/coordinate_log.txt"
const MAX_RESULTS := 20
const ON_SCREEN_RESULTS := 8
const MAX_RADIUS := 150.0
const OVERLAY_SECONDS := 8.0

## Leaf/technical node types that clutter results without identifying a
## distinct building or asset -- excluded from the report, but their
## siblings are still visited.
const EXCLUDED_TYPES := [
	"MeshInstance3D", "CollisionShape3D", "CollisionPolygon3D",
	"Skeleton3D", "BoneAttachment3D", "RemoteTransform3D",
	"GPUParticles3D", "CPUParticles3D", "MultiMeshInstance3D",
	"OmniLight3D", "SpotLight3D", "DirectionalLight3D",
	"AudioStreamPlayer3D", "RayCast3D", "ShapeCast3D",
	"VisibleOnScreenNotifier3D", "VisibleOnScreenEnabler3D",
]

## Container types whose children are internal detail (bones, particles,
## LOD meshes) rather than separately placed objects -- don't recurse in.
const DONT_DESCEND_TYPES := [
	"Skeleton3D", "GPUParticles3D", "CPUParticles3D", "MultiMeshInstance3D",
]


var _overlay_layer: CanvasLayer
var _overlay_panel: PanelContainer
var _overlay_label: Label
var _hide_timer: Timer


func _ready() -> void:
	_build_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F12:
		_snapshot()
		get_viewport().set_input_as_handled()


func _snapshot() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var player := _get_player()
	var lines: PackedStringArray = []
	lines.append("=== %s | scene: %s ===" % [Time.get_datetime_string_from_system(), scene.name])

	if player == null:
		lines.append("(no Node3D in group \"player\" found)")
	else:
		lines.append("Player: %s" % _format_node(player, null))
		for node in _nearest_nodes(scene, player):
			lines.append(_format_node(node, player))

	var text := "\n".join(lines)
	print(text, "\n")
	_append_log(text)
	_show_overlay(lines)


func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 100
	add_child(_overlay_layer)

	_overlay_panel = PanelContainer.new()
	_overlay_panel.position = Vector2(16, 16)
	_overlay_panel.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.75)
	bg.content_margin_left = 10
	bg.content_margin_right = 10
	bg.content_margin_top = 8
	bg.content_margin_bottom = 8
	_overlay_panel.add_theme_stylebox_override("panel", bg)
	_overlay_layer.add_child(_overlay_panel)

	_overlay_label = Label.new()
	_overlay_label.custom_minimum_size = Vector2(480, 0)
	_overlay_label.add_theme_font_size_override("font_size", 14)
	_overlay_label.add_theme_color_override("font_color", Color.WHITE)
	_overlay_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_overlay_panel.add_child(_overlay_label)

	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.wait_time = OVERLAY_SECONDS
	_hide_timer.timeout.connect(func(): _overlay_panel.visible = false)
	add_child(_hide_timer)


func _show_overlay(lines: PackedStringArray) -> void:
	var shown := lines.slice(0, 1 + ON_SCREEN_RESULTS)
	_overlay_label.text = "\n".join(shown)
	_overlay_panel.reset_size()
	_overlay_panel.visible = true
	_hide_timer.start()


func _get_player() -> Node3D:
	for n in get_tree().get_nodes_in_group("player"):
		if n is Node3D:
			return n
	return null


func _nearest_nodes(scene: Node, player: Node3D) -> Array[Node3D]:
	var candidates: Array[Node3D] = []
	_collect(scene, player, candidates)
	var origin := player.global_position
	candidates.sort_custom(func(a, b): return a.global_position.distance_to(origin) < b.global_position.distance_to(origin))
	return candidates.slice(0, MAX_RESULTS)


func _collect(node: Node, player: Node3D, out: Array[Node3D]) -> void:
	for child in node.get_children():
		if child == player or player.is_ancestor_of(child):
			continue
		if child is Node3D and not EXCLUDED_TYPES.has(child.get_class()):
			var d: float = child.global_position.distance_to(player.global_position)
			if d <= MAX_RADIUS:
				out.append(child)
		if not DONT_DESCEND_TYPES.has(child.get_class()):
			_collect(child, player, out)


func _format_node(node: Node3D, player: Node3D) -> String:
	var p := node.global_position
	var s := "%s: (%.2f, %.2f, %.2f)" % [node.name, p.x, p.y, p.z]
	if player != null:
		s += "  [%.1fm away]" % p.distance_to(player.global_position)
	return s


func _append_log(text: String) -> void:
	if not DirAccess.dir_exists_absolute("res://tools"):
		DirAccess.make_dir_recursive_absolute("res://tools")
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE
	var f := FileAccess.open(LOG_PATH, mode)
	if f == null:
		push_warning("coordinate_probe: could not open %s (%s)" % [LOG_PATH, FileAccess.get_open_error()])
		return
	f.seek_end()
	f.store_line(text)
	f.store_line("")
	f.close()
