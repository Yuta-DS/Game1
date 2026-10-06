extends Control

const ArtEnhancer := preload("res://scripts/creation_world/art_enhancer.gd")

const CREATIVE_PROMPTS := [
	"IDENTITY • Draw a symbol that represents what makes you unique.",
	"IDENTITY • If your personality were a landscape, what would it look like?",
	"COURAGE • Draw a symbol of a time you were brave.",
	"COURAGE • If courage were an animal, what would it be?",
	"EMOTIONS • Draw your feelings as colours or weather.",
	"EMOTIONS • Draw a safe place where your feelings can rest.",
	"CREATIVITY • Design a magical world that could only come from you.",
	"CREATIVITY • Create a creature that represents you.",
	"PURPOSE • Draw a gift you would like to share with the world.",
	"PURPOSE • Draw the person you are becoming.",
]

const REFLECTIONS := [
	"Milo asks: What part of your artwork are you most proud of?",
	"Milo asks: What strength did you use while creating this?",
	"Milo asks: What story does your artwork tell?",
	"Milo asks: What did you discover about yourself?",
]

# Link of background
# https://images.nasa.gov/details/PIA12348

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
var _creative_prompt := ""
var _prompt_label: Label
var _creative_dialog: AcceptDialog
var _creative_summary: Label
var _creative_styles: VBoxContainer
var _guide_button: Button
var _enter_world_button: Button
var _last_gallery_path := ""


func _ready() -> void:
	_build_creative_prompt()
	_build_ai_companion()
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
	# ARTÉA's default journey is private and offline. Facilitators can add a
	# deliberate export feature later; a child should never reach cloud upload
	# from the creative flow by accident.
	firebase_button.visible = false
	firebase_button.disabled = true

	local_button.pressed.connect(_on_local_button_pressed)

	http_request.request_completed.connect(_on_http_request_request_completed)

	save_option_dialog.get_ok_button().hide()
	save_option_dialog.get_cancel_button().hide()
	artgallery.pressed.connect(_on_art_gallery_button_pressed)

	_update_undo_button()


func _build_creative_prompt() -> void:
	var js := get_node_or_null("/root/JourneyState")
	var prompt_index := 0
	if js != null:
		prompt_index = js.creations.size() % CREATIVE_PROMPTS.size()
	_creative_prompt = CREATIVE_PROMPTS[prompt_index]

	var banner := PanelContainer.new()
	banner.name = "CreativeDiscoveryPrompt"
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(-330.0, 12.0)
	banner.custom_minimum_size = Vector2(660.0, 58.0)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.12, 0.88)
	style.border_color = Color(0.90, 0.68, 0.25, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	banner.add_theme_stylebox_override("panel", style)
	_prompt_label = Label.new()
	_prompt_label.text = "URIEL'S CREATIVE INVITATION\n%s" % _creative_prompt
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 17)
	_prompt_label.add_theme_color_override("font_color", Color("fff0bd"))
	banner.add_child(_prompt_label)
	add_child(banner)


func _build_ai_companion() -> void:
	var actions := get_node_or_null(
		"CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Actions/VBoxContainer")
	if actions != null:
		_guide_button = Button.new()
		_guide_button.name = "CreativeGuide"
		_guide_button.text = "✨ Creative Reflection"
		_guide_button.tooltip_text = "Choose a kind, authored reflection without changing your original."
		_guide_button.pressed.connect(_ask_guide_for_current_art)
		actions.add_child(_guide_button)

		_enter_world_button = Button.new()
		_enter_world_button.name = "EnterArtworkWorld"
		_enter_world_button.text = "✨ Frame My Artwork"
		_enter_world_button.tooltip_text = "Place this artwork in a magical castle frame."
		_enter_world_button.pressed.connect(_enter_current_artwork_world)
		actions.add_child(_enter_world_button)

	_creative_dialog = AcceptDialog.new()
	_creative_dialog.name = "CreativeCompanionDialog"
	_creative_dialog.title = "Your Creative Reflection"
	_creative_dialog.min_size = Vector2i(720, 520)
	_creative_dialog.get_ok_button().text = "Keep Creating"
	add_child(_creative_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_creative_dialog.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	_creative_summary = Label.new()
	_creative_summary.text = "Your original drawing always stays safe. The guide offers choices; you remain the artist."
	_creative_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_creative_summary.custom_minimum_size = Vector2(650, 125)
	_creative_summary.add_theme_font_size_override("font_size", 18)
	box.add_child(_creative_summary)

	var style_heading := Label.new()
	style_heading.text = "Optional inspirations — choose one only if it feels like you:"
	style_heading.add_theme_font_size_override("font_size", 17)
	box.add_child(style_heading)
	_creative_styles = VBoxContainer.new()
	box.add_child(_creative_styles)

	var original_button := Button.new()
	original_button.text = "Keep My Original Exactly As It Is"
	original_button.pressed.connect(_keep_original_for_world)
	box.add_child(original_button)

	var world_button := Button.new()
	world_button.text = "Begin the Gallery Frame Ritual"
	world_button.pressed.connect(func() -> void:
		_creative_dialog.hide()
		_enter_current_artwork_world()
	)
	box.add_child(world_button)


func _ask_guide_for_current_art() -> void:
	var path := _ensure_gallery_copy()
	if path.is_empty():
		return
	_begin_creative_guide(path)


func _begin_creative_guide(path: String) -> void:
	_last_gallery_path = path
	CreationWorldState.prepare_artwork(path, _sanitize_title(title_input.text))
	_creative_dialog.popup_centered(Vector2i(760, 560))
	_show_creative_guide({
		"celebration": "Every mark belongs to your story. Choose what feels true to you.",
		"scene_description": "You can keep your artwork exactly as it is, try an optional local colour treatment, or place it in a Gallery Frame Ritual.",
		"style_ideas": ["soft watercolor", "paper collage", "storybook pastel"],
	}, false)


func _show_creative_guide(guide: Dictionary, degraded: bool) -> void:
	var celebration := str(guide.get("celebration", "Your idea already has its own special spark."))
	var scene := str(guide.get("scene_description", "Your marks can become a world with light, depth, and movement."))
	_creative_summary.text = "%s\n\n%s" % [celebration, scene]
	for child in _creative_styles.get_children():
		child.queue_free()
	var styles = guide.get("style_ideas", ["soft watercolor", "paper collage", "storybook pastel"])
	if not styles is Array:
		styles = ["soft watercolor", "paper collage", "storybook pastel"]
	for style_value in styles.slice(0, 3):
		var style := str(style_value)
		var button := Button.new()
		button.text = "Preview %s (optional)" % style.capitalize()
		button.tooltip_text = "Creates a separate variation. Your original file is never overwritten."
		button.pressed.connect(_apply_ai_style.bind(style))
		_creative_styles.add_child(button)


func _apply_ai_style(style: String) -> void:
	var image := Image.new()
	if image.load(CreationWorldState.current_artwork_path) != OK:
		show_notification("The original artwork could not be opened.", false)
		return
	_creative_summary.text = "Preparing an optional %s variation…" % style
	var path := ArtEnhancer.save_variation(image, CreationWorldState.current_artwork_path, style)
	if path.is_empty():
		show_notification("The optional variation could not be saved.", false)
		return
	CreationWorldState.select_variation(path, style)
	var preview := Image.new()
	if preview.load(path) == OK:
		canvas_texture.update(preview)
	_creative_summary.text = "The %s variation is selected for your frame ritual. Your original drawing remains unchanged, and you can switch back at any time." % style
	show_notification("Optional variation created — original kept safely.", true)


func _keep_original_for_world() -> void:
	CreationWorldState.keep_original()
	var original := Image.new()
	if original.load(CreationWorldState.current_artwork_path) == OK:
		canvas_texture.update(original)
	show_notification("Your original is selected for the frame ritual.", true)


func _enter_current_artwork_world() -> void:
	var path := _ensure_gallery_copy()
	if path.is_empty():
		return
	if CreationWorldState.current_artwork_path != path:
		CreationWorldState.prepare_artwork(path, _sanitize_title(title_input.text))
	_enter_world_button.disabled = true
	show_notification("Opening the Gallery Frame Ritual…", true)
	var scene_error := get_tree().change_scene_to_file("res://scenes/gallery_frame_ritual.tscn")
	if scene_error != OK:
		_enter_world_button.disabled = false
		show_notification("The Gallery Frame Ritual could not open yet.", false)


func _ensure_gallery_copy() -> String:
	if not _last_gallery_path.is_empty() and FileAccess.file_exists(_last_gallery_path):
		return _last_gallery_path
	_last_gallery_path = save_artwork_to_gallery()
	return _last_gallery_path


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
	if _creative_dialog != null and _creative_dialog.visible:
		return

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
	# Any new mark makes the previous saved copy stale. The next guide/world
	# request will save a fresh version instead of analysing an older drawing.
	_last_gallery_path = ""

	undo_history.append(canvas_image.duplicate())

	if undo_history.size() > max_undo_steps:
		undo_history.pop_front()

	_update_undo_button()


func _on_undo_button_pressed() -> void:

	if undo_history.is_empty():
		return

	canvas_image = undo_history.pop_back()
	_last_gallery_path = ""

	canvas_texture.update(canvas_image)

	_update_undo_button()


func _update_undo_button() -> void:
	undo_button.disabled = undo_history.is_empty()


func create_quick_color_palette() -> void:

	quick_color_grid.columns = 7

	# The player's own colours come first — every feeling they honoured in
	# the Sanctuary of Sound is a brush here. This is the moment the journey
	# stops being three minigames and becomes one thing.
	_add_earned_colors()

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
		quick_color_grid.add_child(_make_swatch(color))


# Build a swatch for each emotion the player recorded in stage 2.
# Most recent first, de-duplicated, so revisiting the same feeling doesn't
# flood the palette with copies of one colour.
func _add_earned_colors() -> void:

	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return

	var seen := {}

	for i in range(js.emotions.size() - 1, -1, -1):
		var entry = js.emotions[i]

		var emotion_name: String = entry.get("name", "")
		var html: String = entry.get("colour", "")

		if emotion_name.is_empty() or html.is_empty():
			continue

		if seen.has(emotion_name):
			continue

		seen[emotion_name] = true

		quick_color_grid.add_child(_make_swatch(
			Color.from_string(html, Color.WHITE),
			"Your %s" % emotion_name,
			true,
		))


# One colour button. Shared by the standard palette and the emotion
# swatches so both stay visually identical.
# `tooltip` names the feeling a colour came from; empty for stock colours.
# `earned` gives emotion swatches a gold ring so they read as the player's.
func _make_swatch(color: Color, tooltip := "", earned := false) -> Button:

	var button := Button.new()

	button.custom_minimum_size = Vector2(45, 45)

	button.text = ""

	button.clip_contents = true

	button.tooltip_text = tooltip

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

	style.border_color = Color(1.0, 0.85, 0.3) if earned else Color.WHITE

	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)

	button.pressed.connect(func(c = color):
		active_color = c
		color_picker.color = c
		is_Erasing = false
	)

	return button


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
		_record_creation(save_path, custom_title)
		show_notification("Artwork added to gallery!", true)
		return save_path
	else:
		show_notification("Failed to save to gallery!", false)
		return ""


# Remember what the player made, so the castle can hang it and stage 4 can
# name the creativity it took. Only local paths — nothing here is uploaded.
func _record_creation(path: String, title: String) -> void:
	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return

	js.record_creation(path, title)
	js.advance_to(3)
	if _prompt_label != null:
		var reflection_index: int = (js.creations.size() - 1) % REFLECTIONS.size()
		_prompt_label.text = "ARTWORK SAVED • FRAME IT TO DISCOVER CREATOR'S LIGHT\n%s" % REFLECTIONS[reflection_index]


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

	_last_gallery_path = save_artwork_to_gallery()

	save_artwork_to_desktop()

	# Replaced by upload to server
	#upload_artwork_to_firebase()

	print("Authenticated artwork upload requested.")
	upload_artwork_to_server()
	if not _last_gallery_path.is_empty():
		_begin_creative_guide(_last_gallery_path)

func _on_local_button_pressed() -> void:

	save_option_dialog.hide()

	_last_gallery_path = save_artwork_to_gallery()

	save_artwork_to_desktop()
	if not _last_gallery_path.is_empty():
		_begin_creative_guide(_last_gallery_path)


func _on_back_to_hub_button_pressed() -> void:
	_return_to_campaign()
	
func _on_art_gallery_button_pressed() -> void:
	_return_to_campaign()


func _return_to_campaign() -> void:
	var campaign := get_node_or_null("/root/JourneyCampaign")
	if campaign != null and campaign.has_method("return_to_campaign"):
		campaign.call("return_to_campaign")
	else:
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
		APIManager.UPLOAD_ARTWORK_URL,
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
