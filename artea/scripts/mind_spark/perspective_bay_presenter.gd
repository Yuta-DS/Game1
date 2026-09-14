extends Node3D
const Evidence := preload("res://scripts/mind_spark/perspective_evidence.gd")
var station: QuestObjectBase
var model: Node3D
var heading: Label3D
var description: Label3D
var selected := -1
func configure(source: QuestObjectBase, world: MindSparkWorldOne) -> void:
	station=source
	name="ProductionPerspectiveBay"
	model=preload("res://scripts/mind_spark/research_bay_mount.gd").mount(self,station,world,
		"res://assets3D/mind_spark/unfinished_light/perspective_bay/perspective_bay.glb",3.1)
	# Include the projecting eyepiece in the solid instrument envelope.
	var housing := station.get_node("IslandTwoStationSolid/HousingCollision") as CollisionShape3D
	(housing.shape as BoxShape3D).size.z=2.8
	heading=_label("",Vector3(0,3.15,1.45),28,.003)
	description=_label("",Vector3(0,1.21,1.0),24,.0024)
	_label("THE PERSPECTIVE WORKSHOP",Vector3(0,4.58,1.061),40,.003)
	_label("TURN THE EVIDENCE VIEWER",Vector3(1.78,1.81,.60),24,.002)
	var view := clampi(int(station.current_state.get("view",0)),0,2)
	(model.get_node("Carousel") as Node3D).rotation.y=Evidence.angle(view)
	_sync_text(view)
func _label(text: String, at: Vector3, size: int, pixels: float) -> Label3D:
	var label := Label3D.new()
	label.text=text
	label.position=at
	label.font_size=size
	label.pixel_size=pixels
	label.modulate=Color("fff0d3")
	add_child(label)
	return label
func _sync_text(view: int) -> void:
	selected=view
	heading.text=Evidence.TITLES[view]
	var answers: Array=station.current_state.get("view_answers",[false,false,false])
	description.text=("RECORDED · " if answers[view] or station.current_state.get("completed",false) else "EXPLORE · ")+Evidence.CONTRIBUTIONS[view]
func _process(delta: float) -> void:
	var view := clampi(int(station.current_state.get("view",0)),0,2)
	var target := Evidence.angle(view)
	var carousel := model.get_node("Carousel") as Node3D
	carousel.rotation.y=lerp_angle(carousel.rotation.y,target,minf(1,delta*6))
	(model.get_node("Selector") as Node3D).rotation.y=carousel.rotation.y
	_sync_text(view)
