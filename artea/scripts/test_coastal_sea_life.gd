extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("COASTAL_SEA_LIFE_TEST: %s" % message)
	quit(1)

func _run() -> void:
	var coast := (load("res://scripts/Pier.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(coast)
	await process_frame

	var expected := {"fish": 23, "crabs": 3, "shells": 3, "oysters": 2,
		"sea_mushrooms": 2, "jellyfish": 2, "starfish": 2, "turtles": 1}
	var counts: Dictionary = coast.call("creature_counts")
	if counts != expected:
		_fail("expected intact creature roots %s, got %s" % [expected, counts])
		return
	if coast.find_child("*Crystal*", true, false) != null:
		_fail("sea-life branch must not add crystals")
		return

	var fish := coast.find_child("Fish_ReefBlue_01", true, false) as Node3D
	var shell := coast.find_child("Shell_FanLarge_01", true, false) as Node3D
	if fish == null or shell == null:
		_fail("representative fish and shell are missing")
		return
	var fish_start := fish.position
	var shell_start := shell.transform
	coast.call("_process", 1.0)
	if fish.position.distance_to(fish_start) < 0.1:
		_fail("fish must visibly swim")
		return
	if shell.transform != shell_start:
		_fail("shells must remain seated")
		return

	print("COASTAL_SEA_LIFE_TEST: PASS — 38 intact creatures, animated fish and fixed seabed life")
	quit(0)
