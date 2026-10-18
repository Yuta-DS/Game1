extends SceneTree


const VILLAGER_SCENES := [
	"res://scenes/entities/villager_barbarian.tscn",
	"res://scenes/entities/villager_rogue.tscn",
	"res://scenes/entities/villager_rogue_hooded.tscn",
	"res://scenes/entities/villager_father.tscn",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene_path in VILLAGER_SCENES:
		var scene := load(scene_path) as PackedScene
		if scene == null:
			_fail("could not load " + scene_path)
			return
		var villager := scene.instantiate() as Node3D
		root.add_child(villager)
		var surface_count := 0
		for node in villager.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			for surface_index in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
				if material == null or material.albedo_texture == null:
					_fail("missing character color texture on %s/%s" % [scene_path, mesh_instance.name])
					return
				surface_count += 1
		if surface_count == 0:
			_fail("no textured surfaces found in " + scene_path)
			return
		villager.queue_free()
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 3:
		await physics_frame
	for character_name in ["Rogue", "Barbarian"]:
		var character := hub.get_node(character_name)
		var surface_count := 0
		for node in character.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			for surface_index in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
				if material == null or material.albedo_texture == null:
					_fail("Hub %s still has a white, untextured surface: %s" % [character_name, mesh_instance.name])
					return
				surface_count += 1
		if surface_count == 0:
			_fail("Hub " + character_name + " has no visible textured surface")
			return
	print("HUB_VILLAGER_TEXTURES: PASS — visible hub NPCs and villager scenes retain their color textures")
	quit()


func _fail(message: String) -> void:
	push_error("HUB_VILLAGER_TEXTURES: " + message)
	quit(1)
