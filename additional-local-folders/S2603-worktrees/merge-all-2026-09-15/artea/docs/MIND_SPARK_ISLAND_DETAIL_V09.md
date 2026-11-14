# MindSpark v09 — detailed celestial engine islands

28 August 2026. This revision fills exposed lower architectural bays while
preserving the six existing playable decks, positions, bridge connections and
quest placements. It does not redesign quests or add machine gameplay.

## Space audit and response

| Island | Audit finding | Added construction |
| --- | --- | --- |
| Sun Gate | Front engine facade already has a strong focal point; side/rear cliff faces are comparatively bare. | Two auxiliary pump stations and a supported side maintenance gallery; retain the original front facade. |
| Verdant Engine Gardens | Terraces read clearly, but the gaps between original engine pods lack detail and continuity. | Three irrigation exchanger stations, rounded feed/return pipes and a continuous lower service gallery. |
| Astral Observatory | Large arcade openings read as empty supports, rather than an inhabited machine structure. | Five blue-enamel circulation stations in alternating bays, retaining the open arch rhythm and lower orbital rings. |
| Dawn Viaduct | The original small engine is undersized relative to the twin arch spans. | Two larger three-cylinder lift-engine assemblies, with radiator faces, bearing skids and a curved braced service gallery. |
| Stormworks Bastion | Heavy structural towers leave unarticulated gaps between pressure banks. | Four copper accumulator stations and a maintenance ring, without changing the octagonal silhouette. |
| Crownroot Sanctuary | Root ribs have a distinct silhouette but little usable-looking machinery at their bases. | Eight small sage-enamel nutrient pumps between ribs and a rooted lower service ring. |

All six receive 36 ivory-framed rim cassettes with enamel recesses and brass vent
fins. New machinery has separately editable shells, flange covers, flange
fasteners, jacket staves, level-glass casings, level marks, mounting feet, valves,
radiator fins, headers, rounded pipe bends, skids and structural corbels.

The open tops in the isolated architecture board are intentional. Existing
in-game courts, trees, quest props and movement routes occupy those areas. The
new lower galleries are visual architecture, not newly playable collision decks.
No pressure simulation, moving engine mechanism or new quest interaction is claimed.

## Exactly 3,000 editable mesh parts per island

Each saved Blender file has **3,000 non-empty mesh objects**, with globally unique
IDs such as `MS09-I03-P0123`. There are **18,000 editable mesh parts** across six
files, not 18,000 runtime scene nodes.

The count is deliberately transparent: existing disconnected stone/component
pieces are separated first; broad masonry, paving and rock surfaces are then
partitioned into labelled editable surface patches. Patches retain the original
faces and positions. They are not extra overlapping geometry, empty placeholders,
or a claim that all 3,000 parts are separate closed mechanical solids.

Every part carries its ID, island ID, category, assembly, component kind and
source-component provenance. Its CSV inventory records those fields and triangle
count. The corresponding Blender collections organise paving, cliff masonry,
preserved architecture, civic frieze, engine assemblies and service galleries.

| Island | Editable mesh parts | New engine-category components | Runtime triangles including paving |
| --- | ---: | ---: | ---: |
| Sun Gate | 3,000 | 282 | 340,716 |
| Verdant Engine Gardens | 3,000 | 423 | 290,012 |
| Astral Observatory | 3,000 | 705 | 271,036 |
| Dawn Viaduct | 3,000 | 384 | 187,862 |
| Stormworks Bastion | 3,000 | 564 | 287,058 |
| Crownroot Sanctuary | 3,000 | 1,128 | 292,854 |

Runtime total: **1,669,538 visible triangles**, versus v08's 1,161,574. Additional
detail has a real geometry cost. Four batched architecture meshes plus shared
paving remain five mesh instances per island; no frame-rate or Web-performance
improvement is claimed. The explicit whole-family limit is two million triangles.

## Files

Assets and audit data live under `assets3D/mind_spark/celestial_islands_v09/`.

| Island | Editable Blender file | Part inventory |
| --- | --- | --- |
| Sun Gate | [island_01_3000.blend](../assets3D/mind_spark/celestial_islands_v09/source/island_01_3000.blend) | [CSV](../assets3D/mind_spark/celestial_islands_v09/bom/island_01_parts.csv) |
| Gardens | [island_02_3000.blend](../assets3D/mind_spark/celestial_islands_v09/source/island_02_3000.blend) | [CSV](../assets3D/mind_spark/celestial_islands_v09/bom/island_02_parts.csv) |
| Observatory | [island_03_3000.blend](../assets3D/mind_spark/celestial_islands_v09/source/island_03_3000.blend) | [CSV](../assets3D/mind_spark/celestial_islands_v09/bom/island_03_parts.csv) |
| Viaduct | [island_04_3000.blend](../assets3D/mind_spark/celestial_islands_v09/source/island_04_3000.blend) | [CSV](../assets3D/mind_spark/celestial_islands_v09/bom/island_04_parts.csv) |
| Bastion | [island_05_3000.blend](../assets3D/mind_spark/celestial_islands_v09/source/island_05_3000.blend) | [CSV](../assets3D/mind_spark/celestial_islands_v09/bom/island_05_parts.csv) |
| Sanctuary | [island_06_3000.blend](../assets3D/mind_spark/celestial_islands_v09/source/island_06_3000.blend) | [CSV](../assets3D/mind_spark/celestial_islands_v09/bom/island_06_parts.csv) |

`manifest.json` provides measured per-island totals and the counting policy.
`validation_report.json` is the independent Blender/source/BOM/GLB reimport audit.
The v07 and v08 master files are preserved and checksum-verified.

The 2400-by-1680 comparison board and six 1600-by-1200 architecture detail renders
are in `artifacts/mind_spark_islands_v09/`. These are actual Godot asset renders
under neutral presentation lighting, not a production-browser capture. The board
labels are derived from the generated manifest rather than manually typed counts.

## Reproducible build

The builder reads one v08 collection at a time, avoiding an unnecessary six-island
peak-memory load. On a memory-constrained machine, build each island in its own
Blender process. Rebuilding overwrites v09 generated outputs; preserve manual edits
in a separate copy first. It never overwrites the v07/v08 masters.

```sh
rtk proxy /opt/homebrew/bin/blender --background --python-exit-code 1 --python tools/blender/build_celestial_islands_v09.py -- --island=1
# Repeat with --island=2 through --island=6, then:
rtk proxy /opt/homebrew/bin/blender --background --python-exit-code 1 --python tools/blender/build_celestial_islands_v09.py -- --finalize
rtk proxy /opt/homebrew/bin/blender --background --python-exit-code 1 --python tools/blender/validate_celestial_islands_v09.py
rtk proxy /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
rtk proxy /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --path . --script res://scripts/capture_mind_spark_islands_v09.gd
```

The initial build encountered disk pressure during the third export. Incremental
one-collection builds recovered without deleting user files. The incomplete third
GLB was replaced by a complete regenerated export before integration.

## Delivery boundary

This is local visual integration. Existing combat/story and Bio-Data Tree detail
regressions documented in the prior integration reports are outside this change.
No branch switch, commit, push, Web export, production deployment or browser
verification is claimed. The workstation also remains very low on disk space.

## Final verification

The independent Blender audit passed for all six final source files and GLBs:
exactly 3,000 non-empty uniquely named mesh objects per island, matching CSV IDs
and triangle counts, valid finite triangle geometry, positive face areas, no mesh
repairs required, geometry below the walkable plane, source/runtime triangle-area
and bounds agreement, and unchanged v07/v08 source checksums. The subdivided source
paving also matches the shared game paving.

Passed in this delivery cycle:

- `test_mind_spark_celestial_land.gd`: six original footprints, five runtime
  meshes each, correct revision/part metadata, shared paving, 1,669,538 visible
  triangles, 72 support probes and no new collision obstacles.
- `test_mind_spark_zone02_route_clearance.gd`: real player capsule crosses the
  existing bridge/island threshold without jumping.
- `test_mind_spark_architecture_physics.gd`: floor/bridge and real remote jump.
- `test_mind_spark_transit_network.gd`: existing bridge ring and shortcuts.
- `test_live_mind_spark_entry.gd`: live gallery gate entry and return.
- `test_world_minimap.gd`, `test_art_castle_gallery_flow.gd`,
  `test_gallery_embedded_floating_world.gd`,
  `test_train_station_jump_traversal.gd`, `test_story_crown_railway.gd`.
- `git diff --check`.

Several baseline runs still emit existing music/duplicate-UID warnings and
shutdown ObjectDB/resource-in-use messages. Passing gameplay assertions does not
mean those runs were warning-free. Full World One combat/story completion is not
claimed. No Web export or deployment ID exists for this cycle.

The updated `test_mind_spark_island_texture_coverage.gd` passes its new foundation
checks, then still fails the existing Bio-Data Tree base-service assertion.
Rerunning `artifacts/mind_spark_celestial_land/baseline_probe.gd` in this cycle
reproduces the same results with the old foundation method and current v09:
`enemy_core_valid=false`, service cells = 0, status windows = 4, feeds = 12.
Neither combat/batching nor the failing tree assertions were changed to hide
those problems. They remain blockers for full game delivery, separate from the
verified island geometry and movement paths.
