extends Control

@onready var input = $HBoxContainer/VBoxContainer/EmotionInput
@onready var button = $HBoxContainer/VBoxContainer/GenerateButton
@onready var result = $HBoxContainer/VBoxContainer/ResultText
@onready var color_rect = $BackgroundVisual
@onready var player = $MusicPlayer
@onready var visualizer = $VisualizerContainer
@onready var emotion_ai = $EmotionAI
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
@onready var model = $Model
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
var valid_emotions = [
	"happy",
	"anticipation",
	"angry",
	"disgust",
	"sad",
	"surprise",
	"fear",
	"trust"
]

var color_tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	player.stream = load("res://assets/audio/minigame/intro.mp3")
	player.play()
	
	# The emotion classifier needs the local LLM, which has no web build.
	# Skip AI setup there; the minigame still runs, just without classification.
	if Global.has_local_llm():
		# Load model
		model.model_path = "res://nobodywhomodels/gemma-2-2b-it-Q4_K_M.gguf"

		# Connect model to AI node
		emotion_ai.set_model_node(model)

		# Set strict emotion classifier prompt
		emotion_ai.set_system_prompt(load_emotion_prompt())

		# Start AI worker
		emotion_ai.start_worker()

		# Connect response signal
		emotion_ai.connect(
			"response_finished",
			Callable(self, "_on_emotion_response")
		)
	else:
		print("Local LLM unavailable (web build) - emotion AI disabled.")
	
	if not button.pressed.is_connected(_on_generate_pressed):
		button.pressed.connect(_on_generate_pressed)
		
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
	
func _on_volume_changed(value: float):

	var adjusted = pow(value, 2.0)

	player.volume_db = linear_to_db(adjusted)
	drums_player.volume_db = linear_to_db(adjusted)

func _on_drums1_pressed():
	play_drum_loop("res://assets/audio/minigame/beats/drums_1.mp3")

func _on_drums2_pressed():
	play_drum_loop("res://assets/audio/minigame/beats/drums_2.mp3")

func _on_drums3_pressed():
	play_drum_loop("res://assets/audio/minigame/beats/drums_3.mp3")

func _on_drums4_pressed():
	play_drum_loop("res://assets/audio/minigame/beats/drums_4.mp3")
	
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

func load_emotion_prompt() -> String:

	return """
You are an emotion ranking system.

You must analyze the user's text and distribute 100 points across emotions based on how strongly each emotion is present.

Return ONLY valid JSON:

{
  "happy": number,
  "anticipation": number,
  "trust": number,
  "surprise": number,
  "angry": number,
  "sad": number,
  "fear": number,
  "disgust": number
}

RULES:
- All values must be integers
- ALL values combined MUST equal 100
- At least ONE emotion must be greater than 0
- Do NOT output all zeros
- Strongest emotion should have the highest value
- Weak emotions should still get small values (1–20 range)
- If uncertain, distribute evenly but NEVER all zeros

OUTPUT ONLY JSON
NO explanation
NO extra text
"""

func extract_json(text: String) -> String:

	var start = text.find("{")
	var end = text.rfind("}")

	if start == -1 or end == -1:
		return ""

	return text.substr(start, end - start + 1)
	
func clean_ai_response(text: String) -> String:

	# remove markdown code blocks
	text = text.replace("```json", "")
	text = text.replace("```", "")

	return text.strip_edges()

func parse_emotion_from_response(response: String):

	var cleaned = clean_ai_response(response)
	print("Cleaned: ", cleaned)
	var json_str = extract_json(cleaned)
	print("Json_str: ", json_str)

	if json_str == "":
		print("Json_str == \"\"")
		return "surprise"

	var data = JSON.parse_string(json_str)
	print("Type of data: ", typeof(data))
	print("TYPE_DICTIONARY == ", TYPE_DICTIONARY)

	if typeof(data) != TYPE_DICTIONARY:
		print("Data type mismatch")
		return "surprise"

	var best_emotion = ""
	var best_score = -1

	for key in data.keys():

		var value = data[key]
		print("Key: ", key, " Value: ", value)

		if typeof(value) != TYPE_FLOAT:
			print("Value !TYPE_FLOAT")
			continue

		if value > best_score:
			best_score = value
			best_emotion = key

	if best_emotion == "":
		return "surprise"

	return best_emotion

func detect_emotion(user_text: String):

	print("Analyzing emotion...")
	print(user_text)

	emotion_ai.say(user_text)

func _on_emotion_response(response):
	print(typeof(response))
	print(response)
	#var emotion = response.strip_edges().to_lower()
	var emotion = parse_emotion_from_response(response)

	print("RAW AI RESPONSE: " + emotion)

	# Safety validation
	if emotion not in valid_emotions:

		print("Invalid emotion returned.")
		print("Falling back to surprise.")

		emotion = "surprise"
		
	result.text = "Detected emotion: " + emotion

	print("FINAL EMOTION: " + emotion)

	apply_color(emotion)

	play_music(emotion)
	
	print("Finished processing.")

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
			path = "res://assets/audio/minigame/happy.mp3"

		"anticipation":
			path = "res://assets/audio/minigame/anticipation.mp3"

		"angry":
			path = "res://assets/audio/minigame/angry.mp3"

		"disgust":
			path = "res://assets/audio/minigame/disgust.mp3"

		"sad":
			path = "res://assets/audio/minigame/sad.mp3"

		"surprise":
			path = "res://assets/audio/minigame/surprise.mp3"

		"fear":
			path = "res://assets/audio/minigame/fear.mp3"

		"trust":
			path = "res://assets/audio/minigame/trust.mp3"

		_:
			path = "res://assets/audio/minigame/intro.mp3"

	var stream = load(path)

	if stream:
		player.stream = stream
		player.play()
	else:
		print("Audio file missing: ", path)

func apply_color(emotion: String):

	var colors = []
	var speed = 6.0

	match emotion:

		# HAPPY
		"happy":

			speed = 5.0
			visualizer_speed = speed

			colors = [
				Color(1.0, 0.9, 0.2),    # bright yellow
				Color(1.0, 0.75, 0.4),   # warm peach
				Color(1.0, 0.85, 0.7),   # pastel peach
				Color(1.0, 0.7, 0.8),    # soft pink
				Color(1.0, 1.0, 0.85)    # creamy light
			]

			apply_visualizer_colors(colors, true)

		# ANTICIPATION
		"anticipation":

			speed = 4.5
			visualizer_speed = speed

			colors = [
				Color(1.0, 0.55, 0.15),  # orange
				Color(1.0, 0.75, 0.3),   # golden orange
				Color(1.0, 0.85, 0.5),   # soft amber
				Color(1.0, 0.65, 0.55),  # coral
				Color(1.0, 0.9, 0.7)     # pastel orange
			]

			apply_visualizer_colors(colors, false)

		# ANGER
		"angry":

			speed = 3.0
			visualizer_speed = speed

			colors = [
				Color(0.9, 0.1, 0.1),    # bright red
				Color(0.5, 0.0, 0.0),    # dark red
				Color(1.0, 0.3, 0.0),    # fiery orange
				Color(0.8, 0.0, 0.2),    # crimson
				Color(0.4, 0.0, 0.1)     # blood red
			]

			apply_visualizer_colors(colors, true)

		# DISGUST
		"disgust":

			speed = 7.0
			visualizer_speed = speed

			colors = [
				Color(0.7, 0.1, 0.4),    # dark pink
				Color(0.5, 0.0, 0.25),   # wine
				Color(0.9, 0.5, 0.7),    # dusty pink
				Color(0.6, 0.2, 0.45),   # muted magenta
				Color(0.3, 0.0, 0.15)    # deep berry
			]

			apply_visualizer_colors(colors, false)

		# SAD
		"sad":

			speed = 9.0
			visualizer_speed = speed

			colors = [
				Color(0.45, 0.3, 0.7),   # purple
				Color(0.25, 0.15, 0.45), # deep violet
				Color(0.7, 0.6, 0.9),    # lavender
				Color(0.55, 0.45, 0.8),  # soft lilac
				Color(0.2, 0.1, 0.35)    # dark purple
			]

			apply_visualizer_colors(colors, false)

		# SURPRISE
		"surprise":

			speed = 4.0
			visualizer_speed = speed

			colors = [
				Color(0.4, 0.8, 1.0),    # sky blue
				Color(0.8, 0.95, 1.0),   # icy blue
				Color(0.5, 1.0, 1.0),    # cyan glow
				Color(0.7, 0.85, 1.0),   # pastel blue
				Color(1.0, 1.0, 1.0)     # white flash
			]

			apply_visualizer_colors(colors, true)

		# FEAR
		"fear":

			speed = 8.5
			visualizer_speed = speed

			colors = [
				Color(0.55, 0.75, 1.0),  # light blue
				Color(0.2, 0.35, 0.6),   # storm blue
				Color(0.75, 0.85, 1.0),  # pale blue
				Color(0.35, 0.5, 0.75),  # muted blue
				Color(0.1, 0.15, 0.3)    # dark navy
			]

			apply_visualizer_colors(colors, false)

		# TRUST
		"trust":

			speed = 6.5
			visualizer_speed = speed

			colors = [
				Color(0.2, 0.5, 0.25),   # green
				Color(0.45, 0.75, 0.5),  # soft green
				Color(0.7, 0.9, 0.75),   # pastel mint
				Color(0.3, 0.6, 0.4),    # sage green
				Color(0.1, 0.3, 0.15)    # deep forest green
			]

			apply_visualizer_colors(colors, false)

		_:

			speed = 6.0
			visualizer_speed = speed

			colors = [
				Color(0.7, 0.8, 1.0),    # soft blue
				Color(0.9, 0.8, 1.0),    # lavender
				Color(1.0, 0.85, 0.9),   # pastel pink
				Color(1.0, 0.95, 0.7),   # warm cream
				Color(0.7, 0.9, 0.85)    # mint
			]

			apply_visualizer_colors(colors, true)

	start_color_loop(colors, speed)

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
	
func _on_generate_pressed():

	var text = input.text.strip_edges()

	if text == "":
		return

	# Without the local LLM there is no worker to answer, so bail out with a
	# message instead of leaving "Analyzing emotion..." on screen forever.
	if not Global.has_local_llm():
		result.text = "Emotion analysis is unavailable in the browser version."
		return

	result.text = "Analyzing emotion..."

	if not music_system_activated:
		music_system_activated = true

	detect_emotion(text)

	print("Emotion request sent")


func _on_return_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/New_Hub_World.tscn")
