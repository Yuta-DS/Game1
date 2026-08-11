extends Control

@onready var settingsPanel = $"Settings Panel"
@onready var inventoryPanel = $"Inventory Panel"
#@onready var usersPanel =

# Called when the node enters the scene tree for the first time.

func _on_inventory_close_button_pressed() -> void:
	inventoryPanel.visible = false


func _on_inventory_pressed() -> void:
	inventoryPanel.visible = true
	settingsPanel.visible = false


func _on_settings_close_button_pressed() -> void:
	settingsPanel.visible = false

func _on_settings_pressed() -> void:
	settingsPanel.visible = true
	inventoryPanel.visible = false


func _on_volume_value_changed(value: float) -> void:
	# Clamp to avoid logarithmic issues
	if value <= 0.01:
		AudioServer.set_bus_volume_db(0, -80)  # Silent
	else:
		# Scale volume to max out at ~ -6 dB instead of 0 dB
		var scaled = value * 0.2  # Adjust multiplier to control max volume
		var db = linear_to_db(scaled)
		AudioServer.set_bus_volume_db(0, db)


func _on_mute_check_box_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(0,toggled_on)


func _on_settings_logout_button_pressed() -> void:
	
	Auth.logout()
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/game_start.tscn"
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free()


func _on_settings_credits_button_pressed() -> void:
	
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/credit_Section.tscn"
	
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free()
