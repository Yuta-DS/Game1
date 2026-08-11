# Artéa Castle Universe implementation

The Castle Universe is implemented directly in the existing Godot 4 hub scene,
not as a separate React/Three.js application. This keeps the work inside the
game's player, camera, progress, portal, terrain, and scene systems.

## Runtime systems

- `hub_lumen_citadel.gd`: floating castle foundation, supports, gallery anchor,
  living brass/crystal machinery, and castle dormant/vibrant state.
- `hub_sky_isles.gd`: Mind Spark, Heart Melody, and Creator's Light islands,
  walkable floors, distinct terrain/landmarks, idle bob, and independent states.
- `hub_skyrail.gd`: Grand Station, three curved supported rails, and three
  color-coded detailed magitech trains.
- `hub_train_rider.gd`: visible six-pad two-way boarding system and scenic rides.
- `hub_atmosphere.gd`: one low-count additive aether-mote particle field.
- `teleport_Art_Gallery.gd`: castle-following Gallery door trigger and lit frame.
- `hub_castle_entrance.gd`: the front courtyard (15 x 19 paved landing with a
  flagstone grid, parapets and merlons, an aether fountain on the door axis
  with a hovering crystal core in a rotating brass armature, hedged planters,
  benches, standing braziers, flanking gatehouse towers with brass gear bands
  and red roofs, rune arch with keystone crystal, lamp posts, swaying sigil
  banners, threshold seal) and the arrival point the player is returned to
  when leaving the gallery.

### The approach is tiered

A single flat deck meant the player stepped off the causeway and walked on the
level straight to the door — nothing was revealed, and the courtyard read as a
platform with props on it. The approach is now three parts, measured outward
from the door:

| range | piece |
| --- | --- |
| `0 .. UPPER_LENGTH` (8.4) | upper court, at the door's own level |
| `+ GRAND_STAIR_RUN` (3.4) | ceremonial stair, `UPPER_RISE` 2.2 m |
| out to `PLAZA_LENGTH` (24.0) | arrival terrace, where the causeway lands |

What each layer contributes:

- **Colonnade** — four columns per side down the upper court, each with plinth,
  tapered shaft, brass collar, capital, a hanging caged aether lamp, and a
  lintel spanning to its neighbour. This was the single biggest miss: without
  vertical elements repeating along the walk, the eye had nothing to travel
  along and the court was a floor with objects on it.
- **Grand stair** — wide shallow flight, glowing cyan tread inlays echoing the
  spiral stair, solid brass-capped cheek walls, and newel piers at the foot
  carrying hovering violet orbs.
- **Substructure** — battered skirts under both decks, corbels along the
  overhang, and levitation anchors (brass ring + crystal) under the terrace.
  The decks previously ended in a razor edge with open sky beneath.
- **Balustrades** — merloned parapet on the upper court; open baluster rail on
  the terrace so the view out over the kingdom is not walled off.
- **Fountain** — on the *terrace*, not the upper court. Centred on the upper
  court it stood squarely between the stair head and the doorway, so the player
  had to walk around their own centrepiece and it hid the door on the climb.

`DOOR_LEVEL` anchors everything belonging to the doorway (gatehouse, arch,
banners, lamps, threshold seal) so changing `UPPER_RISE` moves them together.

### The route must be continuous

The walk from the ground to the door crosses two independently-built systems:

```
spiral stair -> crown deck -> causeway -> arrival terrace
  -> grand stair -> upper court -> door
```

Two joins broke because the systems share constants by duplication:

- **Crown deck vs terrace.** The tower top was derived from `CASTLE_BASE_Y`,
  finishing at y 65.4 against a terrace at 68.9 — a 3.5 m wall at the top of
  the spiral stair with no way up. `top_y` now comes from `TERRACE_DECK_Y`.
- **Causeway slope.** It ran from the tower deck up to the *door's* height,
  which after the tower moved meant a 3.5 m climb across a mostly-sideways
  span: a steep diagonal that read as loose planks hanging in the air. Both
  ends now sit at `TERRACE_DECK_Y`, so it only crosses the gap.

It also gained a **launch platform** where it leaves the tower (the first plank
previously started half a segment out, leaving an open hole) and a **continuous
roadbed slab** under the segmented planks, so the walking surface is one
unbroken collider instead of twelve boxes with seams between them.

The crown deck gained a **gateway** — two lantern-topped piers and a brass
lintel — at the point the causeway leaves it. Reaching the top of a 30 m spiral
and finding an unmarked octagon with a walkway running off one edge gave the
player nothing to aim at; the piers turn that edge into a doorway so the route
still reads as a route. The opening is 3.65 m clear against a 4.8 m causeway,
which frames the exit without pinching a 1.0 m player capsule.

`test_approach_continuity.gd` asserts all of this: deck-to-terrace step within
the controller's 0.65 m limit, causeway overlapping the courtyard edge, the
span level rather than ramped, and real collision along it.

### Courtyard sizing

`PLAZA_LENGTH` / `PLAZA_WIDTH` are load-bearing for two other systems, and
nothing enforces it automatically:

- `hub_castle_stairs` re-declares `PLAZA_LENGTH` and `TERRACE_DECK_Y` so the
  causeway stops at the courtyard edge, at its height. Growing or raising the
  courtyard without updating them leaves the causeway short or at the wrong
  level.
- `TOWER_OFFSET` must keep the stair tower outside the courtyard footprint.

At the current 24 m length the courtyard runs x -39.8 .. -15.8 and the tower
stands at -11.4. `PLAZA_LENGTH` covers *both* tiers plus the stair — at 15.0
the terrace was left only 3.2 m deep, too cramped to arrive on and far too
small for the fountain it carries.

## The Lens of Seeing (viewfinder mechanic)

Real-time world cutting, ported from the technique studied in
`ViewFinder.txt`. The player frames part of Artéa, carries what they saw, and
places it somewhere else — genuine runtime mesh surgery, not a shader trick
and not a portal.

### The story it tells

The three kingdoms each make the same claim about the player's inside world: a
thought can be looked at and changed, a feeling can be given a voice, a thing
can be made that did not exist. The Lens makes that claim about the world
*outside* them, so the player discovers it by doing rather than being told:

> what you notice in one place, you can carry, and make true in another.

Two rules follow from that, and both are enforced in code:

- **The player never loses Artéa.** Capture hides the source prop and restores
  it on placement; `release()` cancels a held seeing; `restore_world()` removes
  committed runtime fragments and returns displaced authored props. A child or
  facilitator always has a route back to the authored world.
- **The Crown of Life is not gated on the Lens.** Completing a bridging grants
  the `perception` strength and is counted in `JourneyState.bridgings`, but the
  finale still turns on the three kingdom treasures alone. Perception is
  offered as a fourth strength to discover, never a toll on the ending.
  `test_lens_journey.gd` asserts a player who never touches the lens is still
  crowned.

The ceremony speaks it under the same evidentiary rule as every other line —
"you saw what was missing and carried it there yourself", cited from a real
count, never flattery.

### Files

| file | role |
| --- | --- |
| `viewfinder/mesh_cutter.gd` | one plane, one mesh: split and cap both halves |
| `viewfinder/frustum_cutter.gd` | four frustum planes + broad phase |
| `viewfinder/viewfinder_lens.gd` | capture / place / release |
| `viewfinder/lens_journey.gd` | story layer, guardian lines, journey record |
| `viewfinder/lens_persistence.gd` | saving placements by replaying the cut |
| `viewfinder/hub_lens.gd` | hub wiring: finds the player, tags cuttable props |
| `viewfinder/lens_controller.gd` | player input, viewfinder HUD |

### Decisions that differ from the source material

- **GDScript, not C#.** `ViewFinder.txt` §6 recommends C# for the numeric
  loops. Artéa has *zero* C# gameplay code, and `Artea.csproj` targets net8.0
  against a locally-installed SDK 10 — an unverified build path. Adding one to
  a ~160-file GDScript project costs more than it buys while the cuttable set
  is low-poly props. `MAX_CUTTABLE_TRIANGLES` (4000) enforces that assumption
  rather than leaving it as a hope: an over-budget mesh is refused, not
  slowly chewed through.
- **No three-frame trigger hack.** The original enables collider triggers and
  waits three frames for `OnTriggerEnter`, which depends on physics tick
  timing and is the mechanic's biggest fragility. `overlapping_bodies()` uses
  `intersect_shape()` and answers in the same frame, deterministically.
- **Analytic edge intersection**, not `Plane.intersects_ray` — faster, and no
  null case to guard (§6.3).
- **Cap UVs use a real orthonormal basis.** The original computes
  `left = cross(normal, normal)`, which is always zero, pinning every cap UV's
  u coordinate to 0.5. `test_mesh_cutter.gd` asserts cap UVs actually vary.

### Known limitation

`_add_cap` sorts seam points by angle around their centroid and fans from
there. That is correct for a single convex loop and wrong for a cut producing
**multiple disjoint loops** — slicing a torus, or any prop with a hole through
it, will bridge between the loops. Acceptable for the intended cuttable set
(solid low-poly props); it is the first thing to revisit if a holed prop is
ever made cuttable.

### What must never be made cuttable

Layer 4 (`Cuttable`) is opt-in per prop, and deliberately so:

- **Terrain3D** meshes are streamed clipmaps — slicing them fights the addon.
- **ProtonScatter / MultiMeshSpawner** output is `MultiMesh`, which has no
  per-instance mesh to cut at all.

`test_frustum_cutter.gd` asserts a prop off the Cuttable layer is ignored by
the broad phase, so the mechanic cannot slice scenery it was never meant to
touch.

### Fragments are bodies, not meshes

Every fragment is a `StaticBody3D` carrying its mesh and a `CollisionShape3D`.
Bare `MeshInstance3D` fragments render perfectly and are walked straight
through, so a placed seeing looked solid and was not — the mechanic produced
scenery rather than world.

Collision is **trimesh, not convex**. Cut pieces are routinely concave: an
L-shaped corner left after the frustum bites a notch out of a wall is the
normal case, not the exception. A convex hull fills that notch in and lets the
player stand on air — `ViewFinder.txt` R3, which the original inherits by
using convex everywhere. Trimesh is exact and is only valid on static bodies,
which is what fragments are.

Fragments keep the `Cuttable` layer, so a placed seeing can be re-framed and
carried onward instead of becoming permanently inert.

**Held seeings are intangible.** A captured seeing rides inside the player's
own capsule; live collision there would trap them. Both the fragment and the
suppressed source prop disable their shapes *directly* rather than with
`set_deferred` — a deferred disable stays live for one more frame, which is
long enough to shove the player and long enough for a prop that has visibly
vanished to still block them.

### Seeings, turning, and depth of field

- **`MAX_SEEINGS` (5)** — a limited resource makes each framing a decision
  rather than something to spam. Unlike the original it is *refunded* on both
  place and release, so a child can never spend every seeing and reach a state
  where the puzzle is unsolvable, and cancelling never quietly costs them one.
- **`rotate_held()`, bound to `T`** — turns in 30° steps about the view axis,
  matching the original's film rotation. The whole seeing turns as one rigid
  object about the capture point; rotating each fragment about its own centre
  would tear a multi-fragment seeing apart.
- **Depth of field** while the lens is raised, via a `CameraAttributesPractical`
  swapped in and out. The scene's own attributes are stored and restored, never
  overwritten. The blur is the cue that the next click will change the world.

The on-screen counter appears only while the lens is raised — a resource
readout during ordinary play is noise.

### Placements survive a reload

A placed seeing is runtime geometry with no source asset. `ViewFinder.txt` §R5
offers two options; this saves the **cut**, not the mesh: two player poses and
a turn count, about 100 bytes, replayed through the same public
`capture()`/`place()` API the player drives. Serializing fragments would be
tens of kilobytes each and would rot the moment the cutter changed.

The consequence worth knowing: replay is faithful only while the underlying
props are unchanged. If a prop moves between sessions the restored placement
follows the prop, not the old pixels. For an authored world that is right; it
is still a real difference from storing geometry.

Failure modes are all soft, because this must never cost more than the
placements themselves: a corrupt file loads as empty, malformed records are
dropped rather than replayed as garbage transforms, and a stale record whose
prop is gone is skipped without aborting the rest of the list.

### In the hub

`HubLens` is a node in `New_Hub_World.tscn` running `hub_lens.gd`. It finds the
player through the `player` group, hangs the controller off their **camera**
(so a held seeing follows where they look, not just where they stand), and tags
cuttable props.

Tagging is opt-in and narrow — currently `Environment/mountains`, which are
`.glb` rock instances with real mesh geometry and their own collision. It
**adds** the Cuttable bit rather than replacing the layer, or the player would
fall through the mountains. Props over the triangle budget are skipped at
tagging time, so the player never frames something that turns out to be
uncuttable at the shutter.

The lens is gated on `UNLOCK_STAGE` (1): the three kingdoms come first, since
the Lens generalises what they teach and handing it over earlier gives the
player a tool with nothing to say.

`test_hub_lens.gd` loads the real hub and asserts all of this, including that
no `Terrain3D` or `MultiMeshInstance3D` node ever carries the Cuttable layer.

### Reach and framing

`CAPTURE_DISTANCE` is **9 m** and the lens cuts against its own camera at
`LENS_FOV_SCALE` (0.62) of the player's FOV. Both numbers are about feel as
much as cost:

- Cost is O(triangles in the frustum) × 4 cuts, so a far plane at Artéa's
  usual draw distance would try to cut the whole level (`ViewFinder.txt` R1).
- At the first-attempt 18 m with a 70° camera the far plane was ~25 m across.
  The screenshot of that build showed **every prop in the room vanishing at
  once** — the lens read as a vacuum, not as framing, and the player had no
  sense of choosing anything.

The on-screen frame's `FRAME_INSET` is *derived* from `LENS_FOV_SCALE` rather
than picked by eye, so the drawn frame always matches the cone actually cut. A
frame that does not match what gets taken is a lie told to the player.

### Looking at it

```sh
# play it
Godot --path artea res://scenes/viewfinder/lens_demo.tscn
# or capture before/after stills to artifacts/
Godot --path artea --script res://scripts/capture_lens_demo.gd
```

`lens_demo.gd` builds a room of box / sphere / cylinder / prism props — four
different topologies, because the cutter behaves differently on flat faces,
many straddling triangles, and curved sides against flat caps. It depends on
no autoload, no hub and no player scene, so a cutter regression can be
reproduced without loading the game.

This is not optional polish. The headless suites cannot see inside-out faces,
an unlit cross-section, or a fragment that renders as a black hole — and the
"lens takes the whole room" problem above was invisible to every assert and
obvious in the first screenshot.

## Faith and universal audience modes

ARTÉA is built on a Christian foundation and **faith mode is the default** —
the authentic voice of the project, not a feature to switch on. Universal mode
exists because the same game runs in schools and community programs where
presenting explicit faith language to someone else's children may not be
appropriate.

**Only the naming register changes.** The guardians keep their role, their
warmth, and every word of the message about being known, valued, and uniquely
made. The Keeper of Wisdom says what the Everlasting Father says.

| faith | universal |
| --- | --- |
| Everlasting Father | the Keeper of Wisdom |
| Archangel Raphael | the Keeper of Healing |
| Uriel | the Keeper of Creativity |
| Prince of Peace | the Keeper of Peace |
| Archangel Gabriel | the Guide of Artéa |
| The Maker (finale) | Milo (finale) — already handled in `gallery_ceremony.gd` |

Milo has no variant: his lines carry no faith naming, so he is already correct
in both modes. Adding a duplicate would be two copies to keep in sync for no
gain.

### How it resolves

`GameManager.resolve_audience_node()` prefers a `<node>_universal` twin when
`JourneyState.audience_mode == "universal"`, and falls back to the authored
node when no twin exists. Same shape as the existing `_milo_variant()` seam,
so authoring no universal node for a scene is safe — it simply plays the faith
text.

It is called from `run_dialogue()`, **not** `start_dialogue()`. `=>` jumps and
choice targets re-enter through `run_dialogue`; resolving only at conversation
entry would speak the first line as the Keeper and every following line as the
angel.

Island plaques (`hub_sky_isles.gd`) carry a `guardian_universal` field beside
`guardian`, picked at the single render site by `_guardian_label()`.
`refresh_audience_mode()` re-texts them when a facilitator switches mid-session,
since plaques are built once in `_ready()`.

### What must never differ

Progression, treasures, strengths, and rewards are identical in both modes.
`JourneyState` enforces this structurally by **never reading
`audience_mode`** — no code path can gate a discovery on the setting.
`test_audience_mode.gd` runs the same actions through both modes and asserts
the resulting treasures, strengths, and stage match.

### The facilitator control

`facilitator_settings.gd`, opened from the "Setup" button. Deliberately plain
and text-led so it does not read to a child as something to go and play with.

### Safeguard buttons

`JourneySafeguards` documented an "always-visible button pair" that **did not
exist** — nothing in the game called `show_support()` or
`show_journey_privacy()`, so the crisis card was unreachable from every scene.
`_build_buttons()` now builds that row (Need help / My journey / Setup) in the
autoload itself, so no scene can ship without it. "Need help" is first: in a
moment of distress it must not be the button the player has to hunt for.

## Leaving the gallery

`change_scene_to_file` rebuilds the hub from disk, so the player was always
placed at the hub's authored start position — ground level, across the map from
the castle they had just walked out of.

`Global.pending_spawn_point` now carries the intent across the swap:
`ExitGallery.gd` calls `Global.request_spawn_at("castle_front_door")`, and
`hub_castle_entrance.gd` consumes it once in `_ready()` and places the player on
the plaza facing out. Consuming clears it, so a normal entry to the hub still
uses the authored start position.

`ExitGallery.gd` also pointed at `res://New_Hub_World.tscn`, which does not
exist (the scene lives in `res://scenes/`), so the exit previously logged
"target scene file not found" and did nothing at all.

## Debug controls

In a debug build:

- `F5`: toggle Castle
- `F6`: toggle Mind Spark
- `F7`: toggle Heart Melody
- `F8`: toggle Creator's Light
- `F9`: toggle all three kingdoms

The existing number keys still preview the journey-wide stage progression.

## Verification

Four focused suites, all passing:

```sh
G=/Applications/Godot_mono.app/Contents/MacOS/Godot
$G --headless --path artea --script res://scripts/test_transit_scripts.gd
$G --headless --path artea --script res://scripts/test_castle_entrance.gd
$G --headless --path artea --script res://scripts/test_hub_entrance_in_scene.gd
$G --headless --path artea --script res://scripts/test_train_rides.gd
$G --headless --path artea --script res://scripts/test_audience_mode.gd
$G --headless --path artea --script res://scripts/test_audience_resolver.gd
$G --headless --path artea --script res://scripts/test_mesh_cutter.gd
$G --headless --path artea --script res://scripts/test_frustum_cutter.gd
$G --headless --path artea --script res://scripts/test_viewfinder_lens.gd
$G --headless --path artea --script res://scripts/test_lens_journey.gd
$G --headless --path artea --script res://scripts/test_lens_controller.gd
$G --headless --path artea --script res://scripts/test_lens_collision.gd
$G --headless --path artea --script res://scripts/test_lens_persistence.gd
$G --headless --path artea --script res://scripts/test_hub_lens.gd
```

- `test_transit_scripts.gd` — every transit script parses, and the
  rail/rider `get_ride_lift()` seam exists.
- `test_castle_entrance.gd` — the entrance builds geometry and collision, the
  arrival point is on the plaza, and the `Global` spawn handoff is one-shot.
- `test_hub_entrance_in_scene.gd` — the same checks inside the real hub, plus
  both vegetation roots visible with grass items present.
- `test_train_rides.gd` — six stations, boarding pads that track their bobbing
  island, and a full out-and-back ride that lands on both pads with the
  player's physics restored.
- `test_rail_clearance.gd` — no rail passes through the castle, and the
  station sits outside its foundation.
- `test_approach_continuity.gd` — the ground-to-door route has no unwalkable
  step, no gap at the causeway/courtyard join, no ramped span, and collision
  everywhere the player stands.
- `test_audience_mode.gd` — every faith node has a universal twin, no universal
  node reintroduces faith naming, the guardian labels keep their keeper role,
  and (the one that matters) both modes award identical treasures, strengths,
  and stage.
- `test_mesh_cutter.gd` — the cutter alone, no camera or physics: halves never
  leak across the plane, volume is conserved (which only holds if both halves
  are watertight), caps lie in the cut plane with opposing normals and varying
  UVs, materials survive, an over-budget mesh is refused, and null/empty/
  normal-less meshes are handled instead of crashing.
- `test_frustum_cutter.gd` — in a live physics scene: all four planes face
  inward, the shape query finds only Cuttable bodies, a prop wider than the
  frustum leaves geometry both inside and outside, and props behind the camera
  or past the capture distance are untouched.
- `test_viewfinder_lens.gd` — capture/place/release, with reversibility as the
  headline property: an empty frame is refused with a reason, the source is
  hidden while held and restored on both place and release, and a second
  capture while holding is refused.
- `test_lens_journey.gd` — bridgings are counted and survive save/load, a
  wipe erases them, the two audience registers carry the same lesson under
  different names, and (the one that matters) the Crown is reachable with zero
  bridgings.
- `test_lens_controller.gd` — the controller's lens, story layer and HUD are
  actually wired to each other, and a capture-then-place completes a bridging
  end to end.
- `test_lens_collision.gd` — fragments are bodies with trimesh shapes, a held
  seeing is intangible, a ray fired into placed geometry actually hits it, the
  seeing counter spends and refunds, and turning a seeing keeps every fragment
  rigid relative to the others.
- `test_lens_persistence.gd` — placements round trip, and the failure modes
  degrade softly: a corrupt file loads empty, malformed records are dropped,
  and a stale record does not cost the player the placements still valid.
- `test_hub_lens.gd` — loads the real hub: the controller reaches the player's
  camera, tagging finds real props and preserves their original collision
  layer, and no Terrain3D or MultiMesh node is ever cuttable.
- `test_audience_resolver.gd` — faith mode never redirects, universal mode
  never resolves to a node that does not exist, missing twins fall back,
  already-universal nodes are not suffixed twice, and jump targets resolve.
  Mirrors `resolve_audience_node`'s rules rather than instantiating
  `GameManager`, which preloads scenes that reference autoload singletons
  unavailable in a `--script` run.

Measurement helpers (not assertions — they print what the live scene contains):
`probe_castle_door.gd`, `probe_entrance_placement.gd`,
`probe_causeway_clutter.gd`.

Visual check (writes to `artifacts/`):

```sh
$G --path artea --script res://scripts/capture_castle_universe.gd
```

`test_castle_universe.gd` (the older whole-world suite) does not currently
finish: after the hub it loads the Art Castle gallery scene, which pulls in the
local LLM and audio and runs past a several-minute budget. That is why the
checks above are split into scene-scoped suites. Its first assertion also fails
on the unmodified baseline, so it needs separate attention.

Generate the two visual inspection captures:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot \
  --path artea --script res://scripts/capture_castle_universe.gd
```

The focused world-layer budget measured in the integration test is:

- 694 low-poly mesh instances
- 20,472 triangles
- 16 local lights (all traversal/detail lights are unshadowed)
- 84 ambient particle quads in one particle system

The mesh-instance count is driven mostly by individually collidable castle stair
treads and safety rails; triangle cost remains low. The existing full hub still
emits asset UID/mipmap and Proton Scatter warnings that predate this work.

## Debug log

- The Gallery trigger was measured at Y=37.2 while the castle mesh begins at
  Y=65.5. It now follows the imported door's local anchor each frame.
- The Gallery Area serialized a `body_entered` connection and connected it again
  in `_ready()`. Signal connection is now idempotent.
- Castle bridge boxes were aimed along local Z and then rotated another 90°,
  standing every plank upright. The redundant rotation and 28% endpoint gap were
  removed; the target is now the actual door face.
- Station proximity flattened only the player Y coordinate, leaving station Y in
  the distance calculation. Both positions are now compared in X/Z.
- Ambient train animation and ride tween both wrote the train transform. Each
  line now grants exclusive transform ownership to the rider while occupied.
- All rails originally started at an unrelated low village/gallery coordinate.
  They now start at three physical docks in the castle's Grand Station.
- Island materials were originally stored in global arrays, making independent
  state changes impossible. Each island now owns its material/spinner set.
- Initial distance fog flattened the castle into a pink silhouette from scenic
  angles. Density/energy were reduced and local unshadowed fill lights now keep
  the castle, station, and vibrant island faces readable against the bright sky.
- `_place_on_curve` fed curve-LOCAL sample points to `look_at_from_position`,
  which works in global space. Inside the Art Castle galaxy layer (0.5 scale,
  -33 Y offset) that aimed the trains at an arbitrary direction. Both points are
  now converted with `to_global` first.
- The rider read `train.global_position` immediately after `place_train` wrote
  the train's LOCAL position, so the passenger rode a frame-stale transform and
  visibly lagged/clipped through the carriage. Player and train are now derived
  from the same curve sample in the same step, lifted by `get_ride_lift()`.
- Arrival reused island pad positions captured once at build time, but the
  islands bob (`BOB_AMPLITUDE` 0.24), so the player was set down up to a quarter
  metre off the deck. Island pads are now re-resolved every frame, and the pad
  meshes follow their island instead of hanging in the air beside it.
- `_arrive` treated `Vector3.ZERO` as "no landing found", which is a legitimate
  coordinate. Station lookups now return `null` for genuinely unknown.
- `hub_sky_isles.get_platform_pos` computed the dock from the authored `ISLES`
  table, so it reported a fixed height for an island that bobs. Every consumer
  (rail docking, boarding pads, arrival) read a stale Y. It now takes the
  island node's current height.
- `hub_castle_entrance.apply_stage` built a tween before `_ready()` had created
  any materials, raising "Tween started with no Tweeners". It now early-returns
  until there is something to animate, matching `hub_skyrail.apply_stage`.
- The rails started at x = -43.0, inside the castle's 16.5 m foundation
  (centre x = -51.4), so every line was born in the rock and punched out
  through the wall. The station moved clear of both the foundation and the
  door walkway, and `_make_sagging_curve` now leaves the station along a
  radially-outward `DEPARTURE_RUN` before turning — without that,
  `creatorslight` (island at z = -43) bowed back across the castle.
  `test_rail_clearance.gd` locks this in, measuring only inside the castle's
  occupied height band so a rail passing safely over the roof is not flagged.
- The old flat causeway aimed at `CASTLE_DOOR` itself, driving a bare slab
  across the ground the entrance plaza needed. It now stops at the plaza edge
  and carries arched ribs, brass collars and lamps.
- Causeway guard-rail posts and lamp posts were built through `_oriented_box`,
  which `look_at()`s the far end of the span — correct for planks and hand
  rails, but it lays a vertical post over with the slope. They are built
  upright now.
- `teleport_Art_Gallery` set only `global_position` while parented under the
  10x-scaled, rotated castle, so its doorframe boxes inherited that scale and
  rotation. It now rewrites the whole global transform with an identity basis.
- The plaza deck was a single pale slab that clipped to flat white under the
  hub's sun — the "so basic" report. It is a darker `STONE_MID` with an inlaid
  two-tone flagstone grid.
- The spiral stair's parapet was 0.34 m wide with a 0.48 m brass cap on top —
  a cap wider than the wall it sat on, so from any distance the caps floated as
  loose brass sticks and the wall behind them vanished. Outer wall is now
  0.62 x 1.42 with a 0.76 x 0.24 cap.
- Both stair parapets are extruded well past the 0.82 m arc spacing between
  steps so consecutive segments merge into one surface. The inner wall sits at
  a smaller radius, so it needs MORE depth than the outer one to close, not the
  same — matching their depths left visible gaps along the shaft.
- The causeway's 0.18 m guard bars had the same problem and are now a solid
  parapet plus a brass cap, matching the stair.

### Castle door coordinates

`scripts/probe_castle_door.gd` measures the imported castle rather than
inferring it. It reports basis columns X=(0,0,-10), Y=(0,10,0), Z=(10,0,0)
about origin (-51.4, 65.53, 27.41), with the body spanning y 52.3 .. 105.3.

The door anchor (0, 0.38, 1.16) therefore resolves to **(-39.8, 69.33, 27.41),
facing +X**. Both `hub_castle_stairs` and `hub_castle_entrance` use exactly
that constant. An intermediate attempt at -63.0 facing -X came from
transposing the basis and was wrong; the probe script exists so that guess is
never repeated.
- Fragments were bare `MeshInstance3D` with **no collision at all**, so every
  placed seeing was scenery the player walked straight through. They are
  `StaticBody3D` with trimesh shapes now.
- `set_deferred("disabled", true)` leaves a collision shape **live for one more
  frame**. A freshly captured seeing spends that frame inside the player's own
  capsule, and a suppressed source prop spends it solid after visibly
  vanishing. Both are set directly now.
- The **demo room wrote to the player's real journey**. `lens_journey.gd` uses
  the live `JourneyState` autoload, which is right in the hub and wrong in a
  sandbox: opening the demo to check a cut looked correct awarded a real child
  the `perception` strength and a bridging they never made. Gated on
  `record_to_journey`, which the controller drives from its `persist` flag.
- `test_hub_lens.gd` was **flaky, not broken**: the hub's systems each await a
  frame in `_ready()` and `hub_lens` attaches the controller after its own
  await, so a fixed two-frame wait passed most runs and not all. It now waits
  until the controller exists. Verified over three consecutive runs.
- The suites **overwrote the player's real `journey.json`**. `JourneyState`'s
  save path was a `const`, so a test could not redirect it, and `save()`,
  every `record_*` method and `clear_journey()` all wrote to it regardless of
  which instance called them — meaning running the suite destroyed a real
  child's record. `test_journey_state.gd` even documented that it did not do
  this. `save_path` is now instance state defaulting to `SAVE_PATH`, and the
  tests point it at a scratch file they delete afterwards.
  (`test_crown_finale.gd` still uses the live autoload on purpose — it needs
  the real scene — and already backs the file up and restores it.)
- The cutter treated a plane **tangent to a face** as a real cut. A box face
  lying exactly on the plane classifies as "all on-plane", which routes to the
  positive half and leaves the negative half non-empty — so grazing a prop
  sheared off a zero-thickness shell of that face. Emptiness alone cannot tell
  "cut" from "grazed"; `cut()` now tracks whether any vertex genuinely lies
  off the plane on each side.
- `surface_get_arrays()` returns **null, not an empty array**, for a channel a
  surface does not have. Assigning that into a typed `PackedVector3Array` is a
  hard crash, and real `.glb` props do ship without UVs or normals. Every
  channel read is now null-guarded.
- Godot has a built-in `Side` enum (`SIDE_LEFT` etc.). The accumulator class
  was originally named `Side`, which made every type annotation using it a
  parse error. Renamed to `Half`.
- Source meshes are **indexed** — a unit `BoxMesh` is 24 vertices and 36
  indices — so the first version of the test's volume helper walked
  `ARRAY_VERTEX` in threes and measured 0.0 on a solid box. `get_faces()`
  returns the expanded triangle soup for indexed and non-indexed surfaces
  alike. That was a test bug, not a cutter bug, but it would have hidden a
  real one.
- `global_transform` silently reads identity when a node is not yet in the
  tree. Two of the new tests positioned a camera before adding it, so the
  frustum was computed from the wrong pose while still "passing". Transforms
  are now set only after the node is tree-resident.
- `audience_mode` was settable and persisted but only **one line of the game
  read it** — the ceremony's closing in `gallery_ceremony.gd`. A school
  deployment got archangels for all three worlds and then a mode-switched
  final sentence. Every guardian-facing surface now reads it.
- `JourneySafeguards`' docstring described an "always-visible button pair"
  that was never built. `show_support()` and `show_journey_privacy()` had no
  callers anywhere in the project, so the crisis card — the safeguard the
  whole design rests on — could not be opened from any scene.
- `hub_sky_isles._guardian_label` first called `get_node_or_null("/root/...")`
  without an `is_inside_tree()` guard, the exact trap already documented in
  `journey_privacy.gd`. It errored under the test harness and would have
  errored during scene transitions. Guarded, and it falls back to faith naming.
- The gallery guardian was authored **"Price of Peace"** in all five of its
  lines. Fixed to "Prince of Peace"; `test_audience_mode.gd` asserts against
  the typo returning.
- `artea_park_dialogues.txt` is the file actually loaded (`GameManager.gd:17`).
  `HubworldDialogue.dialogue` is stale — it predates the Milo journey nodes and
  is referenced only by a print statement and a commented-out line. Edit the
  park file; the other one is not live.
- Both `Environment/Grass` and `Environment/Objects` were authored
  `visible = false`, and `Grass` carried no `ScatterItem` at all — which is why
  the world rendered bare terrain. Both are visible again and `Grass` now
  scatters two grass meshes plus a bush; the five tree species were already
  configured under `Objects` and only needed to be shown.
