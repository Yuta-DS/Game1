# Mind Spark — lasting visual style and implementation standard

Version 1.3 · 13 September 2026

## Purpose and authority

Use this document as the canonical reference for future Mind Spark environment,
architecture, quest-object and visual-feedback work. It records the user's
direction and a proposed implementation method; it is not a claim that the
current assets have passed final art review.

The direction is **warm, heavenly, luxurious, stylized low-poly**, with the clean
readability of polished idle-game objects. Ivory architecture encloses elegant
brass machinery; purposeful movement makes each puzzle understandable.

Preserve the latest three combined islands, five quests and existing saved
gameplay contracts. Begin implementation with Island One and its two quests.
Idle-game readability is an art reference, not a request to replace the
first-person experience or introduce idle-game progression.

This document supersedes historical requirements for six islands, eight-island
versions, arbitrary 1,000/3,000-object counts, and texture-painted triangle grids.
The older enginehouse references remain useful for architecture and palette.
Keep editable source components where useful; runtime object counts are decided
by movement, materials, visibility and measured performance.

New explicit user direction can revise this standard. Record the change here so
future implementations do not silently return to an older design. Planning and
documentation changes do not themselves authorize a game release.

## 1. Visual identity

| Element | Required direction | Reject at review |
|---|---|---|
| Overall form | Strong, generous shapes with deliberate small details | A collection of unrelated primitives |
| Architecture | Ivory arches, substantial piers, layered mouldings, refined railings | Thin unsupported arches or gold outlines on every edge |
| Machinery | Recognizable working assemblies within supported bays | Floating gears, decorative pipes without endpoints |
| Quest stations | One distinct silhouette and one obvious operating area | The same circular badge pasted onto every machine |
| Gardens | Grouped planting with quiet space around interactions | Foliage crossing puzzle faces or paths |
| Lighting | Warm highlights, soft readable shadows, restrained energy glow | Black metal, blank grey ambience, clipped white emission |
| Detail | Concentrated at handles, joints, focal mechanisms and rewards | Uniform noise, excessive bolts, visible triangle grids |

Original architecture may evoke the elegance of Piltover and historical steam
engineering, while retaining Mind Spark's own shapes and symbols. Fictional lift
technology should show source, conduit and support relationships; do not present
steam alone as a real explanation of levitation.

### Palette starting points

These swatches are material starting values, not final rendered colour targets.
Check them in the actual game lighting.

| Role | Starting colour | Use |
|---|---|---|
| Warm ivory | `#EEE3CE` | Structural shells and stone |
| Pearl highlight | `#FFF2D9` | Small bevels and upper surfaces |
| Champagne brass | `#C5A366` | Frames, handles and mechanisms |
| Warm copper | `#A87554` | Selected pipes and chamber fittings |
| Deep teal | `#245B61` | Recesses and enamel |
| Pale aqua | `#8FD6C8` | Energy lenses and active channels |
| Soft lavender | `#A794BD` | Thought variation and secondary accents |
| Hope green | `#7BC99B` | Successful state, paired with shape and motion |

Aim for roughly 70% quiet structure, 20% secondary material and 10% accents in a
typical composition. This is a visual guide, not a pixel-count test. Do not assign
correctness from colour alone or depict difficult thoughts as morally bad.

## 2. What a finished low-poly object contains

Low-poly describes economical geometry. Few objects, few triangles and few draw
calls are different measurements. Joining objects does not automatically lower
triangle count or draw calls, and triangulation alone does not smooth a surface.

Build each instrument in this order:

1. **Silhouette:** one recognizable body expressing its purpose.
2. **Structure:** a stable base, housing, mounting points and supported joints.
3. **Mechanism:** two or three major moving assemblies explaining its operation.
4. **Secondary shape:** controlled bevels, recessed panels, collars and grips.
5. **Surface finish:** coherent UVs, quiet textures and material separation.
6. **Feedback:** state-driven motion, a readable result and limited light effects.

Leave large surfaces quiet. Use silhouette-changing geometry for important
bevels, handles, pipes, chamber caps and near-camera engravings. Use textures for
small seams, subtle wear and fine inscriptions. Do not divide the model into
editable "pixels" or pad component counts.

### Source and runtime layout

```text
QuestInstrument_<id>
├── StaticBodyArt       housing, fixed supports, fixed ornament
├── Mechanism           pivoted rings, lever, piston or card carriage
├── Interaction         existing control ID and proximity detection
├── Feedback            state lens, indicator, energy output
├── Collision           simple authored shapes
└── Presentation        nearby prompt and optional inspection camera anchors
```

Keep the Blender source more editable than the exported scene. Export fixed
pieces together when they share materials and visibility requirements. Keep
moving, interactive and independently hidden parts separate. Preserve authored
pivots and gameplay node references. Instance repeated assets where practical.

### Materials and shading

- Use shared ivory, brass, copper and enamel materials across the kit.
- Give metal enough roughness to retain colour in shadow; verify reflections.
- Use subtle albedo variation. Fine normal detail must support the main shape.
- Use ambient occlusion for contacts, not heavy dark outlines across every face.
- Paint metalness only onto actual metal regions. Texture channels must use the
  correct colour-space treatment for the exporter and Godot importer.
- Give textures mipmaps and consistent apparent detail at interaction distance.
- Use weighted or split normals intentionally: planar facets remain planar,
  while selected curved surfaces can shade smoothly. Inspect exported normals.
- Use emission for small lenses and channels. Provide readable dormant states.
- Use glass only where seeing inside serves the design; limit layered transparency.

### Provisional budgets

These are initial planning ranges, not measured limits or approval evidence.
Adjust after profiling a complete Island One view on the target Web hardware.

| Asset class | Initial LOD0 triangle range | Material slots |
|---|---:|---:|
| Small handle, socket or prop | 200–1,000 | 1–2 |
| Standard quest instrument | 2,000–6,000 | 2–4 |
| Large balance or observatory assembly | 6,000–15,000 | 3–5 |

Start a shared kit atlas at 1024 pixels; use 2048 only when player-distance
inspection establishes a need. Add LODs where screen size and visibility justify
them. Record triangles, material slots, mesh instances, draw calls, texture memory
and frame time separately. Do not hide an expensive export behind a low-poly label.

## 3. Island One spatial layout

Retain the existing island footprint and connections. This is a functional layout,
not a new surveyed coordinate plan:

```text
ENTRY / ORIENTATION
        ↓
SIGNAL OBSERVATORY
Colour · Rhythm · Weight → Analysis
        ↓
Notice pressure ↔ Make space
        ↓
Notice · Understand · Choose alignment controls
        ↓
Send signal → Signal Prism
        ↓
ECHO GARDEN / WISDOM TREE
Collector → Three echo-classification instruments
        ↓
Protective-question cards → Verification beacon
        ↓
Echo Seed → Power existing heavenly gate → ISLAND TWO
```

Keep a continuous walkable route with no mandatory precision jumps. Establish an
approach area, interaction area, full movement envelope and maintenance/support
area for each instrument. As a starting layout allowance, keep circulation about
three player-capsule diameters wide; validate with the real controller.

Face controls toward their approach areas. Reserve the viewing cone from the
player's actual eye position to the entire mechanism. Plants, other instruments,
rails, pipes and labels must not enter that cone. Keep the middle alignment
instrument's approach clear of the send console.

Use planting pockets and benches beside routes, not to fill every empty area.
Place foundation machinery in architectural bays below the terrace. Keep cliff
mass visible. Gate leaves need swept clearance, reachable hinges and collision
that follows their inward/outward movement.

## 4. Object-by-object implementation plan

These are art and feedback briefs. Retain existing puzzle meanings, dependencies
and valid solutions. Any new input mechanic needs its own design and validation.

| Existing control | Final form and layers | Visible response |
|---|---|---|
| Colour Prism | Three-lens mixer, triangular support, recessed optical bed, brass lens collars | Existing choices rotate lenses; output shows the selected composition |
| Rhythm Prism | Compact musical mechanism, graduated bars, toothed drive and countable marks | Selected rhythm drives a readable repeat pattern; reduced-motion equivalent available |
| Weight Prism | Physical balance, two suspended chambers, fulcrum, counterweight rail and stable plinth | Existing visual-weight selection changes beam/chamber pose; equilibrium is readable |
| Analysis Console | Sloped evidence desk, three specimen windows and comparison lens | Collected evidence appears in separate slots; analysis reveals relationships |
| West Regulator | Intake housing, enclosed pressure column, valve and upward flow symbol | Valve position and chamber level express noticing pressure |
| East Regulator | Release housing, return pipe, expansion chamber and outward flow symbol | Release position and expanding chamber express making space |
| Outer Ring | Accessible alignment wheel with distinct outer grip and eight detents | All affected ring positions reflect the coupled puzzle state |
| Middle Ring | Middle-grip alignment wheel facing a clear aisle | Middle selection and coupled movement remain visible from the operating point |
| Inner Ring | Compact central selector with distinct hub grip | Inner selection remains distinguishable by shape, label and position |
| Confirm | Protected send lever, prism socket and visible output conduit | Valid verification moves the lever and routes energy toward the reward |
| Echo Collector | Three receiving horns, converging supported tubes, transparent reservoir | One visible charge per collected echo; count remains after reload |
| Echo Signal 1 | Echo holder with three category slots and readable statement panel | Selected Fact/Possibility/Unsure category remains visible |
| Echo Signal 2 | Same reusable classifier family, different echo identifier and profile | Same category semantics; selected position follows this echo's saved choice |
| Echo Signal 3 | Same family with third identifier and profile | No colour or decoration reveals the correct answer before reasoning |
| Protective Question | Four physical cards on a framed reading desk, selector and output slot | Chosen card moves forward; actual question is readable in nearby UI |
| Verification Beacon | Cradled wisdom crystal, charge chamber, restrained radial fins and output mast | Verification shows incomplete/ready/complete states and directs reward energy |

The three echo controls each classify one echo; do not silently turn them into
three bins permanently assigned to Fact, Possibility and Unsure. Two regulators
may share parts while retaining distinguishable purposes. Move away from a large
identical badge as the primary silhouette of all 16 objects.

### First benchmark object: Weight Prism

Use the Weight Prism to establish the quality of the full kit before rebuilding
the other fifteen instruments.

```text
     suspended chamber        suspended chamber
              └──── pivoting beam ────┘
                         │
                    visible fulcrum
         adjustable counterweight / operating grip
                         │
          shaped ivory housing with inset scale
                         │
           brass feet → broad supported plinth
```

Model the plinth and shell as coherent forms. Keep the beam and counterweight
separate for motion. Add two restrained pipe returns, bearing collars, a legible
scale and a few fasteners at actual joints. Confirm how the existing three visual
weight choices map to poses; do not invent a physics puzzle during the art pass.

Review front, side, rear, moving extremes and the actual first-person operating
view. The benchmark passes only when the player can identify the control, observe
the state change and read the result without decorative obstruction.

## 5. Reusable kit and asset contracts

Build a shared kit of plinths, shell panels, bevelled trims, bearings, pipe elbows,
valves, chamber caps, hand grips, glass inserts, card sockets, crystal cradles,
lanterns, railing sections and planter edges. Variation comes from composition
and proportions; reuse does not require identical final silhouettes.

For each asset deliver:

- Editable `.blend` source with units, applied scale, named collections and pivots.
- `.glb` runtime export with explicit transforms, normals and material assignments.
- Shared textures/materials and documented import settings.
- Godot wrapper preserving control IDs, interaction and persistence interfaces.
- Simple collision, approach anchor, camera anchor and movement-envelope notes.
- Front/side/rear and first-person captures in dormant, active and complete states.
- A manifest of triangles, slots, texture sizes, moving parts and reuse dependencies.

Suggested new asset layout, to create during implementation:

```text
assets3D/mind_spark/quest_kit/<asset_id>/
    source/      editable Blender files
    export/      game-ready models
    previews/    review captures
    manifest.json
```

Do not rename existing runtime resources without updating and verifying their
references. Keep old source versions until replacements pass the full review.

## 6. Gameplay feedback contract

The existing saved puzzle state is the authority. Visuals derive from it; an
animation finishing must not award progress independently.

| State | Presentation |
|---|---|
| Locked | Mechanism rests; prerequisite is explained on approach |
| Available | Handle is identifiable; a restrained pulse signals availability |
| Operating | Input causes understandable mechanical movement |
| Selected | Choice remains legible while the player considers another control |
| Needs revision | Preserve choices; show a calm cue and actionable explanation |
| Complete | Mechanism settles, output energizes and destination becomes clear |

Cancel or replace obsolete tweens when players interact rapidly. Keep rotating
parts on their pivots, card engravings attached to moving cards, and indicators
consistent with all coupled values. Save/reload must restore the visual result
without replaying rewards. Respect reduced-motion settings where available.

Use high-contrast nearby prompts; avoid tiny floating titles and overlapping
labels. Pair colour with shape, text or position. Visuals must never imply that
all unpleasant thoughts should be destroyed; the theme remains understanding
thoughts, exploring them and choosing grounded hope.

## 7. Implementation phases and completion evidence

All steps below are planned, not completed by writing this document.

### Phase A — establish the baseline

- [ ] Inventory all 16 current controls, their saved state and their moving parts.
- [ ] Capture all controls from actual player eye height, including Middle Ring.
- [ ] Record current geometry, draw calls, textures and frame time.
- [ ] Locate/restore the missing tree, grass and cloud sources reported by export.
- [ ] Identify which prior audit defects persist in the current checkout.

### Phase B — complete the benchmark

- [x] Build the Weight Prism in Blender with full construction and material layers.
- [x] Integrate it with existing inputs and progression.
- [ ] Verify front/side/rear, operating view and motion clearances.
- [ ] Show the in-game benchmark for art-direction review before mass production.
- [ ] Record the accepted benchmark and exact asset revision in section 9.

### Phase C — build Island One Quest 1

- [x] Reuse benchmark materials and parts for Colour and Rhythm.
- [x] Build the evidence desk and distinct intake/release regulators.
- [x] Finish the three coupled ring controls with visible eight-position feedback.
- [ ] Finish the send mechanism, reward socket and connecting energy route.
- [x] Verify creative solutions, revision attempts, completion and reload.

### Phase D — build Island One Quest 2

- [x] Finish collector and three classifiers with readable thought content.
- [ ] Finish the card mechanism, verification beacon and Echo Seed reward.
- [ ] Connect quest completion to the existing tree and heavenly gate visuals.
- [ ] Verify quest dependency, choice persistence and gate movement clearance.

### Phase E — environment and rendering

- [ ] Clear operating views and walking routes for every instrument.
- [ ] Organize gardens into deliberate pockets around quiet circulation space.
- [ ] Tune ivory/brass/glass under shared game lighting, including shadowed areas.
- [ ] Limit simultaneous glow, particles and redundant visible labels.
- [ ] Apply measured instancing, material sharing and LOD improvements.

### Phase F — release and extend

- [ ] Run focused gameplay, persistence, movement and gate regressions.
- [ ] Review every instrument visually at near, interaction and approach distances.
- [ ] Export non-Mono Web without unresolved missing-resource or script errors.
- [ ] Follow the repository delivery contract for production deployment.
- [ ] Verify start screen, Offline Guest and the changed Island One path in WebGL2.
- [ ] Record deployment, browser evidence and any limits separately from native results.
- [ ] Reuse the accepted kit for later islands while preserving distinct landmarks.

## 8. Final quality checklist

An object is ready only when all applicable checks pass. A node count, metadata
flag, successful import or passing gameplay test does not establish art quality.

- [ ] Its silhouette communicates a distinct purpose at approach distance.
- [ ] The player can identify the operating part without relying only on colour.
- [ ] Supports, connections and moving clearances are credible from all sides.
- [ ] The full mechanism is visible from the actual interaction location.
- [ ] Main surfaces are quiet; small details reinforce the focal area.
- [ ] Ivory, brass, enamel and glass remain distinguishable in light and shadow.
- [ ] No clipping, buried symbols, inverted faces or incorrect material channels.
- [ ] No clipped highlights, texture shimmer or distracting transparent overlap.
- [ ] Labels remain readable and do not overlap neighbouring stations.
- [ ] Feedback reflects real puzzle values and persists correctly after reload.
- [ ] Incorrect attempts support revision without hiding the player's choices.
- [ ] Runtime measurements fit the agreed target hardware and scene budget.
- [ ] Native and Web captures agree sufficiently to support release.

Keep a per-object review table with status `planned`, `in progress`, `needs
revision` or `accepted`, evidence paths and remaining defects. Do not use an
average score to conceal a blocking readability or gameplay defect.

## 9. Reference history

| Date | Revision | Meaning |
|---|---|---|
| 2026-09-12 | 1.0 | Written standard and implementation roadmap created |
| 2026-09-13 | 1.1 | Checked current kit and native render; added reusable shape/detail rules, next-island rollout and review template |
| 2026-09-13 | 1.2 | Traced Island Two districts, assets and quest contracts; added its scoped layout and implementation checklist |
| 2026-09-13 | 1.3 | Added Island One Part Two / Echo Garden assessment, layout, reusable parts and staged implementation plan |

Accepted finished benchmark: **not yet established**.

Implemented candidate: `weight_benchmark_01`. See
[implementation evidence](MIND_SPARK_WEIGHT_BENCHMARK_IMPLEMENTATION.md).
The candidate has not yet received final art-direction acceptance.

The user subsequently requested the new style across the quest objects.
Implementation candidate `heavenly_kit_02` replaces the other fifteen Island One
instruments. See [per-object audit and evidence](MIND_SPARK_HEAVENLY_QUEST_KIT_AUDIT.md).
This records implementation, not blanket final-art approval.

Historical v41/v42 renders are diagnostic evidence, not the final style target.
When a benchmark is accepted, copy its captures into a stable project reference
folder, record source/export revisions and update this section. Avoid relying on
temporary clipboard paths or chat memory as the only reference.

## 10. Current assessment and permanent working method

### Assessment on 13 September 2026

The current game is a mixed implementation, not an accepted finished idle-style
environment. The new quest kit uses economical, shaped low-poly models; the
surroundings still contain dense procedural ornament and competing visual layers.

Evidence inspected:

- `assets3D/mind_spark/quest_kit/heavenly_kit_manifest.json`: the fifteen newer
  instruments report 1,296–2,792 triangles, 3–7 runtime mesh nodes, four materials,
  and a 1024px atlas. Their editable sources contain 18–33 meshes each.
- Weight Prism's separate manifest reports 4,260 triangles and seven runtime
  mesh nodes. These are model/export figures, not full station or scene costs.
- `tools/build_heavenly_quest_kit.py` applies single-segment bevels and consolidates
  fixed parts while retaining mechanism pivots. The visual adapter shares kit
  materials. This is already closer to the intended method than arbitrary
  thousands-of-parts construction.
- `scripts/mind_spark/mind_spark_world_one.gd` batches eligible repeated scenery
  into MultiMeshes. This does not prove that the complete scene is inexpensive.
- Native capture `artifacts/island_one_warm_surroundings/weight_prism.png` shows a
  recognizable balance, shaped feet and restrained material regions. Background
  foliage, rails, repeated instruments and service labels still compete with it.
  Floor highlights lose definition in places; fine surface/shadow stippling needs
  a motion and Web review before attributing its cause or calling it acceptable.

No new runtime performance measurements or live Web art inspection were performed
for this documentation update. The local lighting candidate is not a production
reference: see `MIND_SPARK_ISLAND_ONE_LIGHTING_PASS.md` for its export blocker.

### The standing style rule

**Heavenly crafted low-poly: fewer coherent runtime assemblies, strong shaped
forms, selective small details, quiet textures and readable mechanisms.**

Low-poly geometry and idle-game visual readability are complementary, not
alternatives. Preserve first-person movement and the existing puzzle game.
Triangulation is an export/topology step, not a smoothing or detail technique.
Use bevels, appropriate curve segmentation and controlled normals to shape surfaces.

| Detail level | Build as | Example | Rejection rule |
|---|---|---|---|
| Primary | Main mesh silhouette | Tapered machine housing, arch pier, clustered canopy | Unrelated boxes with decoration hiding an unclear body |
| Secondary | Modelled shape where visible | Recessed door panel, thick rim, bearing, root flare | Flat box with every feature painted on |
| Operating | Separate pivoted assembly | Valve, gate leaf, balance beam, selector card | Joining pieces that must move independently |
| Fine | Shared texture/normal detail when useful | Panel seams, fine grain, tiny engravings | A separate object for every scratch or rivet |
| Repeated | Reusable module/instance | Rail bay, planter, lantern, tree variation | Unique copies with unnecessary unique materials |
| Feedback | Small state-driven accent | Charge lens, selected card position | Whole machine glowing or correctness conveyed by colour alone |

Geometry detail must survive the intended viewing distance. If it does not change
the silhouette, explain function, or remain legible in motion, simplify or bake it.
Joining fixed pieces must respect visibility/culling boundaries: do not join an
entire island into one giant mesh merely to reduce node count.

### Reusable surroundings kit

| Family | Source breakdown | Runtime/layout rule |
|---|---|---|
| Architecture | Plinth, tapered shaft, capital, arch segments, cornice | Join a fixed bay; repeat bays; keep door leaves and hinges functional |
| Machinery | Housing, supported chamber, drive, bearing, supply/return pipes | One dominant mechanism per bay; show connection endpoints |
| Trees | Root flare, tapered trunk, main branches, grouped canopy masses | Hero tree receives detail; background trees use simpler varied silhouettes |
| Garden | Planter shell, soil, grouped planting, edging | Plant beside circulation and outside operating views; preserve quiet space |
| Lighting | Shaped lantern body, diffuser, mounting, small emissive surface | Reuse fixtures; add real lights only where they improve the view |
| Paths/rails | Paving bay, border, post, infill | Preserve accessible route, fall protection and full gate sweep clearance |

### Next-island implementation sequence

Apply this sequence to Island Two next, then Island Three. Do not invent new
quest assignments from visual references; trace the existing five-quest code first.
Every step is planned until evidence is recorded.

1. **Inventory and baseline.** List actual Island Two objects, quest IDs, runtime
   references, collisions and moving parts. Capture entry, each operating position,
   garden, exit and underside. Record near/far scene costs on named Web hardware.
2. **Spatial drawing.** Map entry → existing quest stations → reward → exit.
   Mark walkable lane, operating area, viewing cone, moving envelope and planted
   pockets separately. Preserve existing island footprint and connections.
3. **One representative asset.** Select the most visible existing quest instrument.
   Draw front/side silhouettes and exploded functional parts. Build the shaped
   low-poly candidate in Blender with UVs, materials and real pivots.
4. **In-game benchmark review.** Show dormant, operating and complete views at
   player eye height. Compare under the actual island lighting, including shadow.
   Obtain visual acceptance before treating it as the template for all objects.
5. **Reusable family rollout.** Rebuild the remaining instruments from approved
   parts. Preserve IDs, state, interactions and collision contracts. Record reuse
   and justified exceptions rather than making every instrument identical.
6. **Surroundings pass.** Shape architectural bays, simplify background trees,
   group gardens, clear sightlines and control highlight/glow competition. Do not
   fill every gap; do not delete safety rails or route objects to simplify a view.
7. **Gameplay and performance.** Test incorrect attempts, all intended solutions,
   rapid inputs, saved-state restoration, movement and gate clearance. Measure
   frame time, draw calls, triangles and texture memory separately before/after.
8. **Delivery and reference.** Follow the repository Web release contract; inspect
   the changed route in the browser. Archive accepted screenshots, source/export
   revision and measured results, then advance to the next island.

### Copyable asset review record

Use this record for every future asset or reusable family:

```text
Asset ID / island / existing quest ID:
Status: planned | in progress | needs revision | accepted
Purpose and player action:
Primary silhouette / secondary shapes / fine surface details:
Shared source parts and materials:
Fixed meshes / moving pivots / collision / interaction anchors:
Approach, viewing cone and movement clearances:
Source .blend / runtime .glb / revision:
Export triangles / mesh nodes / material surfaces / texture sizes:
Whole-view draw calls / frame time / texture memory / device / resolution:
Dormant / selected / incorrect / complete / reload evidence:
Native and Web screenshot paths / production deployment:
Remaining defects / approval date and user acceptance:
```

This file is the single versioned style reference, not a promise of automatic
future compliance or an immutable rule. Future work should read it first, record
exceptions explicitly, and update the revision when the user changes direction.
Do not create a competing style guide or modify the original AGENTS.md to enforce it.

## 11. Island Two — scoped reference and implementation plan

Status: **planned, not implemented or visually accepted**. This section applies
the shared rules above; it does not create another art style. Read sections 1–2,
6, 8 and 10 before implementing an Island Two asset. Preserve existing source
versions until replacements pass review. Record future revisions here.

### 11.1 Current code and asset assessment

Physical Island Two combines `03_constellation_court` and `04_hope_path_ridge`
through `SUPER_ISLAND_PAIRS`. Do not confuse it with legacy `island_02.glb`, which
belongs to the first combined island.

The standalone foundation builder currently selects:

| District | Foundation asset | Manifest runtime meshes | Manifest triangles |
|---|---|---:|---:|
| Constellation Court | `celestial_astral_v16/island_03.glb` | 13 | 517,995 |
| Hope Path Ridge | `celestial_dawn_v17/island_04.glb` | 9 | 396,382 |
| Combined foundation assets | Excludes extra upper scenery and quest objects | 22 | 914,377 |

Sources: the corresponding `assets3D/mind_spark/*/manifest.json` files. These are
recorded export statistics, not fresh GLB validation, simultaneous visible
triangle counts, draw calls or measured Web frame time. Both manifests retain
the historical 3,000 editable-parts target; do not propagate it into new assets.

Current style is a **hybrid authored/procedural implementation**, not a verified
economical idle-style finish. `_build_constellation_court` adds a dais, three
inlay rings, eight memory spheres and two gates. `_build_hope_ridge` adds five
stepped tiles, an eight-column pavilion, a segmented roof, engine towers and
garden terraces. The grove layout plans fourteen trees per district. Batching
reduces eligible node/draw overhead but does not remove their triangles.

The six functional objects use `QuestObjectBase`: authored scene nodes are
retained for behavior, legacy geometry is made transparent, and Blender GLBs
are attached. This deserves a visibility/resource audit: do not assume hidden
legacy nodes cost nothing or delete them before checking animation references.
The newer Island One instrument kit is not automatically applied to these objects.

This assessment is from code and manifests. No new Island Two render, live
performance benchmark or playthrough was performed for this planning pass.

### 11.2 Art direction and layout

Working identity: **The Observatory of Understanding**. Use scholarly instrument
shapes on the Constellation side and an open sunrise pavilion on the Hope side.
Keep the existing two-lobed foundation, connections, raised route and lift-engine
silhouette. Distinction comes from purpose and composition, not a new palette.

Apply the shared ivory/champagne/teal palette. Keep large panels quiet; reserve
fine geometry for bearings, control grips, sockets, thick rims and readable
mechanisms. Do not copy an identical circular badge onto every station.

Functional layout, not a new coordinate or mandatory traversal specification:

```text
FROM ISLAND ONE — existing bridge/arrival
                    ↓
 CONSTELLATION COURT: examine → connect → verify
 Evidence scanner → Memory board → Logic gate
       └──── optional Focus Bell / help alcove ────┘
                    ↓
 Existing intra-island connection / accessible circulation
                    ↓
 HOPE RIDGE: change viewpoint → establish footing
 Perspective lens → Truth-bridge tile → existing guard encounter
                    ↓
 Existing exit toward ISLAND THREE
```

Keep the current task dependencies: the Logic Gate task also checks the
constellation enemy wave; the Hope sequence ends with the existing elite guard.
An art redesign must not silently remove those conditions.

For each station, draw five envelopes before moving anything: approach lane,
player operating space, eye-height viewing cone, mechanical sweep and planting
boundary. Start circulation at three player-capsule diameters and validate with
the actual controller. Keep the optional jumping route and accessible alternative.
Keep help visible from arrival but outside the main instrument's viewing cone.
Put planting behind or beside stations, never between the eye and control.
Place maintenance machinery under terrace bays rather than in the walking lane.
The layout keeps deliberate empty space; filling every gap is not a quality goal.

### 11.3 Object-by-object build briefs

Existing IDs remain authoritative. New motions below are proposed presentation,
not permission to change input rules, correct answers or saved-state schemas.

| Object / save ID suffix | Primary form | Smaller reusable parts | Proposed visible feedback |
|---|---|---|---|
| Evidence Scanner / `evidence_scanner` | Sloped optical examination desk | Tapered plinth, recessed specimen tray, lens yoke, thick glass collar, two choice keys, evidence slot | Scan shutter reveals the clue; selected key depresses; evidence slot responds to actual result |
| Memory Board / `memory_board` | Broad three-node constellation table | Bevelled slab, inset teal slate, three distinct sockets, supported connector channels, reset grip | Existing node-order input lights the connected route in sequence; revision clears only the appropriate state |
| Logic Gate / `logic_gate` | Substantial ivory verification arch | Two piers, capitals, arch crown, memory socket, two evidence receptacles, door assembly and protected guides/hinges | Each required item has a visible socket state; clearance follows existing unlock and collision logic |
| Focus Bell / `focus_bell` | Small suspended bell in a forked support | Foot, yoke, bell shell, clapper, help marker | Help availability is readable without constant flashing; any bell motion follows the real hint event |
| Perspective Lens / `perspective_lens` | Accessible gimbal-mounted optical instrument | Base, bearing blocks, lens hoop, faceted lens, three-detent grip, engraved angle marks | Existing three fixed angles produce three legible poses; no unrelated decorative ring stack |
| Truth Bridge / `truth_bridge` | Supported inlaid path-tile mechanism | Load-bearing frame, bevelled tile, recessed channel, statement controls, output lens | Correct state changes the tile and walkability consistently; no disappearing support under the player |

All IDs above have prefix `world_one.`. The Logic Gate is a quest instrument;
do not mistake the decorative Fear/Proof arches or inter-island gate for its
interactive object. Preserve original gate movement behavior until its collision
and state contract has been traced; do not import Island One door motion blindly.

**First benchmark: Memory Board.** It is central to the Constellation task and
tests the full desired method: a shaped housing, quiet textured slate, reusable
sockets, readable connections and state-driven feedback. Draw front, side and
exploded views; build one finished candidate before rebuilding all six objects.
Inspect it from standing eye height, not only from above.

### 11.4 Surroundings families and geometry policy

| Family | Keep | Redesign/simplify | Must verify |
|---|---|---|---|
| Foundation and engine bays | Recognizable crown/oval silhouette, engine purpose, cliff mass | Bake tiny fittings; simplify hidden backs; author near/mid/far versions | No holes from normal camera angles; retain supports, barriers and service access |
| Pavilion and arches | Existing footprints and usable spans | Coherent tapered columns, moulded capitals and shaped roof panels instead of layers of thin outlines | Door/column clearance and headroom |
| Paths and rails | Current route, steps, fall protection | Quiet ivory paving, restrained inlays, repeated rail modules | Continuous collisions at seams and transitions |
| Trees | Hero/landmark hierarchy and intentional groups | Clustered low-poly canopies and tapered trunks; simpler background variants | No foliage masking clues or controls; no new route obstruction |
| Garden pockets | Soil containment and planted edges | Reuse planter, soil and grouped-flower modules | Quiet operating areas remain empty |
| Lanterns and conduits | Supported mounts and source-to-destination logic | Shared lantern housing, small emissive lens, purposeful pipes | Avoid glare and excessive overlapping real lights |

Use the instrument ranges in section 2 as provisional budgets, not final limits.
For the foundation, first measure the contribution of each bay, tower, engine,
railing and hidden face. Set reduction targets from those measurements; do not
declare 22 mesh nodes cheap or promise an arbitrary scene triangle total.

Join static pieces within one culling unit/material family. Keep moving parts,
collisions and gameplay anchors separate. Reuse mesh/material resources for
repeated modules. Model silhouette-changing details; bake small seams and grain.
Use deliberate bevels and split/weighted normals; triangles alone do not smooth
surfaces. Avoid whole-island joining and thousands of independent micro-objects.

### 11.5 Implementation checklist and acceptance gates

1. **Baseline and contracts**
   - [ ] Capture entry, all six objects, pavilion, underside and exit in the actual game.
   - [ ] Measure triangles, draw calls, texture memory and frame-time distribution
     at named resolution/device/browser, including moving-camera views.
   - [ ] Trace all six object actions, moving-node references, collision and saves.
   - [ ] Reconcile presentation of five player-facing quests with the controller's
     four QUESTS records: Island One's two puzzles are currently grouped in one
     record, and the HUD uses `/4`. Preserve saves; do not renumber in an art pass.
   - [ ] Verify standalone and embedded foundation modes before applying coordinates.
2. **Spatial approval**
   - [ ] Draw existing anchors plus circulation/view/sweep/planting envelopes.
   - [ ] Identify which objects are functional, decorative or enemy encounter props.
   - [ ] Confirm the proposed arrangement preserves progression and accessibility.
3. **Memory Board benchmark**
   - [ ] Build editable Blender source with named static shell, sockets and mechanism.
   - [ ] Add shared UV atlas/materials, controlled normals and simple collision.
   - [ ] Integrate behind the existing object ID and input/state interface.
   - [ ] Show dormant, selected, revision and completed states at player eye height.
   - [ ] Obtain visual acceptance before calling it the reference for the full set.
4. **Family rollout**
   - [ ] Evidence Scanner, then Logic Gate; verify the complete Broken Pattern sequence.
   - [ ] Perspective Lens, then Truth Bridge; verify the complete Hope Path sequence.
   - [ ] Focus Bell and supporting signage; preserve help without revealing solutions.
   - [ ] Audit hidden legacy geometry before removing or unloading any replacement.
5. **Environment and audio**
   - [ ] Simplify measured costly foundation components; review LOD transitions.
   - [ ] Refine pavilion, grouped gardens, railings and lanterns around clear views.
   - [ ] Tune local warm lighting; verify that other islands are unaffected.
   - [ ] Plan distinct scan, socket, lens-detent, gate and completion sounds.
     Current generic feedback tone is not a finished soundscape. Pair audio with
     visual cues; test mute/volume and avoid repeated reward sounds on reload.
6. **Release and archive**
   - [ ] Test incorrect input, reset, all allowed solutions, rapid input and reload.
   - [ ] Test Island One arrival → both Island Two task chains → Island Three exit,
     including enemy-wave conditions, no early unlock and traversal collisions.
   - [ ] Compare scene costs before/after under identical camera and hardware.
   - [ ] Complete clean non-Mono export, existing-project deployment and live Web
     route verification according to the repository delivery contract.
   - [ ] Archive approved views, .blend/.glb revisions, metrics and known defects
     in the asset review record from section 10. Update this reference's history.

Planning-only delivery: this revision changes documentation, not runtime art,
quests, assets or AGENTS.md. No production release or performance pass is claimed.

### 11.6 First implementation candidate — memory_board_01

Implementation follow-up, 13 September 2026: the Memory Board benchmark is now
built and locally integrated for `world_one.memory_board`. The other five Island
Two object rebuilds, foundation optimization and surroundings remain planned.
This supersedes the planning-only status above for this one object only.

- Generator: `tools/build_memory_board_benchmark.py`.
- Editable source: `assets3D/mind_spark/quest_kit/memory_board/source/memory_board.blend`.
- Runtime: `assets3D/mind_spark/quest_kit/memory_board/export/memory_board.glb`.
- Export record: 2,916 triangles, seven mesh nodes, four materials, shared 1024px
  atlas; 39 editable mesh pieces in the source. These exclude retained hidden
  behavior nodes, surrounding world geometry and draw-call overhead.
- Design: bevelled ivory housing, brass reveals, quiet teal slate, three numbered
  sockets, selected cap depression, two progress links and completion seal.
- Uses existing node-order, reset, help, completion and persistence rules. The
  primary action still chooses the expected next node; this art pass does not
  claim increased puzzle difficulty or new mouse-based node selection.
- Scoped adapter in `quest_object_base.gd` preserves IDs and legacy behavior
  nodes. Explicitly hides obsolete surfaces after state updates and excludes
  this object from world batching so hidden geometry cannot reappear in batches.
- Native in-world captures: `previews/dormant.png` and `previews/complete.png`
  under the asset folder. These use player-height relative viewpoints and the
  containing world's existing environment; not a manual walking recording.
- Passed: `test_island_two_memory_benchmark.gd -- --capture` (wrong input, reset,
  cap/link feedback, completion, restore and no legacy visual overlap),
  `test_mind_spark_quest_object_integration.gd`, and
  `test_mind_spark_world_one_story.gd`.
- Web export produced 143 pack parts including the new GLB, but both attempts
  reported `TLS handshake error: -27648` after pack serialization. No production
  deployment or updated browser verification was performed. Existing music UID
  fallback and ObjectDB leak warnings remain. Do not label this a clean release.

Status: **local candidate awaiting visual review; production blocked**. The
background remains overly bright and some existing world labels overlap in the
view; these belong to the pending Island Two surroundings pass. No full island
performance improvement is claimed. Original AGENTS.md unchanged; no Git commit
or push. Review the benchmark before rolling its design across the remaining kit.

## 12. Island One, Part Two — Echo Garden and Wisdom Tree

Status: **planning only**. This is the right-hand garden lobe in
`artifacts/island_one_overview/overview.png`, not physical Island Two and not the
Oldest Tree Sanctuary on Island Three. Gameplay for this area is authored beneath
`CelestialWorldGateArrival`; scene hierarchy does not map neatly to the visual
district boundary. Resolve actual transforms before editing placement.

### 12.1 Assessment and evidence limits

The current appearance combines economical authored quest instruments with dense
procedural surroundings. Low-poly and idle-game readability are not alternatives:
the desired outcome uses both. Few mesh nodes alone do not establish low geometry
cost, good silhouettes or clear first-person interactions.

The latest local overview shows a broad circular garden, a spreading central
tree, radial roots, repeated perimeter trees, lanterns, rails and terraced planting.
Ivory highlights lose definition and the surface has many competing small accents.
This overview is useful for composition, not close-range texture certification.

Code in `_build_island_one_science_art_garden` contains a separate named
`CognitiveLightTree` assembly with twelve trunk segments, 36 signal-fibre segments,
ten two-piece branches, 55 leaf shapes, thirteen seven-piece blossoms, three
observation orbits and a crown. The garden also has 34 pavement pips. Both garden
and tree carry `preserve_authored_nodes`, excluding them from general world
batching. These are construction counts, not measured runtime triangle totals.

Do not assume the broad brown tree in the overview is wholly this procedural
ivory teaching-tree assembly. The environment contains imported and procedural
layers. First isolate their visibility in a diagnostic scene and map each visible
trunk, canopy and root system to its owning asset. Do not accidentally replace a
secondary tree while leaving the dominant silhouette unchanged.

The six Echo controls already use the newer Island One kit: collector, three
classifiers, protective-question desk and verification beacon. Retain these as
starting candidates; do not replace them merely to claim a complete rebuild.
Existing feedback includes six root conduits, staged pulses, four guidance
chapters and an Echo Seed reward. Their saved-state relationships matter more
than their current decorative geometry.

Evidence: current local overview, world builder, puzzle control integration and
section 10's kit export records. No new live Web playthrough, triangle measurement
or performance benchmark was performed for this planning update. Do not apply
Island Two's foundation statistics to this area.

### 12.2 Permanent direction for this area

**A warm celestial listening garden: one expressive tree, quiet planted terraces,
and clearly readable thought instruments.** Keep the shared ivory, champagne,
teal and aqua palette; use soft lavender sparingly. Preserve first-person gameplay.

- Primary forms: a grounded tree silhouette, a restrained root basin, curved
  planted edges and substantial structural bays.
- Secondary forms: root flare, branch junctions, layered canopy groups, moulded
  planter rims, socket collars and instrument handles.
- Fine detail: bark grain, leaf veins, small seams and engravings use quiet shared
  textures when they do not affect silhouette or readability.
- Feedback: localized lenses and purposeful motion, not whole-tree or whole-floor
  emission. Success also needs shape/text cues, not green alone.
- Reuse: keep editable source parts, but export coherent static assemblies within
  sensible culling boundaries. Preserve independently animated feedback pieces.

Triangulation does not smooth a model. Shape curves with appropriate segments,
small bevels and controlled normals. Keep intentional planar facets on the low-poly
trunk and canopy; do not add visible triangle grids or arbitrary 3,000-part targets.

### 12.3 Layout blueprint

This is a functional organization to validate against existing anchors, not a
new surveyed floor plan or authorization to move stations immediately.

```text
FROM SIGNAL OBSERVATORY — Signal Prism prerequisite
                         ↓
                  Arrival / listening cue
                         ↓
     Collector → Echo I → Echo II → Echo III
                         ↓
               Protective-question desk
                         ↓
                Verification beacon
                         ↓
          Echo Seed → existing powered gate → ISLAND TWO

       Wisdom Tree + contained roots = central landmark
       Planting/benches = side pockets outside operating views
       Foundation engines = supported bays below the terrace
```

Keep a clear route around the root basin, with no mandatory jumping. Draw approach,
interaction, viewing and mechanism-sweep envelopes for each station. Start the
walking lane at three player-capsule diameters, then test the real controller.
Keep exposed roots inside planted/contained areas or safely below the walking
surface. Preserve fall barriers and the gate's actual swept clearance.

Group the classifiers so their relationship is obvious without their statement
panels overlapping. Put the question desk in a quieter reading pocket and make
the beacon visible as the destination. The tree should orient the player without
covering the clue text. Retain an unobstructed visual connection to the exit.

### 12.4 Reusable object breakdown

| Family | Smaller editable source parts | Runtime/design treatment | Purpose |
|---|---|---|---|
| Hero tree | Root flare, main trunk, major branch forks, canopy clusters | Join fixed wood; use a few canopy clusters with reusable material; keep feedback separate | Main landmark, recognizable from approach and exit |
| Teaching-tree signal detail | Fibre channel, signal lens, blossom cluster | Retain meaningful distribution anchors; consolidate static geometry without losing state references | Support science-art theme without dense glowing wires |
| Root basin | Basin shell, shaped rim, soil bed, root mounts, inspection inset | Repeat rim sectors; keep real soil containment and accessible edges | Ground the tree and protect circulation |
| Background trees | Tapered trunk, two/three branch variants, grouped canopy | Few varied silhouettes, shared mesh/material resources, measured LOD | Frame the hero tree rather than compete with it |
| Garden pocket | Curved planter, soil insert, grouped foliage, flower cluster | Reusable pocket family; quiet gaps between groups | Deliberate planting rather than scattered filler |
| Bench/rest bay | Shaped seat, two supports, back/edge if appropriate | One static module; keep entry and interaction space clear | Optional pause/read area, no new quest requirement |
| Echo Collector | Existing receiving horns, reservoir, charge indicators, base | Keep newer kit; review support connections and readable charge count | Gather three echoes |
| Echo I–III | Shared classifier shell, statement panel, three selectable cards | One family with distinct identifiers; preserve Fact/Possibility/Unsure options on every instrument | Interpret each thought separately |
| Question desk | Existing shell, four cards, selector, output port | Improve text placement and card clearance before rebuilding geometry | Choose a useful protective question |
| Beacon / Echo Seed | Existing crystal cradle, indicator, seed core and petal shell | One clear focal reward; avoid duplicate towers/halos | Verify and explain why the gate receives power |
| Power routes | Socket, short conduit, return junction, pulse element | Route through supported channels; derive endpoints from live anchors | Connect each task to the tree/gate visually |
| Perimeter | Rail bay, post, lantern, corner/curve adapters | Instance modules; retain safety collision | Frame the garden and protect edges |
| Underside | Arch bay, chamber, bearing, supply/return pipe, service rail | Reuse bay families; simplify unseen detail only after measurement | Show structural support and fictional lift machinery |

Do not assign a unique material to every part. Reuse the shared kit atlas and
palette where appropriate. Give the hero canopy more silhouette detail than
background foliage. Each pipe needs credible endpoints; a decorative gear needs
a support/shaft or should be removed from the proposed design.

### 12.5 Implementation order and review gates

1. **Isolate and measure**
   - [ ] Identify the actual owners of the dominant tree, teaching tree, roots,
     planting, railings, imported foundation and quest overlays.
   - [ ] Capture overview, tree approach, all six operating views, exit and underside.
   - [ ] Record visible triangles, materials, draw calls, texture memory and frame
     times on named native/Web hardware at matching viewpoints.
   - [ ] Trace Echo state, guidance, reward and gate references before replacing art.
2. **Approve the spatial drawing**
   - [ ] Mark existing anchors, accessible loop, operating/viewing envelopes,
     gate sweep and contained planting; identify conflicts before changing positions.
   - [ ] Decide which tree is the principal landmark and what the secondary
     teaching-tree assembly contributes. Preserve useful functions, avoid duplicates.
3. **First benchmark: hero tree plus root-basin segment**
   - [ ] Build the full primary silhouette in Blender, then one detailed branch/
     canopy family and one finished basin segment. No isolated leaf-only benchmark.
   - [ ] Review near, approach and overview views in actual game lighting.
   - [ ] Deliver UVs, materials, normals, simple collision and editable source.
   - [ ] Obtain visual approval before repeating canopy and garden modules widely.
4. **Garden and architecture rollout**
   - [ ] Complete root containment, simplify competing foliage, group planters and
     place optional seating without filling the operating lanes.
   - [ ] Refine rails and lanterns; preserve foundations and playable bridges.
   - [ ] Replace only measured problematic underside details, retaining cliff mass.
5. **Quest presentation refinement**
   - [ ] Reuse the six newer instruments; fix concrete silhouette, material, text
     or movement defects established by player-height captures.
   - [ ] Verify labels remain readable during selection and do not reveal answers.
   - [ ] Bind conduits to actual output anchors and keep reward feedback localized.
   - [ ] Keep the untimed collect → classify → question → verify rules unchanged.
6. **Lighting, sound and verification**
   - [ ] Retain elevated light placement; tune highlights and shadows locally.
     Do not blindly copy Island One's local lighting candidate into other areas.
   - [ ] Plan subtle collection, card-selection, verification and seed-award cues;
     do not claim the existing generic sound system already provides them.
   - [ ] Test incorrect classifications, revision, prerequisite locks, all allowed
     solutions, rapid input, reload, no duplicate reward and gate collision.
   - [ ] Re-run Island One kit, Echo Garden, science-art and gate regressions.
   - [ ] Existing tests assert leaf/fibre counts. If consolidation changes node
     representation, preserve lesson anchors/behavior and revise tests deliberately;
     do not pad runtime meshes solely to satisfy historical counts.
7. **Release and archive**
   - [ ] Compare before/after costs and visual clarity under the same conditions.
   - [ ] Complete the repository's clean export/deploy/live Web verification loop;
     track the existing TLS export blocker explicitly.
   - [ ] Record source/export revisions, accepted screenshots, performance evidence
     and outstanding defects using section 10's asset review template.

Acceptance requires an identifiable hero tree, unobstructed quest text and routes,
coherent shaped low-poly surfaces, restrained glow, functioning saved-state
feedback and measured performance. No fixed object count proves quality.
This section is the standing reference for later work on this area; revise it
when the user changes direction, rather than creating a competing guide.

No runtime, asset, quest or AGENTS.md changes were made for this planning section.

### 12.6 Implementation candidate: echo_garden_01

13 September 2026 follow-up: the first hero-tree/basin candidate is locally
implemented. The wider section 12 checklist remains incomplete.

Tracing `tools/blender/build_mind_spark_super_island_one_3000.py::build_garden`
confirmed the broad brown tree belongs to `MSI1_Runtime_Nature`: 120 root segments,
80 branch segments, 160 leaf facets and 60 planter/soil pieces. It is separate
from `CognitiveLightTree`, which is retained unchanged for puzzle teaching cues.

The world builder hides only that old Nature batch, protects it from rebatching,
and loads the replacement at the same transformed garden origin. The original
GLB/source remains recoverable. Other overlay roles, foundation, bridge collision,
quest controls and save contracts remain unchanged.

Candidate assets: `assets3D/mind_spark/echo_garden_benchmark/`:

- `source/echo_garden.blend`: 102 editable source mesh pieces.
- `export/echo_garden.glb`: six material-group meshes, 6,644 triangles.
- `manifest.json`: source/export counts and design parameters.
- Generator: `tools/build_echo_garden_benchmark.py`.

The replacement has a connected tapered trunk/branch system, nineteen grouped
canopy shapes, roots ending within radius 21 inside a radius-25 basin, and eight
spaced planted pockets. These are solid-color roughness/metalness materials;
fine bark/leaf textures, LODs and full close-range art acceptance are still pending.
No new blocking collision was added to the decorative tree or planters. This is
not proof of collision-complete garden assets or a full walking-clearance audit.

Passed: `test_echo_garden_hero_benchmark.gd` (six meshes, old layer hidden,
teaching tree retained, bridge collision and early-gate lock),
`test_island_one_science_art_harmony_v31.gd` (three creative solutions), and
`test_heavenly_quest_kit.gd` (both quests through gate completion and restore).

Actual local overview and detail captures:
`artifacts/island_one_overview/overview.png` and `echo_garden_detail.png`.
Floating labels are suppressed for these architectural views. They are not
first-person walking evidence or proof that the whole environment is finished.

The maintained non-Mono export included the replacement asset and generated 143
pack parts, but reported `TLS handshake error: -27648`. Production deployment
and new live browser verification were not performed. Existing UID and ObjectDB
warnings remain. No claim of clean release or measured whole-scene speedup.

Next review: judge the hero silhouette and basin proportions before repeating
this design across other trees. Continue with texture detail, operating-view
clearance, existing lighting glare and selective garden refinements after that
review. Original AGENTS.md unchanged; no Git commit or push.

### 12.7 Matching saplings and perimeter protection

13 September 2026 follow-up: Island One's forty organized grove trees now use
`echo_garden_benchmark/export/echo_sapling.glb`, derived in Blender from the hero
tree's trunk, roots and canopy. Other islands keep their existing grove style.
Generator: `tools/build_echo_sapling.py`; editable source:
`echo_garden_benchmark/source/echo_sapling.blend`.

For the standalone Island One layout, tree centers are clamped inward to local
radii 103 and 128 for the two districts. This addresses the screenshot's
tree/railing intersection; it is not a complete tree-to-tree or quest-view audit.

Source inspection found that the v11 inherited rail openings were calculated
from old six-island coordinates. The new `IslandOnePerimeterRepairs` adds a low
ivory/brass, collision-backed guard on the current exposed circular boundaries.
It skips ground inside the other lobe and preserves 30-unit half-width openings
toward Island Two and the return connection from Island Three. Existing ornate
railing artwork is retained. Projection/capital slabs outside the gameplay circle
are not assumed to be accessible balconies and are not newly made walkable.

`test_echo_garden_hero_benchmark.gd` now checks forty saplings, more than 100
repair collision bodies, and physical ray hits across the repaired segments,
as well as the preserved hero/teaching tree and quest lock. It passed; the full
`test_heavenly_quest_kit.gd` also passed in this pass. Latest native overview and
garden-detail captures are in `artifacts/island_one_overview/`.

Remaining: manually review complete perimeter traversal, exact screenshot angle,
all tree clearances and the low guard's visual fit against existing ornament.
This does not claim a complete architectural safety certification or clearance
proof from ray tests alone.

The maintained non-Mono export completed with 143 pack parts and without the
previous TLS error in this run. Deployment to the existing Vercel project failed
with `Not authorized`. No new production deployment ID or updated live Web
verification is claimed. Restore project deployment authorization before release.
No AGENTS.md modification, Git commit or push.

### 12.8 Reference-matched perimeter and planted saplings

13 September 2026 correction supersedes the plain low guards in 12.7.
`tools/build_echo_railing.py` extracts the original reference Panel_01 scrollwork
and Post_01 lantern/pier assembly, remapping them into reusable curved bays.
The first two districts' old `Railing_v11_*` batches are hidden and excluded
from batching. Matching panels and posts now cover exposed perimeter arcs;
short terminal bays are curved and their normals regenerated. Interior overlap
and current bridge openings remain clear. Collision-only edge segments provide
fall protection without adding a second visible barrier style.

Forty saplings now have contained soil, ivory basin rims, restrained brass
reveals, root flares and simple bed/trunk collision. Three shared GLB variants
use the same central-tree vocabulary; secondary variants omit canopy crests.
Editable sources are `source/echo_sapling*.blend` and the maintained generator
is `tools/build_echo_sapling.py`. Background variants are not independently
hand-authored species and no high-resolution bark/leaf texture claim is made.

Placement uses full canopy envelopes rather than radius clamping alone:
separate canopies, clear station operating space, gate exclusion and a clear
promenade toward the adjoining court and bridge connections. Existing quest
anchors, the central hero and teaching tree, and the three-island layout remain.

The local atmosphere now covers Island One views rather than only instrument
hotspots. Sun/fill energy and camera atmosphere are restored when leaving.
Opaque imported surface materials are included in the finish pass; formerly it
only covered material overrides. Native Mobile blue/black grazing-edge pixels
disappeared in the reviewed render after disabling specular on this local
scenery. This trades sharp mirror highlights for consistent matte gilding.
Glass and puzzle controls retain their own material behavior.

Verification this pass: enhanced hero test (40 saplings, three variants,
canopy separation, station clearance, exact perimeter ray collider and player
capsule sweeps), heavenly quest kit progression, fused-saddle/open-gate route
clearance, and Compatibility-renderer lighting capture/restoration all passed.
Native overview and player-height captures: `artifacts/island_one_overview/`.
These are actual scene captures with labels hidden for presentation, not
recordings of a complete human playthrough. Production status is reported
separately after export/deployment; no AGENTS.md edits, Git commit or push.

Release: final non-Mono export completed with 143 parts and no TLS error on
the final retry (an earlier attempt logged a TLS handshake error). The new
assets are explicitly present in the export log. Existing duplicate-UID and
two-object shutdown warnings remain outside this art correction.
Vercel deployment `dpl_F6DUfymSomLjvmSVaJWgXhvmTnQV` reached READY at
`https://artea-huoumu5ic-dsovann80-2407s-projects.vercel.app`.
The existing `https://artea-web.vercel.app/` alias was assigned to this build;
the project and public URL were not replaced. Browser verification follows.

Public verification on that deployment: the complete 1,139 MB asset download
finished, the Artéa start screen rendered, Offline Guest entered the coloured
playable hub, and the world map opened. Browser logs confirm WebGL 2.0 with
the Compatibility renderer. An existing Firebase missing-.env console error
remains; guest play worked, and online authentication was not tested or changed.
The exact Island One art and quest checks were performed in native/Compatibility
scene tests, not as a complete public-browser quest playthrough. Public hub
startup does not substitute for that remaining end-to-end island walkthrough.

### 12.9 Island One interactive instruments

Keep the existing instrument meshes, three-island layout and five-quest story.
Q opens the nearby instrument's untimed panel; Esc returns movement and mouse
control. Use readable ivory/teal/gold controls, explicit choices and feedback,
not hidden cycling as the only interaction. Existing direct interaction APIs
remain compatible with older tests and authored systems.

Quest One retains its evidence, pressure and coupled-constellation mechanics.
Players may undo up to 32 recent adjustments before earning the Signal Prism;
undo cannot revoke earned completion. History is session-local.

Quest Two requires installing that prism once, then visiting three receivers in
any order. Each receiver has eight phase notches and reversible two-/three-notch
gears. Match the green hand to the gold source marker before capture. The physical
valve also turns with phase. Captures cannot be duplicated. Classify the captured
statement using direct Fact/Possibility/Unsure buttons, choose a preparatory
question, and test the interpretation at the beacon. These are authored fictional
statements, not a judgement of the player's private emotions.

Persist prism installation, individual captures and phases alongside existing
quest state. Legacy collected counts migrate to individual captures. Completion
still awards the Echo Seed and opens the garden gate; the separate route onwards
still requires the existing checkpoints, Thought Spark relay and network encounter.
HUD numbering is consistently five quests, with a clear relay handover.

Regression coverage includes installation prerequisites, mismatched phases,
out-of-order captures, duplicate rejection, distance checks, direct UI selection,
movement restoration, partial-save reload, earned rewards, guidance and story gates.

Delivery evidence (2026-09-13): Quest One, Quest Two (including the new panel,
reverse gears and partial reload), detailed guidance, heavenly instrument kit,
first-person proximity journey and full story progression tests passed. Quest Two
also passed with the native Compatibility renderer. UI captures are under
`artifacts/interactive_quest/`. Non-Mono Web export succeeded (143 pack parts).
Production deployment `dpl_2tnkS2gkxBCuL7UE2iHVWEEWiW7X` is READY at
`https://artea-79g8rg9xe-dsovann80-2407s-projects.vercel.app`; the existing public
alias `https://artea-web.vercel.app/` was assigned to it and inspected.

Browser verification is incomplete: the new public build's loader advanced from
3% to 82%, then the browser inspection timed out during initialization. Reconnection
reported no available browser and discovery returned an empty list. No start-screen
or public quest-completion claim is made for this deployment. The existing UID
fallback/duplicate warnings and shutdown ObjectDB warnings remain; they were not
introduced or addressed as part of this quest change.

Verification retry (same deployment, 2026-09-13): the browser connection recovered
and the existing tab had reached the Artéa start screen. Offline Guest successfully
entered the coloured 3D hub; movement and the map responded to real browser input.
Console output confirms WebGL 2.0 / Compatibility. The earlier startup uncertainty
is resolved. Console errors remain for missing Firebase `.env` configuration and
`refresh_slots called but inventory_data is null`. No fixes were made during this
verification-only retry. Island One was not reached, so the complete public quest
playthrough remains unverified; native quest-test evidence is unchanged.

### 12.10 Island Two — evidence and memory pass

Preserve the three-island footprint and existing imported station models. Extend
the reversible warm camera-lighting profile and matte scenery finish to the
Constellation Court and Hope Path Ridge. Avoid extra bright cyan illumination:
ivory paving joints, brass trim and under-island machinery must remain legible.

The world-specific evidence scanner now reveals three authored practice-log cards.
Classify supported observations versus unproven predictions; a wrong choice gives
an explanation and cannot award completion. Save each secured card. Existing
completed saves remain complete, while partial legacy scans begin with card one.
The memory board no longer chooses its own next node when Q is pressed. Players
explicitly reconstruct observation → interpretation → action using labelled choices;
undo/reset preserve earned evidence. No timer or judgement of private feelings.
Both stations share Island One's accessible ivory/teal/gold panel, pause movement
while reading, enforce proximity and respect the existing story locks. Q opens the
panel; Esc restores movement. The existing linked Spark and Logic Gate requirements
are unchanged. This pass does not redesign the later lens, bridge or combat encounters.

Focused evidence: interactive-station tests passed in Compatibility rendering,
including UI button signals, wrong answers, locked stations, range checks, save
reload, undo and completed reward preservation. Memory mesh/state benchmark and
full story progression passed. Overview: `artifacts/island_two_overview/overview.png`;
station UI: `artifacts/island_two_interactive/evidence.png`.
The older `test_mind_spark_quest_objects.gd` reports socket texture/legacy component
assertion failures despite printing a success line; it is NOT a passing suite.
Those assertions concern the older socket model, not the new evidence/memory path.

Island One echo, warm-surroundings and heavenly-kit regressions also passed.
The non-Mono Web export succeeded with 143 parts and no script/export errors after
temporarily disabling the dialogue editor's optional update check. Prior attempts
logged a TLS handshake error; disabling that editor-only check eliminated it.
The original `check_for_updates: true` preference was restored immediately after
export. Runtime dialogue/network behavior and original AGENTS.md were not changed.

Published deployment: `dpl_BJivhUM3P2iQMF7HTM9jHFBixAvM`, READY at
`https://artea-clqf17cho-dsovann80-2407s-projects.vercel.app`, assigned to the
existing `https://artea-web.vercel.app/` alias. Browser verification on the new
cache-busting URL completed the 1,139 MB download, rendered the start screen and
entered the coloured Offline Guest hub. Logs confirm WebGL 2.0 / Compatibility.
The current startup still logs missing Firebase `.env`; the tab also retains
older pre-navigation `Cane_Walk` animation errors, not evidence of an Island Two
regression. The full public-browser Island Two puzzle walkthrough remains
unverified. Local interactive-station and full story tests are the changed-path
evidence; public hub startup is not a substitute for that walkthrough.

### 12.11 Memory-board family — 2026-09-13

The approved memory board is the visual benchmark for the eleven other core
quest-object types: spark socket, evidence scanner, perspective lens, logic
gate, truth tile, focus bell, warden anchor, calm basin, reflection mirror,
checkpoint archive, and path projector. Repeated checkpoints and anchors reuse
these models. The memory board itself and Island One's separate fifteen-tool
instrument kit are retained, not rebuilt in this pass.

Use layered ivory plinths, a restrained brass reveal, recessed teal enamel,
mint state indicators, beveled low-poly silhouettes and the shared quiet-surface
atlas. Different functions retain different silhouettes. Do not replace every
tool with a ring or increase object counts merely to add detail.

Rebuild with `tools/build_memory_style_quest_family.py` in Blender. Each asset
has an editable `.blend` and a runtime `.glb` below
`assets3D/mind_spark/quest_kit/memory_style_family/`. Source parts remain separate;
static export geometry is joined. Each model uses four atlas materials and
5–7 runtime mesh nodes, with 616–2,944 triangles (see the generated manifest).
Moving parts remain separate for quest-state updates; triangulation alone is
not treated as smooth shading or visual quality.

The adapter is restricted to `world_one.*` core instances. Existing state keys,
quest order and physical collision nodes remain intact. Socket charges, scanner
position, lens angle, gate lift, anchor reward and status windows read existing
state. Hint arrows and route guides are not hidden with replaced legacy surfaces.
Labels clear the taller housings; the three-card scanner reports a denominator
of three. Five station positions were adjusted away from canopy rails, roots
and Hope Path platform edges; the district-specific alternate layout is unchanged.

Verification: `test_memory_style_quest_family.gd` checks all eleven types,
mesh-count budget, live indicator states, socket charges, gate travel, collision
retention and persisted-state reload. Compatibility-renderer screenshots are in
`artifacts/memory_style_family/`. Full story, interactive Island Two stations,
reference-memory benchmark and Island One echo tests passed. The separate
heavenly-kit assertions passed but its dummy-renderer shutdown reports a shader
RID leak; several suites also report ObjectDB shutdown leaks. These diagnostics
are not represented as a clean full-suite result.

Release evidence: standard non-Mono Web export succeeded with 144 PCK parts and
no export/script errors. The optional editor update preference was restored.
Deployment `dpl_AQ6iFeXqwmEwnCspgLwDtFpUSFbG` is READY at
`https://artea-c1u23hf9m-dsovann80-2407s-projects.vercel.app` and serves the existing
`https://artea-web.vercel.app/` alias. The cache-busting public URL finished its
1,150 MB initial load, rendered the start screen and entered the coloured Offline
Guest hub. Browser logs confirm WebGL2 Compatibility. The existing missing
Firebase `.env` error remains. This is startup verification, not a complete
public-browser quest walkthrough. The Zone 02 route-clearance regression also
passed after the station position changes. No commit or push was performed.

### 12.12 Quest layout consistency audit

The follow-up acceptance checklist and findings are in
`MIND_SPARK_QUEST_LAYOUT_CHECKLIST.md`. It supersedes the first family pass's
label spacing, material values, indicator counts and arrival/bell placements.
Use the reference board's exact material settings; use one physical light for
binary actions, two for the evidence gate, and three for three-stage tasks. Place engraved action plates on
upright cabinets, keep two compact lines above the silhouette, and keep optional
hint text clear of the housing. Shared camera-local lighting extends to close
quest views on later islands. Current exports use 3–7 mesh nodes; the source
manifest remains authoritative for each asset's updated count.

Current layout release: `dpl_8EYxihtj5jBhc9E6u49ZBS6vhjpy` at the existing
public alias. WebGL2 and Offline Guest startup verified; Firebase configuration
and guest inventory-null errors remain. See the layout checklist for evidence
and the explicitly unverified full-browser walkthrough.
