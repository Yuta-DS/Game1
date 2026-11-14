extends "res://scripts/milo_animations.gd"

# Milo 2 is the separately authored pictured-prototype character. It shares
# gameplay behaviour with Milo 1 but owns a different scene and model asset.

func _ready() -> void:
	set_meta("milo_generation", 2)
	set_meta("milo_visual_variant", "pictured_prototype_reference")
	super._ready()


func get_milo_generation() -> int:
	return 2
