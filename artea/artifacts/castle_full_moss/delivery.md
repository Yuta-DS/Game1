# Bottom-to-top stair moss

Implemented locally on 2026-08-28.

## Result

Broad, continuous moss now covers most of the selected stone wall faces of the stair tower, both spiral parapets, ground foundation/entry walls, rooftop walls and final castle stair. The shader follows world coordinates across neighbouring pieces and retains irregular exposed-stone patches.

Coverage is applied as a material overlay on 238 existing wall meshes. No mesh is displaced and no new floor, obstacle or collider is created. Treads, walking floors, windows, heraldry, roofs and flames are excluded; the shader also suppresses moss on horizontal top faces. Existing underlying stone materials and all 887 collision shapes remain unchanged.

## Tests

- Full-height coverage, geometry/material preservation and idempotence: PASS. Spiral spans the 27.63m ground datum to the 67.73m crown datum, with coverage continuing up the final castle stair.
- Real renderer wall-coverage checks: PASS, 68.5% green moss pixels in Mobile and 76.1% in GL Compatibility on the test panel. Horizontal test face stays unchanged. These are test-panel measurements, not whole-castle area measurements.
- Botanical placement, rooftop garden walking/landings, three spiral lanes, upper castle entry, rooftop wall impacts/escapes, masonry bridge and reference-style preservation: PASS.
- Gallery flow, embedded floating world, story railway, minimap, train-station jumping and Web compatibility policy: PASS.
- `git diff --check`: PASS.

Screenshots: `01_bottom_to_top.png`, `02_ground_approach.png`, `03_middle_stair.png`, `04_rooftop.png`, `05_upper_castle_stair.png`.

## Remaining delivery blockers

No production export/deployment/browser verification was completed in this cycle. The two previously identified missing preview resources remain absent (`Grass_Common_Short.gltf` and `CommonTree_1.gltf` under `assets3D/stylizedNature`). Export configuration is unchanged.

During later full-world tests/captures, an unrelated ocean shader error also appeared: `shaders/ocean_surface.gdshaderinc:36` contains the invalid numeric text `0湖.20`. That file was not changed by this work. Moss rendering passes independently, but the full game is not shader-error-free. Existing full-world resource/UID warnings also remain.

Production URL: https://artea-web.vercel.app/ (unchanged).
New deployment ID: none.
Production browser verification: not performed.
No Git commit or push was made.
