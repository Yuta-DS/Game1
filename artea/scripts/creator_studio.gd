extends Node3D
const TouchDevice := preload("res://scripts/touch_controls.gd")
const SceneLoader := preload("res://scripts/scene_loader.gd")

## Creator's Light studio. Stepping onto the raised floor grows the player
## SIZE_MULTIPLIER times with a clockwise spin, so the easels are in reach;
## stepping off shrinks them back with an anticlockwise spin. Near an easel the
## `interact` key opens the drawing tool over the world, with the camera held
## still. Saving there works exactly as in the drawing scene; Escape or "Back
## to Studio" closes it and the drawing appears on that easel's canvas.
##
## Sits at the district centre. The world builder sets platform_half,
## platform_top and easel_positions (all local to this node).

const DRAWING_TOOL_SCENE := "res://scenes/drawing_tool.tscn"
const PROMPT_TEXT := "Press Q to paint"
const SIZE_MULTIPLIER := 8.0
const SPIN_SECONDS := 0.8
## Horizontal reach from an easel's centre, for the grown player.
const PAINT_RANGE := 40.0
const CAMERA_PROPERTIES := ["follow_height", "follow_distance", "follow_look_at_offset",
	"min_follow_distance", "max_follow_distance"]

var platform_half := Vector2(90.0, 82.0)
var platform_top := 2.0
var easel_positions: Array[Vector3] = []
## Each easel's canvas mesh, same order as easel_positions.
var easel_canvases: Array[MeshInstance3D] = []

var _player: CharacterBody3D
var _big := false
var _tween: Tween
var _camera_base: Dictionary = {}
var _prompt: Label
var _drawing_layer: CanvasLayer
var _drawing_tool: Node
var _easel_in_reach := -1
var _painting_easel := -1
var _fetching_tool := false


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.name = "StudioPrompt"
	layer.layer = 40
	add_child(layer)
	_prompt = Label.new()
	_prompt.text = PROMPT_TEXT
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 5)
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -96.0
	_prompt.offset_bottom = -60.0
	_prompt.visible = false
	layer.add_child(_prompt)


func is_player_big() -> bool:
	return _big


func is_paint_prompt_visible() -> bool:
	return _prompt != null and _prompt.visible


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as CharacterBody3D
		if _player == null or not _player.has_method("set_size_multiplier"):
			_player = null
			return
	if _drawing_layer != null:
		return
	var local := to_local(_player.global_position)
	# The body origin sits 1 m above the feet, so this is "feet on or above
	# the platform top" and excludes the stairs, which are outside the rect.
	var on_platform := absf(local.x) <= platform_half.x and absf(local.z) <= platform_half.y \
		and local.y > platform_top
	var resizing := _tween != null and _tween.is_running()
	if on_platform != _big and not resizing:
		_resize(on_platform)
	_easel_in_reach = _nearest_easel(local) if _big and not resizing else -1
	_prompt.visible = _easel_in_reach >= 0


## Index of the closest easel within PAINT_RANGE, or -1.
func _nearest_easel(local: Vector3) -> int:
	var best := -1
	var best_distance := PAINT_RANGE
	for index in easel_positions.size():
		var easel := easel_positions[index]
		var distance := Vector2(local.x - easel.x, local.z - easel.z).length()
		if distance <= best_distance:
			best = index
			best_distance = distance
	return best


func _resize(big: bool) -> void:
	_big = big
	var from := float(_player.call("get_size_multiplier"))
	var to := SIZE_MULTIPLIER if big else 1.0
	_player.call("set_input_enabled", false)
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_apply_size, from, to, SPIN_SECONDS)
	var visuals := _player.get_node_or_null("FoxVisuals") as Node3D
	if visuals != null:
		# Seen from above, +Y rotation is anticlockwise: grow spins clockwise.
		_tween.tween_property(visuals, "rotation:y",
			visuals.rotation.y + (-TAU if big else TAU), SPIN_SECONDS)
	_tween.chain().tween_callback(Callable(_player, "set_input_enabled").bind(true))


func _apply_size(multiplier: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.call("set_size_multiplier", multiplier)
	# The follow camera pulls back in step, or it ends up inside the fox.
	var camera := get_viewport().get_camera_3d()
	if camera == null or not ("follow_distance" in camera):
		return
	if _camera_base.is_empty():
		for property in CAMERA_PROPERTIES:
			_camera_base[property] = camera.get(property)
	for property in CAMERA_PROPERTIES:
		camera.set(property, _camera_base[property] * multiplier)
	if is_equal_approx(multiplier, 1.0):
		_camera_base.clear()


# _input, not _unhandled_input: the drawing tool's controls take focus and
# would swallow Escape before the unhandled stage.
func _input(event: InputEvent) -> void:
	var escape: bool = event is InputEventKey and event.pressed and not event.echo \
		and (event as InputEventKey).keycode == KEY_ESCAPE
	if _drawing_layer != null and (escape or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_close_drawing()


func _unhandled_input(event: InputEvent) -> void:
	if is_paint_prompt_visible() and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_drawing()


func _open_drawing() -> void:
	if _fetching_tool:
		return
	# The drawing tool may be in the deferred Web content pack. Mount it before
	# opening the easel; the helper returns immediately when it is already here.
	if OS.has_feature("web") or not SceneLoader.can_open(DRAWING_TOOL_SCENE):
		_fetching_tool = true
		_prompt.text = "Getting the paints ready…"
		var error: String = await SceneLoader.mount_packs_for(get_tree(), DRAWING_TOOL_SCENE,
			func(loaded: float, total: float) -> void:
				_prompt.text = "Getting the paints ready… %d%%" % int(100.0 * loaded / total))
		_fetching_tool = false
		_prompt.text = PROMPT_TEXT
		if not error.is_empty():
			push_warning("creator_studio: drawing tool unavailable: " + error)
			_prompt.text = "The paints couldn't load. Press Q to try again."
			return
		# Walked away from the easel while it downloaded.
		if _easel_in_reach < 0:
			return
	var scene := load(DRAWING_TOOL_SCENE) as PackedScene
	if scene == null:
		return
	_painting_easel = _easel_in_reach
	_prompt.visible = false
	_drawing_layer = CanvasLayer.new()
	_drawing_layer.name = "StudioDrawing"
	_drawing_layer.layer = 60
	# The follow camera ignores mouse look, zoom and click-to-capture while any
	# node in this group exists (CameraFollow.CAMERA_INPUT_BLOCKERS_GROUP).
	_drawing_layer.add_to_group("camera_input_blockers")
	add_child(_drawing_layer)
	_drawing_tool = scene.instantiate()
	_drawing_tool.set("embedded", true)
	_drawing_tool.connect("closed", _close_drawing)
	_drawing_layer.add_child(_drawing_tool)
	_player.call("set_input_enabled", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_drawing() -> void:
	if _drawing_layer == null:
		return
	if _drawing_tool != null and bool(_drawing_tool.call("has_drawing")):
		_show_on_easel(_painting_easel, _drawing_tool.call("get_artwork_image"))
	# Out of the group now, so the camera takes input again this frame.
	_drawing_layer.remove_from_group("camera_input_blockers")
	_drawing_layer.queue_free()
	_drawing_layer = null
	_drawing_tool = null
	if _player != null and is_instance_valid(_player):
		_player.call("set_input_enabled", true)
	var camera := get_viewport().get_camera_3d()
	if camera != null and bool(camera.get("capture_mouse")):
		Input.mouse_mode = TouchDevice.captured_mode()


## Puts the drawing on that easel's canvas (see shaders/easel_canvas.gdshader).
func _show_on_easel(index: int, image: Image) -> void:
	if image == null or index < 0 or index >= easel_canvases.size():
		return
	var canvas := easel_canvases[index]
	if canvas == null:
		return
	var material := canvas.material_override as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("art", ImageTexture.create_from_image(image))
	material.set_shader_parameter("art_aspect", float(image.get_width()) / float(image.get_height()))
	material.set_shader_parameter("has_art", true)
