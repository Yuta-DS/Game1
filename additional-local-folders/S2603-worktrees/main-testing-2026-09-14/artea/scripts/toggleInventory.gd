extends CanvasLayer

@onready var inventory_gui: Control = $inventoryGUI

func _ready() -> void:
    inventory_gui.close()

#press e to open inventory
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_Inventory"):
        if inventory_gui.isOpen:
            inventory_gui.close()
        else:
            inventory_gui.open()
