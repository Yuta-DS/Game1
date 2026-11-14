# Stair and stair-castle matching pass — 29 August 2026

## Local implementation

The spiral stairs and tower now reuse the main keep's existing architectural vocabulary, materials and window components. The approved front courtyard, bridge, fountain and main castle remain in place.

- Twelve substantial, solid, red-roofed stair piers replace the slender finials. Their shallow round-arched recesses and dark capitals match the keep.
- Twenty-two low, solid battlements sit above the unbroken outer safety wall. No gaps were cut into the guard, and the piers and battlements stay outside its lane-facing boundary.
- The tower has broader dark structural belts, shallow dressed course lips, forty tapered corner strips and ten red pennants. Existing round windows and sparse stone patches remain.
- The floor heights, tread widths, visible stair geometry and continuous walking sheet are unchanged.
- A new real-input sprint/turn test exposed an existing outer-guard collision snag. It reproduced with all new ornament collisions disabled. The outer guard's legacy inward-facing collision triangles were corrected; the inner guard/roof transition was preserved. Refining the floor mesh did not solve the issue and was reverted.
- Both stair sides now pass ten real-input sprint impacts and escapes. The new roofed piers, capitals and battlements have matching collision shapes. Small decorative window frames remain backed by the solid piers.

This pass follows the lean-build skill by reusing existing castle components and preserving the established walking route, rather than introducing another architectural system.

## Verification

Focused assertions passed: new stair keep details, three spiral lanes, full terrain-to-crown ascent/descent, jump transitions, loose-prop support, shared reference style, moss preservation, rooftop perimeter, inner rooftop guard, bridge traversal, full player-to-gallery route, rooftop garden, final castle entrance and front-court style.

The five repository baseline suites were also exercised: gallery flow, minimap, embedded gallery world, train-station traversal and Crown Line. Their assertions passed; some earlier runs logged an unrelated Mind Spark modular-foundation resource/instantiation error from concurrent world work. This is not a claim that all game subsystems are error-free. The final full castle/player route rerun passed without that script error.

Two actual rendered colour fixtures passed: Mobile and GL Compatibility. Four material roles match the main keep's imported atlas within 0.00392 maximum RGB difference. No shader or renderer-specific material change was required.

Six actual in-game camera views were captured in each renderer. The main folder contains Mobile captures; `gl_compatibility/` contains the desktop GL captures. The castle renders correctly in both. The desktop GL full-world capture does not invoke the Web-only terrain fallback and shows terrain differences; it must not be presented as a verified browser build.

Main result: `06_stair_detail.png`. Full staircase: `02_spiral_stair.png`. Opposite side: `05_reverse_stair_view.png`.

## Web delivery limitation

Not exported or deployed in this delivery cycle. Existing production URL: https://artea-web.vercel.app/. New deployment ID: none. Browser verification: not performed.

Read-only checks still find both missing source assets referenced by included scenes:

- `assets3D/stylizedNature/Grass_Common_Short.gltf`, referenced by `textures/grass_common_short_2.tscn`.
- `assets3D/stylizedNature/CommonTree_1.gltf`, referenced by `textures/common_tree_12.tscn`.

The existing all-resources Web export remains blocked. No scene exclusions, gameplay removal or substitute vegetation was introduced. The maintained exporter was not rerun against the known missing-resource blocker because it removes prior split-pack output first.

No Git commit or push. Other worktree changes were preserved.
