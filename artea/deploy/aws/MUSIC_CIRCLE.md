# Heart Melody playable music circle

The five instruments sit inside the highlighted central pink ring on the
Heart Melody overworld platform, beyond the fountain. Their stages face the
open centre and leave room to walk between them.

Walk up and press **Q**. Click the instrument or its on-screen pads, or use
**A S D F G H J K**. Press **Esc** or choose **Leave instrument** to resume walking.

- Grand piano: the gallery's 88-key, sampled piano, with an added C-major
  keyboard octave. All keys remain clickable and support dragging.
- Rainbow xylophone: eight pitched bars.
- Hand drums: three distinct low, middle and high voices.
- Garden bells: five pitched bells.
- Guitar: four strummed chords, C, Am, F and G.

The four new instrument families use 20 short, original PCM sounds prepared
offline by `tools/audio/build_music_circle_notes.gd` (under 1 MB combined).
They load from the deferred game assets and are cached after first use.
Playing does not resize the instruments. The performance interface captures
world keyboard shortcuts while open, and restores movement and the follow
camera when closed, when walking out of range or when the scene is removed.

## Validation

Ten native checks passed: the new music-circle behavior test, gallery piano,
arrival garden, gallery flow, minimap, embedded world, station traversal,
Crown railway, Heart gate round trip and main-world integration.
The focused test checks real player proximity, mouse picking, keyboard input,
non-silent audio streams, every pad, camera exit and scene-removal recovery.
Evidence: `work/music-regressions.json` and `work/music-test-*.log`.
After import, the focused test passed again using the actual compressed
streams; non-silence is checked against their original PCM sources.

A native Compatibility-renderer capture verifies placement within the ring:
`artifacts/arrival_repairs/04_music_circle.png` (excluded from export).
The opt-in `node tools/web-smoke.js URL --music-circle` tour uses the full
gallery and real browser input to open, play and leave all five instruments.
Its controller is copied into that test browser's temporary filesystem; the
production export continues to exclude `tools/**`.

## Packaged build

Release `f6a68c1a9c86654d`, 20 October 2026. The complete maintained non-Mono
Web export passed its dependency, duplication and startup-budget checks.
All 20 prepared WAV files were included. All 102 packaged files passed
SHA-256 and hosted MIME, compression and isolation-header verification.

Local preview: <http://127.0.0.1:8885/>.
Package: `artifacts/aws/artea-aws-f6a68c1a9c86654d` and adjacent ZIP.
The fresh Chrome test successfully opened, played by keyboard and mouse, and
left all five instruments. The J shortcut test passed for xylophone and piano.
Screenshots of each playing interface were reviewed.
The complete browser tour finished with `RESULT: PLAYABLE` and zero fatal
script/resource errors. Guest login, hub and castle movement, story, Mind
Spark, Heart Melody activity and valley, Creator's Light and every return
passed in the same packaged build.
Browser evidence: `work/music-circle-browser-verified-run.log` and
`work/music-circle-browser-verified/`. The first run exposed a test-coordinate
conversion error under canvas stretching; the controller now converts to
display pixels before sending browser clicks.

Vercel CLI still reports `Logged out`; this build has not been published to
the existing production project. Its project and alias remain unchanged.
