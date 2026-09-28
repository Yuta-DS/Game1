extends RefCounted

const ECHO_IDS := ["echo_collector","echo_signal_1","echo_signal_2","echo_signal_3","echo_question","echo_beacon"]

static func apply(world: MindSparkWorldOne) -> void:
	var puzzle := world.get_island_one_puzzle()
	if puzzle == null or world.has_node("IslandOneResearchCampus"):
		return
	var zones: Dictionary = world.get("_zone_nodes")
	var arrival: Node3D = zones["01_world_gate_landing"]
	var garden: Node3D = zones["02_living_network_forest"]
	var campus := Node3D.new()
	campus.name = "IslandOneResearchCampus"
	campus.set_meta("preserve_authored_nodes",true)
	campus.set_meta("story_sequence",["Signal Laboratory","Signal Prism","Living Research Garden","Echo Seed","Island Two"])
	world.add_child(campus)
	var controls := puzzle.get_node("PuzzleControls")
	# Separate confirmation from the middle control far enough that its operator
	# anchor selects confirmation, rather than tying with the earlier control.
	(controls.get_node("PuzzleControl_confirm") as Node3D).position = Vector3(0,3,84)
	# These coordinates are already relative to the deck-height zone. The old
	# extra 3 m offset left the plinths above the actual player capsule.
	for control in controls.get_children():
		if control is Node3D: control.position.y=.05
	_relocate_signal_laboratory(controls)
	var offset := puzzle.to_local(garden.to_global(Vector3(-28,0,40))) - Vector3(-52,0,24)
	var echo := puzzle.get_node("EchoGardenQuestArchitecture") as Node3D
	echo.position += offset
	var gate := world.find_child("IslandOneHeavenlyStarGate",true,false) as Node3D
	var echo_layout := {
		"echo_collector":Vector3(-68,.05,48)+offset,
		"echo_signal_1":Vector3(-80,.05,12)+offset,
		"echo_signal_2":Vector3(-84,.05,25)+offset,
		"echo_signal_3":Vector3(-80,.05,38)+offset,
		"echo_question":Vector3(-53,.05,54)+offset,
		"echo_beacon":Vector3(-36,.05,48)+offset,
	}
	# Each station faces the direction from which the player reaches it. This
	# creates one legible curved route rather than six machines staring at an
	# arbitrary centre point.
	var echo_approaches := {
		"echo_collector":puzzle.to_local(gate.global_position),
		"echo_signal_1":Vector3(-72,.05,12)+offset,
		"echo_signal_2":Vector3(-76,.05,25)+offset,
		"echo_signal_3":Vector3(-72,.05,38)+offset,
		"echo_question":Vector3(-59.9,.05,49.9)+offset,
		"echo_beacon":Vector3(-44.0,.05,53.4)+offset,
	}
	for route_index in ECHO_IDS.size():
		var id: String = ECHO_IDS[route_index]
		var control := controls.get_node("PuzzleControl_"+id) as Node3D
		control.position=echo_layout[id]
		_face(control,echo_approaches[id])
		control.set_meta("quest_route_order",route_index+5)
		control.set_meta("operator_clearance_met",control.position.distance_to(echo_approaches[id])>7.0)
		control.set_meta("laboratory_department","Living Research Garden")
	# The grove is placed before the finished six-station layout. Its twentieth
	# sapling otherwise stands in the Echo Question operator envelope.
	var question_side_tree := garden.find_child("MindSparkGroveTree_020", true, false) as Node3D
	if question_side_tree != null:
		question_side_tree.position = world.call("_clear_garden_position", garden,
			question_side_tree.position, float(question_side_tree.get_meta("growth_scale")),
			question_side_tree)
	_connect_garden_services(world,echo,controls)
	# Orient the complete assembly, not just the visible model. Its collision,
	# state lamp, labels and western inspection marker rotate together.
	var approaches := {
		"colour_prism":Vector3(-31.5,.05,14), "rhythm_prism":Vector3(-29.5,.05,30),
		"weight_prism":Vector3(-57,.05,24), "analysis_console":Vector3(-52,.05,40),
		"west_regulator":Vector3(-24,.05,-34), "east_regulator":Vector3(24,.05,-34),
		"outer_ring":Vector3(-22,.05,50), "middle_ring":Vector3(0,.05,56),
		"inner_ring":Vector3(22,.05,50), "confirm":Vector3(0,.05,76)}
	for id in approaches:
		var control := controls.get_node("PuzzleControl_"+id) as Node3D
		_face(control,approaches[id])
		control.set_meta("laboratory_department","Signal Laboratory")
	_install_quest_visual_hierarchy(world,campus,controls)
	# Beam endpoints are authored from the actual output anchors.
	var old_routes := puzzle.get_node("LivingLightLaboratoryRoutes")
	puzzle.remove_child(old_routes)
	old_routes.queue_free()
	world.call("_build_living_light_routes",puzzle)
	# The first guidance segment now begins at the real garden threshold.
	var collector := controls.get_node("PuzzleControl_echo_collector") as Node3D
	var guidance := echo.get_node("EchoGardenGuidancePath") as Node3D
	for marker in guidance.get_children():
		if int(marker.get_meta("guidance_chapter",-1)) == 0:
			var fraction := float(str(marker.name).get_slice("_",2).to_int())/8.0
			var a := guidance.to_local(gate.global_position)
			var b := guidance.to_local(collector.global_position)
			marker.position = a.lerp(b,fraction)
		marker.position.y = .08
	puzzle.set_meta("research_campus_layout",true)
	puzzle.puzzle_state_changed.connect(func(state: Dictionary):
		var unlocked := bool(state.get("signal_observatory_complete",false))
		if world.is_island_one_star_gate_open() != unlocked:
			world.call("_set_island_one_star_gate_open",unlocked,true))
	world.call("_set_island_one_star_gate_open",puzzle.is_signal_observatory_complete(),false)
	gate.set_meta("prerequisite","signal_observatory_complete")
	gate.set_meta("purpose","Signal Prism opens access to the Living Research Garden")
	for station in world.get_quest_objects():
		if station.save_id == "world_one.checkpoint.landing":
			# Keep the helper beside the signal laboratory. The former operator
			# point at (-25, -23) sat on the west regulator's solid plinth. The
			# obvious outer side is occupied by the lantern tower, so this diagonal
			# apron preserves interaction range in the clear space between both.
			station.position=Vector3(-36,.05,-28)
			var target := Vector3(-44,.05,-17)
			station.look_at(arrival.to_global(target),Vector3.UP,true)
			station.set_meta("operator_approach_local",target)
		elif station.save_id == "world_one.path_projector":
			station.position=Vector3(36,.05,-28)
			var target := Vector3(44,.05,-17)
			station.look_at(arrival.to_global(target),Vector3.UP,true)
			station.set_meta("operator_approach_local",target)
		elif station.save_id == "world_one.checkpoint.network":
			var onward := (world.get_zone_position("03_constellation_court") \
				- world.get_zone_position("02_living_network_forest")) * Vector3(1,0,1)
			onward=onward.normalized()
			var side := Vector3(-onward.z,0,onward.x)
			station.position=onward*123.0-side*22.0+Vector3.UP*.05
			var target := station.position-onward*12.0
			station.look_at(garden.to_global(target),Vector3.UP,true)
			station.set_meta("operator_approach_local",target)
		elif station.save_id == "world_one.spark_socket":
			var onward := (world.get_zone_position("03_constellation_court") \
				- world.get_zone_position("02_living_network_forest")) * Vector3(1,0,1)
			onward=onward.normalized()
			var side := Vector3(-onward.z,0,onward.x)
			station.position=onward*123.0+side*22.0+Vector3.UP*.05
			var target := station.position-onward*12.0
			station.look_at(garden.to_global(target),Vector3.UP,true)
			station.set_meta("operator_approach_local",target)
		if station.get_parent() in [arrival,garden]:
			station.position.y=.05
			# Interaction Areas detect proximity; they are not solid collision.
			_solid_box(station,"CampusSolidPlinth",Vector3(0,.17,0),Vector3(2.2,.34,1.3))
			_solid_box(station,"CampusSolidCabinet",Vector3(0,1,0),Vector3(1.9,1.7,.85))
		if station.save_id == "world_one.spark_socket":
			_replace_legacy_spark_socket(world,station)
	# The former four "sample benches" deliberately reused the checkpoint-server
	# model. Although noninteractive, they read as duplicate quest machines and
	# weakened the player's ability to identify the active route. Keep the courts
	# open and let the unique functional instruments below carry the story.
	_sign(world,campus,arrival.to_global(Vector3(-30,.05,83)),arrival.to_global(Vector3(-30,.05,105)),"01 • SIGNAL LABORATORY\nObserve → Compare → Form the Prism")
	_sign(world,campus,garden.to_global(Vector3(-66,.05,70)),gate.global_position,"02 • LIVING RESEARCH GARDEN\nListen → Classify → Choose a response")
	world.set_meta("island_one_environment_style","heavenly research campus")
	world.set_meta("island_one_quest_visual_rule","one silhouette = one verb; repetition only inside a labelled set")


static func _relocate_signal_laboratory(controls: Node) -> void:
	# The architecture already provides three unique crescent bay medallions.
	# Restore the controls to those physical foundations, then put Analysis at the
	# point where all three buried conduits converge beyond the shared root well.
	var layout := {
		"colour_prism":Vector3(-39.5,.05,16),
		"rhythm_prism":Vector3(-37.5,.05,30),
		"weight_prism":Vector3(-66,.05,24),
		"analysis_console":Vector3(-52,.05,48),
	}
	var order := ["colour_prism","rhythm_prism","weight_prism","analysis_console"]
	for route_index in order.size():
		var id: String=order[route_index]
		var control := controls.get_node("PuzzleControl_"+id) as Node3D
		control.position=layout[id]
		control.set_meta("quest_route_order",route_index+1)
		control.set_meta("route_family","signal laboratory arc")


static func _install_quest_visual_hierarchy(world: MindSparkWorldOne, parent: Node3D, controls: Node) -> void:
	# A readable quest line from the player camera: each machine keeps the shared
	# ivory/brass laboratory chassis, but gains a different upper silhouette that
	# explains its verb before UI text is read.
	parent.set_meta("quest_visual_hierarchy","island_one_unique_roles_01")
	var roles := {
		"colour_prism":["REFRACT",0],
		"rhythm_prism":["TUNE",1],
		"weight_prism":["BALANCE",2],
		"analysis_console":["COMPARE",3],
		"echo_collector":["COLLECT",4],
		"echo_signal_1":["FACT",5],
		"echo_signal_2":["POSSIBILITY",6],
		"echo_signal_3":["UNSURE",7],
		"echo_question":["REFRAME",8],
		"echo_beacon":["CHOOSE HOPE",9]
	}
	for id in roles:
		var control := controls.get_node_or_null("PuzzleControl_"+id) as Node3D
		if control == null:
			continue
		control.set_meta("unique_quest_role",roles[id][0])
		control.set_meta("visual_duplicate",false)
		_add_role_silhouette(world,control,id,str(roles[id][0]),int(roles[id][1]))
	# The three evidence channels intentionally repeat one chassis. A shared
	# lintel makes them read as a single classification instrument, not three
	# copied quests, while their crowns remain visibly different.
	var first := controls.get_node_or_null("PuzzleControl_echo_signal_1") as Node3D
	var second := controls.get_node_or_null("PuzzleControl_echo_signal_2") as Node3D
	var third := controls.get_node_or_null("PuzzleControl_echo_signal_3") as Node3D
	if first != null and second != null and third != null:
		for unit in [first,second,third]:
			unit.set_meta("intentional_reuse_group","three-channel evidence classifier")
			unit.set_meta("single_puzzle_array",true)


static func _add_role_silhouette(world: MindSparkWorldOne, control: Node3D,
		control_id: String, verb: String, role_index: int) -> void:
	var old := control.get_node_or_null("CampusRoleSilhouette")
	if old != null:
		old.queue_free()
	var crown := Node3D.new()
	crown.name="CampusRoleSilhouette"
	crown.position=Vector3(0,5.45,0)
	crown.set_meta("control_id",control_id)
	crown.set_meta("interaction_verb",verb)
	crown.set_meta("editable_component",true)
	control.add_child(crown)
	var mats: Dictionary=world.get("_materials")
	# Shared construction layers make the kit coherent without repeating its icon.
	world.call("_add_cylinder",crown,"IvoryNeck",Vector3(0,.18,0),.56,.36,mats.sanctum_ivory,false,12)
	world.call("_add_torus",crown,"BrassRoleBezel",Vector3(0,.52,0),.58,.76,mats.astral_brass)
	world.call("_add_sphere",crown,"StateJewel",Vector3(0,.58,0),Vector3.ONE*.28,mats.arrival_glass)
	match control_id:
		"colour_prism":
			# Three separated optical fins form a faceted prism, never a solid ring.
			for i in 3:
				var fin := world.call("_add_box",crown,"SpectralFin_%02d"%(i+1),Vector3((i-1)*.55,1.35,0),Vector3(.28,1.5,.75),mats.sanctum_ivory,false) as Node3D
				fin.rotation.z=deg_to_rad(float(i-1)*18.0)
		"rhythm_prism":
			for i in 4:
				world.call("_add_cylinder",crown,"Chime_%02d"%(i+1),Vector3((float(i)-1.5)*.42,1.20+float(i%2)*.22,0),.13,1.45+float(i)*.12,mats.astral_brass,false,10)
		"weight_prism":
			world.call("_add_box",crown,"BalanceBeam",Vector3(0,1.35,0),Vector3(2.5,.18,.30),mats.astral_brass,false)
			for side in [-1,1]:
				world.call("_add_box",crown,"Suspension_%s"%side,Vector3(side*.92,.86,0),Vector3(.08,.9,.08),mats.astral_brass,false)
				world.call("_add_sphere",crown,"Counterweight_%s"%side,Vector3(side*.92,.38,0),Vector3(.42,.22,.42),mats.sanctum_ivory)
		"analysis_console":
			world.call("_add_box",crown,"AnalysisCanopy",Vector3(0,1.22,0),Vector3(2.8,1.35,.38),mats.bio_gunmetal,false)
			for i in 3:
				world.call("_add_box",crown,"EvidenceWindow_%02d"%(i+1),Vector3((i-1)*.78,1.22,-.24),Vector3(.54,.72,.08),mats.arrival_glass,false)
		"echo_collector":
			world.call("_add_cylinder",crown,"ListeningBell",Vector3(0,1.30,0),1.15,.95,mats.sanctum_ivory,false,12)
			world.call("_add_cylinder",crown,"ListeningThroat",Vector3(0,.82,0),.28,.72,mats.astral_brass,false,10)
		"echo_signal_1":
			world.call("_add_box",crown,"FactPillar",Vector3(0,1.30,0),Vector3(.30,1.65,.48),mats.sanctum_ivory,false)
		"echo_signal_2":
			for side in [-1,1]:
				var branch := world.call("_add_box",crown,"PossibilityBranch_%s"%side,Vector3(side*.38,1.28,0),Vector3(.22,1.55,.42),mats.sanctum_ivory,false) as Node3D
				branch.rotation.z=deg_to_rad(float(side)*24.0)
		"echo_signal_3":
			world.call("_add_sphere",crown,"UncertaintyLens",Vector3(0,1.30,0),Vector3(.82,.82,.34),mats.arrival_glass)
			world.call("_add_box",crown,"UncertaintyStem",Vector3(0,.55,0),Vector3(.18,.48,.30),mats.astral_brass,false)
		"echo_question":
			for side in [-1,1]:
				var arm := world.call("_add_box",crown,"ReframeBranch_%s"%side,Vector3(side*.55,1.30,0),Vector3(.25,1.85,.45),mats.astral_brass,false) as Node3D
				arm.rotation.z=deg_to_rad(float(side)*35.0)
			world.call("_add_sphere",crown,"ReframeChoice",Vector3(0,1.85,0),Vector3.ONE*.42,mats.arrival_glass)
		"echo_beacon":
			world.call("_add_cylinder",crown,"HopeSpire",Vector3(0,1.48,0),.42,2.25,mats.sanctum_ivory,false,12)
			world.call("_add_sphere",crown,"HopeLight",Vector3(0,2.72,0),Vector3(.55,.72,.55),mats.arrival_glass)
	# A front-facing role plaque is the only text repeated across the family.
	var plaque := world.call("_add_label",crown,"%02d • %s"%[role_index+1,verb],Vector3(0,-.12,-.82),Color("214f5c"),18) as Label3D
	plaque.name="QuestRolePlaque"
	plaque.pixel_size=.011
	plaque.outline_size=1
	plaque.billboard=BaseMaterial3D.BILLBOARD_ENABLED

static func _face(control: Node3D, approach: Vector3) -> void:
	var direction := approach-control.position
	direction.y=0
	control.rotation.y=atan2(direction.z,-direction.x)
	control.set_meta("approach_position",approach)
	control.set_meta("front_axis",Vector3.LEFT)

static func _sign(world: MindSparkWorldOne, parent: Node3D, at: Vector3, approach: Vector3, text: String) -> void:
	var sign := Node3D.new()
	sign.name="LaboratoryWayfinding"
	parent.add_child(sign)
	sign.global_position=at
	approach.y=at.y
	sign.look_at(approach,Vector3.UP,true)
	var mats: Dictionary=world.get("_materials")
	world.call("_add_box",sign,"IvorySignPlinth",Vector3(0,.35,0),Vector3(9,.7,2),mats.sanctum_ivory,true)
	world.call("_add_box",sign,"BrassSupport",Vector3(0,2,0),Vector3(.35,3,.35),mats.astral_brass,true)
	world.call("_add_box",sign,"TealDirectory",Vector3(0,4,0),Vector3(10,3,.3),mats.bio_gunmetal,true)
	var label := world.call("_add_label",sign,text,Vector3(0,4,.25),Color("fff2d9"),28) as Label3D
	label.pixel_size=.012
	label.outline_size=2
	label.billboard=BaseMaterial3D.BILLBOARD_DISABLED

static func _solid_box(parent: Node3D, title: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name=title
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	collision.position=at
	body.add_child(collision)


static func _replace_legacy_spark_socket(world: MindSparkWorldOne, station: QuestObjectBase) -> void:
	# The prior socket was a decorative disc of green circuitry, gold tracks and
	# halo rings. It did not communicate the three physical Spark slots and it
	# clashes with the calm laboratory material family. Keep the quest object and
	# its interaction/collision unchanged; replace its render-only imported model.
	var visual := station.get_node_or_null("VisualRoot") as Node3D
	if visual == null:
		return
	var legacy := visual.get_node_or_null("BlenderModel") as Node3D
	if legacy != null:
		legacy.visible=false
		legacy.set_meta("replaced_reason","obsolete ring, green line and gold circuit-disc silhouette")
	var old := visual.get_node_or_null("CampusSparkReceiver") as Node3D
	if old != null:
		old.queue_free()
	var receiver := Node3D.new()
	receiver.name="CampusSparkReceiver"
	receiver.set_meta("style","heavenly research-cabinet; no exposed circular route graphics")
	receiver.set_meta("physical_role","three-slot Spark receiver")
	visual.add_child(receiver)
	var mats: Dictionary=world.get("_materials")
	# The cabinet is deliberately rectilinear: a stepped ivory foundation carries
	# a teal enamel body, with every luminous indicator contained in a window.
	world.call("_add_box",receiver,"ReceiverFoot",Vector3(0,.10,0),Vector3(1.58,.20,1.10),mats.sanctum_ivory,false)
	world.call("_add_box",receiver,"ReceiverStep",Vector3(0,.25,.03),Vector3(1.34,.14,.90),mats.sanctum_ivory,false)
	world.call("_add_box",receiver,"ReceiverBody",Vector3(0,.77,.10),Vector3(1.12,1.06,.62),mats.bio_gunmetal,false)
	world.call("_add_box",receiver,"ReceiverCrown",Vector3(0,1.35,.10),Vector3(1.22,.13,.70),mats.sanctum_ivory,false)
	world.call("_add_box",receiver,"ReceiverRearPanel",Vector3(0,.77,.425),Vector3(.82,.68,.04),mats.sanctum_ivory,false)
	for row in 3:
		world.call("_add_box",receiver,"RearVent_%02d"%(row+1),Vector3(0,.58+float(row)*.18,.455),Vector3(.52,.045,.025),mats.astral_brass,false)
	world.call("_add_box",receiver,"ReceiverFace",Vector3(0,.82,-.235),Vector3(.82,.71,.045),mats.arrival_glass,false)
	world.call("_add_box",receiver,"DockingBay",Vector3(0,.43,-.285),Vector3(.56,.18,.13),mats.sanctum_ivory,false)
	world.call("_add_box",receiver,"DockingBayInset",Vector3(0,.43,-.355),Vector3(.36,.07,.035),mats.bio_gunmetal,false)
	for side in [-1,1]:
		world.call("_add_box",receiver,"ReceiverSideFin_%s"%side,Vector3(side*.69,.77,.10),Vector3(.12,.84,.48),mats.sanctum_ivory,false)
		world.call("_add_sphere",receiver,"ReceiverFastener_%s"%side,Vector3(side*.54,1.14,-.29),Vector3.ONE*.07,mats.astral_brass)
	for index in 3:
		var y:=1.12-float(index)*.22
		world.call("_add_box",receiver,"ChargeWindow_%02d"%(index+1),Vector3(-.29,y,-.285),Vector3(.19,.12,.035),mats.sanctum_ivory,false)
		var lamp := world.call("_add_sphere",receiver,"ChargeCell_%02d"%(index+1),Vector3(-.29,y,-.325),Vector3.ONE*.075,mats.bio_gunmetal) as MeshInstance3D
		lamp.set_meta("inactive_material",mats.bio_gunmetal)
		lamp.set_meta("active_material",mats.arrival_glass)
	world.call("_add_box",receiver,"ReceiverDataPlate",Vector3(.16,1.10,-.285),Vector3(.38,.15,.035),mats.sanctum_ivory,false)
	var label := world.call("_add_label",receiver,"SPARK\nRECEIVER",Vector3(.16,1.10,-.33),Color("214f5c"),12) as Label3D
	label.pixel_size=.012
	label.outline_size=0
	label.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	label.rotation.y=PI
	_set_spark_receiver_progress(receiver,int(station.current_state.get("progress",0)))
	station.progress_changed.connect(func(_save_id: String, current: int, _total: int):
		_set_spark_receiver_progress(receiver,current))


static func _set_spark_receiver_progress(receiver: Node3D, progress: int) -> void:
	for index in 3:
		var cell := receiver.get_node_or_null("ChargeCell_%02d"%(index+1)) as MeshInstance3D
		if cell != null:
			cell.material_override=cell.get_meta("active_material") if index < progress else cell.get_meta("inactive_material")

static func _connect_garden_services(world: MindSparkWorldOne, echo: Node3D, controls: Node) -> void:
	var mats: Dictionary=world.get("_materials")
	var manifold := Node3D.new()
	manifold.name="GardenReceivingManifold"
	manifold.position=Vector3(-52,.05,24)
	echo.add_child(manifold)
	world.call("_add_cylinder",manifold,"IvoryFoundation",Vector3(0,.4,0),3.2,.8,mats.sanctum_ivory,true,24)
	world.call("_add_cylinder",manifold,"TealHousing",Vector3(0,1.4,0),2.4,1.4,mats.bio_gunmetal,true,24)
	world.call("_add_torus",manifold,"BrassCrown",Vector3(0,2.1,0),2.1,2.45,mats.astral_brass)
	world.call("_add_sphere",manifold,"ReceivingCrystal",Vector3(0,2.2,0),Vector3(.8,1.3,.8),mats.arrival_glass)
	# Solid service drops stay behind each instrument. The interconnecting runs
	# stay buried; progress pulses briefly reveal the route without floor lines.
	for i in ECHO_IDS.size():
		var control := controls.get_node("PuzzleControl_"+ECHO_IDS[i]) as Node3D
		var anchor := Node3D.new()
		anchor.name="GardenServicePort"
		anchor.position=Vector3(1.3,.6,0)
		control.add_child(anchor)
		var start := echo.to_local(anchor.global_position)
		var below := Vector3(start.x,.06,start.z)
		var angle := TAU*float(i)/6.0
		var port_direction := Vector3(cos(angle),0,sin(angle))
		var finish := Vector3(-52,.06,24)+port_direction*3.1
		var socket := world.call("_add_cylinder",manifold,"ChannelPort_%02d"%i,port_direction*2.45+Vector3.UP*1.4,.28,.32,mats.astral_brass,false,12) as Node3D
		socket.quaternion=Quaternion(Vector3.UP,port_direction)
		world.call("_add_sphere",manifold,"ChannelReading_%02d"%i,port_direction*2.63+Vector3.UP*1.4,Vector3.ONE*.14,mats.arrival_glass)
		world.call("_add_cable_between",echo,"GardenServiceDrop_%02d"%i,start,below,.16,.16,mats.astral_brass,8)
		_solid_box(echo,"GardenServiceDropBody_%02d"%i,start.lerp(below,.5),Vector3(.38,maxf(.1,absf(start.y-below.y)),.38))
		for j in 3:
			var pulse := echo.get_node("EchoRootPulse_%02d_%02d"%[i+1,j+1]) as Node3D
			pulse.set_meta("path_start",below)
			pulse.set_meta("path_end",finish)
			pulse.scale=Vector3.ONE*.3
	world.call("_add_box",manifold,"IvoryReceiverPlaque",Vector3(0,1.35,2.4),Vector3(3.4,.5,.12),mats.sanctum_ivory,false)
	var title := world.call("_add_label",manifold,"6-CHANNEL RECEIVER",Vector3(0,1.35,2.48),Color("214f5c"),18) as Label3D
	title.pixel_size=.014
	title.outline_size=0
	title.billboard=BaseMaterial3D.BILLBOARD_DISABLED
