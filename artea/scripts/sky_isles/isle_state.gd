# Dormant/vibrant state system for Sky Isles.
#
# Attached to node "IsleState" under the world root. Owns the single public
# switch every other system (debug panel, future gallery hooks, whatever
# eventually replaces the "leave a hook for progress logic" comment below)
# flips to wake or sleep an island. Autoload-free by contract — this is a
# plain node other scripts reach via get_node(), not a singleton.
#
# Islands (Agent B's isle_castle.gd / isle_kingdoms.gd) build their own
# geometry and hand back real material/light/particle references via
# state_targets(). This script never constructs geometry, it only drives
# the properties on what it's handed — same division of responsibility as
# hub_awakening.gd driving the hub's sun/environment instead of building it.
extends Node3D

signal isle_state_changed(isle_id: String, state: String)

const ISLE_NODE_NAMES := {
	"castle": "Isle_castle",
	"mind": "Isle_mind",
	"heart": "Isle_heart",
	"creator": "Isle_creator",
}

const SWAP_SECONDS := 1.5

# Vibrant/dormant light + particle tuning. Colours themselves come from
# sky_isles_world.gd's PALETTE — this script reads that table, it does not
# redefine island colours per CONTRACT.md.
const EMISSION_ENERGY_VIBRANT := 1.4
const EMISSION_ENERGY_DORMANT := 0.0
const LIGHT_ENERGY_SCALE_VIBRANT := 1.0  # multiplies each light's own authored energy
const LIGHT_ENERGY_SCALE_DORMANT := 0.15

# Dormant is the default for every island at scene start, castle included —
# CONTRACT.md is explicit that nothing starts pre-awakened.
var _states: Dictionary = {}

# One live tween per island so re-toggling mid-swap cancels the old tween
# instead of fighting it for the same properties.
var _tweens: Dictionary = {}

# World root's PALETTE, read once found. Typed Variant on purpose: PALETTE
# is an untyped const Dictionary literal, so := here would infer Variant and
# trip the project's warnings-as-errors setting.
var _palette: Dictionary = {}


func _ready() -> void:
	for isle_id in ISLE_NODE_NAMES.keys():
		_states[isle_id] = "dormant"

	# World root may still be finishing its own _ready (sibling nodes build
	# in whatever order the scene tree assigns), and island nodes from the
	# concurrently-written isle_kingdoms.gd may not exist for a frame or two
	# after that. Give the tree a couple of frames before touching anything.
	await get_tree().process_frame
	await get_tree().process_frame

	_load_palette()

	# Apply the dormant baseline explicitly (instant, not tweened) so any
	# island that starts with emission/lights/particles authored "on" is
	# forced to the resting look before the player ever sees a frame.
	for isle_id in ISLE_NODE_NAMES.keys():
		_apply_state_instant(isle_id, "dormant")


# --- public API ----------------------------------------------------------

func set_isle_state(isle_id: String, state: String) -> void:
	if state != "dormant" and state != "vibrant":
		push_warning("isle_state: unknown state '%s' for '%s', ignoring" % [state, isle_id])
		return
	if not ISLE_NODE_NAMES.has(isle_id):
		push_warning("isle_state: unknown isle_id '%s'" % isle_id)
		return

	_states[isle_id] = state
	_tween_to_state(isle_id, state)
	isle_state_changed.emit(isle_id, state)

	# --- progress-system hook point -----------------------------------
	# Deliberately NOT coupled to JourneyState here. When island wake-state
	# should start tracking player progress instead of the debug panel,
	# drive it by calling set_isle_state() from that system — this function
	# stays the single entry point, nothing else in this file should know
	# progress exists.


func get_isle_state(isle_id: String) -> String:
	if _states.has(isle_id):
		return _states[isle_id]
	return "dormant"


func toggle_isle(isle_id: String) -> void:
	var current: String = get_isle_state(isle_id)
	var next: String = "dormant" if current == "vibrant" else "vibrant"
	set_isle_state(isle_id, next)


# --- palette -------------------------------------------------------------

# Reads sky_isles_world.gd's PALETTE off the world root rather than
# redefining colours locally, per CONTRACT.md ("everyone else reads them,
# nobody redefines them"). Falls back to isle_castle.gd's own duplicated
# constants for "castle" only if the world root script cannot be reached —
# mirrors the same no-hard-load-order-dependency pattern isle_castle.gd
# already uses for isle_builder.gd.
func _load_palette() -> void:
	# Matches _find_isle()'s lookup below: get_tree().current_scene when run
	# normally (main scene or change_scene_to_*), falling back to our own
	# parent (the world root IsleState sits directly under) for harnesses
	# that instantiate this scene without going through that flow.
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_parent()
	if root != null and root.get_script() != null:
		# A GDScript const is readable directly off the object once the
		# script is attached — Object.get() returns it like a property.
		# Typed Variant on purpose: get() always returns Variant.
		var maybe_palette: Variant = root.get("PALETTE")
		if maybe_palette is Dictionary and not (maybe_palette as Dictionary).is_empty():
			_palette = maybe_palette
			return

	push_warning("isle_state: could not read PALETTE from world root, using castle-only fallback")
	_palette = {
		"castle": {"dormant": Color(0.42, 0.40, 0.48), "vibrant": Color(0.85, 0.80, 0.92)},
	}


func _palette_color(isle_id: String, state: String) -> Color:
	if _palette.has(isle_id):
		var entry: Dictionary = _palette[isle_id]
		if entry.has(state):
			var c: Color = entry[state]
			return c
	# Neutral grey fallback so an unrecognised isle still swaps something
	# visible rather than silently no-op'ing.
	return Color(0.5, 0.5, 0.5) if state == "dormant" else Color(0.9, 0.9, 0.9)


# --- node lookup -----------------------------------------------------------

func _find_isle(isle_id: String) -> Node:
	if not ISLE_NODE_NAMES.has(isle_id):
		return null
	var node_name: String = ISLE_NODE_NAMES[isle_id]

	# owner/parent rather than get_tree().current_scene, which is null when
	# the scene is instantiated manually instead of loaded as the main scene.
	var root: Node = owner if owner != null else get_parent()
	if root == null:
		return null

	# Recursive: the castle names itself Isle_castle at the top level, but the
	# kingdom islands are children of the "Isles2" node, so a direct-child
	# lookup would silently miss three of the four islands.
	return _find_descendant(root, node_name)


# Depth-first search by node name, so islands can sit at any depth under the
# world root without this system needing to know the scene's shape.
func _find_descendant(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for child in node.get_children():
		var hit := _find_descendant(child, target)
		if hit != null:
			return hit
	return null


# Fetches state_targets() from the island, guarding every step: island may
# not exist yet (isle_kingdoms.gd is being written concurrently), or may
# exist but not have reached _ready() and populated its arrays yet.
func _find_targets(isle_id: String) -> Dictionary:
	var isle := _find_isle(isle_id)
	if isle == null:
		return {}
	if not isle.has_method("state_targets"):
		return {}
	var targets: Dictionary = isle.state_targets()
	return targets


# --- swap: tweened -----------------------------------------------------

func _tween_to_state(isle_id: String, state: String) -> void:
	var targets: Dictionary = _find_targets(isle_id)
	if targets.is_empty():
		return

	if _tweens.has(isle_id):
		var old_tween: Tween = _tweens[isle_id]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()

	var albedo_target: Color = _palette_color(isle_id, state)
	var emission_energy_target: float = EMISSION_ENERGY_VIBRANT if state == "vibrant" else EMISSION_ENERGY_DORMANT
	var light_scale_target: float = LIGHT_ENERGY_SCALE_VIBRANT if state == "vibrant" else LIGHT_ENERGY_SCALE_DORMANT

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens[isle_id] = tween

	var materials: Array = targets.get("materials", [])
	for i in materials.size():
		var mat: StandardMaterial3D = materials[i]
		if mat != null:
			tween.tween_property(mat, "albedo_color", albedo_target, SWAP_SECONDS)

	var emissives: Array = targets.get("emissives", [])
	for i in emissives.size():
		var mat: StandardMaterial3D = emissives[i]
		if mat != null:
			mat.emission_enabled = true  # must be true for either endpoint to render/tween
			tween.tween_property(mat, "emission_energy_multiplier", emission_energy_target, SWAP_SECONDS)
			# Emissive panes (windows etc.) also carry an albedo tint toward
			# the same palette colour so they don't stay a flat dark square
			# while dormant next to now-desaturated stone.
			tween.tween_property(mat, "albedo_color", albedo_target, SWAP_SECONDS)

	var lights: Array = targets.get("lights", [])
	for i in lights.size():
		var light: Light3D = lights[i]
		if light != null:
			# Scale relative to whatever energy the island authored the light
			# with, rather than a hardcoded absolute — isle_castle.gd's
			# lanterns and a future island's brighter beacon both land at
			# "15% of authored" dormant / "100% of authored" vibrant.
			if not light.has_meta("base_energy"):
				light.set_meta("base_energy", light.light_energy / LIGHT_ENERGY_SCALE_VIBRANT if light.light_energy > 0.0 else 1.0)
			var base_energy: float = light.get_meta("base_energy")
			var energy_target: float = base_energy * light_scale_target
			tween.tween_property(light, "light_energy", energy_target, SWAP_SECONDS)

	var particles: Array = targets.get("particles", [])
	if state == "vibrant":
		for i in particles.size():
			var p: GPUParticles3D = particles[i]
			if p != null:
				p.emitting = true
	else:
		# Particles stop emitting only once the swap finishes, so existing
		# ones drift out naturally instead of vanishing mid-tween.
		tween.chain().tween_callback(func():
			for i in particles.size():
				var p: GPUParticles3D = particles[i]
				if p != null:
					p.emitting = false
		)


# Instant version of the same swap, used once at startup to force the
# dormant baseline without a visible fade on the very first frame.
func _apply_state_instant(isle_id: String, state: String) -> void:
	var targets: Dictionary = _find_targets(isle_id)
	if targets.is_empty():
		return

	var albedo_target: Color = _palette_color(isle_id, state)
	var emission_energy_target: float = EMISSION_ENERGY_VIBRANT if state == "vibrant" else EMISSION_ENERGY_DORMANT
	var light_scale_target: float = LIGHT_ENERGY_SCALE_VIBRANT if state == "vibrant" else LIGHT_ENERGY_SCALE_DORMANT

	var materials: Array = targets.get("materials", [])
	for i in materials.size():
		var mat: StandardMaterial3D = materials[i]
		if mat != null:
			mat.albedo_color = albedo_target

	var emissives: Array = targets.get("emissives", [])
	for i in emissives.size():
		var mat: StandardMaterial3D = emissives[i]
		if mat != null:
			mat.emission_enabled = true
			mat.emission_energy_multiplier = emission_energy_target
			mat.albedo_color = albedo_target

	var lights: Array = targets.get("lights", [])
	for i in lights.size():
		var light: Light3D = lights[i]
		if light != null:
			if not light.has_meta("base_energy"):
				light.set_meta("base_energy", light.light_energy / LIGHT_ENERGY_SCALE_VIBRANT if light.light_energy > 0.0 else 1.0)
			var base_energy: float = light.get_meta("base_energy")
			light.light_energy = base_energy * light_scale_target

	var particles: Array = targets.get("particles", [])
	for i in particles.size():
		var p: GPUParticles3D = particles[i]
		if p != null:
			p.emitting = (state == "vibrant")
