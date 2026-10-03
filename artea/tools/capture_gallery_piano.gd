extends SceneTree

## Render the gallery grand piano on its own, away from the rotunda.
##
## The gallery scene pulls in the local LLM and the whole room, which is far
## more than is needed to look at one instrument -- this builds just the piano,
## a floor and some lights, and waits for several presented frames before
## reading the viewport back.
##
##   Godot --path artea --script res://tools/capture_gallery_piano.gd

const Piano := preload("res://scripts/gallery_piano.gd")

const SHOTS := [
	{"name": "three-quarter", "from": Vector3(2.5, 1.85, 2.5), "at": Vector3(0.0, 0.85, -0.9)},
	# Taken from the piano's own seated constants, so this preview is the view
	# the player actually gets rather than one that drifts from it.
	{"name": "keyboard", "from": Piano.SEAT_FOCUS + Piano.SEAT_VIEW, "at": Piano.SEAT_FOCUS},
	{"name": "side", "from": Vector3(-3.4, 1.35, -1.2), "at": Vector3(0.0, 0.80, -1.2)},
]


func _initialize() -> void:
	_run()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24.0, 24.0)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.13, 0.11, 0.10)
	floor_material.roughness = 0.35
	floor_mesh.material_override = floor_material
	world.add_child(floor_mesh)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.52, 0.66, 0.64)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.75)
	env.ambient_light_energy = 0.9
	environment.environment = env
	world.add_child(environment)

	var key_light := DirectionalLight3D.new()
	key_light.light_energy = 1.5
	world.add_child(key_light)
	key_light.rotation_degrees = Vector3(-48.0, -34.0, 0.0)

	var fill := OmniLight3D.new()
	fill.omni_range = 12.0
	fill.light_energy = 1.4
	world.add_child(fill)
	fill.position = Vector3(2.4, 2.6, 2.2)

	var piano: Node3D = Piano.new()
	world.add_child(piano)

	var camera := Camera3D.new()
	camera.fov = 52.0
	world.add_child(camera)
	camera.current = true

	var out_dir := "res://builds/piano"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	for shot: Dictionary in SHOTS:
		# Atomic: setting position and then look_at() leaves the aim computed
		# against the transform the camera had a moment earlier.
		var from: Vector3 = shot.from
		var at: Vector3 = shot.at
		camera.look_at_from_position(from, at, Vector3.UP)
		# Several presented frames: the first is often incomplete, and a
		# half-drawn frame reads back black.
		for _i in range(6):
			await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := "%s/piano_%s.png" % [out_dir, shot.name]
		image.save_png(path)
		print("wrote %s" % path)

	quit(0)
