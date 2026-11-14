# Main castle style unification — 29 August 2026

## Implemented locally
The original Art Castle keep is the reference; its mesh and atlas are retained. The spiral stair tower, rooftop, stone bridge, front courtyard and final entrance now reuse its grey stone, darker structural courses, red roofs, round-arched windows and restrained raised masonry accents.

- Shared palette: wall `818c91`, dressed stone/floor `9198a2`, structural trim `586065`, recess `42494b`, red roof `ef443d`.
- Replaced the six tall classical columns and overhead lintels with four compact, physically solid red-roofed castle turrets. Kept both side aisles open.
- Replaced the old rounded topiary/anonymous stone props with four low medieval herb plots, using the rooftop garden's existing components.
- Unified the bridge/courtyard gate and castle doorway arches; retained the door, central fire, fountain, garden and walking connections.
- Added solid low battlements only above the existing rooftop guard wall footprints. Gateway and stair openings remain usable.
- Gave the spiral barriers full-width dark stone coping. Removed duplicate visual top faces so the coping and wall no longer flicker/intersect at the seam. Collision meshes retain their original winding and bounds.
- Kept floors at their established physical heights; no decorative layer was raised through the player.
- Reduced moss density and kept it off structural courses, coping and raised masonry so the architecture remains readable.

The implementation reused the existing material, architectural and garden components rather than adding an independent decorative style.

## Verification
19 structural/gameplay test scripts passed, including the new main-keep unification test. Coverage includes:
- Three spiral lanes; terrain-to-crown ascent/descent and jump transitions.
- Full crown, bridge, terrace, final stair and gallery door route.
- Rooftop guards, angled sprint impacts, corner releases and stairwell-edge protection.
- Both new courtyard side aisles in both directions, four turret impacts/escapes, turret roof solidity and grounded herb beds.
- Single-owner spiral coping surfaces; battlements contained above existing guard footprints.
- Fountain rim/aisles; gallery transition; minimap; embedded gallery world; train station and Crown Line regression checks.
- Web environment compatibility policy (a local source/runtime check, not browser verification).

Six additional rendered fixture runs passed: three fixtures on each of Godot Mobile and GL Compatibility.
- Four shared material roles against the main castle's actual imported atlas: maximum RGB difference 0.00392 on both renderers.
- Dressed floor shader against StandardMaterial: difference 0.00000 on both renderers.
- Moss: stable pattern, horizontal surfaces unchanged; retained 12.9% / 14.4% of a full coat in the fixture samples.

Some full-world test harnesses still log unrelated inventory initialization, external gallery response and exit resource-leak diagnostics. These checks do not establish that every game subsystem is bug-free.

## Actual game captures
All five images are fresh local Godot game renders at 1600 × 1100, not generated concept art or browser captures:
1. `01_full_castle_route.png`
2. `02_spiral_stair.png`
3. `03_stair_castle_rooftop.png`
4. `04_art_castle_front.png`
5. `05_reverse_stair_view.png`

Capture command:
```sh
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://artifacts/castle_route_overview/capture.gd -- --output=res://artifacts/main_castle_unified_route
```

## Web delivery: blocked, not deployed
Existing production URL: https://artea-web.vercel.app/
No new export or deployment was made for this redesign. No new deployment ID. Browser verification was not performed; these changes are not claimed to be live.

Read-only checks confirmed two referenced source assets are still missing:
- `textures/grass_common_short_2.tscn` references `assets3D/stylizedNature/Grass_Common_Short.gltf`.
- `textures/common_tree_12.tscn` references `assets3D/stylizedNature/CommonTree_1.gltf`.

Both scenes remain in the all-resources Web export. The maintained exporter was not rerun against this known blocker because it removes previous split-pack output before the export fails. No export exclusions, feature removals or unrelated asset substitutions were made.

No Git commit or push. Unrelated worktree changes were preserved.

