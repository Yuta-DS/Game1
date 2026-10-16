# Verdant Engine Gardens — v12 hanging-garden silhouette

Island two only. The other five islands retain v11; v11 source assets remain
untouched and available as the reversible baseline. No branch, commit or push.

## Design

- Two asymmetric hanging rock keels replace the previous single tapered cone.
  The longer eastern tip and open slot between the keels are the new silhouette.
- Four elliptical planted ledges step down the sides at different elevations.
  Individual curved masonry blocks, brass lips, sage friezes, soil, leaf blades,
  and trailing vines belong to named reusable assemblies.
- Four copper-jacketed pressure stays and transverse tie beams connect the
  crown bearing structure to the keels. Compression hoops, mounting shoes,
  fasteners, level glasses, and continuous supply/return pipes explain the
  fictional floating machinery visually; no levitation simulation is claimed.
- Original reference arches, engines, balustrades and lamps are retained.
  Smoothness comes from curved geometry and smooth normals where appropriate;
  triangulation alone is not treated as smoothing.

## Gameplay and scope

The central circular walking disc, collision, radius, world position, bridge
connections, quests and existing top-side objects are unchanged. Added garden
ledges are inaccessible scenery below the gameplay plane, not new playable
platforms. This deliberately changes the island silhouette without redesigning
the level. Top-side quest props have not been restyled in this pass.

The lean-build skill kept the change at the existing visual-foundation seam.
The exporter still batches geometry into five role meshes plus shared paving.
Authoring contains exactly 3,000 nonempty mesh parts: preserved components,
new construction and explicitly grouped related fittings, not filler objects.
Runtime role-node names remain stable for existing inspection tools.

## Reproduction

Run `tools/blender/build_verdant_island_v12.py` with Blender in background mode.
It reads v11 and writes only `assets3D/mind_spark/celestial_verdant_v12/`.
The source, inventory and audit are under that directory; the Godot loader uses
its `island_02.glb` only for zone index 1.

Run `tools/blender/validate_verdant_island_v12.py` in Blender. Native regressions
use `tools/blender/verify_celestial_v11_game.mjs` with
`--out=artifacts/verdant_island_v12/tests`. Captures use
`scripts/capture_verdant_island_v12.gd`; isolated architecture and actual game
scene images are saved under `artifacts/verdant_island_v12/`.

## Geometry verification

`assets3D/mind_spark/celestial_verdant_v12/validation_report.json` passes all
source/export checks: 3,000 unique nonempty parts with matching inventory,
triangulation, finite coordinates, positive face areas, preservation of the
reference enginehouses and railing openings, unchanged shared paving,
four terraces, four stays, and nine open-air ray probes through the split keel.

There are 531,836 runtime triangles before shared paving (592,500 with it).
The full six-island family is 3,268,404 visible triangles, within the existing
3.5-million ceiling. This is not a measured Web performance certification.

`01_verdant_hanging_gardens.png` is an isolated view of the actual game asset;
`04_verdant_in_game_reverse.png` shows the populated game scene and bridges.
Both use neutral review lighting rather than claiming a production screenshot.

## Delivery status

Local implementation is complete. Native regression results are retained in
`artifacts/verdant_island_v12/tests/results.json` with full adjacent logs.
Geometry, player route walking, remote jump, six-island transit, live Art Castle
entry/return, minimap, gallery integration, station traversal and Crown railway
checks pass. Existing JSON/UID/resource-at-exit diagnostics remain in the logs;
the project is not presented as warning-free.

Publication is blocked by the existing story/combat freed-core error and the
Bio-Data Tree service-component assertion. The baseline probe reproduces the
same invalid enemy core and tree counts with both legacy and current land.
Neither gameplay system nor its required assertions was removed to pass tests.
Art-revision expectations now explicitly require v12 for island two and v11
for the other five, and the batched-mesh count reflects six meshes per island.

Disk storage is no longer the blocker. No Web export, production deployment,
deployment ID or browser verification was produced in this revision. The public
game has not been updated by this task; local completion is not publication.
