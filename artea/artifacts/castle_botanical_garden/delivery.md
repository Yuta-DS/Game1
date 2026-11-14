# Centred fountain and royal botanical dressing

Date: 2026-08-28

## Implemented locally

- Moved the existing animated fountain to the exact rooftop centre and relocated the small floral paving inlays around its basin.
- Added restrained, fresh moss, fine fibres, veined leaves and ivory/lavender blossoms to selected stonework across the spiral stairs, rooftop borders, bridge, royal stair, gate, court, tower and original keep.
- Reused the existing castle stone anchors and materials. Preserved shields, windows, doors, walking surfaces and collision geometry. Lowered nearby planting to clear stair posts.
- Batched 117 shallow, wall-attached clusters into nine mesh surfaces. The botanical dressing adds no collision objects or floor layers.

## Verification

Passed focused tests: centred royal fountain, botanical placement/geometry/idempotence, rooftop garden circulation, rooftop barrier safety, full spiral route, real castle player route, stair dynamics, royal entry, masonry bridge and reference-style preservation.

Passed regression tests: Art Castle gallery flow, embedded floating world, story crown railway, world minimap, train-station jump traversal and Web environment compatibility.

Botanical render checks passed in native Mobile and GL Compatibility renderers. These are not browser tests. Full-world test runs still emit existing resource-UID fallback, terrain and shutdown warnings; no whole-project error-free claim is made.

Final real-game screenshots:

- `01_centred_fountain.png`
- `02_spiral_garden.png`
- `03_royal_stair_and_gate.png`
- `04_castle_garden_overview.png`
- `05_moss_leaf_fibre_detail.png`
- `06_original_keep.png`

## Delivery limitation

Local implementation and tests are complete. This version has not been exported, deployed or verified in a production browser.

Existing preview scenes still reference missing resources:

- `textures/grass_common_short_2.tscn` → `assets3D/stylizedNature/Grass_Common_Short.gltf`
- `textures/common_tree_12.tscn` → `assets3D/stylizedNature/CommonTree_1.gltf`

The Web preset exports all resources. Its configuration has been preserved, and neither preview scene was removed or excluded without direction. Resolve these missing references or authorize excluding these two broken previews before the maintained Web export and production verification can proceed.

Production URL: https://artea-web.vercel.app/ (unchanged by this work).
New deployment ID: none.
Production browser verification: not performed this cycle.
No Git commit or push was made.
