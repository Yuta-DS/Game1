class_name MindSparkCollectible
extends Area3D

signal collected(collectible_id: String)

@export var collectible_id := "mind_spark.spark"
@export var collected_state := false

@onready var visual: Node3D = $Visual
@onready var label: Label3D = $Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_state()


func collect() -> bool:
	if collected_state:
		return false
	collected_state = true
	_apply_state()
	collected.emit(collectible_id)
	return true


func restore_collected() -> void:
	collected_state = true
	_apply_state()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		collect()


func _process(delta: float) -> void:
	if not collected_state:
		visual.rotation.y += delta * 1.2


func _apply_state() -> void:
	visual.visible = not collected_state
	monitoring = not collected_state
	label.text = "THOUGHT SPARK COLLECTED ✓" if collected_state else "THOUGHT SPARK • WALK THROUGH"
	label.modulate = Color("7ee9a6") if collected_state else Color("fff0a0")

