# Main sync and Melody maze — 22 October 2026

Fetched GitHub main during this session and fast-forwarded
`more-improvements-on-melody-world-and-some-other-fixes` to `6718994e`.
Main already contained PR #84, so all existing Melody work was included and
there were no merge conflicts. No remote push or PR update was performed.

The maze now includes the former straight instrument promenade. The fixed
layout has winding routes of 43 cells to the fountain and 45 to the instrument
exit, with branches and dead ends. The instrument circle, fountain clearing,
raised garden route, saved progress, and Q escape remain available.

Main's exporter now gzips individual chunks. Updated AWS packaging to validate
their compressed sizes, decompressed lengths and original pack checksum, and
preserve them without HTTP Content-Encoding so the game loader inflates them.
Added coverage for compressed delivery, corruption and unknown encodings.

Validation:

- 11 distinct native regressions passed: maze, Milo guidance, complete chapter,
  gallery flow, minimap, embedded floating world, station traversal, story rail,
  Hub cleanup, gallery spawn camera and grounded recovery volume.
- Seven production backend tests and ten packaging tests passed.
- Complete maintained non-Mono Web export succeeded. Release
  `0ad3f044f6de9004`: 94 files, all hashes and hosted headers verified.
- Real Chrome WebGL2 tour returned `RESULT: PLAYABLE`: startup, guest login,
  movement, castle, both maze routes, solid hedges, fountain audio playback,
  five instruments, piano seating, Q escape, guidance, staged garden menus,
  River Song controls, other worlds and Hub returns.
- Browser captures and logs: `work/main-maze-browser/` and
  `work/main-maze-browser-run.log` (local QA artifacts, not committed).

Local full game: http://127.0.0.1:8911/

No AWS or Vercel deployment was attempted. This is not a smoothness guarantee:
the measured garden median was about 49 ms/frame and the Hub about 83 ms/frame
in this browser run. Automated audio checks confirm playback state, not a
human listening assessment. Journey saves remain browser-local.
