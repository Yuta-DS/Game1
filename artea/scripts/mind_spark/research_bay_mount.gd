extends RefCounted
## Shared physical contract for the authored 5.4m laboratory bench/pavilion kit.
## Station route position/facing remains owned by the world's canonical layout.
const APPROACH := Vector3(0,0,4.5)
const SENSOR_RADIUS := 5.0
const BENCH_WIDTH := 5.4
const BENCH_DEPTH := 1.9
const IMPORTED_TEXTURE_UID_ALIASES := {
	"res://assets3D/mind_spark/unfinished_light/inspection_bay/inspection_bay.glb": {
		"uid": "uid://1diuddxolsth",
		"path": "res://assets3D/mind_spark/unfinished_light/inspection_bay/inspection_bay_quiet_surface_atlas.png",
	},
	"res://assets3D/mind_spark/unfinished_light/recorder_bay/recorder_bay.glb": {
		"uid": "uid://c311injowp6iu",
		"path": "res://assets3D/mind_spark/unfinished_light/recorder_bay/recorder_bay_quiet_surface_atlas.png",
	},
	"res://assets3D/mind_spark/unfinished_light/tester_bay/tester_bay.glb": {
		"uid": "uid://bo2fe6lx50842",
		"path": "res://assets3D/mind_spark/unfinished_light/tester_bay/tester_bay_quiet_surface_atlas.png",
	},
	"res://assets3D/mind_spark/unfinished_light/perspective_bay/perspective_bay.glb": {
		"uid": "uid://bn0g16uhniluo",
		"path": "res://assets3D/mind_spark/unfinished_light/perspective_bay/perspective_bay_quiet_surface_atlas.png",
	},
	"res://assets3D/mind_spark/unfinished_light/projector/projector.glb": {
		"uid": "uid://dxh502c0co43g",
		"path": "res://assets3D/mind_spark/unfinished_light/projector/projector_quiet_surface_atlas.png",
	},
}

static func mount(bay: Node3D, station: QuestObjectBase, world: MindSparkWorldOne,
		asset: String, housing_height: float, shell_present := true) -> Node3D:
	_register_imported_texture_uid(asset)
	bay.set_meta("preserve_authored_nodes",true)
	station.scale=Vector3.ONE
	var zone := station.get_parent() as Node3D
	var floor_at := world.to_local(station.global_position)
	floor_at.y=float(world.call("_zone_floor_surface_y",world.to_local(zone.global_position)))
	station.global_position=world.to_global(floor_at)
	# The research court has a real raised dais above its island deck. Ground
	# the new bay on that authored surface, not inside its solid collision.
	var dais := world.find_child("ConstellationDais",true,false) as MeshInstance3D
	if dais!=null and dais.mesh is CylinderMesh and dais.is_visible_in_tree():
		var local := dais.to_local(station.global_position)
		var cylinder_mesh := dais.mesh as CylinderMesh
		if Vector2(local.x,local.z).length()+4.5 < cylinder_mesh.top_radius:
			station.global_position.y=maxf(station.global_position.y,dais.to_global(Vector3(0,cylinder_mesh.height*.5,0)).y)
	station.set_meta("production_asset",asset.get_file())
	station.set_meta("physical_signage",true)
	station.set_meta("operator_approach_local",station.position+station.basis*APPROACH)
	station.set_meta("minimum_operator_apron_m",4.0)
	station.get_node("VisualRoot").visible=false
	for body in station.get_node("VisualRoot").find_children("*","CollisionObject3D",true,false):
		body.collision_layer=0
		body.collision_mask=0
	for label in station.find_children("*","Label3D",true,false): label.visible=false
	for key in ["Prompt","Status","Icon"]: station.get_node(key).visible=false
	var housing := station.get_node("IslandTwoStationSolid/HousingCollision") as CollisionShape3D
	var box := BoxShape3D.new()
	box.size=Vector3(BENCH_WIDTH,housing_height,BENCH_DEPTH)
	housing.shape=box
	housing.position=Vector3(0,housing_height*.5,0)
	var sensor := station.get_node("InteractionArea/CollisionShape3D") as CollisionShape3D
	var cylinder := CylinderShape3D.new()
	cylinder.radius=SENSOR_RADIUS
	cylinder.height=4
	sensor.shape=cylinder
	for side in [-1,1]:
		if not shell_present: break
		for z in [-2.0,.9]:
			_solid(bay,"PavilionPier%d_%s"%[side,str(z)],Vector3(side*3.55,2.5,z),Vector3(.8,5,.8))
		# Side shelves are real masses, not surfaces the player's torso can enter.
		_solid(bay,"ServiceShelf%d"%side,Vector3(side*3.3,1.15,-1),Vector3(.85,.14,1.2))
	var light := OmniLight3D.new()
	light.name="WarmBenchTaskLight"
	light.position=Vector3(0,3.5,1.5)
	light.light_color=Color("fff0d3")
	light.light_energy=1.4
	light.omni_range=7
	light.shadow_enabled=false
	bay.add_child(light)
	var model := load(asset).instantiate() as Node3D
	bay.add_child(model)
	return model


static func _register_imported_texture_uid(asset: String) -> void:
	## These five Blender exports retained the atlas UID from the machine that
	## authored them. The paths are stable project assets, so register the legacy
	## identifiers before ResourceLoader resolves the imported PackedScene.
	if not IMPORTED_TEXTURE_UID_ALIASES.has(asset):
		return
	var alias: Dictionary = IMPORTED_TEXTURE_UID_ALIASES[asset]
	var uid := ResourceUID.text_to_id(str(alias.uid))
	var texture_path := str(alias.path)
	if not ResourceUID.has_id(uid):
		ResourceUID.add_id(uid, texture_path)

static func _solid(bay: Node3D, id: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name=id
	body.position=at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=size
	collider.shape=shape
	body.add_child(collider)
	bay.add_child(body)
