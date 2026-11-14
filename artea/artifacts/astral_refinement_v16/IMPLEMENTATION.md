# Astral Observatory — v16 quality repair

Scope: the third island in Mind Spark World One. Original island centres,
walkable radii, bridge directions, quests and other five island assets remain.
No branch, commit or push was made. The v15 Blender source remains unchanged
and is checked by SHA-256 in the independent validator.

## Implemented

- Replaced the oversized ground balustrade with approximately 1.4 m guards,
  ivory piers, brass diamonds and spaced lanterns. Collision follows the actual
  circular perimeter; both bridge entrances remain open.
- Replaced tangled side supports with four swept load cradles. Turrets and
  their bearings sit aft of the engine openings. Twenty masonry courses meet
  four arch capitals; keyed crown courses meet the cornice.
- Fitted the inherited rock patches behind the two engine chambers. Open
  surface patches are affine-fitted, not destructively booleaned as solids.
- Added two open-spoked flywheels, matched 20:12 pinions, guided crossheads,
  constant-length connecting rods, steam cylinders and generator conduits.
  Eight assemblies animate independently in Godot.
- Unified ivory, champagne brass, copper and dark teal. Reworked the court and
  gates to use this palette without changing their gameplay locations.
- Preserved actor and authored-tree node ownership during geometry batching.
  Restored combat and tree-detail regression coverage.
- Made existing AI-response fallback parse non-JSON responses without throwing
  a JSON parser error; gallery regression exercises that path.

## Editable deliverables

`assets3D/mind_spark/celestial_astral_v16/source/island_03_3000.blend`
contains exactly 3,000 nonempty mesh objects. Every source face is triangulated.
This is an authoring inventory, not 3,000 runtime draw calls or voxel pixels.
Related fittings may be grouped into one editable mesh.

`bom/island_03_parts.csv` maps every unique part ID. `modules/catalog.json`
describes four appendable Blender Collections in metre units:
promenade panel, steam generator, carved engine chamber and curved load cradle.
The panel is one mesh with editable internal geometry; the other modules retain
62, 57 and 10 separate objects respectively.

## Verification and budgets

- Independent geometry audit: 3,000 unique nonempty parts; finite vertices,
  triangular positive-area faces, no mesh validation repairs, matching source
  and GLB coverage. All pass.
- 1,318 perimeter samples: no missing handrail outside bridge openings.
- 286 chamber-interior samples: no obstructing rock.
- Real Godot capsule: blocked at four perimeter edges; both castle approaches
  remain traversable when the quest gate opens.
- Kinematics: 20:12 rotation ratio and constant rod length verified over 90 poses.
- Full native suite: all 14 tests pass on the final asset. Results are in
  `tests/results.json` and individual test logs.
- Re-running the rock-fitting operation leaves every rock vertex unchanged;
  the saved-source idempotence check passes.
- Runtime asset: 517,995 triangles, 13 meshes, 23,121,664 bytes.
  Shared paving adds 60,664 triangles and one mesh. Architecture is about
  12.8% fewer triangles than v15, despite separate moving assemblies.
- Native capture sample: approximately 47.4 FPS at 1800 × 1600, 120 frames on
  Apple M2 Pro, OpenGL compatibility; approximately 5,680 draw calls across the
  occupied six-island scene. This is not a browser/mobile performance guarantee
  or a controlled before/after performance comparison.

## Limits

The steam plant uses scripted kinematics; levitation is fictional. The lower
maintenance galleries are scenery, not newly traversable gameplay areas.
Other islands retain their existing railing designs. Whole-world rendering
cost and the large initial Web download remain optimization work; no 60 FPS
or mobile-readiness claim is made. Existing UID fallback warnings and some
headless shutdown resource-leak notices remain outside this island repair.

The four PNGs alongside this report are actual Godot renders, not generated
concept art. Production delivery evidence is recorded separately after export
and browser verification.
