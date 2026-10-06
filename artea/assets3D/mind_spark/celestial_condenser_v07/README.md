# MineSpark — twin-vessel condenser / v07

The large clock-like regulator is replaced by a compact condenser machine.
The new silhouette is two domed vertical vessels with a central cooling stack,
connected header pipes, small lever controls and vertical sight-glass strips.
There is no large circular face, dial hand, sun wheel or radial display in the
replacement. The separate flywheel and small gauges in the left engine bay are
unchanged.

The warm ivory, champagne-gold, copper and muted teal palette is retained.
The mounting skid sits on the existing stone sill; inlet and outlet retain the
previous assembly's pipe connection coordinates. This is static fictional
game machinery, not an operating or thermodynamically validated condenser.

## Editable machine components

| Assembly | Parts |
| --- | ---: |
| Skid, feet and supporting frame | 9 |
| Paired pressure-vessel components | 36 |
| Exchanger core and fourteen cooling fins | 15 |
| Inlet, branch and return pipes | 6 |
| Connection flanges | 6 |
| Valve bodies and lever handles | 4 |
| Frame anchors | 4 |
| Total replacement | 80 |

The whole model remains **3,000 independently editable mesh objects**.
The other 2,920 objects retain their geometry and transforms. The v06 source
and GLB are preserved. The surgical-patch scope limits the change to this
machine and its delivery files: no map integration, branch, commit or push.

## Files

- `source/celestial_condenser_v07.blend`: editable Blender source.
- `celestial_condenser_v07.glb`: self-contained static export.
- `previews/01_hero.png`: full terrace view, actual Blender render.
- `previews/02_enginehouse.png`: close-up, actual Blender render.
- `parts_catalogue.csv` and `parts_manifest.json`: full component inventory.
- `validation_report.json`: source/export, preserved geometry, mounting and port checks.

New objects start with `CC7_`, preserve the replaced part IDs, and record the
old object name in `replaces`. Select one and press Tab to edit triangular faces,
edges and vertices. Shared materials remain shared; meshes are independent.

The validation report is the source of truth for checks actually run. Targeted
arch-envelope, mounting contact and pipe-endpoint checks do not replace a full
collision audit, animation tests, gameplay tests or structural engineering.
No live-map changes or optimized game-ready delivery are claimed.

Build: `tools/blender/build_celestial_condenser_v07.py`.
Validate: `tools/blender/validate_celestial_condenser_v07.py`.
