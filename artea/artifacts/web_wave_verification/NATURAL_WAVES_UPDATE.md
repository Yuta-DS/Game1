# Natural wave refinement — 29 August 2026

Refined the existing Blender-mesh/shader system rather than adding simulation or particles:

- Broad, uneven crest heights and gently wandering fronts replace the nearly uniform extrusion.
- Each random event's existing width supplies a stable variation phase. Different portions curl and collapse at different times without jittering frame to frame.
- The rear shoulder is fuller, and late breaking sections settle farther down toward the sea.
- Vertex noise is limited to eight broad cells across the crest, avoiding unresolved high-frequency geometry noise on the 56-segment mesh at 10× width.
- Softer, irregular foam patches retain the blue wave face instead of tracing a continuous bright outline.
- A small shared profile include keeps shell, spray and surface wash aligned in bending and breaking time.
- Preserved the prior 10× widths, 3× height targets (1.5–4.5m), six random starts per ten seconds, wind direction, offshore bounds, protected sailing corridor, six pooled meshes and 96 droplets per wave. No player-camera change.

Verification:

- PASS: `test_stylized_ocean.gd` (including new shared-profile, foam and geometry-frequency guards).
- PASS: `test_curling_surf.gd`, `test_surf_spawn_pattern.gd`, `test_random_ocean_waves.gd`, `test_coastal_harbour.gd`, `test_web_environment_compat.gd`.
- Native full-hub graphical capture passed without shader/script errors; close-up capture framing now accommodates the enlarged waves.
- Clean standard non-Mono export of the isolated wave fixture; actual WebGL2 formation, curl and collapse rendered at localhost:8801 without relevant browser warnings/errors.
- Two 20-second wave-only samples at 1280×720 reported 2,400 frames, 8.30ms median (~120.5 FPS) and 10.30ms p95. The repeat ran after native/export work finished (ready 15:38:46 UTC, pass 15:39:11 UTC). This is display-paced isolated-scene timing, not a full-game or all-device guarantee; p95 is 1.1ms above the prior XL sample.
- Browser evidence: `natural_wave_phase_0.png`, `natural_wave_phase_1.png`, `natural_wave_crest_0.png` through `_2.png`, and `natural_wave_wide.png`.
- `git diff --check`: passed.

Production delivery remains blocked: the full non-Mono Web export writes 136 PCK parts but reports existing missing resources `Grass_Common_Short.gltf`, `CommonTree_1.gltf`, and `low_poly_cloud.glb`, plus a TLS handshake error. The new `surf_profile.gdshaderinc` is included in the pack. Log: `/tmp/artea-natural-waves-export.log`. No errorful build was deployed; nothing committed or pushed.
