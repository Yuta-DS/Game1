extends Node3D

# The custom procedural sky shader (stylizedsky.gdshader) renders solid
# black under the web export's GLES3/Compatibility renderer. Extensively
# ruled out as the cause: shader compile failure, shader logic (forced-
# magenta test - written before any texture sampling, still came out
# black), half-res-pass compositing, glow, fog, adjustment, multiple
# WorldEnvironment nodes, camera environment override, Sky.process_mode
# (baked vs realtime). This is a genuine gap in Godot 4.7.1's Compatibility
# renderer's sky compositing, not something fixable at the project level -
# falling back to a flat sky color + BG-sourced lighting on web only;
# desktop keeps the full shader-driven sky.
func _ready():
	if OS.has_feature("web"):
		var world_env = $WorldEnvironment
		if world_env and world_env.environment:
			var env = world_env.environment
			env.background_mode = Environment.BG_COLOR
			env.ambient_light_source = Environment.AMBIENT_SOURCE_BG
			env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED

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
