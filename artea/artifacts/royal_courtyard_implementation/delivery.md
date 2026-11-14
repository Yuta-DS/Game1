# Royal entrance courtyard — local implementation

Implemented the approved courtyard concept in the actual Godot hub, not an image overlay.

- Wide gate: 10.6 m clear opening; paired towers meet the side perimeter at ±7.5 m.
- Closed masonry arch, continuous solid perimeter, fitted bridge-mouth returns.
- Central live fire, its pedestal grounded at (-23.65, 67.97, 27.41).
- Blue-grey ashlar paving, subtle eight-petal inlay, paired royal flower beds.
- One authoritative courtyard floor at y=67.97, matching the bridge landing.
- Seven regular solid ceremonial treads, grounded newels and closed cheek walls.
- Lower ascent landing no longer projects across the ceremonial steps.

## Root cause of the sunken-player appearance

The old decorative terrace skirt used the upper-court datum. Its visible top was
y=68.63, above the physical walking floor. It hid the player's lower body, the
new paving and the planter bases. `CastleArrivalUnderside` now ends at y=67.37,
under the single 0.6 m floor slab. The raised receiving rectangle is removed.
The inlaid flower changes colour only and never displaces the floor.

## Verification

Passed focused checks:

- `test_castle_royal_courtyard`: 28 support probes, four gate lanes both ways,
  complete circuit around the fire, stair ascent/descent, six wall impacts and
  escapes, jump landing, matching floor/underside/fire heights.
- `test_castle_masonry_bridge`: three bridge lanes both ways, 72 support/feet
  probes, six wall impacts/escapes.
- `test_castle_player_route`: crown → bridge → both courtyard aisles → castle
  threshold, return journey and diagonal bridge mouths.
- `test_castle_redesign`, `test_castle_entrance`, `test_web_environment_compat`.
- Gallery flow, world minimap, embedded world, station jumping and Crown Line.

The broader checks exposed two existing runtime errors. Gallery placeholder
images are now decompressed before resizing; removed island animation details
are skipped safely. `test_castle_gallery_runtime_guards` covers both cases.
Gallery flow, embedded-world, station and full player-route tests were rerun
without the previous resize/freed-instance exceptions.

Actual in-game captures: `01_courtyard_overview.png`, `02_ground_and_fire.png`,
`03_stair_landing.png`, `04_player_on_paving.png`, `05_wide_gate.png`.
Captured with native Forward Mobile. Compatibility also renders the courtyard;
native Terrain3D has a separate existing OpenGL shader compilation problem.
The existing Web terrain replacement does not use that native Terrain3D shader.
Courtyard palette conversion follows the [Godot spatial shader colour-space
contract](https://docs.godotengine.org/en/latest/tutorials/shaders/shader_reference/spatial_shader.html),
so its stone colours match across Compatibility and linear renderers.

## Web delivery blocker

The maintained non-Mono export script generated 105 pack parts, but reported
missing models referenced by two unused preview scenes:

- `textures/grass_common_short_2.tscn` → `assets3D/stylizedNature/Grass_Common_Short.gltf`
- `textures/common_tree_12.tscn` → `assets3D/stylizedNature/CommonTree_1.gltf`

Neither model exists locally or in accessible Git history. Searches found no
gameplay references to either preview scene. No source assets were substituted
or deleted. Awaiting permission to exclude these two unused previews from Web
export while preserving the rest of the preset and every gameplay feature.

Not deployed; no new deployment ID or production browser verification.
The existing https://artea-web.vercel.app/ is not claimed to contain this work.
No commit or push performed.
