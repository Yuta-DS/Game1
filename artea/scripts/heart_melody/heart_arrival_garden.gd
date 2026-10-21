extends Node3D

const Art = preload("res://scripts/heart_melody/heart_art.gd")
const NoteShader = preload("res://shaders/heart_fountain_notes.gdshader")
const CENTER := Vector3(1787.4, 0.22, 7943.7)
var fountain_position := CENTER

func _ready() -> void:
	var fountain := Node3D.new()
	fountain.name = "MusicalFountain"
	fountain.position = fountain_position
	add_child(fountain)
	Art.cone(fountain, Vector3(0, 0.4, 0), 19, 19, 0.8, Color("c9afbd"), true, 24)
	Art.cone(fountain, Vector3(0, 1.1, 0), 16.5, 17.5, 1.1, Color("f2d8cf"), true, 24)
	Art.cone(fountain, Vector3(0, 1.72, 0), 15.8, 15.8, 0.12, Color("67cbd4"), false, 24)
	Art.cone(fountain, Vector3(0, 2.0, 0), 5.5, 4.0, 3.0, Color("b99bac"), true, 12)
	Art.cone(fountain, Vector3(0, 4.1, 0), 8.5, 8.5, 0.7, Color("f2d8cf"), false, 20)
	Art.cone(fountain, Vector3(0, 4.5, 0), 7.8, 7.8, 0.12, Color("7bd9e0"), false, 20)
	for index in 7:
		var angle := float(index) * TAU / 7.0
		var height := 7.0 + 5.0 * (0.5 + 0.5 * sin(angle))
		Art.cone(fountain, Vector3(cos(angle) * 3.5, 4.5 + height * 0.5, sin(angle) * 3.5),
			0.48, 0.48, height, Color("e7c27f"), false, 8)
	_build_water_arcs(fountain)
	_build_notes(fountain)
	var sound := AudioStreamPlayer3D.new()
	sound.name = "FountainMusic"
	sound.position = Vector3.UP * 4
	# Natural distance attenuation brings the music forward on approach.
	sound.unit_size = 12.0
	sound.max_distance = 72.0
	sound.volume_db = -12.0
	sound.max_db = -10.0
	sound.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	var path := "res://assets/audio/music_circle/fountain_theme.wav"
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = 22050 * 16
		sound.stream = stream
		sound.autoplay = true
	fountain.add_child(sound)

func _build_water_arcs(parent: Node3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for jet in 8:
		var angle := float(jet) * TAU / 8.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		var side := direction.cross(Vector3.UP) * 0.14
		for segment in 16:
			var t0 := float(segment) / 16.0
			var t1 := float(segment + 1) / 16.0
			var p0 := direction * (4.0 + t0 * 10.0) + Vector3.UP * (5.0 + sin(t0 * PI) * 8.0 - t0 * 3.2)
			var p1 := direction * (4.0 + t1 * 10.0) + Vector3.UP * (5.0 + sin(t1 * PI) * 8.0 - t1 * 3.2)
			for point in [p0 - side, p1 - side, p1 + side, p0 - side, p1 + side, p0 + side]:
				surface.add_vertex(point)
	surface.generate_normals()
	var arc := Art.mesh(parent, surface.commit(), Vector3.ZERO, Color("8ae0e5"))
	arc.name = "WaterArcs"
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("8ae0e5")
	water.emission_enabled = true
	water.emission = Color("65bfcf")
	water.emission_energy_multiplier = 0.45
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	arc.material_override = water

func _build_notes(parent: Node3D) -> void:
	var surface := SurfaceTool.new()
	var head := SphereMesh.new()
	head.radius = 0.65
	head.height = 0.75
	head.radial_segments = 8
	head.rings = 4
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.append_from(head, 0, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	var stem := BoxMesh.new()
	stem.size = Vector3(0.20, 2.7, 0.20)
	surface.append_from(stem, 0, Transform3D(Basis.IDENTITY, Vector3(0.48, 1.25, 0)))
	var flag := BoxMesh.new()
	flag.size = Vector3(1.25, 0.28, 0.20)
	surface.append_from(flag, 0, Transform3D(Basis(Vector3.FORWARD, -0.35), Vector3(1, 2.4, 0)))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = surface.commit()
	multi.instance_count = 28
	for index in multi.instance_count:
		multi.set_instance_transform(index, Transform3D.IDENTITY)
		multi.set_instance_custom_data(index, Color(float(index) / 28.0, float(index % 3) / 2.0, 0, 1))
	var notes := MultiMeshInstance3D.new()
	notes.name = "SkywardMusicNotes"
	notes.multimesh = multi
	notes.custom_aabb = AABB(Vector3(-32, 0, -32), Vector3(64, 95, 64))
	var material := ShaderMaterial.new()
	material.shader = NoteShader
	notes.material_override = material
	parent.add_child(notes)
