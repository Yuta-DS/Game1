# The Lens of Seeing — real-time world cutting

Artéa's viewfinder mechanic: the player frames part of the world, carries what
they framed, and makes it real somewhere else. This document covers the player
loop, the architecture, what may and may not be cut, the performance envelope,
and how to test it.

Everything lives under `artea/scripts/viewfinder/`. No scene file is edited —
every part of the system builds itself at runtime, the same convention
`hub_magitech.gd` and `gallery_ceremony.gd` follow.

---

## 1. The player loop

Two steps, and one undo.

| Step | Input | What happens |
|---|---|---|
| Raise | `Q` | The Lens of Seeing comes up. The screen gains corner brackets and depth of field. |
| Take | `Left click` | Everything inside the lens frame is cut out, cloned into a held *seeing*, and the world is restored intact. A photo card appears showing what was framed. |
| Turn | `T` | The held seeing rotates −30° about the view axis. The card turns with it. |
| Place | `Left click` | The frame is recomputed where the player now stands, whatever occupies it is removed, and the held seeing drops into the hole. |
| Put back | `Escape` | The seeing is released, the world returns to intact, the seeing is refunded. |

### The fiction

The player is not cutting Artéa up. They are **seeing** — and a seeing, once
held, can fill a gap somewhere else:

> what you notice in one place, you can carry, and make true in another.

That is the same claim the three kingdoms make about thoughts, feelings and
creations, applied to the world outside the player. A gap in the world is not
damage to repair; it is a place where something the player noticed is missing.

Two rules follow from this and are not negotiable:

- **Every capture is reversible.** `Escape` always restores the world. A child
  who frames the wrong thing must never be stuck with a hole they cannot undo.
- **Every committed placement is accounted for.** `restore_world()` removes
  generated seeings and destination offcuts, then restores the authored props.
  This gives facilitators and recovery flows one exact reset path.
- **Seeings are refunded, not consumed.** Taking costs one, placing and
  releasing give it back. The player can never reach a dead end with every
  seeing spent and the puzzle unsolvable. (The original game lets the player
  strand themselves; this is a deliberate softening.)

The Lens is awarded as a fourth treasure (`perception`) for an act the player
performed, and it deliberately does **not** gate the Crown of Life — a child who
never finds it must still be able to finish the journey.

---

## 2. Architecture

```
lens_controller.gd     input state machine (DOWN / RAISED / HOLDING), HUD, DOF
  ├── viewfinder_lens.gd    capture / place / release / restore, fragment state
  │     └── frustum_cutter.gd    broad phase + four-plane frustum cut
  │           └── mesh_cutter.gd     one plane, two capped halves
  ├── lens_photo_card.gd    the frozen seeing, as a Polaroid-like HUD card
  ├── lens_journey.gd       story layer: messages, the perception treasure
  └── lens_persistence.gd   replay placements across a reload

hub_lens.gd            attaches the lens to the hub and decides what is cuttable
lens_demo.gd           a sandbox room for checking cuts look right
```

### `mesh_cutter.gd` — one plane

A plain `RefCounted` with static entry points, no scene presence, no camera, no
physics. This is the piece that can be subtly, invisibly wrong, so it is
testable in complete isolation.

`cut(mesh, plane, cap_material)` returns `{"positive", "negative"}`, either side
`null` if the plane missed. The plane is in the **mesh's own local space** — the
caller transforms the plane once instead of the cutter transforming every vertex,
which is the central performance decision.

Per-surface arrays are kept separate so a multi-material prop keeps its
materials, and the cap is written to its own trailing surface so the
cross-section can take a distinct material. Absent normals are derived as flat
face normals; absent UVs are zeroed. `EPSILON` (1e-5) treats near-plane vertices
as on-plane, so no zero-area slivers are generated.

**Capping.** The seam arrives as an unordered soup of segment endpoint *pairs*.
`_boundary_loops()` welds those endpoints onto a quantised grid (so the two
triangles either side of a source edge agree on one shared vertex) and chains
them into **separate closed loops**. Each loop is then fanned around its own
centroid, wound consistently by a signed-area test in the plane.

This matters: an earlier version sorted every seam point by angle around one
shared centroid. That bridges disjoint loops — slice a torus and the cap becomes
a solid disc spanning the hole, geometry the player can stand on that is not
there. `test_cutter_cap_loops.gd` asserts no cap triangle crosses the torus axis.

Remaining limitation: a centroid fan on a strongly non-convex loop can bulge
slightly outside the true outline. Far smaller an error than bridging, and
correct for the convex-ish seams a frustum cut produces on props.

Only genuinely closed loops are capped. An open or non-manifold seam is left
open rather than inventing an edge between unrelated endpoints; fabricating that
edge creates solid collision where the source mesh had none.

### `frustum_cutter.gd` — four planes

A frustum is the intersection of four half-spaces, so four sequential plane cuts
produce it for free. One prop becomes at most 2⁴ = 16 fragments, each classified
inside or outside by its centroid.

Broad phase is Godot's synchronous `intersect_shape()` against a
`ConvexPolygonShape3D` hull of the frustum's five corner points — answered in the
same frame, deterministically. (The original enables a trigger collider and reads
what collided three frames later, which is the mechanic's biggest fragility.)

Imported GLBs frequently put the visible `MeshInstance3D` above a generated
`StaticBody3D`, not below it. A physics hit is therefore resolved by searching
the collider subtree and then each nearest ancestor subtree. The cutter also
deduplicates by mesh instance, so several generated bodies cannot cut the same
render mesh twice. Source suppression begins at the lowest common ancestor of
the mesh and collider, hiding rendering and collision as one reversible unit.

Each fragment is a `StaticBody3D` carrying a `MeshInstance3D` and a
**`ConcavePolygonShape3D` (trimesh)** collision shape. Trimesh, not convex: a cut
piece is routinely concave — an L-shaped corner left after a frustum bites a
notch out of a wall is the normal case — and a convex hull would fill the notch
in and let the player stand on air. Trimesh is exact and valid on static bodies,
which fragments are. Static rather than rigid because a placed seeing is level
geometry, not debris: it must not settle, roll or fall.

Fragments are themselves on the cuttable layer, so a placed seeing can be
re-framed and carried onward.

### `viewfinder_lens.gd` — the held seeing

The held fragments are **parented to the capture point**, so their transform
relative to the player *is* the photograph. Placement needs no projection maths:
`reparent(keep_global_transform)` bakes the frame-relative pose into world space
and the geometry lands exactly where it was framed, by construction.

While held, fragments are hidden **and intangible** — a seeing rides inside the
player's own capsule, and live collision there would trap them.

Source props are **hidden, not freed**, so placing or releasing restores them
exactly.

### `lens_photo_card.gd` — the frozen seeing

Presentation only. The seeing the player carries is the real geometry above;
this is a picture of it, frozen at the instant of capture.

It has to be frozen *before* the cut, because capture hides the props the player
framed — by the time a HUD could react to the `seeing_captured` signal, the world
no longer contains what was framed. So `freeze()` is a separate call the
controller makes ahead of `capture()`, cropping the viewport image to
`FRAME_INSET`, which is derived from `LENS_FOV_SCALE` and is therefore the exact
region the frustum cuts. The card shows what was taken, not more.

`T` turns the card in the same 30° steps as the geometry, so the picture stays an
honest description of what is held. Placing shrinks the card away as the geometry
becomes real; releasing fades it.

**It must never block a capture.** Headless has no framebuffer, a viewport can
have no texture on the first frame, and `create_tween()` throws outside the tree.
Every one of those paths returns quietly: `freeze()` reports `false`, the card
still appears (holding a plain undeveloped pane, captioned *"A seeing (unseen)"*),
and animated paths fall back to setting their final value directly.

---

## 3. Transaction safety

`capture()`, `place()` and `release()` each rewrite `_held` and `_suppressed`
across many nodes, and are driven straight from a mouse click. A second click
landing inside the first — through a signal handler, a queued input event, or a
child clicking twice fast — would re-enter mid-surgery with half-written state,
and could leave a prop hidden with no seeing to restore it: **a permanent hole in
the world.**

So:

- `viewfinder_lens._busy` guards all three. A call arriving while one is running
  is refused outright, before any state is touched.
- The flag is cleared on **every** exit path, and cleared *before* the completion
  signals fire — a listener that captures in response is doing something
  legitimate and must not be refused by the call it is reacting to.
- `lens_controller._acting` guards the gesture as a whole, covering the photo-card
  work that happens either side of the lens call.
- Every refusal leaves sources visible and solid, temporary fragments freed, held
  state consistent, and the guard clear. A refusal that half-performs the cut is
  worse than a crash, because it looks like nothing happened.
- `release()` with nothing held is a no-op, not a refund — Escape pressed twice
  must not mint a seeing.

**Collision toggling is recursive.** An imported `.glb` prop is a whole subtree:
Godot's generated `StaticBody3D` sits under the mesh node, which sits under the
scene root. A direct-children-only walk found no shapes at all and left the prop
solid after it had visibly vanished, so the player collided with a hole.
`_set_shapes_disabled()` walks the entire subtree. Shapes are disabled directly,
not deferred — a deferred disable leaves a freshly captured seeing solid inside
the player's capsule for one frame, long enough to shove them.

---

## 4. Cuttable authoring contract

Cutting is **opt-in per prop** and must stay that way.

A cuttable prop must:

1. Sit on **collision layer 8** (`Cuttable`, `CUTTABLE_MASK` in
   `frustum_cutter.gd`). Add the bit, never replace the layer — these props are
   usually world collision the player already walks into.
2. Have a real `MeshInstance3D` with an `ArrayMesh` somewhere at or under the
   body, or in the nearest imported-scene ancestor subtree. Collider-to-mesh
   resolution handles both common GLB layouts.
3. Be **under 4000 triangles** (`MeshCutter.MAX_CUTTABLE_TRIANGLES`).
4. Be safe to hide, cut and restore — nothing else may depend on its transform or
   its continued existence.

`hub_lens.gd` is the reference implementation of the tagging policy:

- `CUTTABLE_ROOTS` — subtrees whose children are considered (`Environment/mountains`).
- `CUTTABLE_PREFIXES` — top-level props by name prefix (`building_`).
- `NEVER_CUTTABLE` — explicit exclusions, whatever else matches.
- Over-budget props are skipped **at tagging time**, so the player never frames
  something that turns out to be uncuttable at the shutter. A refusal that only
  appears after framing reads as the mechanic being broken.

### Never cuttable

| Excluded | Why |
|---|---|
| **Terrain3D** | A streamed clipmap. There is no per-instance mesh to cut. |
| **ProtonScatter output** | `MultiMesh` instances share one mesh; there is nothing per-instance to replace. |
| **`building_castle_red2`** (hub castle) | The Castle Universe's anchor. `hub_lumen_citadel`, `hub_castle_crown`, `hub_castle_entrance`, the Gallery door trigger and the skyrail station all attach to it or measure from it. Slicing it would take the finale down with it. It is also over budget, but the refusal must be intentional and not a coincidence of its poly count. |
| **Trains and rails** | Excluded by omission — they are moving, scripted, and pathed. |

The exclusions are by omission, not by blocklist: nothing is cuttable until
something tags it.

---

## 5. Performance limits

| Limit | Value | Where |
|---|---|---|
| Triangles per cuttable mesh | 4000 | `MeshCutter.MAX_CUTTABLE_TRIANGLES` |
| Broad-phase results per query | 32 | `FrustumCutter.MAX_OVERLAPS` |
| Capture reach | 9 m | `ViewfinderLens.CAPTURE_DISTANCE` |
| Lens FOV vs. player camera | 0.62 | `ViewfinderLens.LENS_FOV_SCALE` |
| Seeings held at once | 1 | `viewfinder_lens.capture()` |
| Seeing budget | 5 | `ViewfinderLens.MAX_SEEINGS` |
| Fragments per prop | ≤ 16 | four sequential plane cuts |

Cost is O(triangles overlapping the frustum). The reach is short on purpose: at
18 m with a 70° camera the far plane is ~25 m across, which swallowed a whole row
of props at once and gave the player no sense of choosing anything. 9 m keeps the
frame around what they are actually looking at — and keeps the cut affordable.

This is GDScript, not C#. Artéa has no C# gameplay code, and adding a build step
to a ~160-file GDScript project costs more than it buys while the cuttable set is
low-poly props. The triangle budget enforces that assumption rather than leaving
it as a hope.

---

## 6. Testing

```bash
GODOT=/Applications/Godot_mono.app/Contents/MacOS/Godot

# Preferred: all 11 suites, bounded and with script-error detection
bash artea/scripts/run_viewfinder_tests.sh

# The cutter, in isolation — no camera, no input, no physics
$GODOT --headless --path artea --script res://scripts/test_mesh_cutter.gd
$GODOT --headless --path artea --script res://scripts/test_cutter_cap_loops.gd

# The frustum and the fragments
$GODOT --headless --path artea --script res://scripts/test_frustum_cutter.gd
$GODOT --headless --path artea --script res://scripts/test_lens_collision.gd

# The lens, restoration safety, the guard, and the HUD
$GODOT --headless --path artea --script res://scripts/test_viewfinder_lens.gd
$GODOT --headless --path artea --script res://scripts/test_lens_safety.gd
$GODOT --headless --path artea --script res://scripts/test_lens_photo_card.gd
$GODOT --headless --path artea --script res://scripts/test_lens_controller.gd

# Story, persistence, hub integration
$GODOT --headless --path artea --script res://scripts/test_lens_journey.gd
$GODOT --headless --path artea --script res://scripts/test_lens_persistence.gd
$GODOT --headless --path artea --script res://scripts/test_hub_lens.gd
```

What each of the newer ones is actually asserting:

- **`test_cutter_cap_loops.gd`** — a torus cut produces two seam loops, capped
  independently: distinct fan apexes, no cap triangle crossing the axis
  (the bridging bug), consistent per-loop winding, and a box's single loop still
  sealing to a conserved volume.
- **`test_lens_safety.gd`** — a capture attempted from inside the capture signal
  is refused; every refusal leaves sources visible and solid; `_busy` never
  sticks after success, refusal or no-op; a double release refunds once; a
  deeply nested `.glb`-shaped prop's collision shape is disabled when hidden and
  restored when released.
- **`test_lens_photo_card.gd`** — `freeze()` fails safely headless and the card
  still shows; the lifecycle survives any call order, including out of the tree;
  rotation tracks the geometry's 30° steps; and the controller takes the card
  down on placement.

`test_lens_photo_card.gd` asserts it is running headless — it is testing the
no-framebuffer path deliberately, so run it with `--headless`.

The complete-hub suite loads native Terrain3D/Firebase add-ons. On macOS those
can keep Godot alive after the test calls `SceneTree.quit()`. The runner waits for
the hub suite's terminal success marker, rejects script/assertion errors, and
then stops only the Godot process it launched so local and CI runs remain
bounded.

---

## 7. How the frozen image relates to the real geometry

Worth being precise about, because they are easy to confuse:

- **The seeing** is real geometry: capped `ArrayMesh` fragments in
  `StaticBody3D`s with trimesh collision, parented to the capture point. This is
  what gets placed. Placement is exact because of that parenting.
- **The card** is a cropped screenshot taken a moment before the cut. It is
  never projected, never used to compute anything, and never touches physics.

The card is *honest but not authoritative*. It is cropped to the same
`LENS_FOV_SCALE` cone the frustum cuts, so it shows the right region, and it
turns in the same 30° steps, so it shows the right orientation. But it is a flat
image of one moment: it does not update as the player walks, and the geometry
behind it is what actually lands. If the two ever disagree, **the geometry is
right and the card is stale** — which is why the card is retired the instant the
seeing stops being held (`_refresh()` reconciles it against `is_holding()`
regardless of how state got there, including a persistence replay).

If the card cannot be produced at all, the mechanic is unaffected.

---

## 8. Study references

The technique was studied from, and reimplemented for Godot rather than
transliterated:

- **ToughNutToCrack**'s ViewFinder devlog (video `rdExK08zYBI`) and its Unity
  source — the frustum-as-four-planes cut, the parent-to-camera "photo" data
  structure, the Polaroid state machine and the photo counter as a puzzle
  constraint.
- **Kristin Lague**'s Mesh-Cutting, which TNTC's cutting core derives from — the
  per-triangle plane classification and edge-intersection split.
- **Sam Barlow / Logan Preshaw's _Viewfinder_** (Thunderful, 2023), the
  commercial game the technique imitates.

Full study notes, including the specific things that had to change for Godot and
for a children's game, are in `/Users/davidsovann/GAME/ViewFinder.txt`.

Departures worth naming: synchronous `intersect_shape()` instead of a
three-frame trigger read; trimesh instead of convex fragment collision; local
loop-reconstructed caps instead of a single angular fan; a non-degenerate
orthonormal cap basis (the original's degenerate cross product pins cap U at
0.5); refunded rather than consumed seeings; and no player-freeze during the
operation.
