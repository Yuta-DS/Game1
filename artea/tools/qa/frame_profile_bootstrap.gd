extends Node

func _ready() -> void:
	var sampler: Node = (load("/tmp/frame_profile_sampler.gd") as GDScript).new()
	sampler.name = "OptInFrameProfile"
	get_tree().root.add_child.call_deferred(sampler)
