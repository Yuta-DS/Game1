# Sky Isles — shared build contract

Parallel agents build against this file. Do not change it without saying so
in your final report; other agents have already coded against these names.

## What this is

A self-contained floating-island world for ARTÉA: four islands in a sky,
linked by a hub-and-spoke train network. Built as a NEW scene. It does not
touch `New_Hub_World.tscn` or any `hub_*.gd` script.

## Hard rules

1. **Never edit** `scenes/New_Hub_World.tscn`, `scripts/hub_*.gd`,
   `scripts/aether_atlas.gd`, `scripts/JourneyState.gd`, `project.godot`.
2. **Runtime authoring only.** Build geometry in `_ready()` from code, the
   same convention as `hub_magitech.gd`. The only authored scene file is
   `scenes/sky_isles.tscn`, which is a near-empty root plus child nodes with
   scripts attached.
3. **Mobile renderer.** `renderer/rendering_method="mobile"`. No SDFGI, no
   volumetric fog, no screen-reading shaders. Target iPad.
4. **GDScript, not C#.** Matches every existing `hub_*` script.
5. Tabs for indentation, `snake_case.gd` filenames, typed vars where
   practical. Match the comment density of `hub_magitech.gd`: explain *why*,
   never *what*.
6. Every file starts with a comment block explaining its role.

## File ownership — one agent per file, no overlap

| File | Owner | Builds |
|---|---|---|
| `scripts/sky_isles/sky_isles_world.gd` | A | Root controller, sky, fog, motes, island registry |
| `scripts/sky_isles/isle_builder.gd` | A | Island mesh construction (shared by all four) |
| `scripts/sky_isles/isle_castle.gd` | B | Island 1 — ARTÉA Castle + Grand Station + GALLERY_ANCHOR |
| `scripts/sky_isles/isle_kingdoms.gd` | B | Islands 2-4 — Mind Spark, Heart Melody, Creator's Light |
| `scripts/sky_isles/rail_network.gd` | C | 3 rail curves, support pillars, 3 train meshes |
| `scripts/sky_isles/travel_controller.gd` | C | Click-to-travel, camera ride along curve |
| `scripts/sky_isles/isle_state.gd` | D | dormant/vibrant material+light swap |
| `scripts/sky_isles/debug_panel.gd` | D | On-screen toggles + keyboard shortcuts |
| `scenes/sky_isles.tscn` | A | Scene wiring (built LAST, after scripts exist) |

## Island layout — fixed world coordinates

Y=0 is the sky plane the islands float on. Castle is largest and central.

```
const ISLES := {
	"castle":   { pos = Vector3(0, 0, 0),      radius = 34.0 },
	"mind":     { pos = Vector3(-95, 12, -60), radius = 20.0 },
	"heart":    { pos = Vector3(105, -6, -40), radius = 20.0 },
	"creator":  { pos = Vector3(15, 8, 115),   radius = 20.0 },
}
```

Kingdom islands sit at different heights on purpose — a flat ring reads as
a menu, staggered heights read as a place.

## Palette — single source of truth

Agent A defines these in `sky_isles_world.gd` as `const PALETTE`. Everyone
else reads them, nobody redefines them.

```
castle : dormant Color(0.42,0.40,0.48)  vibrant Color(0.85,0.80,0.92)
mind   : dormant Color(0.34,0.38,0.52)  vibrant Color(0.45,0.62,1.00)  # blue/lavender
heart  : dormant Color(0.50,0.38,0.44)  vibrant Color(1.00,0.55,0.62)  # pink/coral
creator: dormant Color(0.50,0.45,0.34)  vibrant Color(1.00,0.76,0.30)  # amber/gold
```

Sky gradient: lavender `Color(0.72,0.68,0.88)` at horizon → pale gold
`Color(0.98,0.93,0.78)` at top. Fog matches horizon lavender.

## Interfaces between agents — code against these exactly

### Island nodes (B provides, A/C/D consume)

Every island is a `Node3D` added under the world root, named exactly
`Isle_castle`, `Isle_mind`, `Isle_heart`, `Isle_creator`.

Each island node sets these in its `_ready()`:

```gdscript
# Metadata every other system reads.
set_meta("isle_id", "mind")             # castle|mind|heart|creator
set_meta("platform_pos", Vector3(...))  # world pos where a train docks
set_meta("camera_anchor", Vector3(...)) # where the camera sits on arrival
set_meta("look_target", Vector3(...))   # what the camera looks at there
```

Each island node must expose:

```gdscript
# Collect every material that should change with state, plus every light.
# isle_state.gd calls this once and drives the swap. Return real references,
# not copies.
func state_targets() -> Dictionary:
	return {
		"materials": [StandardMaterial3D, ...],  # albedo gets tinted
		"emissives": [StandardMaterial3D, ...],  # emission turns on when vibrant
		"lights":    [Light3D, ...],             # energy scales with state
		"particles": [GPUParticles3D, ...],      # enabled only when vibrant
	}
```

### Idle bob (A owns, applies to islands B built)

A applies bob in `sky_isles_world.gd::_process`. B must NOT animate island
Y itself. A reads `set_meta("bob_phase", float)` if B set one; otherwise A
assigns a phase per island. Amplitude 0.1-0.3, period 6-11s, phase offset
per island so they never sync.

### Rails (C), needs B's platforms

C reads `isle.get_meta("platform_pos")` for both ends of each line. C must
handle the case where an island node does not exist yet by awaiting one
frame in `_ready()` — build order is not guaranteed.

Rail lines, colour-matched to destination:
- `castle ↔ mind`, `castle ↔ heart`, `castle ↔ creator`

### Travel (C)

```gdscript
# Public. Called by a click on a train/station, and by debug_panel.
# Rides the camera along the line's curve, then hands control to the
# destination island's camera_anchor.
func travel_to(isle_id: String) -> void

signal travel_started(from_id: String, to_id: String)
signal travel_finished(isle_id: String)
```

Travel takes ~4s, `Tween.TRANS_SINE`, `EASE_IN_OUT`. Camera follows the
curve, not a straight lerp. Input is locked during travel and released on
`travel_finished`.

### State (D)

```gdscript
# Autoload-free. A node under the world root.
func set_isle_state(isle_id: String, state: String) -> void  # "dormant"|"vibrant"
func get_isle_state(isle_id: String) -> String
func toggle_isle(isle_id: String) -> void

signal isle_state_changed(isle_id: String, state: String)
```

Swap is a 1.5s tween, never an instant cut. Vibrant = saturated albedo +
emission on + light energy up + particles on. Dormant is the default at
scene start, including the castle.

Keyboard (D): `1`=castle `2`=mind `3`=heart `4`=creator toggle that island,
`0`=all dormant, `9`=all vibrant. Debug UI is a small `Control` panel,
top-left, that can be hidden with `H`.

## Performance budget

Whole scene: keep under ~150k tris and ~250 draw calls. Motes: one
`GPUParticles3D`, <=400 particles, additive, no collision, no shadows.
Islands use low-poly primitives — `SphereMesh` with low segments,
`CylinderMesh`, `BoxMesh`, `PrismMesh`. No shadow-casting lights except the
single directional sun A owns.

## Build status (all phases complete)

Every file below is implemented and verified. The measurements here were
taken from the finished scene, not predicted.

| System | File | Verified |
|---|---|---|
| Sky/fog/sun/motes, bob, orbit camera | `sky_isles_world.gd` | renders; motes visible |
| Shared island geometry | `isle_builder.gd` | used by all four islands |
| Castle + Grand Station + GALLERY_ANCHOR | `isle_castle.gd` | 6 materials, 4 emissives, 4 lights, 1 particle system |
| Mind / Heart / Creator | `isle_kingdoms.gd` | three inner classes, one `Isle_*` node each |
| 3 rails + pillars + trains | `rail_network.gd` | curve lengths 118.7 / 113.6 / 70.6, train on each |
| Click-to-travel camera ride | `travel_controller.gd` | all 3 legs arrive at distance **0.000** |
| Dormant/vibrant swap | `isle_state.gd` | 15/19 sampled properties change on toggle |
| Debug panel + keys | `debug_panel.gd` | on-screen, live state per island |

Whole scene: **143 MeshInstance3D, 18,078 verts** — far inside the
~150k tri / ~250 draw call budget.

### Gotchas that cost real time here — do not reintroduce

1. **Never use `get_tree().current_scene`.** It is null whenever the scene
   is instantiated manually (test harnesses, loading screens, sub-viewports)
   and silently breaks every lookup downstream. Use
   `owner if owner != null else get_parent()` and search recursively —
   kingdom islands are nested under `Isles2`, so a direct-child lookup finds
   only the castle.
2. **Warnings are errors for type inference.** Never `:=` on anything the
   compiler sees as Variant: `get_meta()`, untyped Array/Dictionary reads,
   `load()`, `lerp()`. Type them explicitly and use `lerpf()` for floats.
3. **`class_name` is not reliable from inner classes.** Reach `isle_builder`
   via `load("res://scripts/sky_isles/isle_builder.gd")`, as the islands do.
4. **A headless `SceneTree --script` does not tick at 60fps.** Timing a
   4-second ride by frame count times out spuriously; wait on the
   `travel_finished` signal with a wall-clock cap instead.

## Verify your own work

Headless smoke test — must exit clean, no errors:

```
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless \
  --path /Users/davidsovann/GAME/artea \
  res://scenes/sky_isles.tscn --quit-after 180 2>&1 | tail -40
```

Treat any `SCRIPT ERROR`, `Parse Error`, or `Cannot open` as a failure to
fix before reporting done. `ObjectDB instances were leaked at exit` is
pre-existing in this project and is not your bug.
