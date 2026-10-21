extends Node

const SceneLoader := preload("res://scripts/scene_loader.gd")
const WebDecor := preload("res://scripts/web_decor.gd")
const RatingHeart := preload("res://scripts/rating_heart.gd")
const STAR_ICON := preload("res://assets/UI/icons/star.svg")

@export var painting_title: String = "artwork_1.png"


@export var frame_name : String = ""
var current_target_sprite: Sprite2D
var selected_frame_name: String = ""
var player_near_artwork = false
var current_frame_name := ""
var _world_opening := false

# --- Scene Paths ---
const HUB_WORLD_PATH = "res://scenes/New_Hub_World.tscn"
const ARTEA_GAME_PATH = "res://scenes/artea_game.tscn"
const CREATION_WORLD_PATH = "res://scenes/creation_world.tscn"
const QUEST_JOURNAL_PATH = "res://scenes/crown_quest_journal.tscn"

# --- Rating UI ---
@onready var ratingpanel: Control = $CanvasLayer/RatingPanel
@onready var ratinglabel: Label = $CanvasLayer/RatingPanel/RatingLabel
@onready var likebutton: Button = $CanvasLayer/RatingPanel/HBoxContainer/LikeButton




func _ready() -> void:
	_build_galaxy_transit()
	_face_fountain_on_spawn()
	_report_galaxy_state()
	_build_quest_journal_button()
	likebutton.visible = true
	RatingHeart.apply_to_button(likebutton, false)

	
	print("RatingPanel = ", ratingpanel)
	print("RatingLabel = ", ratinglabel)
	print("likebutton = ", likebutton)
	
	
			
	likebutton.pressed.connect(func(): _on_rate_button_pressed(1))
	

	if ratingpanel:
		ratingpanel.visible = false


# The complete train-and-island kingdom belongs inside this cosmic Art Castle
# scene. The Crown Line follows the story in one open world: Gallery Station,
# Mind Spark, Heart Melody, then Creator's Light.
const FLOATING_WORLD_FRONT_OFFSET := Vector3(0.0, 0.0, -480.0)


func _report_galaxy_state() -> void:
	# Report unconditionally and as early as possible. If the gallery appears
	# empty and this text is absent, the scene itself is not being reached and
	# the fault is upstream of anything in this file.
	# The galaxy world builds correctly in headless runs on the same renderer the
	# web uses, so any remaining failure is specific to the browser. Print what
	# actually exists at runtime so the console says which stage broke instead of
	# leaving it to be guessed at.
	await get_tree().process_frame
	await get_tree().process_frame
	var world := find_child("ArtCastleFloatingWorld", true, false)
	var meshes := 0
	if world != null:
		var stack: Array = [world]
		while stack.size() > 0:
			var n: Node = stack.pop_back()
			if n is VisualInstance3D and (n as Node3D).is_visible_in_tree():
				meshes += 1
			for c in n.get_children():
				stack.append(c)
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	var report := "world=%s meshes=%d cam=%s" % [
		str(world != null), meshes,
		str(cam.global_position) if cam != null else "none"]
	print("[ARTEA] galaxy ", report)



# The scene's authored camera looks back into the gallery. Turn the fox and
# the view toward the arrival island's fountain instead, so every visit starts
# looking out at the world.
func _face_fountain_on_spawn() -> void:
	var player := get_node_or_null("Player3D") as Node3D
	var fountain := find_child("LatonaFountain", true, false) as Node3D
	if player == null or fountain == null:
		return
	var to_fountain := fountain.global_position - player.global_position
	to_fountain.y = 0.0
	var visuals := player.get_node_or_null("FoxVisuals") as Node3D
	if visuals != null:
		visuals.rotation.y = atan2(to_fountain.x, to_fountain.z) - player.global_rotation.y
	var camera := get_node_or_null("Camera3D")
	if camera != null and camera.has_method("face_direction"):
		camera.face_direction(to_fountain)


func _build_galaxy_transit() -> void:
	# The 2 km island is part of this same scene—there is no portal or scene
	# change. Its arrival island is centred under the authored gallery floor,
	# so walking north out of the gallery continues directly into the world.
	var floating_world := Node3D.new()
	floating_world.name = "ArtCastleFloatingWorld"
	# ArrivalIsland is authored at local z=820 with radius 155. The gallery wall
	# is global z=10, so this puts the island centre at z=340 and its nearest edge
	# at z=185: a measured 175 m clear gap for the castle approach bridge. This is
	# 75 m farther away than the previous layout while preserving its orientation.
	floating_world.position = FLOATING_WORLD_FRONT_OFFSET
	floating_world.set_script(load("res://scripts/art_castle_floating_world.gd"))
	floating_world.set("embedded_in_gallery", true)
	# A Node3D only renders beneath a 3D parent. This scene's root may be a
	# Node2D (ArtGallery.tscn) or a Node3D (art_gallery_3d.tscn), so when it is
	# 2D the world goes inside a SubViewport that provides the missing 3D world,
	# displayed behind the 2D content rather than not at all.
	# Compared as a plain Node so the static analyser does not reject the test:
	# under `extends Node` it can prove `self is Node3D` is impossible and refuses
	# to parse the script at all.
	var host: Node = self
	if host is Node3D:
		add_child(floating_world)
	else:
		var viewport := SubViewport.new()
		viewport.name = "GalaxyViewport"
		viewport.size = Vector2i(1920, 1080)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.handle_input_locally = false
		var container := SubViewportContainer.new()
		container.name = "GalaxyViewportContainer"
		container.stretch = true
		container.set_anchors_preset(Control.PRESET_FULL_RECT)
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var layer := CanvasLayer.new()
		layer.name = "GalaxyCanvas"
		layer.layer = -10
		add_child(layer)
		layer.add_child(container)
		container.add_child(viewport)
		viewport.add_child(floating_world)

	var kingdom_regions := Node3D.new()
	kingdom_regions.name = "KingdomRegions3000m"
	kingdom_regions.set_script(load("res://scripts/art_castle_kingdom_regions.gd"))
	floating_world.add_child(kingdom_regions)

	var crown_line := Node3D.new()
	crown_line.name = "StoryCrownRailway"
	crown_line.set_script(load("res://scripts/art_castle_story_railway.gd"))
	floating_world.add_child(crown_line)

	var story_director := Node3D.new()
	story_director.name = "ConnectedKingdomStory"
	story_director.set_script(load("res://scripts/art_castle_kingdom_story.gd"))
	floating_world.add_child(story_director)

	var map_canvas := CanvasLayer.new()
	map_canvas.name = "WorldMapCanvas"
	map_canvas.layer = 40
	add_child(map_canvas)
	var minimap := Control.new()
	minimap.name = "ArteaWorldMinimap"
	minimap.set_script(preload("res://scripts/art_castle_minimap.gd"))
	minimap.set("map_context", "galaxy")
	map_canvas.add_child(minimap)
	# On the web, small decoration is drawn unshaded: entering the castle is
	# mostly shader compilation, and these compile at about half the cost.
	# Done before the first frame, so the lit versions are never compiled.
	if OS.has_feature("web"):
		WebDecor.make_decoration_unshaded(floating_world)
		
		
func _input(event):
	if not is_inside_tree() or get_viewport() == null:
		return
	var active_player := get_node_or_null("Player3D")
	if active_player != null and active_player.get_meta("heart_melody_active", false):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		_open_quest_journal()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept") and player_near_artwork and not _world_opening:
		if event is InputEventKey and event.echo:
			return
		_enter_current_frame_world()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return

	if event.is_action_pressed("rate_artwork") and player_near_artwork:

		show_rating_panel(
			current_frame_name,
			$GalleryManager.get_frame_rating(current_frame_name)
		)


func _build_quest_journal_button() -> void:
	var button := Button.new()
	button.name = "CrownJourneyJournalButton"
	button.text = "Crown Journey  [J]"
	button.icon = STAR_ICON
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 22)
	button.tooltip_text = "Open the Crown of Life quest journal"
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.position = Vector2(-250.0, 24.0)
	button.custom_minimum_size = Vector2(220.0, 48.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(_open_quest_journal)
	$CanvasLayer.add_child(button)


func _open_quest_journal() -> void:
	var campaign := get_node_or_null("/root/JourneyCampaign")
	if campaign != null and campaign.has_method("open_quest_journal"):
		if bool(campaign.call("open_quest_journal")):
			return
	if ResourceLoader.exists(QUEST_JOURNAL_PATH):
		SceneLoader.change_scene(get_tree(), QUEST_JOURNAL_PATH)

func show_rating_panel(frame_name: String, current_rating: int) -> void:
	print("Frame:", frame_name)
	print("Current rating:", current_rating)

	selected_frame_name = frame_name
	ratingpanel.visible = true

	var liked := current_rating > 0
	RatingHeart.apply_to_label(ratinglabel, liked, "\nEnter / Space — explore this artwork")
	RatingHeart.apply_to_button(likebutton, liked)
		
func hide_rating_panel() -> void:
	ratingpanel.visible = false
	selected_frame_name = ""

func _on_rate_button_pressed(value: int) -> void:
	if selected_frame_name == "":
		return

	var gallery_manager = $GalleryManager

	if gallery_manager:
		var current_rating = gallery_manager.get_frame_rating(selected_frame_name)

		var liked: bool = current_rating <= 0
		gallery_manager.rate_frame(selected_frame_name, 1 if liked else 0)
		RatingHeart.apply_to_label(ratinglabel, liked)
		RatingHeart.apply_to_button(likebutton, liked)			
func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		go_to_scene(HUB_WORLD_PATH)

func _on_back_to_hubworld_pressed() -> void:
	SceneLoader.change_scene_with_loading(get_tree(), ARTEA_GAME_PATH)

func go_to_scene(path: String) -> void:
	if ResourceLoader.exists(path):
		if path == HUB_WORLD_PATH:
			_request_castle_front_door_spawn()
		print("TRAVELING to: ", path)
		# The hub is the heaviest scene in the project (its ProtonScatter grass
		# alone places tens of thousands of instances), so leaving the gallery
		# goes through the loading screen rather than freezing on a synchronous
		# swap -- the same route used coming the other way.
		SceneLoader.change_scene_with_loading(get_tree(), path)
	else:
		print("ERROR: Target scene file not found at path:", path)


# Exit1's body_entered signal is connected to this gallery root, not to the
# ExitGallery script on the Area3D. Carry the destination explicitly here so
# every real doorway return lands at the castle it just exited.
func _request_castle_front_door_spawn() -> void:
	var global := get_node_or_null("/root/Global")
	if global != null and global.has_method("request_spawn_at"):
		global.request_spawn_at("castle_front_door")


func _on_open_test_button_pressed() -> void:
	print("Test button pressed")


func _on_interaction_area_body_entered(body, frame_name):

	if body.name != "Player3D":
		return

	player_near_artwork = true
	current_frame_name = frame_name

	var rating = $GalleryManager.get_frame_rating(frame_name)

	print("Entered:", frame_name)
	print("Rating returned:", rating)

	show_rating_panel(frame_name, rating)
	

func _on_interaction_area_body_exited(body, frame_name):

	if body.name != "Player3D":
		return

	print("Exited:", frame_name)

	player_near_artwork = false
	current_frame_name = ""

	hide_rating_panel()


func _enter_current_frame_world() -> void:
	if current_frame_name.is_empty() or _world_opening:
		return
	_world_opening = true
	# Space is also Jump. Stop that input before the next physics frame and keep
	# the player still while the artwork world is being prepared.
	var player := get_node_or_null("Player3D")
	if player != null and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)
	var path: String = $GalleryManager.prepare_frame_for_world(current_frame_name)
	if path.is_empty() or not FileAccess.file_exists(path):
		_frame_world_failed("This artwork is not available locally yet. Please try again.")
		return
	var state := get_node_or_null("/root/CreationWorldState")
	if state == null:
		_frame_world_failed("The interactive artwork world is not available in this scene yet.")
		return
	if not ResourceLoader.exists(CREATION_WORLD_PATH):
		_frame_world_failed("The interactive artwork world is still being prepared. Please try again shortly.")
		return

	state.prepare_artwork(path, current_frame_name.replace("_", " "))
	ratinglabel.text = "Building your interactive 3D artwork world…\nYou will be able to walk, jump and interact inside it."
	state.prepare_explorable_world(func(ok: bool, response: Dictionary) -> void:
		if not is_instance_valid(self):
			return
		if not ok:
			_frame_world_failed(str(response.get("error",
				"This artwork world could not open yet. Please try again.")))
			return
		# Leave the current input dispatch before replacing its scene. Otherwise
		# the Space event used at the frame can reach the new world as a jump.
		call_deferred("_open_prepared_frame_world")
	)


func _open_prepared_frame_world() -> void:
	if not SceneLoader.change_scene(get_tree(), CREATION_WORLD_PATH):
		_frame_world_failed("The interactive artwork world could not open yet. Please try again.")


func _frame_world_failed(message: String) -> void:
	_world_opening = false
	ratinglabel.text = message
	var player := get_node_or_null("Player3D")
	if player != null and player.has_method("set_input_enabled"):
		player.set_input_enabled(true)
