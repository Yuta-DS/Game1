class_name MindSparkWardenBoss
extends StaticBody3D

signal phase_changed(phase: int)
signal anchor_window_opened(index: int)
signal combat_stopped
signal defeated(xp_reward: int)

enum Phase { INTRO, PHASE_1, TRANSITION, PHASE_2, PHASE_3, COMPLETE }

const MAX_HEALTH := 300.0
const XP_REWARD := 150
const TELEGRAPH_SECONDS := 1.15
const RECOVERY_SECONDS := 4.0
const Foley := preload("res://scripts/mind_spark/mind_spark_foley.gd")

@onready var shell: Node3D = $VisualRoot/BlightShell
@onready var core: MeshInstance3D = $VisualRoot/CrystalCore
@onready var core_label: Label3D = $CoreLabel
@onready var storm_line: MeshInstance3D = $StormLineTelegraph
@onready var rain: GPUParticles3D = $GentleRain

var phase := Phase.INTRO
var current_health := MAX_HEALTH
var active := false
var anchors: Array[QuestObjectBase] = []
var broken_anchor_count := 0
var _cycle_time := TELEGRAPH_SECONDS
var _damage_applied := false
var _player: CharacterBody3D
var _storm_crown: Node3D
var _visual_time := 0.0
var _combat_audio: AudioStreamPlayer3D


func _ready() -> void:
	_build_combat_audio()
	_build_storm_crown()
	core.visible = false
	storm_line.visible = false
	rain.emitting = false
	_find_player.call_deferred()


func _process(delta: float) -> void:
	_visual_time += delta
	if _storm_crown != null:
		_storm_crown.rotation.y = _visual_time * (0.22 if active else 0.08)
		_storm_crown.position.y = sin(_visual_time * 1.15) * 0.35
	if core.visible:
		core.scale = Vector3.ONE * (1.0 + sin(_visual_time * 3.2) * 0.06)


func bind_anchors(new_anchors: Array[QuestObjectBase]) -> void:
	anchors = new_anchors.duplicate()
	broken_anchor_count = 0
	for index in anchors.size():
		var anchor := anchors[index]
		if not anchor.completed.is_connected(_on_anchor_completed):
			anchor.completed.connect(_on_anchor_completed.bind(index))
		if bool(anchor.current_state.get("completed", false)):
			broken_anchor_count += 1
	if broken_anchor_count >= 3:
		_open_core()


func start_battle() -> void:
	if phase == Phase.COMPLETE:
		return
	active = true
	_set_phase(Phase.PHASE_1)
	_cycle_time = TELEGRAPH_SECONDS
	storm_line.visible = true
	core_label.text = "DODGE THE WIDE STORM LINE"
	_play_combat_sound(&"warden_storm")


func reset_battle() -> void:
	current_health = MAX_HEALTH
	active = false
	broken_anchor_count = 0
	shell.visible = true
	core.visible = false
	storm_line.visible = false
	rain.emitting = false
	_set_phase(Phase.INTRO)
	for anchor in anchors:
		anchor.reset_sequence() if anchor.definition.object_kind == 3 else _reset_anchor(anchor)


func take_damage(amount: float, _source: Node = null) -> float:
	if not active or phase != Phase.PHASE_3 or amount <= 0.0:
		core_label.text = "BREAK ALL THREE OPEN ANCHORS FIRST • %d/3" % broken_anchor_count
		return 0.0
	var applied := minf(current_health, amount)
	current_health -= applied
	_play_combat_sound(&"warden_hit")
	core_label.text = "OPEN CORE • %d / 300" % ceili(current_health)
	if current_health <= 0.0:
		_free_warden()
	return applied


func restore_combat_stopped() -> void:
	current_health = 0.0
	active = false
	broken_anchor_count = 3
	shell.visible = false
	core.visible = true
	storm_line.visible = false
	_set_phase(Phase.COMPLETE)
	core_label.text = "COMBAT STOPPED • PLACE THE FINAL SPARK"


func set_gentle_rain() -> void:
	restore_combat_stopped()
	rain.emitting = true
	core_label.text = "THE STORM IS NOW GENTLE RAIN"


func _physics_process(delta: float) -> void:
	if not active or phase in [Phase.INTRO, Phase.COMPLETE, Phase.PHASE_3]:
		return
	_cycle_time -= delta
	if _cycle_time > 0.0:
		storm_line.visible = true
		return
	storm_line.visible = false
	if not _damage_applied and _player != null and _player.global_position.distance_to(global_position) < 38.0:
		_player.call("take_damage", 16.0, self)
		_damage_applied = true
		_play_combat_sound(&"warden_strike")
	var next_anchor := _next_unbroken_anchor()
	if next_anchor >= 0:
		var result := anchors[next_anchor].interact(&"dodge")
		if bool(result.get("accepted", false)):
			anchor_window_opened.emit(next_anchor)
			core_label.text = "ANCHOR %d OPEN • STRIKE THE CRYSTAL RING" % (next_anchor + 1)
	_cycle_time = RECOVERY_SECONDS + TELEGRAPH_SECONDS
	_damage_applied = false


func _on_anchor_completed(_save_id: String, _result: Dictionary, _index: int) -> void:
	broken_anchor_count = 0
	for anchor in anchors:
		if bool(anchor.current_state.get("completed", false)):
			broken_anchor_count += 1
	core_label.text = "SHIELD LAYERS • %d/3" % broken_anchor_count
	if broken_anchor_count == 1:
		_set_phase(Phase.TRANSITION)
		_set_phase(Phase.PHASE_2)
	elif broken_anchor_count >= 3:
		_open_core()


func _open_core() -> void:
	broken_anchor_count = 3
	storm_line.visible = false
	core.visible = true
	_set_phase(Phase.PHASE_3)
	core_label.text = "OPEN CRYSTAL CORE • 300 / 300"
	_play_combat_sound(&"warden_open")


func _free_warden() -> void:
	active = false
	storm_line.visible = false
	shell.visible = false
	core.visible = true
	core_label.text = "COMBAT STOPPED • PLACE THE FINAL SPARK"
	_set_phase(Phase.COMPLETE)
	_play_combat_sound(&"warden_free")
	combat_stopped.emit()
	defeated.emit(XP_REWARD)


func _next_unbroken_anchor() -> int:
	for index in anchors.size():
		if not bool(anchors[index].current_state.get("completed", false)):
			return index
	return -1


func _set_phase(next_phase: int) -> void:
	phase = next_phase
	phase_changed.emit(phase)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("Player")
	if not players.is_empty():
		_player = players[0] as CharacterBody3D


func _reset_anchor(anchor: QuestObjectBase) -> void:
	anchor.current_state["completed"] = false
	anchor.current_state["progress"] = 0
	anchor.current_state["anchor_state"] = QuestObjectBase.AnchorState.TELEGRAPH
	anchor.call("_apply_visual_state", false)


func _build_storm_crown() -> void:
	if shell.has_node("StormCrown"):
		_storm_crown = shell.get_node("StormCrown") as Node3D
		return
	_storm_crown = Node3D.new()
	_storm_crown.name = "StormCrown"
	shell.add_child(_storm_crown)
	var dark := _material(Color("102f35"), Color("27606a"), 0.36, 0.56)
	var storm := _material(Color("44334e"), Color("8d5aa6"), 0.72, 0.38)
	var brass := _material(Color("b68a3b"), Color("d2aa58"), 0.16, 0.30)
	var crystal := _material(Color("49e6ff"), Color("31d8ff"), 3.2, 0.18)

	# Three restrained casing orbits read as a damaged aether turbine shield;
	# violet remains corruption feedback instead of becoming the whole landmark.
	for index in 3:
		var ring := MeshInstance3D.new()
		ring.name = "ShieldOrbit%02d" % (index + 1)
		var torus := TorusMesh.new()
		torus.inner_radius = 7.2 + index * 0.28
		torus.outer_radius = torus.inner_radius + 0.28
		torus.rings = 32
		torus.ring_segments = 8
		ring.mesh = torus
		ring.material_override = storm if index == 1 else brass
		ring.rotation = Vector3(deg_to_rad(24.0 + index * 19.0), deg_to_rad(index * 31.0), deg_to_rad(index * 13.0))
		_storm_crown.add_child(ring)

	# A jagged crown distinguishes the Warden from normal round enemies.
	for index in 12:
		var angle := TAU * float(index) / 12.0
		var shard := MeshInstance3D.new()
		shard.name = "CrownShard%02d" % (index + 1)
		var shard_mesh := PrismMesh.new()
		shard_mesh.size = Vector3(1.35, 5.5 + float(index % 3) * 1.2, 1.5)
		shard.mesh = shard_mesh
		shard.material_override = brass if index % 3 else crystal
		shard.position = Vector3(cos(angle) * 6.2, 4.7 + float(index % 2), sin(angle) * 6.2)
		shard.rotation = Vector3(0.0, -angle, -0.38)
		_storm_crown.add_child(shard)

	for index in 7:
		var cloud := MeshInstance3D.new()
		cloud.name = "StormCloud%02d" % (index + 1)
		var cloud_mesh := SphereMesh.new()
		cloud_mesh.radius = 2.8 + float(index % 3) * 0.55
		cloud_mesh.height = cloud_mesh.radius * 1.45
		cloud_mesh.radial_segments = 16
		cloud_mesh.rings = 8
		cloud.mesh = cloud_mesh
		cloud.material_override = dark
		var cloud_angle := TAU * float(index) / 7.0
		cloud.position = Vector3(cos(cloud_angle) * 5.1, float(index % 2) * 2.1 - 1.0, sin(cloud_angle) * 5.1)
		cloud.scale = Vector3(1.35, 0.65, 1.0)
		_storm_crown.add_child(cloud)

	var crown_light := OmniLight3D.new()
	crown_light.name = "StormCrownLight"
	crown_light.light_color = Color("70d7d6")
	crown_light.light_energy = 2.2
	crown_light.omni_range = 22.0
	_storm_crown.add_child(crown_light)


func _material(albedo: Color, emission: Color, energy: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = 0.42
	material.roughness = roughness
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _build_combat_audio() -> void:
	_combat_audio = AudioStreamPlayer3D.new()
	_combat_audio.name = "WardenCombatFoley3D"
	_combat_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_combat_audio.unit_size = 8.0
	_combat_audio.max_distance = 82.0
	_combat_audio.volume_db = -3.0
	_combat_audio.panning_strength = 1.0
	_combat_audio.bus = &"SFX"
	add_child(_combat_audio)


func _play_combat_sound(event: StringName) -> void:
	if _combat_audio == null:
		return
	_combat_audio.stream = Foley.make_combat_event(event)
	_combat_audio.play()
