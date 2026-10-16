# The Crown of Life — a short, playable first-person story chapter.
#
# One continuous scene, built entirely at runtime (same convention as
# lens_demo.gd, gallery_ceremony.gd, hub_castle_entrance.gd): nothing is
# authored in a .tscn, so this can be removed by deleting one file. Reuses the
# existing Lens of Seeing (viewfinder/lens_controller.gd) — no second cutter.
#
# STORY (see artea/docs/CROWN_OF_LIFE_STORY_IMPLEMENTATION.md): the player
# crosses three symbolic kingdoms in sequence. Each kingdom has one prop tagged
# Cuttable, one gap in the world, and a guardian who names the strength the
# player just demonstrated by carrying a seeing across that gap. On the third
# chapter, the three treasures the player already holds combine into the Crown
# of Life finale.
#
# Every guardian line and reward is backed by JourneyState — the game only
# claims a strength the player actually earned by placing a seeing, matching
# gallery_ceremony.gd's evidentiary standard.
extends Node3D

const SceneLoader := preload("res://scripts/scene_loader.gd")

const ControllerScript := preload("res://scripts/viewfinder/lens_controller.gd")
const FrustumCutterScript := preload("res://scripts/viewfinder/frustum_cutter.gd")

const MOVE_SPEED := 5.5
const RUN_SPEED := 8.5
const LOOK_SENSITIVITY := 0.0025
const PITCH_LIMIT := deg_to_rad(85.0)
const JUMP_VELOCITY := 6.5
const GRAVITY := 18.0

const HUB_SCENE_PATH := "res://scenes/New_Hub_World.tscn"
const STORY_SCENE_PATH := "res://scenes/viewfinder/crown_of_life_story.tscn"
const SETTINGS_PATH := "user://crown_story_settings.cfg"

const FALL_RESPAWN_Y := -12.0
const STONE_ALBEDO := "res://demo/assets/textures/rock023_alb_ht.png"

# One named emotion cue per chapter, played on approach and on completion, so
# Heart Melody in particular is legible with the game fully muted (captions
# already carry the same words in the HUD) and distinct with sound on.
const CHAPTER_SFX := {
	"mind_spark": "res://assets/audio/minigame/anticipation.ogg",
	"heart_melody": "res://assets/audio/minigame/happy.ogg",
	"creators_light": "res://assets/audio/minigame/trust.ogg",
}
const BRIDGE_OPEN_SFX := "res://assets/SFX/open chest.ogg"
const AMBIENT_MUSIC := "res://assets/audio/Atmospheric-instrumental-music.ogg"
const INTERACT_RADIUS := 6.0
const HEART_EMOTIONS := [
	{"name": "Joy", "colour": Color("ffd166"), "sound": "res://assets/audio/minigame/happy.ogg"},
	{"name": "Sadness", "colour": Color("72a5ff"), "sound": "res://assets/audio/minigame/sad.ogg"},
	{"name": "Frustration", "colour": Color("ff6b6b"), "sound": "res://assets/audio/minigame/angry.ogg"},
	{"name": "Fear", "colour": Color("a78bfa"), "sound": "res://assets/audio/minigame/fear.ogg"},
	{"name": "Peace", "colour": Color("55e6c1"), "sound": "res://assets/SFX/Peace - David Lastra.ogg"},
	{"name": "Hope", "colour": Color("ff9de2"), "sound": "res://assets/audio/minigame/trust.ogg"},
]
const CREATIVE_CHOICES := [
	{"name": "Courage Sun", "colour": Color("ffd166")},
	{"name": "Kindness Star", "colour": Color("ff8fcf")},
	{"name": "Wonder Portal", "colour": Color("55e6c1")},
]
const GUARDIAN_MODELS := [
	"res://assets3D/characters/Barbarian.glb",
	"res://assets3D/characters/Knight.glb",
	"res://assets3D/characters/Mage.glb",
]
const MILO_MODEL := "res://meshy ai/Milo_Animations.glb"

# One entry per kingdom, in play order. Zone N is not enterable (its gap
# Area3D stays inert) until zone N-1's chapter has been recorded, so the
# sequence cannot be skipped by walking around it.
const CHAPTERS := [
	{
		"id": "mind_spark",
		"label": "Mind Spark Kingdom",
		"theme": "I can understand my thoughts.",
		"before": "I cannot do this.",
		"after": "I am learning and growing.",
		"colour": Color(0.45, 0.62, 1.00),
		"guardian": {
			"faith": "Everlasting Father",
			"universal": "Keeper of Wisdom",
		},
		"line_before": {
			"faith": "Everlasting Father: Every thought that visits you can be looked at, and changed. Carry this one to where it belongs.",
			"universal": "Keeper of Wisdom: Every thought that visits you can be looked at, and changed. Carry this one to where it belongs.",
		},
		"line_after": {
			"faith": "Everlasting Father: You found the courage to understand your thoughts and choose hope. This is the Star of Wisdom.",
			"universal": "Keeper of Wisdom: You found the courage to understand your thoughts and choose hope. This is the Star of Wisdom.",
		},
		"treasure_label": "Star of Wisdom",
		"z": -18.0,
	},
	{
		"id": "heart_melody",
		"label": "Heart Melody Kingdom",
		"theme": "My feelings have a voice.",
		"before": "a silent note",
		"after": "a song of hope",
		"colour": Color(1.00, 0.55, 0.62),
		"guardian": {
			"faith": "Archangel Raphael",
			"universal": "Keeper of Healing",
		},
		"line_before": {
			"faith": "Archangel Raphael: Your feelings matter. Carry this melody to where the kingdom has gone quiet.",
			"universal": "Keeper of Healing: Your feelings matter. Carry this melody to where the kingdom has gone quiet.",
		},
		"line_after": {
			"faith": "Archangel Raphael: Your heart has a beautiful voice, and you just let it be heard. This is the Harmony Jewel.",
			"universal": "Keeper of Healing: Your heart has a beautiful voice, and you just let it be heard. This is the Harmony Jewel.",
		},
		"treasure_label": "Harmony Jewel",
		"z": 0.0,
	},
	{
		"id": "creators_light",
		"label": "Creator's Light Kingdom",
		"theme": "I was created to create.",
		"before": "an unfinished light",
		"after": "a light only you could make",
		"colour": Color(1.00, 0.76, 0.30),
		"guardian": {
			"faith": "Uriel",
			"universal": "Keeper of Creativity",
		},
		"line_before": {
			"faith": "Uriel: What you make is a gift only you can share. Carry your light to the doorway that is missing it.",
			"universal": "Keeper of Creativity: What you make is a gift only you can share. Carry your light to the doorway that is missing it.",
		},
		"line_after": {
			"faith": "Uriel: Your creativity is a gift that only you can share with the world. This is the Creator's Light.",
			"universal": "Keeper of Creativity: Your creativity is a gift that only you can share with the world. This is the Creator's Light.",
		},
		"treasure_label": "Creator's Light",
		"z": 18.0,
	},
]

const ZONE_WIDTH := 16.0
const ZONE_DEPTH := 16.0

# Raw LensPersistence is deliberately off here because its placement file is
# shared across scenes; replaying a hub pose inside this chapter could import
# foreign geometry or accidentally satisfy a goal. JourneyState persists the
# verified chapter and bridge evidence instead, and rebuilds safe bridges on
# revisit. The export remains available for an isolated developer sandbox.
@export var persist_lens_placements := false
@export var settings_path := SETTINGS_PATH

var _camera: Camera3D
var _player: CharacterBody3D
var _pitch := 0.0
var _yaw := 0.0
var _velocity := Vector3.ZERO

var _zone_roots: Array[Node3D] = []
var _gap_areas: Array[Area3D] = []
var _bridges: Array[Node3D] = []
var _gates: Array[StaticBody3D] = []
var _guardian_labels: Array[Label3D] = []
var _source_bodies: Array[StaticBody3D] = []
var _source_labels: Array[Label3D] = []
var _interaction_complete := [false, false, false]
var _heart_emotions_heard := 0
var _creative_choice := -1

var _hud_layer: CanvasLayer
var _guardian_text: Label
var _controls_text: Label
var _story_panel: ColorRect
var _objective_text: Label
var _progress_text: Label

var _finale_built := false
var _greeted: Array[int] = []
var _checkpoint := Vector3.ZERO
var _respawns := 0

# --- audio / accessibility settings, persisted independently of JourneyState
# because they are presentation preferences, not story evidence. -----------
var _music_volume := 0.8
var _sfx_volume := 0.9
var _music_muted := false
var _sfx_muted := false
var _subtitles_on := true
var _large_text := false
var _reduce_motion := false

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

var _pause_layer: CanvasLayer
var _settings_panel: CanvasLayer
var _confirm_panel: CanvasLayer
var _confirm_action: Callable = Callable()
var _confirm_reopens_pause := false
var _finale_layer: CanvasLayer


func _ready() -> void:
	_load_settings()
	_build_audio()
	_build_world()
	_build_milo_guide()
	_build_player()
	_build_hud()
	_build_return_action()
	_build_pause_menu()
	_apply_text_scale()

	for i in CHAPTERS.size():
		_build_zone(i)

	_refresh_gates()
	_restore_interaction_state()
	_checkpoint = _player.global_position
	_update_progress_hud()
	var js := get_node_or_null("/root/JourneyState")
	if js != null and js.story_chapters_complete() and js.has_all_treasures() and not _finale_built:
		_finale_built = true
		_build_finale(js)
	else:
		_show_guardian_line("Milo: This optional Lens path remembers what you carry across each gap. The three kingdom treasures are discovered in the connected Art Castle journey.")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * LOOK_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * LOOK_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
		_camera.rotation = Vector3(_pitch, 0.0, 0.0)
		_player.rotation = Vector3(0.0, _yaw, 0.0)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		# Releases the mouse so a facilitator can click away without alt-tabbing.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and event.keycode == KEY_P:
		# P (not Esc) opens the pause menu — Esc is already owned by the Lens
		# controller while a seeing is raised or held, and this scene's own
		# Esc-releases-mouse convention stays intact for a quick look-away.
		_toggle_pause()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_E and not _is_any_panel_open():
		_perform_current_interaction()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_1, KEY_2, KEY_3] and not _is_any_panel_open():
		_perform_current_interaction(event.keycode - KEY_1)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		if _is_any_panel_open():
			_close_all_panels()
		else:
			_toggle_pause()


func _physics_process(delta: float) -> void:
	if _player == null:
		return

	if _is_any_panel_open():
		return

	if _player.global_position.y < FALL_RESPAWN_Y:
		_respawn_at_checkpoint()
		return

	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input.x += 1.0
	input = input.normalized()

	var speed := RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) else MOVE_SPEED
	var basis := _player.global_transform.basis
	var direction := (basis.x * input.x + basis.z * input.y)
	_velocity.x = direction.x * speed
	_velocity.z = direction.z * speed

	if _player.is_on_floor():
		if Input.is_key_pressed(KEY_SPACE):
			_velocity.y = JUMP_VELOCITY
		else:
			_velocity.y = -0.5
	else:
		_velocity.y -= GRAVITY * delta

	_player.velocity = _velocity
	_player.move_and_slide()
	_velocity = _player.velocity
	_update_story_prompt()


# --- world ------------------------------------------------------------

func _build_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(-30.0), 0.0)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	add_child(sun)

	# A soft opposite-facing rim/fill so shadow faces keep readable form instead
	# of collapsing to near-black — the galaxy mood stays, but nothing pure-crushes.
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-25.0), deg_to_rad(150.0), 0.0)
	fill.light_color = Color("8fa0ff")
	fill.light_energy = 0.16
	fill.shadow_enabled = false
	add_child(fill)

	var env_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	var galaxy_sky := ProceduralSkyMaterial.new()
	galaxy_sky.sky_top_color = Color("070b24")
	galaxy_sky.sky_horizon_color = Color("392f6e")
	galaxy_sky.ground_horizon_color = Color("211d4d")
	galaxy_sky.ground_bottom_color = Color("050817")
	galaxy_sky.sun_angle_max = 8.0
	environment.sky.sky_material = galaxy_sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.16
	environment.fog_enabled = true
	environment.fog_light_color = Color("221f42")
	environment.fog_density = 0.0016
	environment.fog_aerial_perspective = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 2.4
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	environment.glow_bloom = 0.03
	environment.glow_strength = 0.7
	environment.glow_hdr_threshold = 1.1
	env_node.environment = environment
	add_child(env_node)

	# Four islands separated by three real chasms. Their edges line up exactly
	# with the goal areas below, so a bridge is functional level geometry, not
	# decoration painted over a continuous floor.
	var gap_centres: Array[float] = []
	for chapter in CHAPTERS:
		gap_centres.append(float(chapter["z"]) + 4.0)
	var edges := [-34.0, gap_centres[0] - 1.5, gap_centres[0] + 1.5,
		gap_centres[1] - 1.5, gap_centres[1] + 1.5,
		gap_centres[2] - 1.5, gap_centres[2] + 1.5, 40.0]
	for i in 4:
		_build_floor_island(i, float(edges[i * 2]), float(edges[i * 2 + 1]))
	_build_galaxy_landmarks()
	_build_celestial_route_spine()


# Island collision keeps its original single StoryIslandN StaticBody3D/box
# contract (test_crown_story counts exactly four); everything below is purely
# decorative geometry added as siblings so the physics shape never changes.
func _build_floor_island(index: int, from_z: float, to_z: float) -> void:
	var width := ZONE_WIDTH + 6.0
	var depth := to_z - from_z
	var centre := Vector3(0.0, -0.25, (from_z + to_z) * 0.5)

	var floor_body := StaticBody3D.new()
	floor_body.name = "StoryIsland%d" % (index + 1)
	var size := Vector3(width, 0.5, depth)
	var floor_mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	floor_mesh.mesh = box_mesh
	floor_mesh.material_override = _stone_material(Color(0.28, 0.30, 0.38), true)
	# The authoritative rectangular mesh remains as the test-proven floor
	# collider, but it is not the visible island silhouette. Rendering it made
	# the Galaxy read as a row of editor test blocks.
	floor_mesh.visible = false
	floor_body.add_child(floor_mesh)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = size
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	floor_body.global_position = centre

	var deco := Node3D.new()
	deco.name = "StoryIsland%dDetail" % (index + 1)
	add_child(deco)
	deco.global_position = centre

	# A faceted astrolabe top is visual-only and sits flush over the unchanged
	# floor collider. It rounds the corners into a believable floating island
	# while retaining the generous, accessible walkable rectangle underneath.
	var island_top := MeshInstance3D.new()
	island_top.name = "AstrolabeIslandTop"
	var island_top_mesh := CylinderMesh.new()
	island_top_mesh.top_radius = 1.0
	island_top_mesh.bottom_radius = 0.92
	island_top_mesh.height = 0.52
	island_top_mesh.radial_segments = 12
	island_top.mesh = island_top_mesh
	island_top.material_override = _stone_material(Color(0.28, 0.30, 0.38), true)
	island_top.scale = Vector3(width * 0.5, 1.0, depth * 0.5)
	deco.add_child(island_top)

	# Coloured edge band that reads as intentional trim along the rim, not a
	# random accent — sampled from the nearest chapter so each island still
	# carries a hint of the kingdom it belongs to.
	var edge_colour := _island_edge_colour(index)
	var edge := Node3D.new()
	edge.name = "EdgeBand"
	deco.add_child(edge)
	var edge_material := _finale_material(edge_colour, 0.45)
	# Four narrow rails reveal the textured stone top. The earlier full-size
	# emissive slab hid the surface material and made every island look like a
	# flat pastel box rather than a skinned floating structure.
	for z_side in [-1.0, 1.0]:
		var front_rail := MeshInstance3D.new()
		var front_mesh := BoxMesh.new()
		front_mesh.size = Vector3(width + 0.12, 0.14, 0.22)
		front_rail.mesh = front_mesh
		front_rail.material_override = edge_material
		front_rail.position = Vector3(0.0, 0.34, z_side * (depth * 0.5 + 0.01))
		edge.add_child(front_rail)
	for x_side in [-1.0, 1.0]:
		var side_rail := MeshInstance3D.new()
		var side_mesh := BoxMesh.new()
		side_mesh.size = Vector3(0.22, 0.14, depth)
		side_rail.mesh = side_mesh
		side_rail.material_override = edge_material
		side_rail.position = Vector3(x_side * (width * 0.5 + 0.01), 0.34, 0.0)
		edge.add_child(side_rail)
	# The old rails preserve the flat rectangular collision outline but are not
	# rendered; a single elliptical energy rim now describes the island instead.
	edge.visible = false
	var edge_ring := MeshInstance3D.new()
	edge_ring.name = "AstrolabeEnergyRim"
	var edge_ring_mesh := TorusMesh.new()
	edge_ring_mesh.inner_radius = 0.965
	edge_ring_mesh.outer_radius = 1.0
	edge_ring_mesh.rings = 12
	edge_ring_mesh.ring_segments = 6
	edge_ring.mesh = edge_ring_mesh
	edge_ring.material_override = _finale_material(edge_colour, 0.58)
	edge_ring.scale = Vector3(width * 0.5, 1.0, depth * 0.5)
	edge_ring.position.y = 0.30
	deco.add_child(edge_ring)

	# Dark stone underside tapering away from the top slab so the island reads
	# as a floating mass with real thickness instead of a flat plane.
	var underside := MeshInstance3D.new()
	underside.name = "Underside"
	var under_mesh := CylinderMesh.new()
	under_mesh.top_radius = 1.0
	under_mesh.bottom_radius = 0.36
	under_mesh.height = 2.6
	under_mesh.radial_segments = 8
	underside.mesh = under_mesh
	underside.material_override = _stone_material(Color(0.13, 0.13, 0.18), true)
	underside.scale = Vector3(width * 0.45, 1.0, depth * 0.40)
	underside.position = Vector3(0.0, -1.55, 0.0)
	deco.add_child(underside)

	# Corner crystals give each island a silhouette beyond a plain box and add
	# small emissive accents visible from a distance across the chasms.
	var crystal_colour := edge_colour
	var half_w := width * 0.5 - 0.9
	var half_d := depth * 0.5 - 0.9
	if half_w > 0.5 and half_d > 0.5:
		for signs in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var crystal := MeshInstance3D.new()
			crystal.name = "CornerCrystal"
			var crystal_mesh := CylinderMesh.new()
			crystal_mesh.top_radius = 0.0
			crystal_mesh.bottom_radius = 0.3
			crystal_mesh.height = 1.0
			crystal_mesh.radial_segments = 6
			crystal.mesh = crystal_mesh
			crystal.material_override = _finale_material(crystal_colour, 1.4)
			crystal.position = Vector3(signs.x * half_w, 0.75, signs.y * half_d)
			deco.add_child(crystal)


func _island_edge_colour(index: int) -> Color:
	var chapter_index := clampi(index - 1, 0, CHAPTERS.size() - 1)
	return CHAPTERS[chapter_index]["colour"]


# --- shared procedural materials ------------------------------------------

# Reused across stone surfaces (islands, castle, bridges) so this stays a
# handful of shared StandardMaterial3D resources, not one per mesh.
var _stone_material_cache: Dictionary = {}

func _stone_material(base: Color, textured := false) -> StandardMaterial3D:
	var key := "%s_%s" % [base.to_html(), textured]
	if _stone_material_cache.has(key):
		return _stone_material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.roughness = 0.85
	material.metallic = 0.05
	if textured:
		material.albedo_texture = load(STONE_ALBEDO)
		material.uv1_scale = Vector3(3.0, 3.0, 3.0)
	_stone_material_cache[key] = material
	return material


func _build_galaxy_landmarks() -> void:
	var stars := Node3D.new()
	stars.name = "CastleGalaxyStars"
	add_child(stars)
	var star_colours := [Color("fff3a1"), Color("8fd3ff"), Color("ff9de2")]
	# Two depth layers (near/bright, far/dim) so the corridor does not end
	# abruptly in flat empty space — distant stars are smaller and dimmer,
	# giving the sky real depth instead of one uniform scatter.
	for i in 42:
		var star := MeshInstance3D.new()
		var star_mesh := SphereMesh.new()
		var far_layer := i % 3 == 2
		var radius := (0.03 if far_layer else 0.05) + 0.025 * float(i % 3)
		star_mesh.radius = radius
		star_mesh.height = radius * 2.0
		star_mesh.radial_segments = 6
		star_mesh.rings = 4
		star.mesh = star_mesh
		star.material_override = _finale_material(star_colours[i % 3], 1.3 if far_layer else 2.4)
		var side := -1.0 if i % 2 == 0 else 1.0
		var depth_spread := 110.0 if far_layer else 72.0
		star.position = Vector3(
			side * (13.0 + float((i * 7) % 16)) * (1.6 if far_layer else 1.0),
			4.0 + float((i * 11) % 18) * (1.4 if far_layer else 1.0),
			-32.0 + float((i * 13) % int(depth_spread)))
		stars.add_child(star)

	# A low-poly castle at the end makes the three rooms read as one road
	# through the Artéa Castle Galaxy, even before the finale wakes it.
	# Trim, windows, a central doorway, and battlements make it read as an
	# actual destination rather than three bare cylinders.
	var castle := Node3D.new()
	castle.name = "ArteaGalaxyCastle"
	castle.position = Vector3(0.0, 0.0, 38.0)
	add_child(castle)
	var castle_mat := _stone_material(Color("5d5680"), true)
	var trim_mat := _finale_material(Color("8f7fd1"), 0.6)
	var window_mat := _finale_material(Color("ffe9a8"), 2.0)
	for x in [-5.0, 0.0, 5.0]:
		var tower := MeshInstance3D.new()
		var tower_mesh := CylinderMesh.new()
		tower_mesh.top_radius = 1.3
		tower_mesh.bottom_radius = 1.7
		tower_mesh.height = 7.0 if x == 0.0 else 5.2
		tower_mesh.radial_segments = 8
		tower.mesh = tower_mesh
		tower.material_override = castle_mat
		tower.position = Vector3(x, tower_mesh.height * 0.5, 0.0)
		castle.add_child(tower)

		# A base trim ring grounds the tower against the plaza floor.
		var base_ring := MeshInstance3D.new()
		var base_ring_mesh := CylinderMesh.new()
		base_ring_mesh.top_radius = 1.85
		base_ring_mesh.bottom_radius = 1.95
		base_ring_mesh.height = 0.35
		base_ring_mesh.radial_segments = 8
		base_ring.mesh = base_ring_mesh
		base_ring.material_override = trim_mat
		base_ring.position = Vector3(x, 0.18, 0.0)
		castle.add_child(base_ring)

		# Small glowing windows in two bands, facing the plaza approach.
		var window_bands := 2 if x == 0.0 else 1
		for band in window_bands:
			var window := MeshInstance3D.new()
			var window_mesh := BoxMesh.new()
			window_mesh.size = Vector3(0.5, 0.7, 0.12)
			window.mesh = window_mesh
			window.material_override = window_mat
			window.position = Vector3(x, 1.8 + float(band) * 2.1, -1.62)
			castle.add_child(window)

		var roof := MeshInstance3D.new()
		var roof_mesh := CylinderMesh.new()
		roof_mesh.top_radius = 0.0
		roof_mesh.bottom_radius = 2.0
		roof_mesh.height = 2.8
		roof_mesh.radial_segments = 8
		roof.mesh = roof_mesh
		roof.material_override = _finale_material(Color("ffd76a"), 0.7)
		roof.position = Vector3(x, tower.position.y + tower_mesh.height * 0.5 + 1.4, 0.0)
		castle.add_child(roof)

		if x != 0.0:
			continue
		# Central doorway on the middle tower only, facing the plaza.
		var door := MeshInstance3D.new()
		var door_mesh := BoxMesh.new()
		door_mesh.size = Vector3(1.0, 1.9, 0.14)
		door.mesh = door_mesh
		door.material_override = _finale_material(Color("2c2447"), 0.15)
		door.position = Vector3(x, 0.95, -1.69)
		castle.add_child(door)
		for frame_part in [
			{"size": Vector3(0.18, 2.25, 0.12), "position": Vector3(-0.62, 0.95, -1.74)},
			{"size": Vector3(0.18, 2.25, 0.12), "position": Vector3(0.62, 0.95, -1.74)},
			{"size": Vector3(1.42, 0.18, 0.12), "position": Vector3(0.0, 2.02, -1.74)},
		]:
			var door_frame := MeshInstance3D.new()
			var door_frame_mesh := BoxMesh.new()
			door_frame_mesh.size = frame_part["size"]
			door_frame.mesh = door_frame_mesh
			door_frame.material_override = trim_mat
			door_frame.position = frame_part["position"]
			castle.add_child(door_frame)

	# A short battlement wall linking the two outer towers gives the castle a
	# single silhouette instead of three separate towers with nothing between.
	for side in [-1.0, 1.0]:
		var wall := MeshInstance3D.new()
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(3.4, 2.4, 0.6)
		wall.mesh = wall_mesh
		wall.material_override = castle_mat
		wall.position = Vector3(side * 2.5, 1.2, 0.0)
		castle.add_child(wall)
		for merlon_i in 3:
			var merlon := MeshInstance3D.new()
			var merlon_mesh := BoxMesh.new()
			merlon_mesh.size = Vector3(0.55, 0.5, 0.6)
			merlon.mesh = merlon_mesh
			merlon.material_override = trim_mat
			merlon.position = Vector3(side * 2.5 + (float(merlon_i) - 1.0) * 1.0, 2.65, 0.0)
			castle.add_child(merlon)

	# Local presentation lighting keeps the castle readable without washing the
	# three playable islands in global fill light.
	for light_x in [-5.0, 5.0]:
		var castle_light := OmniLight3D.new()
		castle_light.light_color = Color("ffe4a8")
		castle_light.light_energy = 1.35
		castle_light.omni_range = 13.0
		castle_light.position = Vector3(light_x, 4.5, -4.0)
		castle.add_child(castle_light)


# A non-colliding constellation promenade turns the functional row of islands
# into a visible Castle Galaxy voyage. It deliberately sits outside the playable
# centre lane and never spans a Lens gap, so it cannot become a bypass route.
func _build_celestial_route_spine() -> void:
	var route := Node3D.new()
	route.name = "CelestialRouteSpine"
	add_child(route)
	var route_colours := [Color("8fd3ff"), Color("ff9de2"), Color("ffd76a")]
	for i in 16:
		var colour: Color = route_colours[i % route_colours.size()]
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := -31.0 + float(i) * 4.45
		var pylon := MeshInstance3D.new()
		pylon.name = "AetherPylon"
		var pylon_mesh := CylinderMesh.new()
		pylon_mesh.top_radius = 0.10
		pylon_mesh.bottom_radius = 0.52
		pylon_mesh.height = 3.4 + float(i % 3) * 0.7
		pylon_mesh.radial_segments = 6
		pylon.mesh = pylon_mesh
		pylon.material_override = _stone_material(Color("34405f"), true)
		pylon.position = Vector3(side * (13.8 + float(i % 2) * 1.7), pylon_mesh.height * 0.5, z)
		route.add_child(pylon)
		var pylon_tip := MeshInstance3D.new()
		var tip_mesh := CylinderMesh.new()
		tip_mesh.top_radius = 0.0
		tip_mesh.bottom_radius = 0.20
		tip_mesh.height = 0.55
		tip_mesh.radial_segments = 5
		pylon_tip.mesh = tip_mesh
		pylon_tip.material_override = _finale_material(colour, 1.0)
		pylon_tip.position = pylon.position + Vector3(0.0, pylon_mesh.height * 0.5 + 0.22, 0.0)
		route.add_child(pylon_tip)
		if i % 3 == 0:
			var beacon := OmniLight3D.new()
			beacon.light_color = colour
			beacon.light_energy = 0.48
			beacon.omni_range = 7.0
			beacon.position = pylon.position + Vector3(0.0, 1.6, 0.0)
			route.add_child(beacon)

	# Three vertical constellation arches hover beside the real gaps. They act
	# as wayfinding landmarks, not bridges or physics objects.
	for i in 3:
		var arch := MeshInstance3D.new()
		arch.name = "ConstellationArch"
		var arch_mesh := TorusMesh.new()
		arch_mesh.inner_radius = 2.45
		arch_mesh.outer_radius = 2.67
		arch_mesh.rings = 12
		arch_mesh.ring_segments = 6
		arch.mesh = arch_mesh
		arch.material_override = _finale_material(route_colours[i], 0.85)
		arch.rotation.x = PI * 0.5
		arch.position = Vector3(13.2, 4.0, float(CHAPTERS[i]["z"]) + 4.0)
		route.add_child(arch)

	# Asteroid silhouettes at different depths make the galaxy feel vast without
	# adding collision, gameplay state, or a texture dependency.
	for i in 12:
		var asteroid := MeshInstance3D.new()
		asteroid.name = "GalaxyAsteroid"
		var asteroid_mesh := SphereMesh.new()
		asteroid_mesh.radius = 0.5 + float(i % 3) * 0.28
		asteroid_mesh.height = asteroid_mesh.radius * 1.7
		asteroid_mesh.radial_segments = 6
		asteroid_mesh.rings = 4
		asteroid.mesh = asteroid_mesh
		asteroid.material_override = _stone_material(Color("25233d"), true)
		var side := -1.0 if (i / 2) % 2 == 0 else 1.0
		asteroid.position = Vector3(side * (20.0 + float(i % 4) * 3.0),
			4.0 + float(i % 4) * 2.3, -26.0 + float(i) * 5.7)
		asteroid.rotation = Vector3(0.2 * float(i), 0.4 * float(i), 0.15 * float(i))
		route.add_child(asteroid)


func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.name = "StoryPlayer"
	_player.add_to_group("player")
	# This story drives the body itself and respawns at its chapter checkpoint,
	# so the general Milo fall rescue (milo_fall_rescue.gd) stays out of it.
	_player.set_meta(&"custom_fall_recovery", true)

	var capsule := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.4
	capsule_shape.height = 1.8
	capsule.shape = capsule_shape
	capsule.position.y = 0.9
	_player.add_child(capsule)

	_camera = Camera3D.new()
	_camera.name = "StoryCamera"
	_camera.fov = 75.0
	_camera.far = 300.0
	_camera.position.y = 1.6
	_player.add_child(_camera)

	add_child(_player)
	_player.global_position = Vector3(0.0, 1.0, CHAPTERS[0]["z"] - 10.0)
	# Godot cameras look down local -Z. Turn the player toward the journey,
	# which advances along +Z from Mind Spark to Creator's Light.
	_yaw = PI
	_player.rotation.y = _yaw
	_pitch = 0.0

	var lens := ControllerScript.new()
	lens.name = "LensController"
	lens.camera = _camera
	# Chapter evidence is persisted by _on_gap_filled. Raw geometry replay is
	# disabled by default because LensPersistence is shared across scenes.
	lens.persist = persist_lens_placements
	lens.show_idle_hint = false
	lens.show_narrative_messages = false
	_camera.add_child(lens)
	var viewfinder := lens.find_child("ViewfinderLens", true, false)
	if viewfinder != null:
		# A freshly reparented StaticBody3D does not consistently emit an
		# Area3D body_entered event in every Godot physics backend. The Lens's
		# own placement signal is authoritative; verify the resulting fragment
		# pose against the goal volume as a deterministic companion check.
		viewfinder.seeing_placed.connect(_on_seeing_placed)


# --- zones --------------------------------------------------------------

func _build_zone(index: int) -> void:
	var chapter: Dictionary = CHAPTERS[index]
	var centre_z: float = chapter["z"]

	var root := Node3D.new()
	root.name = "Zone_%s" % chapter["id"]
	add_child(root)
	_zone_roots.append(root)

	_build_zone_lighting(root, chapter, centre_z)
	_build_chapter_floor_motif(root, chapter, centre_z)
	_build_zone_landmark(root, chapter, centre_z)
	_build_gap(root, chapter, centre_z, index)
	_build_source(root, chapter, centre_z)
	_build_guardian_label(root, chapter, centre_z)
	_build_guardian_avatar(root, index, centre_z)


func _build_zone_lighting(root: Node3D, chapter: Dictionary, centre_z: float) -> void:
	var glow := OmniLight3D.new()
	glow.light_color = chapter["colour"]
	glow.light_energy = 0.55
	glow.omni_range = 14.0
	glow.position = Vector3(0.0, 3.0, centre_z)
	root.add_child(glow)

	# A softer rim light from the opposite side keeps the guardian and source
	# from going flat/silhouetted against the zone's own key light.
	var rim := OmniLight3D.new()
	rim.light_color = chapter["colour"].lightened(0.3)
	rim.light_energy = 0.25
	rim.omni_range = 10.0
	rim.position = Vector3(-4.0, 2.2, centre_z - 3.5)
	root.add_child(rim)


# Chapter-specific floor identity beyond colour: thin, non-colliding inlays
# only, laid directly on the island top so the physics floor never changes.
# Mind reads crystalline/celestial, Heart reads musical with note-path rings,
# Creator's Light reads like a studio/forge with palette-accent wedges.
func _build_chapter_floor_motif(root: Node3D, chapter: Dictionary, centre_z: float) -> void:
	var motif := Node3D.new()
	motif.name = "FloorMotif_%s" % chapter["id"]
	motif.position = Vector3(0.0, 0.02, centre_z)
	root.add_child(motif)
	var colour: Color = chapter["colour"]
	var inlay_mat := _finale_material(colour, 0.5)

	match str(chapter["id"]):
		"mind_spark":
			# Concentric hexagonal rings suggest a crystalline star chart.
			for i in 3:
				var ring := MeshInstance3D.new()
				var ring_mesh := TorusMesh.new()
				var outer := 2.4 + float(i) * 1.6
				ring_mesh.outer_radius = outer
				ring_mesh.inner_radius = outer - 0.08
				ring_mesh.rings = 6
				ring_mesh.ring_segments = 4
				ring.mesh = ring_mesh
				ring.material_override = inlay_mat
				ring.rotation.y = deg_to_rad(30.0 * float(i))
				motif.add_child(ring)
		"heart_melody":
			# Note-path rings pulse outward from the harmony jewel like ripples.
			for i in 4:
				var ring := MeshInstance3D.new()
				var ring_mesh := TorusMesh.new()
				var outer := 1.8 + float(i) * 1.1
				ring_mesh.outer_radius = outer
				ring_mesh.inner_radius = outer - 0.1
				ring_mesh.rings = 24
				ring_mesh.ring_segments = 4
				ring.mesh = ring_mesh
				ring.material_override = inlay_mat
				motif.add_child(ring)
		"creators_light":
			# Palette-accent wedges fan out like a painter's palette on the
			# studio floor, using the three creative-choice colours.
			for i in CREATIVE_CHOICES.size():
				var wedge := MeshInstance3D.new()
				var wedge_mesh := CylinderMesh.new()
				wedge_mesh.top_radius = 3.0
				wedge_mesh.bottom_radius = 3.0
				wedge_mesh.height = 0.06
				wedge_mesh.radial_segments = 3
				wedge.mesh = wedge_mesh
				wedge.material_override = _finale_material(CREATIVE_CHOICES[i]["colour"], 0.45)
				wedge.rotation.y = deg_to_rad(120.0 * float(i))
				wedge.position = Vector3(0.0, 0.0, -2.0)
				motif.add_child(wedge)


# A tall, non-colliding silhouette at the side of each zone makes the three
# chapters readable from the previous island. The player still solves the same
# source, gap, and gate; this only gives the science-magic journey landmarks.
func _build_zone_landmark(root: Node3D, chapter: Dictionary, centre_z: float) -> void:
	var landmark := Node3D.new()
	landmark.name = "Landmark_%s" % chapter["id"]
	root.add_child(landmark)
	var colour: Color = chapter["colour"]
	var anchor := Vector3(9.2, 0.0, centre_z - 1.0)

	match str(chapter["id"]):
		"mind_spark":
			# Crystalline observatory with a suspended star-chart orbit.
			for i in 3:
				var crystal := MeshInstance3D.new()
				crystal.name = "ObservatoryCrystal"
				var crystal_mesh := CylinderMesh.new()
				crystal_mesh.top_radius = 0.0
				crystal_mesh.bottom_radius = 0.58
				crystal_mesh.height = 4.4 + float(i % 2) * 1.2
				crystal_mesh.radial_segments = 6
				crystal.mesh = crystal_mesh
				crystal.material_override = _finale_material(colour, 1.1)
				crystal.position = anchor + Vector3(float(i - 1) * 1.15,
					crystal_mesh.height * 0.5, float(i % 2) * 1.1 - 0.55)
				landmark.add_child(crystal)
			var orbit := MeshInstance3D.new()
			var orbit_mesh := TorusMesh.new()
			orbit_mesh.inner_radius = 2.35
			orbit_mesh.outer_radius = 2.48
			orbit_mesh.rings = 12
			orbit_mesh.ring_segments = 6
			orbit.mesh = orbit_mesh
			orbit.material_override = _finale_material(colour.lightened(0.25), 0.8)
			orbit.rotation.x = PI * 0.5
			orbit.position = anchor + Vector3(0.0, 3.5, 0.0)
			landmark.add_child(orbit)
		"heart_melody":
			# Resonance garden: tuning pylons and a vertical harmonic ring.
			for i in 4:
				var tuning_pylon := MeshInstance3D.new()
				tuning_pylon.name = "ResonancePylon"
				var pylon_mesh := CylinderMesh.new()
				pylon_mesh.top_radius = 0.18
				pylon_mesh.bottom_radius = 0.42
				pylon_mesh.height = 2.8 + float(i % 2) * 1.1
				pylon_mesh.radial_segments = 8
				tuning_pylon.mesh = pylon_mesh
				tuning_pylon.material_override = _finale_material(
					HEART_EMOTIONS[i]["colour"], 0.9)
				var angle := TAU * float(i) / 4.0
				tuning_pylon.position = anchor + Vector3(cos(angle) * 1.8,
					pylon_mesh.height * 0.5, sin(angle) * 1.8)
				landmark.add_child(tuning_pylon)
			for i in 2:
				var resonance_ring := MeshInstance3D.new()
				var ring_mesh := TorusMesh.new()
				ring_mesh.inner_radius = 2.0 + float(i) * 0.6
				ring_mesh.outer_radius = ring_mesh.inner_radius + 0.12
				ring_mesh.rings = 18
				ring_mesh.ring_segments = 6
				resonance_ring.mesh = ring_mesh
				resonance_ring.material_override = _finale_material(colour, 0.75)
				resonance_ring.rotation.x = PI * 0.5
				resonance_ring.position = anchor + Vector3(0.0, 2.9 + float(i) * 1.1, 0.0)
				landmark.add_child(resonance_ring)
		"creators_light":
			# Luminous atelier/forge: three palette prisms in a solar armature.
			for i in CREATIVE_CHOICES.size():
				var prism := MeshInstance3D.new()
				prism.name = "AtelierPrism"
				var prism_mesh := CylinderMesh.new()
				prism_mesh.top_radius = 0.0
				prism_mesh.bottom_radius = 0.48
				prism_mesh.height = 3.4
				prism_mesh.radial_segments = 5
				prism.mesh = prism_mesh
				prism.material_override = _finale_material(CREATIVE_CHOICES[i]["colour"], 1.0)
				var angle := TAU * float(i) / float(CREATIVE_CHOICES.size())
				prism.position = anchor + Vector3(cos(angle) * 1.8, 1.7, sin(angle) * 1.8)
				landmark.add_child(prism)
			var forge_ring := MeshInstance3D.new()
			var forge_mesh := TorusMesh.new()
			forge_mesh.inner_radius = 2.65
			forge_mesh.outer_radius = 2.84
			forge_mesh.rings = 16
			forge_mesh.ring_segments = 6
			forge_ring.mesh = forge_mesh
			forge_ring.material_override = _finale_material(colour, 1.0)
			forge_ring.rotation.x = PI * 0.5
			forge_ring.position = anchor + Vector3(0.0, 3.7, 0.0)
			landmark.add_child(forge_ring)

	var landmark_light := OmniLight3D.new()
	landmark_light.light_color = colour
	landmark_light.light_energy = 0.65
	landmark_light.omni_range = 9.0
	landmark_light.position = anchor + Vector3(0.0, 3.0, 0.0)
	landmark.add_child(landmark_light)


# The missing bridge: a gap in the floor spanned by a permanent safe bridge
# that only appears once the chapter's seeing has been placed here. Until
# then the player must detour around rather than fall through — the gap itself
# stays a visual/physical absence, not a bottomless pit.
func _build_gap(root: Node3D, chapter: Dictionary, centre_z: float, index: int) -> void:
	var gap_z := centre_z + 4.0

	var area := Area3D.new()
	area.name = "Gap_%s" % chapter["id"]
	# Listens ONLY for Cuttable fragment bodies (frustum_cutter.CUTTABLE_MASK),
	# matching the handoff: the gap does not react to the player walking
	# through, only to a placed seeing landing in it.
	area.collision_layer = 0
	area.collision_mask = FrustumCutterScript.CUTTABLE_MASK
	area.monitoring = true
	var area_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 3.0)
	area_shape.shape = box
	area.add_child(area_shape)
	area.position = Vector3(0.0, 1.5, gap_z)
	root.add_child(area)
	_gap_areas.append(area)
	area.body_entered.connect(_on_gap_filled.bind(index))

	var bridge := StaticBody3D.new()
	bridge.name = "Bridge_%s" % chapter["id"]
	bridge.visible = false
	bridge.collision_layer = 0
	var bridge_mesh := MeshInstance3D.new()
	var bridge_box := BoxMesh.new()
	bridge_box.size = Vector3(4.0, 0.4, 3.0)
	bridge_mesh.mesh = bridge_box
	var bridge_mat := StandardMaterial3D.new()
	bridge_mat.albedo_color = chapter["colour"]
	bridge_mat.emission_enabled = true
	bridge_mat.emission = chapter["colour"]
	bridge_mat.emission_energy_multiplier = 0.6
	bridge_mesh.material_override = bridge_mat
	bridge.add_child(bridge_mesh)
	var bridge_shape := CollisionShape3D.new()
	var bridge_col := BoxShape3D.new()
	bridge_col.size = bridge_box.size
	bridge_shape.shape = bridge_col
	bridge.add_child(bridge_shape)
	bridge.position = Vector3(0.0, 0.05, gap_z)
	root.add_child(bridge)
	_bridges.append(bridge)

	# Glowing side trim and small posts on the bridge deck, non-colliding so
	# the tested bridge collision shape above stays exactly a 4x0.4x3 box.
	var trim_mat := _finale_material(chapter["colour"], 1.1)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.name = "BridgeRail"
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.12, 0.12, 3.1)
		rail.mesh = rail_mesh
		rail.material_override = trim_mat
		rail.position = Vector3(side * 1.94, 0.28, 0.0)
		bridge.add_child(rail)
		for post_i in 3:
			var post := MeshInstance3D.new()
			post.name = "BridgePost"
			var post_mesh := CylinderMesh.new()
			post_mesh.top_radius = 0.05
			post_mesh.bottom_radius = 0.05
			post_mesh.height = 0.4
			post.mesh = post_mesh
			post.material_override = trim_mat
			post.position = Vector3(side * 1.94, 0.34, (float(post_i) - 1.0) * 1.4)
			bridge.add_child(post)

	# Chasm edge trim on the approach/far lips so the gap reads as an authored
	# drop rather than the level simply stopping; purely visual, no collision.
	var chasm_trim := _stone_material(Color(0.10, 0.10, 0.14))
	for edge_z in [gap_z - 1.55, gap_z + 1.55]:
		var lip := MeshInstance3D.new()
		lip.name = "ChasmLip"
		var lip_mesh := BoxMesh.new()
		lip_mesh.size = Vector3(ZONE_WIDTH + 6.2, 0.5, 0.3)
		lip.mesh = lip_mesh
		lip.material_override = chasm_trim
		lip.position = Vector3(0.0, -0.28, edge_z)
		root.add_child(lip)

	# Even a running jump cannot skip the story order. This energy gate stands
	# just beyond the chasm and becomes non-solid only after a Cuttable seeing
	# enters the corresponding goal area.
	var gate := StaticBody3D.new()
	gate.name = "Gate_%s" % chapter["id"]
	gate.collision_layer = 1
	var gate_mesh := MeshInstance3D.new()
	var gate_box := BoxMesh.new()
	gate_box.size = Vector3(ZONE_WIDTH + 6.0, 4.5, 0.35)
	gate_mesh.mesh = gate_box
	var gate_mat := StandardMaterial3D.new()
	gate_mat.albedo_color = Color(chapter["colour"], 0.14)
	gate_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gate_mat.emission_enabled = true
	gate_mat.emission = chapter["colour"]
	gate_mat.emission_energy_multiplier = 0.18
	gate_mesh.material_override = gate_mat
	# The collider remains a full anti-bypass wall, but drawing that whole box
	# made the journey look like a test corridor. The visible portal below now
	# carries the gate's presence while this mesh remains physics-only.
	gate_mesh.visible = false
	gate.add_child(gate_mesh)
	var gate_shape := CollisionShape3D.new()
	var gate_collision := BoxShape3D.new()
	gate_collision.size = gate_box.size
	gate_shape.shape = gate_collision
	gate.add_child(gate_shape)
	gate.position = Vector3(0.0, 2.25, gap_z + 2.0)
	root.add_child(gate)
	_gates.append(gate)

	# Arch frame around the gate so the energy field reads as authored magical
	# architecture (a doorway) rather than a bare translucent rectangle. Purely
	# decorative siblings of the gate, no collision, always visible regardless
	# of gate solidity so the doorway keeps reading once it opens.
	var frame_mat := _finale_material(chapter["colour"], 0.8)
	var frame_parent := Node3D.new()
	frame_parent.name = "GateFrame_%s" % chapter["id"]
	frame_parent.position = gate.position
	root.add_child(frame_parent)
	var frame_width := 8.2
	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(frame_width, 0.4, 0.5)
	lintel.mesh = lintel_mesh
	lintel.material_override = frame_mat
	lintel.position = Vector3(0.0, 2.45, 0.0)
	frame_parent.add_child(lintel)
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.4, 4.9, 0.5)
		post.mesh = post_mesh
		post.material_override = frame_mat
		post.position = Vector3(side * (frame_width * 0.5 - 0.2), 0.0, 0.0)
		frame_parent.add_child(post)
	# A spaced energy curtain retains the gate's magical presence while letting
	# players see the next island. It replaces the visual impression of one
	# giant translucent wall; collision remains the original tested box.
	var curtain_mat := StandardMaterial3D.new()
	curtain_mat.albedo_color = Color(chapter["colour"], 0.32)
	curtain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	curtain_mat.emission_enabled = true
	curtain_mat.emission = chapter["colour"]
	curtain_mat.emission_energy_multiplier = 0.35
	for beam_i in 5:
		var beam := MeshInstance3D.new()
		var beam_mesh := BoxMesh.new()
		beam_mesh.size = Vector3(0.07, 4.15, 0.10)
		beam.mesh = beam_mesh
		beam.material_override = curtain_mat
		beam.position = Vector3(-2.4 + float(beam_i) * 1.2, 0.0, -0.26)
		frame_parent.add_child(beam)


# The Cuttable source prop the player frames and carries to the gap. Simple
# low-poly geometry only, on physics layer 4 (frustum_cutter.CUTTABLE_MASK) —
# never Terrain3D, ProtonScatter, trains, rails, or the hub castle.
func _build_source(root: Node3D, chapter: Dictionary, centre_z: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Source_%s" % chapter["id"]
	# The story-specific interaction activates the Lens target. A player must
	# first transform a thought, voice emotions, or make a creative choice;
	# merely photographing the first glowing object is not the whole chapter.
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_meta("interaction_kind", chapter["id"])

	var mesh := _source_mesh_for(str(chapter["id"]))
	var baked := ArrayMesh.new()
	baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.get_mesh_arrays())
	var material := StandardMaterial3D.new()
	material.albedo_color = chapter["colour"]
	material.emission_enabled = true
	material.emission = chapter["colour"]
	material.emission_energy_multiplier = 1.1
	material.roughness = 0.3
	baked.surface_set_material(0, material)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = baked
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	shape.shape = baked.create_convex_shape()
	body.add_child(shape)

	root.add_child(body)
	body.global_position = Vector3(0.0, 1.6, centre_z - 4.0)
	_source_bodies.append(body)

	var label := Label3D.new()
	label.text = chapter["before"]
	label.font_size = 28
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 1.4, 0.0)
	body.add_child(label)
	_source_labels.append(label)

	# Visual-only shell/pedestal attached below the Cuttable body, not as its
	# child, so the cutter's mesh lookup on `body` (its own first
	# MeshInstance3D) and the Lens capture geometry stay exactly as before —
	# this only makes the source read as an authored artefact resting in the
	# world instead of a bare primitive floating in space.
	_build_source_shell(root, chapter, body.global_position)
	_build_interaction_symbols(root, chapter, body.global_position)


func _source_mesh_for(chapter_id: String) -> PrimitiveMesh:
	if chapter_id == "heart_melody":
		var note := TorusMesh.new()
		note.inner_radius = 0.32
		note.outer_radius = 0.82
		note.rings = 18
		note.ring_segments = 8
		return note
	if chapter_id == "creators_light":
		var canvas := BoxMesh.new()
		canvas.size = Vector3(1.7, 1.7, 0.45)
		return canvas
	var thought := SphereMesh.new()
	thought.radius = 0.9
	thought.height = 1.8
	thought.radial_segments = 16
	thought.rings = 10
	return thought


# A pedestal/grounding pool beneath each Cuttable source so it reads as a
# treasure resting on an authored plinth rather than hovering in empty air.
# Non-colliding decoration only; never a sibling of collision-bearing bodies.
func _build_source_shell(root: Node3D, chapter: Dictionary, centre: Vector3) -> void:
	var colour: Color = chapter["colour"]
	var pedestal := MeshInstance3D.new()
	pedestal.name = "SourcePedestal_%s" % chapter["id"]
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 1.0
	pedestal_mesh.bottom_radius = 1.25
	pedestal_mesh.height = 0.5
	pedestal_mesh.radial_segments = 8
	pedestal.mesh = pedestal_mesh
	pedestal.material_override = _stone_material(Color(0.12, 0.12, 0.16))
	pedestal.position = centre + Vector3(0.0, -1.35, 0.0)
	root.add_child(pedestal)

	var ring := MeshInstance3D.new()
	ring.name = "SourcePedestalRing_%s" % chapter["id"]
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.9
	ring_mesh.outer_radius = 1.05
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 6
	ring.mesh = ring_mesh
	ring.material_override = _finale_material(colour, 1.0)
	ring.position = centre + Vector3(0.0, -1.08, 0.0)
	root.add_child(ring)


func _build_interaction_symbols(root: Node3D, chapter: Dictionary, centre: Vector3) -> void:
	var chapter_id := str(chapter["id"])
	if chapter_id == "heart_melody":
		for i in HEART_EMOTIONS.size():
			var note := MeshInstance3D.new()
			note.name = "Emotion_%s" % HEART_EMOTIONS[i]["name"]
			var note_mesh := SphereMesh.new()
			note_mesh.radius = 0.20
			note_mesh.height = 0.40
			note.mesh = note_mesh
			note.material_override = _finale_material(HEART_EMOTIONS[i]["colour"], 1.0)
			var angle := TAU * float(i) / float(HEART_EMOTIONS.size())
			root.add_child(note)
			note.global_position = centre + Vector3(cos(angle) * 2.2, 0.5 + 0.3 * float(i % 2), sin(angle) * 2.2)
	elif chapter_id == "creators_light":
		for i in CREATIVE_CHOICES.size():
			var crystal := MeshInstance3D.new()
			crystal.name = "CreativeChoice_%d" % (i + 1)
			var crystal_mesh := CylinderMesh.new()
			crystal_mesh.top_radius = 0.0
			crystal_mesh.bottom_radius = 0.32
			crystal_mesh.height = 1.1
			crystal_mesh.radial_segments = 5
			crystal.mesh = crystal_mesh
			crystal.material_override = _finale_material(CREATIVE_CHOICES[i]["colour"], 1.0)
			root.add_child(crystal)
			crystal.global_position = centre + Vector3(float(i - 1) * 1.4, -0.7, -1.8)


func _build_guardian_label(root: Node3D, chapter: Dictionary, centre_z: float) -> void:
	var label := Label3D.new()
	label.text = "%s\n\"%s\"" % [chapter["label"], chapter["theme"]]
	label.font_size = 38
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Stage the chapter title opposite the guardian instead of stacking it over
	# the source, gate and character dialogue in the centre of the frame.
	label.position = Vector3(-4.2, 4.0, centre_z + 0.8)
	add_child(label)
	_guardian_labels.append(label)


func _build_milo_guide() -> void:
	var packed := load(MILO_MODEL) as PackedScene
	if packed == null:
		return
	var milo := packed.instantiate() as Node3D
	if milo == null:
		return
	milo.name = "MiloGuide"
	add_child(milo)
	milo.position = Vector3(4.5, 0.0, -29.0)
	milo.rotation.y = deg_to_rad(-135.0)
	_play_idle_animation(milo)
	_build_grounding_sigil(self, milo.position, Color("cfe0ff"))


func _build_guardian_avatar(root: Node3D, index: int, centre_z: float) -> void:
	var packed := load(GUARDIAN_MODELS[index]) as PackedScene
	if packed == null:
		return
	var avatar := packed.instantiate() as Node3D
	if avatar == null:
		return
	avatar.name = "GuardianAvatar_%s" % CHAPTERS[index]["id"]
	root.add_child(avatar)
	var position := Vector3(-5.0, 0.0, centre_z - 1.0)
	avatar.global_position = position
	avatar.rotation.y = deg_to_rad(90.0)
	_play_idle_animation(avatar)

	# Grounding pool/rune beneath the guardian plus a subtle key light so they
	# read as staged rather than dropped into empty space.
	_build_grounding_sigil(root, position, CHAPTERS[index]["colour"])
	var key_light := OmniLight3D.new()
	key_light.name = "GuardianKeyLight_%s" % CHAPTERS[index]["id"]
	key_light.light_color = Color(1.0, 0.96, 0.88)
	key_light.light_energy = 0.55
	key_light.omni_range = 6.0
	key_light.position = position + Vector3(1.2, 2.6, 1.0)
	root.add_child(key_light)


# Shared grounding pool/rune used under both Milo and each guardian: a flat
# emissive disc plus a thin rune ring, non-colliding, sitting just above the
# floor so characters read as intentionally placed rather than floating.
func _build_grounding_sigil(root: Node3D, position: Vector3, colour: Color) -> void:
	var pool := MeshInstance3D.new()
	pool.name = "GroundingPool"
	var pool_mesh := CylinderMesh.new()
	pool_mesh.top_radius = 1.3
	pool_mesh.bottom_radius = 1.3
	pool_mesh.height = 0.03
	pool_mesh.radial_segments = 20
	pool.mesh = pool_mesh
	pool.material_override = _finale_material(colour, 0.22)
	pool.position = position + Vector3(0.0, 0.02, 0.0)
	root.add_child(pool)

	var rune := MeshInstance3D.new()
	rune.name = "GroundingRune"
	var rune_mesh := TorusMesh.new()
	rune_mesh.inner_radius = 1.35
	rune_mesh.outer_radius = 1.5
	rune_mesh.rings = 20
	rune_mesh.ring_segments = 4
	rune.mesh = rune_mesh
	rune.material_override = _finale_material(colour, 0.5)
	rune.position = position + Vector3(0.0, 0.04, 0.0)
	root.add_child(rune)


func _play_idle_animation(character: Node3D) -> void:
	var animation_player := character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		return
	var animations := animation_player.get_animation_list()
	for candidate in animations:
		if str(candidate).to_lower().contains("idle"):
			animation_player.play(candidate)
			return


# --- chapter completion ---------------------------------------------------

func _on_gap_filled(body: Node3D, index: int) -> void:
	if body == null:
		return
	var chapter: Dictionary = CHAPTERS[index]
	if not _zone_unlocked(index):
		# A fragment landed here out of order — refuse it as a chapter
		# completion, but do not undo the placement itself; the Lens already
		# guarantees reversibility via Esc/release.
		return
	if not bool(_interaction_complete[index]):
		_show_guardian_line("Milo: This seeing is not ready yet. Complete the kingdom's discovery first, then frame it with the Lens.")
		return

	var js := get_node_or_null("/root/JourneyState")
	var already_recorded: bool = js != null and js.has_story_chapter(chapter["id"])
	if js != null and not already_recorded:
		js.record_story_chapter(chapter["id"])
		js.record_bridging(str(chapter["label"]), "Crown of Life path")

	var label: Label3D = _guardian_labels[index]
	label.text = "%s\n\"%s\"" % [chapter["label"], chapter["after"]]

	_show_guardian_line(chapter["line_after"].get(_audience_mode(), chapter["line_after"]["faith"]))
	_refresh_gates()

	if not already_recorded:
		_play_sfx(CHAPTER_SFX.get(chapter["id"], ""))
		_play_treasure_transition(index, chapter)
		_checkpoint = _player.global_position
		_update_progress_hud()

	if index == CHAPTERS.size() - 1 and js != null and js.story_chapters_complete():
		if js.has_all_treasures() and not _finale_built:
			_finale_built = true
			_build_finale(js)
		elif not js.has_all_treasures():
			_show_guardian_line("Milo: Lens path complete. Artéa remembered your crossings; return to the Castle to continue the three kingdom journey.")


func _on_seeing_placed(_placed_count: int) -> void:
	for i in CHAPTERS.size():
		if not _zone_unlocked(i):
			continue
		var js := get_node_or_null("/root/JourneyState")
		if js != null and js.has_story_chapter(CHAPTERS[i]["id"]):
			continue
		var gap := _gap_areas[i]
		for body in find_children("*", "StaticBody3D", true, false):
			if body.collision_layer & FrustumCutterScript.CUTTABLE_MASK == 0:
				continue
			var local := gap.to_local(body.global_position)
			if absf(local.x) <= 2.0 and absf(local.y) <= 2.0 and absf(local.z) <= 1.5:
				_on_gap_filled(body, i)
				return


func _zone_unlocked(index: int) -> bool:
	if index == 0:
		return true
	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return true
	var previous: Dictionary = CHAPTERS[index - 1]
	return js.has_story_chapter(previous["id"])


# Chapters must be crossed in order. A zone whose predecessor is not yet
# complete keeps its gap and gate closed. Guardian introductions are handled
# by proximity in _update_story_prompt(), so Milo's prologue remains readable
# until the player actually approaches Mind Spark.
func _refresh_gates() -> void:
	var js := get_node_or_null("/root/JourneyState")
	for i in CHAPTERS.size():
		var complete: bool = js != null and js.has_story_chapter(CHAPTERS[i]["id"])
		_bridges[i].visible = complete
		_bridges[i].collision_layer = 1 if complete else 0
		_gates[i].visible = not complete
		_gates[i].collision_layer = 0 if complete else 1
		_gap_areas[i].monitoring = not complete


func _update_story_prompt() -> void:
	if _player == null:
		return
	var js := get_node_or_null("/root/JourneyState")
	for i in CHAPTERS.size():
		if _greeted.has(i) or not _zone_unlocked(i):
			continue
		if bool(_interaction_complete[i]):
			continue
		var chapter: Dictionary = CHAPTERS[i]
		if js != null and js.has_story_chapter(chapter["id"]):
			continue
		var source_z := float(chapter["z"]) - 4.0
		if absf(_player.global_position.z - source_z) <= 5.5:
			_greeted.append(i)
			_show_guardian_line(chapter["line_before"].get(
				_audience_mode(), chapter["line_before"]["faith"]))
			_checkpoint = _player.global_position
			_update_objective_hud(i)
			return


func _restore_interaction_state() -> void:
	var js := get_node_or_null("/root/JourneyState")
	for i in CHAPTERS.size():
		var complete: bool = js != null and js.has_story_chapter(CHAPTERS[i]["id"])
		_interaction_complete[i] = complete
		_source_bodies[i].collision_layer = 0 if complete else 0


func _current_chapter_index() -> int:
	var js := get_node_or_null("/root/JourneyState")
	for i in CHAPTERS.size():
		if js == null or not js.has_story_chapter(CHAPTERS[i]["id"]):
			return i
	return -1


func _is_near_source(index: int) -> bool:
	if index < 0 or index >= _source_bodies.size() or _player == null:
		return false
	var flat_player := Vector2(_player.global_position.x, _player.global_position.z)
	var flat_source := Vector2(_source_bodies[index].global_position.x, _source_bodies[index].global_position.z)
	return flat_player.distance_to(flat_source) <= INTERACT_RADIUS


# The three pre-Lens discoveries make the kingdoms mechanically different:
# one reframes a thought, one gives every named feeling a voice, and one asks
# for an ungraded creative choice. Returns true only when the Lens source has
# become ready, which keeps this public enough for deterministic acceptance
# tests without synthesising key events.
func _perform_current_interaction(choice: int = -1) -> bool:
	var index := _current_chapter_index()
	if index < 0 or not _zone_unlocked(index):
		return false
	if not _is_near_source(index):
		_show_guardian_line("Milo: Move closer to the glowing discovery first.")
		return false
	if bool(_interaction_complete[index]):
		return true

	var chapter: Dictionary = CHAPTERS[index]
	if not _greeted.has(index):
		_greeted.append(index)
	match str(chapter["id"]):
		"mind_spark":
			_source_labels[index].text = "I am learning and growing."
			_show_guardian_line("Choose hope: a thought is something you can notice and reframe—not a verdict about who you are.")
			_activate_source(index, chapter["colour"])
		"heart_melody":
			var emotion: Dictionary = HEART_EMOTIONS[_heart_emotions_heard]
			_heart_emotions_heard += 1
			_source_labels[index].text = "%s has a voice  •  %d/%d" % [
				emotion["name"], _heart_emotions_heard, HEART_EMOTIONS.size()]
			_show_guardian_line("Raphael: %s belongs in your melody. Every feeling can be named and heard safely." % emotion["name"])
			_play_sfx(str(emotion["sound"]))
			_set_source_colour(index, emotion["colour"])
			if _heart_emotions_heard >= HEART_EMOTIONS.size():
				_source_labels[index].text = "My feelings have a voice."
				_activate_source(index, chapter["colour"])
		"creators_light":
			var selected := clampi(choice if choice >= 0 else 0, 0, CREATIVE_CHOICES.size() - 1)
			_creative_choice = selected
			var creation: Dictionary = CREATIVE_CHOICES[selected]
			_source_labels[index].text = str(creation["name"])
			_show_guardian_line("Uriel: You chose the %s. It does not need a score—its meaning comes from the choice only you made." % creation["name"])
			_activate_source(index, creation["colour"])

	_update_objective_hud(index)
	return bool(_interaction_complete[index])


func _activate_source(index: int, colour: Color) -> void:
	_interaction_complete[index] = true
	_source_bodies[index].collision_layer = FrustumCutterScript.CUTTABLE_MASK
	_set_source_colour(index, colour)
	_play_sfx(CHAPTER_SFX.get(CHAPTERS[index]["id"], ""))


func _set_source_colour(index: int, colour: Color) -> void:
	var mesh_instance := _source_bodies[index].get_child(0) as MeshInstance3D
	if mesh_instance == null:
		return
	mesh_instance.material_override = _finale_material(colour, 1.35)


func _audience_mode() -> String:
	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return "faith"
	return str(js.audience_mode)


# --- finale ---------------------------------------------------------------

func _build_finale(js: Node) -> void:
	js.advance_to(4)

	var finale_z: float = CHAPTERS[CHAPTERS.size() - 1]["z"] + 14.0

	# Sits just above the camera's eye height (camera.y = 1.6) like a crown
	# actually worn on the head, instead of floating well above the frame.
	var crown := Node3D.new()
	crown.name = "CrownOfLife"
	_player.add_child(crown)
	crown.position = Vector3(0.0, 1.78, 0.0)
	crown.scale = Vector3.ONE * 0.62
	var gold := _finale_material(Color("ffd76a"), 1.2)
	var rim := MeshInstance3D.new()
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.25
	rim_mesh.outer_radius = 0.34
	rim_mesh.rings = 16
	rim_mesh.ring_segments = 6
	rim.mesh = rim_mesh
	rim.material_override = gold
	crown.add_child(rim)

	var jewel_colours := [Color("ffd966"), Color("8fd3ff"), Color("ff8fcf")]
	for i in 7:
		var point := MeshInstance3D.new()
		var point_mesh := CylinderMesh.new()
		point_mesh.top_radius = 0.0
		point_mesh.bottom_radius = 0.065
		point_mesh.height = 0.28 + 0.06 * float(i % 2)
		point_mesh.radial_segments = 5
		point.mesh = point_mesh
		var angle := TAU * float(i) / 7.0
		point.position = Vector3(cos(angle) * 0.30, 0.16, sin(angle) * 0.30)
		point.material_override = _finale_material(jewel_colours[i % 3], 1.8)
		crown.add_child(point)

	var star := Node3D.new()
	star.name = "IdentityStar"
	add_child(star)
	star.position = Vector3(0.0, 12.0, finale_z)
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.8
	core_mesh.height = 1.6
	core.mesh = core_mesh
	core.material_override = _finale_material(Color("fff3a1"), 2.5)
	star.add_child(core)

	# Four crossed ray shafts so the star reads as a sigil/star rather than a
	# plain sphere, without any moving parts (reduce-motion safe).
	for i in 4:
		var ray := MeshInstance3D.new()
		var ray_mesh := BoxMesh.new()
		ray_mesh.size = Vector3(0.16, 2.6, 0.16)
		ray.mesh = ray_mesh
		ray.material_override = _finale_material(Color("fff3a1"), 1.6)
		ray.rotation.z = deg_to_rad(45.0 * float(i))
		star.add_child(ray)

	var star_label := Label3D.new()
	var who := "YOUR"
	var global_node := get_node_or_null("/root/Global")
	if global_node != null and not str(global_node.current_user_name).strip_edges().is_empty():
		who = str(global_node.current_user_name).strip_edges().to_upper() + "'S"
	star_label.text = "%s STAR\nYOUR STORY MATTERS" % who
	star_label.position.y = 1.8
	star_label.font_size = 34
	star_label.outline_size = 10
	star_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Label3D's billboard front faces away from this +Z journey camera when it
	# inherits the finale node basis; flip the local face so the name is never
	# mirrored in gameplay or presentation captures.
	star_label.rotation.y = PI
	star.add_child(star_label)

	var train := Node3D.new()
	train.name = "RainbowGalaxyTrain"
	add_child(train)
	train.position = Vector3(0.0, 8.0, finale_z)
	var rainbow := [Color("ff5f6d"), Color("ffd166"), Color("55e6c1"), Color("62a8ff"), Color("c77dff")]
	for i in rainbow.size():
		var car := Node3D.new()
		car.name = "TrainCar%d" % i
		car.position = Vector3(0.0, 0.0, -float(i) * 2.0)
		train.add_child(car)

		var body := MeshInstance3D.new()
		var car_mesh := BoxMesh.new()
		car_mesh.size = Vector3(1.6, 1.2, 1.6)
		body.mesh = car_mesh
		body.material_override = _finale_material(rainbow[i], 1.35)
		car.add_child(body)

		# Layered roof and signal finial give each car a clear ceremonial train
		# silhouette instead of reading as one coloured modular cube.
		var roof := MeshInstance3D.new()
		var roof_mesh := BoxMesh.new()
		roof_mesh.size = Vector3(1.72, 0.22, 1.72)
		roof.mesh = roof_mesh
		roof.material_override = _finale_material(rainbow[i].lightened(0.18), 0.75)
		roof.position.y = 0.70
		car.add_child(roof)
		var finial := MeshInstance3D.new()
		var finial_mesh := CylinderMesh.new()
		finial_mesh.top_radius = 0.0
		finial_mesh.bottom_radius = 0.12
		finial_mesh.height = 0.34
		finial_mesh.radial_segments = 5
		finial.mesh = finial_mesh
		finial.material_override = _finale_material(Color("fff3a1"), 1.4)
		finial.position.y = 0.98
		car.add_child(finial)

		# Windows on both sides so cars read as train cars, not plain cubes.
		var window_mat := _finale_material(Color("fff7d6"), 2.0)
		for side in [-1.0, 1.0]:
			var window := MeshInstance3D.new()
			var window_mesh := BoxMesh.new()
			window_mesh.size = Vector3(0.05, 0.5, 0.9)
			window.mesh = window_mesh
			window.material_override = window_mat
			window.position = Vector3(side * 0.81, 0.15, 0.0)
			car.add_child(window)

		# Wheels along the bottom edge.
		var wheel_mat := _finale_material(Color("2c2c34"), 0.2)
		for wheel_side in [-1.0, 1.0]:
			for wheel_z in [-0.55, 0.55]:
				var wheel := MeshInstance3D.new()
				var wheel_mesh := CylinderMesh.new()
				wheel_mesh.top_radius = 0.22
				wheel_mesh.bottom_radius = 0.22
				wheel_mesh.height = 0.15
				wheel_mesh.radial_segments = 10
				wheel.mesh = wheel_mesh
				wheel.material_override = wheel_mat
				wheel.rotation.x = deg_to_rad(90.0)
				wheel.position = Vector3(wheel_side * 0.87, -0.68, wheel_z)
				car.add_child(wheel)

		# Coupler linking to the next car (skip the last car).
		if i < rainbow.size() - 1:
			var coupler := MeshInstance3D.new()
			var coupler_mesh := CylinderMesh.new()
			coupler_mesh.top_radius = 0.06
			coupler_mesh.bottom_radius = 0.06
			coupler_mesh.height = 0.4
			coupler_mesh.radial_segments = 6
			coupler.mesh = coupler_mesh
			coupler.material_override = wheel_mat
			coupler.rotation.x = deg_to_rad(90.0)
			coupler.position = Vector3(0.0, 0.0, -1.0)
			car.add_child(coupler)

	# Engine silhouette on the lead car: a rounded nose cone and headlamp.
	var lead_car: Node3D = train.get_child(0)
	var nose := MeshInstance3D.new()
	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.0
	nose_mesh.bottom_radius = 0.9
	nose_mesh.height = 1.0
	nose_mesh.radial_segments = 8
	nose.mesh = nose_mesh
	nose.material_override = _finale_material(rainbow[0], 1.35)
	nose.rotation.x = deg_to_rad(-90.0)
	nose.position = Vector3(0.0, 0.0, 1.3)
	lead_car.add_child(nose)
	var headlamp := MeshInstance3D.new()
	var headlamp_mesh := SphereMesh.new()
	headlamp_mesh.radius = 0.18
	headlamp_mesh.height = 0.36
	headlamp.mesh = headlamp_mesh
	headlamp.material_override = _finale_material(Color("fff7d6"), 2.4)
	headlamp.position = Vector3(0.0, -0.1, 1.75)
	lead_car.add_child(headlamp)

	# A luminous path beneath the train so it reads as riding a track through
	# the galaxy rather than floating disconnected from everything else.
	var path := Node3D.new()
	path.name = "TrainLuminousPath"
	add_child(path)
	path.position = Vector3(0.0, 6.6, finale_z)
	var path_mat := _finale_material(Color("bfe9ff"), 1.0)
	for rail_side in [-1.0, 1.0]:
		for i in 6:
			var segment := MeshInstance3D.new()
			var segment_mesh := BoxMesh.new()
			segment_mesh.size = Vector3(0.12, 0.06, 1.6)
			segment.mesh = segment_mesh
			segment.material_override = path_mat
			segment.position = Vector3(rail_side * 0.56, 0.0, -float(i) * 2.0 + 1.0)
			path.add_child(segment)
	for i in 7:
		var sleeper := MeshInstance3D.new()
		var sleeper_mesh := BoxMesh.new()
		sleeper_mesh.size = Vector3(1.55, 0.05, 0.14)
		sleeper.mesh = sleeper_mesh
		sleeper.material_override = _finale_material(Color("5a4c80"), 0.35)
		sleeper.position = Vector3(0.0, -0.05, -float(i) * 1.65 + 1.1)
		path.add_child(sleeper)

	# A wide constellation halo frames the earned finale without adding motion;
	# it ties the Crown, identity star, train and Artéa castle into one ceremony.
	var halo := Node3D.new()
	halo.name = "FinaleConstellationHalo"
	halo.position = Vector3(0.0, 10.0, finale_z)
	add_child(halo)
	for i in 3:
		var halo_ring := MeshInstance3D.new()
		var halo_mesh := TorusMesh.new()
		halo_mesh.inner_radius = 2.7 + float(i) * 0.55
		halo_mesh.outer_radius = halo_mesh.inner_radius + 0.09
		halo_mesh.rings = 16
		halo_mesh.ring_segments = 6
		halo_ring.mesh = halo_mesh
		halo_ring.material_override = _finale_material(jewel_colours[i], 0.65)
		halo_ring.rotation = Vector3(PI * 0.5, 0.0, deg_to_rad(24.0 * float(i)))
		halo.add_child(halo_ring)

	_show_finale_message(js)


func _finale_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.55
	material.roughness = 0.22
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _show_finale_message(js: Node) -> void:
	var who := ""
	var global_node := get_node_or_null("/root/Global")
	if global_node != null:
		who = str(global_node.current_user_name).strip_edges()
	var named := "The sky over Artéa knows your name now%s." % (
		"" if who.is_empty() else ", %s" % who)

	var message: String
	if str(js.audience_mode) == "faith":
		message = "The Maker: You are known. You are loved. You have been uniquely created with gifts and purpose.\n%s\nYour light has a place in this universe." % named
	else:
		message = "Milo: You are known. You are valued. Your gifts, purpose, and story are uniquely yours.\n%s\nYour light has a place in this universe." % named

	_show_guardian_line(message)
	_update_progress_hud()
	_build_finale_ui(named)


# --- finale replay / return / credits -------------------------------------

const CREDITS_TEXT := "Crown of Life\n\nMilo — your guide\nEverlasting Father / Keeper of Wisdom — Mind Spark Kingdom\nArchangel Raphael / Keeper of Healing — Heart Melody Kingdom\nUriel / Keeper of Creativity — Creator's Light Kingdom\n\nThank you for playing the Artéa Crown of Life story."

func _build_finale_ui(named_line: String) -> void:
	if _finale_layer != null and is_instance_valid(_finale_layer):
		return

	_finale_layer = CanvasLayer.new()
	_finale_layer.layer = 14
	add_child(_finale_layer)

	var dim := ColorRect.new()
	# Keep the finale actions legible without hiding the castle, star, train and
	# crown that the player has just earned.
	dim.color = Color(0.02, 0.02, 0.06, 0.20)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finale_layer.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.offset_left = -260.0
	box.offset_right = -18.0
	box.offset_top = -220.0
	box.offset_bottom = -18.0
	box.add_theme_constant_override("separation", 10)
	_finale_layer.add_child(box)

	var replay := Button.new()
	replay.text = "Replay Journey"
	replay.custom_minimum_size = Vector2(0, 40)
	replay.pressed.connect(_confirm_replay_journey)
	box.add_child(replay)

	var credits := Button.new()
	credits.text = "Credits"
	credits.custom_minimum_size = Vector2(0, 40)
	credits.pressed.connect(_show_credits)
	box.add_child(credits)

	var return_button := Button.new()
	return_button.text = _return_label()
	return_button.custom_minimum_size = Vector2(0, 40)
	return_button.pressed.connect(_return_to_castle)
	box.add_child(return_button)

	_apply_text_scale()


func _show_credits() -> void:
	_show_guardian_line(CREDITS_TEXT)


# Restarting the whole journey re-plays all three chapters from an empty
# state. Confirmed like any other progress-losing action (see
# _confirm_restart_journey), because it clears earned story chapters and
# treasures, not just the current scene.
func _confirm_replay_journey() -> void:
	_open_confirm(
		"Replay the whole journey? This clears your three earned treasures so you can experience the story again.",
		_replay_journey)


func _replay_journey() -> void:
	var js := get_node_or_null("/root/JourneyState")
	if js != null:
		# clear_journey() resets audience_mode to "faith" as part of a full
		# reset; a facilitator's chosen register is a session setting, not
		# story evidence, so restore it rather than silently overriding it.
		var mode := str(js.audience_mode)
		js.clear_journey()
		js.set_audience_mode(mode)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SceneLoader.change_scene(get_tree(), STORY_SCENE_PATH)


# --- HUD --------------------------------------------------------------

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 12
	add_child(_hud_layer)

	var root_control := Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(root_control)

	_controls_text = Label.new()
	_controls_text.text = "WASD move   Mouse look   Space jump   E discover   1–3 choose   Q Lens   Click take/place   T turn   Esc/P pause"
	_controls_text.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_controls_text.offset_left = -430.0
	_controls_text.offset_right = 430.0
	_controls_text.offset_top = 62.0
	_controls_text.offset_bottom = 84.0
	_controls_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls_text.add_theme_font_size_override("font_size", 14)
	_controls_text.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88, 1.0))
	_controls_text.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.02, 0.9))
	_controls_text.add_theme_constant_override("outline_size", 4)
	root_control.add_child(_controls_text)

	_objective_text = Label.new()
	_objective_text.name = "ObjectiveText"
	_objective_text.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective_text.offset_left = -430.0
	_objective_text.offset_right = 430.0
	_objective_text.offset_top = 18.0
	_objective_text.offset_bottom = 40.0
	_objective_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_text.add_theme_font_size_override("font_size", 17)
	_objective_text.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	root_control.add_child(_objective_text)

	_progress_text = Label.new()
	_progress_text.name = "ProgressText"
	_progress_text.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_progress_text.offset_left = -190.0
	_progress_text.offset_right = -18.0
	_progress_text.offset_top = 18.0
	_progress_text.offset_bottom = 40.0
	_progress_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress_text.add_theme_font_size_override("font_size", 16)
	_progress_text.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	root_control.add_child(_progress_text)

	_story_panel = ColorRect.new()
	_story_panel.color = Color(0.035, 0.045, 0.10, 0.78)
	_story_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_story_panel.offset_left = -480.0
	_story_panel.offset_right = 480.0
	_story_panel.offset_top = -178.0
	_story_panel.offset_bottom = -82.0
	_story_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(_story_panel)

	_guardian_text = Label.new()
	_guardian_text.name = "StoryMessage"
	_guardian_text.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_guardian_text.offset_left = -460.0
	_guardian_text.offset_right = 460.0
	_guardian_text.offset_top = -170.0
	_guardian_text.offset_bottom = -90.0
	_guardian_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guardian_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guardian_text.add_theme_font_size_override("font_size", 19)
	_guardian_text.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	root_control.add_child(_guardian_text)


func _show_guardian_line(text: String) -> void:
	# Every line is also the subtitle: this scene has no spoken audio, so
	# "subtitles" here means the caption stays up regardless of audio state.
	# The toggle governs whether it is shown at all, for a facilitator who
	# wants a cleaner screen once a child is reading confidently.
	_last_guardian_line = text
	if _guardian_text != null:
		_guardian_text.text = text if _subtitles_on else ""
		_guardian_text.visible = _subtitles_on


var _last_guardian_line := ""


# A visible Return to Castle action: shown as a persistent on-screen button
# rather than requiring the player to find a portal, since this is a short,
# bounded chapter rather than an open world.
func _build_return_action() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 13
	add_child(layer)

	var button := Button.new()
	button.name = "ReturnToCastleButton"
	button.text = _return_label()
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.offset_left = 18.0
	button.offset_top = 18.0
	button.offset_right = 190.0
	button.offset_bottom = 52.0
	button.pressed.connect(_confirm_return_to_castle)
	layer.add_child(button)

	var pause_button := Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "Pause"
	pause_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pause_button.offset_left = 198.0
	pause_button.offset_top = 18.0
	pause_button.offset_right = 280.0
	pause_button.offset_bottom = 52.0
	pause_button.pressed.connect(_toggle_pause)
	layer.add_child(pause_button)


# Leaving mid-chapter would silently drop an in-progress placement from the
# player's point of view even though JourneyState only records completed
# chapters — confirm so a stray click near the always-visible button cannot
# end the session by accident.
func _confirm_return_to_castle() -> void:
	var destination := "exit the game" if OS.has_feature("crown_story") else "return to the Castle"
	_open_confirm("%s? Your earned treasures are saved; the current chapter's progress toward its next placement is not." % destination.capitalize(), _return_to_castle)


func _return_to_castle() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if OS.has_feature("crown_story"):
		get_tree().quit()
	else:
		SceneLoader.change_scene_with_loading(get_tree(), HUB_SCENE_PATH)


func _return_label() -> String:
	return "Exit Game" if OS.has_feature("crown_story") else "Return to Castle"


# --- objective / progress HUD ----------------------------------------------

func _update_progress_hud() -> void:
	var js := get_node_or_null("/root/JourneyState")
	var done := 0
	if js != null:
		for chapter in CHAPTERS:
			if js.has_story_chapter(chapter["id"]):
				done += 1
	if _progress_text != null:
		if done >= CHAPTERS.size():
			_progress_text.text = "Crown of Life: complete"
		else:
			_progress_text.text = "Treasures: %d / %d" % [done, CHAPTERS.size()]
	_update_objective_hud(mini(done, CHAPTERS.size() - 1))


# Contextual tutorial: names the next concrete action rather than restating
# the whole scene's controls, so a player who alt-tabs away and comes back
# always knows the one thing to do next.
func _update_objective_hud(next_index: int) -> void:
	if _objective_text == null:
		return
	var js := get_node_or_null("/root/JourneyState")
	if js != null and js.story_chapters_complete() and js.has_all_treasures():
		_objective_text.text = "Objective: enjoy the Crown of Life finale"
		return
	if js != null and js.story_chapters_complete():
		_objective_text.text = "Lens path complete: return to the Castle for the three kingdom journey"
		return
	if next_index < 0 or next_index >= CHAPTERS.size():
		_objective_text.text = ""
		return
	var chapter: Dictionary = CHAPTERS[next_index]
	if bool(_interaction_complete[next_index]):
		_objective_text.text = "Objective: press Q, frame the glowing seeing, then place it in the gap"
		return
	match str(chapter["id"]):
		"mind_spark":
			_objective_text.text = "Mind Spark: approach the thought and press E to choose hope"
		"heart_melody":
			_objective_text.text = "Heart Melody: press E for each feeling (%d/%d heard)" % [_heart_emotions_heard, HEART_EMOTIONS.size()]
		"creators_light":
			_objective_text.text = "Creator's Light: approach and press 1, 2, or 3 to choose your symbol"


# --- fall recovery -----------------------------------------------------

func _respawn_at_checkpoint() -> void:
	_respawns += 1
	_velocity = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	_player.global_position = _checkpoint + Vector3(0.0, 1.0, 0.0)
	_show_guardian_line("Milo: Safe again! Carry your seeing across the gap using the Lens — you cannot fall out of the story.")


# --- treasure transitions ---------------------------------------------------

# A short, skippable-by-nature flourish (it does not block input) rather than
# a cutscene: the bridge's own light pulses and grows brighter as the gate
# dissolves, so the moment a chasm becomes safe to cross is legible even with
# reduce-motion on, where the pulse becomes a single instant brightness change.
func _play_treasure_transition(index: int, chapter: Dictionary) -> void:
	var bridge := _bridges[index]
	var mesh := bridge.get_child(0) as MeshInstance3D
	if mesh == null or mesh.material_override == null:
		return
	var material := mesh.material_override as StandardMaterial3D
	if _reduce_motion:
		material.emission_energy_multiplier = 1.4
		return
	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(material, "emission_energy_multiplier", 2.2, 0.25)
	tween.tween_property(material, "emission_energy_multiplier", 0.6, 0.25)


# --- audio ---------------------------------------------------------------

func _build_audio() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "StoryMusic"
	_music_player.stream = load(AMBIENT_MUSIC)
	_music_player.volume_db = _volume_to_db(_music_volume if not _music_muted else 0.0)
	add_child(_music_player)
	_music_player.play()

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "StorySfx"
	_sfx_player.volume_db = _volume_to_db(_sfx_volume if not _sfx_muted else 0.0)
	add_child(_sfx_player)


func _volume_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return linear_to_db(linear)


func _play_sfx(path: String) -> void:
	if path.is_empty() or _sfx_player == null:
		return
	var stream := load(path)
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.volume_db = _volume_to_db(_sfx_volume if not _sfx_muted else 0.0)
	_sfx_player.play()


func _apply_audio_settings() -> void:
	if _music_player != null:
		_music_player.volume_db = _volume_to_db(_music_volume if not _music_muted else 0.0)
	if _sfx_player != null:
		_sfx_player.volume_db = _volume_to_db(_sfx_volume if not _sfx_muted else 0.0)


# --- settings persistence (independent of JourneyState: presentation, not
# story evidence) -----------------------------------------------------------

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	_music_volume = clampf(float(config.get_value("audio", "music_volume", _music_volume)), 0.0, 1.0)
	_sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", _sfx_volume)), 0.0, 1.0)
	_music_muted = bool(config.get_value("audio", "music_muted", _music_muted))
	_sfx_muted = bool(config.get_value("audio", "sfx_muted", _sfx_muted))
	_subtitles_on = bool(config.get_value("accessibility", "subtitles", _subtitles_on))
	_large_text = bool(config.get_value("accessibility", "large_text", _large_text))
	_reduce_motion = bool(config.get_value("accessibility", "reduce_motion", _reduce_motion))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", _music_volume)
	config.set_value("audio", "sfx_volume", _sfx_volume)
	config.set_value("audio", "music_muted", _music_muted)
	config.set_value("audio", "sfx_muted", _sfx_muted)
	config.set_value("accessibility", "subtitles", _subtitles_on)
	config.set_value("accessibility", "large_text", _large_text)
	config.set_value("accessibility", "reduce_motion", _reduce_motion)
	config.save(settings_path)


const _BASE_FONT_SIZES := {
	"guardian": 19,
	"objective": 17,
	"progress": 16,
	"controls": 14,
}


func _apply_text_scale() -> void:
	var scale := 1.25 if _large_text else 1.0
	var labels := {
		"guardian": _guardian_text,
		"objective": _objective_text,
		"progress": _progress_text,
		"controls": _controls_text,
	}
	for key in labels:
		var label: Label = labels[key]
		if label == null:
			continue
		var base_size: int = _BASE_FONT_SIZES[key]
		label.add_theme_font_size_override("font_size", int(round(base_size * scale)))


# --- pause menu --------------------------------------------------------

func _is_paused() -> bool:
	return _pause_layer != null and _pause_layer.visible


func _is_any_panel_open() -> bool:
	return _is_paused() \
		or (_settings_panel != null and _settings_panel.visible) \
		or (_confirm_panel != null and _confirm_panel.visible)


func _toggle_pause() -> void:
	if _is_any_panel_open():
		_close_all_panels()
		return
	_pause_layer.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_all_panels() -> void:
	if _pause_layer != null:
		_pause_layer.visible = false
	if _settings_panel != null:
		_settings_panel.visible = false
	if _confirm_panel != null:
		_confirm_panel.visible = false
	# The finale keeps the mouse free for its Replay/Credits/Return buttons;
	# otherwise resuming from pause recaptures the mouse for movement/look.
	if not _finale_built:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_pause_menu() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.name = "PauseLayer"
	_pause_layer.layer = 20
	_pause_layer.visible = false
	add_child(_pause_layer)

	var dim := ColorRect.new()
	# Darker than before so the large world prop behind the panel stops
	# competing with the pause text (audit item G).
	dim.color = Color(0.015, 0.015, 0.04, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.add_child(dim)

	var panel_backing := ColorRect.new()
	panel_backing.color = Color(0.08, 0.07, 0.14, 0.9)
	panel_backing.set_anchors_preset(Control.PRESET_CENTER)
	panel_backing.custom_minimum_size = Vector2(400, 360)
	panel_backing.position = Vector2(-200, -190)
	panel_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_layer.add_child(panel_backing)

	var box := VBoxContainer.new()
	box.name = "PauseBox"
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(360, 0)
	box.position = Vector2(-180, -170)
	box.add_theme_constant_override("separation", 12)
	_pause_layer.add_child(box)

	var heading := Label.new()
	heading.text = "Paused"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72))
	box.add_child(heading)

	var resume := Button.new()
	resume.name = "ResumeButton"
	resume.text = "Resume"
	resume.custom_minimum_size = Vector2(0, 44)
	resume.pressed.connect(_close_all_panels)
	box.add_child(resume)

	var restart_chapter := Button.new()
	restart_chapter.name = "RestartChapterButton"
	restart_chapter.text = "Restart Current Chapter"
	restart_chapter.custom_minimum_size = Vector2(0, 44)
	restart_chapter.pressed.connect(func():
		_open_confirm("Restart the current chapter? You will return to its start; already-earned treasures stay earned.", _restart_current_chapter))
	box.add_child(restart_chapter)

	var restart_journey := Button.new()
	restart_journey.name = "RestartJourneyButton"
	restart_journey.text = "Restart Whole Journey"
	restart_journey.custom_minimum_size = Vector2(0, 44)
	restart_journey.pressed.connect(func():
		_open_confirm("Restart the whole journey? This clears all three earned treasures.", _replay_journey))
	box.add_child(restart_journey)

	var settings_button := Button.new()
	settings_button.name = "SettingsButton"
	settings_button.text = "Audio & Accessibility"
	settings_button.custom_minimum_size = Vector2(0, 44)
	settings_button.pressed.connect(_open_settings)
	box.add_child(settings_button)

	var return_button := Button.new()
	return_button.name = "ReturnButton"
	return_button.text = "Return to Castle"
	return_button.custom_minimum_size = Vector2(0, 44)
	return_button.pressed.connect(_confirm_return_to_castle)
	box.add_child(return_button)

	_build_settings_panel()
	_build_confirm_panel()


# Respawns at the start of the chapter currently in progress (the last
# checkpoint), not a full journey reset — matches the "restart chapter" half
# of the completion standard distinctly from "restart journey".
func _restart_current_chapter() -> void:
	var lens := find_child("ViewfinderLens", true, false)
	if lens != null:
		lens.restore_world()
	var index := _current_chapter_index()
	if index >= 0:
		_interaction_complete[index] = false
		_source_bodies[index].collision_layer = 0
		_source_labels[index].text = str(CHAPTERS[index]["before"])
		if index == 1:
			_heart_emotions_heard = 0
		elif index == 2:
			_creative_choice = -1
		_update_objective_hud(index)
	_player.global_position = _checkpoint + Vector3(0.0, 1.0, 0.0)
	_velocity = Vector3.ZERO
	_close_all_panels()


func _open_settings() -> void:
	_pause_layer.visible = false
	_settings_panel.visible = true
	_refresh_settings_panel()


func _build_settings_panel() -> void:
	_settings_panel = CanvasLayer.new()
	_settings_panel.name = "SettingsLayer"
	_settings_panel.layer = 21
	_settings_panel.visible = false
	add_child(_settings_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_panel.add_child(dim)

	var box := VBoxContainer.new()
	box.name = "SettingsBox"
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(460, 0)
	box.position = Vector2(-230, -230)
	box.add_theme_constant_override("separation", 10)
	_settings_panel.add_child(box)

	# A dedicated panel surface gives the controls a stable reading field while
	# preserving SettingsBox as child 1 for the existing test/refresh contract.
	var panel_backing := ColorRect.new()
	panel_backing.color = Color(0.07, 0.075, 0.13, 0.96)
	panel_backing.set_anchors_preset(Control.PRESET_CENTER)
	panel_backing.custom_minimum_size = Vector2(520, 520)
	panel_backing.position = Vector2(-260, -255)
	panel_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_backing.z_index = -1
	_settings_panel.add_child(panel_backing)

	var heading := Label.new()
	heading.text = "Audio & Accessibility"
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72))
	box.add_child(heading)

	box.add_child(_settings_row_label("Music volume"))
	var music_slider := HSlider.new()
	music_slider.name = "MusicSlider"
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = _music_volume
	music_slider.value_changed.connect(func(v):
		_music_volume = v
		_apply_audio_settings()
		_save_settings())
	box.add_child(music_slider)

	var music_mute := CheckButton.new()
	music_mute.name = "MusicMuteCheck"
	music_mute.text = "Mute music"
	music_mute.button_pressed = _music_muted
	music_mute.toggled.connect(func(pressed):
		_music_muted = pressed
		_apply_audio_settings()
		_save_settings())
	box.add_child(music_mute)

	box.add_child(_settings_row_label("Sound effects volume"))
	var sfx_slider := HSlider.new()
	sfx_slider.name = "SfxSlider"
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = _sfx_volume
	sfx_slider.value_changed.connect(func(v):
		_sfx_volume = v
		_apply_audio_settings()
		_save_settings())
	box.add_child(sfx_slider)

	var sfx_mute := CheckButton.new()
	sfx_mute.name = "SfxMuteCheck"
	sfx_mute.text = "Mute sound effects"
	sfx_mute.button_pressed = _sfx_muted
	sfx_mute.toggled.connect(func(pressed):
		_sfx_muted = pressed
		_apply_audio_settings()
		_save_settings())
	box.add_child(sfx_mute)

	var subtitles_check := CheckButton.new()
	subtitles_check.name = "SubtitlesCheck"
	subtitles_check.text = "Subtitles / captions"
	subtitles_check.button_pressed = _subtitles_on
	subtitles_check.toggled.connect(func(pressed):
		_subtitles_on = pressed
		_show_guardian_line(_last_guardian_line)
		_save_settings())
	box.add_child(subtitles_check)

	var text_size_check := CheckButton.new()
	text_size_check.name = "LargeTextCheck"
	text_size_check.text = "Large text"
	text_size_check.button_pressed = _large_text
	text_size_check.toggled.connect(func(pressed):
		_large_text = pressed
		_apply_text_scale()
		_save_settings())
	box.add_child(text_size_check)

	var reduce_motion_check := CheckButton.new()
	reduce_motion_check.name = "ReduceMotionCheck"
	reduce_motion_check.text = "Reduce motion"
	reduce_motion_check.button_pressed = _reduce_motion
	reduce_motion_check.toggled.connect(func(pressed):
		_reduce_motion = pressed
		_save_settings())
	box.add_child(reduce_motion_check)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 42)
	back.pressed.connect(func():
		_settings_panel.visible = false
		_pause_layer.visible = true)
	box.add_child(back)


func _refresh_settings_panel() -> void:
	var box := _settings_panel.get_child(1) as VBoxContainer
	(box.get_node("MusicSlider") as HSlider).value = _music_volume
	(box.get_node("MusicMuteCheck") as CheckButton).button_pressed = _music_muted
	(box.get_node("SfxSlider") as HSlider).value = _sfx_volume
	(box.get_node("SfxMuteCheck") as CheckButton).button_pressed = _sfx_muted
	(box.get_node("SubtitlesCheck") as CheckButton).button_pressed = _subtitles_on
	(box.get_node("LargeTextCheck") as CheckButton).button_pressed = _large_text
	(box.get_node("ReduceMotionCheck") as CheckButton).button_pressed = _reduce_motion


func _settings_row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	return label


# --- confirmation dialog -----------------------------------------------

# One shared yes/no confirmation for every progress-affecting action
# (restart chapter, restart journey, return to castle) rather than a native
# popup, so it matches this scene's own visual language and stays keyboard/
# mouse operable without an OS dialog.
func _build_confirm_panel() -> void:
	_confirm_panel = CanvasLayer.new()
	_confirm_panel.name = "ConfirmLayer"
	_confirm_panel.layer = 22
	_confirm_panel.visible = false
	add_child(_confirm_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_panel.add_child(dim)

	var box := VBoxContainer.new()
	box.name = "ConfirmBox"
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(420, 0)
	box.position = Vector2(-210, -100)
	box.add_theme_constant_override("separation", 12)
	_confirm_panel.add_child(box)

	var label := Label.new()
	label.name = "ConfirmLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(400, 0)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	box.add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var yes := Button.new()
	yes.name = "ConfirmYes"
	yes.text = "Yes"
	yes.custom_minimum_size = Vector2(120, 42)
	yes.pressed.connect(_confirm_yes)
	row.add_child(yes)

	var no := Button.new()
	no.name = "ConfirmNo"
	no.text = "No"
	no.custom_minimum_size = Vector2(120, 42)
	no.pressed.connect(_confirm_no)
	row.add_child(no)


func _open_confirm(message: String, on_confirm: Callable) -> void:
	_confirm_action = on_confirm
	(_confirm_panel.get_child(1).get_node("ConfirmLabel") as Label).text = message
	_confirm_reopens_pause = _pause_layer.visible
	_pause_layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_confirm_panel.visible = true


func _confirm_yes() -> void:
	var action := _confirm_action
	_confirm_action = Callable()
	_confirm_panel.visible = false
	if action.is_valid():
		action.call()


func _confirm_no() -> void:
	_confirm_action = Callable()
	_confirm_panel.visible = false
	_pause_layer.visible = _confirm_reopens_pause
	if not _confirm_reopens_pause and (_finale_layer == null or not _finale_built):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
