extends Control

const INVENTORY_CAPACITY := 30
const SlotScene := preload("res://scenes/slot.tscn")

@onready var grid_container: GridContainer = $NinePatchRect/GridContainer

var inventory_data: inventoryData
var isOpen := false


func _ready() -> void:
	close()


func set_inventory_data(data: inventoryData) -> void:
	inventory_data = data
	if inventory_data != null and inventory_data.slot_Data.size() < INVENTORY_CAPACITY:
		inventory_data.slot_Data.resize(INVENTORY_CAPACITY)
	populate_slots()


func populate_slots() -> void:
	if inventory_data == null:
		return
	while grid_container.get_child_count() < inventory_data.slot_Data.size():
		grid_container.add_child(SlotScene.instantiate())
	while grid_container.get_child_count() > inventory_data.slot_Data.size():
		grid_container.get_child(grid_container.get_child_count() - 1).free()
	for index in inventory_data.slot_Data.size():
		grid_container.get_child(index).set_slot_data(inventory_data.slot_Data[index])


func refresh_slots() -> void:
	if inventory_data == null:
		return
	if grid_container.get_child_count() != inventory_data.slot_Data.size():
		populate_slots()
		return
	for index in inventory_data.slot_Data.size():
		grid_container.get_child(index).set_slot_data(inventory_data.slot_Data[index])


func toggle_visibility() -> void:
	if isOpen:
		close()
	else:
		open()


func open() -> void:
	visible = true
	isOpen = true
	refresh_slots()


func close() -> void:
	visible = false
	isOpen = false
