# Regression for the movement freeze caused by an orphaned interaction flag.
# Run headless:
#   godot --headless --path artea --script res://scripts/test_player_control_recovery.gd
extends SceneTree

const PLAYER_SCRIPT := preload("res://scenes/entities/new_player.gd")

class FakeNPC extends Node:
	var ended := false

	func end_dialogue() -> void:
		ended = true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := PLAYER_SCRIPT.new()
	player.interacting = true
	player.velocity = Vector3(4.0, 0.0, -2.0)

	# Outside the tree there cannot be a live dialogue/chat owner. This models
	# the broken state visible in play: movement locked, but no modal UI exists.
	player._recover_orphaned_interaction_lock()
	assert(not player.interacting, "orphaned interaction lock releases")
	assert(is_zero_approx(player.velocity.x) and is_zero_approx(player.velocity.z),
		"recovery clears stale horizontal motion")

	var manager_source := FileAccess.get_file_as_string("res://scripts/GameManager.gd")
	assert(manager_source.contains("Dialogue node not found: %s"),
		"invalid dialogue nodes are reported")
	assert(manager_source.contains("end_dialogue()\n\t\treturn"),
		"invalid dialogue nodes use the normal cleanup path")
	assert(manager_source.contains("is_instance_valid(active_npc)"),
		"dialogue cleanup tolerates an NPC removed during a scene change")
	player.free()

	# Reproduce the live-world variant that the old unit-only check missed. A
	# chatbot node can survive hidden for a frame (or be hidden by another UI)
	# after its modal interaction has ended. Merely finding a node called
	# `chatbot` must not keep the global movement lock alive when no chatbot is
	# actually visible to the player.
	var previous_scene := current_scene
	var world := Node3D.new()
	world.name = "ControlRecoveryWorld"
	root.add_child(world)
	current_scene = world
	var packed_player := (load("res://scenes/entities/NewPlayer.tscn") as PackedScene).instantiate()
	world.add_child(packed_player)
	var dormant_chatbot := Control.new()
	dormant_chatbot.name = "chatbot"
	dormant_chatbot.visible = false
	world.add_child(dormant_chatbot)
	await process_frame
	packed_player.interacting = true
	packed_player._recover_orphaned_interaction_lock()
	assert(not packed_player.interacting,
		"a hidden dormant chatbot cannot retain the player's movement lock")
	current_scene = previous_scene
	world.queue_free()
	await process_frame

	# Exercise the real autoload as well: a bad authored target must notify its
	# NPC and leave neither a UI nor an active owner behind.
	var manager := root.get_node_or_null("GameManager")
	assert(manager != null, "GameManager autoload is available")
	var npc := FakeNPC.new()
	root.add_child(npc)
	manager.start_dialogue("__missing_control_recovery_test__", npc)
	assert(npc.ended, "invalid dialogue target releases its NPC/player lock")
	assert(manager.active_npc == null, "invalid dialogue target clears its owner")
	assert(manager.dialogue_ui == null, "invalid dialogue target closes its UI")
	npc.queue_free()
	await process_frame

	print("PLAYER_CONTROL_RECOVERY_TEST: PASS — orphan locks release and invalid dialogue cleans up")
	quit()
