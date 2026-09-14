class_name HeartGardenWorld
extends Node3D

signal return_requested
signal quest_completed

const State := preload("res://scripts/heart_melody/heart_garden_state.gd")
const Kit := preload("res://scripts/heart_melody/heart_nature_kit.gd")
const Enemy := preload("res://scripts/heart_melody/heart_garden_enemy.gd")
const GardenObject := preload("res://scripts/heart_melody/heart_garden_object.gd")
const Catalog := preload("res://scripts/heart_melody/heart_garden_catalog.gd")
const GardenMap := preload("res://scripts/heart_melody/heart_garden_map.gd")
const TreeModel := preload("res://assets3D/heart_melody/island_one/glb/faceted_tree.glb")
const PlanterModel := preload("res://assets3D/heart_melody/island_one/glb/feeling_planter.glb")
const DrumModel := preload("res://assets3D/heart_melody/island_one/glb/flower_drum.glb")
const PLANTERS := [Vector3(-46,0,-22), Vector3(-24,0,-28), Vector3(-6,0,-16)]
const DRUMS := [Vector3(4,0,5), Vector3(12,0,3), Vector3(20,0,5)]
const ARRIVAL := Vector3(-70,2,0)
const CLEARING := Vector3(54,0,0)
const FEELING_COLORS := {"joy":"pink", "sadness":"blue", "frustration":"d78c6b",
	"fear":"b7a2ce", "peace":"leaf_light", "hope":"gold", "sound":"ivory"}

@export var save_path := State.SAVE_PATH
@export var persist_progress := true
@export var build_hud := true
@export var defer_build := false
var state: State
var player: CharacterBody3D
var active := false
var built := false
var controls: Dictionary = {}
var blooms: Array[Node3D] = []
var drums: Array[Node3D] = []
var panel: PanelContainer
var panel_content: VBoxContainer
var hud: CanvasLayer
var objective_label: Label
var feedback_label: Label
var prompt_label: Label
var _selected := ""
var _preview_choice := "sound"
var _bridge: Node3D
var _bridge_blocker: Node3D
var _note_player: AudioStreamPlayer
var _playing := false
var _previous_speed := 10.0
var _previous_blocking := true
var _camera: Camera3D
var _encounter: Node3D
var _defeated: Array = []
var _combat_paused := false
var _restoration_seen := false
var _bridge_opening := false
var _ambience: AudioStreamPlayer
var _ambient_clock := 0.0
var catalog: Dictionary = {}
var route_segments: Array = []
var _local_map: Control
var _previous_maps: Dictionary = {}
var _legacy_combat_help: CanvasLayer


func _ready() -> void:
	catalog = Catalog.read()
	state = State.new(save_path, persist_progress)
	state.load_progress()
	_restoration_seen = state.complete()
	state.changed.connect(_restore)
	state.feedback.connect(_feedback)
	if not defer_build: ensure_world_built()


func ensure_world_built() -> bool:
	if built: return true
	var errors := Catalog.validate(catalog)
	if not errors.is_empty():
		push_error("Heart garden catalog: "+"; ".join(errors))
		return false
	built = true
	_build_ground()
	_build_garden()
	_build_cast()
	_note_player = AudioStreamPlayer.new()
	add_child(_note_player)
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = -24
	add_child(_ambience)
	if build_hud: _build_ui()
	_restore()
	return true


func activate(body: CharacterBody3D) -> void:
	if not ensure_world_built(): return
	player = body
	_camera = get_viewport().get_camera_3d()
	_previous_speed = float(player.get("speed"))
	_previous_blocking = bool(player.get("blocking_available"))
	var journey := get_node_or_null("/root/JourneyState")
	if journey != null and int(journey.get("heart_campaign_version")) >= 2:
		player.set("blocking_available",journey.has_treasure("harmony_jewel"))
	player.set("speed", 10.0)
	_legacy_combat_help = player.get_node_or_null("CombatHelpHUD") as CanvasLayer
	if _legacy_combat_help != null: _legacy_combat_help.visible = false
	player.global_position = to_global(checkpoint_position())
	player.velocity = Vector3.ZERO
	active = true
	for map in get_tree().root.find_children("*","Control",true,false):
		var script = map.get_script()
		if script != null and script.resource_path == "res://scripts/art_castle_minimap.gd":
			_previous_maps[map] = map.visible
			map.visible = false
	if hud != null: hud.visible = true
	_feedback(true, "Milo: Plant three seeds, then help the flowers find their song. Q: use • H: help")


func deactivate() -> void:
	_close_panel()
	active = false
	_clear_encounter()
	if player != null: player.set("speed", _previous_speed)
	if player != null: player.set("blocking_available",_previous_blocking)
	if _legacy_combat_help != null: _legacy_combat_help.visible = true
	if _ambience != null: _ambience.stop()
	if _note_player != null: _note_player.stop()
	for map in _previous_maps:
		if is_instance_valid(map): map.visible = _previous_maps[map]
	_previous_maps.clear()
	if hud != null: hud.visible = false


func checkpoint_position() -> Vector3:
	return ARRIVAL if state.data.checkpoint == "arrival" else Vector3(12,2,17)


func _build_ground() -> void:
	var terrain := Node3D.new()
	terrain.name = "TerrainAndPaths"
	add_child(terrain)
	for pair in [[Vector3(-36,0,0),52.0], [Vector3(42,0,0),60.0]]:
		var at: Vector3 = pair[0]
		var radius: float = pair[1]
		Kit.cylinder(terrain,"IslandCliff",at+Vector3(0,-14,0),radius,27,"stone",false,14,radius*0.56)
		Kit.cylinder(terrain,"GrassDeck",at+Vector3(0,-0.5,0),radius,1,"grass",true,14)
		# Polygon rails match the same fourteen-sided foundation. Shared interior edges are omitted.
		for i in 14:
			var a := at + Vector3(sin(TAU*i/14.0),0,cos(TAU*i/14.0)) * (radius-1.0)
			var b := at + Vector3(sin(TAU*(i+1)/14.0),0,cos(TAU*(i+1)/14.0)) * (radius-1.0)
			var mid := (a+b)*0.5
			var other: Vector3 = Vector3(42,0,0) if at.x < 0 else Vector3(-36,0,0)
			var other_radius := 60.0 if at.x < 0 else 52.0
			if mid.distance_to(other) < other_radius-1.0: continue
			# East exit connects to the protected departure terrace below.
			if mid.x > 94 and absf(mid.z) < 15: continue
			Kit.branch(terrain,"RootRail",a+Vector3.UP*1.3,b+Vector3.UP*1.3,0.25,"wood",true)
			Kit.branch(terrain,"RailPost",a,a+Vector3.UP*1.7,0.28,"wood",true)
	for route in [[Vector3(-72,0,0),Vector3(-46,0,-22)],
		[Vector3(-46,0,-22),Vector3(-24,0,-28)], [Vector3(-24,0,-28),Vector3(-6,0,-16)],
		[Vector3(-6,0,-16),Vector3(-6,0,12)], [Vector3(-6,0,12),Vector3(12,0,18)],
		[Vector3(12,0,18),Vector3(54,0,0)],
		[Vector3(54,0,0),Vector3(96,0,0)], [Vector3(-70,0,0),Vector3(-42,0,16)],
		[Vector3(-42,0,16),Vector3(12,0,12)]]:
		_path(terrain,route[0],route[1],4.0)
	# Deterministic sparse trees and stones, away from the control and combat aprons.
	for at in [Vector3(-66,0,-24),Vector3(-57,0,29),Vector3(-32,0,34),
		Vector3(-25,0,-43),Vector3(5,0,-36),Vector3(30,0,40),Vector3(72,0,33),Vector3(72,0,-34)]:
		var tree := TreeModel.instantiate() as Node3D
		tree.position = at
		tree.scale = Vector3.ONE*0.9
		terrain.add_child(tree)
		if tree.find_children("*","CollisionShape3D",true,false).is_empty():
			(tree.find_child("Trunk",true,false) as MeshInstance3D).create_trimesh_collision()
	for at in [Vector3(-72,0,18),Vector3(-60,0,-36),Vector3(-8,0,38),Vector3(14,0,-32),
		Vector3(83,0,24),Vector3(86,0,-22)]:
		Kit.facet(terrain,"Stone",at+Vector3.UP*1.8,Vector3(3,2.5,2.2),"rock",true)
	for i in 26:
		var at := Vector3(-65+float(i%13)*11,0, -37 if i<13 else 31)
		Kit.flower(terrain,at+Vector3.UP*0.45,0.55,"pink" if i%2 == 0 else "ivory")
		Kit.facet(terrain,"GrassTuft",at+Vector3(1.3,0.5,1),Vector3(0.35,0.8,0.4),"leaf")
	Kit.cylinder(terrain,"ShallowPool",Vector3(-48,0.035,8),4,0.04,"blue",false,10)
	_build_departure(terrain)


func _path(parent: Node3D,a: Vector3,b: Vector3,width: float) -> void:
	route_segments.append([a,b])
	var slab := Kit.box(parent,"GardenPath",(a+b)*0.5+Vector3.UP*0.025,
		Vector3(width,0.04,a.distance_to(b)),"path")
	slab.rotation.y = atan2(b.x-a.x,b.z-a.z)


func _register(id: String, at: Vector3, label: String) -> void:
	var anchor := GardenObject.new()
	anchor.name = id
	anchor.save_id = "heart_melody.island_one."+id
	anchor.state = state
	anchor.role = "planter" if id.begins_with("planter_") else ("drum" if id.begins_with("drum_") else id)
	if anchor.role in ["planter","drum"]: anchor.index = int(id.get_slice("_",1))
	anchor.position = at
	add_child(anchor)
	controls[id] = {"anchor": anchor, "label": label}


func use_object(id: String, action: StringName, value: Variant = null) -> Dictionary:
	if not controls.has(id): return {"accepted": false, "message": "Unknown garden object."}
	return controls[id].anchor.interact(action,value)


func _build_garden() -> void:
	var entry := Node3D.new()
	entry.name = "ArrivalForecourt"
	add_child(entry)
	for side in [-1,1]:
		Kit.branch(entry,"GateRoot",Vector3(-76,0,side*4),Vector3(-76,7,side*3),0.7,"wood",true)
		Kit.branch(entry,"GateCrown",Vector3(-76,7,side*3),Vector3(-76,10,0),0.65)
		Kit.flower(entry,Vector3(-76,8,side*2),1.0)
	_register("return_gate",Vector3(-72,0,0),"Return to the Castle")
	Kit.sign_text(entry,"QUIET MEADOW",Vector3(-76,10.5,0),40)
	for i in 3:
		var root := PlanterModel.instantiate() as Node3D
		root.name = "FeelingPlanter%d" % i
		root.position = PLANTERS[i]
		add_child(root)
		(root.find_child("StoneNest",true,false) as MeshInstance3D).create_trimesh_collision()
		var bloom := root.find_child("GrowingBloom",true,false) as Node3D
		blooms.append(bloom)
		_register("planter_%d"%i,PLANTERS[i]+Vector3(0,0,3.5),"Plant a Feeling Seed %d"%(i+1))
		Kit.sign_text(root,"SEED %d"%(i+1),Vector3(0,3.3,0),26)
	for i in 3:
		var root := DrumModel.instantiate() as Node3D
		root.name = "DrumFlower%d" % i
		root.position = DRUMS[i]
		add_child(root)
		(root.find_child("LivingBase",true,false) as MeshInstance3D).create_trimesh_collision()
		var petals := root.find_child("MovingPetals",true,false) as Node3D
		for part in petals.get_children():
			if part is MeshInstance3D and str(part.name).begins_with("Petal"):
				part.material_override = Kit.material("pink" if i == 0 else ("blue" if i == 1 else "ivory"))
		drums.append(petals)
		Kit.sign_text(root,State.SYMBOLS[i].capitalize(),Vector3(0,3.5,0),30)
		_register("drum_%d"%i,DRUMS[i]+Vector3(0,0,4),"Play the %s flower" % State.SYMBOLS[i])
	_register("phrase",Vector3(12,0,18),"Arrange the garden phrase")
	Kit.cylinder(self,"PhraseStone",Vector3(12,0.35,15),1.4,0.7,"rock",true,6)
	Kit.sign_text(self,"LISTEN • PLAY • CONFIRM",Vector3(12,2.8,15),25)
	Kit.box(self,"MemoryBench",Vector3(-42,1,16),Vector3(5,0.5,1.8),"wood",true)
	for x in [-43.7,-40.3]: Kit.box(self,"BenchLeg",Vector3(x,0.5,16),Vector3(0.5,1,1.2),"stone",true)
	_register("bench",Vector3(-42,0,19),"Song Memory Bench")
	Kit.branch(self,"LanternBranch",Vector3(-49,0,18),Vector3(-49,4,18),0.25,"wood",true)
	Kit.facet(self,"SeedpodLantern",Vector3(-49,3,18),Vector3(0.7,1.1,0.7),"gold")
	_register("lantern",Vector3(-47,0,20),"Rest at the Comfort Lantern")
	_register("encounter",Vector3(35,0,3),"Enter the Blight clearing")
	Kit.sign_text(self,"BLIGHT CLEARING\nStep aside, then strike",Vector3(38,3,-7),28)
	Kit.cylinder(self,"ClearingGround",CLEARING+Vector3.UP*0.035,17,0.05,"path",false,14)


func _build_departure(parent: Node3D) -> void:
	_bridge = Node3D.new()
	_bridge.name = "RestoredRootCrossing"
	parent.add_child(_bridge)
	for i in 8:
		Kit.box(_bridge,"Plank",Vector3(99+i*1.5,-0.2,0),Vector3(1.6,0.4,5),"wood",true)
	for side in [-1,1]:
		Kit.branch(_bridge,"BridgeRoot",Vector3(97,1.4,side*2.4),Vector3(112,1.4,side*2.4),0.3,"wood",true)
		Kit.branch(parent,"DepartureEdgeRoot",Vector3(97,1.4,side*2.5),Vector3(98,1.4,side*13),0.3,"wood",true)
	Kit.cylinder(parent,"Overlook",Vector3(115,-0.5,0),7,1,"grass",true,10)
	for i in 9:
		var angle := -PI*0.7+float(i)*PI*1.4/8
		var at := Vector3(115,0,0)+Vector3(cos(angle),0,sin(angle))*6
		Kit.branch(parent,"OverlookPost",at,at+Vector3.UP*1.5,0.25,"wood",true)
	_bridge_blocker = Kit.box(parent,"DormantVineBarrier",Vector3(96,1.2,0),Vector3(0.6,2.4,6),"leaf",true)
	Kit.sign_text(parent,"RIVER SONG\nComing next",Vector3(118,3.5,0),30)
	# A distant lightweight landmark, deliberately without a route into unfinished space.
	Kit.cylinder(parent,"DistantIsland",Vector3(230,-18,0),34,25,"stone",false,10,17)
	Kit.cylinder(parent,"DistantGrass",Vector3(230,-5,0),34,1,"grass",false,10)
	for i in 3:
		Kit.facet(parent,"OrganRock",Vector3(230+i*5,9,-8),Vector3(5,15+i*2,6),"rock")
		Kit.box(parent,"WaterRibbon",Vector3(229+i*5,8,-1),Vector3(2,25,0.3),"blue")


func _build_cast() -> void:
	for item in [["mayor_milo",Vector3(-62,0,7),"Milo"], ["guardian_angel",Vector3(-59,0,-8),"Mother Guardian"]]:
		var scene := load("res://scenes/mind_spark/cast/%s.tscn" % item[0]) as PackedScene
		var guide := scene.instantiate() as Node3D
		guide.position = item[1]
		guide.scale = Vector3.ONE * 0.4
		add_child(guide)
		guide.get_node("DialogueLabel").visible = false
		_register(str(item[0]),item[1]+Vector3(0,0,3),"Talk with %s"%item[2])


func _restore() -> void:
	if not built: return
	for i in blooms.size():
		var planted: bool = state.data.planters.has(str(i))
		var new_scale := Vector3.ONE if planted else Vector3(0.3,1.5,0.3)
		var was_planted := bool(blooms[i].get_meta("planted",planted))
		if planted and not was_planted and not state.data.settings.reduced_motion:
			var growth := create_tween()
			growth.tween_property(blooms[i],"scale",new_scale,1.1).set_trans(Tween.TRANS_SINE)
		else: blooms[i].scale = new_scale
		blooms[i].set_meta("planted",planted)
		var choice := str(state.data.planters.get(str(i),"sound"))
		for part in blooms[i].get_children():
			if part is MeshInstance3D and str(part.name).begins_with("Petal"):
				part.material_override = Kit.material(FEELING_COLORS[choice])
	for drum in drums:
		drum.scale = Vector3.ONE if state.planted_count() == 3 else Vector3(0.6,0.6,0.6)
	if state.complete() and not _restoration_seen:
		_restoration_seen = true
		if not state.data.settings.reduced_motion:
			_grow_crossing()
	var crossing_ready := state.complete() and not _bridge_opening
	_bridge.visible = state.complete()
	for shape in _bridge.find_children("*","CollisionShape3D",true,false): shape.set_deferred("disabled",not crossing_ready)
	_bridge_blocker.visible = not crossing_ready
	for shape in _bridge_blocker.find_children("*","CollisionShape3D",true,false): shape.set_deferred("disabled",crossing_ready)
	if objective_label != null:
		objective_label.text = "HEART MELODY • FEELING GARDEN\n%s\nGarden XP: %d" % [state.objective(),state.xp()]
	if state.data.settings.muted:
		if _note_player != null: _note_player.stop()
		if _ambience != null: _ambience.stop()


func _grow_crossing() -> void:
	_bridge_opening = true
	_bridge.position.y = -3.0
	var growth := create_tween()
	growth.tween_property(_bridge,"position:y",0.0,1.0).set_trans(Tween.TRANS_SINE)
	growth.tween_callback(func():
		_bridge_opening = false
		_restore())


func _process(delta: float) -> void:
	if not active or player == null: return
	_ambient_clock += delta
	if _ambient_clock >= 4.0 and state.planted_count() > 0 and not state.data.settings.muted:
		_ambient_clock = 0
		var note := int(Time.get_ticks_msec()/4000)%3
		_ambience.stream = _tone(note,1.6)
		_ambience.play()
	if to_local(player.global_position).y < -12 or float(player.get("current_health")) <= 0:
		_clear_encounter()
		player.global_position = to_global(checkpoint_position())
		player.velocity = Vector3.ZERO
		player.call("heal",100)
		_feedback(true,"You are safe. Your flowers and song are remembered.")
	if _encounter != null:
		var resting := to_local(player.global_position).x < 28
		for enemy in _encounter.get_children():
			enemy.suspended = resting or (panel != null and panel.visible)
			enemy.assist = bool(state.data.settings.combat_assist)
	if panel != null and panel.visible: return
	_selected = nearest_control(player.global_position)
	if prompt_label != null:
		prompt_label.text = "Q • %s" % controls[_selected].label if not _selected.is_empty() else "WASD move • Space jump • F strike • H help"


func nearest_control(global_at: Vector3) -> String:
	var nearest := ""
	var distance := 4.5
	for id in controls:
		var anchor: Marker3D = controls[id].anchor
		var d := global_at.distance_to(anchor.global_position+Vector3.UP)
		if d < distance:
			distance = d
			nearest = id
	return nearest


func _unhandled_input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		open_control("help")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and panel != null and panel.visible:
		_close_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and not _selected.is_empty():
		open_control(_selected)
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	hud = CanvasLayer.new()
	hud.name = "HeartHUD"
	hud.layer = 60
	add_child(hud)
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(overlay)
	objective_label = Label.new()
	objective_label.position = Vector2(20,20)
	objective_label.add_theme_font_size_override("font_size",22)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	objective_label.add_theme_constant_override("shadow_offset_x",2)
	objective_label.add_theme_constant_override("shadow_offset_y",2)
	overlay.add_child(objective_label)
	feedback_label = Label.new()
	feedback_label.position = Vector2(20,125)
	feedback_label.size = Vector2(560,100)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay.add_child(feedback_label)
	prompt_label = Label.new()
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	prompt_label.position = Vector2(20,-50)
	prompt_label.add_theme_font_size_override("font_size",22)
	overlay.add_child(prompt_label)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -430
	panel.offset_right = -20
	panel.offset_top = -270
	panel.offset_bottom = 270
	var style := StyleBoxFlat.new()
	style.bg_color = Color("253d32")
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel",style)
	overlay.add_child(panel)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	panel_content = VBoxContainer.new()
	panel_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_content.add_theme_constant_override("separation",9)
	scroll.add_child(panel_content)
	panel.visible = false
	hud.visible = false
	_local_map = GardenMap.new()
	_local_map.world = self
	_local_map.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_local_map.offset_left = -240
	_local_map.offset_right = -15
	_local_map.offset_top = 15
	_local_map.offset_bottom = 165
	overlay.add_child(_local_map)
	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui()
	if DisplayServer.is_touchscreen_available():
		_build_touch_controls(overlay)


func _layout_ui() -> void:
	if panel == null: return
	var size := get_viewport().get_visible_rect().size
	objective_label.size.x = minf(650,size.x-40)
	feedback_label.size.x = minf(560,size.x-40)
	feedback_label.position.y = 155 if size.x < 650 else 125
	panel.offset_left = -minf(430,size.x-10)
	panel.offset_right = -10
	panel.offset_top = -minf(270,size.y*0.45)
	panel.offset_bottom = minf(270,size.y*0.45)
	if _local_map != null: _local_map.visible = size.x >= 900


func _build_touch_controls(parent: Control) -> void:
	for item in [["↑","move_forward",Vector2(70,-175)], ["←","move_left",Vector2(15,-120)],
		["↓","move_backward",Vector2(70,-120)],["→","move_right",Vector2(125,-120)]]:
		var button := Button.new()
		button.text = item[0]
		button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		button.position = item[2]
		button.size = Vector2(52,52)
		var action: String = item[1]
		button.button_down.connect(func(): Input.action_press(action))
		button.button_up.connect(func(): Input.action_release(action))
		parent.add_child(button)
	for i in 3:
		var button := Button.new()
		button.text = ["Use","Strike","Help"][i]
		button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		button.position = Vector2(-95,-230+i*58)
		button.size = Vector2(85,52)
		if i == 0:
			button.pressed.connect(func():
				if not _selected.is_empty(): open_control(_selected))
		elif i == 1:
			button.button_down.connect(func(): Input.action_press("attack"))
			button.button_up.connect(func(): Input.action_release("attack"))
		else: button.pressed.connect(open_control.bind("help"))
		parent.add_child(button)


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",22)
	panel_content.add_child(label)


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	panel_content.add_child(button)
	return button


func open_control(id: String) -> void:
	if panel == null: return
	for child in panel_content.get_children():
		panel_content.remove_child(child)
		child.queue_free()
	panel.visible = true
	if player != null: player.call("set_input_enabled",false)
	if _camera != null: _camera.set_process_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if id.begins_with("planter_"):
		var index := int(id.get_slice("_",1))
		_heading("Feeling Seed %d\nEvery choice can bloom."%(index+1))
		for choice in State.CHOICES:
			_button("Choose a sound instead" if choice == "sound" else choice.capitalize(),_preview_seed.bind(index,choice))
	elif id.begins_with("drum_"):
		var index := int(id.get_slice("_",1))
		_heading("%s flower"%State.SYMBOLS[index].capitalize())
		_button("Play this flower",func():
			var result := use_object("drum_%d"%index,&"play")
			if result.accepted: play_note(index))
		_button("Arrange the full phrase",open_control.bind("phrase"))
	elif id in ["phrase","bench"]:
		_heading("Song Memory\nLeaf • Droplet • Sun")
		_button("Hear the garden phrase",play_phrase.bind(State.PHRASE))
		_button("Hear my arrangement",func(): play_phrase(state.data.phrase.duplicate()))
		for i in 3:
			_button("Play %s"%State.SYMBOLS[i].capitalize(),_input_note.bind(i))
		_button("Undo last note",func(): use_object("phrase",&"undo"))
		_button("Reset arrangement",func(): use_object("phrase",&"reset"))
		_button("Confirm phrase",func(): use_object("phrase",&"confirm"))
		_button("Show a slow demonstration",play_phrase.bind(State.PHRASE))
	elif id == "lantern":
		_heading("Comfort Lantern\nRest as often as you need.")
		_button("Restore health",func():
			if player != null: player.call("heal",100)
			_feedback(true,state.objective()))
	elif id == "encounter":
		_heading("Release the Blight\nStep out of the marked attack, then strike during the pause.")
		_button("Enter the clearing",_start_encounter)
	elif id == "return_gate":
		_heading("Return to the Castle\nYour garden progress will be remembered.")
		_button("Save and return",func():
			if state.save():
				deactivate()
				return_requested.emit()
			else: _feedback(false,"Could not save. Please try again before leaving."))
	elif id in ["mayor_milo","guardian_angel"]:
		_heading("Milo: Let's help the garden find its song." if id == "mayor_milo" else "Mother Guardian: Every feeling may speak here. You can also choose a sound.")
		_heading(state.objective())
		_button("Optional ways to explore",open_control.bind("reflections"))
	elif id == "reflections":
		_heading("Your choice — or keep it private\nThese never change your rewards.")
		var moments := [
			["HM_ID_01","energy","Greet Milo together","E","Listen quietly first","I"],
			["HM_ID_02","information","Listen to one note","S","Hear the whole garden","N"],
			["HM_ID_03","decisions","Follow the seed instructions","T","Imagine what would comfort the garden","F"],
			["HM_ID_04","structure","Plan my phrase first","J","Explore the flowers first","P"]]
		for moment in moments:
			if moment[0] in state.data.identity_dismissed: continue
			_button(moment[2],_identity.bind(moment[0],moment[1],moment[3]))
			_button(moment[4],_identity.bind(moment[0],moment[1],moment[5]))
			_button("Keep this choice private",_identity.bind(moment[0],moment[1],""))
			break
	else:
		_heading("Garden help\n%s"%state.objective())
		_button("Replay the clue",play_phrase.bind(State.PHRASE))
		for key in ["combat_assist","reduced_motion","muted"]:
			_button("%s: %s"%[key.replace("_"," ").capitalize(),"on" if state.data.settings[key] else "off"],_toggle_setting.bind(key))
	_button("Return to the garden",_close_panel)
	for child in panel_content.get_children():
		if child is Button:
			child.grab_focus()
			break


func _preview_seed(index: int, choice: String) -> void:
	_preview_choice = choice
	open_control("seed_preview")
	for child in panel_content.get_children():
		panel_content.remove_child(child)
		child.queue_free()
	_heading("%s seed\nListen, then plant when you are ready." % ("Sound" if choice == "sound" else choice.capitalize()))
	_button("Preview note",play_note.bind(index))
	_button("Plant this seed",func():
		var result := use_object("planter_%d"%index,&"plant",choice)
		if result.accepted:
			play_note(index)
			_close_panel())
	_button("Change choice",open_control.bind("planter_%d"%index))
	_button("Cancel",_close_panel)
	(panel_content.get_child(1) as Button).grab_focus()


func _toggle_setting(key: String) -> void:
	state.set_setting(key,not state.data.settings[key])
	open_control("help")


func _close_panel() -> void:
	if panel != null: panel.visible = false
	if player != null: player.call("set_input_enabled",true)
	if _camera != null: _camera.set_process_input(true)
	if active: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input_note(index: int) -> void:
	var result := use_object("drum_%d"%index,&"play")
	if result.accepted: play_note(index)


func _feedback(_accepted: bool, message: String) -> void:
	if feedback_label != null:
		feedback_label.text = message + ("\nYour phrase: " + " → ".join(state.data.phrase) if not state.data.phrase.is_empty() else "")


func play_note(index: int) -> void:
	_feedback(true,"%s flower"%State.SYMBOLS[index].capitalize())
	if not state.data.settings.reduced_motion and index < drums.size():
		var tween := create_tween()
		tween.tween_property(drums[index],"scale",Vector3(1.08,0.85,1.08),0.12)
		tween.tween_property(drums[index],"scale",Vector3.ONE,0.2)
	if state.data.settings.muted: return
	_note_player.stream = _tone(index,0.5)
	_note_player.play()


func _tone(index: int,duration: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	var samples := int(22050*duration)
	bytes.resize(samples*2)
	var frequency: float = [261.63,329.63,392.0][index]
	for i in samples:
		var t := float(i)/22050.0
		var sample := sin(TAU*frequency*t)*exp(-t*7.0)*minf(t*80,1.0)*0.3
		bytes.encode_s16(i*2,int(sample*32767))
	stream.data = bytes
	return stream


func play_phrase(phrase: Array) -> void:
	if _playing: return
	_playing = true
	for symbol in phrase:
		var index := State.SYMBOLS.find(symbol)
		if index >= 0: play_note(index)
		await get_tree().create_timer(0.8).timeout
	_playing = false


func _start_encounter() -> void:
	if not state.data.rhythm_solved:
		_feedback(false,"Wake the drum flowers before entering this clearing.")
		return
	if state.complete():
		_feedback(true,"The garden is already safe.")
		return
	_close_panel()
	if _encounter != null: return
	_encounter = Node3D.new()
	_encounter.name = "GardenEncounter"
	add_child(_encounter)
	_defeated.clear()
	var ids: Array = State.WAVES[state.current_wave()]
	for i in ids.size():
		var enemy := Enemy.new()
		enemy.enemy_id = ids[i]
		enemy.slime = str(ids[i]).contains("slime")
		enemy.player = player
		enemy.position = CLEARING+Vector3(0,0,(-5 if i == 0 else 5))
		enemy.released.connect(_on_enemy_released)
		_encounter.add_child(enemy)
	_feedback(true,"Step aside from the marked attack, then strike the open shell.")


func _on_enemy_released(id: String) -> void:
	if id not in _defeated: _defeated.append(id)
	var result := state.record_defeat(id)
	if not result.accepted:
		_clear_encounter.call_deferred()
		return
	if _defeated.size() == State.WAVES[state.current_wave()].size():
		var outcome := state.finish_wave(_defeated)
		if outcome.accepted:
			_clear_encounter.call_deferred()
			if state.complete():
				quest_completed.emit()
				play_phrase(State.PHRASE)


func _clear_encounter() -> void:
	if _encounter != null:
		_encounter.queue_free()
		_encounter = null
	_defeated.clear()


func _identity(id: String, axis: String, side: String) -> void:
	if not side.is_empty():
		var tracker := get_node_or_null("/root/PlayerIdentityTracker")
		if tracker == null or not tracker.record_evidence(id,axis,side,"heart_melody"):
			_feedback(false,"Your choice could not be saved. You can retry or keep it private.")
			return
	state.dismiss_identity(id)
	open_control("reflections")
