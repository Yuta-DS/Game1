extends SceneTree

# Hub village cleanup: non-Milo NPCs no longer open the old dialogue box (left
# for a future group to rebuild), unused objects are gone, and each minigame
# door has a sign beside it that doesn't block the way in.

const MUTED_NPCS := ["Father_Animations2", "Knight2", "Rogue", "Barbarian", "Mage"]
# Includes the floating orbs: the skyway trail with its "Mind Spark Kingdom"
# marker, the landmark lantern crystals and the drifting aether motes.
const REMOVED := ["MayorAlder", "Magitech", "Music_World", "Knight",
	"SkywayMap", "MindSparkWaypoint", "LandmarkGlow", "CastleAtmosphere"]
const SIGNED_DOORS := {
	"Popthought_world": "MinigameSign_PopThoughts",
	"Drawing_Tool2": "MinigameSign_Music",
	"Drawing_Tool": "MinigameSign_Drawing",
}


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("HUB_VILLAGE_CLEANUP_TEST: %s" % message)
	quit(1)


func _run() -> void:
	change_scene_to_file("res://scenes/New_Hub_World.tscn")
	for i in 30:
		await physics_frame
	var hub := current_scene
	var manager := root.get_node("GameManager")

	for node_name in REMOVED:
		if hub.find_child(node_name, true, false) != null:
			_fail("%s should have been removed from the hub" % node_name)
			return

	# Interacting with a muted NPC must not open the old dialogue box.
	for node_name in MUTED_NPCS:
		var npc := hub.get_node(node_name)
		npc.call("start_dialogue")
		await process_frame
		if manager.get("dialogue_ui") != null:
			_fail("%s still opens the old dialogue box" % node_name)
			return

	# The greeter neither offers a talk prompt nor opens dialogue.
	var greeter := hub.get_node("Villagers/Villager_Greeter")
	var player := hub.get_node("NewPlayer") as Node3D
	greeter.call("_on_dialogue_area_body_entered", player)
	if (greeter.get_node("InteractionPrompt") as Label3D).visible:
		_fail("the greeter still shows a talk prompt")
		return
	greeter.call("start_dialogue")
	await process_frame
	if manager.get("dialogue_ui") != null:
		_fail("the greeter still opens the old dialogue box")
		return

	# Milo keeps his dialogue.
	if hub.get_node_or_null("Milo_Animations2") == null:
		_fail("Milo is missing from the hub")
		return

	# Each minigame door has its sign close by, but not in the doorway.
	var signs := hub.get_node("MinigameSigns")
	for trigger_name in SIGNED_DOORS:
		var door := (hub.get_node("%s/CollisionShape3D" % trigger_name) as Node3D).global_position
		var signpost := signs.get_node_or_null(SIGNED_DOORS[trigger_name]) as Node3D
		if signpost == null:
			_fail("no sign for %s" % trigger_name)
			return
		var distance := Vector2(door.x, door.z).distance_to(
			Vector2(signpost.global_position.x, signpost.global_position.z))
		if distance < 3.0 or distance > 8.0:
			_fail("%s is %.1f m from its door" % [signpost.name, distance])
			return

	# The doors still work: walking straight up to the church door from the
	# front reaches the Pop Thoughts trigger.
	var church_trigger := hub.get_node("Popthought_world") as Area3D
	var church_door := (church_trigger.get_node("CollisionShape3D") as Node3D).global_position
	var church := hub.get_node("building_church_red2") as Node3D
	var outward := Vector3(church_door.x - church.global_position.x, 0.0,
		church_door.z - church.global_position.z).normalized()
	church_trigger.set_script(null)
	var reached := [false]
	church_trigger.body_entered.connect(func(body): if body == player: reached[0] = true)
	player.global_position = church_door + outward * 7.0
	for i in 20:
		await physics_frame
	for i in 90:
		player.global_position = player.global_position.move_toward(
			Vector3(church_door.x, player.global_position.y, church_door.z), 0.15)
		await physics_frame
	if not reached[0]:
		_fail("the Pop Thoughts door can no longer be reached")
		return

	print("HUB_VILLAGE_CLEANUP_TEST: PASS")
	quit()
