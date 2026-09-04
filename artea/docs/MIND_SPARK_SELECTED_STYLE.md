# MindSpark — selected island style

The user selected the attached enginehouse reference on 2026-08-28 after
reviewing the v10 Dawn Viaduct prototype. This reference supersedes v10's
exposed engine-platform silhouette as the visual direction. This document
records design intent; it does not switch the live game's assets.

## Existing matching source

- Editable model: `assets3D/mind_spark/celestial_condenser_v07/source/celestial_condenser_v07.blend`
- Matching close-up: `assets3D/mind_spark/celestial_condenser_v07/previews/02_enginehouse.png`
- Full-island view: `assets3D/mind_spark/celestial_condenser_v07/previews/01_hero.png`
- Existing inventory and validation: the v07 `parts_manifest.json`,
  `parts_catalogue.csv` and `validation_report.json`.

Reuse the matching source geometry and material palette. Do not replace it
with an approximation made from the v10 exterior engine pods. Earlier source
files and prototypes remain preserved.

## Visual rules

1. Architecture leads: substantial ivory piers, segmented curved arches,
   layered cornices, smooth mouldings and restrained champagne-brass reveals.
2. Machines belong to the building: tall vessels, cooling fins, flywheels,
   piston rods and valves sit in deep, shadowed arch bays. Large does not mean
   exposed freestanding engine platforms dominating the island silhouette.
3. Supports are readable: each machine bears on a stone sill or a bracketed
   maintenance balcony; arch springings meet piers; braces terminate on
   bearing surfaces rather than empty space.
4. Warm luxury: ivory and pearl stone dominate, with champagne brass, aged
   copper, dark teal recesses and small pale-aqua sight glasses. Preserve
   delicate metalwork instead of thick gold outlines on every surface.
5. Keep the heavenly terrace: fine curved balustrades, lanterns, carved pier
   panels, planters and subtle floor inlays. Ground-level decoration must be
   adapted around the actual game's walking routes, not pasted across them.
6. Preserve the floating rock: cliff mass remains visible below and between
   the architectural bays. Do not turn the whole island into a metal drum.

## Applying the earlier machinery request

- Fill underused foundation perimeter with additional integrated arch bays,
  not objects scattered on the playable floor.
- Distribute steam-generation, geared-drive and condenser assemblies around
  the perimeter, connected by supported headers and return pipes.
- Express fictional lift power through restrained emitters and conduitwork
  integrated into the lower ribs; avoid a visually dominant exposed ring.
- Keep all six island footprints, bridge connections, collision, quests and
  route widths unchanged. Vary bay rhythm and machine composition while
  retaining the same architectural language.
- Retain 3,000 nonempty editable mesh objects per island, named and inventoried.
  Distinguish whole components from surface patches; do not pad counts with
  empty objects or claim that triangulation alone makes a surface smooth.

## Current status

The images above remain the original v07 reference renders. On the user's
subsequent request to implement the style in the game, v11 was integrated into
the local six-island World One scene. See `MIND_SPARK_REFERENCE_INTEGRATION_V11.md`
for the implemented adaptations, verification evidence and publication status.
V10 remains a separate, unused prototype. No production deployment is implied
by the local integration.

Island two uses the separate v12 hanging-garden silhouette and island three
uses the v13 Astral Observatory citadel. The other four remain v11. Reference
enginehouses, paving and route openings are retained. See
`MIND_SPARK_VERDANT_RESHAPE.md` and `MIND_SPARK_ASTRAL_CASTLE_V13.md` for sources,
captures and verification.
