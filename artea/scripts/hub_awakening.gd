# Makes the hub world respond to how far the player has come.
#
# Attached to the HubWorld root. Reads JourneyState.stage and warms the
# world as the journey deepens. Stage 0 is the world exactly as authored —
# colour drained but no darker than it shipped — and each stage the player
# completes adds light and saturation on top.
#
# This is the payoff for Pop Thoughts — the player leaves, comes back, and
# the world is different because of what they did.
#
# Dev: in a debug build, press 1-5 in the hub to preview stages 0-4, 0 to
# wipe the journey.
extends Node3D

# Sun energy per stage. Index = JourneyState.stage.
# Stage 0 keeps cycle.tscn's authored baseline (0.65, raised from the
# original 0.45 for a brighter map overall) on purpose. A player who has
# not started yet must not find the world *darker* than it shipped — that
# reads as broken lighting, not as a sleeping castle. The journey only
# ever adds light on top of the baseline.
const STAGE_LIGHT := [1.10, 1.20, 1.30, 1.40, 1.52]

# The shipped environment's 0.95 brightness made shaded train/castle faces read
# as silhouettes against the gold sky. Keep the world gentle but legible from
# the first visit, then add a small lift as it wakes.
const STAGE_BRIGHTNESS := [1.05, 1.07, 1.09, 1.11, 1.13]

# Tint carries the stage as much as brightness does — a 10% energy step is
# invisible outdoors at midday, but cold blue-grey turning to warm gold
# reads instantly.
const STAGE_TINT := [
	Color(1.00, 0.96, 0.88),  # 0: clear daylight with a gentle warm key
	Color(1.00, 0.94, 0.82),  # 1: thoughts faced, warmth builds
	Color(1.00, 0.92, 0.76),  # 2: emotions honoured, warmth
	Color(1.00, 0.90, 0.68),  # 3: creations on the walls, golden
	Color(1.00, 0.88, 0.60),  # 4: crown of life, full sun
]

# Colour still deepens as the world wakes, but stage 0 is no longer
# desaturated toward grey — a new player must see a warm, colourful world
# from the first frame, just less vivid than a fully-awakened one.
# cycle.tscn authors saturation at 1.3, which is stage 2's value.
const STAGE_SATURATION := [1.00, 1.06, 1.12, 1.19, 1.26]

const AWAKEN_SECONDS := 2.5

@onready var _hub_root: Node = self
@onready var _sun: DirectionalLight3D = _hub_root.get_node_or_null(
	"Environment/DayNite/DirectionalLight3D")

var _env: Environment = null
var _fill_light: DirectionalLight3D = null


func _ready() -> void:
	_build_outdoor_minimap()
	# The day/night AnimationPlayer animates light_energy every frame, so a
	# tween on the same property would be overwritten. Stop the cycle
	# before taking over the sun.
	var anim := _hub_root.get_node_or_null("Environment/DayNite/AnimationPlayer")
	if anim and anim is AnimationPlayer:
		# stop() alone leaves the sky wherever autoplay happened to land. The
		# RESET animation is the *night* frame, despite its name; seeking it was
		# the reason the whole hub rendered as purple silhouettes. Freeze the
		# actual cycle just after its daytime keys instead.
		anim.stop()
		if anim.has_animation("cycle"):
			anim.play("cycle")
			anim.seek(12.0, true)
			anim.stop()

	var world_env := _hub_root.get_node_or_null("Environment/DayNite/WorldEnvironment")
	if world_env != null and world_env.environment != null:
		# The Environment resource is shared with cycle.tscn on disk, so
		# duplicate before writing — otherwise saturation changes leak into
		# every other scene using it.
		_env = world_env.environment.duplicate()
		world_env.environment = _env
		if OS.has_feature("web"):
			# The procedural desktop sky uses shader state beyond WebGL2's
			# compatibility budget. Keep a stable daylight backdrop on Web.
			var web_sky_color := Color(0.38, 0.67, 0.92)
			RenderingServer.set_default_clear_color(web_sky_color)
			_env.background_mode = Environment.BG_CLEAR_COLOR
			_env.background_color = web_sky_color
			_env.sky = null
			_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			_env.ambient_light_color = Color(0.72, 0.82, 0.92)
			# AMBIENT_SOURCE_COLOR still BLENDS toward the sky by
			# ambient_light_sky_contribution, which defaults to 1.0 and is
			# authored to 0.6 in cycle.tscn. With _env.sky cleared just above,
			# that fraction of the ambient term comes from nothing, so most of
			# the ambient light vanished and models rendered near-black. Force
			# the contribution to zero so the colour above is the whole term.
			_env.ambient_light_sky_contribution = 0.0
			_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		# This inherited Environment carries experimental height/depth fog values
		# (including a negative height density). Enabling them covers the nearby
		# world with an opaque blue sheet: the sky and UI remain visible while all
		# terrain, trains, and character meshes disappear. Keep legacy fog off;
		# the authored sky shader already supplies the distant atmosphere.
		_env.fog_enabled = false
		# Ambient must NOT be forced back to the sky on Web.  The block above
		# clears _env.sky (the procedural sky exceeds WebGL2's budget), so
		# sourcing ambient from the sky there means sourcing it from nothing:
		# ambient light drops to zero and every model renders as a black
		# silhouette, while sun-lit terrain still looks correct - which is what
		# made this read as a model bug rather than a lighting one.
		if not OS.has_feature("web"):
			_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		_env.ambient_light_energy = 1.25

	# A low-energy, shadowless lavender fill lifts the side of the castle and
	# trains facing away from the warm sun. This is what makes details readable
	# without bleaching the sky or removing the authored key-light shadows.
	_fill_light = DirectionalLight3D.new()
	_fill_light.name = "CastleUniverseFill"
	_fill_light.rotation_degrees = Vector3(-48.0, 142.0, 0.0)
	_fill_light.light_color = Color(0.78, 0.86, 1.0)
	_fill_light.light_energy = 0.48
	_fill_light.shadow_enabled = false
	add_child(_fill_light)

	if _sun == null:
		push_warning("hub_awakening: sun not found, sky will not respond to stage")

	apply_stage(_current_stage())


func _build_outdoor_minimap() -> void:
	# The outside kingdom needs its own atlas. The Art Castle scene creates the
	# galaxy atlas separately, so crossing the door always changes map context.
	var canvas := CanvasLayer.new()
	canvas.name = "WorldMapCanvas"
	canvas.layer = 40
	add_child(canvas)
	var minimap := Control.new()
	minimap.name = "ArteaWorldMinimap"
	minimap.set_script(load("res://scripts/art_castle_minimap.gd"))
	minimap.set("map_context", "hub")
	canvas.add_child(minimap)


# Tween the world to a stage. Public so a dev shortcut can drive it live.
func apply_stage(stage: int) -> void:
	stage = clampi(stage, 0, STAGE_LIGHT.size() - 1)

	# The portal pylons are independent of the sky, so they wake even in a
	# scene where the sun is missing.
	_wake_magitech(stage)

	if _sun == null:
		return

	# Always start from the sleeping look and rise, so the player watches
	# the world wake rather than finding it already awake.
	_sun.light_energy = STAGE_LIGHT[0]
	_sun.light_color = STAGE_TINT[0]
	if _env:
		_env.adjustment_enabled = true
		_env.adjustment_brightness = STAGE_BRIGHTNESS[0]
		_env.adjustment_saturation = STAGE_SATURATION[0]

	var tween := create_tween().set_parallel()
	tween.tween_property(_sun, "light_energy", STAGE_LIGHT[stage], AWAKEN_SECONDS) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_sun, "light_color", STAGE_TINT[stage], AWAKEN_SECONDS) \
		.set_trans(Tween.TRANS_SINE)
	if _env:
		tween.tween_property(_env, "adjustment_brightness",
			STAGE_BRIGHTNESS[stage], AWAKEN_SECONDS).set_trans(Tween.TRANS_SINE)
		tween.tween_property(_env, "adjustment_saturation",
			STAGE_SATURATION[stage], AWAKEN_SECONDS).set_trans(Tween.TRANS_SINE)


# The portal pylons and village lanterns wake on the same stage the sun
# does. Kept in step here rather than each reading JourneyState separately,
# so the dev preview keys below move the whole world at once.
func _wake_magitech(stage: int) -> void:
	for path in ["Magitech", "LandmarkGlow", "LumenCitadel", "AetherAtlas",
			"CastleCrown", "CastleEntrance", "SkyRail", "SkyIsles"]:
		var node := _hub_root.get_node_or_null(path)
		if node != null and node.has_method("apply_stage"):
			node.apply_stage(stage)


# --- dev shortcut -----------------------------------------------------
# Keys 1-5 preview stages 0-4 live; 0 wipes the journey back to a fresh
# save. Debug builds only — stripped from exported release builds, so
# players can never reach it.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			# Explicitly typed: event.keycode is untyped, so := cannot infer
			# here and the whole script fails to compile.
			var stage: int = event.keycode - KEY_1
			var js := get_node_or_null("/root/JourneyState")
			if js:
				js.stage = stage
				js.save()
			apply_stage(stage)
			print("[dev] previewing stage %d — energy %.2f, saturation %.2f"
				% [stage, STAGE_LIGHT[stage], STAGE_SATURATION[stage]])

		KEY_0:
			var js := get_node_or_null("/root/JourneyState")
			if js:
				js.clear_journey()
			apply_stage(0)
			print("[dev] journey wiped — back to stage 0")


# Clamped so a future stage value can never index past the tables.
func _current_stage() -> int:
	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return 0
	return clampi(js.stage, 0, STAGE_LIGHT.size() - 1)
