# Heart Melody Island 1 — local implementation

> This is the initial implementation note. See [the 21 September audit handoff](HEART_MELODY_AUDIT_HANDOFF.md) for current implementation changes, tests, screenshots, performance and limitations. The audit supersedes the verification and polish status below.

Implemented from the 24-page Heart Melody Island 1 document. The Island 1-specific scope takes precedence over the later full-world roadmap. Islands 2/3, Rain Boat, boss, Harmony Jewel and new Shield rewards are not delivered here.

## Play

Open the existing Godot project and run `res://scenes/heart_melody/heart_melody_world.tscn` for direct local preview. In the campaign, earn the Star of Wisdom and use the Heart Melody World Gate on the Heart district's forecourt. The campaign router, legacy music trigger and GameManager music request now lead to this island. Return through the branch gate; saving must succeed before leaving.

WASD/arrows move, Q interacts, F strikes, Space jumps (never required), Escape closes panels. Controller left stick moves, A interacts/uses focused controls, X strikes and B jumps. Touch controls are available on touch-capable screens. Help offers separate combat and puzzle assistance, reduced motion, larger text and save retry.

## Implemented gameplay

- Continuous, collision-backed paired-lobe low-poly island, faceted trees/rocks, shallow decorative pool, readable paths, root edge protection and fall recovery.
- Existing fox controller/animations, existing Milo and Mother Guardian scenes. Optional replayable introduction.
- Three independent persistent planters. All six feelings and a neutral sound are valid, with preview, confirmation, cancellation, appearance changes and fixed musical roles. Timbres vary without making any feeling correct.
- Leaf → Sun → Droplet puzzle. Direct flower interaction and focused UI controls, audible/visible demonstrations, partial saving, replay, undo, reset and non-destructive mismatch feedback.
- One Echo Moth, then one Echo Moth plus one Pulse Slime. Fixed warning lanes/landing discs, recovery-only hurtboxes, real player sword hitbox, retreat suspension, modal pause and full-health recovery.
- Atomic temporary-file save/replace, last-valid backup, schema checks, session retention after write failure, explicit retry and one-time receipts. XP and progression are committed in the same record so there is no separate pending reward-delivery window.
- Garden blossom/Blight state and stable crossing derive from committed progress. Island 1 awards 39 enemy XP plus 80 quest XP once. A closed vine arch labels River Song as coming next.
- Comfort Lantern, Song Memory Bench and four optional explicit identity moments under heart_melody. No identity result, diagnostic inference or reward for reflection.
- New JourneyState records no longer grant the Harmony Jewel from feelings. Pre-version-2 saves retain qualifying legacy ownership; new reloads cannot infer a Jewel. Existing shared blocking behavior is preserved elsewhere, with Heart blocking unavailable to new players.
- Heart progress is erased by the real JourneyState clear operation. Tests redirect their save paths and user-data environment.

## Source layout

- `scripts/heart_melody/heart_catalog.gd`: authored choices, phrase and enemy definitions.
- `scripts/heart_melody/heart_progress.gd`: validated persistent progression and rewards.
- `scripts/heart_melody/heart_art.gd`: editable procedural low-poly meshes and shared materials.
- `scripts/heart_melody/heart_enemy.gd`: telegraph/attack/recovery behavior.
- `scripts/heart_melody/heart_world.gd`: scene composition, interactions, HUD and environment response.
- `scenes/heart_melody/heart_melody_world.tscn`: standalone on-demand world.

The editable art sources are procedural GDScript, not Blender files. The soundtrack is synthesized note feedback and a minimal repeating garden layer, not a fully produced music score. Restoration currently changes the committed world state immediately and animates flowers; a cinematic bridge-unfolding sequence and elaborate ambient foliage animation remain polish work.

## Verification

`test_heart_melody_island.gd` covers every feeling/neutral choice, cancelled previews, actual UI puzzle revision, partial/completed reload, corrupt-save backup recovery, failed writes, idempotent 119 XP, legacy/new Jewel migration, modal suspension, actual player sword strikes, death recovery, and continuous movement from arrival to overlook and back.

Passing focused/regression suites: JourneyState, JourneyCampaign, safe Heart Melody chooser, player combat, player direction/animations, Mind Spark World One story, audience mode, world minimap, story Crown railway, Art Castle gallery flow, embedded floating world, and train station jump traversal.

One existing `test_gallery_galaxy_transit.gd` assertion is obsolete: it expects story-order railway locks, while the unchanged baseline railway explicitly permits travel to all stations and separately tracks completed-world destinations. The baseline implementation was checked against HEAD; Heart Melody does not change that policy or grant train-completion flags.

Native rendering sample on Intel Core Ultra 7 155H / Intel Arc Graphics, GL compatibility, 960×540 window: 180 frames, median 5.916 ms, 95th percentile 9.363 ms, engine static memory 118.5 MiB. Island geometry including shared guides measured 29,233 triangles (player/companion counted separately). This is a short stationary native sample, not a Web or mobile benchmark.

## Local delivery and remaining release checks

The user explicitly selected local delivery; no Vercel deployment was performed.

The existing standard non-Mono Godot Web preset exports, but the complete project reports pre-existing missing sources in three orphan prototype scenes: `assets3D/worlds/low_poly_cloud.glb`, `assets3D/stylizedNature/Grass_Common_Short.gltf`, and `assets3D/stylizedNature/CommonTree_1.gltf`. No runtime references to those prototype scene files were found. They were not replaced or removed. The Web build is not certified release-ready, and a full WebGL2 campaign playthrough remains unverified. Editor shutdown also reports sandbox-restricted editor-settings writes; these are separate from the island runtime.

Keyboard/native automation and rendered views were verified. Physical controller, touch-device and complete manual accessibility playthroughs remain unverified. A continuous manual gameplay recording and Blender source pack are not included.

