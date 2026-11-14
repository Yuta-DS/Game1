# Rooftop fountain refinement — 28 August 2026

Status: implemented and verified locally. Not exported or deployed to production in this delivery cycle.

## Implemented

- Basin diameter 3.304m (40% wider); stone crown 2.3125m (25% taller).
- Shifted 0.4m inward to retain a continuous player-width aisle beside the garden.
- Reused the existing fountain and its castle-style materials. The original castle palette/atlas, garden, bridge and rooftop guard geometry remain unchanged.
- Blender stone: 78 editable components, 42,048 triangles. Curved sections use up to 192 radial stations and profile edges of at most 0.12m; seam/pole vertices are welded and degenerate geometry removed.
- Rounded segmented coping, restrained masonry patches, turned/fluted pedestal, carved carp spouts and aged brass crown.
- Eight gravity-shaped water streams, finer animated surfaces, 32 travelling droplets and 80 instanced impact droplets. Translucent water, moving highlights, local foam and expanding impact ripples.
- Water effects are real-time animation, not a fluid simulation. They do not require screen/depth textures, compute shaders or a baked fluid cache.
- Hidden simple stone collision remains aligned with the visible floors/rims. No collision on water, droplets or tiny carving details.
- Builder's new `--fountain-only` mode preserves bridge and foliage outputs and saves a separate editable Blender master.

## Evidence

- `01_fountain_closeup.png`: actual native in-game fountain.
- `02_fountain_castle_garden.png`: rooftop circulation and castle context.
- `03_water_and_carving.png`: close view of flowing water and rounded stone.
- `fountain_in_game.mp4`: four seconds, 960×540, 120 frames at 30fps, captured in the game.
- `render_mobile.png` and `render_gl_compatibility.png`: isolated fountain using both real renderers.

## Verification

Passed in this cycle:

- `test_castle_royal_fountain.gd`, headless and native mobile: imported size/triangle budget; animated morphs/droplets; eight solid rim probes; eight sprint impacts and escapes; complete surrounding aisle; three basin/rim landings and exits.
- `test_castle_fountain_render.gd`, mobile and GL compatibility: actual water pixels change over time and instanced splash droplets move. No fountain shader compilation failures.
- `test_castle_rooftop_garden.gd`: central paving, perimeter planting, collision impacts, corners, landings and exits. Its old two-metre centre waypoints were inside the enlarged fountain's collision clearance; the centre-floor test now uses the clear one-metre radius. The separate fountain test exercises the whole outer aisle with the real player.
- `test_castle_rooftop_barrier_safety.gd`: sprint impacts and escape at protected rooftop edges.
- `test_castle_player_route.gd`: crown gateway, bridge, terrace, final ascent, threshold and diagonal bridge mouths.
- `test_castle_reference_style.gd`: castle palette/masonry consistency and original atlas preserved.
- `test_art_castle_gallery_flow.gd`.
- `test_world_minimap.gd`.
- `test_gallery_embedded_floating_world.gd`.
- `test_train_station_jump_traversal.gd`.
- `test_story_crown_railway.gd`.
- `test_web_environment_compat.gd`.
- Focused GLB reimport and `git diff --check` succeeded.

The existing project still emits UID fallback, Terrain3D mipmap and teardown/resource-leak warnings in some full-world tests. These are not evidence of a clean whole-project audit. No unrelated gameplay or asset changes were made to suppress them.

## Production blockers

The existing Web preset uses `all_resources`, including two preview scenes with unresolved dependencies:

- `textures/grass_common_short_2.tscn` → missing `assets3D/stylizedNature/Grass_Common_Short.gltf`.
- `textures/common_tree_12.tscn` → missing `assets3D/stylizedNature/CommonTree_1.gltf`.

Both missing files were reconfirmed in this cycle. The preset was not changed. Available disk space also remained below 200MiB near handoff, insufficient for a safe full Web export. The maintained export script deletes old pack parts before exporting, so it was not rerun against these known blockers.

Production URL: https://artea-web.vercel.app/ (unchanged).
New deployment ID: none.
Production browser verification: not performed; the new build was not published.
Native GL compatibility is verified, but it is not a substitute for an actual deployed WebGL2 browser check or testing every operating system.

No Git commit or push was made in this cycle. Unrelated ongoing workspace changes were preserved.
