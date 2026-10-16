# Milo's castle line summons a guide arrow that floats above the player,
# points at the hub castle's door, and clears itself on arrival. Scenes
# without that door never get one.
#   godot --headless --path artea --script res://scripts/test_castle_guide_arrow.gd
extends SceneTree

const CHATBOT_SCENE := preload("res://scenes/chatbot.tscn")
const DOOR_POSITION := Vector3(-39.8, 78.33, 27.41)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# A scene with no castle door (e.g. the gallery) gets no arrow.
	var plain := Node3D.new()
	plain.name = "PlainScene"
	root.add_child(plain)
	current_scene = plain
	var chat = CHATBOT_SCENE.instantiate()
	root.add_child(chat)
	await process_frame
	chat._show_castle_arrow()
	assert(plain.get_node_or_null("CastleGuideArrow") == null,
		"scenes without the hub castle's door get no arrow")
	chat.queue_free()
	plain.queue_free()
	await process_frame

	# A hub-like scene: the castle door high up the stair, player down below.
	var hub := Node3D.new()
	hub.name = "HubScene"
	root.add_child(hub)
	current_scene = hub
	var door := Area3D.new()
	door.name = "Art_Gallery"
	hub.add_child(door)
	door.global_position = DOOR_POSITION
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.add_to_group("player")
	hub.add_child(player)
	player.global_position = Vector3(60.0, 20.0, 10.0)

	chat = CHATBOT_SCENE.instantiate()
	root.add_child(chat)
	await process_frame
	chat._show_strength_discoveries()
	for _question in chat.STRENGTH_QUESTIONS:
		chat._answer_strength_question("curiosity")
	var choices := chat.get_node("InputContent/CuratedChoices") as VBoxContainer
	var reveal := (chat.get_node("MiloReplyCard/ChatHistory") as TextEdit).text
	assert(reveal.contains("Other worlds also await you") and not reveal.contains("Try this"),
		"in the overworld the reveal mentions the other worlds instead of a tip")
	assert(hub.get_node_or_null("CastleGuideArrow") == null,
		"the arrow waits until the player asks for other worlds")
	var other_worlds := choices.get_node_or_null("MiloTryOtherWorlds") as Button
	assert(other_worlds != null, "the hub offers Try other worlds beside the suggestion")
	var travel := choices.get_node_or_null("MiloTravel_mind") as Button
	assert(travel != null and other_worlds.get_index() == travel.get_index() + 1,
		"Try other worlds sits right after the suggested world")
	other_worlds.pressed.emit()
	var history := chat.get_node("MiloReplyCard/ChatHistory") as TextEdit
	assert(history.text.contains("top of the castle"),
		"Try other worlds tells the player the worlds are at the top of the castle")
	var arrow := hub.get_node_or_null("CastleGuideArrow") as Node3D
	assert(arrow != null, "Try other worlds summons the castle arrow")
	chat._show_other_worlds()
	var arrows := 0
	for child in hub.get_children():
		if child.name.begins_with("CastleGuideArrow"):
			arrows += 1
	assert(arrows == 1, "asking again never stacks arrows")

	await process_frame
	await process_frame
	assert(arrow.global_position.y > player.global_position.y + 2.5,
		"the arrow floats above the player's head")
	var pivot := arrow.get_node("Pivot") as Node3D
	var aim := -pivot.global_transform.basis.z.normalized()
	var expected := (DOOR_POSITION - arrow.global_position).normalized()
	assert(aim.dot(expected) > 0.99, "the arrow points at the castle door")

	# The castle drifts; the arrow follows the live door, not a fixed point.
	door.global_position = DOOR_POSITION + Vector3(0.0, 0.0, 30.0)
	await process_frame
	aim = -pivot.global_transform.basis.z.normalized()
	expected = (door.global_position - arrow.global_position).normalized()
	assert(aim.dot(expected) > 0.99, "the arrow tracks the door as it moves")
	door.global_position = DOOR_POSITION
	var caption := arrow.get_node("Caption") as Label3D
	assert(caption.text.contains("Castle · ") and caption.text.ends_with(" m"),
		"the caption names the castle and the distance")
	assert(arrow.get_node_or_null("Pivot/Sparkles") is CPUParticles3D \
			and arrow.get_node_or_null("Pivot/Halo") != null \
			and arrow.get_node_or_null("Pivot/Glow") != null,
		"the arrow has its glow, halo and sparkle layers")

	# Arriving at the door clears the arrow.
	player.global_position = DOOR_POSITION - Vector3(2.0, 3.0, 0.0)
	await process_frame
	await process_frame
	assert(not is_instance_valid(arrow), "the arrow disappears once the player arrives")

	chat.queue_free()
	hub.queue_free()
	print("CASTLE_GUIDE_ARROW_TEST: PASS — hub-only arrow above the player points at the castle door and clears on arrival")
	quit()
