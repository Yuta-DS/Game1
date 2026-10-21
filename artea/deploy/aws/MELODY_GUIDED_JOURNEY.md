# Melody guided journey — 21 October 2026

Branch: `more-improvements-on-melody-world-and-some-other-fixes`.

## Player-facing changes

- Maze fountain music is 8 dB louder, with stronger nearby attenuation gain
  and its existing 120-metre hearing limit. A second, smaller singing fountain
  sits beside the meadow rest area and restores health/focus when interacted
  with. Both use the looping fountain theme.
- Milo's transcript uses an opaque navy card, cyan border, speaker heading and
  short pages. Pages follow recorded playback; the actual finished signal
  hides the card immediately. Leaving the area also stops it cleanly.
- Ten new milestone recordings use the existing opening-voice reference.
  Only committed completions queue congratulations and the next task. New
  island instructions wait until the player reaches that area; optional
  free-play narration cannot jump ahead of an unplayed island lesson.
- Entry and return introductions are compact. Current-task journal cards
  reveal fruit routes as they become relevant; completion history is separate.
  Harvesting, seed planting, garden instruments and ensemble menus show a
  three-step visual flow. Menus fit their content, scroll when necessary, and
  place keyboard/controller focus on an activity control. Sequence instruments
  also accept number keys, Backspace to undo and Enter to check.
- Five gates open on approach after saved requirements: Feeling Garden (2
  tasks), Rain Boat Call Bells (5), Bridge Chimes (6), Warning Bell Path (7),
  and Fruit Orchestra (10). Each gate celebrates once per scene visit with a
  brief gold burst and musical note. Reduced-motion mode omits the burst.
  Required Harmony Figs remain reachable before the sanctuary gate.
- Six healing pools/mist zones sit below the crossing routes. Walking through
  the mist restores 12 health and 8 focus per second, without requiring a jump
  into the void. Richer rounded tree canopies, branches, planted borders and
  rocks echo World One's detail using a distinct pastel garden palette.
  Added static scenery is batched; celebrations use one short particle emitter
  with no permanent lights or per-particle scene nodes.

## Validation

Fourteen distinct native checks passed: journey presentation, complete chapter,
arrival garden, fruit bucket, Milo guidance, return gate, musical garden, maze,
final gate/signage, gallery flow, minimap, embedded world, station traversal and
Crown railway. The new journey test checks short transcript pages and actual
voice dismissal, staged journal contents, default keyboard/controller focus,
real gate collision before/after saved restoration, healing on the crossing,
one celebration per opening and arrival-based spoken instructions.

Native evidence: `work/melody-final-focused.log`,
`work/melody-menu-focus-test.log`, `work/melody-presentation-tests.log`,
`work/melody-journey-regressions.log` and `work/melody-journey-baselines.log`.
The earlier presentation log includes the initial failing test; the final
focused and baseline runs supersede it.

The final menu tests (`work/melody-menu-final-tests.log`) additionally passed
screen-margin and delayed-scroll checks. Rendered inspection caught and fixed
retained scroll/focus hiding titles and diagrams; menus now start at the top,
then follow keyboard/controller focus when the player navigates.

## Packaged Web verification

Release: `d53e6e00dd2fa93b`.
Local play: <http://127.0.0.1:8905/>.
Package: `artea/artifacts/aws/artea-aws-d53e6e00dd2fa93b` and adjacent ZIP.
All 102 files (403,635,621 bytes) passed SHA-256 and hosted MIME/isolation-header
checks in `work/melody-guided-final-verify.log`. The maintained complete
non-Mono Web export passed pack checks with no script/parse errors.

The final fresh Chrome tour completed in 548.9 seconds with `RESULT: PLAYABLE`.
It exercised login, movement, story, castle, all five music-circle instruments,
the seated piano and keyboard view, solid maze paths, fountain music, Milo's
directions, staged garden presentation, Mind Spark, Heart Melody, the valley,
Creator's Light and every Hub return. The transcript advanced during the
recording and disappeared on completion. After layout settled, entry, harvest,
journal and instrument menus all retained their headings and diagrams in view.
The new meadow fountain played and the River Song gate opened with its burst.
Final menu, transcript, gate and fountain screenshots were inspected.

Evidence: `work/melody-guided-verified-browser-run.log`,
`work/melody-guided-verified-browser/console.log`, live console logging,
`frame-profiles.json` and screenshots in that folder. No script/parse/resource
errors appeared in the successful final tour. Automation-only pointer-lock
permission exceptions remain in the log.

One earlier fast-reload browser tour stopped responding on standalone valley
entry after several world reloads. Its renderer held about 2.8 GB; no cause was
established. It was stopped and logged in
`work/melody-guided-final-browser-run.log`. The final diagnostic tour did not
repeat it: valley entry took 5.0 seconds, with median 16.7 ms frames and an orbit
maximum of 26.5 ms. This pass does not establish that the intermittent stall is
fixed or that every device will sustain 60 FPS. The smoke runner now writes
live console logs and times out unanswered browser commands for diagnosis.

Vercel login and deployment remain skipped at the user's explicit request.

## Flower answer and island progression audit

The optional orchard's **Answer the Flowers** menu previously saved only its
local music activity; the story encounter required a different confirmation.
Both confirmation menus now save the same story phrase after three committed
seed plantings. The optional four-fruit orchard is not a story prerequisite.
Existing saves can submit the flower answer again without losing progress.
The HUD then directs the player to the round sandy Blight Clearing and identifies
the pending wave. Closing the panel and entering that clearing spawns each wave.

The wider audit also fixed stale instrument keyboard ownership and timing text
when visiting Help or the journal, plus premature completion wording after an
individual Conductor anchor. Outdoor flower-key play retains its active lesson.

Native checks passed: complete ten-task chapter, progression/save migration,
save failure safety, real island walking and earned gate crossing, instrument
feedback, fruit bucket, final gate/signage, castle round trip, journey menus and
Milo guidance. The chapter regression now uses the screenshot's flower menu,
automatic wave spawning, rejects future-task shortcuts without consuming fruit,
reloads each completed instrument, verifies journal isolation, and checks partial
anchor feedback. An older walking test was updated to respect the deliberately
locked gate before restoration and walk its far side only after earning entry.

Web release `97fc9465a205f200` passed the full diagnostic browser tour
(`work/flower-garden-browser-run.log`, RESULT: PLAYABLE). The transient journey
fixture used real flower-menu buttons and automatic clearing entry, observed and
released both enemy waves, then verified the River Song gate opening. Native
combat tests separately exercise the player's strike input and recovery window.
All tested worlds returned to the Hub; no fatal script/resource errors were
reported. All 102 packaged and hosted files passed manifest/header checks
(`work/flower-garden-hosting-verify.log`). Local preview: port 8906.
These checks establish the tested progression paths, not a guarantee against
every possible gameplay or device-specific issue.

## Garden audio revision

Continuous synthesized garden music is removed, including the layers previously
enabled by planting and restoration. Milo and player-played instruments retain
their own audio. Fountains now play at -12 dB with a -10 dB maximum spatial gain,
using native 3D distance attenuation. The maze source has a 12-unit reference
distance and 72-unit range; the smaller meadow fountain uses 4 and 28 units.
This supersedes the earlier louder-fountain setting above.

Focused native journey, maze and Milo checks passed. The maintained non-Mono
Web export completed without script/parse errors. Release `3ad50964657e813c`
passed all 102 local manifest checks and hosted MIME/isolation-header checks.
Local preview uses port 8907. Vercel remains skipped.

The focused WebGL check passed fountain playback, absence of soundtrack layers,
and return to the Hub (`work/garden-audio-browser-final-run.log`, RESULT: GARDEN
AUDIO PLAYABLE). The initial focused harness omitted mounting the valley pack;
the harness now enters the real valley through SceneLoader before its fixture.
The passing rerun used the same exported game package.
