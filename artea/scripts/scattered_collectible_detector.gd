extends Area3D

## Attach this to the player to detect scattered collectibles via collision
## Works with Proton Scatter meshes that have collision enabled

@export var inventory_data: inventoryData
@export var pickup_range: float = 2.0

var nearby_collectibles: Dictionary = {} # Maps body RID to item data

func _ready() -> void:
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Set up collision
	collision_layer = 0
	collision_mask = 2 # Layer 2 for collectibles

func _on_body_entered(body: Node3D) -> void:
	# Check if this is a scattered collectible
	if body is StaticBody3D and body.has_meta("collectible_type"):
		var item_type = body.get_meta("collectible_type")
		nearby_collectibles[body.get_rid()] = item_type
		print("Near collectible: ", item_type)

func _on_body_exited(body: Node3D) -> void:
	if body is StaticBody3D:
		nearby_collectibles.erase(body.get_rid())

func _process(_delta: float) -> void:
	# Auto-collect nearby items
	for rid in nearby_collectibles.keys():
		var body = PhysicsServer3D.body_get_object_instance_id(rid)
		if body:
			var node = instance_from_id(body)
			if node and node.global_position.distance_to(global_position) <= pickup_range:
				_collect_item(node, nearby_collectibles[rid])

func _collect_item(body: Node3D, item_type: String) -> void:
	# Load item data based on type
	var item_data: itemData
	match item_type:
		"apple":
			item_data = load("res://resources/items/apple_item.tres")
		"clam":
			item_data = load("res://resources/items/clam_item.tres")
		_:
			print("Unknown item type: ", item_type)
			return
	
	# Try to add to inventory
	if get_parent().has_method("collect_item"):
		if get_parent().collect_item(item_data):
			# Remove the visual
			body.queue_free()
			nearby_collectibles.erase(body.get_rid())
			print("Collected scattered ", item_type)

