extends Node3D
const Replay := preload("res://scripts/mind_spark/recorder_replay.gd")
const Rules := preload("res://scripts/mind_spark/unfinished_light_rules.gd")
var station: QuestObjectBase
var model: Node3D
var tiles: Array[Node3D] = []
var output: Label3D
var elapsed := -1.0
var serial := 0
var playing_order: Array = []
var drift_bar: MeshInstance3D
var flow_bar: MeshInstance3D
var shutter: MeshInstance3D
var tile_labels: Array[Label3D] = []
var displayed_order: Array = []
var tile_motion: Tween
func configure(source: QuestObjectBase, world: MindSparkWorldOne) -> void:
	station=source
	name="ProductionRecorderBay"
	model=preload("res://scripts/mind_spark/research_bay_mount.gd").mount(self,station,world,
		"res://assets3D/mind_spark/unfinished_light/recorder_bay/recorder_bay.glb",3.3)
	for i in 3:
		var tile := model.get_node("EventTile%d"%i) as Node3D
		tiles.append(tile)
		var label := _label(["BEAM DRIFT","FLOW FALLS","SHUTTER CLOSES"][i],Vector3(0,1.93,.54),.0026,32)
		add_child(label)
		tile_labels.append(label)
	output=_label("RECONSTRUCT · THEN REPLAY",Vector3(0,3.05,-.58),.003,36)
	add_child(output)
	var title := _label("THE MECHANICAL RECORDER",Vector3(0,4.58,1.061),.003,40)
	add_child(title)
	serial=int(station.current_state.get("replay_serial",0))
	displayed_order=Replay.order(station.current_state)
	for slot in 3: tiles[int(displayed_order[slot])].position.x=(slot-1)*1.4
	drift_bar=_bar("BeamDisplacement",Vector3(-1.3,2.98,-.50),Vector3(.45,.04,.04),Color("abe4ce"))
	flow_bar=_bar("CoolingLevel",Vector3(0,2.98,-.50),Vector3(.4,.04,.04),Color("abe4ce"))
	shutter=_bar("ShutterBlade",Vector3(1.3,2.98,-.50),Vector3(.28,.11,.04),Color("d4b675"))

func _label(text: String, at: Vector3, pixel: float, size: int) -> Label3D:
	var label := Label3D.new()
	label.text=text
	label.position=at
	label.pixel_size=pixel
	label.font_size=size
	label.modulate=Color("fff0d3")
	return label

func _bar(id: String, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name=id
	node.position=at
	var mesh := BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color=color
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override=mat
	add_child(node)
	return node

func replay_saved() -> void:
	# Presentation-only replay of a completed record: no new reward or save edit.
	playing_order=Replay.order(station.current_state)
	elapsed=-2

func _process(delta: float) -> void:
	if not is_instance_valid(station): return
	var order := Replay.order(station.current_state)
	for i in 3:
		tile_labels[i].position=Vector3(tiles[i].position.x,tiles[i].position.y,.54)
	if (tile_motion==null or not tile_motion.is_running()) and displayed_order!=order:
		# Lift into separated transfer lanes before exchanging places. Never
		# slide solid event plates through one another in the same plane.
		tile_motion=create_tween()
		tile_motion.tween_property(tiles[0],"position:y",1.93,.25)
		for i in range(1,3): tile_motion.parallel().tween_property(tiles[i],"position:y",1.93+i*.65,.25)
		tile_motion.tween_property(tiles[int(order[0])],"position:x",-1.4,.45)
		for slot in range(1,3): tile_motion.parallel().tween_property(tiles[int(order[slot])],"position:x",(slot-1)*1.4,.45)
		tile_motion.tween_property(tiles[0],"position:y",1.93,.25)
		for i in range(1,3): tile_motion.parallel().tween_property(tiles[i],"position:y",1.93,.25)
		displayed_order=order.duplicate()
	var current_serial := int(station.current_state.get("replay_serial",0))
	if current_serial != serial:
		serial=current_serial
		elapsed=-2 if serial>0 else -1
		playing_order=order.duplicate()
		if serial==0:
			output.text="RECONSTRUCT · THEN REPLAY"
			drift_bar.rotation.z=0
			flow_bar.scale.x=1
			shutter.position.y=3.1
	if tile_motion!=null and tile_motion.is_running(): return
	if elapsed==-2: elapsed=0
	if elapsed<0: return
	if playing_order!=order:
		elapsed=-1
		output.text="ORDER CHANGED · REPLAY AGAIN"
		return
	elapsed=minf(elapsed+delta,Replay.DURATION)
	var state := Replay.sample(playing_order,elapsed)
	(model.get_node("Pointer") as Node3D).position.x=lerpf((model.get_node("Pointer") as Node3D).position.x,(int(state.slot)-1)*1.4,minf(1,delta*10))
	(model.get_node("Drum") as Node3D).rotation.x=elapsed*1.2
	(model.get_node("ReplayLever") as Node3D).rotation.x=-.35 if not state.finished else 0.0
	drift_bar.rotation.z=.18 if state.drift else 0.0
	flow_bar.scale.x=float(state.flow)
	shutter.position.y=3.1 if state.shutter_open else 2.98
	output.text="%d · %s"%[int(state.slot)+1,Rules.EVENTS[int(state.event)]]
