extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("PLAYER_3D_COMBAT_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var balance := JSON.parse_string(FileAccess.get_file_as_string(
		"res://resources/mind_spark/player_combat_balance.json")) as Dictionary
	if balance.is_empty() or float((balance.focus as Dictionary).dodge_cost) != 25.0 \
			or (balance.attack.combo_damage as Array).size() != 3:
		_fail("data-driven combat balance is missing the Focus or three-hit contract")
		return
	var sentinel := load("res://resources/mind_spark/enemies/blight_sentinel.tres")
	var sentinel_reward: Dictionary = sentinel.call("reward_bundle")
	if int(sentinel.get("encounter_tier")) != 3 \
			or str(sentinel.get("animation_profile")) != "heavy_guard" \
			or int((sentinel_reward.items as Dictionary).get("storm_crystal", 0)) != 2:
		_fail("enemy definitions do not expose tier, animation and guaranteed rewards")
		return
	if not InputMap.has_action("jump") or not InputMap.has_action("attack") \
			or not InputMap.has_action("block") or not InputMap.has_action("dodge") \
			or not InputMap.has_action("charged_attack"):
		_fail("jump, combo, charge, dodge and block inputs must all exist")
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
	var progression := root.get_node_or_null("WorldOneProgression")
	if progression == null:
		_fail("WorldOneProgression autoload is missing")
		return
	progression.call("configure_save_path", "user://test_player_combat_progression.json", false)
	progression.call("clear_progress")
	progression.call("grant_item", "signal_blade", 1, "test:blade")
	progression.call("equip_item", "signal_blade")
	progression.call("grant_item", "memory_outfit", 1, "test:outfit")
	progression.call("equip_item", "memory_outfit")
	if not is_equal_approx(float(player.get("_equipment_attack_bonus")), 4.0) \
			or not is_equal_approx(float(player.get("max_health")), 112.0):
		_fail("authored equipment stats do not change attack and maximum health")
		return
	if player.get_node_or_null("CombatHelpHUD/CombatVitals/Bars/HealthBar") == null \
			or player.get_node_or_null("CombatHelpHUD/CombatVitals/Bars/FocusBar") == null:
		_fail("health and Focus are not visible in the production HUD")
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
	player.call("_finish_attack")
	player.set("_attack_cooldown_remaining", 0.0)
	player.call("_start_attack", "light")
	player.call("_finish_attack")
	player.set("_attack_cooldown_remaining", 0.0)
	player.call("_start_attack", "light")
	if int(player.get("_combo_stage")) != 3:
		_fail("successive light attacks do not reach the three-hit finisher")
		return
	player.call("_finish_attack")
	player.set("_attack_cooldown_remaining", 0.0)
	player.call("_start_attack", "charged")
	if float(player.get("_current_attack_damage")) <= float(player.get("attack_damage")) * 2.0:
		_fail("charged strike does not exceed twice the base attack damage")
		return
	player.call("_finish_attack")
	player.set("_attack_cooldown_remaining", 0.0)
	var focus_before := float(player.get("current_focus"))
	if not bool(player.call("_start_dodge")) or not bool(player.get("is_dodging")) \
			or not is_equal_approx(float(player.get("current_focus")), focus_before - 25.0):
		_fail("dodge does not spend exactly 25 Focus and enter its movement state")
		return
	var dodge_health := float(player.get("current_health"))
	if float(player.call("take_damage", 30.0, null)) != 0.0 \
			or float(player.get("current_health")) != dodge_health:
		_fail("dodge invulnerability does not reject incoming damage")
		return
	player.set("is_dodging", false)
	player.set("_invulnerability_remaining", 0.0)
	player.call("_set_blocking", false)
	player.call("_set_blocking", true)
	player.call("take_damage", 12.0, null)
	if float(player.get("_counter_ready_remaining")) <= 0.0:
		_fail("a hit inside the perfect-block window does not prime a counter")
		return
	progression.call("record_failed_attempt", "world_one.test_combat")
	progression.call("record_failed_attempt", "world_one.test_combat")
	var assist_prompt := player.get_node(
		"CombatHelpHUD/AdaptiveAssistancePrompt") as PanelContainer
	if assist_prompt == null or not assist_prompt.visible or bool(player.get("input_enabled")):
		_fail("two failures do not open the optional assistance prompt and pause control")
		return
	player.call("_enable_adaptive_assistance")
	if assist_prompt.visible or not bool(player.get("input_enabled")) \
			or not bool(progression.get("assist_settings").enabled):
		_fail("accepting assistance does not apply its saved setting and restore control")
		return
	progression.call("clear_progress")

	print("PLAYER_3D_COMBAT_TEST: PASS — combo, charge, dodge Focus, block, counter, hitbox and combat HUD are live")
	quit()
