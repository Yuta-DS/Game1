class_name HeartGardenEnemy
extends CharacterBody3D

signal released(enemy_id: String)

const Kit := preload("res://scripts/heart_melody/heart_nature_kit.gd")
enum Phase { NOTICE, TELEGRAPH, ATTACK, RECOVERY, RELEASED }
var enemy_id := ""
var slime := false
var player: CharacterBody3D
var health := 40.0
var phase := Phase.NOTICE
var remaining := 1.0
var assist := false
var suspended := false
var home := Vector3.ZERO
var target := Vector3.ZERO
var attack_start := Vector3.ZERO
var attack_hit := false
var body_visual: Node3D
var telegraph: MeshInstance3D
var caption: Label3D

func _ready() -> void:
	health = 50.0 if slime else 40.0
	collision_layer = 1
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.2
	capsule.height = 2.4
	shape.shape = capsule
	shape.position.y = 1.2
	add_child(shape)
	body_visual = Node3D.new()
	add_child(body_visual)
	Kit.facet(body_visual,"BlightShell",Vector3(0,1.4,0),Vector3(1.4,1.4,1.3),"blight")
	if slime:
		Kit.facet(body_visual,"LivingLeaf",Vector3(0,2.8,0),Vector3(0.5,0.6,0.2),"leaf_light")
	else:
		for side in [-1,1]:
			for offset in [-0.6,0.6]:
				Kit.facet(body_visual,"PetalWing",Vector3(side*1.7,1.7,offset),Vector3(1.5,0.2,0.8),"pink")
	caption = Kit.sign_text(self,"Pulse Slime" if slime else "Echo Moth",Vector3(0,4,0),25)
	# The telegraph lives in the world, independent from the moving creature.
	if slime:
		telegraph = Kit.cylinder(get_parent().get_parent(),"LandingWarning",Vector3.ZERO,3,0.07,"gold",false,16)
	else:
		telegraph = Kit.box(get_parent().get_parent(),"DashWarning",Vector3.ZERO,Vector3(3,0.07,10),"gold")
	telegraph.visible = false
	home = global_position

func _exit_tree() -> void:
	if is_instance_valid(telegraph): telegraph.queue_free()

func _physics_process(delta: float) -> void:
	if suspended or player == null or phase == Phase.RELEASED: return
	remaining -= delta
	if phase == Phase.NOTICE:
		var offset := player.global_position-global_position
		offset.y = 0
		if offset.length() > 5:
			velocity = offset.normalized()*3.0
			move_and_slide()
		if remaining <= 0: _warn()
	elif phase == Phase.TELEGRAPH:
		if remaining <= 0:
			phase = Phase.ATTACK
			remaining = 0.65 if slime else 0.5
			attack_hit = false
			caption.text = "STEP ASIDE"
	elif phase == Phase.ATTACK:
		var duration := 0.65 if slime else 0.5
		var progress := clampf(1.0-remaining/duration,0,1)
		var desired := attack_start.lerp(target,progress)
		velocity = (desired-global_position)/maxf(delta,0.001)
		velocity.y = 0
		move_and_slide()
		body_visual.position.y = sin(progress*PI)*3 if slime else 0.0
		if (not slime or remaining <= 0) and not attack_hit and hits_point(player.global_position):
			player.call("take_damage",(5.0 if assist else 10.0) if slime else (4.0 if assist else 8.0),self)
			attack_hit = true
		if remaining <= 0:
			phase = Phase.RECOVERY
			remaining = (1.8 if slime else 1.5) * (1.5 if assist else 1.0)
			telegraph.visible = false
			body_visual.position.y = 0
			caption.text = "SHELL OPEN • STRIKE"
	elif remaining <= 0:
		phase = Phase.NOTICE
		remaining = 0.8

func _warn() -> void:
	phase = Phase.TELEGRAPH
	remaining = (1.2 if slime else 1.0)*(1.7 if assist else 1.0)
	attack_start = global_position
	var direction := player.global_position-attack_start
	direction.y = 0
	if direction.length() < 0.01: direction = Vector3.FORWARD
	var reach := minf(direction.length(),8.0) if slime else 10.0
	target = attack_start+direction.normalized()*reach
	target.y = home.y
	telegraph.global_position = (target if slime else (attack_start+target)*0.5)+Vector3.UP*0.04
	if not slime: telegraph.rotation.y = atan2(direction.x,direction.z)
	telegraph.visible = true
	caption.text = "LEAVE THE CIRCLE" if slime else "LEAVE THE STRIP"

func hits_point(point: Vector3) -> bool:
	if absf(point.y-home.y) > 3: return false
	if slime:
		return Vector2(point.x-target.x,point.z-target.z).length() <= 3.0
	# Capsule-like contact restricted to the visible 3 m wide strip.
	var line := Vector2(target.x-attack_start.x,target.z-attack_start.z)
	var offset := Vector2(point.x-attack_start.x,point.z-attack_start.z)
	var along := offset.dot(line.normalized())
	var side := absf(offset.cross(line.normalized()))
	return along >= 0 and along <= line.length() and side <= 1.5 \
		and Vector2(point.x-global_position.x,point.z-global_position.z).length() < 2.2

func take_damage(amount: float, _source: Node = null) -> float:
	if phase != Phase.RECOVERY or amount <= 0 or suspended: return 0.0
	var applied := minf(health,amount)
	health -= applied
	if health <= 0:
		phase = Phase.RELEASED
		telegraph.visible = false
		collision_layer = 0
		caption.text = "FREE"
		for item in body_visual.get_children():
			if item is MeshInstance3D: item.material_override = Kit.material("leaf_light")
		released.emit(enemy_id)
	return applied
