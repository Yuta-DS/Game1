extends Node3D

var thought_text := ""
var grid_position = null
var paused := false          # first click holds the thought still to look at it
var resolving := false       # one cloud may report exactly one completed resolve
var was_wandering := false   # so releasing resumes only if it was drifting
var floating := false
var float_timer := 0.0
var base_y := 0.0
var move_direction := Vector3.ZERO
var move_speed := 0.0
var speed_min := 0.3
var speed_max := 0.8
var bounds_x := 10.0
var bounds_y := 5.0

func _ready():
	await get_tree().process_frame
	_setup()

func _setup():
	# The shipped scene names this node CLoudMesh. Keep the authored scene data
	# intact and resolve the exact node name here rather than silently failing
	# on every cloud setup.
	var sprite = $CLoudMesh
	var label = $CloudLabel
	
	# Get text length
	var length = thought_text.length()
	if length < 1:
		length = 1
	
	# 1. CLOUD SIZE - MUCH SMALLER
	var new_scale = 0.1 + (length * 0.0012)
	if new_scale > 0.2:
		new_scale = 0.2
	scale = Vector3(new_scale, new_scale, new_scale)
	
	# 2. TEXT - MUCH BIGGER
	if label:
		label.text = thought_text
		label.modulate = Color(0, 0, 0, 1)  # Black text
		label.font_size = 600  # BIG text
		label.outline_size = 6
		label.outline_modulate = Color(1, 1, 1, 1)
		label.billboard = 1
		label.position = Vector3(0, 0, 0.2)
		
		
	
	# 3. COLORS
	if sprite:
		# Force bright red - TEST ONLY
		sprite.modulate = Color(1.0, 0.0, 0.0)
		print("DEBUG: Cloud color set to RED")
	
		#var colors = [
			#Color(1.0, 0.6, 0.6),
			#Color(0.6, 1.0, 0.6),
			#Color(0.6, 0.6, 1.0),
			#Color(1.0, 0.7, 0.4),
			#Color(0.8, 0.5, 1.0),
			#Color(0.5, 1.0, 0.7),
		#]
		#sprite.modulate = colors[randi() % colors.size()]
		sprite.pixel_size = 0.06
	
	print("DEBUG: Text length: ", length, " Cloud scale: ", new_scale)
	add_to_group("cloud_ui")

# Two clicks, not one. The first pauses the thought so the player can look
# at it without fighting it; the second lets it go. Witness, then release.
func check_click():
	if not paused:
		_hold_thought()
	else:
		pop_cloud()


func _hold_thought():
	paused = true
	was_wandering = floating
	floating = false

	# Bring it forward and steady it so it reads as "being looked at".
	var sprite = $CLoudMesh
	if sprite:
		sprite.modulate = Color(1.0, 0.95, 0.7)

	var ui = _get_ui()
	if ui and ui.has_method("thought_held"):
		ui.thought_held(thought_text)


# Let the thought drift on without popping it — not every thought has to go.
func release_thought():
	if not paused:
		return
	paused = false

	var sprite = $CLoudMesh
	if sprite:
		sprite.modulate = Color(1.0, 0.0, 0.0)

	if was_wandering:
		floating = true


func _get_ui():
	return get_node_or_null("/root/CloudPop3d/CanvasLayer2")


func pop_cloud():
	# A fast second click can arrive while the pop animation is running. It
	# must not count the same cloud twice toward the kingdom completion.
	if resolving:
		return
	resolving = true

	JourneyState.mark_popped(thought_text)
	$PopSound.play()
	print("=== POP_CLOUD CALLED ===")
	
	var sprite = $CLoudMesh
	if sprite:
		sprite.modulate = Color(1.0, 0.2, 0.2)
	
	var sparkles = $Sparkles
	if sparkles:
		sparkles.emitting = true
	
	await get_tree().create_timer(0.3).timeout

	# The UI determines completion from the number of live clouds. Detach this
	# cloud before reporting so it can only finish after every spawned cloud is
	# resolved, while preserving the visible pop animation above.
	var ui = _get_ui()
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)
	queue_free()

	if ui:
		print("UI found: ", ui.name)
		if ui.has_method("cloud_popped"):
			print("Calling cloud_popped directly")
			ui.cloud_popped()
		else:
			print("UI does not have cloud_popped method")
	else:
		print("UI not found at /root/CloudPop3d/CanvasLayer2")

func start_wandering():
	floating = true
	base_y = global_position.y
	float_timer = randf() * TAU
	move_speed = randf_range(speed_min, speed_max)
	move_direction = Vector3(
		randf_range(-1, 1),
		randf_range(-1, 1),
		0
	).normalized()
	set_process(true)
	
	##
	

func _process(delta):
	if not floating:
		return
	
	float_timer += delta
	global_position.y = base_y + sin(float_timer * 1.5) * 0.05
	
	var new_pos = global_position + move_direction * move_speed * delta
	
	if new_pos.x < -bounds_x:
		new_pos.x = -bounds_x
		move_direction.x = abs(move_direction.x)
	elif new_pos.x > bounds_x:
		new_pos.x = bounds_x
		move_direction.x = -abs(move_direction.x)
	
	if new_pos.y < -bounds_y:
		new_pos.y = -bounds_y
		move_direction.y = abs(move_direction.y)
		base_y = new_pos.y
	elif new_pos.y > bounds_y:
		new_pos.y = bounds_y
		move_direction.y = -abs(move_direction.y)
		base_y = new_pos.y
	
	global_position = new_pos
	
	## New lines for text wrapping
	
