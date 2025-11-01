extends TextureButton

# Reference to the inventory GUI scene
@export var inventory_gui_scene: PackedScene

# Reference to the instantiated inventory GUI
var inventory_gui: Control = null

func _ready():
	# Load the inventory GUI scene if not set in the editor
	if inventory_gui_scene == null:
		inventory_gui_scene = load("res://scenes/inventory_gui.tscn")
	
	# Disable focus to prevent keyboard activation (like spacebar)
	focus_mode = Control.FOCUS_NONE
	
	# Connect the button pressed signal
	pressed.connect(_on_button_pressed)

func _on_button_pressed():
	if inventory_gui == null:
		# Instantiate and add the inventory GUI to the scene tree
		inventory_gui = inventory_gui_scene.instantiate()
		inventory_gui.visible = false
		get_tree().root.add_child(inventory_gui)
	
	# Toggle the inventory visibility
	inventory_gui.visible = !inventory_gui.visible
	
	# Pause/unpause the game when inventory is open
	# Uncomment if you want to pause the game when inventory is open
	# get_tree().paused = inventory_gui.visible

func _input(event):
	# Optional: Allow pressing 'I' or 'Tab' to toggle inventory
	if event.is_action_pressed("ui_cancel") and inventory_gui != null and inventory_gui.visible:
		inventory_gui.visible = false
		# get_tree().paused = false
