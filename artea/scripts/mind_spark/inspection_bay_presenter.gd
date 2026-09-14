extends Node3D
## Detailed Blender geometry reflects persistent state; it never owns puzzle rules.
const Trace := preload("res://scripts/mind_spark/inspection_trace.gd")
var station: QuestObjectBase
var model: Node3D
var screens: Array[MeshInstance3D] = []
var captions: Array[Label3D] = []
var previous := ""
var trace_material: StandardMaterial3D
var shutters: Array[MeshInstance3D] = []

func configure(source: QuestObjectBase, world: MindSparkWorldOne) -> void:
	station = source
	name = "ProductionInspectionBay"
	model = preload("res://scripts/mind_spark/research_bay_mount.gd").mount(self,station,world,
		"res://assets3D/mind_spark/unfinished_light/inspection_bay/inspection_bay.glb",2.5)
	trace_material = StandardMaterial3D.new()
	trace_material.albedo_color = Color.WHITE
	trace_material.vertex_color_use_as_albedo = true
	trace_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trace_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 3:
		var screen := MeshInstance3D.new()
		screen.name = "EvidenceTrace%d" % i
		screen.position = Vector3(-1.55 + i * 1.55, 1.71, -.328)
		screen.material_override = trace_material
		add_child(screen)
		screens.append(screen)
		var caption := Label3D.new()
		caption.name = "ChannelLabel%d" % i
		caption.text = Trace.TITLES[i]
		caption.font_size = 36
		caption.pixel_size = .003
		caption.position = Vector3(-1.55 + i * 1.55, 2.4, -.30)
		caption.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		caption.modulate = Color("f8ebcd")
		add_child(caption)
		captions.append(caption)
		if i > 0:
			var shutter := MeshInstance3D.new()
			shutter.name = "ObservableShutter%d" % i
			var mesh := BoxMesh.new()
			mesh.size = Vector3(.28,.26,.025)
			shutter.mesh = mesh
			shutter.position = Vector3(-1.55 + i * 1.55 + .42,1.78,-.30)
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("d7bc79")
			material.roughness = .5
			shutter.material_override = material
			add_child(shutter)
			shutters.append(shutter)
	var title := Label3D.new()
	title.text = "THE EVIDENCE WORKSHOP"
	title.font_size = 40
	title.pixel_size = .0025
	title.position = Vector3(0,4.58,1.061)
	add_child(title)
	_update()

func _process(delta: float) -> void:
	if not is_instance_valid(station): return
	var settings: Array = station.current_state.get("adjustments", [0,0,0])
	for i in 3:
		var control := model.get_node_or_null("Control%d" % i) as Node3D
		if control != null: control.rotation.y = lerp_angle(control.rotation.y, int(settings[i]) * PI * .5, minf(1, delta * 12))
	_update()

func _update() -> void:
	var settings: Array = station.current_state.get("adjustments", [0,0,0])
	var found: Array = station.current_state.get("observations", [false,false,false])
	var signature := str(settings) + str(found)
	if signature == previous: return
	previous = signature
	for i in 3:
		screens[i].mesh = _trace_mesh(i,int(settings[i]))
		captions[i].text = Trace.TITLES[i] + (" ✓" if found[i] else "")
		var indicator := model.get_node_or_null("SavedLamp%d" % i) as Node3D
		if indicator != null: indicator.visible = bool(found[i])
		if i > 0:
			shutters[i-1].position.y = 2.1 if Trace.shutter_open(i,int(settings[i])) else 1.78
	var carriage := model.get_node_or_null("FocusCarriage") as Node3D
	if carriage != null: carriage.position.x = -.10 + float(settings[0]) * .07
	var wheel := model.get_node_or_null("ValveWheel") as Node3D
	if wheel != null: wheel.rotation.z = int(settings[2]) * PI * .5
	var drum := model.get_node_or_null("RecorderDrum") as Node3D
	if drum != null: drum.rotation.y = int(settings[1]) * PI * .5

func _trace_mesh(channel: int, setting: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_color(Color("a4ead4"))
	var points := Trace.series(channel,setting)
	var ghosts := 1 if Trace.clarity(channel,setting) == 1 else 3
	for ghost in ghosts:
		var offset := (ghost - (ghosts-1)*.5) * .045
		for i in range(points.size()-1):
			var a := Vector3(points[i].x - .5, points[i].y * .55 + offset, 0)
			var b := Vector3(points[i+1].x - .5, points[i+1].y * .55 + offset, 0)
			var width := Vector3(0,.008,0)
			for v in [a-width,b-width,b+width,a-width,b+width,a+width]: surface.add_vertex(v)
	var marker := Trace.event_marker(channel,setting)
	if marker >= 0:
		surface.set_color(Color("f4cd82"))
		var x := marker - .5
		for v in [Vector3(x-.005,0,0),Vector3(x+.005,0,0),Vector3(x+.005,.55,0),Vector3(x-.005,0,0),Vector3(x+.005,.55,0),Vector3(x-.005,.55,0)]: surface.add_vertex(v)
	surface.generate_normals()
	return surface.commit()
