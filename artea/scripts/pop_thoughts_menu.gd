# April 2026 - Complete pop thoughts menu and 3D clouds
extends Control

func _on_play_pressed():
	get_tree().change_scene_to_file("res://scenes/cloud_pop_3d.tscn")
	
func _on_instructions_pressed():
	$CenterContainer.visible = false
	$Panel.visible = true

func _on_return_to_hubworld_pressed():
	get_tree().change_scene_to_file("res://scenes/New_Hub_World.tscn")
	


var instruction_images = []
var current_index = 0

@onready var texture_rect = $Panel/TextureRect
@onready var next_button = $Panel/Next
@onready var prev_button = $Panel/Previous

func _ready():

	# Preload your instruction PNGs
	instruction_images = [
		preload("res://assets/Clouds/Menu/NewInstructions/PopCloud_instruction1.png"),
		preload("res://assets/Clouds/Menu/NewInstructions/PopCloud_instruction2.png"),
		preload("res://assets/Clouds/Menu/NewInstructions/PopCloud_instruction3.png"),
		preload("res://assets/Clouds/Menu/NewInstructions/PopCloud_instruction4.png"),
		preload("res://assets/Clouds/Menu/NewInstructions/PopCloud_instruction5.png"),
		preload("res://assets/Clouds/Menu/NewInstructions/PopCloud_instruction6.png"),
	]
	
	$Panel.visible = false  # Or replace with actual node path if different
	update_image()

func update_image():
	texture_rect.texture = instruction_images[current_index]
	prev_button.disabled = current_index == 0
	next_button.disabled = current_index == instruction_images.size() - 1

func _on_next_pressed():
	if current_index < instruction_images.size() - 1:
		current_index += 1
		update_image()

func _on_previous_pressed():
	if current_index > 0:
		current_index -= 1
		update_image()

func _on_close_pressed():
	$CenterContainer.visible = true
	$Panel.visible = false
