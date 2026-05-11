extends Control

@onready var input = $VBoxContainer/EmotionInput
@onready var button = $VBoxContainer/GenerateButton
@onready var result = $VBoxContainer/ResultText
@onready var color_rect = $BackgroundVisual
@onready var player = $MusicPlayer
@onready var visualizer = $VisualizerContainer

var bars = []
var bar_speed_offsets = []
var bar_strength_offsets = []
var bar_offsets = []
var visualizer_speed = 5.0
var visualizer_strength = 180.0

var color_tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	#bars.clear()
	#bar_speeds.clear()
	#bar_strengths.clear()
	#bar_offsets.clear()
	
	button.pressed.connect(_on_generate_pressed)
		
	for child in visualizer.get_children():

		bars.append(child)
		
		bar_speed_offsets.append(randf_range(-1.0, 1.0))

		bar_strength_offsets.append(randf_range(-50.0, 50.0))

		bar_offsets.append(randf_range(0.0, 10.0))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):

	var time = Time.get_ticks_msec() / 1000.0

	for i in range(bars.size()):

		var bar = bars[i]

		var speed = (
	12.0
	- visualizer_speed * 1.0
	#+ bar_speed_offsets[i]
)
		
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

		bar.size.y = 20 + wave * strength

		bar.position.y = 300 - bar.size.y

func apply_visualizer_colors(colors: Array, random: bool):

	if colors.size() < 3:
		return

	var total_bars = bars.size()

	for i in range(total_bars):

		var bar = bars[i]

		var style = bar.get_theme_stylebox("panel")

		if style is StyleBoxFlat:

			# RANDOM MODE
			if random:

				var random_color = colors.pick_random()

				style.bg_color = random_color

			# SECTION MODE
			else:

				@warning_ignore("integer_division")
				var third_size = total_bars / 3

				if i < third_size:

					style.bg_color = colors[0]

				elif i < third_size * 2:

					style.bg_color = colors[1]

				else:

					style.bg_color = colors[2]

func detect_emotion(text: String) -> String:

	text = text.to_lower()

	# STRESS / OVERTHINKING / CONTROL
	if (
		text.find("stress") != -1 or
		text.find("overthink") != -1 or
		text.find("control") != -1 or
		text.find("pressur") != -1
	):
		return "stress"

	# EMPTY / NUMB
	elif (
		text.find("empty") != -1 or
		text.find("numb") != -1 or
		text.find("nothing") != -1 or
		text.find("blank") != -1
	):
		return "empty"

	# NOT ENOUGH / SELF WORTH / COMPARISON
	elif (
		text.find("not enough") != -1 or
		text.find("worthless") != -1 or
		text.find("compar") != -1 or
		text.find("behind") != -1 or
		text.find("inferior") != -1 or
		text.find("failure") != -1
	):
		return "enough"

	# PURPOSE / FUTURE FEAR
	elif (
		text.find("purpose") != -1 or
		text.find("future") != -1 or
		text.find("lost") != -1 or
		text.find("direction") != -1 or
		text.find("calling") != -1
	):
		return "purpose"

	# EXHAUSTION
	elif (
		text.find("tired") != -1 or
		text.find("exhaust") != -1 or
		text.find("burned out") != -1 or
		text.find("drained") != -1 or
		text.find("fatigue") != -1
	):
		return "exhausted"

	# GUILT / SHAME
	elif (
		text.find("guilt") != -1 or
		text.find("shame") != -1 or
		text.find("regret") != -1
	):
		return "guilt"

	# PEOPLE THINK / PEOPLE PLEASING
	elif (
		text.find("people think") != -1 or
		text.find("approval") != -1 or
		text.find("accepted") != -1 or
		text.find("accepting") != -1 or
		text.find("please everyone") != -1 or
		text.find("judged") != -1
	):
		return "peoplethink"

	# LEFT OUT / LONELY / REJECTION
	elif (
		text.find("alone") != -1 or
		text.find("lonely") != -1 or
		text.find("left out") != -1 or
		text.find("unwanted") != -1 or
		text.find("reject") != -1 or
		text.find("abandon") != -1
	):
		return "lonely"

	# SAD / GRIEF
	elif (
		text.find("sad") != -1 or
		text.find("grief") != -1 or
		text.find("cry") != -1 or
		text.find("depress") != -1 or
		text.find("heartbr") != -1
	):
		return "sad"

	# ANGER
	elif (
		text.find("angry") != -1 or
		text.find("mad") != -1 or
		text.find("furious") != -1 or
		text.find("rage") != -1 or
		text.find("irritated") != -1
	):
		return "anger"

	# IDENTITY / BURDEN
	elif (
		text.find("identity") != -1 or
		text.find("who am i") != -1 or
		text.find("who i am") != -1 or
		text.find("burden") != -1 or
		text.find("too much") != -1 or
		text.find("not enough") != -1
	):
		return "identity"

	# BODY IMAGE
	elif (
		text.find("ugly") != -1 or
		text.find("body") != -1 or
		text.find("appearance") != -1 or
		text.find("look") != -1 or
		text.find("fat") != -1
	):
		return "body"

	# PAST / TRUST
	elif (
		text.find("past") != -1 or
		text.find("hurt") != -1 or
		text.find("betray") != -1 or
		text.find("trust") != -1 or
		text.find("trauma") != -1
	):
		return "past"

	# GOD FAR
	elif (
		text.find("god") != -1 or
		text.find("faith") != -1 or
		text.find("spiritual") != -1 or
		text.find("abandoned by god") != -1
	):
		return "godfar"

	# DEFAULT
	else:
		return "neutral"

func play_music(emotion: String):

	var path = ""

	match emotion:

		"stress":
			path = "res://audio/stress.ogg"

		"empty":
			path = "res://audio/empty.ogg"

		"enough":
			path = "res://audio/enough.ogg"

		"purpose":
			path = "res://audio/purpose.ogg"

		"exhausted":
			path = "res://audio/exhausted.ogg"

		"guilt":
			path = "res://audio/guilt.ogg"

		"peoplethink":
			path = "res://audio/peoplethink.ogg"

		"lonely":
			path = "res://audio/lonely.ogg"

		"sad":
			path = "res://audio/sad.ogg"

		"anger":
			path = "res://audio/anger.ogg"

		"identity":
			path = "res://audio/identity.ogg"

		"body":
			path = "res://audio/body.ogg"

		"past":
			path = "res://audio/past.ogg"

		"trust":
			path = "res://audio/trust.ogg"

		"godfar":
			path = "res://audio/godfar.ogg"

		_:
			path = "res://audio/neutral.ogg"

	# load and play safely
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

		# STRESS / OVERTHINKING / CONTROL
		"stress", "overthinking", "control":
			speed = 3.5
			visualizer_speed = speed

			colors = [
				Color(0.15, 0.0, 0.25),   # dark purple
				Color(0.8, 0.2, 1.0),    # vivid violet
				Color(0.1, 0.8, 0.9)     # cyan
			]
			apply_visualizer_colors(colors, false)

		# EMPTY / NUMB
		"empty", "numb":
			speed = 9.0
			visualizer_speed = speed

			colors = [
				Color(0.08, 0.08, 0.12), # near black
				Color(0.45, 0.5, 0.6),   # cold gray blue
				Color(0.2, 0.25, 0.35)   # muted steel blue
			]
			apply_visualizer_colors(colors, true)

		# NOT ENOUGH / SELF WORTH / COMPARING / BEHIND
		"enough", "selfworth", "comparing", "behind":
			speed = 6.0
			visualizer_speed = speed

			colors = [
				Color(0.1, 0.1, 0.4),    # deep blue
				Color(1.0, 0.8, 0.2),    # gold
				Color(0.5, 0.2, 0.8)     # royal purple
			]
			apply_visualizer_colors(colors, true)

		# PURPOSE / FUTURE / FUTUREFEAR
		"purpose", "future", "futurefear":
			speed = 5.5
			visualizer_speed = speed

			colors = [
				Color(0.0, 0.2, 0.4),    # deep ocean blue
				Color(0.3, 0.9, 1.0),    # bright cyan
				Color(1.0, 0.9, 0.3)     # hopeful yellow
			]
			apply_visualizer_colors(colors, true)

		# EXHAUSTED
		"exhausted":
			speed = 10.0
			visualizer_speed = speed

			colors = [
				Color(0.05, 0.05, 0.2),  # dark blue
				Color(0.4, 0.5, 0.8),    # soft blue
				Color(0.15, 0.0, 0.25)   # faded purple
			]
			apply_visualizer_colors(colors, false)

		# GUILT / SHAME
		"guilt", "shame":
			speed = 7.0
			visualizer_speed = speed

			colors = [
				Color(0.2, 0.0, 0.0),    # deep maroon
				Color(0.7, 0.1, 0.1),    # dark red
				Color(1.0, 0.7, 0.2)     # redemption gold
			]
			apply_visualizer_colors(colors, false)

		# PEOPLE THINK / PLEASING
		"peoplethink", "pleasing":
			speed = 5.0
			visualizer_speed = speed

			colors = [
				Color(0.1, 0.1, 0.3),    # dark navy
				Color(1.0, 0.4, 0.7),    # pink
				Color(1.0, 0.85, 0.2)    # yellow
			]
			apply_visualizer_colors(colors, true)

		# LEFT OUT / LONELY / REJECTION
		"leftout", "lonely", "rejection":
			speed = 8.0
			visualizer_speed = speed

			colors = [
				Color(0.0, 0.05, 0.2),   # deep midnight blue
				Color(0.3, 0.5, 1.0),    # emotional blue
				Color(0.6, 0.7, 1.0)     # pale soft blue
			]
			apply_visualizer_colors(colors, false)

		# SAD / GRIEF
		"sad", "grief":
			speed = 9.0
			visualizer_speed = speed

			colors = [
				Color(0.0, 0.1, 0.3),    # dark blue
				Color(0.5, 0.7, 1.0),    # pale blue
				Color(0.3, 0.0, 0.4)     # melancholy purple
			]
			apply_visualizer_colors(colors, false)

		# ANGER
		"anger":
			speed = 3.0
			visualizer_speed = speed

			colors = [
				Color(0.25, 0.0, 0.0),   # blood red
				Color(1.0, 0.0, 0.0),    # bright red
				Color(1.0, 0.5, 0.0)     # fire orange
			]
			apply_visualizer_colors(colors, true)

		# IDENTITY / BURDEN
		"identity", "burden":
			speed = 6.5
			visualizer_speed = speed

			colors = [
				Color(0.1, 0.0, 0.3),    # deep indigo
				Color(0.7, 0.3, 1.0),    # violet
				Color(1.0, 1.0, 1.0)     # white
			]
			apply_visualizer_colors(colors, false)

		# BODY IMAGE
		"body":
			speed = 6.0
			visualizer_speed = speed

			colors = [
				Color(0.2, 0.0, 0.1),    # dark rose
				Color(1.0, 0.6, 0.7),    # soft pink
				Color(1.0, 0.9, 0.7)     # peach
			]
			apply_visualizer_colors(colors, false)

		# PAST / TRUST
		"past", "trust":
			speed = 7.0
			visualizer_speed = speed

			colors = [
				Color(0.1, 0.1, 0.1),    # dark gray
				Color(0.2, 0.7, 0.6),    # teal
				Color(0.8, 1.0, 0.9)     # pale mint
			]
			apply_visualizer_colors(colors, true)

		# GOD FAR
		"godfar":
			speed = 11.0
			visualizer_speed = speed

			colors = [
				Color(0.0, 0.0, 0.1),    # near black blue
				Color(0.2, 0.2, 0.5),    # distant blue
				Color(1.0, 0.95, 0.7)    # warm light
			]
			apply_visualizer_colors(colors, false)

		_:
			speed = 6.0
			visualizer_speed = speed

			colors = [
				Color(0.2, 0.6, 0.55),
				Color(0.35, 0.3, 0.5),
				Color(0.2, 0.4, 0.7)
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
	var text = input.text
	var emotion = detect_emotion(text)

	result.text = "Detected emotion: " + emotion

	play_music(emotion)
	apply_color(emotion)
	print("Finished processing")
