# Loading and smoothness rollback

Requested after reports of audio interruptions and stalled scene transitions.
This removes the added performance paths; it does not claim those paths were
the sole cause of every reported interruption.

## Restored behavior

- Loader, shader warmup, MusicManager, drawing music playback, Milo skin, and
  castle construction return to their versions at `d3031dcb`, before the loading
  optimization pass. The later camera sweep and Web warmup timeout are removed.
- The Hub and common runtime resources ship in the initial Core download again.
  The added deferred `hub` and `shared_runtime` packs are removed. Main's older
  area packs and background prefetch remain as they were before this pass.
- Long audio is no longer forced through the streaming playback policy.
- Castle mesh caching/baking, rigid Milo conversion, merged flower petals and
  static garden scenery batching are removed. Original meshes and animation
  paths render the same authored content.

## Preserved

Melody islands and progression fixes, maze and its fountain, piano seating and
playable instruments, Milo voice/transcript/guidance, scenery, menus, gates,
celebrations, healing crossings, and castle return fixes remain. The recent
request for fountain-only garden music, quieter nearby gain and distance fading
also remains. AWS accounts, security, deployment tooling and existing assets
are preserved.

Export correctness fixes remain: complete asset references, safe generated
presets, Godot property typing and particle export compatibility. Old generated
castle assets are explicitly excluded. Historical performance documents describe
superseded builds and are not the current configuration.

## Validation

All 17 focused/native regressions passed: Milo character and natural animation;
flower rendering and play feedback; maze; complete ten-step chapter; journey
presentation and Milo guidance; castle gallery flow; minimap; embedded floating
world; station traversal; story railway; arrival fountain; castle round trip;
ground entry route; and tree-bridge environmental audio. Logs:
`work/performance-rollback-melody-tests.log`,
`work/performance-rollback-baseline-tests.log`, and
`work/performance-rollback-audio-tests.log`.

Pack analysis confirms the Hub scene is in Core, no deferred Hub/runtime packs,
and no missing-reference errors (`work/performance-rollback-pack-graph.json`).
The initial download can be larger again, as it was before the optimization.
Vercel login/deployment remains skipped at the user's explicit request.

## Exported browser result

Release `95c47ff64dc1f09d`, local preview `http://127.0.0.1:8908/`.
The non-Mono export completed and all 95 packaged/hosted files passed hash,
MIME and isolation-header checks (`work/performance-rollback-hosting-verify.log`).
The complete browser tour returned `RESULT: PLAYABLE` with zero fatal resource
errors (`work/performance-rollback-browser-run.log`). All tested worlds returned
to the Hub. The instrument/bench/maze/fountain checks, Milo transcript lifecycle,
and real flower-answer/automatic Blight waves/gate checks passed. Maze and garden
screenshots were retained in `work/performance-rollback-browser/`.

The rollback does not establish that every audible interruption or frame hitch
is fixed. The test still measured low frame rates in detailed areas: valley idle
median 67.8 ms, orbit 71.6 ms; Hub standing median 116.6 ms in this run. These
figures describe the observed browser run, not a controlled attribution to one
change. No optimizations were reintroduced to hide or change these results.
Audio checks establish active fountain/instrument playback, not a subjective
listening guarantee. Core is 249.6 MB again; total packaged files are 391,989,755
bytes, so the initial download is larger than the superseded deferred build.
