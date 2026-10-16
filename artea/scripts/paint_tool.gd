extends Control
const SceneLoader := preload("res://scripts/scene_loader.gd")

# Configuration Variables
const GRID_SIZE = 32 # Length in each direction
var active_color : Color = Color(1, 0, 0) # Default color - red
var is_painting = false # Track if mouse is being dragged
var is_eraser_enabled: bool = false
var erase_color: Color = Color(1, 1, 1) # White, assuming white is the "blank" color

# Tools
enum Tool { BRUSH, STAMP, ERASER }
var current_tool: Tool = Tool.BRUSH
var brush_radius: float = 2.0
var selected_stamp_index: int = -1
var stamp_tint: Color = Color(1, 1, 1, 1)
var stamp_masks := []
var stamp_textures = [
    preload("res://assets/Paintingtool/flower.png"),
    preload("res://assets/Paintingtool/heart.png"),
    preload("res://assets/Paintingtool/star.png"),
    preload("res://assets/Paintingtool/sun.png")
]
var emoji_stamps := ["🌸", "❤️", "⭐", "☀️"]
var _emoji_enabled := false
var _emoji_font: FontFile = null
var _emoji_sv: SubViewport = null
var _emoji_label: Label = null
var _emoji_cache := {}
var undo_stack: Array = []
var redo_stack: Array = []


#Node references
@onready var grid: GridContainer = $CenterContainer/PanelContainer/MarginContainer/VSplitContainer/Drawing/GridContainer
@onready var color_picker: ColorPickerButton =$CenterContainer/PanelContainer/MarginContainer/VSplitContainer/Drawing/VBoxContainer/ColorPickerButton
@onready var eraser_button = $CenterContainer/PanelContainer/MarginContainer/VSplitContainer/Drawing/VBoxContainer/EraserButton
@onready var brush_button = $CenterContainer/PanelContainer/MarginContainer/VSplitContainer/Drawing/VBoxContainer/ToolButtons/BrushButton
@onready var stamp_button = $CenterContainer/PanelContainer/MarginContainer/VSplitContainer/Drawing/VBoxContainer/ToolButtons/StampButton
@onready var title_input = $CenterContainer/PanelContainer/MarginContainer/VSplitContainer/Actions/VBoxContainer/HBoxContainer/TitleLineEdit
@onready var http_request: HTTPRequest = $HTTPRequest # Make sure you added this node in the scene
@onready var save_option_dialog = $SaveOptionDialog
@onready var firebase_button = $SaveOptionDialog/VBoxContainer/FirebaseButton
@onready var local_button = $SaveOptionDialog/VBoxContainer/LocalButton
@onready var stamps_menu: PopupPanel = $StampsMenu
@onready var stamps_grid: GridContainer = $StampsMenu/VBoxContainer/MyStamps
@onready var palette_colors := [
    $CenterContainer/PanelContainer/MarginContainer/VSplitContainer/Actions/VBoxContainer/ColorPalette/ColorA,
    $CenterContainer/PanelContainer/MarginContainer/VSplitContainer/Actions/VBoxContainer/ColorPalette/ColorB,
    $CenterContainer/PanelContainer/MarginContainer/VSplitContainer/Actions/VBoxContainer/ColorPalette/ColorC,
    $CenterContainer/PanelContainer/MarginContainer/VSplitContainer/Actions/VBoxContainer/ColorPalette/ColorD,
    $CenterContainer/PanelContainer/MarginContainer/VSplitContainer/Actions/VBoxContainer/ColorPalette/ColorE
]

# Store Firebase ID token if needed later
var firebase_id_token: String = ""


# Called when the node enters the scene tree for the first time.
func _ready() -> void:

    generate_grid()
    color_picker.color = active_color
    # Capture initial blank canvas state for Undo baseline
    call_deferred("_push_undo_snapshot")
    # Connect palette swatch gui_input; signal provides (InputEvent). We bind the swatch as second arg
    for c in palette_colors:
        c.gui_input.connect(Callable(self, "_on_palette_gui_input").bind(c))
    _init_stamp_masks()
    _setup_stamp_menu()

    # Attempt to enable emoji rendering if a font exists
    if ResourceLoader.exists("res://assets/Fonts/NotoColorEmoji-Regular.ttf"):
        _emoji_font = load("res://assets/Fonts/NotoColorEmoji-Regular.ttf")
        _emoji_enabled = _emoji_font != null
        if _emoji_enabled:
            _emoji_sv = SubViewport.new()
            _emoji_sv.size = Vector2i(128, 128)
            _emoji_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
            add_child(_emoji_sv)
            _emoji_sv.visible = false
            var root = Control.new()
            root.custom_minimum_size = Vector2(128, 128)
            _emoji_sv.add_child(root)
            _emoji_label = Label.new()
            _emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            _emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            _emoji_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            _emoji_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
            _emoji_label.add_theme_font_override("font", _emoji_font)
            _emoji_label.add_theme_font_size_override("font_size", 96)
            root.add_child(_emoji_label)

# Hide default buttons from ConfirmationDialog
    save_option_dialog.get_ok_button().hide()
    save_option_dialog.get_cancel_button().hide()

    # Runtime Permissions
    if OS.has_feature("Android"):
        # returns true if already granted, otherwise shows the system dialog
        var granted = OS.request_permissions()
        if granted:
            print("Storage permissions already granted.")
        else:
            print("Requested storage permissions; waiting for user...")

# Called by the engine once the user responds to the permission dialog
func _on_request_permissions_result(permissions: Array, grant_results: Array) -> void:
    for i in range(permissions.size()):
        var perm = permissions[i]
        var ok = grant_results[i] == OK
        #print("%s → %s" % [perm, ok ? "granted" : "denied"])
    # e.g. if WRITE_EXTERNAL_STORAGE was just granted, you could now:
    # if "android.permission.WRITE_EXTERNAL_STORAGE" in permissions and grant_results[permissions.find("android.permission.WRITE_EXTERNAL_STORAGE")] == OK:
    #     save_artwork_to_android()

func generate_grid() -> void:
    grid.columns = GRID_SIZE #set no.of columns
    
    # Create each cell in the grid
    for i in range(GRID_SIZE * GRID_SIZE):
        var cell = TextureButton.new()
        
        # Cursor shape
        cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        # Size 
        cell.custom_minimum_size = Vector2(16, 16)
        # Texture
        cell.stretch_mode = TextureButton.STRETCH_SCALE
        cell.ignore_texture_size = true
        cell.texture_normal = load("res://assets/Paintingtool/square.png")
        # Colour
        cell.modulate = Color(1, 1, 1)
        
        grid.add_child(cell)
        
# Handle painting when mouse is used 	
func _input(event) -> void:
    if event is InputEventMouseButton:
        # Start painting when left mouse button is pressed
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            is_painting = true
            # Paint the cell under the mouse on press
            var cell_under_mouse = get_cell_at_mouse_position(event.position)
            if cell_under_mouse:
                match current_tool:
                    Tool.BRUSH:
                        _fill_radius_at_cell(cell_under_mouse, brush_radius, active_color)
                    Tool.ERASER:
                        _fill_radius_at_cell(cell_under_mouse, 1, erase_color)
                    Tool.STAMP:
                        _apply_stamp_at_cell(cell_under_mouse)
                
        # Stop painting when the left mouse button is released
        if event.button_index == MOUSE_BUTTON_LEFT and !event.pressed:
            is_painting = false

    if event is InputEventMouseMotion and is_painting:
        # Paint while the mouse moves (if we are painting)
        var cell_under_mouse = get_cell_at_mouse_position(event.position)
        if cell_under_mouse:
            match current_tool:
                Tool.BRUSH:
                    _fill_radius_at_cell(cell_under_mouse, brush_radius, active_color)
                Tool.ERASER:
                    _fill_radius_at_cell(cell_under_mouse, brush_radius, erase_color)
        
# Get the cell under the mouse position
func get_cell_at_mouse_position(_mouse_pos: Vector2) -> TextureButton:
    # Prefer hovered control, which respects scaling and containers
    var hovered = get_viewport().gui_get_hovered_control()
    if hovered and hovered.get_parent() == grid and hovered is TextureButton:
        return hovered
    return null

func _fill_radius_at_cell(target: TextureButton, radius: float, color: Color) -> void:
    _push_undo_snapshot()
    var cells = grid.get_children()
    var index = cells.find(target)
    if index == -1:
        return
    var cx = index % GRID_SIZE
    var cy = index / GRID_SIZE
    var min_y = max(0, int(floor(cy - radius)))
    var max_y = min(GRID_SIZE - 1, int(ceil(cy + radius)))
    var min_x = max(0, int(floor(cx - radius)))
    var max_x = min(GRID_SIZE - 1, int(ceil(cx + radius)))
    var radius_sq: float = radius * radius
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            var dx: float = float(x - cx)
            var dy: float = float(y - cy)
            if (dx * dx + dy * dy) <= radius_sq + 1e-6:
                var idx = x + y * GRID_SIZE
                (cells[idx] as TextureButton).modulate = color

func _apply_stamp_at_cell(target: TextureButton):
    _push_undo_snapshot()
    var cells = grid.get_children()
    var index = cells.find(target)
    if index == -1:
        return
    var cx = index % GRID_SIZE
    var cy = index / GRID_SIZE

    # Emoji-based stamp rendering
    if _emoji_enabled and selected_stamp_index >= 0 and selected_stamp_index < emoji_stamps.size():
        var ch: String = emoji_stamps[selected_stamp_index]
        var key = ch
        var img: Image = null
        if _emoji_cache.has(key):
            img = _emoji_cache[key]
        else:
            _emoji_label.text = ch
            await get_tree().process_frame
            var tex: Texture2D = _emoji_sv.get_texture()
            if tex:
                img = tex.get_image()
                if img:
                    var side := 9
                    var tmp := img.duplicate()
                    tmp.resize(side, side, Image.INTERPOLATE_NEAREST)
                    _emoji_cache[key] = tmp
                    img = tmp
        if img:
            for y in range(img.get_height()):
                for x in range(img.get_width()):
                    var c: Color = img.get_pixel(x, y)
                    if c.a > 0.1:
                        var gx = clamp(cx + x - img.get_width() / 2, 0, GRID_SIZE - 1)
                        var gy = clamp(cy + y - img.get_height() / 2, 0, GRID_SIZE - 1)
                        var idx2 = int(gx) + int(gy) * GRID_SIZE
                        (cells[idx2] as TextureButton).modulate = stamp_tint
            return

    # Fallback to boolean mask
    if selected_stamp_index < 0 or selected_stamp_index >= stamp_masks.size():
        _fill_radius_at_cell(target, 0.5, stamp_tint)
        return
    var mask: Array = stamp_masks[selected_stamp_index]
    var half = int(floor(sqrt(mask.size()))) / 2
    var side = int(floor(sqrt(mask.size())))
    for y in range(side):
        for x in range(side):
            if mask[y * side + x]:
                var gx2 = clamp(cx + x - half, 0, GRID_SIZE - 1)
                var gy2 = clamp(cy + y - half, 0, GRID_SIZE - 1)
                var idx3 = int(gx2) + int(gy2) * GRID_SIZE
                (cells[idx3] as TextureButton).modulate = stamp_tint

func _init_stamp_masks() -> void:
    # Define simple 5x5 shapes: heart-ish, star-ish, flower-ish, paw, triangle, circle, diamond, leaf
    # Use booleans in a flat array row-major
    var H = true
    var F = false
    var circle = [
        F, H, H, H, F,
        H, H, H, H, H,
        H, H, H, H, H,
        H, H, H, H, H,
        F, H, H, H, F
    ]
    var diamond = [
        F, F, H, F, F,
        F, H, H, H, F,
        H, H, H, H, H,
        F, H, H, H, F,
        F, F, H, F, F
    ]
    var triangle = [
        F, F, H, F, F,
        F, H, H, H, F,
        H, H, H, H, H,
        F, F, F, F, F,
        F, F, F, F, F
    ]
    var star = [
        F, F, H, F, F,
        F, H, F, H, F,
        H, F, H, F, H,
        F, H, F, H, F,
        F, F, H, F, F
    ]
    var heart = [
        H, H, F, H, H,
        H, H, H, H, H,
        H, H, H, H, H,
        F, H, H, H, F,
        F, F, H, F, F
    ]
    var flower = [
        F, H, F, H, F,
        H, H, H, H, H,
        F, H, H, H, F,
        H, H, H, H, H,
        F, H, F, H, F
    ]
    var paw = [
        H, F, H, F, H,
        F, H, F, H, F,
        F, H, H, H, F,
        F, F, H, F, F,
        F, F, H, F, F
    ]
    # Sun: circle with rays
    var sun = [
        F, H, F, H, F,
        H, H, H, H, H,
        F, H, H, H, F,
        H, H, H, H, H,
        F, H, F, H, F
    ]
    # Order to match Stamp1..4: flower, heart, star, sun
    stamp_masks = [flower, heart, star, sun]

func _setup_stamp_menu() -> void:
    if not stamps_grid:
        printerr("Stamps grid not found!")
        return
    
    for i in range(emoji_stamps.size()):
        var stamp_button = TextureButton.new()
        
        # Use a label and viewport texture to display emojis
        var label = Label.new()
        label.text = emoji_stamps[i]
        label.add_theme_font_override("font", _emoji_font)
        label.add_theme_font_size_override("font_size", 48)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.size_flags_vertical = Control.SIZE_EXPAND_FILL
        
        var viewport = SubViewport.new()
        viewport.add_child(label)
        viewport.size = Vector2(64, 64)
        viewport.transparent_bg = true
        
        stamp_button.texture_normal = viewport.get_texture()
        stamp_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
        stamp_button.custom_minimum_size = Vector2(64, 64)
        
        # Connect the pressed signal to a new function
        # We bind the index so we know which stamp was clicked
        stamp_button.pressed.connect(Callable(self, "_on_stamp_selected").bind(i))
        
        stamps_grid.add_child(stamp_button)

func _on_stamp_selected(index: int):
    selected_stamp_index = index
    current_tool = Tool.STAMP
    stamp_tint = active_color
    stamps_menu.hide()
    print("Selected stamp index: ", index)
    
    # Optional: change the main stamp button's icon to the selected stamp
    if selected_stamp_index >= 0 and _emoji_enabled:
        var tex = Texture2D.new()
        _emoji_label.text = emoji_stamps[selected_stamp_index]
        await get_tree().process_frame
        tex = _emoji_sv.get_texture()
        stamp_button.icon = tex


func _on_palette_gui_input(e: InputEvent, color_rect: ColorRect) -> void:
    if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
        _on_palette_color_clicked(color_rect.color)

# Compatibility wrappers for connected signals from scene
func _on_savefiledialog_files_selected(_paths: PackedStringArray) -> void:
    return

func _on_http_request_request_completed(result, response_code, headers, body) -> void:
    _on_HTTPRequest_request_completed(result, response_code, headers, body)

func _on_local_button_pressed() -> void:
    _on_LocalButton_pressed()

func _on_firebase_button_pressed() -> void:
    _on_FirebaseButton_pressed()

# Change brush color from color picker
func _on_color_picker_button_color_changed(color: Color) -> void:
    active_color = color
    is_eraser_enabled = false
    eraser_button.text = "Eraser"
    current_tool = Tool.BRUSH

func _on_palette_color_clicked(color: Color) -> void:
    color_picker.color = color
    _on_color_picker_button_color_changed(color)

#Clear the grid (set all cells to white) 	
func _on_clear_button_pressed() -> void:
    _push_undo_snapshot()
    for cell in grid.get_children():
        if cell is TextureButton:
            cell.modulate = Color(1, 1, 1) # Reset to white

func _on_brush_button_pressed() -> void:
    current_tool = Tool.BRUSH

func _on_thickness_changed(value: float) -> void:
    brush_radius = int(value)
 
func _on_size_small_pressed() -> void:
    brush_radius = 0.5

func _on_size_medium_pressed() -> void:
    brush_radius = 1.25

func _on_size_large_pressed() -> void:
    brush_radius = 2.0

func _on_size_xl_pressed() -> void:
    brush_radius = 3.0

func _on_fill_button_pressed() -> void:
    _push_undo_snapshot()
    # Fill all current white cells to active_color
    for cell in grid.get_children():
        if cell is TextureButton and (cell as TextureButton).modulate.is_equal_approx(Color(1, 1, 1)):
            (cell as TextureButton).modulate = active_color

func _push_undo_snapshot() -> void:
    var cells = grid.get_children()
    var colors: PackedColorArray = PackedColorArray()
    colors.resize(cells.size())
    for i in range(cells.size()):
        colors[i] = (cells[i] as TextureButton).modulate
    undo_stack.append(colors)
    redo_stack.clear()

func _apply_snapshot(colors: PackedColorArray) -> void:
    var cells = grid.get_children()
    var n = min(cells.size(), colors.size())
    for i in range(n):
        (cells[i] as TextureButton).modulate = colors[i]

func _on_undo_pressed() -> void:
    if undo_stack.size() == 0:
        return
    var last: PackedColorArray = undo_stack.pop_back()
    # Save current to redo
    var current: PackedColorArray = PackedColorArray()
    var cells = grid.get_children()
    current.resize(cells.size())
    for i in range(cells.size()):
        current[i] = (cells[i] as TextureButton).modulate
    redo_stack.append(current)
    _apply_snapshot(last)

func _on_redo_pressed() -> void:
    if redo_stack.size() == 0:
        return
    var next: PackedColorArray = redo_stack.pop_back()
    # Save current to undo
    var current: PackedColorArray = PackedColorArray()
    var cells = grid.get_children()
    current.resize(cells.size())
    for i in range(cells.size()):
        current[i] = (cells[i] as TextureButton).modulate
    undo_stack.append(current)
    _apply_snapshot(next)

func _on_stamp_button_pressed() -> void:
    current_tool = Tool.STAMP
    stamp_tint = active_color
    stamps_menu.popup_centered()
    # If textures fail to show for any reason, set fallback text outlines
    var grid = $StampsMenu/VBoxContainer/MyStamps
    var names = ["Flower", "Heart", "Star", "Sun"]
    for i in range(min(4, grid.get_child_count())):
        var b = grid.get_child(i)
        if b is TextureButton and (b as TextureButton).texture_normal == null:
            (b as TextureButton).text = names[i]

func _on_stamps_menu_button_pressed() -> void:
    stamps_menu.popup_centered()

func _on_use_stamp_pressed() -> void:
    # For now, select first stamp implicitly
    if selected_stamp_index == -1:
        selected_stamp_index = 0
    stamps_menu.hide()

# removed H/S/B handlers and preview tinting


# Save the artwork to a fixed path (Desktop) or Pictures folder
func save_artwork_to_desktop() -> void:
    var image = Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
    var grid_cells = grid.get_children()

    for y in range(GRID_SIZE):
        for x in range(GRID_SIZE):
            var index = x + (y * GRID_SIZE)
            var cell = grid_cells[index] as TextureButton
            image.set_pixel(x, y, cell.modulate)

    var custom_title = title_input.text.strip_edges()
    if custom_title == "":
        custom_title = "Artwork"

    # Clean and sanitize title
    custom_title = custom_title.strip_edges().replace(" ", "_")
    custom_title = custom_title.replace("/", "").replace("\\", "").replace(":", "")
    custom_title = custom_title.replace("*", "").replace("?", "").replace("\"", "")
    custom_title = custom_title.replace("<", "").replace(">", "").replace("|", "")

    # To generate UUID-like ID
    var uuid = str(hash(Time.get_ticks_usec())) + "_" + str(randi() % 100000)
    var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
    var file_name = custom_title + "_" + uuid + "_" + timestamp + ".png"
    
    var save_path
    if OS.has_feature("Android"):
        save_path = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES) + "/" + file_name
    else:
        # Prefer Pictures if available, fallback to Desktop
        save_path = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
        if save_path == "":
            save_path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
        save_path += "/" + file_name
    
    var err = image.save_png(save_path)
    if err == OK:
        print("Artwork saved to:", save_path)
    else:
        print("Failed to save. Error code:", err)


# Save & Close button pressed
func _on_save_close_button_pressed() -> void:

    save_option_dialog.popup_centered()
    
# Save to internal path for Firebase
#Save artwork to user:// for Firebase upload
func save_artwork_to_user_path() -> String:
    var image = Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
    var grid_cells = grid.get_children()

    for y in range(GRID_SIZE):
        for x in range(GRID_SIZE):
            var index = x + (y * GRID_SIZE)
            var cell = grid_cells[index] as TextureButton
            image.set_pixel(x, y, cell.modulate)

    var save_path = "user://artwork.png"
    var err = image.save_png(save_path)

    if err == OK:
        return save_path
    else:
        return ""

# Upload to Firebase storage
func upload_artwork_to_firebase() -> void:
    var image = Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
    var grid_cells = grid.get_children()

    for y in range(GRID_SIZE):
        for x in range(GRID_SIZE):
            var index = x + (y * GRID_SIZE)
            var cell = grid_cells[index] as TextureButton
            image.set_pixel(x, y, cell.modulate)

    var byte_data = image.save_png_to_buffer()
    if byte_data.size() == 0:
        print("Image save failed!")
        return

    # Get the custom title from input
    var custom_title = title_input.text.strip_edges()
    if custom_title == "":
        custom_title = "untitled"

    # Clean title for filename
    custom_title = custom_title.replace(" ", "_")
    custom_title = custom_title.replace("/", "").replace("\\", "").replace(":", "")
    custom_title = custom_title.replace("*", "").replace("?", "").replace("\"", "")
    custom_title = custom_title.replace("<", "").replace(">", "").replace("|", "")

    # to generate UUID-like unique ID
    var uuid = str(hash(Time.get_ticks_usec())) + "_" + str(randi() % 100000)

    # Final clean filename
    var file_name = custom_title + "_" + uuid + ".png"

    # Encode only the path for the URL
    var encoded_path = "artworks/" + file_name.uri_encode()
    var upload_url = "https://firebasestorage.googleapis.com/v0/b/artea-9da5a.firebasestorage.app/o?uploadType=media&name=" + encoded_path

    var headers = [
		"Content-Type: image/png"
    ]

    var err = http_request.request_raw(upload_url, headers, HTTPClient.METHOD_POST, byte_data)
    if err != OK:
        print("Failed to send request")
    else:
        print("Uploading:", file_name)

#Callback when HTTP upload finishes
func _on_HTTPRequest_request_completed(result, response_code, headers, body) -> void:
    if response_code == 200:
        print("Upload success")
        print("Response:", body.get_string_from_utf8())
        
    else:
        print("Upload failed:", response_code)
        print("Response:", body.get_string_from_utf8())
        

#Toggle eraser mode
func _on_eraser_button_pressed() -> void:
    is_eraser_enabled = !is_eraser_enabled
    if is_eraser_enabled:
        active_color = erase_color
        eraser_button.text = "Eraser ON"
        current_tool = Tool.ERASER
    else:
        active_color = color_picker.color # Revert to selected color
        eraser_button.text = "Eraser"
        current_tool = Tool.BRUSH

#Firebase save button clicked
func _on_FirebaseButton_pressed() -> void:
    save_option_dialog.hide()
    save_artwork_to_desktop()  
    upload_artwork_to_firebase()

#Local save button clicked
func _on_LocalButton_pressed() -> void:
    save_option_dialog.hide()
    save_artwork_to_desktop()
 
#Back button clicked – return to hub scene
func _on_back_to_hub_button_pressed() -> void:
    SceneLoader.change_scene(get_tree(), "res://scenes/artea_game.tscn")
