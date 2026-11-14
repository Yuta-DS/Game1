# 10× wider / 3× taller waves — 29 August 2026

Implemented in `scripts/curling_surf.gd`:

- Every seeded width is multiplied by exactly 10; base 7–13m becomes 70–130m, or 59.5–149.5m including the existing ±15% width variation.
- Every depth-dependent breaking-wave height target is multiplied by exactly 3, producing 1.5–4.5m targets. Instantaneous visible heights still rise and fall with the animation.
- Curl depth also scales by 3 to preserve the rounded cross-section. Shared geometry places the spray on the enlarged lip; surface wash and CPU/GPU water blending use the matching footprint.
- Enlarged custom bounding boxes prevent long/tall displaced geometry and spray from being incorrectly culled. Spray visibility distance accounts for the longer crest.
- Six offshore positions now occupy separated rows, keeping complete rotated wave/wash footprints inside the 1km water mesh and outside the 80m sailing corridor.
- Preserved six random starts per ten seconds, shared wind, same pooled meshes, 5,250 vertices per breaker, and 96 instanced droplets per wave.

Verification:

- `test_curling_surf.gd`: PASS. Checks exact 10× width and 3× target height per seeded event, full rendering bounds, shared depth scaling, boat clearance, zero-wave setting, CPU/GPU blend consistency, and identical wave mesh/style across slots.
- `test_surf_spawn_pattern.gd`: PASS. Four seeds and 240 ten-second blocks; six starts/block; random gaps 0.53–2.76s; offshore footprint/corridor bounds; non-overlapping rotated footprints; unchanged node identities and spray clock.
- `test_random_ocean_waves.gd`, `test_coastal_harbour.gd`, `test_stylized_ocean.gd`, `test_web_environment_compat.gd`: PASS.
- Native full-hub graphical capture: PASS, no script/shader errors.
- Actual WebGL2 close-up and wide views: enlarged waves visible without shader/runtime errors from the wave-only page.
- 20-second wave-only sample, 1280×720 / DPR 1: 2,400 frames, median 8.30ms (~120.5 FPS), p95 9.20ms. This is display-paced isolated-scene performance, not a full-game or all-device guarantee.
- The temporary preview's camera framing was adjusted for a partial-crest close-up and a full-length overview. The game's player camera is unchanged.
- Browser screenshots: `xl_wave_phase_2.png`, `xl_wave_wide.png`.

Full Web export still emits the existing missing-resource errors for `Grass_Common_Short.gltf`, `CommonTree_1.gltf`, and `low_poly_cloud.glb`; it is not approved for release. Export log: `/tmp/artea-xl-waves-export.log`. No deployment, commit, or push.
