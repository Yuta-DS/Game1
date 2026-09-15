extends Node3D
const Experiment := preload("res://scripts/mind_spark/causal_experiment.gd")
var station: QuestObjectBase
var model: Node3D
var status: Label3D
func configure(source: QuestObjectBase, world: MindSparkWorldOne) -> void:
	station=source
	name="ProductionTesterBay"
	model=preload("res://scripts/mind_spark/research_bay_mount.gd").mount(self,station,world,
		"res://assets3D/mind_spark/unfinished_light/tester_bay/tester_bay.glb",4.1)
	for spec in [["COOLING FLOW",Vector3(-1.63,2.87,.1)],["TEST BYPASS",Vector3(-.70,2.34,.5)],["PROTECTIVE SHUTTER",Vector3(1.48,3.32,.1)],["THE EXPLANATION WORKSHOP",Vector3(0,4.58,1.061)]]:
		var label := _label(str(spec[0]),spec[1])
		add_child(label)
	status=_label("Select an explanation, then test both flow conditions.",Vector3(0,1.15,1.0))
	status.font_size=26
	add_child(status)
func _label(text: String, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text=text
	label.position=at
	label.font_size=32
	label.pixel_size=.0025
	label.modulate=Color("fff0d3")
	return label
func _process(delta: float) -> void:
	var trial := int(station.current_state.get("trial",1))
	var selected := int(station.current_state.get("model",-1))
	var result := Experiment.outcome(trial)
	var flow := model.get_node("FlowColumn") as Node3D
	flow.scale.y=lerpf(flow.scale.y,float(result.flow),minf(1,delta*5))
	var shutter := model.get_node("Shutter") as Node3D
	shutter.position.y=lerpf(shutter.position.y,3.12 if result.shutter_open else 2.08,minf(1,delta*5))
	(model.get_node("ValveWheel") as Node3D).rotation.z=lerp_angle((model.get_node("ValveWheel") as Node3D).rotation.z,trial*PI*.75,minf(1,delta*5))
	(model.get_node("Selector") as Node3D).rotation.y=selected*TAU/3 if selected>=0 else 0
	if station.current_state.has("trial"):
		status.text="%s · FLOW %s · SHUTTER %s"%[Experiment.TRIAL_NAMES[trial],"LOW" if trial==0 else "RESTORED","OPEN" if result.shutter_open else "CLOSED"]
	else:
		status.text="Select an explanation, then test both flow conditions."
