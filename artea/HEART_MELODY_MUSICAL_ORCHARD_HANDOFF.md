# Heart Melody Musical Orchard — local handoff

27 September 2026. This update supersedes the Star of Wisdom entry requirement in older Heart Melody notes. It is intentionally local; nothing was deployed or published.

## Enter and play

Enter through the normal login, register, or **Offline Guest** flow, then use the Castle Heart gate or station-03 garden walk. Both routes are open from a new journey without completing Mind Spark, changing treasure, or altering other-world progress. The branch gate safely returns to the Castle. The start screen no longer includes a direct Heart Melody button.

Move with WASD/arrows or controller stick. Use Q / controller A at the nearest prompt; focused panels support Tab/arrows, Enter/A, Escape/B, and large touch controls. F / controller X is the independent basic strike for the optional legacy Blight clearing. Jump is never required.

All Heart Melody land areas are now joined by broad, railed walking routes. The moss path forms a complete loop through the orchard and instrument clearings; the garden root bridge is present before restoration; a flowering root walk connects the Rain Boat banks; and the Bell Grove decks remain safe terrain while their chimes awaken. Exploring ahead never completes or skips an activity—progress validation remains tied to the authored musical actions.

1. In the Musical Orchard, interact with Bell Apple, Marimba Pear, Shaker Berry, and Bass Melon. Preview, then harvest each into the persistent basket.
2. Play the four broad Flower Drums. Their guided call is **LEAF — SUN — DROPLET**. Shaker Berry or another fruit can change a holder's timbre.
3. Use the five-bar Fruit Marimba. The guided pitch phrase is **1 — 3 — 5**; holder fruit never changes correctness.
4. Pluck the five Vine Harp strings freely, replay **1 — 3 — 5**, configure fruit, or record a short phrase.
5. At the five Hanging Bells, fill the visible gap in **1 — 2 — ? — 4 — 5** with bell 3.
6. At the Garden Ensemble, toggle rhythm, melody, harmony, and accent layers, preview, then perform. The island's local celebration opens; no Harmony Jewel or future world is completed.

Every guided activity is untimed. Sound is paired with written names, slot numbers, shapes, and visible object response. Help exposes larger text, reduced motion, slower demonstrations, combat assistance, and save retry. The older Feeling Seed planters remain replayable and neutral **Sound** remains a valid option; feeling choices do not affect success or rewards.

## Persistence

`heart_melody_island_one.json` is now schema 2. Schema-1 saves migrate additively: original planters, phrase, waves, XP receipts, restoration, and River Song data remain intact, while the new activities start available and incomplete. The existing atomic temp/replace and last-valid backup flow now also owns fruit, basket, holder configurations, partial phrases, activities, bounded symbolic events, the saved arrangement, layer toggles, and local celebration/checkpoint.

Fruit remains present after harvest and configurations reference the basket rather than consuming fruit. Failed writes keep session state and Help offers retry. Existing clear-journey cleanup still removes the shared Heart primary, backup, and temporary files.

## Verification

Godot 4.7.1 native focused/regression passes: `test_heart_musical_garden.gd`, `test_heart_direct_start.gd`, `test_heart_progress_safety.gd`, `test_heart_melody_island.gd`, `test_journey_campaign.gd`, `test_heart_gate_round_trip.gd`, `test_heart_station_integration.gd`, `test_milo_activity_routing.gd`, `test_heart_open_connection.gd`, and `test_river_song.gd`.

Native GL Compatibility capture, Intel Core Ultra 7 155H / Intel Arc, 1280×720, 180 stationary frames: **3.311 ms median, 5.967 ms p95, 125.28 MiB engine static memory, 45,354 scene triangles, 5,226 musical-garden triangles, 1,020 draw calls**. This is not a moving/combat stress profile or GPU/process-memory measurement.

The non-Mono Web preset exported locally to `builds/web`; the new musical scripts are present in the pack. The 907,463,972-byte PCK was regenerated as 109 parts and the side WASM as 6 parts. Local HTTP checks returned 200 for the entry page, manifest, and final pack part. Real WebGL/browser gameplay was not verified because no browser surface was available. Export still reports the three pre-existing missing prototype sources (`low_poly_cloud.glb`, `Grass_Common_Short.gltf`, `CommonTree_1.gltf`) plus sandbox/editor-settings write warnings, so Web readiness is not certified.

## Screenshots

- [Arrival](../work/heart-musical-arrival.png)
- [Musical orchard](../work/heart-musical-orchard.png)
- [Instrument gardens](../work/heart-musical-instruments.png)
- [Completed ensemble garden](../work/heart-musical-ensemble.png)
- [Connected river root walk](../work/heart-connected-root-walk.png)
- [Connected Bell Grove walk](../work/heart-connected-bell-walk.png)

## Remaining limitations

The island uses editable procedural prototype art and synthesized tones rather than final authored models/audio. The ensemble terrace competes visually with some retained legacy canopy from a few angles. Physical controller and touch-device testing, moving/combat performance profiling, and real WebGL playback remain unverified. Optional rhythm mode is forgiving and adjustable but intentionally compact rather than a full timing-score system.
