# Astral Observatory — fitted barriers and side enclosures

## User-requested corrections

The third island's v14 ground perimeter reused a partial reference railing set.
Posts at 75°, 105°, 135° and 165° had no intervening panels. The remaining large
rear span crossed a bridge entrance, and one whole front panel had previously
been omitted for route clearance. Even intact reference bays had small rail-end
gaps because the post plinths were wider than the posts at handrail height.

v15 adds seven fitted panel spans, four compact bridge-terminal piers, one
intermediate pier and 57 short brass rail-to-post connectors. Six long infills
reuse the original curved fan/scroll geometry; one short return uses matching
rails and pickets. Only the two reserved bridge entrance sectors remain open.

The bare side machinery is now framed by two recessed engine chambers:

- Four-course ivory piers, moulded shoes and imposts.
- Nineteen separately editable curved arch stones on each side, with brass reveals.
- Shaped upper spandrels and cornices meeting the crown underside.
- Arched teal backing behind the machines, not a wall across their fronts.
- Eleven copper ventilation louvers and brass frames in each upper void.
- Teal pier inlays, gold flutes, broad bearing sills and keel-seated footing braces.

The existing engines, gears, lower gallery, flying ribs, domes, crystalline keel,
upper facades and shared paving are retained. The lean-build approach kept the
change at the existing Blender asset/Godot loading seam; other islands and
gameplay systems were not redesigned.

## Asset and budget

- `assets3D/mind_spark/celestial_astral_v15/source/island_03_3000.blend`
- `assets3D/mind_spark/celestial_astral_v15/bom/island_03_parts.csv`
- `assets3D/mind_spark/celestial_astral_v15/island_03.glb`
- 406 added constructed objects; related fittings grouped from 3,406 to exactly
  3,000 nonempty editable mesh objects. Grouped geometry remains editable in Edit Mode.
- 54,704 added triangles; 593,934 runtime triangles, 654,598 with shared paving.
- This island's ceiling is explicitly raised from 540,000 to 595,000 to complete
  the detailed reference balustrades. The whole-family ceiling stays 3.5 million;
  the full scene now uses 3,375,186 visible foundation triangles.
- Five role batches plus shared paving remain; material surfaces still require
  their own draw calls. No claim of six total draw calls is made.
- v14 source/runtime, shared paving and v12 island-two files are hash-preserved.
  Every v14 source geometry category retains its triangles, area and bounds.
- No branch, commit, push, new dependency or gameplay collision was added.

## Verification

`tools/blender/validate_astral_enclosure_v15.py` checks actual triangle geometry,
inventory, preservation, clearance, source/export coverage and seating. Its
perimeter check casts radial rays at the upper handrail elevation every 0.5°,
excluding the two entrance sectors. The old asset is also measured to show that
the test detects the original missing spans. Fifty ray probes check that the
two side chambers have a backing or architectural surface at the sampled points.

The results are written to
`assets3D/mind_spark/celestial_astral_v15/validation_report.json`.
Native regression logs are in `artifacts/astral_enclosure_v15/tests/`.

Final results: all 51 asset checks passed. The source and runtime both have zero
missing handrail samples among the 658 positions outside the two entrances;
all 50 side-bay probes hit geometry. Eleven native checks passed, including
real player traversal of both Astral bridge approaches and locked/open gate
fixtures. Two unchanged baseline failures remain as described below.

```sh
rtk proxy /opt/homebrew/bin/blender --background --python-exit-code 1 --python tools/blender/build_astral_enclosure_v15.py
rtk proxy /opt/homebrew/bin/blender --background --python-exit-code 1 --python tools/blender/validate_astral_enclosure_v15.py
rtk proxy /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import
rtk proxy node tools/blender/verify_celestial_v11_game.mjs --out=artifacts/astral_enclosure_v15/tests
rtk proxy /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --path . --rendering-method gl_compatibility --script res://scripts/capture_astral_enclosure_v15.gd
```

Screenshots in `artifacts/astral_enclosure_v15/` show actual geometry: whole island,
side elevation, chamber close-up, overhead perimeter and in-world view. Review
lighting is neutral/warm; the in-world capture hides text labels but not geometry.

## Remaining scope

This is a visual architecture correction. It does not introduce new physical
fence collision, playable service access, gear animation or steam simulation.
Existing walking surfaces, bridge paths and quest-gate behavior stay unchanged.

The native suite still has two unrelated baseline failures: incomplete Bio-Data
Tree service components and freed enemy-core references during combat. The
old/current-land baseline probe reproduces both. Existing UID, JSON and
resource-at-exit warnings/errors remain. No Web export, production deployment
or production browser verification was performed in this cycle; no new deployment
ID exists. Production delivery is not claimed.
