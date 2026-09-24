# River Song — connected Heart Melody Island 2

Implemented 24 September 2026 from the Island 2 roadmap in `Heart Melody Island 1.pdf` (Waterfall Organ and Bell Grove).

## Play

The opening greeting and Help explain the route: plant all three seeds, solve the flower phrase, and clear both Blight waves. Saving is automatic; successful garden restoration opens the bridge and removes its barrier. If the save fails, the crossing stays locked until Help > Retry saving succeeds. The route sign updates when it opens, and loaded completed saves also open it.

Complete and save the Feeling Garden, then walk across its restored root crossing and through the River Song arch. Island 2 is in the same scene and uses the same player in both standalone Heart and the station-03 overworld.

1. Tune three Waterfall Organ valves. Each offers a replayable note, carved symbol and untimed choice; wrong answers preserve progress.
2. Release the three Hush Vine bulbs with Q / interaction.
3. Ring the Rain Boat dock bell and confirm **Board and sail**. Cancelling leaves the boat waiting. The six-second ride carries the player; movement is restored on arrival. Either dock can call the boat for the return trip.
4. Restore three bridge chimes in order. Each committed chime creates a collision-backed walking section.
5. Read the SAFE / WARNING / NEEDS CARE bell choices. The safe response opens the grove path without a timer or damage penalty for retrying.
6. Restore the grove's moth and slime using the existing warning/recovery combat rules, then awaken the Peace Flower.

The Peace Flower heals, saves the resting checkpoint, and completes River Song. Return over the bridge, by boat, and through the garden crossing. Harmony Stage / Island 3 remains visibly closed; Island 2 does not grant the Harmony Jewel, Shield, Creator access or completed-world train entitlement.

## Persistence and integration

`scripts/heart_melody/river_song.gd` owns the new geometry, panels, ferry and grove sequence. `heart_world.gd` provides shared input, camera, help, combat, sound, recovery and overworld activation through the enlarged world footprint.

The existing `heart_melody_island_one.json` atomic record now includes an additive `river` dictionary. Existing saves migrate to empty River progress without changing Island 1 receipts or its 119 XP. Valves, bulbs, boat arrival, chimes, warning response, grove restoration and Peace Flower are saved. Strict validation rejects duplicate/out-of-range IDs, broken prerequisites and skipped bridge order. Dependent stages use committed progress; failed writes retain session work and can be retried in Help. Existing JourneyState erase removes River progress with the same Heart record and backup files.

All geometry, interactions, attack markers, boat movement and recovery use the Heart transform, including the rotated/translated station-03 island. Native controller/touch bindings and assistance settings are inherited from Heart; physical device tests were not performed.

## Verification

`test_river_song.gd` passed twice: first with a rotated/translated standalone world, then with `ARTEA_RIVER_OVERWORLD=1` in the actual gallery/station-03 scene. Tests cover input-driven walking across both directions of the connection and chime bridge, valve UI feedback, locked progression, old-save migration, malformed progress, failed-write handling, boat confirmation/cancellation, both complete rides, safe/wrong bell choices, grove restoration, Peace Flower recovery and full save reload. Grove enemies are released with scripted recovery-phase damage calls; this is not a manual combat playthrough.

Ten regression suites passed: Heart gameplay, save safety, identity consent, station integration, JourneyState, Crown railway, minimap, gallery flow, embedded floating world and station jump traversal. Logs: `../work/river-gameplay-test.log`, `../work/river-overworld-test.log`, and `../work/river-test_*.log`.

Native visual captures were rendered and inspected: [overview](../work/river-overview.png), [organ and boat](../work/river-organ.png), [Bell Grove](../work/river-grove.png). The capture uses isolated fixture saves and does not alter normal player progress. Art and audio remain the project's procedural prototype style.

The standard non-Mono local Web export was regenerated with River Song. Export logs still report the existing three missing prototype source assets and native extension reload/copy errors while another Godot process holds the libraries. No script parse errors were found. A clean Web release is not certified. Browser inventory is empty, so real WebGL playback remains unverified. No deployment was performed; the Web server remains stopped. Current play windows must reload to receive changed scripts.
