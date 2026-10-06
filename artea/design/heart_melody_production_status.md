# Heart Melody playable chapter status

Updated 6 October 2026. Vercel deployment is intentionally skipped at the user's request.

## Play locally

Run `Play Heart Melody.cmd` from the repository root, then open
http://127.0.0.1:8772/heart.html. Keep the server running while playing.
The direct entry uses supported release-template user arguments and transitions
through the normal start scene. `/index.html` retains the regular game entry.
The first download is approximately 848 MiB.

## Implemented

- Connected chapter extension with six zones, ten required instrument tasks,
  fruit groves, crafting/storage UI, restoration, song assembly, three persistent
  Beat Anchors, final fruit/conducting sequence, Jewel and Shield reward handling.
- Six protected story fruit families, authored supplies, separate crafting fruit,
  stacking/overflow, recipes, regrowth and first-clear reward receipts.
- Versioned chapter save migration preserving the original garden IDs and progress,
  temporary-write/rename with backup, validation and corrupt-primary recovery.
- Shared challenge, quest, encounter, environment, audio and HUD components, with
  the original garden/river interfaces retained for compatibility.
- Final island gate returns to the actual Art Castle and saves partial progress.
- Small flower, fruit and decorative floating names removed. Major instruments,
  zones and gates use bordered sage/ivory banners without collision.
- Camera collision volume checks, close-camera avatar hiding, avatar restoration
  when leaving the embedded world, and flush traversal across the chapter extension.
- Browser drag-to-orbit and readable text labels on touch movement buttons.
- Existing optional/private identity rules retained; fruit and assistance do not
  contribute identity evidence or alter rewards.

## Verification

Standard non-Mono Godot 4.7.1:

- Complete chapter regression passes: fruit, seed/drum interactions, all later
  task proofs, persistent anchors, finale rewards, reload and replay receipts.
- Final gate/signage regression passes: reachable gate with the player capsule,
  transition to the real Castle, partial-save preservation and no reward changes.
- 3D environment regression passes: physical traversal, 72-angle camera sweeps,
  wall retraction/release, roof clearance and fall recovery.
- Chapter migration, progress safety, musical garden, river song, identity consent,
  safe Heart Melody, gate round-trip and station integration regressions pass.
- Maintained Web export succeeds; missing model sources were repaired. The exporter
  now rejects error diagnostics even if Godot returns a zero exit code.
- Real Chromium WebGL2 smoke check reaches `HEART CHAPTER READY`, closes the intro,
  moves the player and captures the changed scene without script/scene errors.
- Zone, instrument, fruit and restored-world native captures are in
  `work/heart-production-captures`; browser captures/logs are in
  `work/heart-browser-final3` (and subsequent final checks).

## Remaining production limitations

This is a playable chapter implementation, not a verified completion of every
item in the original 2-4 hour production brief. Full-duration pacing and the
complete physical controller/touch and 30/60/120 FPS acceptance matrix have not
been verified. Some later instrument mechanics use the shared sequence/timing
interface rather than all bespoke physical interactions described in the brief.
Crafting materials currently use chapter inventory/storage rather than the global
inventory adapter. Full four-track mixing and the complete accessibility/remapping
matrix remain unfinished. Further art, sensory-setting and performance polish is
needed before calling this a finished production release.

The local browser reports existing asset UID fallback warnings and an offline
Firebase `.env` notice, but no chapter script or scene-loading errors. Headless
shutdown reports existing ObjectDB leak warnings. No public deployment was made.
