# Astral Observatory — underside completion v14

## Inspection and changes

The v13 front, side and rear views showed three incomplete areas: empty bays
inside the flying ribs, no aft lower plant balancing the front power core, and
no lower maintenance gallery connecting the machine beds.

| Gap | Implemented geometry |
| --- | --- |
| Empty west/east rib bays | Two teal pressure-cylinder engines with exposed piston rods, crossheads, connecting rods, toothed flywheels, shaft bearings, pedestals and sight glasses. |
| Empty lower rear | Twin copper/teal condensers with dished ends, jacket bands, level glasses and a 16-fin cooling matrix. |
| Isolated lower front skid | Continuous 24-sector ivory service gallery, brass balustrade, thresholds and a rear service ladder. |
| Unexplained machine support | Eight radial gallery brackets into the existing keel socket, engine skids, condenser mounting feet and two offset-collar cradle struts. |
| Missing pipe terminations | Separate supply/return risers and crown sockets, condenser matrix branches and front header blind flanges. |

The crystal tip and sweeping ribs remain legible. Open space immediately around
moving-part silhouettes is intentional rather than filled with solid masonry.
This pass does not redesign the retained upper facades or the playable court.

The lean-build approach kept this as one reversible asset revision using the
existing Blender kit and Godot integration seam. No new runtime dependency,
collision layer, branch, commit or push was added.

## Authoring and runtime

- Source: `assets3D/mind_spark/celestial_astral_v14/source/island_03_3000.blend`.
- Inventory: `assets3D/mind_spark/celestial_astral_v14/bom/island_03_parts.csv`.
- Runtime: `assets3D/mind_spark/celestial_astral_v14/island_03.glb`.
- 340 new constructed components; 3,340 objects before related fitting groups.
- Exactly 3,000 nonempty editable mesh objects after grouping. Grouped objects
  retain separately selectable geometry in Edit Mode; no empty padding objects.
- 11,800 additional triangles; 539,230 runtime triangles, below the unchanged
  540,000 ceiling. 599,894 including the shared paving.
- Five runtime role batches plus shared paving; these are mesh-instance counts,
  not a promise of six draw calls (materials have separate surfaces).
- Tiny fittings use economical topology; curved vessels/wheels use smooth shading.
  Triangulation alone is not used as a substitute for smoothing.
- Every v13 geometry category retains its triangle count, area and bounds.
  v13 source/runtime, shared paving and v12 island-two asset hashes are unchanged.
- Only the third island loads v14. All island positions, radii, collision,
  bridge endpoints, quest gates and other island assets remain unchanged.

## Reproduction and evidence

Run from the game directory, with the installed standard Blender and Godot:

```sh
rtk proxy /opt/homebrew/bin/blender --background --python-exit-code 1 --python tools/blender/build_astral_underside_v14.py
rtk proxy /opt/homebrew/bin/blender --background --python-exit-code 1 --python tools/blender/validate_astral_underside_v14.py
rtk proxy /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import
rtk proxy node tools/blender/verify_celestial_v11_game.mjs --out=artifacts/astral_underside_v14/tests
rtk proxy /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --path . --rendering-method gl_compatibility --script res://scripts/capture_astral_underside_v14.gd
```

The independent audit checks inventory, finite nondegenerate triangular meshes,
source/export coverage, retained geometry, route clearance, actual surface
proximity at the gallery supports, condenser cradles and pipe ports. Its result
is `assets3D/mind_spark/celestial_astral_v14/validation_report.json`.

Native regression evidence is in `artifacts/astral_underside_v14/tests/`.
Eleven native checks passed, including actual player traversal of both Astral
bridge approaches and the locked/open quest-gate fixtures. The suite also
reproduced two existing failures: incomplete Bio-Data Tree service components
and freed enemy-core references during story combat. The baseline probe
reproduces both with the old land and current land. Existing UID, JSON and
resource-at-exit warnings/errors also remain; this is not a warning-free build.

Images in `artifacts/astral_underside_v14/` are rendered from actual game geometry:
01 whole-island studio view, 02 side machinery, 03 rear plant, 04 underside closeup,
05 in-world view. Review lighting is neutral/warm; 05 hides text labels but not
game geometry. These are not generated concept images or a production capture.

## Remaining scope / release status

- Machinery is a static fictional lift-plant model, not a physical steam-engine
  simulation. Gear animation, steam effects and operational controls are not added.
- The lower service gallery/ladder are visual architecture, not a newly playable
  route; enabling access would require collision and traversal work separately.
- Production release remains blocked by the existing tree/combat regressions.
  No Web export, deployment or production browser verification was performed in
  this cycle; no new production deployment ID exists.
