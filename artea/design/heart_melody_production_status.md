# Heart Melody production upgrade — implementation status

This is an incomplete implementation of the production brief. The current
playable world has not become the requested finished 2–4 hour adventure.

## Implemented compatibility foundation

- Stable catalog entries for four quests, ten tasks, six zones, three regions,
  prerequisites, checkpoints, and finale entitlement identifiers.
- Six story fruit definitions, visual profile metadata, protected authored
  harvest identifiers, and six recipe definitions.
- An additive, versioned `chapter` record in the existing garden save. The outer
  schema remains 2 so the existing garden and musical garden readers retain their
  record structure. Chapter version 1 is validated independently.
- Schema 1 and schema 2 saves without a chapter migrate after legacy validation.
  Planters, partial phrases, river stages, enemy receipts, XP, musical garden data,
  and legacy checkpoint values remain intact. Existing settings and identity stores
  are not modified. Migration does not grant fruit or finale rewards.
- The existing garden/river APIs synchronize their seven task IDs into the chapter
  transaction. The three finale tasks are never inferred from prior progress.
- Chapter state validates ordered prerequisites, quantities, receipt uniqueness,
  settings, saved attempts, anchor IDs, motifs, and finale reward prerequisites.
- A transaction API supports protected story harvests, material stacks of 99,
  overflow storage, withdrawal, and crafting from materials only. Failed writes
  roll back; chapter edits cannot overwrite pending legacy saves.
- A shared challenge controller supports editable sequences, pitch edits, timing,
  undo, reset, cancellable demonstrations, progressive hints, pause, and assistance
  timing. It has not replaced the existing instruments' interaction code.

The chapter uses the existing temporary-write/rename and persistent `.bak` save
path. First-clear legacy XP remains owned by the original receipt transaction.
Neither new catalog nor controller calls identity APIs.

## Integration still required

The fruit/recipe transaction API and challenge controller are tested foundations,
not player-accessible production systems. They still need physical fruit assets,
harvest interactions, the normal inventory adapter, crafting UI and consumable
effects, checkpoint storage UI, regrowth, and instrument integration.

The full controller split is unfinished: environment, encounter, audio, quest
objects, and HUD still live in the existing implementation. The new quest director
does not yet own task completion or gameplay reward delivery.

Region A still needs its production art/collision pass and celesta/flower challenge
upgrades. Region B still uses the existing simpler river activities. Region C,
the song loom, Beat Anchors encounter, final conducting sequence, Conductor
release, sanctuary, and chapter finale rewards are not implemented. The existing
Castle entry, identity, campaign gates, and station logic were left intact.

Full keyboard/controller/touch walkthroughs, accessibility verification, six-zone
captures, physical traversal at multiple frame rates, production deployment, and
public WebGL2 verification remain outstanding.

## Validation performed

Godot 4.7.1 standard, non-Mono:

- `test_heart_chapter_migration.gd`: legacy migration, receipts, fruit protection,
  overflow, crafting isolation, pending/failed writes, invalid records, partial
  attempts, undo, pitch, pause, timing at 30/60/120 FPS, and corrupt-primary backup
  recovery passed.
- Existing `test_heart_progress_safety`, `test_river_song`,
  `test_heart_musical_garden`, `test_heart_identity_consent`,
  `test_safe_heart_melody`, `test_heart_gate_round_trip`, and
  `test_heart_station_integration` passed.
- The initial maintained export returned zero and produced 106 split pack parts,
  887,397,664 pack bytes, but log review found missing-resource errors for
  `assets3D/worlds/low_poly_cloud.glb`,
  `assets3D/stylizedNature/Grass_Common_Short.gltf`, and
  `assets3D/stylizedNature/CommonTree_1.gltf`. None of those source assets is
  present in this checkout. This package is not a verified release.
- The maintained exporter now retains `builds/web/export.log` and rejects
  Godot error diagnostics even when the process returns zero.

Existing UID fallback/duplicate warnings and exit resource-leak warnings appeared
in the tests/export. A successful headless export is not browser verification.
No production deployment was made. The expected `builds/web/.vercel` project link
is absent, and the Vercel CLI is not installed in the local npm cache.
