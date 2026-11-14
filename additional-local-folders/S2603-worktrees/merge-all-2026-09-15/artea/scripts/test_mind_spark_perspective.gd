# Focused contract for the original dual-role Mind Spark presentation layer.
# Run with:
#   godot --headless --path artea --script res://scripts/test_mind_spark_perspective.gd
extends SceneTree

const PerspectiveScene := preload("res://scenes/mind_spark/mind_spark_perspective.tscn")
const Perspective := preload("res://scripts/mind_spark/mind_spark_perspective.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var alarm = PerspectiveScene.instantiate()
	var hope = PerspectiveScene.instantiate()
	alarm.configure_perspective(Perspective.PerspectiveKind.ALARM_SCIENCE, "alarm", "alarm_keys", {
		"left": &"mind_alarm_move_left", "right": &"mind_alarm_move_right",
		"forward": &"mind_alarm_move_forward", "back": &"mind_alarm_move_back",
		"interact": &"mind_alarm_interact", "ping": &"mind_alarm_ping",
	})
	hope.configure_perspective(Perspective.PerspectiveKind.HOPE_NATURE_MAGIC, "hope", "hope_keys", {
		"left": &"mind_hope_move_left", "right": &"mind_hope_move_right",
		"forward": &"mind_hope_move_forward", "back": &"mind_hope_move_back",
		"interact": &"mind_hope_interact", "ping": &"mind_hope_ping",
	})
	root.add_child(alarm)
	root.add_child(hope)
	await process_frame

	assert(alarm.role.role_id == "alarm", "left perspective owns the Alarm Lens role")
	assert(hope.role.role_id == "hope", "right perspective owns the Hope Lens role")
	assert(alarm.role.input_policy != hope.role.input_policy, "roles use distinct injectable input policies")
	assert(alarm.role.move_left_action != hope.role.move_left_action, "roles do not share movement actions")
	assert(alarm.camera != null and hope.camera != null, "each independently rendered perspective owns a camera")
	assert(alarm.get_node("PerspectiveHUD/Header/Box/Title").text.contains("SCIENCE"), "Alarm side is visibly science-tech")
	assert(hope.get_node("PerspectiveHUD/Header/Box/Title").text.contains("NATURE MAGIC"), "Hope side is visibly nature-magic")
	assert(alarm.get_node_or_null("ProceduralDressing") != null, "Alarm perspective builds mobile-safe dressing")
	assert(hope.get_node_or_null("ProceduralDressing") != null, "Hope perspective builds mobile-safe dressing")
	var alarm_environment: Environment = alarm.get_node("WorldEnvironment").environment
	var hope_environment: Environment = hope.get_node("WorldEnvironment").environment
	assert(alarm_environment != hope_environment, "each perspective owns an isolated Environment resource")
	assert(alarm_environment.background_color != hope_environment.background_color,
		"Hope configuration cannot recolor the Alarm environment")

	alarm.set_shared_anchor_active(true)
	assert(alarm.get_node("SharedAnchor").scale.y > hope.get_node("SharedAnchor").scale.y,
		"active anchor changes silhouette without leaking to the other perspective")
	assert(alarm.get_node("AnchorStatus").text == "ANCHOR READY",
		"active anchor state is written as text")
	alarm.set_bridge_integrated(0.5)
	assert(alarm.get_node("BridgeIndicator").visible and alarm.get_node("BridgeIndicator").scale.x > 0.4,
		"partial bridge progress has a visible shape consequence")
	assert(alarm.get_node("BridgeStatus").text.contains("50%"),
		"partial bridge progress is readable without colour")
	alarm.set_constellation_progress(2, 3)
	assert(alarm.get_node("PerspectiveHUD/ConstellationStatus").text.contains("2 / 3"),
		"constellation progress is exposed as exact text")
	assert(alarm.get_node("ConstellationLights").get_child(0).scale.x
		> alarm.get_node("ConstellationLights").get_child(2).scale.x,
		"completed constellation lights have a distinct silhouette")
	alarm.set_focus_mode(true)
	assert(alarm.get_node("PerspectiveHUD/FocusStatus").visible
		and alarm.camera_mode == Perspective.CameraMode.FIXED,
		"focus mode visibly steadies the camera")
	alarm.set_focus_mode(false)
	alarm.set_reduced_motion(true)
	assert(alarm.get_node("PerspectiveHUD/FocusStatus").text.contains("REDUCED MOTION"),
		"reduced motion is visibly confirmed")

	var interaction := {"role": ""}
	alarm.role_interaction_requested.connect(func(id: String) -> void: interaction["role"] = id)
	alarm.role.request_interaction()
	assert(interaction["role"] == "alarm", "interaction signal stays role-scoped")

	hope.set_solo_companion(true)
	assert(hope.role.companion_mode and not hope.role.input_enabled, "solo companion disables direct input")
	hope.command_companion(Vector3(1.0, 0.0, 0.0), true)
	assert(hope.role.companion_mode, "coordinator can issue an explicit solo command")

	var alarm_policy: String = alarm.role.input_policy
	var hope_policy: String = hope.role.input_policy
	alarm.swap_role_policy(hope)
	assert(alarm.role.input_policy == hope_policy and hope.role.input_policy == alarm_policy,
		"role swap exchanges control policies without swapping story identity")
	assert(alarm.role.role_id == "alarm" and hope.role.role_id == "hope", "role swap preserves perspective meaning")

	var role_source := FileAccess.get_file_as_string("res://scripts/mind_spark/mind_spark_role_controller.gd")
	for forbidden in ["attack", "health", "death", "countdown", "HTTPRequest", "JourneyState"]:
		assert(not role_source.to_lower().contains(forbidden.to_lower()), "role layer excludes %s coupling" % forbidden)
	assert(role_source.contains("command_solo") and role_source.contains("swap_input_policy"),
		"actor exposes solo fallback and role-swap seams")

	alarm.queue_free()
	hope.queue_free()
	print("Mind Spark perspectives: all checks passed")
	quit()
