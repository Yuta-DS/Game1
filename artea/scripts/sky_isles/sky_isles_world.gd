# Root controller for the Sky Isles world.
#
# Owns everything that is true about this world regardless of which island
# an agent is standing on: the sky, the fog, the sun, the drifting motes,
# and the shared PALETTE/ISLES tables every other Sky Isles script codes
# against (see CONTRACT.md). Also owns the gentle idle bob on each island —
# island scripts build the geometry, this script is the only thing allowed
# to move it, so four independently-authored islands never fight over
# transform.y in the same frame.
#
# Runtime-authored like hub_magitech.gd: nothing here is baked into the
# .tscn except this script itself and empty child nodes for the other
# agents' scripts to attach to.
extends Node3D

# Single source of truth for dormant/vibrant island colours. isle_state.gd
# tints materials with these; island scripts (B) should build their base
# materials FROM these rather than hardcoding colour literals of their own.
const PALETTE := {
	"castle":  { "dormant": Color(0.42, 0.40, 0.48), "vibrant": Color(0.85, 0.80, 0.92) },
	"mind":    { "dormant": Color(0.34, 0.38, 0.52), "vibrant": Color(0.45, 0.62, 1.00) },
	"heart":   { "dormant": Color(0.50, 0.38, 0.44), "vibrant": Color(1.00, 0.55, 0.62) },
	"creator": { "dormant": Color(0.50, 0.45, 0.34), "vibrant": Color(1.00, 0.76, 0.30) },
}

# Fixed world layout. Y=0 is the sky plane the islands float on; castle is
# largest and central, kingdom islands stagger in height so the group reads
# as a place rather than a flat menu ring.
const ISLES := {
	"castle":  { "pos": Vector3(0, 0, 0),        "radius": 34.0 },
	"mind":    { "pos": Vector3(-95, 12, -60),   "radius": 20.0 },
	"heart":   { "pos": Vector3(105, -6, -40),   "radius": 20.0 },
	"creator": { "pos": Vector3(15, 8, 115),     "radius": 20.0 },
}

# Sky/fog colours. Kept as constants (not baked into a resource) so any
# agent can read the exact horizon colour to colour-match rim lighting.
const SKY_HORIZON := Color(0.72, 0.68, 0.88)
const SKY_TOP := Color(0.98, 0.93, 0.78)

# Idle bob tuning. Amplitude/period are randomised per-island within these
# ranges so four islands never move in sync; CONTRACT.md calls this out
# explicitly as the difference between "a place" and "a menu".
const BOB_AMPLITUDE_MIN := 0.1
const BOB_AMPLITUDE_MAX := 0.3
const BOB_PERIOD_MIN := 6.0
const BOB_PERIOD_MAX := 11.0

# Node names island agents (B) create under this root. Looked up lazily
# every frame rather than cached at _ready(), since build order between
# parallel agents is not guaranteed — an island may appear after this
# script has already started running.
const ISLE_NODE_NAMES := ["Isle_castle", "Isle_mind", "Isle_heart", "Isle_creator"]

@onready var _orbit_camera: Camera3D = $CameraRig/OrbitCamera

# Per-island bob state, keyed by node name. Populated lazily the first time
# each island is found, so late-appearing islands still get a phase.
var _bob_state: Dictionary = {}

var _bob_rng := RandomNumberGenerator.new()

# Orbit camera state. Mouse-drag to orbit, scroll to zoom; simple enough
# that the travel controller (agent C) can freely take the camera over by
# just reparenting/driving $CameraRig/OrbitCamera directly.
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = -0.35
var _orbit_distance: float = 160.0
var _orbit_dragging: bool = false
const ORBIT_MIN_DISTANCE := 30.0
const ORBIT_MAX_DISTANCE := 400.0
const ORBIT_MIN_PITCH := -1.3
const ORBIT_MAX_PITCH := -0.05


func _ready() -> void:
	_bob_rng.randomize()

	_build_environment()
	_build_sun()
	_build_motes()
	_update_camera_transform()


func _process(delta: float) -> void:
	_bob_islands(delta)


func _unhandled_input(event: InputEvent) -> void:
	# Orbit drag: hold left mouse and move to rotate around the island
	# cluster. Zoom: mouse wheel. Kept intentionally simple — Phase 1 just
	# needs the world to be navigable; travel_controller.gd takes the
	# camera over for scripted rides later.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_orbit_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_orbit_distance = clampf(_orbit_distance - 12.0, ORBIT_MIN_DISTANCE, ORBIT_MAX_DISTANCE)
			_update_camera_transform()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_distance = clampf(_orbit_distance + 12.0, ORBIT_MIN_DISTANCE, ORBIT_MAX_DISTANCE)
			_update_camera_transform()

	elif event is InputEventMouseMotion and _orbit_dragging:
		var mm := event as InputEventMouseMotion
		_orbit_yaw -= mm.relative.x * 0.005
		_orbit_pitch = clampf(_orbit_pitch - mm.relative.y * 0.005, ORBIT_MIN_PITCH, ORBIT_MAX_PITCH)
		_update_camera_transform()


# Public accessor so travel_controller.gd (agent C) can take the camera
# over without needing to know the internal node path. Stable API — do not
# rename without updating CONTRACT.md.
func get_camera() -> Camera3D:
	return _orbit_camera


# --- environment ---------------------------------------------------------

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"

	var env := Environment.new()

	# Procedural sky: lavender horizon rising into pale gold at the zenith.
	# No physical sky / no volumetric fog per the mobile renderer rule —
	# ProceduralSkyMaterial is cheap and reads well on iPad.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = SKY_TOP
	sky_material.sky_horizon_color = SKY_HORIZON
	sky_material.sky_curve = 0.15
	sky_material.ground_bottom_color = SKY_HORIZON
	sky_material.ground_horizon_color = SKY_HORIZON
	sky_material.sun_angle_max = 30.0

	var sky := Sky.new()
	sky.sky_material = sky_material

	env.background_mode = Environment.BG_SKY
	env.sky = sky

	# Ambient light picks up the sky colour so islands never look lit from
	# nowhere, without needing SDFGI (disallowed on mobile renderer).
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# Depth fog, matched to the horizon colour, tuned so islands fade into
	# the sky at range rather than popping at a hard cutoff. Explicitly NOT
	# volumetric fog — that is GPU-costly and banned for the mobile target.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = SKY_HORIZON
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.2
	env.fog_density = 0.0025
	env.fog_sky_affect = 1.0
	env.fog_aerial_perspective = 0.6

	world_env.environment = env
	add_child(world_env)


func _build_sun() -> void:
	# The only shadow-casting light in the scene, per CONTRACT.md's
	# performance budget. Angled low and warm so it reads as late-afternoon
	# light raking across the islands, matching the gold sky top.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	add_child(sun)


func _build_motes() -> void:
	# One ambient GPUParticles3D covering the whole play volume: soft
	# drifting light motes, additive, no collision/shadows so they stay
	# free on the mobile renderer. Kept well under the <=400 particle cap.
	var motes := GPUParticles3D.new()
	motes.name = "Motes"
	motes.amount = 350
	motes.lifetime = 14.0
	motes.preprocess = 6.0
	motes.visibility_aabb = AABB(Vector3(-160, -60, -160), Vector3(320, 140, 320))
	# No collision (particles never had it) and no shadows — set at the node
	# level, not the material, since GeometryInstance3D owns shadow casting.
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.35, 0.35)
	motes.draw_pass_1 = mesh

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.97, 0.85, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = material

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(150.0, 60.0, 150.0)
	process_material.direction = Vector3(0.0, 1.0, 0.0)
	process_material.spread = 180.0
	process_material.gravity = Vector3.ZERO
	process_material.initial_velocity_min = 0.15
	process_material.initial_velocity_max = 0.6
	process_material.angular_velocity_min = -8.0
	process_material.angular_velocity_max = 8.0
	process_material.scale_min = 0.5
	process_material.scale_max = 1.6
	process_material.color = Color(1.0, 0.97, 0.85, 0.9)
	motes.process_material = process_material

	add_child(motes)


# --- idle bob --------------------------------------------------------------

# Applies gentle sine vertical motion to every Isle_* child found under this
# root. Islands must not animate their own Y — this is the one place bob
# happens, so overlapping agents can't fight over the same transform.
func _bob_islands(delta: float) -> void:
	for isle_name in ISLE_NODE_NAMES:
		var isle := get_node_or_null(NodePath(isle_name))
		if isle == null or not (isle is Node3D):
			continue

		# has() before get(): a typed Dictionary assignment from a missing key
		# would fail on the null before any null-check could run.
		if not _bob_state.has(isle_name):
			_bob_state[isle_name] = _make_bob_state(isle)
		var state: Dictionary = _bob_state[isle_name]

		state["t"] += delta
		var t: float = state["t"]
		var amplitude: float = state["amplitude"]
		var period: float = state["period"]
		var phase: float = state["phase"]
		var base_y: float = state["base_y"]

		(isle as Node3D).position.y = base_y + sin((t / period) * TAU + phase) * amplitude


# Builds this island's bob parameters once, on first sight of the node.
# Reads `bob_phase` meta if the island set one (CONTRACT.md allows this),
# otherwise assigns a random phase so islands never sync. Amplitude/period
# are also randomised per-island within the contract's ranges for the same
# reason — identical values on every island would still look synchronized
# even with different phases.
func _make_bob_state(isle: Node3D) -> Dictionary:
	var phase: float
	if isle.has_meta("bob_phase"):
		phase = float(isle.get_meta("bob_phase"))
	else:
		phase = _bob_rng.randf_range(0.0, TAU)

	return {
		"t": 0.0,
		"base_y": isle.position.y,
		"phase": phase,
		"amplitude": _bob_rng.randf_range(BOB_AMPLITUDE_MIN, BOB_AMPLITUDE_MAX),
		"period": _bob_rng.randf_range(BOB_PERIOD_MIN, BOB_PERIOD_MAX),
	}


# --- orbit camera ------------------------------------------------------

func _update_camera_transform() -> void:
	if _orbit_camera == null:
		return

	var rig := get_node_or_null(NodePath("CameraRig"))
	if rig == null:
		return

	var offset := Vector3(
		cos(_orbit_pitch) * sin(_orbit_yaw),
		sin(-_orbit_pitch),
		cos(_orbit_pitch) * cos(_orbit_yaw)
	) * _orbit_distance

	(rig as Node3D).position = offset
	_orbit_camera.look_at(Vector3.ZERO, Vector3.UP)
