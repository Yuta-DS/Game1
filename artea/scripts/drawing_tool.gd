extends Control

const CANVAS_COL: int = 102
const CANVAS_ROW: int = 60
const CELL_SIZE := Vector2i(16, 16)

# Drawing variables
var active_color : Color = Color(1,0,0) 
var is_Drawing = false
var is_Erasing = false
var eraser_Colour : Color = Color(1,1,1) 

# Canvas and cells
var cells: Array[TextureButton] = []

# Undo system variables
var undo_history: Array[Dictionary] = []
var max_undo_steps: int = 10
var current_drawing_session: Dictionary = {}

# Stamp system
var pending_stamp_tex: Texture2D = null
var BASE_TEX: Texture2D = preload("res://assets/Paintingtool/square.png")
var pending_stamp_scale_cells: int = 3  # Fixed at 3x3 size

# Brush settings
var brush_span : int = 1
var active_stamp_id : int = 1

@onready var exit: Button = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Actions/VBoxContainer/Exit
@onready var brush: Button = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Drawing/VBoxContainer/Brush
@onready var stamp: Button = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Drawing/VBoxContainer/Stamp
@onready var eraser: Button = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Drawing/VBoxContainer/Eraser
@onready var canvas: GridContainer = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/VSplitContainer/VBoxContainer/Canvas
@onready var color_picker_button: ColorPickerButton = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Drawing/VBoxContainer/ColorPickerButton
@onready var clear: Button = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Actions/VBoxContainer/Clear
@onready var undo_button: Button = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Actions/VBoxContainer/Undo
@onready var title_input: LineEdit = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Actions/VBoxContainer/TitleLineEdit
@onready var save_close_button: Button = $CenterContainer/PanelContainer/MarginContainer/HSplitContainer/Actions/VBoxContainer/Save
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var save_option_dialog: AcceptDialog = $SaveOptionDialog
@onready var firebase_button: Button = $SaveOptionDialog/VBoxContainer/FirebaseButton
@onready var local_button: Button = $SaveOptionDialog/VBoxContainer/LocalButton

func _ready() -> void:
    generate_Canvas()
    # Sync initial brush color to the picker's initial color
    active_color = color_picker_button.color
    # Initialize undo button state
    _update_undo_button()

    color_picker_button.color_changed.connect(_on_color_picker_button_color_changed)
    brush.size_selected.connect(func(span:int):
        brush_span = span
        is_Drawing = false   # stop any accidental drawing after choosing
    )
    brush.pressed.connect(_on_brush_pressed)
    
    stamp.stamp_selected.connect(func(tex: Texture2D):
        pending_stamp_tex = tex           # arm one-shot placement
        is_Drawing = false                # avoid accidental drawing
    )
    
    clear.pressed.connect(_on_clear_button_pressed)
    undo_button.pressed.connect(_on_undo_button_pressed)
    exit.pressed.connect(_on_back_to_hub_button_pressed)
    eraser.pressed.connect(_on_eraser_pressed)
    
    # Save system connections
    save_close_button.pressed.connect(_on_save_close_button_pressed)
    firebase_button.pressed.connect(_on_firebase_button_pressed)
    local_button.pressed.connect(_on_local_button_pressed)
    http_request.request_completed.connect(_on_http_request_request_completed)
    
    # Hide default dialog buttons
    save_option_dialog.get_ok_button().hide()
    save_option_dialog.get_cancel_button().hide()
    
    # Runtime Permissions for Android
    if OS.has_feature("Android"):
        var granted = OS.request_permissions()
        if granted:
            print("Storage permissions already granted.")
        else:
            print("Requested storage permissions; waiting for user...")

# INPUT HANDLING
func _input(event: InputEvent) -> void:
    # Handle stamp placement
    if pending_stamp_tex != null:
        if event is InputEventMouseButton:
            if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _is_over_canvas(event.position):
                var idx := _cell_index_at_mouse(event.position)
                if idx != -1:
                    _place_stamp_in_cells(idx)
                    pending_stamp_tex = null
                return
            if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
                pending_stamp_tex = null   # cancel
                return
        if event.is_action_pressed("ui_cancel"):
            pending_stamp_tex = null
        return
    
    # Handle brush and eraser drawing
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _is_over_canvas(event.position):
            is_Drawing = true
            var idx: int = _cell_index_at_mouse(event.position)
            if idx != -1:
                # Save state at the start of a new drawing session
                if current_drawing_session.is_empty():
                    _save_current_state()
                
                if is_Erasing:
                    _erase_block_from_index(idx, brush_span)
                else:
                    _paint_block_from_index(idx, brush_span, active_color)
        elif event.button_index == MOUSE_BUTTON_LEFT and !event.pressed:
            is_Drawing = false
            # Save the drawing session to history when drawing stops
            _save_drawing_session()
    elif event is InputEventMouseMotion and is_Drawing and _is_over_canvas(event.position):
        var idx2: int = _cell_index_at_mouse(event.position)
        if idx2 != -1:
            if is_Erasing:
                _erase_block_from_index(idx2, brush_span)
            else:
                _paint_block_from_index(idx2, brush_span, active_color)
        
    if event.is_action_pressed("toggle_eraser"):
        eraser.button_pressed = !eraser.button_pressed


#GENERATE CANVAS
func generate_Canvas() -> void:
    """Generate the drawing canvas with cells"""
    var tex := BASE_TEX
    canvas.columns = CANVAS_COL
    canvas.custom_minimum_size = Vector2(CANVAS_COL * CELL_SIZE.x, CANVAS_ROW * CELL_SIZE.y)
    
    for _i in range(CANVAS_COL * CANVAS_ROW):
        var cell := TextureButton.new()
        cell.texture_normal = tex
        cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        cell.custom_minimum_size = CELL_SIZE
        cell.stretch_mode = TextureButton.STRETCH_SCALE
        cell.ignore_texture_size = true
        cell.texture_normal = tex
        cell.modulate = Color.WHITE
        canvas.add_child(cell)
        cells.append(cell)  # store a typed reference


#DRAWING FUNCTIONS
func _paint_block_from_index(center_idx: int, span: int, col: Color) -> void:
    """Paint a circular brush pattern with the given color"""
    var total: int = cells.size()
    var cols: int = max(1, canvas.columns)

    var r_center: int = int(center_idx / cols)
    var c_center: int = center_idx % cols

    # Calculate radius for circular brush
    var radius: float = span / 2.0
    var radius_squared: float = radius * radius

    # Calculate bounds for the circular area
    var r0: int = r_center - int(radius)
    var c0: int = c_center - int(radius)
    var r1: int = r_center + int(radius) + 1
    var c1: int = c_center + int(radius) + 1

    for r: int in range(r0, r1):
        for c: int in range(c0, c1):
            if r < 0 or c < 0 or c >= cols or r >= CANVAS_ROW:
                continue
                
            # Calculate distance from center
            var dr: float = r - r_center
            var dc: float = c - c_center
            var distance_squared: float = dr * dr + dc * dc
            
            # Only paint if within the circle
            if distance_squared <= radius_squared:
                var idx: int = r * cols + c
                if idx < 0 or idx >= total:
                    continue

                var cell := cells[idx]
                if cell == null or !is_instance_valid(cell):
                    continue
                if cell.get_meta("stamped", false):   # don't tint stickers
                    continue

                if cell.modulate != col:
                    cell.modulate = col

func _erase_block_from_index(center_idx: int, span: int) -> void:
    """Erase a circular area of cells (reset to white)"""
    var total: int = cells.size()
    var cols: int = max(1, canvas.columns)

    var r_center: int = int(center_idx / cols)
    var c_center: int = center_idx % cols

    # Calculate radius for circular eraser
    var radius: float = span / 2.0
    var radius_squared: float = radius * radius

    # Calculate bounds for the circular area
    var r0: int = r_center - int(radius)
    var c0: int = c_center - int(radius)
    var r1: int = r_center + int(radius) + 1
    var c1: int = c_center + int(radius) + 1

    for r: int in range(r0, r1):
        for c: int in range(c0, c1):
            if r < 0 or c < 0 or c >= cols or r >= CANVAS_ROW:
                continue
                
            # Calculate distance from center
            var dr: float = r - r_center
            var dc: float = c - c_center
            var distance_squared: float = dr * dr + dc * dc
            
            # Only erase if within the circle
            if distance_squared <= radius_squared:
                var idx: int = r * cols + c
                if idx < 0 or idx >= total:
                    continue

                var cell: TextureButton = cells[idx]
                if cell == null or !is_instance_valid(cell):
                    continue

                cell.texture_normal = BASE_TEX
                cell.modulate = Color.WHITE
                if cell.has_meta("stamped"):
                    cell.set_meta("stamped", false)


#STAMP SYSTEM
func _place_stamp_in_cells(center_idx: int) -> void:
    """Place a stamp at the given center index"""
    var tex := pending_stamp_tex
    if tex == null:
        return

    var cols: int = max(1, canvas.columns)
    var total: int = cells.size()

    var w_cells: int = pending_stamp_scale_cells
    var h_cells: int = pending_stamp_scale_cells   # make a separate var if you want non-square stamps

    # center the stamp footprint on the hovered cell
    var r_center: int = int(center_idx / cols)
    var c_center: int = center_idx % cols
    var r0: int = r_center - int(h_cells / 2)
    var c0: int = c_center - int(w_cells / 2)

    # Scale the source image to the full footprint size (in pixels)
    var cell_px_w: int = CELL_SIZE.x
    var cell_px_h: int = CELL_SIZE.y
    var target_w_px: int = w_cells * cell_px_w
    var target_h_px: int = h_cells * cell_px_h

    var src_img: Image = tex.get_image()
    var scaled_img := src_img.duplicate()
    # Use NEAREST to keep pixel-art crisp
    scaled_img.resize(target_w_px, target_h_px, Image.INTERPOLATE_NEAREST)

    # Slice into cell-sized tiles and assign to cells
    for ry in range(h_cells):
        for rx in range(w_cells):
            var r := r0 + ry
            var c := c0 + rx
            if r < 0 or c < 0 or c >= cols:
                continue
            var idx := r * cols + c
            if idx < 0 or idx >= total:
                continue

            # Get the stamp portion and use it directly
            var stamp_img: Image = scaled_img.get_region(Rect2i(rx * cell_px_w, ry * cell_px_h, cell_px_w, cell_px_h))
            
            var cell := cells[idx]
            if cell == null or !is_instance_valid(cell):
                continue
                
            var tile_tex := ImageTexture.create_from_image(stamp_img)
            cell.texture_normal = tile_tex
            cell.modulate = Color.WHITE
            cell.set_meta("stamped", true)  # (optional) so brush won't tint it


#UTILITY FUNCTIONS
func _cell_index_at_mouse(mouse_pos: Vector2) -> int:
    for i in range(cells.size()):
        var c := cells[i]
        if !is_instance_valid(c):
            continue
        var rect := Rect2(c.global_position, c.size)
        if rect.has_point(mouse_pos):
            return i
    return -1

func _is_over_canvas(pos: Vector2) -> bool:
    return Rect2(canvas.global_position, canvas.size).has_point(pos)


#UI EVENT HANDLERS
func _on_color_picker_button_color_changed(color: Color) -> void:
    
    active_color = color

func _on_clear_button_pressed() -> void:
  
    var base_tex := load("res://assets/Paintingtool/square.png")
    for cell in cells:
        if cell and is_instance_valid(cell):
            cell.modulate = Color(1,1,1)
            cell.texture_normal = base_tex   # reset any stamps

func _on_brush_pressed() -> void:
    is_Erasing = false
    is_Drawing = false
    # cancel any armed stamp when brush is selected
    pending_stamp_tex = null

func _on_eraser_pressed() -> void:
    is_Erasing = true
    is_Drawing = false
    # cancel any armed stamp when eraser is selected
    pending_stamp_tex = null


#UNDO SYSTEM

func _save_current_state() -> void:

    current_drawing_session.clear()
    
    for i in range(cells.size()):
        var cell = cells[i]
        if cell and is_instance_valid(cell):
            current_drawing_session[i] = {
                "modulate": cell.modulate,
                "texture": cell.texture_normal,
                "stamped": cell.get_meta("stamped", false)
            }

func _save_drawing_session() -> void:
    if current_drawing_session.is_empty():
        return
    
    # Add to undo history
    undo_history.append(current_drawing_session.duplicate(true))
    
    # Limit undo history size
    if undo_history.size() > max_undo_steps:
        undo_history.pop_front()
    
    # Clear current session
    current_drawing_session.clear()
    
    # Update undo button state
    _update_undo_button()

func _on_undo_button_pressed() -> void:
    if undo_history.is_empty():
        return
    
    # Get the last saved state
    var last_state = undo_history.pop_back()
    
    # Restore all cells to their previous state
    for cell_index in last_state:
        var cell_data = last_state[cell_index]
        var cell = cells[cell_index]
        
        if cell and is_instance_valid(cell):
            cell.modulate = cell_data["modulate"]
            cell.texture_normal = cell_data["texture"]
            if cell_data["stamped"]:
                cell.set_meta("stamped", true)
            else:
                cell.remove_meta("stamped")
    
    # Update undo button state
    _update_undo_button()

func _update_undo_button() -> void:
    undo_button.disabled = undo_history.is_empty()

# SAVE SYSTEM

# Called by the engine once the user responds to the permission dialog
func _on_request_permissions_result(permissions: Array, grant_results: Array) -> void:
    for i in range(permissions.size()):
        var perm = permissions[i]
        var ok = grant_results[i] == OK
        print("%s → %s" % [perm, "granted" if ok else "denied"])

# Save the artwork to a fixed path (Desktop) or Pictures folder
func save_artwork_to_desktop() -> void:
    var image = Image.create(CANVAS_COL, CANVAS_ROW, false, Image.FORMAT_RGBA8)

    for y in range(CANVAS_ROW):
        for x in range(CANVAS_COL):
            var index = x + (y * CANVAS_COL)
            var cell = cells[index]
            if cell and is_instance_valid(cell):
                image.set_pixel(x, y, cell.modulate)
            else:
                image.set_pixel(x, y, Color.WHITE)

    var custom_title = title_input.text.strip_edges()
    if custom_title == "":
        custom_title = "Artwork"

    # Clean and sanitize title
    custom_title = custom_title.strip_edges().replace(" ", "_")
    custom_title = custom_title.replace("/", "").replace("\\", "").replace(":", "")
    custom_title = custom_title.replace("*", "").replace("?", "").replace("\"", "")
    custom_title = custom_title.replace("<", "").replace(">", "").replace("|", "")

    # Generate UUID-like ID
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

# Save artwork to user:// for Firebase upload
func save_artwork_to_user_path() -> String:
    var image = Image.create(CANVAS_COL, CANVAS_ROW, false, Image.FORMAT_RGBA8)

    for y in range(CANVAS_ROW):
        for x in range(CANVAS_COL):
            var index = x + (y * CANVAS_COL)
            var cell = cells[index]
            if cell and is_instance_valid(cell):
                image.set_pixel(x, y, cell.modulate)
            else:
                image.set_pixel(x, y, Color.WHITE)

    var save_path = "user://artwork.png"
    var err = image.save_png(save_path)

    if err == OK:
        return save_path
    else:
        return ""

# Upload to Firebase storage
func upload_artwork_to_firebase() -> void:
    var image = Image.create(CANVAS_COL, CANVAS_ROW, false, Image.FORMAT_RGBA8)

    for y in range(CANVAS_ROW):
        for x in range(CANVAS_COL):
            var index = x + (y * CANVAS_COL)
            var cell = cells[index]
            if cell and is_instance_valid(cell):
                image.set_pixel(x, y, cell.modulate)
            else:
                image.set_pixel(x, y, Color.WHITE)

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

    # Generate UUID-like unique ID
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

# Callback when HTTP upload finishes
func _on_http_request_request_completed(result, response_code, headers, body) -> void:
    if response_code == 200:
        print("Upload success")
        print("Response:", body.get_string_from_utf8())
    else:
        print("Upload failed:", response_code)
        print("Response:", body.get_string_from_utf8())

# Save & Close button pressed
func _on_save_close_button_pressed() -> void:
    save_option_dialog.popup_centered()

# Firebase save button clicked
func _on_firebase_button_pressed() -> void:
    save_option_dialog.hide()
    save_artwork_to_desktop()  
    upload_artwork_to_firebase()

# Local save button clicked
func _on_local_button_pressed() -> void:
    save_option_dialog.hide()
    save_artwork_to_desktop()

func _on_back_to_hub_button_pressed() -> void:
    get_tree().change_scene_to_file("res://New_Hub_World.tscn")
