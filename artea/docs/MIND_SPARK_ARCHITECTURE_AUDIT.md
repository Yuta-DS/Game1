# MineSpark terrace — architecture audit and repair

Reviewed against the two screenshots supplied on 28 August 2026, at 15:14:49
and 15:15:04. This is a game-art construction-logic review, not a real-world
structural design, load calculation, or safety certification.

## Findings and response

| Screenshot | Observed problem | Implemented correction |
| --- | --- | --- |
| First: outer pier | The façade stood forward of a narrowing cliff. Its plinth had no modeled bearing into the solid rock core, so it read as hanging unsupported. | Four connected, beveled bearing stones beneath each of the three piers step inward and backward into the actual core. |
| First: projecting capital | The straight capital/cornice ended abruptly beside the curved deck edge. | Two return stones at each outer corner connect the capital to the circular deck shell. |
| Second: space between arches | Random rock occupied the space between two formal arch tiers. The thin lower arch read as applied ornament, not a deliberate masonry assembly. | Eighty fitted ivory ashlar blocks fill this band in four staggered curved courses per bay. Twelve curved lining pieces finish the upper arch's inner edge. Forty lower-arch segments deepen backward from 0.14 m to 1.15 m, preserving their original front plane. |

The intended visual sequence is deck/cornice → arch-and-wall assembly → pier →
stepped bearing → rock core. This describes the modeled arrangement, not a
verified force path. The lower arch remains a blind architectural recess with
rock behind it, not a newly created walk-through passage.

## Shape and material decisions

- Keep the established ivory, cream, champagne-gold palette and heavenly finish.
- Follow the upper arch's inner curve and lower arch's outer curve; do not insert
  unrelated rectangular blocks that cut across the existing silhouette.
- Use staggered joints, narrow reveals and 12 mm bevels on the new fitted bricks.
  Curves are sampled before triangulation; smoothness does not come from triangle
  count alone. The stone supports have 35 mm edge bevels.
- Recess the new masonry behind the existing gold-and-stone arch face, retaining
  depth and shadow. The lower natural-rock recess is intentionally left visible.
- Replace excessive lower-arch rivets with useful construction parts and a
  restrained set of anchors; retain the original façade rhythm and map footprint.

## Part accounting

Exactly 120 repetitive lower-rib rivets were replaced inside the revised model:

| Replacement | Editable mesh parts |
| --- | ---: |
| Curved ashlar backing | 80 |
| Carved intrados lining | 12 |
| Pier bearing stones | 12 |
| Cornice returns | 4 |
| Lower arch anchors | 12 |
| Total replacements | 120 |

Total remains **3,000 independent mesh objects**, in the same nine families.
The 470-part façade allocation is unchanged. The other 2,880 IDs are retained;
40 existing lower-arch meshes also receive the depth/material correction.
Each replacement records its old object name in the `replaces` property.
Current source/export triangle count: **2,237,308**.

## Evidence and limits

- `validation_report.json`: all 32 source/export checks pass, including a fresh
  GLB re-import, independent meshes, triangle-only faces, finite coordinates,
  closed mesh islands, positive volume, UV presence and preserved names/counts.
- `architecture_audit.json`: all 10 targeted component/connection checks pass.
  Original pier plinths had zero vertices inside the core; bottom bearing stones
  now have 36, 72 and 36 vertices inside it. All bearing-course bounds meet, and
  the four corner returns touch capital bounds and penetrate the deck geometry.
- Connection checks use bounding-box contact and nearest-surface normal tests.
  They are useful regression checks, not proof of full-face bearing, mortar bond,
  fastener anchorage, resistance to arch thrust, or physical structural stability.
- A local regression reproduced inverted normals in four translated, beveled
  corbels after triangulation. Building those solids around their local origins
  corrected the issue. The final source and export pass the volume checks.
- The previous 32 checks covered mesh integrity, not architectural relationships.
  Passing them did not establish that the earlier support arrangement made sense.

Actual Blender views: `previews/06_pier_support.png` and
`previews/07_curved_masonry.png`. The presentation board and the five wider
views have been refreshed for this revision. anyCreature uses a separately
decimated preview because the full-detail GLB exceeds its 64 MiB input limit;
it is not a substitute for the master or an architecture validator.

No real-world engineering, pixel-exact reference matching, live gameplay,
collision, navigation, animation or game-performance approval is claimed.

## Recovery and repeatability

Output root: `assets3D/mind_spark/celestial_terrace_3000/`.
Pre-repair source: `source/before_architecture_audit.blend`. The original
1,000-part asset is unchanged. No branch, commit, push, deployment or live-map
integration was performed. The surgical-patch skill kept the change confined to
the highlighted assembly and its evidence/presentation files.

`tools/blender/repair_celestial_architecture.py` implements the repair, and the
full 3,000-part builder invokes it. Use `-- --verify-saved` with Blender to
refresh connection checks on the saved master without modifying its geometry.
`-- --from-backup` intentionally regenerates the repaired master from the
preserved before-repair source; do not use it after making unrelated manual
edits without first saving those edits separately.
