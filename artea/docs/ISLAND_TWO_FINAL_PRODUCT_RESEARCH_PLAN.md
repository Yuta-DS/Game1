# Island Two production design and release plan

## Decision

Develop Island Two as the **Garden of Unfinished Light**: a heavenly botanical
research campus where players investigate an interrupted experiment and help
Ari restore it. Preserve the existing two-lobe foundation, both external bridges,
three-island world, five world quests and existing progress identifiers.

The production target is a coherent playable place, not a denser collection of
props. Architecture must establish destinations; objects must communicate their
function; controls must produce observable consequences; the released Web build
must support the same experience as the approved art. Complete one representative
research bay to release quality before propagating its design to the island.

This is a research-backed proposal, not an implementation-completion report.
Numerical budgets below are initial project targets requiring measurement, not
industry standards or measured current performance. Audience reading level and
minimum supported hardware remain release decisions to confirm.

## 1. Evidence and current limitations

Local evidence includes the current native overview and shared-lantern capture,
the player scene/controller, Island Two layout builder, puzzle rules and existing
architecture checklist. The screenshot shows a developed foundation and border,
but sparse, weakly framed activity areas inside it. Many ornamental lamps are
more visually dominant than the instruments. Thin canopy ribs and small trees
do not yet establish a convincing laboratory or conservatory.

The current base player is approximately two world units tall, with default
movement speed 10 units/second and jump height 1.4. Both the main project and
capture project specify the Mobile renderer. Godot's Web export uses
Compatibility/WebGL2, not Mobile; therefore the native captures are not evidence
of Web appearance or performance. [1]

Recent focused tests establish useful but limited facts: 39 visible perimeter
posts remain after consolidation; no tested pair is within the 14-unit spacing
threshold; 217 sampled exposed-edge rays hit protection; tested bridge sections
block the player capsule at the sides. These do not prove continuous perimeter
coverage, every seam, camera clearance or resistance to jumping around gates.
The Island One safety test reports a cabinet obstructing the west-regulator
approach. Its cause needs investigation before a clean end-to-end release.

The puzzle code contains fixed scanner settings, one accepted explanation,
matching viewpoint/answer indices, and discrete coupled optical controls. It
preserves state and offers revision, but much of the understanding is currently
carried by text. Finishing the art without improving these representations
would produce a polished-looking prototype rather than the intended game.

## 2. Research translated into design decisions

| Evidence | Application to this island | Limit of the comparison |
|---|---|---|
| Epic recommends identifiable landmarks, readable navigation and avoiding excessive prop density. [2] | Frame the research court and garden as distinct destinations; leave a clear main route between them. | Its combat guidance is not a reason to introduce combat here. |
| Riot discusses art, performance and gameplay clarity as joint constraints, with controlled material responses. [3] | Instruments receive the strongest local contrast; ornament is quieter; quality settings must not hide puzzle evidence. | Do not copy VALORANT's shader implementation or competitive gameplay assumptions. |
| Kew's Palm House is an iron-and-glass architectural reference; tinted glass served a practical horticultural purpose. [4] | Give the conservatory complete structural ribs, glazing divisions, ventilation and irrigation rather than disconnected decorative arches. | Floating islands and their lift engines remain fantasy, not engineering claims. |
| Godot identifies transparency, lighting and unnecessary rendered geometry as performance concerns; LOD and MultiMesh are available approaches. [5] | Use limited glazing, shared opaque material families, region-sized instancing and distant machinery simplification. | Instancing does not eliminate collision, animation or transparency costs. |
| Xbox accessibility guidance recommends multiple information channels and adjustable difficulty support. [6][7] | Pair colour with icons/text, caption essential sounds, and offer hints without dexterity penalties. | This is guidance, not a claim of accessibility certification. |

Use the earlier Piltover reference as a mood direction: civic craftsmanship,
scientific optimism and refined machinery. The proposed original design combines
that mood with botanical glasshouse structure, warm ivory, restrained brass and
green planting. It does not depend on copying franchise symbols or asserting a
particular historical style label as canon.

## 3. What to preserve, redesign and retire

| Preserve | Redesign | Retire only after dependency audit |
|---|---|---|
| Three combined islands and foundation silhouettes | Instrument housings and their surrounding research bays | Duplicate construction layers occupying the same footprint |
| Existing bridge decks and landing elevations | Bridge-to-gate visual transition and gate-side seating/planting | Raised decorative strips that obstruct movement |
| Curved barrier kit and shared junction posts | Lantern size hierarchy and material response | Unexplained glowing discs, rings and hovering markers |
| Quest IDs, completed achievements, observations | Observation presentation, timeline replay and optical manipulation | Old instruction text contradicting the new storyline |
| Internal archive gate and external departure gate roles | Conservatory roof, living projector and Ari staging | Obsolete combat prompts on peaceful Island Two |

Retiring an object means removing its runtime presentation and obsolete collision
after confirming ownership, not deleting authored source assets. Do not hide a
functional station simply because its current model looks out of place.

## 4. Spatial blueprint

```text
ISLAND ONE
    │ existing incoming bridge
    ▼
Arrival portico ── Echo Seed reception / orientation
    │
    ▼
RESEARCH COURT — larger lobe
    inspection bay → recorder bay → explanation-testing bay
    │                 central observatory landmark
    │                 quiet perimeter reading pockets
    ▼
Archive threshold — internal chapter gate, continuous floor
    │
    ▼
CONSERVATORY — smaller lobe
    perspective workshop → living projection garden → Ari reflection
    │                    cooling/service equipment at the side
    ▼
Departure forecourt — gate on the island, before the bridge
    │ existing outgoing bridge
    ▼
ISLAND THREE
```

This is an adjacency blueprint, not a replacement coordinate map. Retain the
canonical station layout as the starting point, then validate the actual walking
route before freezing new positions. A single layout definition must own each
station position, operator point, facing, footprint and approach exclusion area.
The art, collision, quest guidance and test data must read that same definition.

### Arrival and research court

The arriving player should see the receiver and the research-building entrance
without a large UI arrow covering the scene. Keep the arrival portico open after
Island One completion; do not introduce another lock before the first task.
Place a compact orientation panel on the approach side rather than behind the
player. Introduce Ari's interrupted experiment with a brief, replayable scene.

Turn the existing observatory framing into a low pavilion with three open work
bays and a taller optical roof lantern. The pavilion groups the scanner, recorder
and model test into one workplace, while each bay has a different silhouette.
Keep the working faces visible from the path. Put storage, maintenance hatches
and piping behind or beside the worktops, not across the operating apron.

### Conservatory and reflection garden

Complete a restrained glasshouse around the living projector. Primary columns
support arched ribs; ribs carry secondary glazing bars; glazing terminates in
frames. Put planters at the edges and a walkable observation aisle around the
projector. Avoid a transparent dome covering the entire island.

The perspective workshop introduces three views of the same event: Ari's
experience, the mechanism, and available help. The garden then makes each chosen
repair approach visible. Ari's reflection position is beside the restored garden,
outside the operator area, with a clear line of sight to the departure gate.

### Bridge, gate and perimeter transitions

Retain two separate gate functions: the archive gate controls the internal chapter;
the departure gate controls travel to Island Three. Neither should block an
instrument needed to open it. Retain the departure gate's 22-unit rim setback
until player-camera testing demonstrates a better location.

At each bridge junction, resolve rail ends into deliberate terminal piers. Do not
leave a numerical opening without checking the physical corner between the
curved island rail and straight bridge parapet. Shared piers must support the
visible rail ends after clustering; spacing alone is not sufficient evidence.
Check closed, opening, obstructed, open and closing gate states from both sides.

## 5. Scale and composition contract

Start from the active player's capsule and camera, including any host-scene scale
overrides. Use ordinary player-height screenshots as the approval view; overhead
renders are secondary. Proposed starting dimensions are 4–6 units clear for local
walkways, a 4-by-4-unit operator apron and hand controls around 1–1.5 units above
the standing surface. These must be tuned for the actual avatar, not copied
blindly into existing oversized models.

Keep the existing 28-unit bridge structure. It can read as a broad civic bridge
without filling its full width with gameplay props. Do not narrow collision
independently of visible geometry. Gate swing clearance must use the actual leaf
shape plus a small tested margin, not a guessed radius or instantaneous teleport.

Use three levels of visual prominence: one landmark per lobe, recognizable
instrument silhouettes, then restrained fittings. At an instrument, its movable
control and output must attract attention before the railing lantern behind it.
Reduce ornamental prominence where needed without making the route unlit.

Measure walking time between tasks after movement tuning. An initial target is
5–12 seconds between adjacent research activities, excluding optional exploration.
Longer empty walks need a reason, a view, or a route adjustment—not more random
props. This target is a design hypothesis to test with unfamiliar players.

## 6. Reusable asset specification

| Assembly | Editable components | Visible function and acceptance |
|---|---|---|
| Research bay | Plinth, worktop, cabinet, backboard, lamp, control mount, conduit socket | Grounded; knee/approach clearance; no floating console; readable without labels |
| Scanner | Lens cradle, rotating lens, sample holder, focus drive, trace screen | Focusing visibly sharpens the same trace the player records |
| Recorder | Drum, strip guides, event tiles, replay lever, pointer | Tile order drives an animated event replay, not just a success label |
| Model tester | Valve block, shutter, flow meter, selectable linkage | Selected explanation predicts a visible sequence; contradiction is shown |
| Perspective instrument | Three viewing positions, lens frame, view selector | Each view reveals different information about one event |
| Living projector | Base, cooling manifold, mirror pivot, shutter, plate cradle, articulated leaf bed | Each control moves a corresponding part; supports and pipes connect |
| Conservatory bay | Foot, column, capital, main rib, glazing bar, pane, vent | Complete load-path appearance; modular end and corner variants |
| Garden bed | Retaining shell, soil, edge planting, mature plant, irrigation branch | Planting grows from soil; access paths and sightlines remain clear |
| Gate kit | Piers, arch, leaves, hinges, stops, actuator, threshold | One mechanical owner per leaf; ornaments and collision follow it |
| Perimeter kit | Full/short curved bay, corner connector, terminal/shared pier | No duplicate lamps, unsupported rail ends or blocked openings |
| Bridge kit | Existing deck, parapet, cap, pier, lantern, transition connector | Continuous floor and side protection through slopes and junctions |

Keep editable components in Blender source. Export static pieces in sensible
material/region groups, with moving parts separate. A source with many editable
pieces does not require an equally large runtime node count. Do not impose a
3,000-part target: it says nothing about readability or frame time.

For low-poly quality, model silhouette and visible bevels, use deliberate hard
and smooth normals, and put fine panel detail into shared textures where useful.
Triangulation controls export topology; it does not by itself smooth a surface.
Inspect the imported GLB under the target lighting for normal seams, missing
faces and material changes. Use additional geometry where the player can see its
effect, not on unseen bolt threads.

## 7. Materials, lighting and sound

Proposed shared material starting points:

| Material | Base colour | Roughness starting range | Role |
|---|---|---|---|
| Warm ivory stone | `#E7DFC9` | 0.65–0.85 | Primary structure, soft broad shading |
| Brushed brass | `#B49150` | 0.35–0.55 | Mechanisms and limited trim |
| Deep teal enamel | `#285A59` | 0.4–0.6 | Instrument background and control contrast |
| Sage foliage | `#63866A` | 0.75–0.95 | Quiet garden mass |
| Dark green foliage | `#365E49` | 0.75–0.95 | Canopy depth and grouping |
| Pale glass tint | `#B7D6CB` | Tune in Web | Small framed panes, not opaque cyan slabs |

These values are art starting points, not measured physical materials. Give metal
and stone different responses. Add subtle roughness variation and restrained
joint shading; avoid noisy dirt that conflicts with the heavenly atmosphere.

Approve lighting in Compatibility first. Use one coherent sun/sky direction and
controlled ambient fill; lamps can appear luminous without each casting expensive
real-time shadows. Test baked static lighting only after deciding how procedural
geometry will be authored or instantiated for baking. Do not promise lightmaps on
runtime-generated geometry without a working pipeline. [5]

Provide distinct sounds for focus detents, recorder replay, valve flow, alignment,
gentle unsuccessful attempts and gate release. Essential evidence must remain
understandable with audio muted. Web audio playback has mode-dependent limitations;
verify actual playback rather than relying on native effects or procedural audio.
[1] No flashing success effect or forced camera shake is required.

## 8. Puzzle-to-environment redesign

### Quest three: understand the moment

Scanner adjustments should reveal a trace with evidence, rather than reward an
unexplained numerical setting. Replay should expose observation times and causal
uncertainty. Players record what happened, reorder events and compare a proposed
explanation with an experiment. An incorrect model should demonstrate the
contradiction while keeping verified observations.

The current causal wording needs correction before final dialogue: the code lists
beam drift before a cooling fall and accepts a flow-loss model. That order alone
does not establish that cooling loss caused the earlier drift. Either show an
earlier pressure decline with a justified delayed gauge reading, or describe drift
as a separate observation and limit the explanation to shutter closure. Do not
require players to guess an unstated cause.

Proposed canonical experiment: a restricted test line reduces measured flow, the
protective shutter closes, and opening the bypass restores flow and releases it.
Ari's touch happened after the first recorded anomaly. This demonstrates why the
available evidence does not justify blaming Ari; it does not prove an unrestricted
claim about every possible cause. Update all recorded strips, dialogue and tests
together once that sequence is approved.

### Quest four: build a possible tomorrow

Preserve three useful approaches: test a smaller bed, work with Ari, or restore
cooling first. Make them differ visibly in constraint, not merely in target digits:
small test uses a smaller receiver area; Ari holds a reference component; cooling
first releases the protective shutter. Use consistent optical feedback and allow
undo, replay and local reset.

Keep the existing discrete solver as a deterministic foundation, but drive world
parts and overlays from the same state. Do not imply the current coupled integer
controls are a physically accurate optics simulation. If mirror reflection is
presented as science, explicitly model and test the relationship being taught;
otherwise frame it as a fictional light-pattern instrument.

Avoid making emotional interpretation a one-correct-feeling quiz. Ari's feeling,
mechanical evidence and an offer of help are different kinds of information, not
rankings of good and bad people. Retain the Everlasting Father as a source of
encouragement. The final reflection should recognize investigation and a useful
next step, not claim that difficult thoughts have been permanently eliminated.
This is an educational narrative, not a clinically validated intervention.

## 9. Interface and accessibility contract

One interaction system must support pointer and keyboard navigation. Show focus,
the action available, a short explanation and an optional deeper hint. Closing
inspection restores the previous camera and input state. Do not rely on colour
alone: each channel needs a shape or name, each changed state a visible indicator,
and essential sound a visual equivalent. [6]

Offer progressive hints: remind the goal, highlight relevant evidence, then
demonstrate one action. Keep the same underlying puzzle and reward; do not punish
players for requesting help. Difficulty support should address reasoning and
input demands separately. [7] Confirm intended age/reading level before final
dialogue and testing. No diagnosis or private emotional disclosure is required.

## 10. Technical architecture and performance

Separate four responsibilities: persistent puzzle state; input actions; visual
state presentation; and layout/collision. A single reset transaction must update
all of them consistently. Preserve legacy IDs and version saved state explicitly.
Test the existing reset path in particular: it currently clears some optical
fields without clearing every auxiliary field, such as cooling/view state.
Specify intended reset semantics rather than assuming this is harmless.

Use shared meshes/materials for repetitions and spatially bounded static batches.
Keep gate leaves, mirrors, shutters, recorder parts and animated plants out of
static merges. Godot's automatic instancing is Forward+-specific; Web must not
depend on it. Use explicit MultiMesh where appropriate and keep transparent
surfaces limited. [5]

Proposed performance gates: choose one named minimum test machine/browser, target
at least 30 FPS at 1280×720 on it, and aim for 60 FPS on the agreed reference
machine. Record frame-time distributions, not only an average. During a repeatable
five-minute route, investigate p95 frames above 33.3 ms on the minimum machine and
repeated stalls above 100 ms. These are unvalidated targets until measured.

Record draw calls, visible triangles, texture memory, CPU/GPU time and download
size before adding new art. Allocate budgets from that baseline; do not invent a
universal safe polygon count. Keep low-quality mode's puzzle evidence identical.
Assess distant under-island machinery and other islands for LOD before reducing
the detail of objects the player operates.

## 11. Delivery sequence and acceptance gates

| Stage | Deliverable | Acceptance evidence |
|---|---|---|
| A — baseline | Cleanly reproducible test build, state inventory, render comparison | Known failures documented; Compatibility capture; named hardware and storage plan |
| B — player layout | Complete main route and station approach envelopes | Input-driven arrival-to-exit recording, both gate directions, corners, jumping, camera sweep |
| C — finished benchmark | One complete inspection bay | Final GLB, materials, collision, UI, sound, save/reload and player-height Web capture approved together |
| D — research chapter | Recorder/model tester and finished pavilion | Evidence supports the solution; wrong attempts teach; no reset or unlock softlocks |
| E — conservatory chapter | Glazing, planting, projector, Ari and reflection | Three approaches visibly distinct; garden restoration and departure cue understandable |
| F — consolidation | Matching bridges, rail junctions, signage and landscaping | Full perimeter visual audit and continuous player tests; no duplicate owners or floating supports |
| G — release candidate | Optimized complete Web build | Performance targets met; save migration; accessibility/input matrix; real production browser playthrough |

No reliable calendar estimate is possible before the finished-bay benchmark and
Web profiling establish asset and iteration costs. Do not label a stage finished
because its nodes exist or a distant screenshot looks attractive.

For the first benchmark, deliver front/side/back views, exploded source assembly,
player approach view, idle/adjusting/recorded states, collider overlay, texture
atlas and profiler capture. This is the reusable standard for all later objects.

## 12. Final-product checklist

- [ ] Target audience, reading level, input devices and minimum hardware agreed.
- [ ] Every main-route floor seam traversed using actual player input.
- [ ] Gate cannot crush, clip, strand or be bypassed through an unintended gap.
- [ ] Every decorative replacement has an identified owner and collision policy.
- [ ] Every instrument is recognizable and operable from its intended approach.
- [ ] Every puzzle has observable evidence, useful feedback and a supported solution.
- [ ] All three repair approaches pass; reset, undo and partial reload are tested.
- [ ] Old saves preserve achievements without duplicate reward or missing unlocks.
- [ ] World animation, UI and saved state agree after interruption/re-entry.
- [ ] Required information works without colour or sound alone.
- [ ] Text/input tested at 720p and larger screens, with visible keyboard focus.
- [ ] Final art approved at player height in the Web renderer, not only native.
- [ ] Frame times, memory and cold/warm loading measured on named hardware.
- [ ] No unresolved startup, missing-resource or gameplay-console errors.
- [ ] Full non-Mono export, production deployment and browser traversal completed.

The last measured free storage was approximately 466 MiB; the source asset set is
multi-gigabyte. Full import/export remains blocked until enough working space is
available. This does not block design planning, but it prevents release approval.
The required production destination is the existing Artea Web project; do not
replace it with a reduced demo and call the full game delivered.

## Sources and local evidence

Web sources consulted September 14, 2026. Stable documentation is mutable; pin
the project's engine version and re-check the applicable features at release.

1. Godot documentation, [Exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html). Renderer, browser and audio constraints.
2. Epic Games documentation, [Level Design Best Practices](https://dev.epicgames.com/documentation/en-us/fortnite/level-design-best-practices-in-fortnite-creative). Density, navigation and landmarks.
3. Brandon Wang, Riot Games, [VALORANT Shaders and Gameplay Clarity](https://www.riotgames.com/en/news/valorant-shaders-and-gameplay-clarity), June 30, 2020. Historical production example; not a Godot implementation recipe.
4. Royal Botanic Gardens, Kew, [Secrets of the Palm House revealed](https://www.kew.org/read-and-watch/palm-house-secrets-facts). Botanical architecture and functional glazing reference.
5. Godot documentation, [Optimizing 3D performance](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html). Transparency, LOD, instancing and lighting considerations.
6. Microsoft, [Xbox Accessibility Guideline 103](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103). Additional channels for visual and audio cues.
7. Microsoft, [Xbox Accessibility Guideline 108](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/108). Difficulty and assist considerations.

Local evidence: `scripts/mind_spark/island_two_memory_campus.gd`,
`scripts/mind_spark/unfinished_light_rules.gd`, `player_3d.gd`,
`scenes/player_3d.tscn`, `project.godot`,
`docs/ISLAND_TWO_PLAYER_ARCHITECTURE.md`, and
`artifacts/island_two_overview/shared_lantern_pier.png`.
Observed source facts, earlier test records and proposed targets are distinguished
above; no new gameplay or production deployment was performed for this report.
