# Parse-and-wire check for the transit scripts, without loading the hub or the
# gallery. Those scenes pull in the local LLM, terrain streaming and audio,
# which makes them far too slow for a feedback loop on this code.
extends SceneTree


func _fail(message: String) -> void:
	push_error("TRANSIT_SCRIPT_TEST: %s" % message)
	quit(1)


func _run() -> void:
	for path in ["res://scripts/hub_skyrail.gd", "res://scripts/hub_sky_isles.gd",
			"res://scripts/hub_train_rider.gd", "res://scripts/hub_castle_entrance.gd",
			"res://scenes/ExitGallery.gd", "res://scripts/Global.gd"]:
		if load(path) == null:
			_fail("%s failed to parse" % path)
			return

	# The rider seats its passenger from the rail's own lift, so that seam has to
	# exist as a method — a const is not readable through get() across scripts.
	var rail := Node3D.new()
	rail.set_script(load("res://scripts/hub_skyrail.gd"))
	root.add_child(rail)
	if not rail.has_method("get_ride_lift"):
		_fail("hub_skyrail lost get_ride_lift, the rider would fall back to a guess")
		return
	var lift: float = rail.call("get_ride_lift")
	if lift <= 0.0:
		_fail("ride lift must be positive, got %f" % lift)
		return

	print("TRANSIT_SCRIPT_TEST: PASS — all transit scripts parse, ride lift %.2f" % lift)
	quit()


func _init() -> void:
	call_deferred("_run")
