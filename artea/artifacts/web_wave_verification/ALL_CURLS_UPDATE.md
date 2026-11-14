# One consistent breaking-wave style — 29 August 2026

All six spawned breaking waves use the same approved Blender curling mesh and the same blue-face/white-crest shader. Added a regression assertion checking every slot's mesh identity and shader path.

Removed the competing procedural whitecap pattern from the underlying ocean. Surface wash is now generated only from the actual breaking-wave patches. Reduced the background carrier field to 12% strength, including its analytic slopes and CPU boat-height sampling, so the 3D curls are the prominent wave shapes. The base still moves gently; it is not a second set of large waves.

Preserved six randomly timed starts per ten-second block, separated positions, prevailing wind, 0.5–1.5m depth-based breaking-wave targets, the harbour approach, six pooled 5,250-vertex meshes, and 96 instanced droplets per wave. No new geometry or particles.

Validation:

- `test_random_ocean_waves.gd`: PASS; carrier height -0.08 to 0.17m, coastal mesh/CPU interpolation error 0.002m, analytic slopes, deterministic wind, and Web uniform parity.
- `test_curling_surf.gd`: PASS, including identical mesh/shader for all six slots and preserved depth-dependent breaker targets.
- `test_stylized_ocean.gd`, `test_surf_spawn_pattern.gd`, `test_coastal_harbour.gd`, `test_web_environment_compat.gd`, `test_hub_sea_sky.gd`: PASS.
- Native hub renders: PASS, no script/shader errors.
- Updated local WebGL2 preview: close-up and wide views inspected, no errors from the wave-only page.
- Twenty-second isolated ocean sample at 1280×720 / DPR 1: 2,400 frames, median 8.30ms (~120.5 FPS), p95 9.20ms. This is display-paced wave-only performance, not a full-game/device guarantee.
- `git diff --check`: PASS.

Full export emitted 136 PCK parts but remains blocked for release by the existing missing `Grass_Common_Short.gltf`, `CommonTree_1.gltf`, and `low_poly_cloud.glb` resources. Log: `/tmp/artea-all-curls-export.log`. No deployment, commit, or push.
