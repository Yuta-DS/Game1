extends Control

# Smooth canvas
const CANVAS_WIDTH := 1024
const CANVAS_HEIGHT := 950

var canvas_image: Image
var canvas_texture: ImageTexture
var smooth_drawing := false
var last_draw_pos: Vector2 = Vector2.ZERO

var active_color: Color = Color.BLACK
var is_Erasing := false
var brush_size: int = 18

# Stamp system
var pending_stamp_tex: Texture2D = null
var stamp_size: int = 80


@onready var notificationpanel: PanelContainer = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/VSplitContainer/VBoxContainer/notificationui/notificationpanel
@onready var notificationlabel: Label = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/VSplitContainer/VBoxContainer/notificationui/notificationpanel/notificationlabel
@onready var ddrawingaudio: AudioStreamPlayer = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/VSplitContainer/VBoxContainer/CanvasTextureRect/ddrawingaudio
@onready var eraseaudio: AudioStreamPlayer = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/VSplitContainer/VBoxContainer/CanvasTextureRect/eraseaudio
@onready var exit: Button = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Actions/VBoxContainer/Exit
@onready var artgallery: Button = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Actions/VBoxContainer/artgallery
@onready var brush: Button = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Drawing/VBoxContainer/Brush
@onready var stamp: Button = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Drawing/VBoxContainer/Stamp
@onready var eraser: Button = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Drawing/VBoxContainer/Eraser

@onready var canvas_rect: TextureRect = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/VSplitContainer/VBoxContainer/CanvasTextureRect

@onready var color_picker: ColorPicker = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Drawing/VBoxContainer/ColorPicker

@onready var quick_color_grid: GridContainer = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Drawing/VBoxContainer/QuickColorGrid

@onready var clear: Button = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Actions/VBoxContainer/Clear
@onready var undo_button: Button = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Actions/VBoxContainer/Undo

@onready var title_input: LineEdit = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/VSplitContainer/VBoxContainer/HBoxContainer/TitleLineEdit
@onready var save_close_button: Button = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Actions/VBoxContainer/Save

@onready var http_request: HTTPRequest = $HTTPRequest

@onready var save_option_dialog: AcceptDialog = $SaveOptionDialog
@onready var firebase_button: Button = $SaveOptionDialog/VBoxContainer/FirebaseButton
@onready var local_button: Button = $SaveOptionDialog/VBoxContainer/LocalButton

var undo_history: Array[Image] = []
var max_undo_steps := 10


func _ready() -> void:
	http_request.timeout = 10
	create_smooth_canvas()
	notificationpanel.visible = false

	active_color = color_picker.color

	color_picker.color_changed.connect(_on_color_picker_button_color_changed)

	create_quick_color_palette()

	brush.size_selected.connect(func(span: int):
		brush_size = max(4, span * 8)
		is_Erasing = false
		pending_stamp_tex = null
	)

	brush.pressed.connect(_on_brush_pressed)

	stamp.stamp_selected.connect(func(tex: Texture2D):
		pending_stamp_tex = tex
		is_Erasing = false
	)

	clear.pressed.connect(_on_clear_button_pressed)

	undo_button.pressed.connect(_on_undo_button_pressed)

	exit.pressed.connect(_on_back_to_hub_button_pressed)

	eraser.pressed.connect(_on_eraser_pressed)

	save_close_button.pressed.connect(_on_save_close_button_pressed)

	firebase_button.pressed.connect(_on_firebase_button_pressed)

	local_button.pressed.connect(_on_local_button_pressed)

	http_request.request_completed.connect(_on_http_request_request_completed)

	save_option_dialog.get_ok_button().hide()
	save_option_dialog.get_cancel_button().hide()
	artgallery.pressed.connect(_on_art_gallery_button_pressed)

	_update_undo_button()


func create_smooth_canvas() -> void:
	canvas_image = Image.create(
		CANVAS_WIDTH,
		CANVAS_HEIGHT,
		false,
		Image.FORMAT_RGBA8
	)

	canvas_image.fill(Color.WHITE)

	canvas_texture = ImageTexture.create_from_image(canvas_image)

	canvas_rect.texture = canvas_texture
	canvas_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:

		if event.pressed and _is_over_canvas(event.position):

			_save_current_state()

			var pos = get_canvas_mouse_pos()

			if pending_stamp_tex != null:
				place_stamp_at(pos)
				pending_stamp_tex = null
				return

			smooth_drawing = true

			# AUDIO
			if is_Erasing:

				if not eraseaudio.playing:
					eraseaudio.play()

			else:

				if not ddrawingaudio.playing:
					ddrawingaudio.play()

			last_draw_pos = pos

			draw_circle_at(last_draw_pos)

			canvas_texture.update(canvas_image)

		elif !event.pressed:

			smooth_drawing = false

			# STOP AUDIO
			if ddrawingaudio.playing:
				ddrawingaudio.stop()

			if eraseaudio.playing:
				eraseaudio.stop()

	elif event is InputEventMouseMotion and smooth_drawing:

		if _is_over_canvas(event.position):

			var current_pos = get_canvas_mouse_pos()

			draw_line_smooth(last_draw_pos, current_pos)

			last_draw_pos = current_pos

	#if event.is_action_pressed("toggle_eraser"):
		#_on_eraser_pressed()

func get_canvas_mouse_pos() -> Vector2:

	var local_pos = canvas_rect.get_local_mouse_position()

	var scale_x = float(canvas_image.get_width()) / canvas_rect.size.x
	var scale_y = float(canvas_image.get_height()) / canvas_rect.size.y

	return Vector2(
		local_pos.x * scale_x,
		local_pos.y * scale_y
	)


func _is_over_canvas(pos: Vector2) -> bool:
	return Rect2(
		canvas_rect.global_position,
		canvas_rect.size
	).has_point(pos)


func draw_line_smooth(from_pos: Vector2, to_pos: Vector2) -> void:

	var distance = from_pos.distance_to(to_pos)

	var steps = max(1, int(distance / 0.5))

	for i in range(steps + 1):

		var t = float(i) / float(steps)

		var pos = from_pos.lerp(to_pos, t)

		draw_circle_at(pos)

	canvas_texture.update(canvas_image)


func draw_circle_at(pos: Vector2) -> void:

	var radius: float = brush_size / 2.0

	var edge_softness: float = 8.0

	for y in range(
		-int(radius + edge_softness),
		int(radius + edge_softness) + 1
	):

		for x in range(
			-int(radius + edge_softness),
			int(radius + edge_softness) + 1
		):

			var dist = sqrt(float(x * x + y * y))

			if dist <= radius + edge_softness:

				var px = int(pos.x) + x
				var py = int(pos.y) + y

				if px >= 0 and px < canvas_image.get_width() and py >= 0 and py < canvas_image.get_height():

					var alpha = clamp(
						(radius + edge_softness - dist) / edge_softness,
						0.0,
						1.0
					)

					var old_color = canvas_image.get_pixel(px, py)

					if is_Erasing:

						# Soft erase
						var erased_color = old_color.lerp(Color.WHITE, alpha)

						canvas_image.set_pixel(px, py, erased_color)

					else:

						# Smooth brush blending
						var blended_color = old_color.lerp(active_color, alpha)

						canvas_image.set_pixel(px, py, blended_color)

func place_stamp_at(pos: Vector2) -> void:

	if pending_stamp_tex == null:
		return

	var stamp_img = pending_stamp_tex.get_image()

	stamp_img.resize(
		stamp_size,
		stamp_size,
		Image.INTERPOLATE_BILINEAR
	)

	var dest = Vector2i(
		int(pos.x - stamp_size / 2),
		int(pos.y - stamp_size / 2)
	)

	canvas_image.blend_rect(
		stamp_img,
		Rect2i(Vector2i.ZERO, stamp_img.get_size()),
		dest
	)

	canvas_texture.update(canvas_image)


func _on_color_picker_button_color_changed(color: Color) -> void:
	active_color = color
	is_Erasing = false


func _on_brush_pressed() -> void:
	is_Erasing = false
	pending_stamp_tex = null


func _on_eraser_pressed() -> void:
	is_Erasing = true
	pending_stamp_tex = null


func _on_clear_button_pressed() -> void:

	_save_current_state()

	canvas_image.fill(Color.WHITE)

	canvas_texture.update(canvas_image)


func _save_current_state() -> void:

	undo_history.append(canvas_image.duplicate())

	if undo_history.size() > max_undo_steps:
		undo_history.pop_front()

	_update_undo_button()


func _on_undo_button_pressed() -> void:

	if undo_history.is_empty():
		return

	canvas_image = undo_history.pop_back()

	canvas_texture.update(canvas_image)

	_update_undo_button()


func _update_undo_button() -> void:
	undo_button.disabled = undo_history.is_empty()


func create_quick_color_palette() -> void:

	quick_color_grid.columns = 7

	var colors: Array[Color] = [

		# Reds / Pinks
		Color.RED,
		Color(1.0, 0.25, 0.0),
		Color(1.0, 0.0, 0.4),

		# Oranges / Yellows
		Color(1.0, 0.5, 0.0),
		Color(1.0, 0.7, 0.0),
		Color.YELLOW,

		# Greens
		Color(0.8, 0.9, 0.0),
		Color(0.5, 0.8, 0.2),
		Color(0.2, 0.7, 0.25),

		# Teals / Blues
		Color(0.0, 0.6, 0.5),
		Color(0.0, 0.7, 0.8),
		Color(0.0, 0.55, 1.0),
		Color(0.0, 0.45, 1.0),
		Color(0.1, 0.2, 0.8),

		# Purples
		Color(0.35, 0.15, 0.8),
		Color(0.65, 0.0, 0.8),

		# Neutral colors
		Color.WHITE,
		Color(0.6, 0.6, 0.6),
		Color(0.35, 0.5, 0.55),
		Color(0.45, 0.25, 0.18),
		Color.BLACK
	]

	for color in colors:

		var button := Button.new()

		button.custom_minimum_size = Vector2(45, 45)

		button.text = ""

		button.clip_contents = true

		var style := StyleBoxFlat.new()

		style.bg_color = color

		style.corner_radius_top_left = 100
		style.corner_radius_top_right = 100
		style.corner_radius_bottom_left = 100
		style.corner_radius_bottom_right = 100

		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2

		style.border_color = Color.WHITE

		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)

		button.pressed.connect(func(c = color):
			active_color = c
			color_picker.color = c
			is_Erasing = false
		)

		quick_color_grid.add_child(button)


func _sanitize_title(raw_title: String) -> String:

	var custom_title = raw_title.strip_edges()

	if custom_title == "":
		custom_title = "Artwork"

	custom_title = custom_title.replace(" ", "_")
	custom_title = custom_title.replace("/", "")
	custom_title = custom_title.replace("\\", "")
	custom_title = custom_title.replace(":", "")
	custom_title = custom_title.replace("*", "")
	custom_title = custom_title.replace("?", "")
	custom_title = custom_title.replace("\"", "")
	custom_title = custom_title.replace("<", "")
	custom_title = custom_title.replace(">", "")
	custom_title = custom_title.replace("|", "")

	return custom_title


func _build_artwork_image() -> Image:
	return canvas_image.duplicate()


func save_artwork_to_desktop() -> void:

	var image = _build_artwork_image()

	var custom_title = _sanitize_title(title_input.text)

	var uuid = str(hash(Time.get_ticks_usec())) + "_" + str(randi() % 100000)

	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")

	var file_name = custom_title + "_" + uuid + "_" + timestamp + ".png"

	var save_path: String

	if OS.has_feature("Android"):
		save_path = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES) + "/" + file_name

	else:

		save_path = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)

		if save_path == "":
			save_path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)

		save_path += "/" + file_name

	# SAVE IMAGE
	var err = image.save_png(save_path)

	# NOTIFICATION
	if err == OK:
		show_notification("Artwork saved successfully!", true)
	else:
		show_notification("Failed to save artwork!", false)

func save_artwork_to_gallery() -> String:

	var image = _build_artwork_image()

	var custom_title = _sanitize_title(title_input.text)

	var dir_path = "user://artworks/"

	DirAccess.make_dir_recursive_absolute(dir_path)

	var uuid = str(hash(Time.get_ticks_usec())) + "_" + str(randi() % 100000)

	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")

	var file_name = custom_title + "_" + uuid + "_" + timestamp + ".png"

	var save_path = dir_path + file_name

	var err = image.save_png(save_path)

	if err == OK:
		show_notification("Artwork added to gallery!", true)
		return save_path
	else:
		show_notification("Failed to save to gallery!", false)
		return ""


func upload_artwork_to_firebase() -> void:

	var image = _build_artwork_image()

	var byte_data = image.save_png_to_buffer()

	if byte_data.size() == 0:
		show_notification("Image export failed!", false)
		return

	var custom_title = _sanitize_title(title_input.text)

	var uuid = str(hash(Time.get_ticks_usec())) + "_" + str(randi() % 100000)

	var file_name = custom_title + "_" + uuid + ".png"

	var encoded_path = "artworks/" + file_name.uri_encode()

	var upload_url = "https://firebasestorage.googleapis.com/v0/b/artea-9da5a.firebasestorage.app/o?uploadType=media&name=" + encoded_path

	var headers = ["Content-Type: image/png"]

	var err = http_request.request_raw(
		upload_url,
		headers,
		HTTPClient.METHOD_POST,
		byte_data
	)

	if err != OK:
		show_notification("Failed to connect to server!", false)
	else:
		show_notification("Uploading artwork...", true)


func _on_http_request_request_completed(result, response_code, headers, body) -> void:

	if result != HTTPRequest.RESULT_SUCCESS:
		print("Network error: server unreachable or timeout")
		return

	# For debugging
	var response_text = body.get_string_from_utf8()
	print("Server response: ", response_text)

	if response_code == 200:
		show_notification("Artwork uploaded successfully!", true)
	else:
		show_notification("Failed to save artwork!", false)


func _on_save_close_button_pressed() -> void:
	save_option_dialog.popup_centered()


func _on_firebase_button_pressed() -> void:

	save_option_dialog.hide()

	save_artwork_to_gallery()

	save_artwork_to_desktop()

	# Replaced by upload to server
	#upload_artwork_to_firebase()

	print("AUTH TOKEN = [", Global.auth_token, "]")
	upload_artwork_to_server()

func _on_local_button_pressed() -> void:

	save_option_dialog.hide()

	save_artwork_to_gallery()

	save_artwork_to_desktop()


func _on_back_to_hub_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/New_Hub_World.tscn")
	
func _on_art_gallery_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/art_gallery_3d_inprogress.tscn")
	
# REMOTE GALLERY - SAVE/UPLOAD TO SERVER
func upload_artwork_to_server() -> void:
	
	if Global.auth_token == "" or Global.auth_token == "invalid_token":
		print("Upload blocked: invalid auth token")
		return

	var image = _build_artwork_image()

	var byte_data = image.save_png_to_buffer()

	if byte_data.size() == 0:
		print("Image conversion failed")
		return

	var custom_title = _sanitize_title(title_input.text)

	var headers = [
		"Content-Type: image/png",
		"Authorization: Bearer " + Global.auth_token,
		"Artwork-Title: " + custom_title
	]

	var err = http_request.request_raw(
		APIManager.BASE_URL + "/upload_artwork",
		headers,
		HTTPClient.METHOD_POST,
		byte_data
	)

	if err != OK:
		print("Request failed locally (no internet or server unreachable)")
	else:
		print("Uploading artwork to server...")
	
var notification_tween: Tween = null

func show_notification(message: String, success := true) -> void:

	# Stop old tween
	if notification_tween:
		notification_tween.kill()

	notificationpanel.visible = true

	notificationlabel.text = message

	# Colors
	if success:
		notificationpanel.modulate = Color(0.3, 1.0, 0.3)
	else:
		notificationpanel.modulate = Color(1.0, 0.3, 0.3)

	# Fade in
	notificationpanel.modulate.a = 0.0

	notification_tween = create_tween()

	notification_tween.tween_property(
		notificationpanel,
		"modulate:a",
		1.0,
		0.25
	)

	await get_tree().create_timer(3.0).timeout

	notification_tween = create_tween()

	notification_tween.tween_property(
		notificationpanel,
		"modulate:a",
		0.0,
		0.4
	)

	await notification_tween.finished

	notificationpanel.visible = false
