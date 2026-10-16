extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("CROWN_TRAIN_SOFT_SMOKE_WAKE_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var world := Node3D.new()
	world.name = "ArtCastleFloatingWorld"
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	world.add_child(player)
	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	for _frame in 10:
		await process_frame

	var train := railway.get_node_or_null("RainbowGalaxyTrain") as Node3D
	var vfx := train.get_node_or_null(
		"DirectionalRainbowMovementVFX") as Node3D if train != null else null
	var smoke := vfx.get_node_or_null(
		"RainbowAuroraSmokeWake") as GPUParticles3D if vfx != null else null
	if smoke == null:
		_fail("soft rainbow smoke wake was not added to the live train")
		return
	if not vfx.find_children("RainbowWakeRibbon_*", "MeshInstance3D", true, false).is_empty():
		_fail("the old rigid rainbow line meshes are still present")
		return
	var state: Dictionary = railway.call("get_directional_vfx_state")
	if String(state.wake_style) != "soft_rainbow_aurora_smoke" \
			or bool(state.has_hard_line_ribbons) \
			or not bool(state.smoke_wake_available):
		_fail("directional VFX state does not identify the line-free smoke design")
		return
	var smoke_motion := smoke.process_material as ParticleProcessMaterial
	var smoke_ramp := smoke_motion.color_ramp as GradientTexture1D \
		if smoke_motion != null else null
	if smoke.amount > 140 or smoke.fixed_fps > 30 or smoke.local_coords \
			or smoke_ramp == null or smoke_ramp.gradient.colors.size() != 8 \
			or smoke_ramp.gradient.colors[-1].a > .01:
		_fail("smoke wake is not Web-bounded or lacks its rainbow fade")
		return
	for colour_index in 7:
		var colour: Color = smoke_ramp.gradient.colors[colour_index]
		var brightest := maxf(colour.r, maxf(colour.g, colour.b))
		var darkest := minf(colour.r, minf(colour.g, colour.b))
		if brightest < .90 or brightest - darkest < .55 or colour.a < .60:
			_fail("smoke wake colour %d is not bright, saturated rainbow" % colour_index)
			return
	railway.set_process(false)
	for _frame in 12:
		railway.call("_update_directional_movement_vfx",
			1.0 / 60.0, Vector3(0.0, 0.0, -0.72))
	state = railway.call("get_directional_vfx_state")
	if not bool(state.emitting) or not bool(state.smoke_wake_emitting):
		_fail("soft smoke does not emit with forward train motion")
		return
	for _frame in 20:
		railway.call("_update_directional_movement_vfx",
			1.0 / 60.0, Vector3.ZERO)
	state = railway.call("get_directional_vfx_state")
	if bool(state.emitting) or bool(state.smoke_wake_emitting):
		_fail("soft smoke continues emitting after the train stops")
		return
	print("CROWN_TRAIN_SOFT_SMOKE_WAKE_TEST: PASS — rounded rainbow aurora smoke replaces every rigid wake line")
	quit()
