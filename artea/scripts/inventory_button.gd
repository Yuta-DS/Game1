extends TextureButton

# Reference to the player's inventory GUI
var inventory_gui: Control = null

func _ready():
	# Disable focus to prevent keyboard activation (like spacebar)
	focus_mode = Control.FOCUS_NONE
	
	# Connect the button pressed signal
	pressed.connect(_on_button_pressed)
	
	# Find the player's inventory GUI
	call_deferred("_find_player_inventory")

func _find_player_inventory():
	# Look for the player in the scene
	var player = get_tree().get_first_node_in_group("player")
	if player:
		inventory_gui = player.get_node_or_null("InventoryGUI")
		if inventory_gui:
			print("Inventory button found player's inventory GUI")
		else:
			print("ERROR: Player exists but has no InventoryGUI child!")
	else:
		print("ERROR: No player found in scene!")

func _on_button_pressed():
	if inventory_gui == null:
		print("ERROR: inventory_gui is null - trying to find it again")
		_find_player_inventory()
		return
	
	# Toggle the inventory visibility using the same method as the 'E' key
	inventory_gui.toggle_visibility()
	
	# Pause/unpause the game when inventory is open
	# Uncomment if you want to pause the game when inventory is open
	# get_tree().paused = inventory_gui.isOpen

func _input(event):
	# Optional: Allow pressing 'I' or 'Tab' to toggle inventory
	if event.is_action_pressed("ui_cancel") and inventory_gui != null and inventory_gui.visible:
		inventory_gui.visible = false
		# get_tree().paused = false
