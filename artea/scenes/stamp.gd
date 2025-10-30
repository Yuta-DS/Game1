extends Button
signal stamp_selected(id: int)

@onready var stamp_pop_up: PopupPanel = $StampPopUp
@onready var grid_container: GridContainer = $StampPopUp/MarginContainer/GridContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
    pressed.connect(func ():
        stamp_pop_up.popup()
    )

    var ids := {
        "Cloud": preload("res://assets/Drawing Tool Icons/Cloud.png"), 
        "Flower": preload("res://assets/Drawing Tool Icons/flower2.png"), 
        "Sun": preload("res://assets/Drawing Tool Icons/sun.png"), 
        "Heart": preload("res://assets/Drawing Tool Icons/heart.png")
    }
    
    for c in grid_container.get_children():
        if c is BaseButton:
            c.pressed.connect(func():
                emit_signal("stamp_selected", ids.get(c.name, 0))  # <-- on self
                stamp_pop_up.hide()
            )

func _unhandled_input(e: InputEvent) -> void:
    if !stamp_pop_up.visible:
        return
    if e is InputEventMouseButton and e.pressed:
        var mouse := get_viewport().get_mouse_position()
        if !stamp_pop_up.get_global_rect().has_point(mouse):
            stamp_pop_up.hide()
    if e.is_action_pressed("ui_cancel"):
        stamp_pop_up.hide()
