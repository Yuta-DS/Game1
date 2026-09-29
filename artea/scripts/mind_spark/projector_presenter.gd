extends Node3D
const Pattern := preload("res://scripts/mind_spark/light_pattern_state.gd")
var station: QuestObjectBase
var model: Node3D
var beams: Array[MeshInstance3D]=[]
var targets: Array[MeshInstance3D]=[]
var target_labels: Array[Label3D]=[]
var readouts: Array[Label3D]=[]
var status: Label3D
var _state_hash := -1
var _animation_remaining := 0.0
func configure(source: QuestObjectBase, world: MindSparkWorldOne) -> void:
	station=source
	name="ProductionLivingProjector"
	var mount=preload("res://scripts/mind_spark/research_bay_mount.gd")
	model=mount.mount(self,station,world,"res://assets3D/mind_spark/unfinished_light/projector/projector.glb",3.8,false)
	mount._solid(self,"GardenPlinthSolid",Vector3(0,.62,-3.3),Vector3(6.4,1.24,3.0))
	for x in [-2.0,0.0,2.0]:
		var body := StaticBody3D.new()
		body.position=Vector3(x,1.50,-3.3)
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius=.91
		cylinder.height=.46
		shape.shape=cylinder
		body.add_child(shape)
		add_child(body)
	var green := StandardMaterial3D.new()
	green.albedo_color=Color("76ccb3")
	green.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var gold := StandardMaterial3D.new()
	gold.albedo_color=Color("cfa454")
	gold.roughness=.5
	# A continuous mounted fascia keeps the readings off drawer edges and
	# recessed cabinet surfaces; labels sit just ahead of its front face.
	var fascia := MeshInstance3D.new()
	fascia.name="LiveTargetReadoutFascia"
	var fascia_mesh := BoxMesh.new()
	fascia_mesh.size=Vector3(4.2,.65,.10)
	fascia.mesh=fascia_mesh
	fascia.position=Vector3(0,.98,1.55)
	var ivory := StandardMaterial3D.new()
	ivory.albedo_color=Color("eee4c6")
	ivory.roughness=.85
	fascia.material_override=ivory
	add_child(fascia)
	for i in 3:
		var beam := MeshInstance3D.new()
		beam.name="LivePatternRay%d"%i
		var cylinder := CylinderMesh.new()
		cylinder.height=1
		cylinder.top_radius=.018
		cylinder.bottom_radius=.018
		cylinder.radial_segments=8
		beam.mesh=cylinder
		beam.material_override=green
		add_child(beam)
		beams.append(beam)
		var target := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius=.10
		mesh.outer_radius=.14
		mesh.rings=16
		mesh.ring_segments=6
		target.mesh=mesh
		target.rotation.x=PI/2
		target.material_override=gold
		add_child(target)
		targets.append(target)
		target_labels.append(_label(["I","II","III"][i],Vector3.ZERO,24,.003))
		var readout := _label("",Vector3((i-1)*1.25,1.09,1.61),32,.005)
		readout.modulate=Color("123c3b")
		readout.outline_size=0
		readouts.append(readout)
		_label(["MIRROR + SPREAD","SHUTTER + PLATE","PATTERN PLATE"][i],Vector3((i-1)*1.25,1.42,.85),22,.002)
	status=_label("Choose a repair approach",Vector3(0,3.95,0),32,.003)
	_label("LIVING LIGHT · PATTERN INSTRUMENT",Vector3(0,1.19,1.0),28,.0025)
	var legend := _label("CHANNEL · LIVE / TARGET",Vector3(0,.82,1.61),26,.004)
	legend.modulate=Color("123c3b")
	legend.outline_size=0
func _label(text: String, at: Vector3, size: int, pixels: float) -> Label3D:
	var label := Label3D.new()
	label.text=text
	label.position=at
	label.font_size=size
	label.pixel_size=pixels
	label.modulate=Color("fff0d3")
	add_child(label)
	return label
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var next_hash := hash(station.current_state)
	if next_hash != _state_hash:
		_state_hash = next_hash
		_animation_remaining = 0.9
	elif _animation_remaining <= 0.0:
		return
	_animation_remaining = maxf(0.0, _animation_remaining - delta)
	var state := Pattern.describe(station.current_state)
	var mix := minf(1,delta*6)
	(model.get_node("Mirror") as Node3D).rotation.y=lerp_angle((model.get_node("Mirror") as Node3D).rotation.y,int(state.optics[0])*PI/8,mix)
	(model.get_node("PatternPlate") as Node3D).position.x=1.3+(int(state.optics[2])-1.5)*.08
	(model.get_node("ReferenceBrace") as Node3D).visible=state.held_reference
	(model.get_node("CoolingLevel") as Node3D).scale.y=1 if state.cooling else .2
	(model.get_node("Shutter") as Node3D).position.y=lerpf((model.get_node("Shutter") as Node3D).position.y,3.30 if state.cooling and state.enabled else 2.79,mix)
	for i in 3:
		readouts[i].text="%s  %d / %d"%[["I","II","III"][i],int(state.optics[i]),int(state.target[i])] if state.enabled else "%s  —"%[ ["I","II","III"][i] ]
		(model.get_node("Control%d"%i) as Node3D).rotation.y=int(state.optics[i])*PI/2
		var x: float=(i-1)*(.4 if state.small_bed else 2.0)
		var endpoint := Vector3(x,2.6+int(state.optics[i])*.22,-3.3)
		targets[i].position=Vector3(x,2.6+int(state.target[i])*.22,-3.3)
		targets[i].visible=state.enabled
		target_labels[i].position=targets[i].position+Vector3(0,.22,0)
		target_labels[i].visible=state.enabled
		var start := Vector3(0,3.33,-.76)
		beams[i].position=(start+endpoint)*.5
		beams[i].look_at(to_global(endpoint),Vector3.UP)
		beams[i].rotate_object_local(Vector3.RIGHT,PI/2)
		beams[i].scale.y=start.distance_to(endpoint)
		beams[i].visible=state.beam_enabled
	for i in 9:
		var active: bool=not state.small_bed or i in [3,4,5]
		var leaf := model.get_node("Leaf%d"%i) as Node3D
		leaf.rotation.x=lerp_angle(leaf.rotation.x,0.0 if state.solved and active else 1.1,mix)
		leaf.visible=active or not state.enabled
	status.text=["SMALL TEST BED","ARI HOLDS THE REFERENCE","RESTORE COOLING FIRST"][state.approach] if state.enabled else "Choose a repair approach"
	if state.solved: status.text="GARDEN RESTORED · SHARE YOUR DISCOVERY"
