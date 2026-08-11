extends TextureRect

signal drawing_changed

const IMAGE_SIZE := Vector2i(768, 512)

var brush_colour := Color("5a3d8f")
var brush_radius := 9
var _image: Image
var _texture: ImageTexture
var _drawing := false
var _last := Vector2i.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(640, 360)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP
	clear_canvas()
	gui_input.connect(_on_canvas_input)


func clear_canvas() -> void:
	_image = Image.create(IMAGE_SIZE.x, IMAGE_SIZE.y, false, Image.FORMAT_RGBA8)
	_image.fill(Color(1.0, 1.0, 1.0, 0.94))
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)
	texture = _texture
	drawing_changed.emit()


func export_image() -> Image:
	return _image.duplicate() if _image != null else null


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drawing = event.pressed
		if _drawing:
			_last = _canvas_position(event.position)
			_stamp(_last)
		accept_event()
	elif event is InputEventMouseMotion and _drawing:
		var current := _canvas_position(event.position)
		_draw_line(_last, current)
		_last = current
		accept_event()


func _canvas_position(local: Vector2) -> Vector2i:
	var sx := float(IMAGE_SIZE.x) / maxf(size.x, 1.0)
	var sy := float(IMAGE_SIZE.y) / maxf(size.y, 1.0)
	return Vector2i(
		clampi(int(local.x * sx), 0, IMAGE_SIZE.x - 1),
		clampi(int(local.y * sy), 0, IMAGE_SIZE.y - 1)
	)


func _draw_line(from: Vector2i, to: Vector2i) -> void:
	var distance := Vector2(from).distance_to(Vector2(to))
	var steps := maxi(1, int(distance / 2.0))
	for i in steps + 1:
		_stamp(Vector2i(Vector2(from).lerp(Vector2(to), float(i) / steps)))
	_texture.update(_image)
	drawing_changed.emit()


func _stamp(point: Vector2i) -> void:
	for y in range(-brush_radius, brush_radius + 1):
		for x in range(-brush_radius, brush_radius + 1):
			if x * x + y * y > brush_radius * brush_radius:
				continue
			var pixel := point + Vector2i(x, y)
			if pixel.x >= 0 and pixel.y >= 0 and pixel.x < IMAGE_SIZE.x and pixel.y < IMAGE_SIZE.y:
				_image.set_pixelv(pixel, brush_colour)
	_texture.update(_image)
