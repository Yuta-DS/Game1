class_name MindSparkEnemyBase
extends CharacterBody3D

signal defeated(enemy: MindSparkEnemyBase, xp_reward: int)
signal state_changed(enemy: MindSparkEnemyBase, state: int)

enum State { IDLE, NOTICE, TELEGRAPH, ATTACK, RECOVERY, DEFEATED }

const Definition := preload("res://scripts/mind_spark/combat/mind_spark_enemy_definition.gd")
const ROOT_STALKER_VISUAL_PATH := "res://assets3D/mind_spark/anycreature/root_stalker.glb"

@export var definition: MindSparkEnemyDefinition
@export var encounter_id := ""
@export var active := false

@onready var navigation: NavigationAgent3D = $NavigationAgent3D
@onready var shell: MeshInstance3D = $VisualRoot/BlightShell
@onready var core: MeshInstance3D = $VisualRoot/LivingCore
@onready var telegraph: MeshInstance3D = $Telegraph
@onready var name_label: Label3D = $Name

var state := State.IDLE
var current_health := 1.0
var _state_time := 0.0
var _player: CharacterBody3D
var _attack_applied := false
var _spawn_position := Vector3.ZERO
var _authored_visual: Node3D
var _authored_animation: AnimationPlayer
var _knockback_velocity := Vector3.ZERO


func _ready() -> void:
	if definition == null:
		push_error("MindSparkEnemyBase requires a definition")
		set_physics_process(false)
		return
	_spawn_position = global_position
	current_health = definition.max_health
	name_label.text = "%s • %d HP" % [definition.display_name.to_upper(), int(current_health)]
	_build_enemy_shape()
	_set_state(State.IDLE, 0.0)
	_find_player.call_deferred()


func set_active(enabled: bool) -> void:
	active = enabled and state != State.DEFEATED
	visible = state != State.DEFEATED or core.visible
	if not active:
		velocity = Vector3.ZERO


func anchor_spawn_to_ground(support_y: float) -> void:
	# World One builds its final decks after these actors enter the tree. Keep the
	# collision capsule just above that deck, and set the reset point to the same
	# place so a combat retry cannot restore the old airborne authored position.
	var grounded := global_position
	grounded.y = support_y + 0.20
	global_position = grounded
	_spawn_position = grounded
	match definition.enemy_kind:
		Definition.EnemyKind.STATIC_MITE:
			# Its low legs were modelled 0.7 m above the scene origin.
			$VisualRoot.position.y = 0.35
		Definition.EnemyKind.GLITCH_SPROUT:
			# The stem extends below the scene origin and should meet the soil.
			$VisualRoot.position.y = 1.65


func reset_enemy() -> void:
	current_health = definition.max_health
	global_position = _spawn_position
	visible = true
	shell.visible = _authored_visual == null
	if _authored_visual != null:
		_authored_visual.visible = true
	core.visible = false
	scale = Vector3.ONE
	_set_state(State.IDLE, 0.0)
	set_active(false)


func restore_defeated() -> void:
	current_health = 0.0
	active = false
	state = State.DEFEATED
	shell.visible = false
	if _authored_visual != null:
		_authored_visual.visible = false
	core.visible = true
	name_label.text = "%s • FREE" % definition.display_name.to_upper()


func take_damage(amount: float, source: Node = null) -> float:
	if not active or state == State.DEFEATED or amount <= 0.0:
		return 0.0
	var multiplier := _damage_multiplier(source)
	if multiplier <= 0.0:
		_show_feedback("BLOCKED • WAIT FOR CYAN", Color("74e8ff"))
		return 0.0
	var applied := minf(current_health, amount * multiplier)
	current_health -= applied
	name_label.text = "%s • %d HP" % [definition.display_name.to_upper(), ceili(current_health)]
	_show_feedback("-%d SHELL" % int(applied), Color("ffd36b"))
	if current_health <= 0.0:
		_defeat()
	else:
		_set_state(State.RECOVERY, definition.recovery_seconds)
	_flash_on_hit()
	return applied


func receive_knockback(direction: Vector3, strength: float) -> void:
	if state == State.DEFEATED:
		return
	var planar := Vector3(direction.x, 0.0, direction.z).normalized()
	_knockback_velocity = planar * clampf(strength, 0.0, 12.0)


func _physics_process(delta: float) -> void:
	if not active or state == State.DEFEATED or _player == null:
		velocity = Vector3.ZERO
		return
	var distance := global_position.distance_to(_player.global_position)
	if distance > 75.0:
		_set_state(State.IDLE, 0.0)
		velocity = Vector3.ZERO
		return
	_state_time -= delta
	match state:
		State.IDLE:
			_set_state(State.NOTICE, 0.42)
		State.NOTICE:
			_face_player(delta)
			if _state_time <= 0.0:
				_set_state(State.TELEGRAPH, definition.validated_telegraph())
		State.TELEGRAPH:
			_face_player(delta)
			if _state_time <= 0.0:
				_set_state(State.ATTACK, 0.34)
		State.ATTACK:
			_perform_attack(delta, distance)
			if _state_time <= 0.0:
				_set_state(State.RECOVERY, definition.recovery_seconds)
		State.RECOVERY:
			velocity = Vector3.ZERO
			if _state_time <= 0.0:
				_set_state(State.TELEGRAPH, definition.validated_telegraph())
	velocity += _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, 24.0 * delta)
	move_and_slide()


func _perform_attack(delta: float, distance: float) -> void:
	var ranged := definition.enemy_kind in [Definition.EnemyKind.GLITCH_SPROUT, Definition.EnemyKind.CIRCUIT_WISP]
	if not ranged:
		var direction := (_player.global_position - global_position)
		direction.y = 0.0
		velocity = direction.normalized() * definition.move_speed * (2.1 if definition.enemy_kind == Definition.EnemyKind.ROOT_STALKER else 1.35)
	else:
		velocity = Vector3.ZERO
		$VisualRoot/ProjectilePreview.visible = true
		$VisualRoot/ProjectilePreview.position = $VisualRoot/ProjectilePreview.position.move_toward(
			to_local(_player.global_position), delta * 18.0)
	if not _attack_applied and distance <= definition.attack_range:
		_player.call("take_damage", definition.attack_damage, self)
		_attack_applied = true


func _damage_multiplier(source: Node) -> float:
	if source == null:
		return 1.0
	var to_source: Vector3 = source.global_position - global_position if source is Node3D else Vector3.ZERO
	to_source.y = 0.0
	var front := global_transform.basis.z.normalized().dot(to_source.normalized())
	if definition.enemy_kind == Definition.EnemyKind.ROOT_STALKER:
		return 1.5 if front < -0.25 else 0.45
	if definition.enemy_kind == Definition.EnemyKind.BLIGHT_SENTINEL:
		return 1.0 if state == State.RECOVERY or front < -0.15 else 0.0
	return 1.0


func _set_state(next_state: int, duration: float) -> void:
	if state == next_state and duration <= 0.0:
		return
	state = next_state
	if state == State.TELEGRAPH:
		var progression := get_node_or_null("/root/WorldOneProgression")
		if progression != null:
			var settings: Dictionary = progression.get("assist_settings")
			duration *= float(settings.get("telegraph_multiplier", 1.0))
	_state_time = duration
	_attack_applied = false
	telegraph.visible = state == State.TELEGRAPH
	$VisualRoot/ProjectilePreview.visible = false
	$VisualRoot/ProjectilePreview.position = Vector3(0, 1.0, 0)
	core.visible = state == State.RECOVERY and definition.enemy_kind == Definition.EnemyKind.BLIGHT_SENTINEL
	if _authored_animation != null:
		var clip := "attack" if state == State.ATTACK else "move" if state == State.NOTICE else "idle"
		for candidate in _authored_animation.get_animation_list():
			if String(candidate).ends_with(clip) and _authored_animation.current_animation != candidate:
				_authored_animation.play(candidate)
				break
	state_changed.emit(self, state)


func _flash_on_hit() -> void:
	var target := _authored_visual if _authored_visual != null else shell
	if target == null:
		return
	var original := target.scale
	target.scale = original * 1.06
	var tween := create_tween()
	tween.tween_property(target, "scale", original, 0.12)


func _defeat() -> void:
	active = false
	velocity = Vector3.ZERO
	_set_state(State.DEFEATED, 0.0)
	shell.visible = false
	if _authored_visual != null:
		_authored_visual.visible = false
	core.visible = true
	name_label.text = "%s • FREE" % definition.display_name.to_upper()
	_show_feedback("BLIGHT SHELL RELEASED", Color("80efaa"))
	var tween := create_tween()
	tween.tween_property(core, "scale", Vector3.ONE * 1.35, 0.25)
	tween.tween_property(core, "scale", Vector3.ONE, 0.35)
	defeated.emit(self, definition.xp_reward)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("Player")
	if not players.is_empty():
		_player = players[0] as CharacterBody3D


func _face_player(delta: float) -> void:
	if _player == null:
		return
	var direction := _player.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 5.0))


func _build_enemy_shape() -> void:
	var shell_material := StandardMaterial3D.new()
	shell_material.albedo_color = definition.shell_color
	shell_material.emission_enabled = true
	shell_material.emission = definition.shell_color
	shell_material.emission_energy_multiplier = 0.42
	shell.material_override = shell_material
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = definition.living_color
	core_material.emission_enabled = true
	core_material.emission = definition.living_color
	core_material.emission_energy_multiplier = 1.15
	core.material_override = core_material
	match definition.enemy_kind:
		Definition.EnemyKind.STATIC_MITE:
			shell.scale = Vector3(1.2, 0.48, 1.5)
			for leg_index in 6:
				var side := -1.0 if leg_index < 3 else 1.0
				var leg := _add_box_part("StaticLeg_%02d" % leg_index, Vector3(side * 1.15, -0.15, -0.75 + (leg_index % 3) * 0.75), Vector3(1.15, 0.16, 0.18), shell_material)
				leg.rotation.z = side * 0.42
			_add_antenna_pair(shell_material)
		Definition.EnemyKind.GLITCH_SPROUT:
			shell.scale = Vector3(0.75, 1.55, 0.75)
			_add_cylinder_part("SproutStem", Vector3(0, -0.8, 0), 0.24, 2.1, core_material)
			for leaf_index in 5:
				var angle := TAU * float(leaf_index) / 5.0
				var leaf := _add_box_part("GlitchLeaf_%02d" % leaf_index,
					Vector3(cos(angle) * 0.8, 0.65 + leaf_index % 2 * 0.35, sin(angle) * 0.8),
					Vector3(0.25, 0.12, 1.25), shell_material)
				leaf.rotation.y = -angle
				leaf.rotation.z = 0.32
		Definition.EnemyKind.CIRCUIT_WISP:
			shell.scale = Vector3.ONE * 0.82
			$VisualRoot.position.y = 2.0
			for ring_index in 3:
				var ring := _add_torus_part("WispOrbit_%02d" % ring_index, Vector3.ZERO,
					0.9 + ring_index * 0.22, 1.02 + ring_index * 0.22, core_material)
				ring.rotation = Vector3(0.35 + ring_index * 0.5, ring_index * 0.7, 0.2)
			for tail_index in 3:
				_add_sphere_part("WispTail_%02d" % tail_index, Vector3(0, -0.7 - tail_index * 0.48, 0),
					0.33 - tail_index * 0.07, core_material)
		Definition.EnemyKind.ROOT_STALKER:
			# Kept as a native development fallback for old fixtures. The production
			# three-island story no longer constructs this retired Island Two actor,
			# so load its authored asset only when a fixture explicitly requests it.
			var root_stalker_scene := load(ROOT_STALKER_VISUAL_PATH) as PackedScene
			_authored_visual = root_stalker_scene.instantiate() as Node3D
			_authored_visual.name = "RootStalkerCreature"
			_authored_visual.scale = Vector3.ONE * 2.1
			add_child(_authored_visual)
			# The imported body surface can lose its COLOR_0 flag in Godot's GLB
			# importer even though the other seven surfaces keep it. Restore the
			# baked bark palette without changing the source animation or mesh.
			for imported_mesh in _authored_visual.find_children("*", "MeshInstance3D", true, false):
				for surface_index in imported_mesh.mesh.get_surface_count():
					var imported_material := imported_mesh.mesh.surface_get_material(surface_index) as StandardMaterial3D
					if imported_material != null and not imported_material.vertex_color_use_as_albedo:
						var corrected_material := imported_material.duplicate() as StandardMaterial3D
						corrected_material.vertex_color_use_as_albedo = true
						imported_mesh.set_surface_override_material(surface_index, corrected_material)
			_authored_animation = _authored_visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
			shell.visible = false
			_add_weak_point("REAR ◇", Vector3(0, 0.7, -1.55))
		Definition.EnemyKind.BLIGHT_SENTINEL:
			shell.scale = Vector3(1.45, 2.1, 1.05)
			for side in [-1.0, 1.0]:
				_add_box_part("SentinelShoulder", Vector3(float(side) * 1.45, 0.65, 0),
					Vector3(1.25, 0.55, 1.2), shell_material)
			var shield := _add_torus_part("SentinelShieldRing", Vector3(0, 0.25, 1.25), 1.15, 1.42, core_material)
			shield.rotation.x = PI * 0.5
			_add_weak_point("CYAN CHEST", Vector3(0, 1.25, 1.05))


func _add_antenna_pair(material: Material) -> void:
	for side in [-1.0, 1.0]:
		var antenna := _add_box_part("StaticAntenna", Vector3(float(side) * 0.55, 0.65, 0.65),
			Vector3(0.10, 1.25, 0.10), material)
		antenna.rotation.z = float(side) * 0.35


func _add_box_part(node_name: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh_part(node_name, at, mesh, material)


func _add_cylinder_part(node_name: String, at: Vector3, radius: float, height: float,
		material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.8
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	return _add_mesh_part(node_name, at, mesh, material)


func _add_sphere_part(node_name: String, at: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _add_mesh_part(node_name, at, mesh, material)


func _add_torus_part(node_name: String, at: Vector3, inner: float, outer: float,
		material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 18
	mesh.ring_segments = 7
	return _add_mesh_part(node_name, at, mesh, material)


func _add_mesh_part(node_name: String, at: Vector3, mesh: PrimitiveMesh,
		material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	part.position = at
	part.mesh = mesh
	part.material_override = material
	$VisualRoot.add_child(part)
	return part


func _add_weak_point(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 24
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	$VisualRoot.add_child(label)


func _show_feedback(text: String, color: Color) -> void:
	$Feedback.text = text
	$Feedback.modulate = color
	$Feedback.visible = true
	var tween := create_tween()
	tween.tween_interval(0.55)
	tween.tween_callback(func(): $Feedback.visible = false)
