# Heart Melody Island 1 — Prototype Audit

Audit date: 2026-09-15

## Verdict

Island 1 is now a compact functional gameplay alpha aligned to the detailed implementation brief. Its progression state, save safety, gate integration, fixed rhythm, progressive hints, enemy rewards, retry rules, full route, full-lobe collision and baseline accessibility settings are implemented and covered by focused tests. The visual scene now uses authored hero GLBs and batched nature dressing, but final lighting, authored audio, complete restoration animation, culling and Web acceptance remain production work.

## Requirement status

| Area | Status | Evidence and gap |
|---|---|---|
| Compact 200 × 120 m visual footprint | Implemented | Two six-sector overlapping natural lobes use the approved compact proportions. |
| Fully walkable footprint | Implemented | Full-diameter simplified floor colliders cover both visible lobes; perimeter barriers bound inaccessible corners. |
| Main route and return traversal | Implemented | Automated player traversal covers the authored route in both directions. |
| World 1 architectural family | Early blockout | Ivory, gold, stone, rails and edge arches exist, but broad deck rings, radial paving, layered cornices, substantial arch bays, terraces and detailed foundations are not readable in the captures. |
| Low-poly nature style | Improved alpha | Three authored tree variants, hero garden props, rocks and batched foliage create a denser readable composition within the compact footprint. Final material and lighting polish remains. |
| Landmark layout | Mostly implemented | Gate, cast, planters, blossom, drums, clearings, lanterns, benches and overlook exist near the planned coordinates. Several assets are too small to function as distant landmarks. |
| Two required tasks | Implemented | Stable task and quest IDs, fixed phrase, wave gates and exactly-once 119 XP are present. |
| Feeling Seed interaction | Partial | All seven choices, cancellation, confirmation and later recolouring work. Preview lacks the promised flower colour and icon presentation. |
| Rhythm interaction | Implemented alpha | Replay, input, undo, reset, confirm and a three-level hint ladder work; wrong phrases persist and the required next flower pulses during advanced help. |
| Combat | Mostly implemented | Stats, phases, telegraphs, recovery-only damage, assist multipliers, leash reset and XP receipts are implemented. Pause-menu suspension and automatic retry presentation are not verified. Released creatures only change colour; their calm living forms are not clearly distinct. |
| Checkpoints and save recovery | Mostly implemented | Atomic temporary replacement, backup recovery, rollback and stable receipts work. Every checkpoint/reload combination and interrupted bridge growth are not covered. |
| Support objects | Partial | Lantern healing/checkpoints and the route map work. Benches reuse the rhythm panel and do not provide note icons or a distinct Guardian hint. Recovery blooms are decorative markers only. |
| Identity moments | Implemented with weak presentation | Four optional choices and Keep Private are stored correctly. They appear sequentially inside a generic menu instead of at authored story moments in the landscape. |
| Audio state | Missing major requirements | The prototype synthesizes three short tones. It has no wind bed, synchronized planter stems, combat percussion, restored harmony layer, or authored Web-safe flower audio. |
| Restoration state | Partial | The bridge grows and objective changes. Lighting, environment colour, flower banks and ambience do not visibly transform from silent to restored. |
| HUD and map | Partial | Objective, prompts, touch controls, settings and local/full map exist. Mobile text is too small, the full-map route is hard to discover on narrow screens, and the map omits checkpoints and exit symbols. |
| Scene architecture | Does not match plan | `HeartGardenWorld` is 765 lines and still owns UI, audio, encounters, dialogue and quest flow. Planned QuestController, EncounterController and HUD components do not exist. |
| Reusable objects | Partial | Planters and drums are packed scenes, but several support objects and bridge logic are built procedurally. `HeartGardenObject` lacks the planned `configure`, `completed` and `hint_requested` interface. |
| Asset delivery | Partially integrated | Runtime now uses authored gate, route stone, planters, drums, listening blossom, benches, lanterns, three tree variants and vine bridge. Remaining kit families still require player-height visual acceptance. |
| Culling and LOD | Missing | Sectors have metadata but no visibility ranges or runtime culling controller. Trees, arches and foundations do not have working high/medium/low switching. |
| Frame-spread construction | Missing | `ensure_world_built()` constructs the entire world synchronously. |
| Performance verification | Partial | The compact build passes 27,034 static triangles, 478 surfaces and 125 peak nearby surfaces. Actual rendered draw calls, construction frame time, memory and Web frame rate remain unprofiled. |
| Production deployment | Partial acceptance | WebGL2 and Offline Guest startup passed without console errors. The cold build is about 1.196 GB and took roughly four minutes. A full production quest run was not completed because a fresh guest correctly lacks the Star of Wisdom prerequisite. |

## Priority improvements

### P0 — Make the entire visible island physically honest

1. Add pause-menu combat suspension coverage using the real pause menu during telegraph and attack phases.
2. Add checkpoint reload cases for arrival, planter court, midpoint, restored garden and interrupted bridge growth.
3. Extend collision probes from representative lobe edges to every perimeter opening and restored bridge edge.

### P1 — Bring the environment to the approved visual target

1. Build readable district silhouettes: a sheltered meadow court around the gate and tree, a terraced planter court, a circular drum lawn, enclosed combat gardens and a ceremonial overlook.
2. Replace thin path strips with 6–7 m paths that use curved paving modules, borders, radial inlays and short stair terraces.
3. Add World 1-style layered edge construction: large arch bays, square piers, cornices, gold rail panels and visible root buttresses under both districts.
4. Increase nature density with clustered trees, hedges, tall grasses, flower banks, vines, rocks, water pockets and canopy framing while preserving camera corridors.
5. Give every quest object a readable silhouette and apron. The gate, planters, drums, blossom, lanterns and encounters should be recognizable from 25–50 m away.
6. Add a meaningful Island 2 teaser: layered distant terrain, moving water or mist, large musical reeds and a clear blocked continuation.

### P1 — Complete story and sensory progression

1. Stage Milo and Mother Guardian as separate authored conversations with camera-safe standing positions and visible dialogue beats.
2. Place the four identity moments at specific landmarks rather than serving them one at a time from one generic menu.
3. Upgrade seed preview to show flower model, colour, icon, name and note before confirmation.
4. Make the hint ladder pulse the exact next drum and display the same symbol in the HUD.
5. Give released enemies separate calm moth and slime forms instead of recolouring the shell.
6. Add a visible restoration sequence that changes flower density, environment warmth, particles, water, lighting and bridge growth.

### P1 — Implement the planned audio design

1. Add a quiet wind bed and sparse notes before planting.
2. Add one synchronized melodic stem per planted seed.
3. Add distinct authored Leaf, Sun and Droplet one-shots.
4. Add muted combat percussion that layers under the melody.
5. Add the restored harmony layer after completion.
6. Route all scheduled playback through a cancellable audio controller so mute immediately stops active and delayed cues.

### P2 — Refactor for maintainability

1. Reduce `HeartGardenWorld` to activation, checkpoint restoration and Castle integration.
2. Extract `HeartGardenQuestController`, `HeartGardenEncounterController` and `HeartGardenHUD` as planned.
3. Complete the reusable quest-object interface with `configure`, `completed` and `hint_requested` signals.
4. Remove the unused duplicate `_build_departure()` implementation from `HeartGardenWorld`.
5. Instantiate the delivered GLB kit in the runtime scene and make tests prove each required asset is actually used.

### P2 — Finish performance and release acceptance

1. Add real distance visibility ranges or sector culling and working high/medium/low variants.
2. Organize vegetation into actual approximately 50 m MultiMesh cells rather than one 900 m-wide instance group.
3. Spread construction over frames and measure maximum frame time during first entry.
4. Capture Godot frame metrics for visible triangles, draw calls, frame time and memory from every acceptance viewpoint.
5. Reduce the 1.196 GB Web cold download by auditing export filters and large unrelated assets.
6. Complete the production flow with a seeded test journey: Castle gate, both tasks, both waves, reload, overlook and Castle return.

## Recommended next milestone

Treat the next pass as an environment and presentation milestone rather than adding new mechanics. First fix full-footprint collision, then rebuild Quiet Meadow, planter court, drum lawn, combat clearings and overlook as five dense visual compositions. Add the audio and restoration state after those spaces have final landmark positions. Refactor the world controller before expanding to Island 2 so the current 765-line script does not become the foundation for the remaining islands.
