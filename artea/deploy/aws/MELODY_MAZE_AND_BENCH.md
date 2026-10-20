# Melody maze, singing fountain and piano bench

20 October 2026.

The Heart Melody arrival court now contains a large, connected hedge maze
around the existing instrument circle. A nine-cell clearing houses the
relocated musical fountain. The 24 added arrival blossom trees were removed.
The raised, flower-lined route to the garden islands remains open.

An open promenade reaches the free-play instruments without solving the maze.
The maze itself has solid six-metre hedges, a reachable fountain court and
**Q** to return to its entrance. Its foliage and lighter trimmed tops use two
MultiMesh draws and a small procedural shader, with no foliage texture download.

The fountain plays an original, seamless 16-second bell-and-chord loop through
a positional audio source. Its volume fades with distance, with a 120-metre
limit so the separate instrument circle remains quiet. Existing water arcs
and animated skyward notes remain in the clearing.

The piano now has a physical upholstered bench. **Q** seats the actual player
using the game's existing seated pose. **Tab** switches between the seated
character view and close keyboard view; **Esc** stands up at the original safe
standing position. Clicking, dragging and **A S D F G H J K** still play notes.
Milo uses the other end of the bench so he cannot overlap the player.
Standing up restores both characters and normal controls.

Milo's station recording now explains the instruments, maze and singing
fountain, and distinguishes the raised path to the Melody World Garden islands.
It uses the same opening recording as its voice reference. Captions match the
new recording. Escort and narration continue throughout the arrival court,
and Help replay selects the station directions while outside the islands.

## Verification

Twelve focused/regression checks passed: music circle, maze integration,
gallery piano, arrival court, Milo guidance, gallery flow, minimap, embedded
world, station traversal, Crown railway, Heart return gate and main-world
integration. The final focused rerun checks the latest bench, companion,
promenade and narration changes. Evidence: `work/maze-final-checks.json`,
`work/maze-regressions.json` and their logs. The initial maze test's type
annotation was corrected and its subsequent focused runs passed.

The maze test sweeps the real gallery player's capsule through its solution,
checks hedge collision and the direct promenade, reaches the fountain,
checks looping positional music, uses the fully rigged fox's seated pose,
stands up again and verifies Milo's playing voice and route caption.

Native Compatibility-renderer captures were reviewed for maze coverage,
the fountain clearing and seated piano framing. Captures are under
`artifacts/arrival_repairs/`, excluded from export. Heavy voice generation and
rendering were run sequentially after a concurrent run exhausted native memory.

The opt-in `tools/web-smoke.js --music-circle` test now additionally checks
the physical bench pose, Tab keyboard view, maze solution and collision,
open instrument promenade, fountain playback, Milo directions and Q return.
Its controller is copied only into the test browser's temporary filesystem.

## Packaged build

Release `9a064064f0ec6b61`. The complete non-Mono Web export passed the pack
dependency, duplication and startup-budget checks. The maze shader, fountain
theme and revised station recording are included in the exported packs.
All 102 packaged files passed SHA-256 and hosted MIME, compression and
isolation-header checks.

The screenshot review caught an overlap between the maze status and Milo's
subtitles. The maze status was moved above the subtitle panel. The changed
Art Castle pack was rebuilt through the maintained import, pack-graph,
Web-export-plugin, pack-check and splitting tools. Its dependency manifest
and the Core pack's SHA-256 were verified unchanged. Evidence:
`work/maze-ui-export.log` and `work/maze-ui-core.sha256`.

The occupied-piano removal test also passed: destroying an active piano
restores player movement, standing state and follow camera.
Evidence: `work/bench-removal-final.log`.

Local preview: <http://127.0.0.1:8887/>.
Package: `artifacts/aws/artea-aws-9a064064f0ec6b61` and adjacent ZIP.
Browser evidence: `work/maze-final-browser-run.log` and `work/maze-final-browser/`.

The first browser tour passed all new mechanics but its last Hub return
stalled while another native export ran. Leftover owned test browsers were
closed, and the final tour runs without a concurrent build. The smoke runner
now closes its own browser through browser-level CDP before its process
fallback, avoiding detached Chromium process trees between future runs.

The final isolated Chrome tour finished with `RESULT: PLAYABLE`, zero fatal
script/resource errors and every world return successful. It passed keyboard
and mouse play on all five instruments, real bench seating and Tab views,
maze navigation and solid walls, the instrument promenade, looping fountain
music, Milo's arrival recording and Q return. The corrected subtitle layout
was reviewed in its actual browser capture.

Vercel CLI reports `Logged out`; the existing production project and alias
were not changed, and no live deployment is claimed.
