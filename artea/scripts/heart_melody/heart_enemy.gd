extends CharacterBody3D
const Art = preload("res://scripts/heart_melody/heart_art.gd")
signal released(enemy)
var spec: Dictionary
var player: CharacterBody3D
var world: Node3D
var hp := 40.0
var phase := "warning"
var remaining := 1.0
var origin := Vector3.ZERO
var target := Vector3.ZERO
var marker: MeshInstance3D
var body_visual: Node3D
var struck := false
var status: Label3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	hp = float(spec.hp)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.4
	capsule.height = 3
	shape.shape = capsule
	shape.position.y = 1.4
	add_child(shape)
	body_visual = Node3D.new()
	add_child(body_visual)
	Art.cone(body_visual, Vector3(0, 1.5, 0), 1.6, 0.7, 2.4, Color("544963"), false, 7)
	if spec.kind == "moth":
		for x in [-1, 1]:
			for z in [-1, 1]:
				var wing := Art.cone(body_visual, Vector3(x * 1.6, 1.8, z * 0.8), 1.3, 0.6, 0.2, Color("a58eaf"), false, 5)
				wing.rotation_degrees.z = x * 20
	else:
		Art.cone(body_visual, Vector3(0.4, 3, 0), 0.7, 0, 1.3, Color("8bb492"), false, 4)
	status = Art.label(self, "", Vector3(0, 4.5, 0), 26)
	_warn()

func _warn() -> void:
	phase = "warning"
	status.text = ("Echo Moth" if spec.kind == "moth" else "Pulse Slime") + " · step outside the marked area"
	remaining = float(spec.warning) * (1.8 if world.combat_assist else 1.0)
	origin = global_position
	var direction := (player.global_position - origin)
	direction.y = 0
	target = origin + direction.limit_length(9)
	if is_instance_valid(marker): marker.queue_free()
	if spec.kind == "moth":
		marker = Art.box(world, world.to_local((origin + target) / 2) + Vector3(0, 0.08, 0), Vector3(3, 0.08, maxf(origin.distance_to(target), 0.1)), Color("e7ad72"))
		if origin.distance_to(target) > 0.1: marker.look_at(target + Vector3(0, 0.08, 0))
	else:
		marker = Art.cone(world, world.to_local(target) + Vector3(0, 0.08, 0), 3, 3, 0.08, Color("e7ad72"), false, 16)
	world.note(0, 0.10)
	struck = false

func _physics_process(delta: float) -> void:
	if world.modal_open or (world.embedded_in_overworld and not world.embedded_active) or player.global_position.distance_to(world.to_global(world.encounter_center)) > 22: return
	remaining -= delta
	if phase == "warning" and remaining <= 0:
		phase = "attack"
		remaining = 0.45
	elif phase == "attack":
		var fraction := clampf(1 - remaining / 0.45, 0, 1)
		global_position = origin.lerp(target, fraction)
		body_visual.position.y = sin(fraction * PI) * (2.5 if spec.kind == "slime" and not world.reduced_motion else 0.0)
		if spec.kind == "moth" and not struck and _inside_dash_lane(player.global_position) and global_position.distance_to(player.global_position) < 1.5: _hit()
		if remaining <= 0:
			# The marker is a 16-sided polygon. Use its inscribed circle, never
			# an invisible circumscribed damage circle beyond the visible edges.
			if spec.kind == "slime" and absf(player.global_position.y - target.y) < 2 and Vector2(player.global_position.x - target.x, player.global_position.z - target.z).length() <= 3 * cos(PI / 16): _hit()
			phase = "recovery"
			status.text = "Shell exposed · strike now"
			remaining = spec.recovery
			marker.visible = false
	elif phase == "recovery" and remaining <= 0: _warn()

func _hit() -> void:
	struck = true
	player.take_damage(float(spec.damage) * (0.5 if world.combat_assist else 1.0), self)

func take_damage(amount: float, _source: Node = null) -> void:
	if world.modal_open or phase != "recovery" or hp <= 0: return
	hp -= amount
	if hp <= 0:
		marker.queue_free()
		world.restore_creature(spec, world.to_local(global_position))
		world.note(2, 0.15)
		released.emit(self)
		queue_free()

func _inside_dash_lane(point: Vector3) -> bool:
	var lane := Vector2(target.x - origin.x, target.z - origin.z)
	var offset := Vector2(point.x - origin.x, point.z - origin.z)
	if lane.length_squared() < 0.01: return false
	var along := offset.dot(lane) / lane.length_squared()
	return along >= 0 and along <= 1 and absf(offset.cross(lane.normalized())) <= 1.5

func _exit_tree() -> void:
	if is_instance_valid(marker): marker.queue_free()
