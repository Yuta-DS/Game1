extends SceneTree

const Fit := preload("res://scripts/train_cab_sightline.gd")
const Seat := preload("res://scripts/train_driver_seat.gd")
const Glass := preload("res://scripts/train_front_windscreen.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and not failures.has(message):
		failures.append(message)
		push_error(message)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var railway := Node3D.new()
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	for i in 6:
		await process_frame
	railway.set_process(false)
	var train := railway.get_node("RainbowGalaxyTrain") as Node3D
	var detailed := train.get_node("BlenderCrownLineTrain") as Node3D
	var chair := train.get_node("DriverCaptainSeat") as Node3D
	_check(int(detailed.get_meta("replaced_driver_seat_pieces")) >= 25, "Remove the old chair including its leaf shell, not stack two seats")
	var imported := detailed.get_node("CrownLineRuntimeTexturedSurface") as MeshInstance3D
	var to_train := train.global_transform.affine_inverse() * imported.global_transform
	for surface in imported.mesh.get_surface_count():
		var material := imported.mesh.surface_get_material(surface)
		for part in Fit.components(imported.mesh.surface_get_arrays(surface), to_train):
			_check(not Seat.is_legacy_component(part.bounds, material.resource_name.to_lower()), "No old driver-seat geometry remains")
	var cushion := chair.get_node("RainbowSeatCushion") as MeshInstance3D
	var box := cushion.transform * cushion.mesh.get_aabb()
	_check(absf(box.end.y - 3.15) < .001, "Cushion matches existing seated hip/thigh height")
	_check(box.has_point(Vector3(-.309, 3.03, -15.007)) and box.has_point(Vector3(.309, 3.03, -15.007)), "Both measured seated hips sit over the cushion")
	_check(box.position.z > -15.5, "Cushion ends before the bent lower legs")
	var back := chair.get_node("ReclinedBackrest/GoldBackSurround") as MeshInstance3D
	var back_pose := train.global_transform.affine_inverse() * back.global_transform
	_check((back_pose * back.mesh.get_aabb()).position.y > 3.55, "Backrest leaves the fox tail clear")
	var fabric_count := 0
	for part: MeshInstance3D in chair.find_children("*", "MeshInstance3D", true, false):
		if part.material_override is ShaderMaterial:
			fabric_count += 1
			_check(part.material_override.get_meta("rainbow_colour_count", 0) == 7, "Keep seven-colour animated seat upholstery")
	_check(fabric_count == 4, "Cushion, contoured back and two arm pads use rainbow fabric")
	_check(chair.get_meta("chair_style") == "aurora_snowflake_captain", "Install the new captain-chair style")
	var back_pad := chair.get_node("ReclinedBackrest/RainbowContouredBackPad") as MeshInstance3D
	_check((back_pad.material_override as ShaderMaterial).shader.resource_path == "res://shaders/train_captain_upholstery.gdshader",
		"Driver upholstery uses the new quilted aurora shader")
	_check(chair.find_children("RainbowBackPad_*", "", true, false).is_empty(), "Replace rather than stack the three old back pads")
	var tail_volume := AABB(Vector3(-.65, 3.20, -14.73), Vector3(1.30, .35, .55))
	var triangle_count := 0
	for part: MeshInstance3D in chair.find_children("*", "MeshInstance3D", true, false):
		var pose := train.global_transform.affine_inverse() * part.global_transform
		var vertices := part.mesh.get_faces()
		triangle_count += vertices.size() / 3
		for vertex in vertices:
			_check(not tail_volume.has_point(pose * vertex), "Keep the central tail-clearance volume free of chair geometry")
	_check(triangle_count < 40000, "Chair stays within a bounded Web geometry budget")
	var pan := chair.get_node("GoldSeatPan") as MeshInstance3D
	for side in [-1, 1]:
		var arm := chair.get_node("SweptArmSupport_%d" % side) as MeshInstance3D
		var tray := chair.get_node("GoldArmTray_%d" % side) as MeshInstance3D
		var arm_bounds := arm.transform * arm.mesh.get_aabb()
		_check(arm_bounds.intersects(pan.transform * pan.mesh.get_aabb()), "Curved arm supports connect into the seat pan")
		_check(arm_bounds.intersects(tray.transform * tray.mesh.get_aabb()), "Curved arm supports meet their arm trays")
		_check(_is_closed_mesh(arm.mesh), "Curved arm supports have continuous, closed joints")
		_check(_is_closed_mesh((chair.get_node("BackSupport_%d" % side) as MeshInstance3D).mesh),
			"Back supports have no open seams between curve segments")
	_check(_is_closed_mesh((chair.get_node("CushionGoldPiping") as MeshInstance3D).mesh),
		"Cushion piping is one closed continuous sweep")
	var badge := chair.get_node("ReclinedBackrest/InsetSnowflakeMedallion") as MeshInstance3D
	var badge_bounds := badge.transform * badge.mesh.get_aabb()
	_check(badge_bounds.intersects(back_pad.mesh.get_aabb()), "Snowflake badge is embedded in the backrest, not floating")
	var snowflake := chair.get_node("ReclinedBackrest/PearlSnowflakeInlay") as MeshInstance3D
	_check(snowflake.mesh.get_aabb().intersects(badge_bounds), "Snowflake inlay touches its medallion")
	for vertex in snowflake.mesh.get_faces():
		_check(Vector2(vertex.x, vertex.y - .58).length() < .16, "All six snowflake arms fit within the medallion")
	_check(railway.get("DRIVER_SEAT") == Vector3(0, 3.55, -15.05), "Driver anchor stays unchanged")
	var assembly := train.get_node("DriverFrontWindscreen") as Node3D
	var frame := assembly.get_node("ContinuousGoldFrame") as MeshInstance3D
	var seal := assembly.get_node("RecessedRubberSeal") as MeshInstance3D
	var pane := assembly.get_node("SingleClearPane") as MeshInstance3D
	_check(not assembly.has_node("SatinFrameFace"), "The whole visible surround is gold, not a dark frame with a gold stripe")
	var gold := frame.material_override as StandardMaterial3D
	_check(gold.albedo_color.r > .85 and gold.albedo_color.g > .60 and gold.albedo_color.b < .5, "Warm gold frame")
	var frame_points: PackedVector3Array = frame.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var seal_points: PackedVector3Array = seal.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var glass_points: PackedVector3Array = pane.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for p in Glass.outline(Glass.FRAME_WIDTH):
		_check(_nearest(frame_points, Glass.surface_point(p, -Glass.DEPTH * .5)) < .00001, "Gold follows the full curved inner boundary")
		_check(_nearest(seal_points, Glass.surface_point(p, -.0275)) < .00001, "Seal touches the frame, without perimeter gaps")
	for p in Glass.outline(Glass.FRAME_WIDTH + Glass.SEAL_WIDTH):
		_check(_nearest(glass_points, Glass.surface_point(p)) < .00001, "Pane ends exactly at the curved seal")
	var middle := Vector2(0, 5.0)
	_check(Glass.surface_point(Vector2(3.8, 5)).z - Glass.surface_point(middle).z > .32, "Glass visibly wraps around the cab")
	for p in glass_points:
		_check(p.y >= Glass.BOTTOM and p.y <= Glass.TOP and p.z >= -19.8 and p.z < -18.45, "Glass stays inside the cab opening")
	var crowns := train.get_node("RainbowGoldAccentLayout/SnowflakeRoofCrowns") as Node3D
	for section in 3:
		var y_min := INF
		var y_max := -INF
		var branch_count := 0
		var arm_count := 0
		for part: MeshInstance3D in crowns.get_children():
			if not String(part.name).begins_with("SnowflakeRoof_%02d_" % section):
				continue
			if String(part.name).contains("_CurvedIceArm_") or String(part.name).contains("_Branch_"):
				var bounds := part.transform * part.mesh.get_aabb()
				y_min = minf(y_min, bounds.position.y)
				y_max = maxf(y_max, bounds.end.y)
				_check(absf(part.basis.z.y) < .08, "Snowflake segments are nearly level")
				_check((part.material_override as StandardMaterial3D).emission_energy_multiplier <= .16, "Low emission preserves visible snowflake details")
				if String(part.name).contains("_Branch_"):
					branch_count += 1
				else:
					arm_count += 1
		_check(y_max - y_min < .305, "Snowflake relief including thickness stays under 31 cm")
		_check(branch_count == 24 and arm_count == 18, "All six arms and twenty-four fine branches remain clear on each roof")
	var stem := crowns.get_node("SnowflakeRoof_02_HaloStem") as MeshInstance3D
	var stem_box := stem.transform * stem.mesh.get_aabb()
	_check(stem_box.position.y < 8.45 and stem_box.end.y > 9.4, "Lowered snowflake remains connected to the existing celestial ornament")
	print("TRAIN_CAB_REDESIGN: %s checks=%d failures=%d replaced_seat_pieces=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), detailed.get_meta("replaced_driver_seat_pieces")])
	quit(0 if failures.is_empty() else 1)

func _nearest(points: PackedVector3Array, target: Vector3) -> float:
	var distance := INF
	for point in points:
		distance = minf(distance, point.distance_to(target))
	return distance

func _is_closed_mesh(mesh: Mesh) -> bool:
	var points: Dictionary = {}
	var edges: Dictionary = {}
	var faces := mesh.get_faces()
	for i in range(0, faces.size(), 3):
		var ids: Array[int] = []
		for corner in 3:
			var vertex := faces[i + corner]
			if not points.has(vertex):
				points[vertex] = points.size()
			ids.append(points[vertex])
		for edge in 3:
			var a := ids[edge]
			var b := ids[(edge + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			edges[key] = edges.get(key, 0) + 1
	for count in edges.values():
		if count != 2:
			return false
	return not edges.is_empty()
