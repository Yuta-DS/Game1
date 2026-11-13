extends "res://scripts/milo_animations.gd"

# Milo 1 is the preserved legacy production character. Its visual asset and
# scene entry never redirect to Milo 2, so both generations can coexist.

func _ready() -> void:
	set_meta("milo_generation", 1)
	set_meta("milo_visual_variant", "legacy_exact_target")
	super._ready()


func get_milo_generation() -> int:
	return 1
