# Heart Melody Island 1 — audited local handoff

## Current update: seamless station 03 integration — 22 September 2026

The user requested that players **walk straight into Heart Melody on the same overworld**. The playable Island 1 is now physically attached beside Crown Line station 03. Disembark, descend the existing station ramp, then follow the marked garden slope and entrance bridge. No portal, loading screen, duplicate player or scene change is used on this route. The Star of Wisdom opens the physical path; travel does not award a Harmony Jewel or Creator access.

`scripts/heart_melody/heart_overworld_connection.gd` supplies a 12 m wide continuous walking route, a level turning landing, entrance signs, flowers and the prerequisite barrier. The island is raised clear of the existing kingdom shelves, at railway-local `(1400, 45, 7470)`, rotated to meet its station approach. The arrival court's old blocking instrument ring is replaced by roadside blossoms. Quiet Meadow is marked on both maps.

The island shares the existing overworld player. Entry activates its camera, movement tuning, HUD and soundscape; departure restores the prior camera, speed, blocking setting and companion/story UI. The train stays in the same scene. Seed, phrase, wave and restoration progress use the established Heart save. Local/global position handling was corrected for rotated geometry, interaction rays, recovery, enemy telegraphs and released creatures. The old Castle district gateway and standalone preview remain available as alternate routes.

The new `test_heart_station_integration.gd` passes against the real gallery scene: actual input-driven walking from the station ramp through the garden route and back without jumping, shared-player/scene identity, prerequisite state, planter interaction, save, transformed encounter activation/telegraphs, modal combat pause, recovery and restored overworld controls/HUD. Nine additional suites passed: Heart gameplay, save safety, identity consent, JourneyCampaign, Crown railway, minimap, gallery flow, embedded floating world and station jump traversal. Logs: `../work/heart-walk-test-output.log` and `../work/station-test_*.log`.

Native GL screenshots were captured and inspected: [station overview](../work/heart-station-overview.png) and [island arrival](../work/heart-station-arrival.png). The retained capture script is `scripts/capture_heart_station.gd`. These captures are visual checks, not a full manual combat/controller playthrough.

The standard non-Mono maintained exporter regenerated `builds/web` with 109 validated pack parts (907,421,328 bytes), including the embedded connection script. No script parse errors occurred. The same three missing prototype source assets listed below still produce export errors; this is not a clean Web release certification. Export log: `../work/heart-station-web-export.log`. No deployment or browser playback verification was performed, and the local Web server remains stopped.

21 September 2026. The existing implementation was audited against the complete 24-page `Heart Melody Island 1.pdf` above the S2603 directory. Pages 1–14 define this deliverable; the later three-island roadmap remains reserved. Existing working-tree changes were preserved. **No deployment was performed.**

## Reach Heart from the start screen

1. Open `artea/project.godot` in standard Godot 4.7.1. Run the configured main scene, or open `res://scenes/start_screen.tscn` and press F6.
2. Select **Offline Guest** and wait for the hub to load.
3. Walk to the Castle door plaza and enter **Crown of Life Adventure • Begin Journey**. This opens the Art Castle Galaxy; the existing Castle/gallery entrance also leads there.
4. A new journey must first complete Mind Spark and earn the **Star of Wisdom**. Heart retains that prerequisite.
5. Follow the Castle Galaxy route to the **Heart Melody** district. At its forecourt World Gate, press **Q** at **HEART MELODY — QUIET MEADOW (Star of Wisdom required)**.
6. Plant three seeds, arrange the flower phrase, then deliberately enter the Blight clearing. Return through the arrival branch gate at any time; retry a failed save before leaving.

The actual World Gate → Heart → Castle loading route was tested. The complete start-screen/hub walking route was not manually replayed in this audit.

**Direct scene preview:** open `res://scenes/heart_melody/heart_melody_world.tscn` and press F6. This bypasses the entry prerequisite but uses the normal Heart save. It does not award campaign treasures.

## Controls

WASD/arrows move, Q interacts, F strikes, Space jumps (never required), Escape closes panels. Tab/Shift+Tab and directional UI navigation select controls; Enter/Space activates them. Controller bindings provide left-stick movement, A interaction/UI acceptance, X strike, B jump/cancel. Touch screens receive spaced movement/strike buttons and larger modal controls. Long panels scroll and follow keyboard/controller focus.

Help offers separate combat assistance and slower puzzle demonstrations, reduced motion, larger text and save retry. Preferences persist in `user://heart_melody_settings.cfg`. Combat assistance extends warnings and halves damage without reducing rewards. Puzzle input is untimed. Text, symbols and shapes accompany musical clues and combat warnings. Modal panels suspend combat.

## Implemented scope and audit changes

The playable loop contains Quiet Meadow arrival/return, optional shared Milo/Guardian guidance, three persistent seed planters, three flower drums, the editable Leaf → Sun → Droplet phrase, two introductory waves, healing, hints, four optional identity moments, restoration and a closed **River Song — coming next** overlook.

Completion requires three seeds, solved music and both cleared waves. Rewards are **39 enemy XP + 80 quest XP = 119 once**. No Island 2/3 gameplay, Rain Boat, organ/bell puzzles, boss, Harmony Jewel, Harmony Shield, Creator access or completed-world train entitlement is awarded.

This audit improved:

- Strict save validation across types, prerequisites, tasks, checkpoints, waves, XP and receipts; visible backup-recovery guidance and retry.
- A committed snapshot separate from session changes. Failed prerequisite saves cannot open the next stage; failed completion cannot open the crossing. A later failed cosmetic save cannot close an earned crossing.
- Preview cancellation restores the prior flower colour. Planters have reusable low-sided bowl geometry, mounted distinct shapes, replay and fixed musical roles. The dirt loop now avoids the centre bowl and gives it a clear operating approach.
- Phrase feedback preserves work; the objective no longer gives away the answer. The panel and camera keep all three flowers visible together. Cancelling demonstrations prevents later text from leaking into another panel.
- Damage constrained to the advertised moth lane and slime polygon; explicit recovery cues; restored living moth/slime forms; actual zero-health recovery and an under-island recovery volume.
- A short skippable restoration that moves the crossing and attached collision together, replays music and opens plants. Independent synthesized ambience/garden/rhythm layers change volume without restarting each other.
- Persistent accessibility preferences, larger touch targets, scalable modal text, scroll/focus support.
- Single guide-input ownership. Heart opts out of the additional global following Milo, whose independent Q polling otherwise competes with the authored guides. Existing companion behavior in other worlds is unchanged.
- Consent copy explicitly explains local storage. All four skip/private paths write nothing. Clear journey removes Heart evidence while preserving Mind Spark evidence and established result state.

## Saves and legacy behavior

Windows default: `%APPDATA%\Godot\app_userdata\Artea\heart_melody_island_one.json`.

**Schema 1 / campaign_version 2** stores planters, partial phrase, solved flag, ordered cleared waves, completed task IDs, checkpoint, completion, XP and reward receipts. Writes flush `.tmp` then atomically replace the primary. `.bak` retains the previous valid record. Invalid primaries recover from a valid backup with visible retry guidance. If neither is valid, the game explains recovery and starts fresh; damaged files remain until a new save is made.

Session progress remains after a failed write. Retry commits the whole record. XP and receipts share that atomic record, eliminating a separate external reward-delivery window. The crossing derives from committed completion, never a presentation flag.

`JourneyState` no longer grants the Jewel from new emotion recording or version-2 emotion reload. Pre-version-2 qualifying emotional evidence and explicit legacy ownership preserve established access, without fabricating new Heart tasks. Legacy blocking behavior remains intact. Clear journey removes Heart primary/backup/temp saves and Heart identity evidence; accessibility preferences remain preferences.

Tests redirect APPDATA into isolated `work/` directories, leaving normal player saves alone.

## Source and integration points

| Files | Responsibility |
|---|---|
| `scripts/heart_melody/heart_catalog.gd` | Choices, phrase, tasks and enemy tuning |
| `heart_progress.gd` | Validation, atomic storage, receipts and committed snapshot |
| `heart_art.gd` | Editable procedural meshes, reusable planters, symbols/colliders |
| `heart_enemy.gd` | Warning, attack, recovery and shell release |
| `heart_soundscape.gd` | Synchronized synthesized sound layers |
| `heart_world.gd` | Scene composition, interaction owner, HUD, restoration/recovery |
| `scenes/heart_melody/heart_melody_world.tscn` | Standalone/on-demand scene |
| `scripts/JourneyState.gd`, `player_identity_tracker.gd` | Migration, explicit evidence, journey erase |
| `scripts/MiloCompanionManager.gd` | Authored-guide ownership opt-out |
| `scripts/art_castle_floating_world.gd`, `mind_spark/mind_spark_world_gate.gd` | Heart destination gate |
| `scripts/journey_campaign.gd`, `GameManager.gd`, `teleport_music.gd` | Campaign/legacy entry routing |
| `player_3d.gd` | Existing Heart-aware blocking switch |

The initial gate/routing, player and migration edits were present at audit start and retained. New focused suites are `test_heart_progress_safety.gd`, `test_heart_identity_consent.gd`, `test_heart_gate_round_trip.gd`; existing `test_heart_melody_island.gd` and `capture_heart_melody.gd` were expanded.

## Verification

Four focused suites pass: Island gameplay, save safety, explicit identity consent/erase, and actual World Gate → Heart → Castle round trip. They cover walking to all planter aprons and the phrase circle, muted phrase revision, actual first-wave sword hits, retreat/modal suspension, actual zero-health recovery, crossing/return movement, malformed saves, failed writes, backup recovery, idempotent rewards and new/legacy Jewel safeguards. Wave two is completed through scripted hurtbox calls, not a manual combat playthrough.

Sixteen relevant regression suites passed assertions: JourneyState, JourneyCampaign, safe Heart chooser, player combat, direction/animations, control recovery, Mind Spark World One story, Mind Spark shared state, audience mode, world minimap, Crown railway, Castle gallery flow, embedded floating world, train station jump traversal, completed-world train policy and Milo companion following. Changed shared-state suites were rerun after consent/erase changes. Logs: `../work/current-test_*.log`, `../work/final-test_*.log`, `../work/revised-test.log`, `../work/recording.log`.

Assertions and runtime errors were inspected rather than relying on exit codes. Existing warnings include the music-resource UID fallback, sandbox certificate-store/directory access and shutdown object/resource leaks. The incoming handoff reported an obsolete railway-lock assertion in `test_gallery_galaxy_transit.gd`; this audit did not rerun it and does not count it as passing.

Evidence:

- [Arrival](../work/heart-arrival.png), [planter](../work/heart-planter.png), [phrase](../work/heart-phrase.png), [overlook](../work/heart-overlook.png).
- [Automated native gameplay recording](../work/heart-playtest.avi): approximately 44 seconds, with fixture repositioning and scripted wave-two release. This is not a continuous manual playthrough.
- [Measured performance](../work/heart-performance.json): 180 stationary native frames, Intel Core Ultra 7 155H / Intel Arc Graphics, GL compatibility, 960×540. Final sample: **1.884 ms median, 4.175 ms p95, 117.33 MiB engine static memory**. These are not process/GPU memory measurements or a moving/combat stress profile.

Geometry: **12,467 environment/prop triangles**, with **17,760 shared-guide triangles** and **5,384 player triangles** measured separately. Largest tree: **150**; planter: **570**; drum flower: **234**, plus its small base/symbol meshes already counted in the environment. This remains procedural production-prototype art, not a Blender source pack.

## Local Web build and remaining work

The maintained `scripts/export_web.sh` produced a standard non-Mono local build in `builds/web`, with the custom loader and 109 split pack files. Its logs still contain three pre-existing missing-source errors: `assets3D/worlds/low_poly_cloud.glb`, `assets3D/stylizedNature/Grass_Common_Short.gltf`, and `assets3D/stylizedNature/CommonTree_1.gltf`. Those sources were not replaced or removed. Generated artifacts do not constitute a clean release certification.

The final export also reported native `nobodywho` and `terrain_3d` temporary-library copy/load errors while another Godot editor was open on this project. That editor was left untouched. The log is `../work/current-web-export.log`; native extension reload and the missing sources remain export blockers to resolve before certification. The generated pack manifest reports 907,412,036 bytes. No script parse error was found in that export log.

Real WebGL2 verification is blocked: computer-use reported no connected browsers, and the in-app browser returned **Browser is not available: iab**. No Web readiness or browser gameplay is claimed. No hosting/deployment action was performed.

Remaining production work: physical controller/touch-device testing, complete manual accessibility and combat playthroughs, representative moving/combat performance, vegetation batching/animation polish, produced audio and finished art/animation. The broader campaign journal still describes the wider journey; Heart's local HUD is the Island 1 objective source. Islands 2/3 and full-world rewards are intentionally outside this delivery.

### Local Web launcher correction
The local /heart.html adapter now sets a one-shot preview flag; start_screen.gd opens Heart with change_scene_to_file after normal engine startup in an offline guest session. No engine scene-path argument is supplied (release templates reject it). The loader fetches an unsplit side WASM directly, retaining split fallback. tools/test_heart_web_loader.cjs passes all three checks; test_heart_web_startup.gd confirms normal main-menu startup and the offline Heart transition. HTTP adapter, updated loader and all 109 pack parts were checked. Rebuilt locally; no deployment. Actual browser playback after this correction remains unverified because browser inspection was blocked. Export retains the previously documented three missing prototype assets; native startup also reports the existing root certificate-store error.

### Resumed verification — 22 September 2026

Restarted the local preview at `http://127.0.0.1:8766/heart.html` using `python tools/serve_heart_web.py --port 8766`. Verified HTTP 200, the one-shot Heart preview flag and `Cross-Origin-Embedder-Policy: require-corp`. The server is a running terminal process; restart with that command if the session ends.

Re-ran all three JavaScript loader checks, the native startup/preview transition, Island 1 gameplay and save-safety suites successfully with isolated APPDATA directories under `work/resume-heart-*`. Logs are `../work/resume-heart-startup-output.log`, `../work/resume-heart-gameplay-output.log`, and `../work/resume-heart-safety-output.log`. Gameplay still reports shutdown object/resource leaks; no assertion or script parse failures were found.

Browser inventory is empty; both Edge and in-app browser creation explicitly returned unavailable. Actual WebGL playback remains blocked. The three missing prototype source assets remain unresolved. This resumption changed no gameplay and performed no new export or deployment; it does not certify Web release readiness.
