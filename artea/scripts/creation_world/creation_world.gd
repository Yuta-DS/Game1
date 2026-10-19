extends Node3D

const SceneLoader := preload("res://scripts/scene_loader.gd")

const PlayerScript := preload("res://scripts/creation_world/creation_world_player.gd")
const LensControllerScript := preload("res://scripts/viewfinder/lens_controller.gd")
const SketchCanvasScript := preload("res://scripts/creation_world/world_sketch_canvas.gd")
const SemanticObjectFactory := preload("res://scripts/creation_world/semantic_object_factory.gd")
const RealtimeWorldGenerator := preload("res://scripts/creation_world/realtime_world_generator.gd")
const TerrainBuilder := preload("res://scripts/creation_world/world_terrain_builder.gd")
const AmbientLifeLoop := preload("res://scripts/creation_world/ambient_life_loop.gd")
const ArtworkEnvironmentAnimator := preload("res://scripts/creation_world/artwork_environment_animator.gd")
const HudTheme := preload("res://scripts/ui/artea_hud_theme.gd")
const WORLD_WIDTH := 36.0
const WORLD_DEPTH := 28.0
const PLAYER_HEIGHT := 1.8

# The control hint is fixed and scannable, so it stays separate from the
# status line rather than growing into one long sentence at the bottom.
const CONTROL_HINT := "WASD move · Shift run · Space jump · E interact · Q lens · X exit"

var _player: CharacterBody3D
var _camera: Camera3D
var _world_root: Node3D
var _actors: Dictionary = {}
var _actor_specs: Dictionary = {}
var _time := 0.0
var _status: Label
var _status_panel: PanelContainer
var _idea_panel: PanelContainer
var _idea_input: LineEdit
var _sketch_panel: PanelContainer
var _sketch_canvas: TextureRect
var _manifest: Dictionary = {}
var _palette: Array[Color] = []
var _source_artwork_image: Image
var _interaction_prompt: Label
var _interaction_target: Node3D
var _interaction_scan_timer := 0.0
var _generator: Node
var _terrain: RefCounted
var _ambient_loop: Node
var _ambient_root: Node3D
var _environment_animator: Node3D
var _sky_material: ProceduralSkyMaterial
var _artwork_sun: DirectionalLight3D


func _ready() -> void:
	_ensure_artwork_selected()
	_manifest = CreationWorldState.current_manifest()
	if not CreationWorldState.current_world_is_explorable():
		_show_reconstruction_blocked()
		return
	_build_environment()
	_build_player()
	_build_hud()
	_build_runtime_generator()
	_apply_manifest(_manifest)
	_restore_world_drawings()
	_start_ambient_life()
	if not CreationWorldState.world_ready.is_connected(_on_richer_world_ready):
		CreationWorldState.world_ready.connect(_on_richer_world_ready)
	# The background vision request may have completed during scene construction.
	# Reconcile its latest subjects immediately instead of waiting for re-entry.
	var latest_manifest := CreationWorldState.current_manifest()
	if latest_manifest != _manifest and CreationWorldState.current_world_is_explorable():
		_apply_manifest(latest_manifest)


func _on_richer_world_ready(manifest: Dictionary, _degraded: bool) -> void:
	if manifest.is_empty() or not CreationWorldState.current_world_is_semantic():
		return
	_apply_manifest(manifest)
	_set_status("Vision found the subjects in your artwork. The world now matches your drawing more closely.")


func _show_reconstruction_blocked() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := ColorRect.new()
	background.color = Color("241d36")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	layer.add_child(background)
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-330, -120)
	panel.size = Vector2(660, 240)
	panel.add_theme_constant_override("separation", 22)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "This artwork is still becoming a real 3D world"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	panel.add_child(title)
	var message := Label.new()
	message.text = "This artwork has not been prepared yet. Return to the gallery and enter the artwork again to build its interactive world."
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 18)
	panel.add_child(message)
	var button := Button.new()
	button.text = "Return to Gallery"
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(_return_to_gallery)
	panel.add_child(button)


func _process(delta: float) -> void:
	_time += delta
	_animate_world()
	_interaction_scan_timer -= delta
	if _interaction_scan_timer <= 0.0:
		_interaction_scan_timer = 0.10
		_refresh_interaction_target()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_activate_interaction()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M:
			_toggle_idea_panel(true)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_D:
			_toggle_sketch_panel(true)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_X:
			_return_to_gallery()
			get_viewport().set_input_as_handled()


func _ensure_artwork_selected() -> void:
	if CreationWorldState.has_current_artwork():
		return
	var directory := DirAccess.open("user://artworks/")
	if directory == null:
		return
	var newest_path := ""
	var newest_time := 0
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.to_lower().ends_with(".png"):
			var path := "user://artworks/" + file_name
			var modified := FileAccess.get_modified_time(path)
			if modified > newest_time:
				newest_time = modified
				newest_path = path
		file_name = directory.get_next()
	directory.list_dir_end()
	if not newest_path.is_empty():
		CreationWorldState.prepare_artwork(newest_path)


func _build_environment() -> void:
	_world_root = Node3D.new()
	_world_root.name = "LivingArtwork"
	add_child(_world_root)
	_palette = _read_palette(_manifest.get("palette", []))
	if _palette.is_empty():
		_palette = [Color("86c5da"), Color("ffd166"), Color("8ac926"), Color("ff99c8")]

	_build_art_backdrop()
	_build_atmosphere()
	_build_living_background_environment()

	# The terrain is sculpted from the artwork itself, so the ground the player
	# walks on belongs to their painting instead of being a flat neutral slab.
	_terrain = TerrainBuilder.new(WORLD_WIDTH + 8.0, WORLD_DEPTH + 10.0, 72)
	_terrain.sculpt(_source_artwork_image, _palette)
	_world_root.add_child(_terrain.build_ground(_palette, _source_artwork_image))
	_world_root.add_child(_terrain.build_water(_palette))
	_build_ambient_life()


func _build_atmosphere() -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "ArtworkAtmosphere"
	var environment := Environment.new()
	var sky_low := _palette[0].lerp(Color.WHITE, 0.28)
	var sky_high := _palette[min(1, _palette.size() - 1)].lerp(Color.WHITE, 0.12)
	# A real gradient sky reads as open air; the previous flat clear colour was
	# the single strongest "unfinished prototype" cue in the scene.
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = sky_high
	_sky_material.sky_horizon_color = sky_low
	_sky_material.ground_horizon_color = sky_low.darkened(0.15)
	_sky_material.ground_bottom_color = _palette[min(2, _palette.size() - 1)].darkened(0.35)
	_sky_material.sun_angle_max = 24.0
	var sky := Sky.new()
	sky.sky_material = _sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 1.6
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.12
	# SSAO only exists on Forward+/Compatibility; enabling it on Mobile logs a
	# renderer warning every time an artwork world opens.
	if str(ProjectSettings.get_setting(
			"rendering/renderer/rendering_method", "forward_plus")) != "mobile":
		environment.ssao_enabled = true
		environment.ssao_radius = 1.4
		environment.ssao_intensity = 1.1
	# Depth cue only. The world is ~40 m across, so anything denser than this
	# drowns the artwork's own colours in a flat haze.
	environment.fog_enabled = true
	environment.fog_light_color = sky_low
	environment.fog_density = 0.0016
	environment.fog_sky_affect = 0.0
	environment.fog_aerial_perspective = 0.25
	environment_node.environment = environment
	add_child(environment_node)

	_artwork_sun = DirectionalLight3D.new()
	_artwork_sun.name = "ArtworkSun"
	_artwork_sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	_artwork_sun.light_color = Color("fff0c2")
	_artwork_sun.light_energy = 1.15
	_artwork_sun.shadow_enabled = true
	_artwork_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_artwork_sun.directional_shadow_max_distance = 90.0
	_artwork_sun.shadow_bias = 0.035
	add_child(_artwork_sun)

	# A cool bounce light from the opposite side keeps shadowed faces readable
	# without washing out the palette the child chose.
	var fill := DirectionalLight3D.new()
	fill.name = "ArtworkFill"
	fill.rotation_degrees = Vector3(-24.0, 148.0, 0.0)
	fill.light_color = sky_high
	fill.light_energy = 0.38
	fill.shadow_enabled = false
	add_child(fill)


func _build_living_background_environment() -> void:
	_environment_animator = ArtworkEnvironmentAnimator.new()
	_environment_animator.name = "ArtworkEnvironmentAnimator"
	_world_root.add_child(_environment_animator)
	_environment_animator.call("configure", _source_artwork_image, _manifest, _palette,
		_sky_material, _artwork_sun)


func _build_ambient_life() -> void:
	_ambient_root = Node3D.new()
	_ambient_root.name = "AmbientLife"
	_world_root.add_child(_ambient_root)
	_ambient_loop = AmbientLifeLoop.new()
	_ambient_loop.name = "AmbientLifeLoop"
	add_child(_ambient_loop)


func _start_ambient_life() -> void:
	if _ambient_loop == null or _player == null:
		return
	var bounds := Rect2(
		-WORLD_WIDTH * 0.5 - 4.0, -WORLD_DEPTH * 0.5 - 5.0,
		WORLD_WIDTH + 8.0, WORLD_DEPTH + 10.0)
	_ambient_loop.world_seed = abs(CreationWorldState.current_title.hash()) + 1
	_ambient_loop.configure(_player, _ambient_root, _terrain, _palette, bounds)
	_refresh_ambient_reservations()
	# One eager pass so the player never spawns into a bare field while the
	# per-frame budget catches up.
	_ambient_loop.force_tick()


# Authored manifest actors claim space so the streaming scatter never grows up
# through the middle of something the player actually painted.
func _refresh_ambient_reservations() -> void:
	if _ambient_loop == null:
		return
	var areas: Array[Dictionary] = []
	for id in _actors:
		var actor: Node3D = _actors[id]
		if not is_instance_valid(actor):
			continue
		var radius := float(actor.get_meta("placement_radius", 0.0))
		if radius <= 0.0:
			continue
		areas.append({
			"centre": Vector2(actor.position.x, actor.position.z),
			"radius": radius + 0.6,
		})
	_ambient_loop.set_reserved_areas(areas)


func ambient_instance_count() -> int:
	return 0 if _ambient_loop == null else int(_ambient_loop.live_instance_count())


func terrain_height_at(world_x: float, world_z: float) -> float:
	return 0.0 if _terrain == null else float(_terrain.height_at(world_x, world_z))


func _build_art_backdrop() -> void:
	_source_artwork_image = _load_artwork_image()
	# Intentionally no giant flat copy of the painting here. The image is a
	# source texture for individual reconstructed subjects, not a backdrop the
	# player merely walks in front of.


func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.name = "CreationWorldPlayer"
	_player.set_script(PlayerScript)
	var spawn_z := WORLD_DEPTH * 0.48
	var spawn_y := PLAYER_HEIGHT * 0.55
	if _terrain != null:
		# Stand on the sculpted surface rather than inside it.
		spawn_y = _terrain.height_at(0.0, spawn_z) + PLAYER_HEIGHT * 0.6
	_player.position = Vector3(0, spawn_y, spawn_z)
	_player.collision_layer = 1
	_player.collision_mask = 1 | 8
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	collision.shape = capsule
	_player.add_child(collision)
	var visual := MeshInstance3D.new()
	visual.name = "FallbackPlayerVisual"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.38
	body_mesh.height = 1.5
	visual.mesh = body_mesh
	visual.material_override = _material(_palette[min(3, _palette.size() - 1)], false)
	_player.add_child(visual)
	var fox_path := "res://assets3D/characters/fox.glb"
	if ResourceLoader.exists(fox_path):
		var fox_scene = load(fox_path)
		if fox_scene is PackedScene:
			var fox: Node3D = fox_scene.instantiate()
			fox.name = "ArtistFox"
			fox.scale = Vector3.ONE * 3.0
			fox.position.y = -0.98
			_player.add_child(fox)
			visual.visible = false
			var animation_player := fox.find_child("AnimationPlayer*", true, false) as AnimationPlayer
			if animation_player != null:
				for animation_name in animation_player.get_animation_list():
					if animation_name.to_lower().contains("idle"):
						animation_player.play(animation_name)
						break

	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position.y = 1.25
	_player.add_child(pivot)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.spring_length = 4.5
	arm.collision_mask = 1 | 8
	pivot.add_child(arm)
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.current = true
	_camera.fov = 70.0
	arm.add_child(_camera)
	add_child(_player)

	var lens := LensControllerScript.new()
	lens.name = "ArtworkLens"
	lens.camera = _camera
	lens.persist = false
	lens.show_idle_hint = false
	_player.add_child(lens)


# The creation world's field-journal HUD. Everything is built from HudTheme so
# the plaque, the actions and both modals read as one hand-made family sitting
# over the painting, rather than default controls competing with it.
#
# Layout follows the supervision brief: artwork plaque top-left, creative
# actions top-right, reticle at centre, contextual status centred along the
# bottom. Nothing is parked in the bottom-right corner any more.
func _build_hud() -> void:
	var accent := _hud_accent()

	var layer := CanvasLayer.new()
	layer.name = "CreationHud"
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The HUD must not eat clicks meant for the world; only the panels and
	# buttons below opt back into receiving input.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_build_title_plaque(root, accent)
	_build_action_group(root, accent)
	_build_reticle(root)
	_build_interaction_prompt(root, accent)
	_build_status_plaque(root, accent)

	_build_idea_panel(root)
	_build_sketch_panel(root)


# The artwork's own strongest colour, used for the accent bars and borders.
# Falls back to the lens cyan before a palette has been sampled.
func _hud_accent() -> Color:
	if _palette.is_empty():
		return HudTheme.LENS_CYAN
	return _palette[0].lerp(Color.WHITE, 0.15)


func _build_title_plaque(root: Control, accent: Color) -> void:
	var plaque := PanelContainer.new()
	plaque.name = "ArtworkPlaque"
	plaque.set_anchors_preset(Control.PRESET_TOP_LEFT)
	plaque.offset_left = HudTheme.SAFE_MARGIN
	plaque.offset_top = HudTheme.SAFE_MARGIN
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_theme_stylebox_override("panel", HudTheme.panel_style(accent, 0.78, 16.0))
	root.add_child(plaque)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_child(box)

	var title := Label.new()
	title.name = "WorldTitle"
	title.text = CreationWorldState.current_title
	HudTheme.style_heading(title, 30)
	box.add_child(title)

	box.add_child(HudTheme.accent_bar(accent))

	var subtitle := Label.new()
	subtitle.name = "WorldSubtitle"
	subtitle.text = "a world made from your art"
	HudTheme.style_body(subtitle, 15)
	box.add_child(subtitle)


func _build_action_group(root: Control, accent: Color) -> void:
	var group := PanelContainer.new()
	group.name = "CreativeActions"
	group.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	group.offset_right = -HudTheme.SAFE_MARGIN
	group.offset_top = HudTheme.SAFE_MARGIN
	group.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	group.mouse_filter = Control.MOUSE_FILTER_STOP
	group.add_theme_stylebox_override("panel", HudTheme.panel_style(accent, 0.72, 12.0))
	root.add_child(group)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	group.add_child(box)

	box.add_child(HudTheme.accent_bar(accent))

	var row := HBoxContainer.new()
	row.name = "ActionRow"
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	# Creative actions carry coral; leaving for the gallery is navigation, so
	# it takes the castle blue instead of competing for the same emphasis.
	var actions := [
		["AddIdeaButton", "Add  (M)", HudTheme.CREATOR_CORAL,
			_toggle_idea_panel.bind(true), "Add an idea to your world"],
		["DrawButton", "Draw  (D)", HudTheme.CREATOR_CORAL,
			_toggle_sketch_panel.bind(true), "Draw something new"],
		["ExitArtworkButton", "Exit Artwork  (X)", HudTheme.CASTLE_BLUE,
			_return_to_gallery, "Leave this artwork and return to the gallery"],
	]
	for action in actions:
		var button := Button.new()
		button.name = str(action[0])
		button.text = str(action[1])
		HudTheme.style_action_button(button, action[2])
		button.pressed.connect(action[3])
		button.tooltip_text = str(action[4])
		row.add_child(button)


func _build_reticle(root: Control) -> void:
	var reticle := Label.new()
	reticle.name = "Reticle"
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.offset_left = -10
	reticle.offset_right = 10
	reticle.offset_top = -14
	reticle.offset_bottom = 14
	reticle.text = "•"
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.add_theme_font_size_override("font_size", 22)
	reticle.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	root.add_child(reticle)


# The "press E" style prompt, just under the reticle. It carries gameplay
# meaning, so it gets its own ink-glass backing rather than floating as pale
# text over a bright world. Hidden until something is actually in reach.
func _build_interaction_prompt(root: Control, accent: Color) -> void:
	var holder := PanelContainer.new()
	holder.name = "InteractionPrompt"
	holder.set_anchors_preset(Control.PRESET_CENTER)
	holder.offset_left = -240
	holder.offset_right = 240
	holder.offset_top = 92
	holder.offset_bottom = 92 + HudTheme.MIN_ACTION_HEIGHT
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	holder.add_theme_stylebox_override("panel", HudTheme.panel_style(accent, 0.80, 10.0))
	root.add_child(holder)

	_interaction_prompt = Label.new()
	_interaction_prompt.name = "InteractionPromptLabel"
	_interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interaction_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interaction_prompt.text = ""
	HudTheme.style_body(_interaction_prompt, 17, HudTheme.LENS_CYAN)
	holder.add_child(_interaction_prompt)


# Bottom centre carries two separate things that used to be one long sentence:
# a fixed, scannable control hint, and a status line that only speaks when the
# world has something to say.
func _build_status_plaque(root: Control, accent: Color) -> void:
	var column := VBoxContainer.new()
	column.name = "StatusColumn"
	column.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	column.offset_left = -430
	column.offset_right = 430
	column.offset_bottom = -HudTheme.SAFE_MARGIN
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	_status_panel = PanelContainer.new()
	_status_panel.name = "StatusPlaque"
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.visible = false
	_status_panel.add_theme_stylebox_override("panel",
		HudTheme.panel_style(accent, 0.82, 12.0))
	column.add_child(_status_panel)

	_status = Label.new()
	_status.name = "StatusLabel"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudTheme.style_body(_status, 16, HudTheme.PARCHMENT)
	_status_panel.add_child(_status)

	var controls_plaque := PanelContainer.new()
	controls_plaque.name = "ControlsPlaque"
	controls_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_plaque.add_theme_stylebox_override("panel",
		HudTheme.panel_style(accent, 0.62, 10.0))
	column.add_child(controls_plaque)

	var controls := Label.new()
	controls.name = "ControlsLabel"
	controls.text = CONTROL_HINT
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudTheme.style_body(controls, 15)
	controls_plaque.add_child(controls)


# Status is contextual: it appears with a message and gets out of the way once
# the world is quiet again.
func _set_status(message: String) -> void:
	if _status == null:
		return
	_status.text = message
	if _status_panel != null:
		_status_panel.visible = not message.strip_edges().is_empty()


# The prompt's backing plaque only exists while something is actually in reach,
# so an empty prompt leaves no dark rectangle sitting under the reticle.
func _set_interaction_prompt(message: String) -> void:
	if _interaction_prompt == null:
		return
	_interaction_prompt.text = message
	var holder := _interaction_prompt.get_parent() as Control
	if holder != null:
		holder.visible = not message.strip_edges().is_empty()


func _build_runtime_generator() -> void:
	_generator = RealtimeWorldGenerator.new()
	_generator.name = "RealtimeWorldGenerator"
	add_child(_generator)
	_generator.configure(
		_spawn_manifest_object,
		_update_manifest_object,
		_remove_manifest_object,
		_actor_ids
	)
	_generator.set_priority_origin(func() -> Vector3:
		return _player.global_position if is_instance_valid(_player) else Vector3.ZERO)
	_generator.generation_started.connect(_on_generation_started)
	_generator.generation_progress.connect(_on_generation_progress)
	_generator.generation_finished.connect(_on_generation_finished)
	_generator.generation_failed.connect(_on_generation_failed)


func _build_idea_panel(root: Control) -> void:
	var accent := _hud_accent()
	_idea_panel = PanelContainer.new()
	_idea_panel.name = "IdeaPanel"
	_idea_panel.set_anchors_preset(Control.PRESET_CENTER)
	_idea_panel.offset_left = -340
	_idea_panel.offset_right = 340
	_idea_panel.offset_top = -130
	_idea_panel.offset_bottom = 130
	_idea_panel.visible = false
	_idea_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_idea_panel.add_theme_stylebox_override("panel", HudTheme.panel_style(accent, 0.94, 24.0))
	root.add_child(_idea_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_idea_panel.add_child(box)

	var heading := Label.new()
	heading.name = "IdeaHeading"
	heading.text = "What should we add?"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HudTheme.style_heading(heading, 26)
	box.add_child(heading)

	box.add_child(HudTheme.accent_bar(accent))

	_idea_input = LineEdit.new()
	_idea_input.name = "IdeaInput"
	_idea_input.placeholder_text = "a friendly bird that flies around my castle"
	HudTheme.style_line_edit(_idea_input, accent)
	_idea_input.text_submitted.connect(func(_text: String): _submit_idea())
	box.add_child(_idea_input)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)

	var add := Button.new()
	add.name = "IdeaSubmitButton"
	add.text = "Add to My World"
	HudTheme.style_action_button(add, HudTheme.CREATOR_CORAL)
	add.pressed.connect(_submit_idea)
	buttons.add_child(add)

	var cancel := Button.new()
	cancel.name = "IdeaCancelButton"
	cancel.text = "Not Yet"
	HudTheme.style_action_button(cancel, HudTheme.CASTLE_BLUE)
	cancel.pressed.connect(_toggle_idea_panel.bind(false))
	buttons.add_child(cancel)


func _build_sketch_panel(root: Control) -> void:
	var accent := _hud_accent()
	_sketch_panel = PanelContainer.new()
	_sketch_panel.name = "SketchPanel"
	_sketch_panel.set_anchors_preset(Control.PRESET_CENTER)
	_sketch_panel.offset_left = -390
	_sketch_panel.offset_right = 390
	_sketch_panel.offset_top = -310
	_sketch_panel.offset_bottom = 310
	_sketch_panel.visible = false
	_sketch_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_sketch_panel.add_theme_stylebox_override("panel", HudTheme.panel_style(accent, 0.94, 22.0))
	root.add_child(_sketch_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_sketch_panel.add_child(box)

	var heading := Label.new()
	heading.name = "SketchHeading"
	heading.text = "Draw something new"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HudTheme.style_heading(heading, 26)
	box.add_child(heading)

	var caption := Label.new()
	caption.name = "SketchCaption"
	caption.text = "it will become part of this world"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HudTheme.style_body(caption, 15)
	box.add_child(caption)

	box.add_child(HudTheme.accent_bar(accent))

	_sketch_canvas = SketchCanvasScript.new()
	_sketch_canvas.name = "SketchCanvas"
	_sketch_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_sketch_canvas)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)

	var sketch_actions := [
		["SketchClearButton", "Clear", HudTheme.CASTLE_BLUE, _sketch_canvas.clear_canvas],
		["SketchPlaceButton", "Place Drawing", HudTheme.CREATOR_CORAL, _place_world_drawing],
		["SketchCancelButton", "Cancel", HudTheme.CASTLE_BLUE,
			_toggle_sketch_panel.bind(false)],
	]
	for data in sketch_actions:
		var button := Button.new()
		button.name = str(data[0])
		button.text = str(data[1])
		HudTheme.style_action_button(button, data[2])
		button.pressed.connect(data[3])
		buttons.add_child(button)


func _apply_manifest(manifest: Dictionary) -> void:
	_manifest = manifest
	_palette = _read_palette(manifest.get("palette", []))
	if _palette.is_empty():
		_palette = [Color("86c5da"), Color("ffd166"), Color("8ac926"), Color("ff99c8")]
	if _generator != null:
		_generator.reconcile(manifest)
	if _environment_animator != null:
		_environment_animator.call("update_manifest", manifest)


func _spawn_manifest_object(spec: Dictionary, animation: Dictionary = {}, interaction: Dictionary = {}) -> Node3D:
	var id := str(spec.get("id", "object_%d" % _actors.size()))
	if _actors.has(id) and is_instance_valid(_actors[id]):
		return _actors[id]
	var type_name := str(spec.get("type", "art_shape")).to_lower()
	var colour := _palette[abs(id.hash()) % _palette.size()]
	var body := SemanticObjectFactory.create(spec, _source_artwork_image, colour)
	body.name = id.validate_node_name()
	var reconstructed_kind := str(body.get_meta("artwork_kind", type_name)).to_lower()
	body.scale = Vector3.ONE * _scale_for_spec(spec, reconstructed_kind)
	var desired_position := _position_for_spec(spec, _actors.size())
	body.position = _resolve_actor_position(desired_position, reconstructed_kind,
		_placement_radius_for(reconstructed_kind, body.scale.x), id)
	body.position.y = _ground_height_for(body.position, reconstructed_kind)
	body.set_meta("artwork_id", id)
	body.set_meta("player_relative_scale", body.scale.x)
	body.set_meta("placement_radius", _placement_radius_for(reconstructed_kind, body.scale.x))
	_world_root.add_child(body)
	_actors[id] = body
	_actor_specs[id] = {
		"base": body.transform,
		"action": str(animation.get("action", _default_action(type_name))).to_lower(),
		"speed": clampf(float(animation.get("speed", 0.6)), 0.1, 3.0),
		"phase": float(abs(id.hash()) % 100) / 13.0,
		"interaction": interaction.duplicate(true),
	}
	return body


func _update_manifest_object(spec: Dictionary, animation: Dictionary = {},
		interaction: Dictionary = {}) -> Node3D:
	var id := str(spec.get("id", "")).validate_node_name()
	var actor: Node3D = _actors.get(id)
	if not is_instance_valid(actor):
		return _spawn_manifest_object(spec, animation, interaction)
	var requested_type := str(spec.get("type", "art_shape")).to_lower()
	var existing_type := str(actor.get_meta("artwork_kind", "art_shape")).to_lower()
	# A semantic type change can require a completely different imported model.
	if requested_type != existing_type and not requested_type.contains(existing_type) \
			and not existing_type.contains(requested_type):
		_remove_manifest_object(id)
		return _spawn_manifest_object(spec, animation, interaction)
	var scale_factor := _scale_for_spec(spec, existing_type)
	actor.scale = Vector3.ONE * scale_factor
	var desired := _position_for_spec(spec, _actors.keys().find(id))
	actor.position = _resolve_actor_position(desired, existing_type,
		_placement_radius_for(existing_type, scale_factor), id)
	actor.position.y = _ground_height_for(actor.position, existing_type)
	actor.set_meta("artwork_description", str(spec.get(
		"description", spec.get("label", existing_type.replace("_", " ")))))
	actor.set_meta("placement_radius", _placement_radius_for(existing_type, scale_factor))
	_actor_specs[id] = {
		"base": actor.transform,
		"action": str(animation.get("action", _default_action(existing_type))).to_lower(),
		"speed": clampf(float(animation.get("speed", 0.6)), 0.1, 3.0),
		"phase": float(abs(id.hash()) % 100) / 13.0,
		"interaction": interaction.duplicate(true),
	}
	return actor


func _remove_manifest_object(id: String) -> void:
	var actor: Node3D = _actors.get(id)
	if is_instance_valid(actor):
		actor.queue_free()
	_actors.erase(id)
	_actor_specs.erase(id)
	if _interaction_target == actor:
		_interaction_target = null
		_set_interaction_prompt("")


func _actor_ids() -> Array:
	return _actors.keys()


func world_generation_idle() -> bool:
	return _generator == null or _generator.is_idle()


func _on_generation_started(_revision: int, total: int) -> void:
	if total > 0:
		_set_status("Building your world… 0/%d" % total)


func _on_generation_progress(_revision: int, completed: int, total: int,
		object_id: String) -> void:
	_set_status("Building %s… %d/%d" % [
		object_id.replace("_", " ").capitalize(), completed, total])


func _on_generation_finished(_revision: int, total: int) -> void:
	# Newly settled actors change where ambient scatter is allowed to grow.
	_refresh_ambient_reservations()
	if total > 0:
		# The controls plaque already carries the key hints, so the status line
		# says only what is new and then clears itself.
		_set_status("Your world is ready.")


func _on_generation_failed(_revision: int, object_id: String, message: String) -> void:
	_set_status("%s could not be created: %s" % [object_id, message])


func _position_for_spec(spec: Dictionary, index: int) -> Vector3:
	var normalized = spec.get("normalized_position", spec.get("position", null))
	if normalized == null and (spec.has("bounding_box") or spec.has("bounds")):
		var bounds := SemanticObjectFactory.normalized_bounds(spec)
		normalized = {"x": bounds.get_center().x, "y": bounds.get_center().y}
	if normalized is Dictionary:
		var nx := clampf(float(normalized.get("x", 0.5)), 0.0, 1.0)
		var ny := clampf(float(normalized.get("y", 0.5)), 0.0, 1.0)
		return Vector3(
			lerpf(-WORLD_WIDTH * 0.45, WORLD_WIDTH * 0.45, nx),
			0.0,
			lerpf(-WORLD_DEPTH * 0.48, WORLD_DEPTH * 0.30, ny)
		)
	if normalized is Array and normalized.size() >= 2:
		var nx := clampf(float(normalized[0]), 0.0, 1.0)
		var ny := clampf(float(normalized[1]), 0.0, 1.0)
		return Vector3(
			lerpf(-WORLD_WIDTH * 0.45, WORLD_WIDTH * 0.45, nx),
			0.0,
			lerpf(-WORLD_DEPTH * 0.48, WORLD_DEPTH * 0.30, ny)
		)
	var hint := str(spec.get("position_hint", "")).to_lower()
	if hint == "center" or str(spec.get("type", "")) == "artwork_portal":
		return Vector3(0, 2.5, -9)
	if hint.contains("near the player") and _player != null:
		return _player.global_position + -_player.global_basis.z * 5.0 + Vector3(0, 1.2, 0)
	var angle := float(index) * 2.39996
	var radius := 7.0 + float(index % 4) * 2.2
	return Vector3(cos(angle) * radius, 1.2, sin(angle) * radius - 3.0)


# Sky subjects hover above the tallest hill so a mountain never swallows the
# sun; everything else is planted on the sculpted surface.
func _ground_height_for(position: Vector3, type_name: String) -> float:
	var ground := 0.0 if _terrain == null else float(
		_terrain.height_at(position.x, position.z))
	if type_name in ["bird", "butterfly", "cloud", "sun", "moon", "star", "planet"]:
		var ceiling := 0.0 if _terrain == null else float(_terrain.max_height())
		return maxf(ground + 4.0, ceiling + 3.5)
	if _terrain != null and type_name in ["boat", "fish"]:
		# A boat stranded on a hillside reads as a bug, not as art, so floating
		# subjects always sit on the waterline. `_resolve_actor_position` has
		# already nudged them toward low ground.
		return float(_terrain.water_level())
	return ground


func _scale_for_spec(spec: Dictionary, type_name: String) -> float:
	var hint := str(spec.get("scale_hint", "medium")).to_lower()
	var size_index := 0 if hint.contains("small") else 2 if hint.contains("large") else 1
	# These factors are calibrated against the 1.8 m player capsule and the
	# factory's canonical collisions. They keep a person near player height,
	# make boats genuinely board-sized, and let mountains read beyond buildings.
	var scales := {
		"person": [0.78, 0.95, 1.10],
		"human": [0.78, 0.95, 1.10],
		"character": [0.78, 0.95, 1.10],
		"avatar": [0.78, 0.95, 1.10],
		"boat": [0.78, 1.0, 1.28],
		"tree": [0.82, 1.12, 1.42],
		"house": [0.82, 1.0, 1.24],
		"home": [0.82, 1.0, 1.24],
		"building": [0.85, 1.05, 1.30],
		"pagoda": [0.90, 1.15, 1.45],
		"castle": [1.0, 1.35, 1.75],
		"mountain": [1.35, 2.0, 2.75],
		"rock": [0.7, 1.0, 1.5],
		"flower": [0.7, 1.0, 1.35],
		"cloud": [0.9, 1.3, 1.8],
	}
	if scales.has(type_name):
		return float(scales[type_name][size_index])
	# Surfaces and cropped painted subjects already use their image bounds to
	# determine physical dimensions inside the factory.
	if type_name in ["water", "river", "lake", "road", "path", "bridge", "ground"]:
		return 1.0
	return [0.75, 1.0, 1.3][size_index]


func _placement_radius_for(type_name: String, scale_factor: float) -> float:
	var canonical_radius: float = float({
		"person": 0.8,
		"human": 0.8,
		"character": 0.8,
		"avatar": 0.8,
		"tree": 1.35,
		"boat": 2.7,
		"house": 2.8,
		"home": 2.8,
		"building": 3.0,
		"pagoda": 3.0,
		"castle": 4.2,
		"mountain": 4.5,
		"rock": 1.5,
		"flower": 0.65,
	}.get(type_name, 1.0))
	if type_name in ["water", "river", "lake", "road", "path", "bridge", "ground", "cloud"]:
		return 0.0
	return float(canonical_radius) * scale_factor


func _resolve_actor_position(desired: Vector3, type_name: String, radius: float,
		actor_id: String) -> Vector3:
	if type_name in ["boat", "fish"]:
		desired = _nearest_low_ground(desired)
	if radius <= 0.0:
		return desired
	var candidate := desired
	for attempt in 25:
		if _position_is_clear(candidate, radius, actor_id):
			return candidate
		var ring := 1.2 + floorf(float(attempt) / 6.0) * 1.25
		var angle := float(attempt) * 2.399963
		candidate = desired + Vector3(cos(angle), 0.0, sin(angle)) * ring
		candidate.x = clampf(candidate.x, -WORLD_WIDTH * 0.46, WORLD_WIDTH * 0.46)
		candidate.z = clampf(candidate.z, -WORLD_DEPTH * 0.48, WORLD_DEPTH * 0.33)
	return candidate


# Spiral outward from where the painting put a floating subject and take the
# lowest ground found, so a boat drifts to the nearest basin instead of being
# planted on whatever hill happened to be under its painted coordinates.
func _nearest_low_ground(desired: Vector3) -> Vector3:
	if _terrain == null:
		return desired
	var best := desired
	var best_height: float = _terrain.height_at(desired.x, desired.z)
	for step in 32:
		var angle := float(step) * 2.399963
		var ring := 1.5 + floorf(float(step) / 8.0) * 2.5
		var probe := desired + Vector3(cos(angle), 0.0, sin(angle)) * ring
		probe.x = clampf(probe.x, -WORLD_WIDTH * 0.46, WORLD_WIDTH * 0.46)
		probe.z = clampf(probe.z, -WORLD_DEPTH * 0.48, WORLD_DEPTH * 0.33)
		var height: float = _terrain.height_at(probe.x, probe.z)
		if height < best_height:
			best_height = height
			best = probe
	return best


func _position_is_clear(candidate: Vector3, radius: float, actor_id: String) -> bool:
	for existing_id in _actors:
		if str(existing_id) == actor_id:
			continue
		var existing: Node3D = _actors[existing_id]
		if not is_instance_valid(existing):
			continue
		var existing_radius := float(existing.get_meta("placement_radius", 0.0))
		if existing_radius <= 0.0:
			continue
		var planar_distance := Vector2(candidate.x, candidate.z).distance_to(
			Vector2(existing.position.x, existing.position.z))
		if planar_distance < radius + existing_radius + 0.55:
			return false
	return true


func _default_action(type_name: String) -> String:
	if type_name in ["bird", "butterfly", "cloud"]:
		return "fly"
	if type_name in ["tree", "flower"]:
		return "sway"
	if type_name in ["fish", "boat"]:
		return "glide"
	if type_name == "artwork_portal":
		return "breathe"
	return "float"


func _animate_world() -> void:
	for id in _actor_specs:
		var actor: Node3D = _actors.get(id)
		if not is_instance_valid(actor):
			continue
		var spec: Dictionary = _actor_specs[id]
		var base: Transform3D = spec["base"]
		var speed: float = spec["speed"]
		var phase: float = spec["phase"]
		var wave := sin(_time * speed * 2.0 + phase)
		actor.transform = base
		if bool(actor.get_meta("following_player", false)) and _player != null:
			var orbit_angle := _time * speed + phase
			actor.global_position = _player.global_position + Vector3(
				cos(orbit_angle) * 2.2, 2.0 + wave * 0.45, sin(orbit_angle) * 2.2)
			continue
		match spec["action"]:
			"float", "breathe", "particle_loop":
				actor.position.y += wave * 0.35
			"sway":
				actor.rotation.z += wave * 0.12
			"spin":
				actor.rotation.y += _time * speed
			"fly", "follow_path":
				actor.position += Vector3(cos(_time * speed + phase) * 2.5, wave * 1.2, sin(_time * speed + phase) * 2.5)
			"walk", "glide":
				actor.position.x += wave * 2.0
			"hop":
				actor.position.y += maxf(0.0, wave) * 1.2
			"ripple":
				actor.scale *= 1.0 + wave * 0.06
		if float(actor.get_meta("interaction_boost_until", 0.0)) > _time:
			actor.scale *= 1.0 + (0.14 + wave * 0.08)
			actor.rotation.y += wave * 0.18


func _refresh_interaction_target() -> void:
	var next := _find_interactive_target()
	if next == _interaction_target:
		return
	_set_highlight(_interaction_target, false)
	_interaction_target = next
	_set_highlight(_interaction_target, true)
	if _interaction_target == null:
		_set_interaction_prompt("")
	else:
		_set_interaction_prompt("E — interact with %s" % _target_name(_interaction_target))


func _find_interactive_target() -> Node3D:
	if _camera == null or _player == null or get_world_3d() == null:
		return null
	var from := _camera.global_position
	var to := from + -_camera.global_basis.z * 12.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 8, [_player.get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var collider = hit.get("collider")
	if collider is Node3D and bool(collider.get_meta("artwork_interactive", false)):
		return collider

	# A close-by fallback makes interaction comfortable on controller/touch and
	# for young players who do not aim precisely with the centre reticle.
	var nearest: Node3D = null
	var nearest_distance := 3.6
	for candidate in _actors.values():
		if not candidate is Node3D or not is_instance_valid(candidate):
			continue
		var actor_candidate := candidate as Node3D
		var actor_distance: float = actor_candidate.global_position.distance_to(_player.global_position)
		if actor_distance < nearest_distance:
			nearest = actor_candidate
			nearest_distance = actor_distance
	return nearest


func _activate_interaction() -> void:
	if not is_instance_valid(_interaction_target):
		_set_status("Walk closer to a shape, or point at something from your artwork.")
		return
	var kind := str(_interaction_target.get_meta("artwork_kind", "friendly_shape")).to_lower()
	if kind == "world_drawing":
		_react_art_tile(_interaction_target)
		_set_status("Your drawing rises, glows, and answers your touch.")
		return

	var id := str(_interaction_target.get_meta("artwork_id", ""))
	var spec: Dictionary = _actor_specs.get(id, {})
	var interaction: Dictionary = spec.get("interaction", {})
	var response := str(interaction.get("response", _interaction_target.get_meta(
		"artwork_description", "This part of your artwork comes alive.")))
	_interaction_target.set_meta("interaction_boost_until", _time + 2.4)

	if kind in ["bird", "butterfly", "animal", "friendly_character", "fish"]:
		var follows := not bool(_interaction_target.get_meta("following_player", false))
		_interaction_target.set_meta("following_player", follows)
		response += " It follows you now." if follows else " It returns to its place in the picture."
	elif kind in ["friendly_light", "light", "star", "moon"]:
		_cycle_object_colour(_interaction_target)
		response += " Its colour changes with you."
	elif kind in ["tree", "flower", "plant"]:
		response += " It grows toward the light."
	elif kind in ["river", "water", "boat"]:
		response += " Ripples travel across its surface."
	elif kind == "artwork_portal":
		var guide := CreationWorldState.current_guide()
		response = str(guide.get("scene_description", response))
	_set_status(response)


func _react_art_tile(tile: Node3D) -> void:
	var original_scale := tile.scale
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "scale", original_scale * Vector3(1.0, 1.55, 1.0), 0.24)
	tween.tween_property(tile, "scale", original_scale, 0.42)
	var visual := _find_mesh_visual(tile)
	if visual != null and visual.material_override is StandardMaterial3D:
		var material := visual.material_override as StandardMaterial3D
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 0.9
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if is_instance_valid(material):
				material.emission_enabled = false
		)


func _cycle_object_colour(actor: Node3D) -> void:
	if _palette.is_empty():
		return
	var visual := _find_mesh_visual(actor)
	if visual == null or not visual.material_override is StandardMaterial3D:
		return
	var material := visual.material_override as StandardMaterial3D
	var index := int(actor.get_meta("colour_cycle", 0)) + 1
	actor.set_meta("colour_cycle", index)
	var colour := _palette[index % _palette.size()]
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 1.8


func _set_highlight(target: Node3D, highlighted: bool) -> void:
	if not is_instance_valid(target):
		return
	var visual := _find_mesh_visual(target)
	if visual == null or not visual.material_override is StandardMaterial3D:
		return
	var material := visual.material_override as StandardMaterial3D
	if not target.has_meta("highlight_original_emission"):
		target.set_meta("highlight_original_emission", material.emission_enabled)
		target.set_meta("highlight_original_energy", material.emission_energy_multiplier)
	if highlighted:
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = maxf(material.emission_energy_multiplier, 0.42)
	else:
		material.emission_enabled = bool(target.get_meta("highlight_original_emission", false))
		material.emission_energy_multiplier = float(target.get_meta("highlight_original_energy", 1.0))


func _find_mesh_visual(target: Node3D) -> MeshInstance3D:
	for child in target.get_children():
		if child is MeshInstance3D:
			return child
		if child is Node3D:
			var nested := _find_mesh_visual(child)
			if nested != null:
				return nested
	return null


func _target_name(target: Node3D) -> String:
	var description := str(target.get_meta("artwork_description", "a part of your artwork"))
	if description.length() > 48:
		description = description.left(45) + "…"
	return description.to_lower()


func _submit_idea() -> void:
	var prompt := _idea_input.text.strip_edges()
	if prompt.is_empty():
		return
	_set_status("Adding your idea now…")
	var optimistic := CreationWorldState.add_local_idea(prompt)
	_apply_manifest(optimistic)
	_toggle_idea_panel(false)
	CreationWorldState.request_world(prompt,
		func(_ok: bool, response: Dictionary) -> void:
			var updated = response.get("world_manifest", optimistic)
			if updated is Dictionary:
				_apply_manifest(updated)
			_set_status("Your idea is alive. Your original artwork is still safe."),
		true)
	_idea_input.clear()


func _place_world_drawing() -> void:
	var image: Image = _sketch_canvas.export_image()
	if image == null:
		return
	var directory := "user://artworks/world_additions/"
	DirAccess.make_dir_recursive_absolute(directory)
	var path := "%sworld_drawing_%d.png" % [directory, Time.get_ticks_usec()]
	if image.save_png(path) != OK:
		_set_status("I could not save that drawing yet. Please try once more.")
		return
	var position := _player.global_position + -_player.global_basis.z * 5.0 + Vector3(0, 1.8, 0)
	CreationWorldState.add_world_drawing(path, position)
	_spawn_world_drawing(path, position)
	_toggle_sketch_panel(false)
	_set_status("Your new drawing is now part of this living world.")


func _spawn_world_drawing(path: String, position: Vector3) -> void:
	var image := Image.new()
	if image.load(path) != OK:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 8
	body.position = position
	body.set_meta("artwork_interactive", true)
	body.set_meta("artwork_kind", "world_drawing")
	body.set_meta("artwork_description", "the new drawing you added inside this world")
	var visual := MeshInstance3D.new()
	visual.name = "PaintedSurface"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(4.5, 3.0, 0.18)
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)
	_world_root.add_child(body)


func _restore_world_drawings() -> void:
	for entry in CreationWorldState.world_drawings():
		if not entry is Dictionary:
			continue
		var values = entry.get("position", [])
		if values is Array and values.size() == 3:
			_spawn_world_drawing(str(entry.get("path", "")), Vector3(values[0], values[1], values[2]))


func _toggle_idea_panel(show: bool) -> void:
	_idea_panel.visible = show
	_player.set_ui_open(show)
	if show:
		_idea_input.grab_focus()


func _toggle_sketch_panel(show: bool) -> void:
	_sketch_panel.visible = show
	_player.set_ui_open(show)


func _request_fresh_manifest() -> void:
	_set_status("Opening your artwork into a living world…")
	CreationWorldState.request_world("Turn my artwork into a safe living world I can explore.",
		func(_ok: bool, response: Dictionary) -> void:
			var manifest = response.get("world_manifest", {})
			if manifest is Dictionary:
				_apply_manifest(manifest)
			_set_status("Your artwork is alive.")
	)


func _return_to_gallery() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SceneLoader.change_scene_with_loading(get_tree(), "res://scenes/art_gallery_3d_inprogress.tscn")


func _load_artwork_texture() -> Texture2D:
	var image := _load_artwork_image()
	return ImageTexture.create_from_image(image) if image != null else null


func _load_artwork_image() -> Image:
	var path := CreationWorldState.active_artwork_path()
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return image


func _artwork_material() -> Material:
	var material := StandardMaterial3D.new()
	material.albedo_texture = _load_artwork_texture()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_energy_multiplier = 0.25
	return material


func _material(colour: Color, glowing: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.72
	if glowing:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = 1.7
	return material


func _read_palette(raw) -> Array[Color]:
	var output: Array[Color] = []
	if raw is Array:
		for value in raw.slice(0, 8):
			output.append(Color.from_string(str(value), Color("d7aefb")))
	return output
