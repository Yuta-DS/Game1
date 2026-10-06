# Milo catches a player who falls off the world and carries them back to the
# last solid ground they stood on, the way Lakitu fishes a kart back onto the
# track.
#
# MiloCompanionManager adds one of these to every scene with a walkable 3D
# player. It keeps a short history of places where the player stood with
# ground all around their feet, notices a fall with no floor underneath, then
# freezes the player in a bubble while Milo swoops down and flies them both
# back. Worlds that already had their own void check hand those falls here
# through MiloCompanionManager.request_fall_rescue(), so every fall reads the
# same. A player carrying the CUSTOM_RECOVERY_META flag is left alone: its
# scene drives the body itself and owns its own checkpoint.
extends Node

signal rescue_started
signal rescue_finished

const CUSTOM_RECOVERY_META := &"custom_fall_recovery"

# --- safe ground history ---
const SAMPLE_INTERVAL := 0.15
# Standing still should not flush the history with copies of one spot.
const SAMPLE_SPACING := 1.0
const SAFE_HISTORY := 24
# Ground must extend this far around the feet. Without it the last sample is
# the ledge the player just walked off, and the rescue would drop them
# straight back over the edge.
const EDGE_CLEARANCE := 0.75
const SUPPORT_PROBE_UP := 1.0
const SUPPORT_PROBE_DOWN := 1.6
# About 35 degrees. Steeper floors are ramps the player may slide off.
const MAX_SAFE_FLOOR_ANGLE := 0.61

# --- fall detection ---
# A drop this far below the last safe ground, with nothing underneath, is a
# fall off the world rather than a jump down to a lower walkway. Deep enough
# that the player gets a real moment of falling before Milo swoops in. Scenes
# with their own void check (station platforms, the approach bridge) use the
# same depth so every fall feels alike.
const RESCUE_DROP := 16.0
const FLOORLESS_PROBE := 80.0
# Past this any fall is rescued, even if there is a floor somewhere far below.
const HARD_DROP := 60.0
const MIN_AIRBORNE_SECONDS := 0.7

# --- the rescue ---
const CATCH_SECONDS := 0.6
const MILO_ARRIVAL_HEIGHT := 7.0
# Milo hovers just above the bubble, holding the player up.
const MILO_HOVER := Vector3(0.0, 3.3, 0.0)
# Wide enough for the fox with its tail and sword out (about 1.9 m tall and
# 1.7 m across), centred on the player's collision capsule.
const BUBBLE_RADIUS := 1.7
# Bright glassy rim, a see-through middle so the player stays visible, a
# highlight to read as a bubble, and a slow pulse so it looks alive.
const BUBBLE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

uniform vec4 glow : source_color = vec4(0.53, 0.72, 1.0, 1.0);
uniform float fill_alpha = 0.2;
uniform float rim_alpha = 1.0;
uniform float rim_power = 1.5;
uniform float fade = 1.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	float pulse = 0.85 + 0.15 * sin(TIME * 4.0);
	vec3 shine_dir = normalize(vec3(-0.45, 0.6, 0.65));
	float shine = pow(max(dot(reflect(-VIEW, NORMAL), shine_dir), 0.0), 28.0);
	// The rim leans white so it still reads against a sky of the glow's colour.
	ALBEDO = mix(glow.rgb, vec3(1.0), clamp(rim * 0.8 + shine, 0.0, 1.0));
	ALPHA = clamp(fill_alpha + rim * rim_alpha * pulse + shine * 0.8, 0.0, 1.0) * fade;
}
"""
const BUBBLE_LIGHT_ENERGY := 1.4
const CARRY_SPEED := 22.0
const MIN_CARRY_SECONDS := 1.4
const MAX_CARRY_SECONDS := 3.2
# Longer trips fade to the destination instead of flying the whole way.
const FADE_DISTANCE := 220.0
const FADE_SECONDS := 0.3
# Released slightly above the ground so the player lands instead of clipping.
const RELEASE_HEIGHT := 0.6
const RELEASE_SECONDS := 0.3
const MILO_LANDING_OFFSET := 1.6
const LINE_SECONDS := 2.4
const RESCUE_LINES := [
	"Gotcha! Let's get you back on solid ground.",
	"Whoops! Milo's got you.",
	"Up we go. Hold on tight!",
	"Careful there! Back you go.",
	"I'll always catch you.",
]

var player: CharacterBody3D
# The companion who does the catching. Without one the rescue still happens,
# just without Milo in it.
var companion: Node3D

var _safe_positions: Array[Vector3] = []
var _sample_timer := 0.0
var _airborne := 0.0
var _rescuing := false
var _rescues := 0
var _bubble: MeshInstance3D
var _bubble_material: ShaderMaterial
var _line_label: Label3D
var _fade_rect: ColorRect


func set_player(next_player: CharacterBody3D, next_companion: Node3D = null) -> void:
	companion = next_companion
	if next_player == player:
		return
	player = next_player
	_safe_positions.clear()
	_airborne = 0.0


func is_rescuing() -> bool:
	return _rescuing


func get_rescue_count() -> int:
	return _rescues


func get_last_safe_position() -> Vector3:
	return _safe_positions[-1] if not _safe_positions.is_empty() else Vector3.INF


# Starts a rescue now. The player goes back to the last safe ground they stood
# on, or to `fallback` when there is none, which is how scenes with their own
# respawn point hand their falls over. Returns false when nothing could be
# rescued, so the caller keeps its own respawn.
func rescue(fallback := Vector3.INF) -> bool:
	if _rescuing:
		return true
	if not _player_is_live():
		return false
	var target := _pick_safe_target()
	if target == Vector3.INF:
		target = fallback
	if target == Vector3.INF:
		return false
	_run_rescue(target)
	return true


func _physics_process(delta: float) -> void:
	if _rescuing or not _player_is_live():
		return
	# Trains and boats suspend the player's physics while carrying them, and a
	# suspended body reports a stale is_on_floor().
	if not player.is_physics_processing() or player.has_meta(CUSTOM_RECOVERY_META):
		_airborne = 0.0
		return
	if player.is_on_floor():
		_airborne = 0.0
		_sample_timer -= delta
		if _sample_timer <= 0.0:
			_sample_timer = SAMPLE_INTERVAL
			_try_record_safe_position()
		return
	_airborne += delta
	if _should_rescue():
		rescue()


func _exit_tree() -> void:
	# A scene change mid-rescue must not leave the surviving player frozen.
	if _rescuing and _player_is_live():
		player.set_physics_process(true)
	_rescuing = false


func _player_is_live() -> bool:
	return player != null and is_instance_valid(player) and player.is_inside_tree()


func _should_rescue() -> bool:
	if _safe_positions.is_empty() or _airborne < MIN_AIRBORNE_SECONDS:
		return false
	if player.velocity.y >= 0.0:
		return false
	var drop := _safe_positions[-1].y - player.global_position.y
	if drop >= HARD_DROP:
		return true
	return drop >= RESCUE_DROP and not _has_ground_below(player.global_position)


func _try_record_safe_position() -> void:
	var here := player.global_position
	if not _safe_positions.is_empty() \
			and here.distance_to(_safe_positions[-1]) < SAMPLE_SPACING:
		return
	if player.get_floor_normal().angle_to(Vector3.UP) > MAX_SAFE_FLOOR_ANGLE:
		return
	if not _is_well_supported(here):
		return
	_safe_positions.append(here)
	if _safe_positions.size() > SAFE_HISTORY:
		_safe_positions.pop_front()


# Newest first, re-checked because streamed chunks and the Lens of Seeing can
# remove ground after it was recorded.
func _pick_safe_target() -> Vector3:
	for index in range(_safe_positions.size() - 1, -1, -1):
		if _is_well_supported(_safe_positions[index]):
			return _safe_positions[index]
	return Vector3.INF


func _is_well_supported(position: Vector3) -> bool:
	for offset: Vector3 in [Vector3.ZERO,
			Vector3(EDGE_CLEARANCE, 0.0, 0.0), Vector3(-EDGE_CLEARANCE, 0.0, 0.0),
			Vector3(0.0, 0.0, EDGE_CLEARANCE), Vector3(0.0, 0.0, -EDGE_CLEARANCE)]:
		var hit := _ray(position + offset + Vector3.UP * SUPPORT_PROBE_UP,
			position + offset + Vector3.DOWN * SUPPORT_PROBE_DOWN)
		if hit.is_empty() or not _is_fixed_ground(hit.collider):
			return false
	return true


# Moving platforms carry the ground away from a recorded position.
func _is_fixed_ground(collider: Object) -> bool:
	return not (collider is AnimatableBody3D or collider is RigidBody3D \
		or collider is CharacterBody3D)


func _has_ground_below(position: Vector3) -> bool:
	return not _ray(position, position + Vector3.DOWN * FLOORLESS_PROBE).is_empty()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var world := player.get_world_3d()
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, player.collision_mask)
	query.exclude = [player.get_rid()]
	return world.direct_space_state.intersect_ray(query)


func _find_milo() -> Node3D:
	if companion != null and is_instance_valid(companion) and companion.is_inside_tree() \
			and companion.has_method("begin_fall_rescue"):
		return companion
	return null


func _run_rescue(target: Vector3) -> void:
	_rescuing = true
	_rescues += 1
	_airborne = 0.0
	rescue_started.emit()
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	var milo := _find_milo()

	# Catch: the bubble closes around the player as Milo swoops down onto it.
	_build_bubble()
	var start := player.global_position
	if milo != null:
		milo.call("begin_fall_rescue")
		milo.global_position = start + MILO_HOVER + Vector3.UP * MILO_ARRIVAL_HEIGHT
		_face(milo, target - start)
		_say(milo, RESCUE_LINES[(_rescues - 1) % RESCUE_LINES.size()])
	var catch_tween := create_tween().set_parallel()
	catch_tween.tween_property(_bubble, "scale", Vector3.ONE, CATCH_SECONDS) \
		.from(Vector3.ONE * 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if milo != null:
		catch_tween.tween_property(milo, "global_position", start + MILO_HOVER,
			CATCH_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await catch_tween.finished
	if not _still_rescuing():
		return

	# Carry: an arc up and over to the safe ground. Very long trips fade most
	# of the way so a far fall never becomes a long wait.
	var release := target + Vector3.UP * RELEASE_HEIGHT
	if start.distance_to(release) > FADE_DISTANCE:
		await _fade_to(1.0)
		if not _still_rescuing():
			return
		var approach := release + (start - release).normalized() * 30.0
		approach.y = release.y + 12.0
		_place(approach, milo)
		await _fade_to(0.0)
		if not _still_rescuing():
			return
	var from := player.global_position
	var distance := from.distance_to(release)
	var peak := (from + release) * 0.5
	peak.y = maxf(from.y, release.y) + clampf(distance * 0.3, 3.0, 18.0)
	var carry_tween := create_tween()
	carry_tween.tween_method(
		func(t: float) -> void: _place(_bezier(from, peak, release, t), milo),
		0.0, 1.0, clampf(distance / CARRY_SPEED, MIN_CARRY_SECONDS, MAX_CARRY_SECONDS)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await carry_tween.finished
	if not _still_rescuing():
		return

	# Release: the bubble pops, the player drops the last few centimetres and
	# Milo steps down beside them.
	var release_tween := create_tween().set_parallel()
	release_tween.tween_property(_bubble, "scale", Vector3.ONE * 1.35, RELEASE_SECONDS)
	release_tween.tween_method(
		func(value: float) -> void: _bubble_material.set_shader_parameter("fade", value),
		1.0, 0.0, RELEASE_SECONDS)
	if milo != null:
		var side := milo.global_basis.x.normalized() * MILO_LANDING_OFFSET
		release_tween.tween_property(milo, "global_position",
			player.global_position + side + Vector3.UP * 0.4, RELEASE_SECONDS)
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	await release_tween.finished
	_finish(milo)


func _still_rescuing() -> bool:
	if _rescuing and _player_is_live():
		return true
	_finish(_find_milo())
	return false


func _finish(milo: Node3D) -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = null
	_bubble_material = null
	if milo != null and is_instance_valid(milo) and milo.has_method("end_fall_rescue"):
		milo.call("end_fall_rescue")
	if _player_is_live():
		player.set_physics_process(true)
	_airborne = 0.0
	if _rescuing:
		_rescuing = false
		rescue_finished.emit()


func _place(point: Vector3, milo: Node3D) -> void:
	if not _player_is_live():
		return
	var travel := point - player.global_position
	player.global_position = point
	player.velocity = Vector3.ZERO
	if milo != null and is_instance_valid(milo):
		milo.global_position = point + MILO_HOVER
		_face(milo, travel)


func _face(node: Node3D, direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		node.rotation.y = atan2(direction.x, direction.z)


func _bezier(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(control, t).lerp(control.lerp(b, t), t)


func _build_bubble() -> void:
	var glow := Color("86b7ff")
	var milo := _find_milo()
	if milo != null:
		var aura_light: Variant = milo.get("aura_light")
		if aura_light is OmniLight3D:
			glow = (aura_light as OmniLight3D).light_color
	var shader := Shader.new()
	shader.code = BUBBLE_SHADER
	_bubble_material = ShaderMaterial.new()
	_bubble_material.shader = shader
	_bubble_material.set_shader_parameter("glow", glow)
	var sphere := SphereMesh.new()
	sphere.radius = BUBBLE_RADIUS
	sphere.height = BUBBLE_RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_bubble = MeshInstance3D.new()
	_bubble.name = "MiloRescueBubble"
	_bubble.mesh = sphere
	_bubble.material_override = _bubble_material
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.position = _body_centre()
	player.add_child(_bubble)

	# Lights the player from inside so they glow in the dark of the void.
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = glow
	light.light_energy = BUBBLE_LIGHT_ENERGY
	light.omni_range = BUBBLE_RADIUS * 2.2
	light.shadow_enabled = false
	_bubble.add_child(light)

	# CPU particles: the web export runs the Compatibility renderer.
	var sparkles := CPUParticles3D.new()
	sparkles.name = "Sparkles"
	sparkles.amount = 40
	sparkles.lifetime = 0.9
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	sparkles.emission_sphere_radius = BUBBLE_RADIUS
	sparkles.gravity = Vector3.ZERO
	sparkles.initial_velocity_min = 0.2
	sparkles.initial_velocity_max = 0.6
	sparkles.scale_amount_min = 0.07
	sparkles.scale_amount_max = 0.14
	var sparkle_mesh := SphereMesh.new()
	sparkle_mesh.radius = 0.5
	sparkle_mesh.height = 1.0
	sparkle_mesh.radial_segments = 6
	sparkle_mesh.rings = 3
	var sparkle_material := StandardMaterial3D.new()
	sparkle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sparkle_material.albedo_color = glow.lightened(0.5)
	sparkle_mesh.material = sparkle_material
	sparkles.mesh = sparkle_mesh
	_bubble.add_child(sparkles)


# The middle of the player's collision capsule: NewPlayer's origin is at its
# feet, Player3D's at its middle.
func _body_centre() -> Vector3:
	for child in player.get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).position
	return Vector3(0.0, 1.0, 0.0)


func _say(milo: Node3D, line: String) -> void:
	if milo.has_method("say_line"):
		milo.call("say_line", line)
	if _line_label != null and is_instance_valid(_line_label):
		_line_label.queue_free()
	_line_label = Label3D.new()
	_line_label.name = "MiloRescueLine"
	_line_label.text = line
	_line_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Mid-air there is nothing to hide behind, and the bubble must not cover it.
	_line_label.no_depth_test = true
	_line_label.font_size = 32
	_line_label.outline_size = 12
	_line_label.modulate = Color(1, 0.91, 0.65, 1)
	_line_label.position = Vector3(0.0, 2.3, 0.0)
	milo.add_child(_line_label)
	var label := _line_label
	var fade := label.create_tween()
	fade.tween_interval(LINE_SECONDS)
	fade.tween_property(label, "modulate:a", 0.0, 0.4)
	fade.tween_callback(label.queue_free)


func _fade_to(alpha: float) -> void:
	if _fade_rect == null or not is_instance_valid(_fade_rect):
		var layer := CanvasLayer.new()
		layer.name = "MiloRescueFade"
		layer.layer = 90
		add_child(layer)
		_fade_rect = ColorRect.new()
		_fade_rect.color = Color(0.03, 0.02, 0.08, 0.0)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_fade_rect)
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", alpha, FADE_SECONDS)
	await tween.finished
