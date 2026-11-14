extends Button
signal size_selected(span: int)

@onready var brush_pop_up: PopupPanel = $BrushPopUp
@onready var grid_container: GridContainer = $BrushPopUp/MarginContainer/GridContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    # If you want it to open on press-down:
    action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
    pressed.connect(func ():
        # Window coords; place popup under the button
        brush_pop_up.popup()
    )

    var map := {"SmallBrush": 1, "MediumBrush": 2, "LargeBrush": 4}
    for c in grid_container.get_children():
        if c is BaseButton:
            c.pressed.connect(func():
                emit_signal("size_selected", map.get(c.name, 1))
                brush_pop_up.hide()
            )

func _unhandled_input(e: InputEvent) -> void:
    # Close when clicking outside or pressing Esc
    if !brush_pop_up.visible:
        return
    if e is InputEventMouseButton and e.pressed:
        var mouse := get_viewport().get_mouse_position()
        if !brush_pop_up.get_global_rect().has_point(mouse):
            brush_pop_up.hide()
    if e.is_action_pressed("ui_cancel"):
        brush_pop_up.hide()
