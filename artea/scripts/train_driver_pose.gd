extends RefCounted
## Analytic two-link posing for the shipped fox rig. No generated clip or added
## character mesh: the player's own shoulders/elbows reach the real handle grips.

var skeleton: Skeleton3D
var animation: AnimationPlayer
var visuals: Node3D
var saved_poses: Array[Transform3D] = []
var saved_yaw := 0.0
var saved_clip := ""
var saved_speed := 1.0
var was_playing := false
var left_target := Vector3.ZERO
var right_target := Vector3.ZERO
var has_targets := false
var hand_error := 0.0
var stowed_items: Array[Node3D] = []

func begin(root: Node3D, player: AnimationPlayer) -> void:
	visuals = root
	animation = player
	skeleton = root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	stowed_items.clear()
	for item in root.find_children("Sword", "MeshInstance3D", true, false):
		if item.visible:
			stowed_items.append(item)
			item.visible = false
	saved_yaw = visuals.rotation.y
	saved_poses.clear()
	for i in skeleton.get_bone_count():
		saved_poses.append(skeleton.get_bone_pose(i))
	if animation != null:
		saved_clip = animation.current_animation
		saved_speed = animation.speed_scale
		was_playing = animation.is_playing()
		animation.pause()
	has_targets = false

func finish() -> void:
	for item in stowed_items:
		if is_instance_valid(item):
			item.visible = true
	stowed_items.clear()
	if is_instance_valid(skeleton):
		for i in mini(saved_poses.size(), skeleton.get_bone_count()):
			skeleton.set_bone_pose(i, saved_poses[i])
	if is_instance_valid(visuals):
		visuals.rotation.y = saved_yaw
	if is_instance_valid(animation):
		animation.speed_scale = saved_speed
		if was_playing and animation.has_animation(saved_clip):
			animation.play(saved_clip, 0.15)
	skeleton = null
	saved_poses.clear()
	has_targets = false

func apply(delta: float, state: Dictionary) -> void:
	if not is_instance_valid(skeleton) or state.is_empty():
		return
	# The fox's authored forward is +Z; the train/player forward is -Z.
	visuals.rotation.y = PI
	for i in skeleton.get_bone_count():
		skeleton.set_bone_pose(i, skeleton.get_bone_rest(i))
	var body := skeleton.find_bone("Bone")
	var torso := skeleton.get_bone_rest(body).origin
	torso.y -= 0.12
	torso.y += sin(float(state.get("elapsed", 0.0)) * 2.2) * 0.002
	skeleton.set_bone_pose_position(body, torso)
	# Flex the actual legs, rather than squashing the entire player mesh.
	_solve("Bone.002", "L_leg_3", Vector3(0, -0.195, -0.02),
		Vector3(0.103, 0.045, 0.17), Vector3(0.103, 0.24, 0.36))
	_solve("R_leg_1", "R_leg_2", Vector3(0, -0.195, -0.02),
		Vector3(-0.103, 0.045, 0.17), Vector3(-0.103, 0.24, 0.36))
	for spec in [["L_leg_1", 0.103], ["Bone.013", -0.103]]:
		var foot := skeleton.find_bone(spec[0])
		skeleton.set_bone_pose_position(foot, Vector3(spec[1], 0.045, 0.17))
	var left_world: Vector3 = state.get("left_target", skeleton.to_global(Vector3(-0.28, 0.4, 0.3)))
	var right_world: Vector3 = state.get("right_target", skeleton.to_global(Vector3(0.28, 0.4, 0.3)))
	var desired_left := skeleton.to_local(left_world)
	var desired_right := skeleton.to_local(right_world)
	if not has_targets:
		left_target = Vector3(0.26, 0.35, 0.22)
		right_target = Vector3(-0.26, 0.35, 0.22)
		has_targets = true
	var blend := 1.0 - exp(-9.0 * maxf(delta, 0.0))
	left_target = left_target.lerp(desired_left, blend)
	right_target = right_target.lerp(desired_right, blend)
	# Rotated 180 degrees, the +X authored arm is on the driver's left.
	var right_tip := skeleton.get_bone_global_rest(9).affine_inverse() \
		* skeleton.get_bone_global_rest(10).origin
	_solve("Bone.006", "Bone.007", right_tip,
		left_target, Vector3(0.55, 0.2, 0.12))
	var left_tip := skeleton.get_bone_global_rest(15).basis.inverse() \
		* Vector3(-0.24288, 0.00587, 0.01037)
	_solve("Bone.020", "Bone.021", left_tip,
		right_target, Vector3(-0.55, 0.2, 0.12))
	# Measure contact with the real grips, not merely with the smoothed IK goal.
	hand_error = maxf(
		skeleton.to_global(skeleton.get_bone_global_pose(9) * right_tip).distance_to(left_world),
		skeleton.to_global(skeleton.get_bone_global_pose(15) * left_tip).distance_to(right_world))
	var head := skeleton.find_bone("Bone.001")
	var head_rest := skeleton.get_bone_rest(head).basis.get_rotation_quaternion()
	var phase: String = state.get("phase", "ready")
	var glance := -0.15 if phase == "check_pressure" else 0.0
	if int(state.get("reverser", 0)) < 0 and phase in ["accelerating", "cruising"]:
		glance = 0.45 * (0.5 + 0.5 * sin(float(state.get("elapsed", 0.0)) * 1.4))
	skeleton.set_bone_pose_rotation(head, head_rest * Quaternion(Vector3.UP, glance))

func _solve(upper_name: String, lower_name: String, tip: Vector3,
		target: Vector3, hint: Vector3) -> float:
	var upper := skeleton.find_bone(upper_name)
	var lower := skeleton.find_bone(lower_name)
	if upper < 0 or lower < 0:
		return INF
	var a := skeleton.get_bone_global_pose(upper)
	var b := skeleton.get_bone_global_pose(lower)
	var first_length := a.origin.distance_to(b.origin)
	var second_length := tip.length()
	var offset := target - a.origin
	var distance := clampf(offset.length(), absf(first_length - second_length) + 0.001,
		first_length + second_length - 0.001)
	var direction := offset.normalized()
	var bend := hint - a.origin
	bend = (bend - direction * bend.dot(direction)).normalized()
	var along := (first_length * first_length + distance * distance
		- second_length * second_length) / (2.0 * distance)
	var height := sqrt(maxf(first_length * first_length - along * along, 0.0))
	var elbow := a.origin + direction * along + bend * height
	_rotate_towards(upper, b.origin - a.origin, elbow - a.origin)
	b = skeleton.get_bone_global_pose(lower)
	_rotate_towards(lower, b.basis * tip, target - b.origin)
	b = skeleton.get_bone_global_pose(lower)
	return (b * tip).distance_to(target) * skeleton.global_basis.get_scale().x

func _rotate_towards(bone: int, from: Vector3, to: Vector3) -> void:
	if from.length_squared() < 0.000001 or to.length_squared() < 0.000001:
		return
	var current := skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
	var desired := Quaternion(from.normalized(), to.normalized()) * current
	var parent := skeleton.get_bone_parent(bone)
	if parent >= 0:
		desired = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion().inverse() * desired
	skeleton.set_bone_pose_rotation(bone, desired.normalized())
