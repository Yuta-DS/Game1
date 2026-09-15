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
const Layout := preload("res://scripts/heart_melody/heart_garden_layout.gd")
const TreeModel := preload("res://assets3D/heart_melody/island_one/glb/faceted_tree.glb")
const PlanterModel := preload("res://assets3D/heart_melody/island_one/glb/feeling_planter.glb")
const DrumModel := preload("res://assets3D/heart_melody/island_one/glb/flower_drum.glb")
const GateModel := preload("res://assets3D/heart_melody/island_one/glb/heart_gate_arch.glb")
const RouteStoneModel := preload("res://assets3D/heart_melody/island_one/glb/heart_route_stone.glb")
const BenchModel := preload("res://assets3D/heart_melody/island_one/glb/song_memory_bench.glb")
const LanternModel := preload("res://assets3D/heart_melody/island_one/glb/comfort_lantern.glb")
const BlossomModel := preload("res://assets3D/heart_melody/island_one/glb/listening_blossom.glb")
const PLANTERS := [Vector3(-38,0,-19), Vector3(-24,0,19), Vector3(-6,0,-8)]
const DRUMS := [Vector3(24,0,-16), Vector3(24,0,16), Vector3(38,0,0)]
const ARRIVAL := Vector3(-88,2,0)
const CLEARINGS := [Vector3(58,0,-20), Vector3(74,0,18)]
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
var _seed_shortcut: Node3D
var _seed_shortcut_blocker: Node3D
var _note_player: AudioStreamPlayer
var _playing := false
var _previous_speed := 10.0
var _previous_blocking := true
var _camera: Camera3D
var _encounter: Node3D
var _encounter_index := -1
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
var _restored_dressing: Node3D
var _seeded_dressing: Node3D
var _grass_surfaces: Array[MeshInstance3D] = []
var _restoration_glow: OmniLight3D


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
	_apply_audio_settings()
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
	match str(state.data.checkpoint):
		"planter_court": return Vector3(-24, 2, 19)
		"drum_garden": return Vector3(38, 2.6, 0)
		"restored_garden": return Vector3(94, 2.6, 0)
	return ARRIVAL


func get_route_segments() -> Array:
	return route_segments.duplicate(true)


func _build_ground() -> void:
	var result := Layout.build(self)
	route_segments = result.route_segments
	_bridge = result.bridge
	_bridge_blocker = result.bridge_blocker
	_seed_shortcut = result.seed_shortcut
	_seed_shortcut_blocker = result.seed_shortcut_blocker
	for surface in result.root.find_children("ContinuousGrassTop", "MeshInstance3D", true, false):
		_grass_surfaces.append(surface as MeshInstance3D)


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
	var gate := GateModel.instantiate() as Node3D
	gate.name = "AuthoredHeartGate"
	gate.position = Vector3(-94, 0, 0)
	gate.scale = Vector3.ONE * 0.75
	entry.add_child(gate)
	for side in [-1.0, 1.0]:
		Kit.box_collider(entry, "GatePierCollision", Vector3(-94, 2.5, side * 3.6),
			Vector3(1.4, 5.0, 1.5))
	_register("return_gate",Vector3(-88,0,0),"Return to the Castle")
	Kit.sign_text(entry,"QUIET MEADOW",Vector3(-94,9.6,0),30)
	_register("arrival_bloom",Vector3(-68,0,0),"Rest at the Arrival Bloom")
	Kit.flower(entry,Vector3(-68,0.8,0),1.5,"ivory")
	_register("route_stone",Vector3(-66,0,-7),"Open the Heart Garden map")
	var route_stone := RouteStoneModel.instantiate() as Node3D
	route_stone.position = Vector3(-66,0,-10)
	route_stone.scale = Vector3.ONE * 0.75
	entry.add_child(route_stone)
	for i in 3:
		var root := PlanterModel.instantiate() as Node3D
		root.name = "FeelingPlanter%d" % i
		root.position = PLANTERS[i]
		root.scale = Vector3.ONE * 1.3
		add_child(root)
		Kit.cylinder_collider(self, "PlanterCollision%d" % i,
			PLANTERS[i] + Vector3.UP * 0.65, 1.5, 1.3)
		var bloom := root.find_child("GrowingBloom",true,false) as Node3D
		blooms.append(bloom)
		_register("planter_%d"%i,PLANTERS[i]+Vector3(0,0,3),"Plant a Feeling Seed %d"%(i+1))
		Kit.sign_text(root,"SEED %d"%(i+1),Vector3(0,3.3,0),22)
	for i in 3:
		var root := DrumModel.instantiate() as Node3D
		root.name = "DrumFlower%d" % i
		root.position = DRUMS[i]
		root.scale = Vector3.ONE * 1.25
		add_child(root)
		Kit.cylinder_collider(self, "DrumCollision%d" % i,
			DRUMS[i] + Vector3.UP * 0.45, 1.35, 0.9)
		var petals := root.find_child("MovingPetals",true,false) as Node3D
		for part in petals.get_children():
			if part is MeshInstance3D and str(part.name).begins_with("Petal"):
				part.material_override = Kit.material("pink" if i == 0 else ("blue" if i == 1 else "ivory"))
		drums.append(petals)
		Kit.sign_text(root,State.SYMBOLS[i].capitalize(),Vector3(0,3.5,0),30)
		_register("drum_%d"%i,DRUMS[i]+Vector3(0,0,3),"Play the %s flower" % State.SYMBOLS[i])
	_register("phrase",Vector3(10,0,3),"Arrange the garden phrase")
	var blossom := BlossomModel.instantiate() as Node3D
	blossom.name = "ListeningBlossom"
	blossom.position = Vector3(10,0,0)
	blossom.scale = Vector3.ONE * 1.15
	add_child(blossom)
	Kit.sign_text(self,"LISTEN • PLAY • CONFIRM",Vector3(10,4.6,0),22)
	_build_bench(Vector3(-56,0,-11),"bench_arrival")
	_build_bench(Vector3(15,0,25),"bench_rhythm")
	_build_lantern(Vector3(-58,0,8),"lantern_arrival")
	_build_lantern(Vector3(50,0,-5),"lantern_mid")
	for index in 2:
		var clearing: Vector3 = CLEARINGS[index]
		_register("encounter_%d"%index,clearing+Vector3(0,0,-5),
			"Enter Blight clearing %d"%(index+1))
		Kit.sign_text(self,"BLIGHT CLEARING %d\nSTEP ASIDE • STRIKE DURING THE PAUSE"%(index+1),
			clearing+Vector3(0,3.5,-10),18)
		for side in [-1.0,1.0]:
			Kit.flower(self,clearing+Vector3(side*7,0.8,8),1.1,"leaf_light")
	_build_environment_dressing()


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
	for item in [["mayor_milo",Vector3(-78,0,5),"Milo"], ["guardian_angel",Vector3(-74,0,-7),"Mother Guardian"]]:
		var scene := load("res://scenes/mind_spark/cast/%s.tscn" % item[0]) as PackedScene
		var guide := scene.instantiate() as Node3D
		guide.position = item[1]
		guide.scale = Vector3.ONE * 0.4
		add_child(guide)
		guide.get_node("DialogueLabel").visible = false
		_register(str(item[0]),item[1]+Vector3(0,0,3),"Talk with %s"%item[2])


func _build_bench(at: Vector3, id: String) -> void:
	var bench := BenchModel.instantiate() as Node3D
	bench.name = "SongMemoryBench"
	bench.position = at
	bench.scale = Vector3.ONE * 0.8
	add_child(bench)
	Kit.box_collider(self, "BenchCollision", at + Vector3(0,0.8,0), Vector3(5.0,1.6,1.8))
	_register(id,at+Vector3(0,0,3.3),"Song Memory Bench")


func _build_lantern(at: Vector3, id: String) -> void:
	var lantern := LanternModel.instantiate() as Node3D
	lantern.name = "ComfortLantern"
	lantern.position = at
	lantern.scale = Vector3.ONE * 0.8
	add_child(lantern)
	Kit.cylinder_collider(self, "LanternCollision", at + Vector3.UP * 1.7, 0.65, 3.4)
	_register(id,at+Vector3(2.5,0,2.5),"Rest at the Comfort Lantern")


func _build_environment_dressing() -> void:
	_seeded_dressing = Node3D.new()
	_seeded_dressing.name = "SeededGardenResponse"
	add_child(_seeded_dressing)
	_add_flower_multimesh(_seeded_dressing, "SeededFlowerBank", [Vector3(-44,0.7,-25),
		Vector3(-31,0.7,27), Vector3(-10,0.7,-15), Vector3(15,0.7,-24),
		Vector3(16,0.7,24)], "pink")
	_restored_dressing = Node3D.new()
	_restored_dressing.name = "RestoredGardenResponse"
	add_child(_restored_dressing)
	var restored_points: Array[Vector3] = []
	for index in 16:
		var x := lerpf(42.0, 94.0, float(index) / 15.0)
		var side := -1.0 if index % 2 == 0 else 1.0
		restored_points.append(Vector3(x, 0.7, side * (7.0 + float(index % 3) * 2.0)))
	_add_flower_multimesh(_restored_dressing, "RestoredFlowerWave", restored_points, "leaf_light")
	_restoration_glow = OmniLight3D.new()
	_restoration_glow.name = "RestoredGardenGlow"
	_restoration_glow.position = Vector3(38, 8, 0)
	_restoration_glow.light_color = Color("ffd99a")
	_restoration_glow.light_energy = 0.55
	_restoration_glow.omni_range = 42.0
	_restoration_glow.shadow_enabled = false
	add_child(_restoration_glow)


func _add_flower_multimesh(parent: Node3D, label: String, points: Array[Vector3], color: String) -> void:
	var bank := MultiMeshInstance3D.new()
	bank.name = label
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = Kit.facet_mesh(Vector3(0.65, 0.28, 0.48))
	multimesh.instance_count = points.size()
	for index in points.size():
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, points[index]))
	bank.multimesh = multimesh
	bank.material_override = Kit.material(color)
	parent.add_child(bank)


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
	var seed_route_ready := state.planted_count() == 3
	if _seeded_dressing != null: _seeded_dressing.visible = state.planted_count() > 0
	if _restored_dressing != null: _restored_dressing.visible = state.complete()
	if _restoration_glow != null: _restoration_glow.visible = state.complete()
	var grass_color := Color("a8ce69") if state.complete() else (
		Color("9fc162") if state.planted_count() > 0 else Color("91ba59"))
	for surface in _grass_surfaces:
		if surface.material_override is StandardMaterial3D:
			(surface.material_override as StandardMaterial3D).albedo_color = grass_color
	_seed_shortcut.visible = seed_route_ready
	for shape in _seed_shortcut.find_children("*","CollisionShape3D",true,false):
		shape.set_deferred("disabled",not seed_route_ready)
	_seed_shortcut_blocker.visible = not seed_route_ready
	for shape in _seed_shortcut_blocker.find_children("*","CollisionShape3D",true,false):
		shape.set_deferred("disabled",seed_route_ready)
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
		var local_player := to_local(player.global_position)
		var clearing_radius := 14.0
		if local_player.distance_to(CLEARINGS[_encounter_index]) > clearing_radius + 12.0:
			_clear_encounter()
			_feedback(true,"The Blight settles when you leave. Return when you are ready.")
			return
		var resting := panel != null and panel.visible
		for enemy in _encounter.get_children():
			enemy.suspended = resting
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
	if event.is_action_pressed("heart_help"):
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
	if _local_map != null and not _local_map.expanded:
		_local_map.visible = size.x >= 900


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
	elif id == "phrase" or id.begins_with("bench_"):
		_heading("Song Memory\nLeaf • Sun • Droplet")
		_button("Hear the garden phrase",play_phrase.bind(State.PHRASE))
		_button("Hear my arrangement",func(): play_phrase(state.data.phrase.duplicate()))
		for i in 3:
			_button("Play %s"%State.SYMBOLS[i].capitalize(),_input_note.bind(i))
		_button("Undo last note",func(): use_object("phrase",&"undo"))
		_button("Reset arrangement",func(): use_object("phrase",&"reset"))
		_button("Confirm phrase",func(): use_object("phrase",&"confirm"))
		_button("Request a hint",_request_phrase_hint)
		_button("Show a slow demonstration",play_phrase.bind(State.PHRASE, 1.15))
	elif id.begins_with("lantern_") or id == "arrival_bloom":
		_heading("Comfort Lantern\nRest as often as you need.")
		_button("Restore health",func():
			if player != null: player.call("heal",100)
			state.set_checkpoint("drum_garden" if id == "lantern_mid" else ("arrival" if id == "arrival_bloom" else str(state.data.checkpoint)))
			_feedback(true,state.objective()))
	elif id.begins_with("encounter_"):
		var clearing_index := int(id.get_slice("_",1))
		_heading("Release the Blight\nStep out of the marked attack, then strike during the pause.")
		_button("Enter the clearing",_start_encounter.bind(clearing_index))
	elif id == "route_stone":
		_heading("Heart Garden Map\nThe gold trail leads from the World Gate to River Song.")
		_button("Toggle full map",_toggle_map)
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
		for key in ["puzzle_help","combat_assist","reduced_motion","muted"]:
			_button("%s: %s"%[key.replace("_"," ").capitalize(),"on" if state.data.settings[key] else "off"],_toggle_setting.bind(key))
		_button("Music volume: %d%%"%roundi(float(state.data.settings.music_volume)*100.0),_cycle_volume.bind("music_volume"))
		_button("Effects volume: %d%%"%roundi(float(state.data.settings.effects_volume)*100.0),_cycle_volume.bind("effects_volume"))
	_button("Return to the garden",_close_panel)
	for child in panel_content.get_children():
		if child is Button:
			child.grab_focus()
			break


func _preview_seed(index: int, choice: String) -> void:
	_preview_choice = choice
	_preview_bloom(index, choice)
	open_control("seed_preview")
	for child in panel_content.get_children():
		panel_content.remove_child(child)
		child.queue_free()
	_heading("%s seed\nListen, then plant when you are ready." % ("Sound" if choice == "sound" else choice.capitalize()))
	var preview_symbol := Label.new()
	preview_symbol.text = "◆  %s  •  %s note" % [choice.capitalize(), State.SYMBOLS[index].capitalize()]
	preview_symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_symbol.add_theme_font_size_override("font_size", 26)
	preview_symbol.add_theme_color_override("font_color", Color(str(Kit.COLORS[FEELING_COLORS[choice]])))
	panel_content.add_child(preview_symbol)
	_button("Preview note",play_note.bind(index))
	_button("Plant this seed",func():
		var result := use_object("planter_%d"%index,&"plant",choice)
		if result.accepted:
			play_note(index)
			_close_panel())
	_button("Change choice",func():
		_restore()
		open_control("planter_%d"%index))
	_button("Cancel",func():
		_restore()
		_close_panel())
	for child in panel_content.get_children():
		if child is Button:
			child.grab_focus()
			break


func _preview_bloom(index: int, choice: String) -> void:
	if index < 0 or index >= blooms.size(): return
	blooms[index].scale = Vector3(0.72, 0.9, 0.72)
	for part in blooms[index].get_children():
		if part is MeshInstance3D and str(part.name).begins_with("Petal"):
			part.material_override = Kit.material(FEELING_COLORS[choice])


func _request_phrase_hint() -> void:
	var result := use_object("phrase", &"hint")
	if not result.accepted: return
	var next_index := mini(state.data.phrase.size(), State.PHRASE.size() - 1)
	var needed_symbol: String = State.PHRASE[next_index]
	var drum_index := State.SYMBOLS.find(needed_symbol)
	if drum_index >= 0:
		play_note(drum_index)
	if int(state.data.get("hint_level", 0)) >= 3:
		play_phrase(State.PHRASE, 1.15)


func _toggle_setting(key: String) -> void:
	state.set_setting(key,not state.data.settings[key])
	_apply_audio_settings()
	open_control("help")


func _cycle_volume(key: String) -> void:
	var current := float(state.data.settings[key])
	state.set_volume(key, 0.0 if current >= 0.99 else minf(1.0, current + 0.1))
	_apply_audio_settings()
	open_control("help")


func _apply_audio_settings() -> void:
	if _note_player != null:
		_note_player.volume_db = linear_to_db(maxf(0.001, float(state.data.settings.effects_volume)))
	if _ambience != null:
		_ambience.volume_db = linear_to_db(maxf(0.001, float(state.data.settings.music_volume))) - 12.0
	if bool(state.data.settings.muted):
		if _note_player != null: _note_player.stop()
		if _ambience != null: _ambience.stop()


func _toggle_map() -> void:
	if _local_map == null:
		return
	_local_map.expanded = not _local_map.expanded
	_local_map.visible = true
	if _local_map.expanded:
		_local_map.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_local_map.position = Vector2(-260,-170)
		_local_map.size = Vector2(520,340)
	else:
		_local_map.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_local_map.offset_left = -240
		_local_map.offset_right = -15
		_local_map.offset_top = 15
		_local_map.offset_bottom = 165


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


func play_phrase(phrase: Array, spacing := 0.8) -> void:
	if _playing: return
	_playing = true
	for symbol in phrase:
		var index := State.SYMBOLS.find(symbol)
		if index >= 0: play_note(index)
		await get_tree().create_timer(spacing).timeout
	_playing = false


func _start_encounter(clearing_index := -1) -> void:
	if not state.data.rhythm_solved:
		_feedback(false,"Wake the drum flowers before entering this clearing.")
		return
	if state.complete():
		_feedback(true,"The garden is already safe.")
		return
	if clearing_index != state.current_wave():
		_feedback(false,"Follow the gold trail to clearing %d."%(state.current_wave()+1))
		return
	_close_panel()
	if _encounter != null: return
	_encounter = Node3D.new()
	_encounter.name = "GardenEncounter"
	add_child(_encounter)
	_encounter_index = clearing_index
	_defeated.clear()
	var ids: Array = State.WAVES[state.current_wave()]
	for i in ids.size():
		var enemy := Enemy.new()
		enemy.enemy_id = ids[i]
		enemy.slime = str(ids[i]).contains("slime")
		enemy.player = player
		enemy.position = CLEARINGS[clearing_index]+Vector3(0,0,(-5 if i == 0 else 5))
		enemy.leash_radius = 12.5
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
	_encounter_index = -1
	_defeated.clear()


func _identity(id: String, axis: String, side: String) -> void:
	if not side.is_empty():
		var tracker := get_node_or_null("/root/PlayerIdentityTracker")
		var context := {"canonical_quest_id": State.QUEST_ID, "task_id": State.PLANT_TASK if id in ["HM_ID_01", "HM_ID_02"] else State.RHYTHM_TASK, "source": "island_one_reflection"}
		if tracker == null or not tracker.record_evidence(id,axis,side,"heart_melody",context):
			_feedback(false,"Your choice could not be saved. You can retry or keep it private.")
			return
	state.dismiss_identity(id)
	open_control("reflections")
