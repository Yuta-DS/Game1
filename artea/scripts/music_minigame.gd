extends Control

const SceneLoader := preload("res://scripts/scene_loader.gd")

@onready var result = $HBoxContainer/VBoxContainer/ResultText
@onready var emotion_choices: GridContainer = $HBoxContainer/VBoxContainer/EmotionChoices
@onready var color_rect = $BackgroundVisual
@onready var player = $MusicPlayer
@onready var visualizer = $VisualizerContainer
@onready var return_button = $ReturnButton
@onready var pitch_slider = $HBoxContainer/Options/PitchSlider
@onready var volume_slider = $HBoxContainer/Options/VolumeSlider
@onready var default_pitch_button = $HBoxContainer/Options/ResetPitch
@onready var drums1 = $HBoxContainer/VBoxContainer3/Drums/DrumsColumn1/ButtonDrums1
@onready var drums3 = $HBoxContainer/VBoxContainer3/Drums/DrumsColumn1/ButtonDrums3
@onready var drums2 = $HBoxContainer/VBoxContainer3/Drums/DrumsColumn2/ButtonDrums2
@onready var drums4 = $HBoxContainer/VBoxContainer3/Drums/DrumsColumn2/ButtonDrums4
@onready var drums_slider = $HBoxContainer/VBoxContainer3/DrumsPitch/DrumsSlider
@onready var reset_drums = $HBoxContainer/VBoxContainer3/DrumsPitch/ResetDrums
@onready var stop_drums = $HBoxContainer/VBoxContainer3/DrumsPitch/StopDrums
@onready var drums_player = $DrumsPlayer
@onready var title_label = $HBoxContainer/VBoxContainer/Title
@export var bar_count = 77
@export var bar_width = 20
@export var bar_spacing = 3
@export var min_height = 40
@export var height_multiplier = 2.0
var music_system_activated = false

var bars = []
var bar_speed_offsets = []
var bar_strength_offsets = []
var bar_offsets = []
var visualizer_speed = 5.0
var visualizer_strength = 180.0
var color_tween: Tween

# A deliberate player choice maps to ARTÉA's six story feelings. The legacy
# sound keys retain the existing music and visualizer palette assets; the
# journey record stores the player-facing choice rather than an inferred label.
const EMOTION_CHOICES := [
	{
		"id": "joy", "label": "Joy", "sound_key": "happy",
		"reply": "You chose Joy. Let this melody be as bright or gentle as you choose.",
	},
	{
		"id": "sadness", "label": "Sadness", "sound_key": "sad",
		"reply": "You chose Sadness. You do not have to explain it. You can change the music at any time.",
	},
	{
		"id": "frustration", "label": "Frustration", "sound_key": "angry",
		"reply": "You chose Frustration. You can make this rhythm steady, strong, quiet, or different.",
	},
	{
		"id": "fear", "label": "Fear", "sound_key": "fear",
		"reply": "You chose Fear. You can listen, change the sound, or choose another feeling.",
	},
	{
		"id": "peace", "label": "Peace", "sound_key": "trust",
		"reply": "You chose Peace. You can keep this melody soft, change it, or move on.",
	},
	{
		"id": "hope", "label": "Hope", "sound_key": "anticipation",
		"reply": "You chose Hope. You can let this sound grow, soften, or make room for another choice.",
	},
]

# Index rather than copied thought text: Heart Melody can connect to Mind Spark
# without showing or passing the player's original wording to another system.
var seeded_thought_index := -1
var recorded_choice_ids := {}

# Test-only injection seam. Production resolves the normal autoload; a focused
# test can supply an in-memory record and prove this scene never writes a real
# player's save.
var journey_state_override: Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	player.stream = load("res://assets/audio/minigame/intro.ogg")
	player.play()
	
	create_visualizer_bars()
	
	pitch_slider.min_value = 0.5
	pitch_slider.max_value = 2.0
	pitch_slider.step = 0.01
	pitch_slider.value = 1.0

	pitch_slider.value_changed.connect(_on_pitch_changed)
	
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.value = 0.3

	volume_slider.value_changed.connect(_on_volume_changed)
	_on_volume_changed(volume_slider.value)
	
	player.finished.connect(_on_music_finished)
	
	if not default_pitch_button.pressed.is_connected(_on_default_pitch_pressed):
		default_pitch_button.pressed.connect(_on_default_pitch_pressed)
		
	if not drums1.pressed.is_connected(_on_drums1_pressed):
		drums1.pressed.connect(_on_drums1_pressed)

	if not drums2.pressed.is_connected(_on_drums2_pressed):
		drums2.pressed.connect(_on_drums2_pressed)

	if not drums3.pressed.is_connected(_on_drums3_pressed):
		drums3.pressed.connect(_on_drums3_pressed)

	if not drums4.pressed.is_connected(_on_drums4_pressed):
		drums4.pressed.connect(_on_drums4_pressed)

	if not drums_slider.value_changed.is_connected(_on_drums_slider_changed):
		drums_slider.value_changed.connect(_on_drums_slider_changed)

	if not reset_drums.pressed.is_connected(_on_reset_drums_pressed):
		reset_drums.pressed.connect(_on_reset_drums_pressed)

	if not stop_drums.pressed.is_connected(_on_stop_drums_pressed):
		stop_drums.pressed.connect(_on_stop_drums_pressed)
	
	drums_slider.min_value = 0.25
	drums_slider.max_value = 4.0
	drums_slider.step = 0.01
	drums_slider.value = 1.0

	_seed_from_journey()
	_build_emotion_choices()


# If the player faced a thought in Pop Thoughts, offer the six curated choices
# at Heart Melody. This keeps stage 1 and stage 2 connected without asking
# the player to type or re-read their original wording.
func _seed_from_journey() -> void:
	var js := _journey_state()
	if js == null:
		return

	# The most recent thought the player popped but hasn't yet paired
	# with a feeling.
	for i in range(js.thoughts.size() - 1, -1, -1):
		var t = js.thoughts[i]
		if t.get("popped", false) and t.get("emotion", "") == "":
			seeded_thought_index = i
			break

	if seeded_thought_index < 0:
		return

	if title_label:
		title_label.text = "Milo: You met a thought in Mind Spark.\nChoose a feeling to explore — or skip it."


func _journey_state() -> Node:
	if journey_state_override != null:
		return journey_state_override
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/JourneyState")


func _build_emotion_choices() -> void:
	emotion_choices.columns = 2
	for child in emotion_choices.get_children():
		child.queue_free()

	for choice in EMOTION_CHOICES:
		emotion_choices.add_child(_emotion_button(choice))

	var skip := Button.new()
	skip.text = "Skip for now"
	skip.custom_minimum_size = Vector2(0, 42)
	skip.tooltip_text = "You can keep playing instruments without choosing a feeling."
	skip.pressed.connect(_skip_emotion)
	emotion_choices.add_child(skip)


func _emotion_button(choice: Dictionary) -> Button:
	var button := Button.new()
	button.text = str(choice["label"])
	button.custom_minimum_size = Vector2(0, 42)
	button.tooltip_text = "Choose this feeling for the music. It is not inferred from your words, art, or colours."

	var palette := _palette_for(str(choice["sound_key"]))
	var accent: Color = palette[0] if not palette.is_empty() else Color(0.65, 0.82, 1.0)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent, 0.24)
	normal.border_color = Color(accent, 0.88)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(accent, 0.42)
	hover.border_color = Color.WHITE
	button.add_theme_stylebox_override("hover", hover)
	button.pressed.connect(_choose_emotion.bind(choice))
	return button

func _on_volume_changed(value: float):

	var adjusted = pow(value, 2.0)

	player.volume_db = linear_to_db(adjusted)
	drums_player.volume_db = linear_to_db(adjusted)

func _on_drums1_pressed():
	play_drum_loop("res://assets/audio/minigame/beats/drums_1.ogg")

func _on_drums2_pressed():
	play_drum_loop("res://assets/audio/minigame/beats/drums_2.ogg")

func _on_drums3_pressed():
	play_drum_loop("res://assets/audio/minigame/beats/drums_3.ogg")

func _on_drums4_pressed():
	play_drum_loop("res://assets/audio/minigame/beats/drums_4.ogg")
	
func play_drum_loop(path: String):

	var stream = load(path)

	if stream:

		drums_player.stream = stream

		# force looping
		if stream is AudioStreamOggVorbis:
			stream.loop = true

		drums_player.play()
		drums_player.volume_db = linear_to_db(0.5)

	else:
		print("Missing drum file: ", path)
		
func _on_drums_slider_changed(value: float):

	drums_player.pitch_scale = value
	
func _on_reset_drums_pressed():

	drums_player.pitch_scale = 1.0
	drums_slider.value = 1.0
	
func _on_stop_drums_pressed():

	if drums_player.playing:
		drums_player.stop()
	
func _on_default_pitch_pressed():
	player.pitch_scale = 1.0
	pitch_slider.value = 1.0

func _on_music_finished():
	player.play()
	
func _on_pitch_changed(value: float):
	player.pitch_scale = value

func create_visualizer_bars():

	for i in range(bar_count):

		var bar = Panel.new()

		bar.custom_minimum_size = Vector2(
			bar_width,
			min_height
		)

		bar.position.x = i * (bar_width + bar_spacing)

		# IMPORTANT
		# gives each bar its own material/style
		var style = StyleBoxFlat.new()

		style.bg_color = Color.WHITE

		bar.add_theme_stylebox_override(
			"panel",
			style
		)

		visualizer.add_child(bar)

		bars.append(bar)

		bar_speed_offsets.append(
			randf_range(-1.0, 1.0)
		)

		bar_strength_offsets.append(
			randf_range(-50.0, 50.0)
		)

		bar_offsets.append(
			randf_range(0.0, 10.0)
		)
		
		setup_idle_visualizer()
		
func setup_idle_visualizer():

	for bar in bars:

		# fixed height
		bar.size.y = 600

		# fixed position
		bar.position.y = 300 - bar.size.y

		var style = bar.get_theme_stylebox("panel")

		if style is StyleBoxFlat:

			# predetermined color
			style.bg_color = Color(0.65, 0.82, 1.0)

func _choose_emotion(choice: Dictionary) -> void:
	var emotion_id := str(choice.get("id", ""))
	var sound_key := str(choice.get("sound_key", ""))
	if emotion_id.is_empty() or not EMOTION_PALETTES.has(sound_key):
		return

	music_system_activated = true
	apply_color(sound_key)
	play_music(sound_key)

	var is_new_choice := not recorded_choice_ids.has(emotion_id)
	if is_new_choice:
		recorded_choice_ids[emotion_id] = true
		_record_emotion(emotion_id, sound_key)

	result.text = "Milo: %s" % str(choice.get("reply", "You chose a melody path."))
	if is_new_choice:
		result.text += "\n\nYour melody is remembered. Continue the Heart Melody adventure to restore the garden and its song."
	else:
		result.text += "\n\nYou can keep playing, choose another melody, or return when you are ready."


func _skip_emotion() -> void:
	result.text = "Milo: That is okay. You can play with pitch and drums without naming a feeling. Skipping does not change your journey."


# Save only a deliberate player-selected feeling. The colour carries forward
# into stage 3 from the matching music palette, never from inferred artwork
# or typed text.
func _record_emotion(emotion_id: String, sound_key: String) -> void:
	var js := _journey_state()
	if js == null:
		return

	js.record_emotion(emotion_id, _emotion_colour(sound_key))

	# Pair the selection to the source thought by index. The thought's text is
	# neither displayed here nor supplied to another system.
	var thoughts = js.get("thoughts")
	if seeded_thought_index >= 0 and thoughts is Array and seeded_thought_index < thoughts.size():
		thoughts[seeded_thought_index]["emotion"] = emotion_id
		js.save()
		seeded_thought_index = -1

	js.advance_to(2)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):

	if not music_system_activated:
		return

	var time = Time.get_ticks_msec() / 1000.0

	for i in range(bars.size()):

		var bar = bars[i]

		var speed = (
	12.0
	- visualizer_speed * 1.0
	#+ bar_speed_offsets[i]
)*0.2
		
		var offset = bar_offsets[i]

		var strength_variation = sin(time * 0.7 + offset) * 40.0

		var strength = (
			visualizer_strength
			+ bar_strength_offsets[i]
			+ strength_variation
		)

		var wave = abs(
			sin(time * speed + offset)
		)

		var target_height = 20 + wave * strength * height_multiplier

		bar.size.y = lerp(
			bar.size.y,
			target_height,
			delta * 3.0
		)

		bar.position.y = 300 - bar.size.y

func apply_visualizer_colors(colors: Array, random: bool):

	if colors.is_empty():
		return

	var total_bars = bars.size()
	var color_count = colors.size()

	for i in range(total_bars):

		var bar = bars[i]

		var style = bar.get_theme_stylebox("panel")

		if style is StyleBoxFlat:

			# RANDOM MODE
			if random:

				style.bg_color = colors.pick_random()

			# DISTRIBUTED MODE
			else:

				var section_size = float(total_bars) / color_count

				var color_index = int(i / section_size)

				color_index = clamp(
					color_index,
					0,
					color_count - 1
				)

				style.bg_color = colors[color_index]

func play_music(emotion: String):

	var path = ""

	match emotion:

		"happy":
			path = "res://assets/audio/minigame/happy.ogg"

		"anticipation":
			path = "res://assets/audio/minigame/anticipation.ogg"

		"angry":
			path = "res://assets/audio/minigame/angry.ogg"

		"disgust":
			path = "res://assets/audio/minigame/disgust.ogg"

		"sad":
			path = "res://assets/audio/minigame/sad.ogg"

		"surprise":
			path = "res://assets/audio/minigame/surprise.ogg"

		"fear":
			path = "res://assets/audio/minigame/fear.ogg"

		"trust":
			path = "res://assets/audio/minigame/trust.ogg"

		_:
			path = "res://assets/audio/minigame/intro.ogg"

	var stream = load(path)

	if stream:
		player.stream = stream
		player.play()
	else:
		print("Audio file missing: ", path)

# Palette, visualizer speed, and whether bars are coloured randomly or in
# bands — one entry per emotion. Single source of truth: apply_color()
# renders it and _emotion_colour() reads it for the journey record.
const EMOTION_PALETTES := {
	"happy": {
		"speed": 5.0, "random": true,
		"colors": [
			Color(1.0, 0.9, 0.2),    # bright yellow
			Color(1.0, 0.75, 0.4),   # warm peach
			Color(1.0, 0.85, 0.7),   # pastel peach
			Color(1.0, 0.7, 0.8),    # soft pink
			Color(1.0, 1.0, 0.85),   # creamy light
		],
	},
	"anticipation": {
		"speed": 4.5, "random": false,
		"colors": [
			Color(1.0, 0.55, 0.15),  # orange
			Color(1.0, 0.75, 0.3),   # golden orange
			Color(1.0, 0.85, 0.5),   # soft amber
			Color(1.0, 0.65, 0.55),  # coral
			Color(1.0, 0.9, 0.7),    # pastel orange
		],
	},
	"angry": {
		"speed": 3.0, "random": true,
		"colors": [
			Color(0.9, 0.1, 0.1),    # bright red
			Color(0.5, 0.0, 0.0),    # dark red
			Color(1.0, 0.3, 0.0),    # fiery orange
			Color(0.8, 0.0, 0.2),    # crimson
			Color(0.4, 0.0, 0.1),    # blood red
		],
	},
	"disgust": {
		"speed": 7.0, "random": false,
		"colors": [
			Color(0.7, 0.1, 0.4),    # dark pink
			Color(0.5, 0.0, 0.25),   # wine
			Color(0.9, 0.5, 0.7),    # dusty pink
			Color(0.6, 0.2, 0.45),   # muted magenta
			Color(0.3, 0.0, 0.15),   # deep berry
		],
	},
	"sad": {
		"speed": 9.0, "random": false,
		"colors": [
			Color(0.45, 0.3, 0.7),   # purple
			Color(0.25, 0.15, 0.45), # deep violet
			Color(0.7, 0.6, 0.9),    # lavender
			Color(0.55, 0.45, 0.8),  # soft lilac
			Color(0.2, 0.1, 0.35),   # dark purple
		],
	},
	"surprise": {
		"speed": 4.0, "random": true,
		"colors": [
			Color(0.4, 0.8, 1.0),    # sky blue
			Color(0.8, 0.95, 1.0),   # icy blue
			Color(0.5, 1.0, 1.0),    # cyan glow
			Color(0.7, 0.85, 1.0),   # pastel blue
			Color(1.0, 1.0, 1.0),    # white flash
		],
	},
	"fear": {
		"speed": 8.5, "random": false,
		"colors": [
			Color(0.55, 0.75, 1.0),  # light blue
			Color(0.2, 0.35, 0.6),   # storm blue
			Color(0.75, 0.85, 1.0),  # pale blue
			Color(0.35, 0.5, 0.75),  # muted blue
			Color(0.1, 0.15, 0.3),   # dark navy
		],
	},
	"trust": {
		"speed": 6.5, "random": false,
		"colors": [
			Color(0.2, 0.5, 0.25),   # green
			Color(0.45, 0.75, 0.5),  # soft green
			Color(0.7, 0.9, 0.75),   # pastel mint
			Color(0.3, 0.6, 0.4),    # sage green
			Color(0.1, 0.3, 0.15),   # deep forest green
		],
	},
}

const DEFAULT_PALETTE := {
	"speed": 6.0, "random": true,
	"colors": [
		Color(0.7, 0.8, 1.0),    # soft blue
		Color(0.9, 0.8, 1.0),    # lavender
		Color(1.0, 0.85, 0.9),   # pastel pink
		Color(1.0, 0.95, 0.7),   # warm cream
		Color(0.7, 0.9, 0.85),   # mint
	],
}


func _palette_for(emotion: String) -> Array:
	return EMOTION_PALETTES.get(emotion, DEFAULT_PALETTE)["colors"]


func apply_color(emotion: String):

	var entry: Dictionary = EMOTION_PALETTES.get(emotion, DEFAULT_PALETTE)
	var colors: Array = entry["colors"]
	var speed: float = entry["speed"]

	visualizer_speed = speed
	apply_visualizer_colors(colors, entry["random"])

	start_color_loop(colors, speed)



# The single colour that best stands for this feeling — the first entry of
# the palette apply_color() already uses, so stage 3's brushes match what
# the player saw here.
func _emotion_colour(emotion: String) -> Color:
	var palette := _palette_for(emotion)
	return palette[0] if not palette.is_empty() else Color(0.7, 0.8, 1.0)


func start_color_loop(colors: Array, speed):

	if color_tween:
		color_tween.kill()

	color_tween = create_tween()

	color_tween.set_loops()

	for color in colors:

		color_tween.tween_property(
			color_rect,
			"color",
			color,
			speed
		)
	
func _on_return_button_pressed() -> void:
	_return_to_park()


func _return_to_park() -> void:
	var campaign := get_node_or_null("/root/JourneyCampaign")
	if campaign != null and campaign.has_method("return_to_park"):
		campaign.call("return_to_park")
	else:
		SceneLoader.change_scene_with_loading(get_tree(), "res://scenes/New_Hub_World.tscn")
