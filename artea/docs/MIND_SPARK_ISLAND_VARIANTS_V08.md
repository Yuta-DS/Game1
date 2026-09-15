# MindSpark: six islands, one celestial design family

Historical v08 design report. The subsequent 3,000-part-per-island detail pass is
documented in [MindSpark v09](MIND_SPARK_ISLAND_DETAIL_V09.md). These v08 sources
remain preserved.

Local implementation and verification: 28 August 2026. Production delivery is
still blocked by the previously identified combat/story regressions; no Web
export, deployment, or production-browser verification is claimed for this cycle.

## Design mapping

The six islands share warm ivory masonry, pale cliff stone, brass edging, copper
condensers, curved structural details and radial paving. Their support structures,
rock profiles, machinery arrangements and flush floor emblems are different.

| Existing gameplay island | Architectural identity | Distinguishing construction |
| --- | --- | --- |
| World Gate Landing | Sun Gate | Original carved gateway arches, maintenance balcony, twin-vessel machinery and sun inlay |
| Living Network Forest | Verdant Engine Gardens | Three stepped sage terraces, three condenser houses on corbel-supported platforms, root conduits and five-petal inlay |
| Constellation Court | Astral Observatory | Ten-pier arcade, wedged arch blocks, three supported orbital rings, compression hub and blue astronomical inlay |
| Hope Path Ridge | Dawn Viaduct | Parallel arch girders, four piers, engine cross-bearer and sweeping braces meeting a lower keel socket |
| Thought Storm Arena | Stormworks Bastion | Octagonal structural courses, eight louvred towers, copper pressure banks and a lower bearing ring |
| Oldest Tree Sanctuary | Crownroot Sanctuary | Eight sweeping stone petals, sage/gold ribs, rooted collar, long tapered cliff and eight-petal inlay |

This is a foundation variation pass, not six new maps. Existing zone centres,
circular walkable radii, floor collisions, friction, bridge connections, recovery
volumes, quest objects, trees and enemy placements are unchanged. New geometry
is visual-only. The old floor's visual top cap stays disabled beneath the imported
paving; its collision is retained. The new machinery is architectural geometry,
not a new interactive machine simulation.

## Editable source and reusable runtime kit

- Blender authoring board: `assets3D/mind_spark/celestial_islands_v08/source/celestial_island_family_v08.blend`.
- Six named authoring collections are arranged in a 3-by-2 board. New blocks,
  piers, arches, rings, ribs, conduits and emblems are separate editable objects.
- The original 3,000-part v07 master remains untouched at
  `assets3D/mind_spark/celestial_condenser_v07/source/celestial_condenser_v07.blend`.
  Its 80 condenser components supply the reusable machine unit. That unit and
  reused v07 facade meshes are batched in v08, not 3,000 new objects per island.
- Runtime: `shared_paving.glb` plus `island_01.glb` through `island_06.glb` in
  `assets3D/mind_spark/celestial_islands_v08/`.
- Each island uses four material-batched mesh roles: rock, architecture,
  machinery and inlay. One additional shared paving mesh makes five instances
  per island. The game builder scales them to the existing zone radius.
- `manifest.json` records asset sizes, triangle counts, component counts and
  preserved v07 source checksums. `validation_report.json` records an independent
  reimport audit.

| Variant | Editable structural objects in v08 | Runtime triangles, excluding shared paving |
| --- | ---: | ---: |
| Sun Gate | 21 | 218,348 |
| Verdant Engine Gardens | 89 | 140,848 |
| Astral Observatory | 205 | 114,168 |
| Dawn Viaduct | 83 | 88,698 |
| Stormworks Bastion | 99 | 130,218 |
| Crownroot Sanctuary | 68 | 105,310 |

There are 565 variant objects, plus the shared paving and its board copies.
Shared paving has 60,664 triangles. All six visible islands total 1,161,574
triangles, including six paving instances. Geometry is triangulated; smooth curved
forms come from sampled curves, bevels and appropriate normals, not triangulation
alone. Six unique variants cost more geometry-resource memory than one shared
model, even though their combined visible triangle count is lower than six v07
copies. No frame-rate or Web-memory improvement is claimed.

## Rebuild and inspect

Run from the repository root. Rebuilding regenerates the v08 assets and board;
save any manual edits to a separate authoring copy first.

```sh
rtk proxy /opt/homebrew/bin/blender --background --python-exit-code 1 --python tools/blender/build_celestial_island_variants.py
rtk proxy /opt/homebrew/bin/blender --background --python-exit-code 1 --python tools/blender/validate_celestial_island_variants.py
rtk proxy /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
rtk proxy /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/test_mind_spark_celestial_land.gd
rtk proxy /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --path . --script res://scripts/capture_mind_spark_island_variants.gd
```

The capture script writes a six-design comparison, a map overview and six gameplay
views to `artifacts/mind_spark_islands_v08/`. These are actual Godot geometry
renders under neutral presentation lighting, not concept images or production
browser screenshots. The comparison intentionally omits existing gameplay props
so the foundations can be compared clearly.

## Verification and remaining limitation

Passed in this cycle:

- Independent Blender reimport: finite vertices, triangle-only faces, positive
  face areas, no mesh repairs required, six distinct rock profiles, exact counts,
  preserved v07 checksums and triangle budgets.
- `test_mind_spark_celestial_land.gd`: all six original footprints and design
  assignments, shared paving resource, 72 collision support probes, real vertex
  clearance below 0.095 game units, no imported collision obstacles.
- `test_mind_spark_zone02_route_clearance.gd`: real player capsule walks from
  the bridge onto Forest ground.
- `test_live_mind_spark_entry.gd`: actual gallery gate entry and return.
- `test_mind_spark_architecture_physics.gd`, `test_mind_spark_transit_network.gd`,
  `test_world_minimap.gd`, `test_art_castle_gallery_flow.gd`,
  `test_gallery_embedded_floating_world.gd`,
  `test_train_station_jump_traversal.gd`, `test_story_crown_railway.gd`.

Some baseline runs still emit existing shutdown ObjectDB/resource-in-use messages
and a music UID warning. Passing gameplay assertions do not mean warning-free runs.
`git diff --check` passed.

`test_mind_spark_island_texture_coverage.gd` passes its v08 foundation checks but
still fails the existing Bio-Data Tree base-service component assertion. The prior
old/new baseline reproduced this same failure; the tree assertions remain intact.

The prior integration audit established an existing enemy `core` reference freed
by static batching, causing combat errors and a pre-boss story checkpoint failure.
Its old/new baseline probe is recorded in `MIND_SPARK_CELESTIAL_LAND_INTEGRATION.md`.
This island-only change does not modify combat, batching, story progression or
tree-detail assertions. Full World One story completion is not claimed.

The Web preset includes all resources and does not exclude the new GLBs; source
Blender files remain excluded. Actual Web startup, performance and production
delivery have not been verified. No branch switch, commit or push was performed.
