# Ocean ambience and warning crossing — 22 October 2026

Two gameplay changes on `final-fixes-of-heart-melody-and-other-parts-of-the-game`:

- Removed the obsolete pink warning barrier and its collision. Progress gates,
  their requirements and existing saves are unchanged.
- Reused the existing surf recording as one looping positional source. It
  tracks the closest coastline point from the existing baked Hub terrain,
  refreshing the target four times per second and smoothing source movement.
  The recording keeps playing through approaches and retreats. Gain is -8 dB,
  capped at -6 dB nearby, with 20m unit distance and 90m maximum distance.
  It uses SFX volume and ends naturally when the Hub scene is unloaded.

The Hub uses lowercase `player`; ocean tracking prefers that active player
over uppercase `Player` nodes used by other scenes. The regression includes
both groups to prevent following an unrelated character.

Seven distinct native checks passed: ocean shore audio, complete Melody
chapter, journey presentation, sea/sky, Web environment compatibility, Melody
gate round trip and tree-bridge spatial audio. They cover looping playback,
coastal coverage, distance limits and physical passage through the removed
barrier before the Warning Bell lesson is completed.

Maintained non-Mono Web export completed. The editor's Dialogue Manager update
checker emitted a shutdown callback warning; no game resource failed export.
Final package `8f1e65f2d8ceec4c` passed all 94 local/hosted file hash, MIME and
isolation-header checks. Browser evidence is in `work/ocean-gate-browser-final/`
and `work/ocean-gate-browser-final-run.log` (local QA artifacts).

Real Chrome WebGL2 checks confirmed continuing surf playback, a 9.1m coastal
listener distance and a 130.8m inland distance (beyond the 90m audible range).
The real capsule crosses the opened chime gate without the pink barrier;
`journey-warning-crossing.png` was inspected visually.
The full browser tour returned `RESULT: PLAYABLE`, including startup, movement,
garden progression, other worlds and returns to the Hub, with no fatal game
script, resource or QA errors.

Local full game: http://127.0.0.1:8911/ — open the root to load this release.
No push, PR update, AWS deployment or Vercel deployment was performed.
Audio playback/proximity was verified automatically, not assessed by ear.
