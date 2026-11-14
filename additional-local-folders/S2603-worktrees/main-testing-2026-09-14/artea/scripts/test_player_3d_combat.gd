extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("PLAYER_3D_COMBAT_TEST: %s" % message)
	quit(1)


func _run() -> void:
	if not InputMap.has_action("jump") or not InputMap.has_action("attack") \
			or not InputMap.has_action("block"):
		_fail("jump, attack and block inputs must all exist")
		return

	var scene := (load("res://scenes/art_castle_floating_world.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player := scene.get_node_or_null("Player3D") as CharacterBody3D
	if player == null:
		_fail("3D world has no combat player")
		return
	if float(player.get("jump_height")) < 1.0:
		_fail("jump height is not usable")
		return
	if player.get_node_or_null("FoxVisuals/AttackHitbox") == null \
			or player.get_node_or_null("FoxVisuals/AttackArc") == null:
		_fail("attack has no forward hitbox or visible arc")
		return
	if player.get_node_or_null("FoxVisuals/ShieldBlock") == null:
		_fail("block has no visible shield")
		return
	if player.get_node_or_null("CombatHelpHUD/CombatHelpPanel/CombatHelpLabel") == null:
		_fail("player controls are not explained on screen")
		return
	var combat_audio := player.get_node_or_null("PlayerCombatFoley3D") as AudioStreamPlayer3D
	if combat_audio == null or combat_audio.max_distance <= 0.0 or combat_audio.panning_strength < 1.0:
		_fail("player combat has no attenuated directional Foley source")
		return

	player.call("_set_blocking", true)
	var before_block: float = player.get("current_health")
	var blocked: float = player.call("take_damage", 30.0, null)
	if blocked != 0.0 or player.get("current_health") != before_block:
		_fail("shield did not absorb damage")
		return
	if not (player.get_node("FoxVisuals/ShieldBlock") as Node3D).visible:
		_fail("shield is not visible while blocking")
		return

	player.call("_set_blocking", false)
	var applied: float = player.call("take_damage", 30.0, null)
	if applied != 30.0 or player.get("current_health") != before_block - 30.0:
		_fail("unblocked damage did not reduce health")
		return
	player.call("_start_attack")
	if not bool(player.get("is_attacking")) \
			or not (player.get_node("FoxVisuals/AttackArc") as MeshInstance3D).visible:
		_fail("attack state and visual did not activate")
		return
	var hitbox_shape := player.get_node(
		"FoxVisuals/AttackHitbox/CollisionShape3D") as CollisionShape3D
	if hitbox_shape == null or hitbox_shape.disabled:
		_fail("attack hitbox was not enabled")
		return
	var combat_stream := combat_audio.stream as AudioStreamWAV
	if combat_stream == null or combat_stream.mix_rate != 48000 \
			or combat_stream.get_meta("foley_event", &"") != &"player_swing":
		_fail("attack did not select the 48 kHz player swing Foley")
		return

	print("PLAYER_3D_COMBAT_TEST: PASS — SPACE jump, F attack hitbox, G shield and damage blocking are live")
	quit()
