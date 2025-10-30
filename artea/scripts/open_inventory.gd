extends Control

@onready var inventoryButton: Node = $InventoryButton

var inventoryScene: PackedScene = preload("res://scenes/inventory_gui.tscn")
var inventoryInstance: Control = null

func _ready() -> void:
    if inventoryButton and inventoryButton.has_signal("pressed"):
        inventoryButton.connect("pressed", Callable(self, "_on_inventory_pressed"))

func _on_inventory_pressed() -> void:
    if inventoryInstance == null or not is_instance_valid(inventoryInstance):
        inventoryInstance = inventoryScene.instantiate()
        get_tree().root.add_child(inventoryInstance)
    else:
        inventoryInstance.visible = true

