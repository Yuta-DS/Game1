extends Resource
class_name slotData

const MAX_STACK_SIZE: int = 99

@export var item_Data: itemData
@export_range(1, MAX_STACK_SIZE) var quantity: int = 1
