extends Node3D

# The custom procedural sky shader (stylizedsky.gdshader) used to render
# solid black, then solid white, under the web export's GLES3/Compatibility
# renderer. Neither was the shader itself - stylizedsky.gdshader's real bug
# (render_mode use_half_res_pass reading HALF_RES_COLOR back as opaque black
# under Compatibility) was already fixed by computing clouds directly instead
# of via that half-res pass. What remained were two things stacked on top of
# each other:
#
# 1. hub_awakening.gd duplicated this Environment after this node's _ready()
#    ran and unconditionally reset ambient_light_source back to SKY on every
#    platform, undoing whatever this script set. Fixed there by gating that
#    reset behind `if not OS.has_feature("web")`.
# 2. Glow is an additive full-screen bloom pass, and under the Compatibility
#    renderer's non-HDR bloom it washes bright/light content out to solid
#    white far more aggressively than under Forward+/Mobile. hub_awakening.gd
#    also tweens the sun up to 1.10-1.52 energy (vs the scene's authored
#    0.45-0.65), feeding a brighter source into that bloom. Confirmed by
#    testing background_color directly: a saturated test colour survived
#    intact, but the authored daylight blue (already close to white in raw
#    luminance) washed to solid white until glow was disabled.
#
# With both fixed, the authored sky renders correctly on web same as desktop
# - no flat-colour fallback needed.
func _ready():
	if OS.has_feature("web"):
		var world_env = $WorldEnvironment
		if world_env and world_env.environment:
			var env = world_env.environment
			env.background_mode = Environment.BG_SKY
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_sky_contribution = 1.0
			env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
			env.glow_enabled = false

		_disable_scatter_threading()
		_skip_relax_on_web()

# ProtonScatter's force_rebuild_on_load spawns a real Thread (scatter.gd:357-358)
# to run the build. The web export runs without WASM thread support (required
# because terrain_3d's web binary is non-threaded-only), so that Thread never
# actually executes its work, but is_thread_running() reports true forever -
# meaning the initial build silently produces zero output, AND every later
# rebuild() call just queues a flag and returns without ever touching the
# modifier stack. scatter.gd has a built-in escape hatch for this:
# dbg_disable_thread runs the same update synchronously on the main thread
# instead of spawning a Thread. Must be set before the node's own _ready()-
# deferred full_rebuild() call fires - since deferred calls run after all
# _ready() calls in the current batch, setting it here (a sibling node whose
# _ready() runs after Grass/Objects in file order) is early enough.
func _disable_scatter_threading():
	for node_name in ["Grass", "Objects"]:
		var scatter_node = get_node_or_null("../" + node_name)
		if scatter_node and "dbg_disable_thread" in scatter_node:
			scatter_node.dbg_disable_thread = true

# ProtonScatter's "Relax Position" modifier is O(n^2) per iteration on the
# CPU (its own documentation says so), and only avoids that cost via a
# compute shader - which requires a RenderingDevice backend (Vulkan/D3D12/
# Metal). Web is stuck on the Compatibility/GLES3 renderer, so
# create_local_rendering_device() returns null there and every relax
# modifier silently falls back to the CPU path. Measured cost on this
# scene's Grass node (3000 points x 3 iterations): ~10-14 seconds, on
# every single hub load - this was the actual cause of "entering rooms
# takes forever", not scene loading itself (confirmed <50ms via timing
# instrumentation). Desktop uses Vulkan/D3D12/Metal and never hits this,
# so iterations only needs reducing on web.
func _skip_relax_on_web():
	for node_name in ["Grass", "Objects"]:
		var scatter_node = get_node_or_null("../" + node_name)
		if not scatter_node or not "modifier_stack" in scatter_node:
			continue
		var stack = scatter_node.modifier_stack
		if not stack or not "stack" in stack:
			continue
		for modifier in stack.stack:
			if modifier and modifier.get_script() and modifier.get_script().resource_path.ends_with("relax.gd"):
				modifier.iterations = 0
