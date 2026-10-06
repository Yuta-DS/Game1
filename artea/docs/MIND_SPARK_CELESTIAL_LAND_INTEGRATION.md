# MindSpark celestial land integration

Historical v07 integration report. The six-design v08 foundation family
is documented in [MindSpark island variants](MIND_SPARK_ISLAND_VARIANTS_V08.md),
followed by the current [v09 detail pass](MIND_SPARK_ISLAND_DETAIL_V09.md).
The v07 authoring master and runtime asset remain preserved.

## Scope

The six standalone World One land foundations now use the approved v07 twin-vessel
condenser architecture: ivory radial paving, stone arches and buttresses, pale rock
anchors, brass/copper distribution pipes, and the under-deck maintenance balcony.
The clock-like regulator is not reintroduced.

The existing Art Castle World Gate already instantiates this six-island builder.
Its lazy-on-Web construction is preserved. Neither the compact Art Castle Mind
district nor the optional railway station is replaced.

## Preserved gameplay

| Island | Centre (world-local x, y, z) | Radius |
| --- | --- | --- |
| World Gate Landing | -960, 2, 420 | 125 |
| Living Network Forest | -800, 12, 100 | 190 |
| Constellation Court | -300, 24, -220 | 175 |
| Hope Path Ridge | 170, 40, 120 | 120 |
| Thought Storm Arena | 620, 58, 20 | 210 |
| Oldest Tree Sanctuary | 940, 84, -420 | 180 |

The floor bodies, friction, bridge topology, route gates, transit destinations,
recovery volumes, trees, quests, enemies, rewards and completion-only station
remain owned by the existing builder. The imported shell has no collision bodies.
Only the floor backing material is recoloured; shared Bio-Data Tree materials are
not changed.

## Authoring versus runtime

- Editable master: `assets3D/mind_spark/celestial_condenser_v07/source/celestial_condenser_v07.blend`.
- Runtime asset: `assets3D/mind_spark/celestial_land_runtime/celestial_land.glb`.
- Rebuild: `rtk /opt/homebrew/bin/blender --background --python-exit-code 1 --python tools/blender/bake_celestial_world_land.py`.
- Provenance and measured counts: `assets3D/mind_spark/celestial_land_runtime/build_manifest.json`.

The master remains 3,000 independent parts. The runtime land derives from 1,720
of them, including all 80 condenser pieces, and batches them into five mesh
families. All six islands share those mesh resources. Simplification happens
inside individual source parts before batching, not across the whole sculpture.
The build verifies that the source file checksum remains unchanged.

The concept's 1,280 railing/lamp, upper-access, basin and garden pieces remain in
the master but are not enlarged onto the playable islands. Doing so would create
giant furniture across established gameplay paths. Existing in-game props stay
in their original places. Raised floor inlay is flattened to a shallow reveal,
less than 0.095 game units above the existing collision plane.

This is a visual foundation replacement, not a new machine simulation, redesigned
quest system, collision-mesh replacement, or full restyling of every existing prop.

## Verification entry points

- `scripts/test_mind_spark_celestial_land.gd`: original footprints, real mesh
  vertices, shared resources, triangle budget, no imported obstacles, perimeter support.
- `scripts/test_mind_spark_zone02_route_clearance.gd`: production player capsule
  walks from the existing bridge onto Living Network ground.
- `scripts/test_live_mind_spark_entry.gd`: actual gallery gate, arrival support,
  return trip and quest-object coverage.
- `scripts/capture_mind_spark_celestial_land.gd`: actual Godot world geometry in
  neutral presentation lighting. This is not a production-browser screenshot.

No branch switch, commit or push is part of this integration.

## Verification results — 28 August 2026

The exported shell contains **285,954 triangles**, in five mesh families, derived
from 1,720 source components. All 11 independent Blender reimport checks passed,
including finite vertices, positive-area triangles, exact export counts, floor
clearance and preservation of the authoring master checksum. Flat paving-face
normals are retained, and the old cylinder's visual top cap is disabled so it
cannot intersect the imported paving bevels. The final preview confirms the
triangular overlap patches are gone. The cylinder collision remains unchanged.

Passed: celestial land geometry/resource sharing/support probes; Zone 02 real
capsule bridge entry; architecture/remote player jump; transit network; live
gallery World Gate entry and return; minimap; gallery flow; embedded floating
world; train station jump traversal; and Crown Line railway regression checks.
Several existing gallery tests also print shutdown resource-leak warnings;
their gameplay assertions passed, but these runs were not warning-free.

The full World One combat test emits errors despite printing an overall pass
message, so it is **not counted as passing**. Story progression subsequently
fails its pre-boss checkpoint assertion. The enemy's `core` reference has been
freed by static batching. A read-only comparison using the previous committed
foundation method reproduces `enemy_core_valid=false` with both old and new land.

The updated tree-detail suite passes the new foundation checks but fails an
existing named-node count: service cells = 0, status windows = 4, feeds = 12.
The baseline probe reproduces those exact counts with both land versions. The
probe is saved under `artifacts/mind_spark_celestial_land/baseline_probe.gd`.
Neither the existing combat/batching logic nor the tree-detail assertions were
changed to hide these failures.

Delivery status: **local visual integration verified, full production delivery
blocked by existing combat/story regressions**. No Web export, Vercel deployment
or production-browser verification was performed in this cycle. No deployment
ID is claimed. Runtime screenshots use neutral presentation lighting, not the
live gallery environment. The Web preset already includes all resources and
does not exclude the new runtime asset; actual Web performance is unverified.
