# Reduced, randomly positioned stair moss

Local update, 2026-08-28.

Reduced the previous broad moss coat by approximately 60%, retaining irregular patches from the bottom to the top of the stair tower and final castle ascent. Independent world-space noise creates scattered positions that remain fixed between frames and across mesh joins. Existing small ivy/moss detail, garden plants, flames, underlying stone, floors and collision geometry are preserved.

Verification:

- Paired before/after render measurements over nine castle locations: 63.9% reduction in Mobile, 61.7% in GL Compatibility. These are sampled visible moss pixels, not an exact whole-castle area calculation.
- Static placement between rendered frames and unchanged horizontal surfaces: PASS.
- Coverage/preservation test: PASS, all 238 selected wall meshes and 887 collision shapes preserved.
- Rooftop walking/landing, full spiral route and final castle stair/door tests: PASS.
- Gallery flow, embedded floating world, story railway, minimap, train-station jump and Web environment policy regressions: PASS.
- `git diff --check`: PASS.

Screenshots: `01_bottom_to_top.png`, `02_ground_approach.png`, `03_middle_stair.png`, `04_rooftop.png`, `05_upper_castle_stair.png`.

No export, production deployment or browser verification this cycle. The two missing preview sources (`Grass_Common_Short.gltf`, `CommonTree_1.gltf`) remain absent; the export preset was preserved. The earlier ocean-shader invalid character was no longer present when checked, and the final capture did not report that shader error. Existing unrelated full-world resource/UID warnings remain.

Production URL: https://artea-web.vercel.app/ (unchanged).
New deployment ID: none.
Production browser verification: not performed.
No Git commit or push was made.
