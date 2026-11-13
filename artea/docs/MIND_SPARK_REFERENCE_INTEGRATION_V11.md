# MindSpark — reference style in the local game / v11

## Implemented

`scripts/mind_spark/mind_spark_world_one.gd::_build_modular_floating_foundation`
now loads `assets3D/mind_spark/celestial_islands_v11/island_01.glb` through
`island_06.glb`. These replace the v09 foundation assets in the actual local
World One scene, including the Art Castle Gallery entry path. V10 is not used.

The lean-build approach reused the existing reference geometry: the v07
carved ivory arches, condensers, flywheel engine, copper pipework and supported
service balcony. Each island has two opposing twin-arch enginehouses: four
recessed bays, not four copies of the exposed v10 engine platform.

Original v07 ornate balustrades and lanterns are restored around the perimeter.
Whole railing bays are omitted at the two story-bridge approaches and Zone 05's
positive-Z station approach. Railings are outside the original walking disc;
the cornice supports their feet. No new collision bodies are imported.

The six rock profiles and floor motifs remain different. Whole cliff stones
are recessed behind the enginehouse envelopes to prevent rock protruding into
the machinery. This changes local cliff placement, not island centres, radii,
floor heights, bridge geometry, collision, quest objects or game logic.

The reference's standalone stairs, basin and planters are not pasted over
existing gameplay content. Machinery remains static fictional steam-magitech;
no working steam or levitation simulation is claimed.

## Authoring and runtime data

- Each final Blender island contains exactly 3,000 nonempty editable meshes.
- Six islands: 18,000 uniquely identified parts, with matching CSV inventories.
- Parts include connected pieces and explicitly grouped related small fittings.
  No filler objects and no surface-patch subdivision was needed in this build.
- Six mesh nodes per island in Godot: rock, architecture, machinery, inlay,
  railing and the shared paving resource. Parts are not individual draw nodes.
- Whole family: 3,206,864 triangles including the shared paving drawn six times.
  This is more geometry than v09; it is not a Web performance certification.
- Earlier v07/v08/v09 sources and the v10 prototype are preserved.

Sources are under `assets3D/mind_spark/celestial_islands_v11/source/`:
`island_01_3000.blend` through `island_06_3000.blend`.
Matching inventories are under `bom/`. The `source/`, `bom/` and `staging/`
directories are ignored by Godot; the runtime GLBs are imported normally.
The existing Web export preset includes the runtime resources unchanged.

## Verification evidence

- `assets3D/mind_spark/celestial_islands_v11/validation_report.json`: source/BOM
  counts, triangulation, nonempty geometry, source/export coverage, preserved
  shared paving, railing/route clearance, recessed-rock envelope and original
  source checksums. Individual reports are `island_01_audit.json` through 06.
- `artifacts/mind_spark_islands_v11/tests/results.json`: actual test outcomes.
  Complete engine output is retained in the adjacent `.log` files, including
  existing UID/resource-at-shutdown warnings rather than presenting a clean log.
- `artifacts/mind_spark_islands_v11/01_six_islands_3000_part_board.png`:
  isolated game-asset review board.
- `artifacts/mind_spark_islands_v11/02_existing_map_with_detailed_foundations.png`:
  actual six-island game scene with its existing content and bridges.
- `island_03_integrated_gameplay.png` and `island_04_integrated_gameplay.png`:
  closer views of the actual game scene. Captures use neutral review lighting.

Native regression checks cover real route walking, remote jumping, Art Castle
entry/return, the transit network, minimap, embedded gallery world, station
boarding/jumping and Crown railway. These do not prove complete story delivery.

## Publication blocked

Two existing checks still fail outside this artwork change:

1. `test_mind_spark_world_one_story`: an enemy's `core` mesh has already been
   freed by existing static batching; damage/defeat accesses the invalid mesh,
   and the pre-boss completion assertion fails.
2. `test_mind_spark_island_texture_coverage`: the Bio-Data Tree service component
   check fails (0 service cells, 4 status windows, 12 feeds).

The `baseline_probe.log` reproduces the same invalid enemy core and tree counts
with the old procedural foundation as well as v11. These unrelated systems
were not altered, and their assertions were not relaxed.

Storage also remains constrained (about 515 MiB free at the first final capture).
The previous local Web output is incomplete: it has trailing PCK chunks but no
parts manifest. The export script would remove outputs before rebuilding, and
the earlier pack sizes indicate substantially more space is required.
No local files were deleted to make room.

Because the full-story check fails and export storage is insufficient, no Web
export or production deployment was attempted in this integration cycle. There
is no new deployment ID and no production-browser verification. The public site
has not been updated by this task. Local integration is not production completion.

No branch was created/switched; no commit or push was performed.

## Reproducible commands

Run from the project directory with RTK, using separate Blender processes to
bound memory. Build `--prepare`, then `--island=1` through `--island=6`, then
`--finalize` with `tools/blender/build_celestial_islands_v11.py`. Audit each
island and finalize with `tools/blender/validate_celestial_islands_v11.py`.

After Godot imports the GLBs, native regression checks are run by
`rtk proxy node tools/blender/verify_celestial_v11_game.mjs`. They intentionally
return a failure when the existing full-story/tree checks fail.
