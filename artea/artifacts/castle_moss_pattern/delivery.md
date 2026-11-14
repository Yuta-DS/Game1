# Redesigned moss pattern — 2026-08-29

## Design

Replaced the large rounded patches with smaller, irregular colonies, broken
feathered outlines, narrow vertical fronds, and olive-green tuft highlights.
Fine shading gives the moss slight visual relief without adding geometry.
Subpixel detail fades with distance to limit shimmer.

The pattern remains fixed in world space across frames and wraps around the
existing curved walls and corners. The existing reduced-density setting is
preserved. Both terrace sides and the already moss-covered castle stairs use
the same material. No new moss surfaces were added during this task.

The surgical-patch scope was limited to moss appearance and its proof/capture
utilities. Floors, mesh shapes, collisions, movement, and unrelated scene
features were not edited.

## Verification

- Actual in-game captures inspected from both terrace sides and at close range.
- Mobile render: 37.2% of full-coat coverage retained; 10.22 visible colony-edge
  transitions per sampled row.
- GL Compatibility render: 39.2% retained; 10.35 transitions per row.
- Both renderers pass frame-stability and unpainted-horizontal-surface checks.
- Full moss regression passes: 264 selected surfaces, both sides covered,
  idempotent application, 887 collision shapes preserved.
- Courtyard regression passes: floor probes, gate traversal both ways, fire
  circuit, stairs, wall impacts/escapes, and jump landing.
- Castle route and reference-style assertions pass.
- Gallery flow, embedded floating world, minimap, station jumping, Crown railway,
  and Web environment compatibility assertions pass.

## Delivery status

Implemented and verified locally only. No export, deployment, or production
browser verification was performed in this cycle; no new deployment ID exists.
The existing production URL is https://artea-web.vercel.app/ and has not been
updated by this task.

The complete Web export still includes two scenes with missing source assets:
textures/grass_common_short_2.tscn references
assets3D/stylizedNature/Grass_Common_Short.gltf, and
textures/common_tree_12.tscn references
assets3D/stylizedNature/CommonTree_1.gltf. Their absence was rechecked. The Web
preset was not changed to hide these errors, and the known failing export was
not rerun because it removes existing split build files before failing.

No Git commit or push was made. Unrelated resource-cleanup warnings occur in
some regression runs. The initial gallery/route runs also encountered a
Mind Spark island resource-loading error and the gallery API JSON error;
these are outside the moss change. Both gallery/route tests were rerun after
the concurrently supplied island import became available: the island loading
error did not recur and both tests passed. The gallery API JSON error remains.
