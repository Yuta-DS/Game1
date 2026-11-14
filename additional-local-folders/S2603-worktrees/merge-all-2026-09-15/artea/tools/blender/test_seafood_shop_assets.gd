extends SceneTree
## Run from an empty Godot project to check GLBs without importing the whole game.
## --script /absolute/path/to/this.gd -- /absolute/path/to/artea

var project_dir: String
var walker: CharacterBody3D

func _init() -> void:
	project_dir = OS.get_cmdline_user_args()[0]
	call_deferred("_run")

func _model(relative_path: String, at: Vector3, yaw: float, size: float) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(project_dir.path_join(relative_path), state) != OK:
		push_error("GLB load failed: " + relative_path)
		quit(1)
		return null
	var model := document.generate_scene(state) as Node3D
	model.position = at
	model.rotation.y = yaw
	model.scale = Vector3.ONE * size
	root.add_child(model)
	return model

func _collisions(model: Node3D) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var extras: Dictionary = mesh.get_meta("extras", {})
		var solid: bool = extras.get("harbour_collision", false)
		for prefix in ["LandingPlank", "JettyPlank", "BerthPlank", "JettySubdeck", "BerthSubdeck", "ShoreApron", "FishMarketCounter"]:
			solid = solid or mesh.name.begins_with(prefix)
		if not solid:
			continue
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = mesh.mesh.create_trimesh_shape()
		body.add_child(shape)
		mesh.add_child(body)

func _walk(point: Vector3) -> bool:
	for frame in 300:
		await physics_frame
		var delta := point - walker.position
		delta.y = 0
		if delta.length() < .12:
			return true
		walker.velocity = delta.normalized() * 5 + Vector3.DOWN * 3
		walker.move_and_slide()
		if walker.position.y < 1.5:
			push_error("Gap at " + str(walker.position))
			return false
	push_error("Blocked at %s toward %s" % [walker.position, point])
	return false

func _run() -> void:
	var harbour := _model("assets3D/coastal_harbour/artea_harbour.glb", Vector3(38, .9, 184), PI, 1.5)
	var link := _model("assets3D/coastal_harbour/artea_watchtower_link.glb", Vector3(19.9201, 0, 189.907), 0, 1)
	if harbour == null or link == null:
		return
	for name in ["SeafoodShopBuilding", "SeafoodShopLettering", "ShopCrabDisplay", "ShopOysterDisplay_0", "ShopFishDisplay_0", "ShopStorageCrate_0", "ShopBasket_0"]:
		if harbour.find_child(name, true, false) == null:
			push_error("Missing shop detail: " + name)
			quit(1)
			return
	_collisions(harbour)
	for label_name in ["SeafoodShopLettering", "CatchLabel_FISH", "CatchLabel_CRAB", "CatchLabel_OYSTERS"]:
		var lettering := harbour.find_child(label_name, true, false) as MeshInstance3D
		var lettering_data: Dictionary = lettering.get_meta("extras", {})
		if not str(lettering_data.get("lettering_style", "")).contains("hand-painted"):
			push_error("Sign must use the authored brush lettering: " + label_name)
			quit(1)
			return
	var shop := harbour.find_child("SeafoodShopBuilding", true, false) as MeshInstance3D
	var provenance: Dictionary = shop.get_meta("extras", {})
	var office := harbour.find_child("VillageHarbourOffice_building_home_A_red", true, false) as MeshInstance3D
	var sign := harbour.find_child("SeafoodShopLettering", true, false) as MeshInstance3D
	var harbour_title := harbour.find_child("HarbourTitle", true, false) as MeshInstance3D
	var harbour_accent := harbour.find_child("HarbourTitleAccent", true, false) as MeshInstance3D
	var title_data: Dictionary = harbour_title.get_meta("extras", {}) if harbour_title != null else {}
	var accent_data: Dictionary = harbour_accent.get_meta("extras", {}) if harbour_accent != null else {}
	if harbour_title == null or harbour_accent == null or title_data.get("sign_text", "") != "Artéa" \
			or title_data.get("lettering_source", "") != "res://assets/Fonts/NewFont-Artea.otf" \
			or not str(title_data.get("style_reference", "")).contains("Milo statue") \
			or not str(accent_data.get("lettering_component", "")).contains("Milo landmark diamond"):
		push_error("Port title must use the exact Artéa display face from the Milo landmark")
		quit(1)
		return
	var shop_bounds := shop.global_transform * shop.get_aabb()
	if provenance.get("front_direction", "") != "village" or office.get_meta("extras", {}).get("front_direction", "") != "village" or sign.global_position.z >= shop_bounds.position.z:
		push_error("Shop sign/counter must be north of the building, facing the village like the house")
		quit(1)
		return
	var material := shop.mesh.surface_get_material(0) as StandardMaterial3D
	if provenance.get("village_source", "") != "building_home_B_red.gltf" or material == null or material.albedo_texture == null:
		push_error("Shop must retain the real village house geometry and original texture atlas")
		quit(1)
		return
	_collisions(link)
	walker = CharacterBody3D.new()
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .7
	collider.shape = capsule
	collider.position.y = 1
	walker.add_child(collider)
	walker.position = Vector3(38, 1.85, 178.5)
	root.add_child(walker)
	for frame in 10:
		await physics_frame
	var route: Array[Vector3] = [Vector3(38, 0, 173.7), Vector3(43.4, 0, 173.7),
		Vector3(38, 0, 173.7), Vector3(26.5, 0, 173.7), Vector3(24, 0, 173.7),
		Vector3(38, 0, 173.7), Vector3(38, 0, 180.7), Vector3(34, 0, 180.7),
		Vector3(30, 0, 180.7), Vector3(34, 0, 180.7), Vector3(38, 0, 180.7),
		Vector3(38, 0, 193), Vector3(26.2, 0, 193)]
	for degrees in range(30, 391, 15):
		var angle := deg_to_rad(float(degrees))
		route.append(link.position + Vector3(cos(angle) * 6.35, 0, sin(angle) * 6.35))
	route.append(Vector3(32, 0, 193))
	for point in route:
		if not await _walk(point):
			quit(1)
			return
	print("SEAFOOD_SHOP_ASSETS: PASS — stocked shop, tagged collision, 1.4m customer approach, bridge and terrace circuit")
	quit()
