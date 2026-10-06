extends Node3D
## Visual-only adapter. Saved puzzle choices remain the source of truth.

var _beam: Node3D
var _left: Node3D
var _right: Node3D
var _grip: Node3D
var _slider: Node3D
var _tween: Tween
var _choice := -99
var _angle := 0.0


func _ready() -> void:
	_beam = find_child("BalanceBeam", true, false)
	_left = find_child("ChamberLeft", true, false)
	_right = find_child("ChamberRight", true, false)
	_grip = find_child("OperatingGrip", true, false)
	_slider = find_child("Counterweight", true, false)
	set_choice(-1, false)


func set_choice(choice: int, animate: bool) -> void:
	if _beam == null or choice == _choice:
		return
	_choice = choice
	if _tween != null and _tween.is_valid():
		_tween.kill()
	# Three art-composition choices, not a new correctness rule. Every pose can
	# participate in a valid harmony profile in the existing puzzle.
	var target: float = 0.0 if choice < 0 else [-0.12, 0.0, 0.12][clampi(choice, 0, 2)]
	if animate:
		_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_method(_pose, _angle, target, 0.45)
	else:
		_pose(target)


func _pose(angle: float) -> void:
	_angle = angle
	_beam.rotation.z = angle
	# Suspended vessels remain vertical while their attachment points follow
	# the beam; they do not rotate through the housing.
	_left.rotation.z = -angle
	_right.rotation.z = -angle
	_grip.position.x = angle / 0.12 * 0.84
	_slider.position.x = angle / 0.12 * 0.64
