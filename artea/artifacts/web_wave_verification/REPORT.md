# Web wave verification — 29 August 2026

Result: wave rendering passes an actual WebGL2 browser test. The complete game build is not a clean release export.

## Browser evidence

- Standard non-Mono Godot 4.7.1 Web release export, Chromium WebGL2 Compatibility renderer.
- Fresh full-game export served locally on port 8800: loader completed all 1,072 MB; start screen rendered; Offline Guest entered the village; map opened in response to keyboard input.
- Full-game console reported a missing Firebase `.env` configuration. No shader or castle-script errors were observed in this browser run. Full-game movement, sailing, ocean-route traversal, and FPS were not benchmarked in the browser.
- The release template ignored the standalone `--script` benchmark launch. Its temporary diagnostic HTML was removed afterward.
- A disposable wave-only project in `/tmp/artea-wave-web-probe.SBQtND` was exported and served locally on port 8801. It uses unchanged copies of the game's two ocean scripts, eight shader/include files, and Blender curling-wave GLB, with the original import settings. Source file hashes/comparison confirmed matching game code and geometry; the fixture supplies only scene setup, lighting, cameras, and timing UI.
- Actual browser canvas: 1280×720, device pixel ratio 1. Five-second warm-up, then 20-second continuous animation sample: 2,400 frames, median 8.30 ms (~120.5 FPS), p95 9.30 ms. Six pooled wave nodes remained active. Browser timing is display-paced, not uncapped GPU time.
- Close-up and wide views visibly rendered blue displaced water, curling mesh, and foam. No warning/error entries from the wave-only page were observed.
- Screenshots: `close_up.png`, `wide.png`.
- This isolated result does not establish full-world performance, mobile performance, or compatibility with every browser/device.

## Focused checks

Run with `/Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --headless --path artea --script res://scripts/<test>.gd`:

- `test_stylized_ocean.gd`: PASS.
- `test_curling_surf.gd`: PASS.
- `test_web_environment_compat.gd`: PASS.
- `test_surf_spawn_pattern.gd`: PASS; four seeds, 240 ten-second blocks, exactly six starts per block, randomized gaps 0.53–2.76 seconds.
- `test_coastal_harbour.gd`: PASS, including native headless boarding/steering/sailing checks.
- `git diff --check`: PASS.

## Release blockers

`rtk bash scripts/export_web.sh` produced 134 PCK parts but emitted missing-resource errors for:

- `res://assets3D/stylizedNature/Grass_Common_Short.gltf`
- `res://assets3D/stylizedNature/CommonTree_1.gltf`
- `res://assets3D/worlds/low_poly_cloud.glb`

The export script returned success despite those errors; the build is not approved for release. Export log: `/tmp/artea-wave-web-verification-export.log`.

Verification-only work: no product code changes, commits, pushes, or deployments. Unrelated asset/configuration problems were not modified.
