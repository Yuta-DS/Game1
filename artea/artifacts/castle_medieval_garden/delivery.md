# Medieval-inspired castle garden and parapet fires

Date: 2026-08-28

## Local result

- Replaced every rooftop green-globe urn with a compact forged-iron brazier. Each flame has independent GPU sway and a flickering warm light; the ornament has two mesh surfaces and no collision.
- Replaced clipped boxwood, repeated iris diamonds and crown medallions with low sage, rue and chamomile plots separated by woven hazel dividers.
- Reworked the wall dressing as connected, irregular moss mats with sparse ivy and fibres. Growth remains shallow, wall-attached and visual-only; it adds no floor layer or collider.
- Preserved the centred animated fountain, existing stone planters, castle masonry, shields, windows, stair barriers, floor and collision geometry.

This is an artistic medieval-inspired treatment, not a claim of exact archaeological reconstruction. Plant selection was informed by English Heritage's overview of medieval monastic herb gardens: https://www.english-heritage.org.uk/visit/inspire-me/blog/blog-posts/grow-medieval-herb-garden/

## Verification

Passed focused tests:

- rooftop herb garden, torch alignment/animation, planter sprint/corners/jump landings and court circuit;
- botanical coverage, attachment, stair-post clearance, no new colliders and 65,496-triangle/nine-surface wall-dressing budget;
- flame/herb rendering and animated frame changes in Mobile and GL Compatibility;
- rooftop barriers, centred fountain, spiral route, masonry bridge, royal entry and castle reference-style preservation.

Passed regressions: Art Castle gallery flow, embedded floating world, story crown railway, world minimap, train-station jump traversal and Web environment compatibility.

Godot's existing full-world startup and shutdown warnings remain present; no whole-project warning-free claim is made.

## Delivery limitation

This revision was not exported, deployed or verified in a production browser. The Web preset still includes two preview scenes whose referenced source resources are missing:

- `textures/grass_common_short_2.tscn` -> `assets3D/stylizedNature/Grass_Common_Short.gltf`
- `textures/common_tree_12.tscn` -> `assets3D/stylizedNature/CommonTree_1.gltf`

The preset was preserved. Production URL https://artea-web.vercel.app/ is unchanged by this work. New deployment ID: none. No Git commit or push was made.
