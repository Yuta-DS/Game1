# Castle terrace: moss on both sides

Added the existing scattered moss treatment to both arrival-court side barriers,
their returns, the upper-court side barriers, and the vertical terrace fascia
and skirt faces shown in the reference screenshot. The previous 0.4 retained
coverage setting is unchanged, with stable world-space random placement.

This is a narrowly scoped material change. The floor height, stone finish,
mesh geometry, stairs, bridge, plants, fire, and collision shapes are unchanged.
The shader excludes horizontal walking surfaces and horizontal undersides.

## Verification

- Full moss regression: 264 selected surfaces; both terrace sides covered;
  idempotent application; 887 collision shapes preserved.
- Real-pixel shader checks pass in Mobile and GL Compatibility renderers:
  stable patches across frames and no moss on the horizontal test surface.
- Courtyard traversal: floor probes, gate lanes, fire circuit, stairs both
  ways, wall impacts/escapes, and jump landing pass.
- Castle player route, royal entry, and reference-style regressions pass.
- Art Castle gallery flow, embedded floating world, minimap, train station
  jump traversal, Crown railway, and Web environment compatibility pass.
- Actual runtime captures inspected from both terrace sides, not mockups.

## Delivery limitation

Local implementation and native verification only. No production deployment
was made; there is no new deployment ID and no browser verification for this
change. The existing production URL is https://artea-web.vercel.app/.

The complete Web export remains blocked by missing source assets referenced
by scenes included in the Web preset:

- textures/grass_common_short_2.tscn references the absent
  assets3D/stylizedNature/Grass_Common_Short.gltf.
- textures/common_tree_12.tscn references the absent
  assets3D/stylizedNature/CommonTree_1.gltf.

The export preset and its feature/resource coverage were preserved. The known
failing export was not rerun, avoiding removal of existing split build files.
Unrelated test logs also contain resource-cleanup warnings and a nonfatal
API_Manager JSON-response error during the gallery test; its assertions passed.
No commits or pushes were made.
