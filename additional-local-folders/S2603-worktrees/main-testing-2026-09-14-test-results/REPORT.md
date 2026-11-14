# Local main branch testing

Branch: `codex/main-testing-2026-09-14`
Source: `origin/main` at `e36ed38d`
Godot: `4.7.1.stable.official.a13da4feb`

Git fetch and Git LFS pull completed. Separate worktree preserves the original checkout and uncommitted work.

Startup and all 16 regression scripts exited with code 0. All regression scripts reported PASS or all checks passed.

Four tests reported resource cleanup errors at shutdown: embedded gallery, train traversal, lens journey, and hub lens. The lens persistence test intentionally exercises corrupt JSON recovery and passes. Initial import also reported missing MTL materials and stale UIDs; runtime tests reported no script parse errors.

Testing was headless; visual gameplay was not verified. No game source changes or deployments were made. Generated tracked import metadata was restored; the import cache remains available.

| Check | Exit code | Log status |
|---|---:|---|
| startup | 0 | No error entries |
| test_art_castle_gallery_flow | 0 | No error entries |
| test_world_minimap | 0 | No error entries |
| test_gallery_embedded_floating_world | 0 | See diagnostics above |
| test_train_station_jump_traversal | 0 | See diagnostics above |
| test_story_crown_railway | 0 | No error entries |
| test_mesh_cutter | 0 | No error entries |
| test_cutter_cap_loops | 0 | No error entries |
| test_frustum_cutter | 0 | No error entries |
| test_lens_collision | 0 | No error entries |
| test_viewfinder_lens | 0 | No error entries |
| test_lens_safety | 0 | No error entries |
| test_lens_photo_card | 0 | No error entries |
| test_lens_controller | 0 | No error entries |
| test_lens_journey | 0 | See diagnostics above |
| test_lens_persistence | 0 | See diagnostics above |
| test_hub_lens | 0 | See diagnostics above |
