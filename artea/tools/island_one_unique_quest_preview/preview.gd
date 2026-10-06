extends Node3D

const OUTPUT := "/Users/davidsovann/S2603/artea/artifacts/island_one_quest_hierarchy_fixed.png"

var ivory := material(Color("f4ead5"),.72,0.0)
var ivory_inset := material(Color("d8c9aa"),.86,0.0)
var brass := material(Color("b9842e"),.32,.72)
var gold := material(Color("ffd979"),.24,.62,Color("8a5311"),1.1)
var teal := material(Color("176d70"),.42,.48)
var glass := material(Color("70e0d2"),.16,.22,Color("2ab8ad"),1.8)
var lavender := material(Color("8a73bd"),.45,.25)


func _ready() -> void:
	_build_environment()
	var stations := [
		["01  REFRACT",0], ["02  TUNE",1], ["03  BALANCE",2],
		["04  COMPARE",3], ["05  COLLECT",4],
		["06  FACT",5], ["07  POSSIBILITY",6], ["08  UNSURE",7],
		["09  REFRAME",8], ["10  CHOOSE HOPE",9]
	]
	for i in stations.size():
		var row := 0 if i < 5 else 1
		var column := i if row == 0 else i-5
		_build_station(Vector3((column-2)*5.5,0,float(row)*-8.0),stations[i][0],stations[i][1])
	_build_route()
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	var image := get_viewport().get_texture().get_image()
	image.save_png(OUTPUT)
	print("ISLAND_ONE_UNIQUE_QUEST_PREVIEW: ",OUTPUT)
	get_tree().quit()


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("b9dce6")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("fff0d5")
	settings.ambient_light_energy=.72
	settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.environment=settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-28,0)
	sun.light_color=Color("ffe2ad")
	sun.light_energy=1.15
	sun.shadow_enabled=true
	add_child(sun)
	var rim := add_cylinder(self,Vector3(0,-.72,-4),18.5,1.0,brass,48)
	rim.scale.z=.61
	var deck := add_cylinder(self,Vector3(0,-.42,-4),17.9,.9,ivory,48)
	deck.scale.z=.60
	var title := add_label(self,"ISLAND ONE • FUNCTIONAL QUEST HIERARCHY",Vector3(0,7.8,-10.5),Color("214f5c"),58)
	title.outline_size=7
	var subtitle := add_label(self,"one silhouette = one action  •  repeated parts only form one labelled instrument",Vector3(0,6.8,-10.5),Color("8a5d25"),27)
	subtitle.outline_size=4
	var camera := Camera3D.new()
	camera.position=Vector3(0,18.5,29.5)
	camera.fov=38
	camera.look_at_from_position(camera.position,Vector3(0,2,-4),Vector3.UP)
	add_child(camera)
	camera.make_current()


func _build_route() -> void:
	for row in 2:
		add_box(self,Vector3(0,.02,float(row)*-8.0+1.85),Vector3(25,.08,.28),brass)
	for i in 10:
		var row := 0 if i < 5 else 1
		var column := i if row == 0 else i-5
		add_sphere(self,Vector3((column-2)*5.5,.1,float(row)*-8.0+1.85),Vector3.ONE*.16,gold)


func _build_station(at: Vector3, title: String, kind: int) -> void:
	var root := Node3D.new()
	root.position=at
	add_child(root)
	add_box(root,Vector3(0,.18,0),Vector3(3.9,.36,2.6),ivory)
	add_box(root,Vector3(0,.42,0),Vector3(3.4,.16,2.2),brass)
	add_cylinder(root,Vector3(0,1.45,0),1.05,2.0,teal,12)
	add_torus(root,Vector3(0,.55,0),.92,1.14,brass)
	add_torus(root,Vector3(0,2.42,0),.92,1.14,brass)
	for side in [-1,1]:
		add_box(root,Vector3(side*1.22,1.45,0),Vector3(.24,1.7,.36),ivory)
	add_sphere(root,Vector3(0,1.52,-1.08),Vector3(.34,.34,.16),glass)
	_build_icon(root,kind)
	var plate := add_box(root,Vector3(0,.52,1.46),Vector3(3.25,.56,.16),ivory_inset)
	plate.rotation.x=deg_to_rad(-12)
	var label := add_label(root,title,Vector3(0,.58,1.57),Color("214f5c"),30)
	label.outline_size=2


func _build_icon(root: Node3D, kind: int) -> void:
	var y := 3.45
	match kind:
		0:
			for i in 3:
				var fin := add_box(root,Vector3((i-1)*.48,y,0),Vector3(.25,1.5,.72),ivory)
				fin.rotation.z=deg_to_rad(float(i-1)*18.0)
		1:
			for i in 4:
				add_cylinder(root,Vector3((float(i)-1.5)*.42,y,0),.12,1.25+float(i)*.18,brass,10)
		2:
			add_box(root,Vector3(0,y+.25,0),Vector3(2.7,.18,.3),brass)
			for side in [-1,1]:
				add_box(root,Vector3(side*.95,y-.2,0),Vector3(.07,.75,.07),brass)
				add_sphere(root,Vector3(side*.95,y-.68,0),Vector3(.42,.2,.42),ivory)
		3:
			add_box(root,Vector3(0,y,0),Vector3(2.7,1.35,.36),teal)
			for i in 3: add_box(root,Vector3((i-1)*.72,y,-.24),Vector3(.46,.7,.08),glass)
		4:
			add_cylinder(root,Vector3(0,y,0),1.15,1.1,ivory,12)
			add_cylinder(root,Vector3(0,y-.72,0),.25,.55,brass,10)
		5:
			add_box(root,Vector3(0,y,0),Vector3(.28,1.65,.46),ivory)
		6:
			for side in [-1,1]:
				var branch := add_box(root,Vector3(side*.36,y,0),Vector3(.2,1.55,.42),ivory)
				branch.rotation.z=deg_to_rad(float(side)*24.0)
		7:
			add_sphere(root,Vector3(0,y+.08,0),Vector3(.8,.8,.32),glass)
			add_box(root,Vector3(0,y-.72,0),Vector3(.18,.48,.3),brass)
		8:
			for side in [-1,1]:
				var arm := add_box(root,Vector3(side*.52,y,0),Vector3(.22,1.7,.42),brass)
				arm.rotation.z=deg_to_rad(float(side)*35.0)
			add_sphere(root,Vector3(0,y+.72,0),Vector3.ONE*.38,glass)
		9:
			add_cylinder(root,Vector3(0,y+.2,0),.38,2.05,ivory,12)
			add_sphere(root,Vector3(0,y+1.45,0),Vector3(.5,.65,.5),gold)


func material(color: Color, roughness: float, metallic: float, emission:=Color.BLACK, energy:=0.0) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color=color
	value.roughness=roughness
	value.metallic=metallic
	if energy > 0.0:
		value.emission_enabled=true
		value.emission=emission
		value.emission_energy_multiplier=energy
	return value


func add_box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	node.position=at
	node.material_override=mat
	parent.add_child(node)
	return node


func add_cylinder(parent: Node3D, at: Vector3, radius: float, height: float, mat: Material, sides: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=sides
	node.mesh=mesh
	node.position=at
	node.material_override=mat
	parent.add_child(node)
	return node


func add_sphere(parent: Node3D, at: Vector3, scale_value: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments=16
	mesh.rings=8
	node.mesh=mesh
	node.position=at
	node.scale=scale_value
	node.material_override=mat
	parent.add_child(node)
	return node


func add_torus(parent: Node3D, at: Vector3, inner: float, outer: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius=inner
	mesh.outer_radius=outer
	mesh.rings=16
	mesh.ring_segments=8
	node.mesh=mesh
	node.position=at
	node.material_override=mat
	parent.add_child(node)
	return node


func add_label(parent: Node3D, text_value: String, at: Vector3, color: Color, size: int) -> Label3D:
	var label := Label3D.new()
	label.text=text_value
	label.position=at
	label.modulate=color
	label.font_size=size
	label.pixel_size=.012
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label
