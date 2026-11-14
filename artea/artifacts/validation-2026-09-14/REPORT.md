# Artéa validation — 14 September 2026

Tested `dd5f9802` on `testing-fix-overall-system`, including six existing modified source/test files listed in [working-copy.txt](working-copy.txt). No gameplay code was changed during validation.

Environment: macOS 26.5.1, arm64; standard non-Mono Godot 4.7.1; local Chrome headless WebGL2, 1280 × 800, Compatibility renderer. Browser profile was fresh. The smoke tool allows SwiftShader, so this is not a hardware/mobile performance measurement.

## Results

58 distinct automated tests: **43 passed**, **4 passed gameplay assertions but logged shutdown resource errors**, **11 failed or logged runtime/assertion errors**. Four failed tests hit the 90-second timeout after assertions. A zero exit code was not accepted as a pass when script errors were present.

The maintained Web export succeeded with no ERROR/SCRIPT ERROR messages. It generated 145 PCK parts, totaling 1,214,172,228 bytes. Export warnings include duplicate UIDs and shutdown object leaks; successful export does not establish every asset path is correct at runtime.

The local Web smoke test reached engine startup at about 11 seconds and built the Offline Guest hub at about 20 seconds. Screenshots confirm the start screen and rendered hub. Frames changed after W input, but animation can also change frames; this is not proof of complete movement/collision correctness. The browser logged an unhandled `WrongDocumentError` for pointer lock, so controls are not fully verified. No fatal missing-resource errors were detected by the smoke script.

## Findings requiring follow-up

- Train smoothness fails reproducibly: camera travel jumps 1.16 m against the 0.60 m limit, on both runs.
- Quest One story test fails “Quest One saves before opening its next path” at test line 68. This needs diagnosis before relying on progression persistence.
- Milo urgent-support test fails its response assertion at line 48 and times out.
- Milo live-hub test logs `Global`/`GameManager` compilation failures even though its visibility assertions pass.
- Chapter-world test logs invalid deferred audio-source arguments in `_configure_surround_source`.
- Milo character test expects `PrototypeEyeWhite_L`, while the current skin builds `CatEyeWhite_*`: likely an outdated asset expectation.
- Celestial land, quest objects, upper-detail batches, three-island fusion, and World One checks disagree with current layout/material/component/interaction expectations. These failures need diagnosis; they are not automatically proof the visuals are incorrect.
- Browser pointer lock throws an unhandled exception during the movement smoke check.

Train gear motion, driving/riding, station jump traversal, station physicality, minimap, gallery integration, Milo follow/natural animation/speech, checkpoint storage, shared quest state, puzzle runtime, perspective, and Island 1 quests 1–2 passed. The railway Web-performance profile passes with `ARTEA_FORCE_WEB_STATION_LOD=1`; the initial unconfigured invocation is retained in the logs.

## Scope remaining unverified

A complete player walkthrough of both islands, existing real-user saves, touch/phone/tablet controls, visual gear/cane inspection, browser p95/p99 frame times, and integration against the six other branches were not completed. Headless checks do not replace those checks. No production deployment was performed for this validation-only task.

GitLab returned no `testing-fix-overall-system` branch and no advertised ref at `dd5f9802`. The expected branch push is therefore not present; remote ancestry was not exhaustively checked. No push was attempted.

## Evidence

- [Structured test results](results.json)
- [Web export log](web-export.log)
- [Browser console](browser/console.log)
- [Start screen](browser/01-start-screen.png)
- [Hub after movement input](browser/04-after-move.png)
- Individual test logs are stored beside this report.

## Test matrix

| Test | Result | Evidence |
|---|---|---|
| test_art_castle_gallery_flow | PASS | [log](test_art_castle_gallery_flow.log) |
| test_crown_train_directional_vfx | PASS | [log](test_crown_train_directional_vfx.log) |
| test_crown_train_soft_smoke_wake | PASS | [log](test_crown_train_soft_smoke_wake.log) |
| test_crown_train_spatial_audio_integration | PASS | [log](test_crown_train_spatial_audio_integration.log) |
| test_crown_train_steam_engine_motion | PASS | [log](test_crown_train_steam_engine_motion.log) |
| test_gallery_embedded_floating_world | PASS | [log](test_gallery_embedded_floating_world.log) |
| test_milo_activity_routing | PASS | [log](test_milo_activity_routing.log) |
| test_milo_activity_states | PASS | [log](test_milo_activity_states.log) |
| test_milo_character | FAIL | [log](test_milo_character.log) |
| test_milo_chat_cursor | PASS | [log](test_milo_chat_cursor.log) |
| test_milo_companion_follow | PASS | [log](test_milo_companion_follow.log) |
| test_milo_conversation_context | PASS | [log](test_milo_conversation_context.log) |
| test_milo_generations | PASS | [log](test_milo_generations.log) |
| test_milo_guide | PASS | [log](test_milo_guide.log) |
| test_milo_live_hub_visibility | FAIL | [log](test_milo_live_hub_visibility.log) |
| test_milo_message_recognition | PASS | [log](test_milo_message_recognition.log) |
| test_milo_missing_walk_fallback | PASS | [log](test_milo_missing_walk_fallback.log) |
| test_milo_natural_animation | PASS | [log](test_milo_natural_animation.log) |
| test_milo_prototype_reference | PASS | [log](test_milo_prototype_reference.log) |
| test_milo_speech_animation | PASS | [log](test_milo_speech_animation.log) |
| test_milo_support_safety | FAIL | [log](test_milo_support_safety.log) |
| test_milo_wisdom_engine | PASS | [log](test_milo_wisdom_engine.log) |
| test_mind_spark_architecture_physics | PASS_WITH_CLEANUP_ERRORS | [log](test_mind_spark_architecture_physics.log) |
| test_mind_spark_celestial_land | FAIL | [log](test_mind_spark_celestial_land.log) |
| test_mind_spark_chapter_catalog | PASS | [log](test_mind_spark_chapter_catalog.log) |
| test_mind_spark_chapter_world | FAIL | [log](test_mind_spark_chapter_world.log) |
| test_mind_spark_checkpoint_store | PASS | [log](test_mind_spark_checkpoint_store.log) |
| test_mind_spark_completed_train_policy | PASS | [log](test_mind_spark_completed_train_policy.log) |
| test_mind_spark_encounter_director | PASS | [log](test_mind_spark_encounter_director.log) |
| test_mind_spark_galaxy_integration | PASS_WITH_CLEANUP_ERRORS | [log](test_mind_spark_galaxy_integration.log) |
| test_mind_spark_galaxy_traversal | PASS | [log](test_mind_spark_galaxy_traversal.log) |
| test_mind_spark_island_one_detailed_guidance | PASS | [log](test_mind_spark_island_one_detailed_guidance.log) |
| test_mind_spark_island_one_quest_1_signal_observatory | PASS | [log](test_mind_spark_island_one_quest_1_signal_observatory.log) |
| test_mind_spark_island_one_quest_2_echo_garden | PASS | [log](test_mind_spark_island_one_quest_2_echo_garden.log) |
| test_mind_spark_island_texture_coverage | PASS | [log](test_mind_spark_island_texture_coverage.log) |
| test_mind_spark_live_gate_blueprint | PASS_WITH_CLEANUP_ERRORS | [log](test_mind_spark_live_gate_blueprint.log) |
| test_mind_spark_perspective | PASS | [log](test_mind_spark_perspective.log) |
| test_mind_spark_quest_object_integration | PASS | [log](test_mind_spark_quest_object_integration.log) |
| test_mind_spark_quest_objects | FAIL | [log](test_mind_spark_quest_objects.log) |
| test_mind_spark_runtime | PASS | [log](test_mind_spark_runtime.log) |
| test_mind_spark_shared_state | PASS | [log](test_mind_spark_shared_state.log) |
| test_mind_spark_split_world | PASS | [log](test_mind_spark_split_world.log) |
| test_mind_spark_super_island_one_3000 | FAIL | [log](test_mind_spark_super_island_one_3000.log) |
| test_mind_spark_three_island_fusion | FAIL | [log](test_mind_spark_three_island_fusion.log) |
| test_mind_spark_transit_network | PASS_WITH_CLEANUP_ERRORS | [log](test_mind_spark_transit_network.log) |
| test_mind_spark_world_one | FAIL | [log](test_mind_spark_world_one.log) |
| test_mind_spark_world_one_story | FAIL | [log](test_mind_spark_world_one_story.log) |
| test_mind_spark_zone02_route_clearance | PASS | [log](test_mind_spark_zone02_route_clearance.log) |
| test_story_crown_railway | PASS | [log](test_story_crown_railway.log) |
| test_story_crown_railway_web_performance | PASS | [log](railway-web-performance-configured.log) |
| test_train_celestial_banner | PASS | [log](test_train_celestial_banner.log) |
| test_train_drive_and_ride | PASS | [log](test_train_drive_and_ride.log) |
| test_train_drive_smoothness | FAIL | [log](test_train_drive_smoothness.log) |
| test_train_rides | PASS | [log](test_train_rides.log) |
| test_train_station_jump_traversal | PASS | [log](test_train_station_jump_traversal.log) |
| test_train_station_physicality | PASS | [log](test_train_station_physicality.log) |
| test_world_minimap | PASS | [log](test_world_minimap.log) |
| test_web_environment_compat | PASS | [log](web-environment.log) |
