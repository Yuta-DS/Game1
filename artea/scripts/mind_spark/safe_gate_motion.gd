extends Node
## Move both hinged bodies together on physics ticks; never force through a body.
var leaves: Array[AnimatableBody3D] = []
var target_open := false
var moving := false
var delay := 0.0

func request(open: bool, animate: bool) -> void:
	target_open=open
	leaves.clear()
	for child in get_parent().get_children():
		if child is AnimatableBody3D and child.has_node("GateLeafCollision"):
			leaves.append(child)
	delay=.38 if animate else 0.0
	moving=animate
	if not animate:
		for leaf in leaves: leaf.rotation.y=_target(leaf)
		get_parent().set_meta("gate_state","open" if open else "sealed")

func _target(leaf: Node3D) -> float:
	return float(leaf.get_meta("open_rotation_y" if target_open else "closed_rotation_y"))

func _physics_process(delta: float) -> void:
	if not moving: return
	if delay>0:
		delay-=delta
		return
	var angles: Array[float]=[]
	for leaf in leaves:
		var next := move_toward(leaf.rotation.y,_target(leaf),deg_to_rad(60)*delta)
		if not _sweep_clear(leaf,next):
			get_parent().set_meta("gate_state","obstructed")
			return
		angles.append(next)
	var finished := true
	for i in leaves.size():
		leaves[i].rotation.y=angles[i]
		finished=finished and is_equal_approx(angles[i],_target(leaves[i]))
	get_parent().set_meta("gate_state",("open" if target_open else "sealed") if finished else ("opening" if target_open else "closing"))
	moving=not finished

func _sweep_clear(leaf: AnimatableBody3D, next: float) -> bool:
	var collision := leaf.get_node("GateLeafCollision") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=collision.shape
	query.margin=.04
	query.collision_mask=leaf.collision_mask
	var exclusions: Array[RID]=[]
	for other in leaves: exclusions.append(other.get_rid())
	# The fixed connector walls wrap the hinge shafts. A leaf briefly sweeps
	# through that built-in housing, but the walls remain solid to the player.
	var perimeter := leaf.get_parent().get_node_or_null(
		"HeavenlyThresholdCourt/CollisionBackedGatePerimeter")
	if perimeter != null:
		for side in ["West", "East"]:
			var connector := perimeter.get_node_or_null(
				"%sGateTowerConnectorWallCollision" % side) as CollisionObject3D
			if connector != null: exclusions.append(connector.get_rid())
	query.exclude=exclusions
	# At most one degree per angular sample, including the current occupied pose.
	var steps := maxi(1,int(ceil(absf(next-leaf.rotation.y)/deg_to_rad(1))))
	for i in range(steps+1):
		var pose := leaf.transform
		pose.basis=Basis(Vector3.UP,lerpf(leaf.rotation.y,next,float(i)/steps)).scaled(leaf.scale)
		query.transform=leaf.get_parent().global_transform*pose*collision.transform
		var hits := leaf.get_world_3d().direct_space_state.intersect_shape(query,1)
		if not hits.is_empty():
			get_parent().set_meta("last_obstruction", str(hits[0].collider.get_path()))
			return false
	return true
