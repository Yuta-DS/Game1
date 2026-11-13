# Web frame pacing — 21 October 2026

Branch: `more-improvements-on-melody-world-and-some-other-fixes`.
Packaged release: `0aac2c5b688cc35a`.

## Changes

- Prepare actual castle and connected-world camera views beneath the opaque
  loader. This exercises real geometry, lighting and particle configurations
  before the player turns the camera. Restore the exact camera and streaming
  state afterward; never move the player into interaction zones during warmup.
- Convert Milo's verified single-bone pieces to rigid bone attachments on Web
  and combine compatible opaque surfaces. Flexible and animated facial parts
  retain their existing animation paths and named nodes.
- Combine each flower's five petals into one surface without changing its
  geometry, coloring, interaction anchor or scale.
- Stream long Web soundtracks, including the drawing tool's autoplay track,
  avoiding a roughly 700 MB decoded buffer for that 31-minute recording.
- Add opt-in browser frame telemetry and reversible diagnostic samples. These
  tools are injected into the isolated test browser and excluded from exports.

## Tradeoffs

Preparing more views increases the first castle loading wait in exchange for
fewer first-use pauses during exploration. Pack prefetch remains prioritized
and runs in the background. Extra downloaded bytes alone cannot remove shader
compilation or a sustained rendering bottleneck.

Paired local WebGL measurements reduced Hub frame time from about 82 ms to
48 ms after Milo optimization. The real-view trial reduced the first castle
camera-turn maximum from 3,576 ms to 48 ms. These measurements use the same
machine's Intel Arc WebGL renderer at 1280×800; they are not a universal frame
rate guarantee. The world still has substantial rendering cost, and a cold
teleport to the music court produced a residual 293 ms frame in the trial.

The final packaged build measured Hub median **44.1 ms**, p95 **51.0 ms**;
castle idle median **16.7 ms**, p95 **17.8 ms**; and the first castle camera
turn median **18.1 ms**, p95 **30.5 ms**, maximum **36.6 ms**. Music-court orbit
median was **16.9 ms**, p95 **36.7 ms**, maximum **60.9 ms**. The cold QA
teleport still measured a **293 ms** frame. First castle entry took **78.5 s**,
including preparation of distant views, versus **87.6 s** in the preceding
synthetic-warmup build; the older arrival-only build traded faster loading for
first-use pauses. These samples do not establish smoothness on every device.

## Validation

The complete 23-test native regression run passed, covering loading, streamed
audio, rigid geometry equivalence, Milo's movement/speech/follow/rescue,
flowers, playable instruments, maze, guidance, gates, cameras, railway, gallery
and minimap. After the real-view change, eight focused/baseline tests also
passed, including exact camera/player and streaming restoration.

The maintained non-Mono Web export passed pack checks and its startup budget.
The 30.2 MB core pack is not the total download required to start playing.
The complete packaged site contains 102 files, about 403 MB, and passed local
SHA-256 and hosted MIME/isolation-header verification.

The final fresh Chrome tour completed in 479 seconds with `RESULT: PLAYABLE`.
It verified movement, story, castle, Mind Spark, Heart Melody, its valley,
Creator's Light, and every Hub return. Instrument keyboard/mouse sound, piano
seat and Tab/Esc controls, solid maze walls and solution, fountain music, and
recorded Milo guidance all passed. Piano, maze and Milo screenshots were
visually inspected. No script/parse/resource errors appeared in the final log.
The 1,853.7-second drawing soundtrack remained in streaming mode with playback
advancing from 10.36 to 16.63 seconds. Cold transfer to the Hub was 171,743,888
bytes (about 164 MiB); later prefetched world entries needed no asset downloads.

Local playable preview: <http://127.0.0.1:8889/>.
Package: `artea/artifacts/aws/artea-aws-0aac2c5b688cc35a` and adjacent ZIP.
Final browser evidence: `work/frame-smooth-browser-run.log` and
`work/frame-smooth-browser/`, including `frame-profiles.json`.

Evidence is retained in `work/frame-final-regressions-run.log`,
`work/frame-view-final-tests.log`, `work/main-sync-export.log`,
`work/frame-smooth-verify.log` and the browser profiling folders under `work/`.

Vercel login and deployment are skipped at the user's explicit request. AWS
infrastructure has not been provisioned by this performance pass.
