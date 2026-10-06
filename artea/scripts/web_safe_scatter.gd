extends "res://addons/proton_scatter/src/scatter.gd"


func _enter_tree() -> void:
	# The non-threaded code path is provided by Proton Scatter itself and produces
	# the same instances. Browser exports do not enable SharedArrayBuffer threads.
	if OS.get_name() == "Web":
		dbg_disable_thread = true

