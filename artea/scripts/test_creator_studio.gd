extends SceneTree

## Creator studio: the player grows on the raised floor, is offered painting
## beside an easel, and is back to normal size once off the floor.

const CREATOR := Vector3(600.0, 0.0, 1640.0)


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("CREATOR_STUDIO_TEST: %s" % message)
	quit(1)


func _settle(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame


func _run() -> void:
	var world := (load("res://scenes/art_castle_floating_world.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var player := world.get_node_or_null("Player3D") as CharacterBody3D
	var studio := world.get_node_or_null("CreatorsLightQuestLandmarks/CreatorStudio")
	if player == null or studio == null:
		_fail("player or CreatorStudio missing")
		return
	if world.get_node_or_null("EastObservatory") != null:
		_fail("east observatory is still standing")
		return
	if not world.find_children("*PortalFrame", "", true, false).filter(
			func(n): return CREATOR.distance_to(world.to_local(n.global_position)) < 200.0).is_empty():
		_fail("portal frames remain in the studio")
		return

	# Beside the first easel (offset -45, 2, -20), in front of its canvas.
	player.global_position = world.to_global(CREATOR + Vector3(-45.0, 3.2, -40.0))
	await _settle(1.5)
	if not bool(studio.call("is_player_big")) \
			or not is_equal_approx(float(player.call("get_size_multiplier")), 8.0):
		_fail("player did not grow on the studio floor (x%s)" % player.call("get_size_multiplier"))
		return
	if not bool(studio.call("is_paint_prompt_visible")):
		_fail("no paint prompt beside an easel")
		return

	# The grown fox's capsule grows too, so it stops at the furniture.
	for target in [["EaselCollision", Vector3(-80.0, 3.2, -20.0)], ["TableCollision", Vector3(-90.0, 3.2, 60.0)]]:
		player.global_position = world.to_global(CREATOR + target[1])
		await physics_frame
		await physics_frame
		var hit := player.move_and_collide(Vector3(40.0, 0.0, 0.0))
		if hit == null or str(hit.get_collider().name) != target[0]:
			_fail("big player walked through %s (hit %s)" % [target[0],
				"nothing" if hit == null else str(hit.get_collider().name)])
			return

	# A finished drawing goes onto that easel's (otherwise blank) canvas.
	var canvas := world.get_node("CreatorsLightStudio/PaintingEasel_00/Canvas") as MeshInstance3D
	var canvas_material := canvas.material_override as ShaderMaterial
	if canvas_material.get_shader_parameter("has_art") == true:
		_fail("easel canvas is not blank before painting")
		return
	var drawing := Image.create(64, 48, false, Image.FORMAT_RGBA8)
	drawing.fill(Color.RED)
	studio.call("_show_on_easel", 0, drawing)
	if canvas_material.get_shader_parameter("has_art") != true:
		_fail("drawing was not shown on the easel canvas")
		return

	player.global_position = world.to_global(CREATOR + Vector3(-150.0, 1.2, 60.0))
	await _settle(1.5)
	if bool(studio.call("is_player_big")) \
			or not is_equal_approx(float(player.call("get_size_multiplier")), 1.0):
		_fail("player did not shrink back off the studio floor")
		return
	if bool(studio.call("is_paint_prompt_visible")):
		_fail("paint prompt still showing off the floor")
		return

	# Flowers are solid: walk at the first plant from 15 m away.
	var garden := world.get_node("CreatorsLightStudio/StudioGardenCollision") as StaticBody3D
	var plant := garden.get_child(0) as CollisionShape3D
	var plant_ground := Vector3(plant.global_position.x, world.to_global(CREATOR).y + 1.2, plant.global_position.z)
	var toward := (world.to_global(CREATOR) - plant_ground)
	toward.y = 0.0
	player.global_position = plant_ground + toward.normalized() * 15.0
	await physics_frame
	await physics_frame
	var flower_hit := player.move_and_collide(-toward.normalized() * 15.0)
	if flower_hit == null or flower_hit.get_collider() != garden:
		_fail("player walked through a flower")
		return
	print("CREATOR_STUDIO_TEST: PASS — grows x8 on the floor, bumps easel and table, paint prompt, normal size off it, flowers solid")
	quit(0)
