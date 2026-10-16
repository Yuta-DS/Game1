extends SceneTree

class FakeSailor:
	extends CharacterBody3D
	var interacting := false
	func collect_item(_item = null) -> void:
		pass

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("COASTAL_HARBOUR_TEST: %s" % message)
	quit(1)

func _run() -> void:
	var harbour := (load("res://scripts/Pier.tscn") as PackedScene).instantiate() as Node3D
	harbour.position.y = 0.9
	harbour.scale = Vector3.ONE * 1.5
	root.add_child(harbour)
	await process_frame
	var counts: Dictionary = harbour.call("creature_counts")
	var expected := {"fish": 23, "crabs": 3, "shells": 3, "oysters": 2,
		"sea_mushrooms": 2, "jellyfish": 2, "starfish": 2, "turtles": 1}
	if counts != expected:
		_fail("count only intact animal roots: expected %s, got %s" % [expected, counts])
		return
	if harbour.find_child("*Crystal*", true, false) != null:
		_fail("no crystal decorations")
		return
	if harbour.find_child("VillageHarbourOffice*", true, false) == null:
		_fail("office must reuse the real red-roof village kit")
		return
	var sign := harbour.find_child("HarbourSign", true, false) as MeshInstance3D
	var sign_data: Dictionary = sign.get_meta("extras", {}) if sign != null else {}
	if not str(sign_data.get("style_reference", "")).contains("Milo landmark") \
			or sign_data.get("front_direction", "") != "village":
		_fail("entrance sign must keep the Milo landmark style and face the village")
		return
	var title := harbour.find_child("HarbourTitle", true, false) as MeshInstance3D
	var accent := harbour.find_child("HarbourTitleAccent", true, false) as MeshInstance3D
	var title_data: Dictionary = title.get_meta("extras", {}) if title != null else {}
	var accent_data: Dictionary = accent.get_meta("extras", {}) if accent != null else {}
	if title_data.get("sign_text", "") != "Artéa" or title_data.get("lettering_revision", 0) != 3 \
			or title_data.get("lettering_source", "") != "res://assets/Fonts/NewFont-Artea.otf" \
			or not str(accent_data.get("lettering_component", "")).contains("Milo landmark diamond"):
		_fail("title must use the Artéa display face and Milo landmark diamond accent")
		return
	var title_bounds := title.global_transform * title.get_aabb()
	var board_bounds := sign.global_transform * sign.get_aabb()
	if title_bounds.end.z >= board_bounds.position.z or title_bounds.size.z < .02 \
			or title_bounds.position.x <= board_bounds.position.x or title_bounds.end.x >= board_bounds.end.x:
		_fail("raised letters must sit in front of the timber without clipping its edges")
		return
	if harbour.get_node_or_null("HarbourName") != null:
		_fail("entrance lettering belongs on the board, not on a floating billboard")
		return
	var sign_material := sign.mesh.surface_get_material(0) as StandardMaterial3D
	if sign_material == null or sign_material.albedo_texture == null:
		_fail("sign must retain its timber texture")
		return
	var sign_front := sign.global_basis * Vector3.BACK
	if sign_front.normalized().dot(Vector3.FORWARD) < .99:
		_fail("raised sign face must point inland (-Z)")
		return
	var sign_bounds := sign.global_transform * sign.get_aabb()
	if sign_bounds.position.y - 1.8 < 2.3:
		_fail("hanging sign must preserve player headroom")
		return
	var fish := harbour.find_child("Fish_ReefBlue_01", true, false) as Node3D
	var fish_start := fish.position
	var parts := {}
	for part in fish.find_children("*", "MeshInstance3D", true, false):
		parts[part] = part.transform
	var shell := harbour.find_child("Shell_FanLarge_01", true, false) as Node3D
	var shell_start := shell.transform
	harbour.call("_process", 1.0)
	if fish.position.distance_to(fish_start) < 0.1 or shell.transform != shell_start:
		_fail("fish must swim while shells stay seated")
		return
	for part in parts:
		if part.transform != parts[part]:
			_fail("animal mesh parts must not animate as independent creatures")
			return
	# Imported deck surfaces and physics surfaces must agree.
	var plank := harbour.find_child("JettyPlank_00", true, false) as Node3D
	var local_plank := harbour.to_local(plank.global_position)
	if local_plank.distance_to(Vector3(0, 0.51, -2.85)) > 0.01:
		_fail("imported jetty orientation must match the collision layout")
		return

	var boat := (load("res://scenes/boat.tscn") as PackedScene).instantiate() as CharacterBody3D
	var docked_position := Vector3(-11.1, 0.92, 9.0)
	boat.position = docked_position
	root.add_child(boat)
	var sailor := FakeSailor.new()
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	collider.shape = CapsuleShape3D.new()
	collider.position.y = 1.0
	sailor.add_child(collider)
	sailor.position = Vector3(0, 2.0, -7.0)
	root.add_child(sailor)
	# Walk the real deck, then across the berth into the boat trigger.
	for frame in 120:
		await physics_frame
		sailor.velocity = Vector3(0, -2, 8)
		sailor.move_and_slide()
	if sailor.position.z < 8.5 or sailor.position.y < 1.65:
		_fail("player must traverse the jetty on its collision surface")
		return
	for frame in 160:
		await physics_frame
		if boat.call("is_boarded"):
			break
		sailor.velocity = Vector3(-5, -2, 0)
		sailor.move_and_slide()
	if not boat.call("is_boarded") or sailor.is_physics_processing():
		_fail("walking from berth into trigger must board the boat")
		return
	await physics_frame
	if not collider.disabled:
		_fail("boarding disables the player's hull collision")
		return
	if not sailor.get_meta("sailing_boat", false):
		_fail("companions must know to wait ashore during sailing")
		return
	boat.call("disembark")
	await physics_frame
	if boat.call("is_boarded") or not sailor.is_physics_processing() or collider.disabled:
		_fail("dock disembark restores player controls and collision")
		return
	if sailor.position.y < 1.7:
		_fail("disembark must land on the berth, not in water")
		return
	if sailor.has_meta("sailing_boat"):
		_fail("safe disembark must release the companion wait state")
		return

	# Real input-driven motion in open water, steering, and riding attachment.
	boat.position = Vector3(30, 0.92, 0)
	boat.call("board", sailor)
	var start := boat.position
	Input.action_press("move_forward")
	for frame in 75:
		await physics_frame
	Input.action_press("move_right")
	for frame in 40:
		await physics_frame
	Input.action_release("move_forward")
	Input.action_release("move_right")
	if boat.position.distance_to(start) < 5 or absf(boat.rotation.y) < 0.2:
		_fail("forward and steering input must actually move and turn the boat")
		return
	if sailor.global_position.distance_to(boat.get_node("Seat").global_position) > 0.05:
		_fail("rider must remain attached while sailing")
		return
	boat.call("disembark")
	if not boat.call("is_boarded"):
		_fail("open-water disembarking must not drop the player into the sea")
		return
	boat.position = docked_position
	boat.rotation = Vector3.ZERO
	boat.velocity = Vector3.ZERO
	await physics_frame
	boat.call("disembark")
	if boat.call("is_boarded"):
		_fail("returning to the port must allow safe disembarking")
		return
	print("COASTAL_HARBOUR_TEST: PASS — village style, 38 intact creatures, deck traversal, trigger boarding, input sailing/steering, safe return")
	quit()
