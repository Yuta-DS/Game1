# Clearer wave shape — 29 August 2026

Applied in the game shaders, with matching copies in the local Web wave preview:

- Curl forms earlier and remains upright longer before collapsing.
- Slightly taller cross-section within the existing depth-based crest limit.
- A narrow, continuous white crown and lip define the silhouette; the wall remains blue, with a darker hollow.
- Reduced fine normal disturbance and background whitecaps improve shape readability.
- Foam fades near the waterline; wash and spray timing follow the later collapse.
- Same six pooled Blender meshes, 5,250 vertices per mesh, 96 instanced droplets per wave, random spawn schedule, height targets, and sailing clearance.

Verification:

- Updated `test_stylized_ocean.gd` readability guards: PASS.
- `test_curling_surf.gd`, `test_surf_spawn_pattern.gd`, `test_coastal_harbour.gd`, `test_web_environment_compat.gd`: PASS.
- Native hub capture and Compatibility capture: PASS without script/shader errors.
- Actual local WebGL2 preview: inspected formation, curled crest, collapse, and wash. No errors from the wave-only page.
- 1280×720, DPR 1, five-second warm-up, 20-second wave-only sample: 2,400 frames, median 8.30 ms (~120.5 FPS), p95 9.20 ms. This is display-paced isolated-scene timing, not a full-game FPS guarantee.
- Preview camera now follows its pooled wave for inspection; the game camera is unchanged.
- Actual browser images: `clarity_phase_0.png` (formed crest), `clarity_phase_1.png` (collapse), `clarity_phase_2.png` (wash).

Full Web export produced 136 pack parts but still reports the pre-existing missing `Grass_Common_Short.gltf`, `CommonTree_1.gltf`, and `low_poly_cloud.glb` resources. Export log: `/tmp/artea-wave-clarity-export.log`. Not deployed. No commits or pushes.
