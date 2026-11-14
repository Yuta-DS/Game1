# Bottom castle stair finish — 2026-08-29

Local implementation and verification complete. Production delivery remains blocked.

## Implemented

- Replaced the two non-solid straight entrance barriers with closed, collision-backed stone walls. Their widths, end cuts and cap heights meet the existing spiral guards.
- Seated the visible entrance floor 2 cm inside each wall, eliminating the previous side slots. Kept the established physical floor height and applied flush flagstone colour/detail without adding a raised floor layer.
- Aligned both entrance capitals and red roofs to one floor datum; only their buried bases follow the hillside. Added solid post, capital and roof collision.
- Replaced the exposed tower footing blocks with a closed octagonal stone plinth, fitted into the terrain.
- Finished the first-flight retaining foundation with outward-facing collision, a modest battered footing and a grounded dark stone toe. The foundation meets the underside rather than overlapping it with a separate exposed strip.
- Reused the main castle's stone palette, dark trim, round-arched details and red roof components. Existing upper stairs, garden, fountain, bridge and main keep were preserved.

## Verification

Standard non-Mono Godot 4.7.1. All 21 checks passed:

1. `test_castle_bottom_finish.gd`: nine visible-floor/collision plane probes; six actual-controller wall impacts and escapes; entrance jump/landing; solid, aligned posts and roofs; foundation inventory.
2. `test_castle_ground_entry_route.gd`: three entrance lanes.
3. `test_castle_stair_dynamics.gd`: ground-to-crown ascent/descent, both jump transitions and loose-prop support.
4. `test_castle_stair_keep_details.gd`: ten actual-input impacts and escapes on both spiral sides.
5. `test_castle_inner_roof_guard.gd`: 50 edge probes and seven impacts/escapes.
6. `test_castle_rooftop_barrier_safety.gd`: six rooftop sections.
7. `test_castle_player_route.gd`: crown, bridge, terrace, final ascent and castle threshold.
8. `test_castle_spiral_route.gd`: three lanes and crown circuit.
9. `test_castle_reference_style.gd`.
10. `test_castle_full_moss.gd`.
11. `test_castle_masonry_bridge.gd`: three lanes both directions, 72 floor/foot probes and six impacts/escapes.
12. `test_art_castle_gallery_flow.gd`.
13. `test_world_minimap.gd`.
14. `test_gallery_embedded_floating_world.gd`.
15. `test_train_station_jump_traversal.gd`.
16. `test_story_crown_railway.gd`.
17. `test_web_environment_compat.gd` (source compatibility policy, not browser verification).
18–19. `test_castle_material_render.gd` under mobile and OpenGL Compatibility: zero sampled colour difference.
20–21. `test_castle_reference_atlas_render.gd` under both renderers: maximum sampled RGB difference 0.00392.

The final screenshot pass also drove the packed player into both entrance walls: neither crossing occurred. Rendered screenshots were inspected from the entrance, both sides and the first-flight foundation. No castle script or shader failures appeared. Existing full-world UID, resource-in-use and ObjectDB shutdown warnings remain; these are not a claim of a warning-free project. Scoped `git diff --check` passed.

## Fresh native screenshots

- `01_bottom_entrance.png`: flagstone floor, aligned entrance and player standing on its surface.
- `02_outer_ground_join.png`: continuous straight foundation and outside wall.
- `03_inner_ground_join.png`: inside wall and terrain join.
- `04_first_turn_underside.png`: enclosed lower first-flight support.
- `05_first_flight.png`: first-turn overview and grounded toe.
- `07_wall_contact_inner.png`, `07_wall_contact_outer.png`: player stopped at each wall.

## Web limitation

These two source assets are still missing:

- `assets3D/stylizedNature/Grass_Common_Short.gltf`, referenced by `textures/grass_common_short_2.tscn`.
- `assets3D/stylizedNature/CommonTree_1.gltf`, referenced by `textures/common_tree_12.tscn`.

The Web preset exports all resources and includes these scenes. Read-only checks found only related `.bin` files, not replacement source scenes, and no history for the two missing paths in local Git refs. Export/deployment was not retried against the known missing-resource blocker. No features were removed or excluded to bypass it.

Existing production URL: https://artea-web.vercel.app/ . No new deployment ID and no production browser verification in this delivery cycle. Native/OpenGL tests and screenshots do not establish that this change is live or verified on every OS.

No commit or push was made.
