# River Song to Bell Grove

The three valves complete one activity: the Waterfall Organ. Bell Grove opens
after three saved River Song activities, in order:

1. Harvest protected Dew Pears and tune the organ to notes **3, 1, 2**.
2. Harvest protected Sun Plums in Feeling Garden and tune the five Hush Vine
   strings beside the river to **1, 2, 3, 4, 5**.
3. Harvest protected Bell Apples beside the Rain Boat and answer the Call Bells
   **North, South, East, West** (Leaf, Sun, Droplet, Diamond; notes 1, 3, 2, 4).

Each activity requires **Check composition**. Once all three are saved, approach
the Bell Grove gate on the flowering bridge beside the boat. The gate collider
opens on approach. Sailing is optional; the bridge is a continuous walk.

The existing save and gate requirements are connected. The unclear feedback was
that the gate named the final Call Bell requirement even when the harp was the
next missing task, and the tuning rows showed only goal notes. Rows now display
their current notes and goals; the gate shows River Song progress out of three
and the next missing activity. Check composition now comes directly below the
playing controls, ahead of optional replay/hint/reset controls. Completion notices explain when Bell Grove is
actually unlocked. No gameplay requirement or save schema was bypassed.

## Native validation

The complete-chapter regression now uses the physical river valve/bulb/boat
interactions, real tuning and note buttons, and Check composition. It verifies
an unfinished organ is rejected, organ/harp completion leaves the gate closed
with the correct next task, a failed Call Bell save neither spends fruit nor
unlocks the gate, a retry commits, and saved progress survives reload. It then
walks the real capsule from the Rain Boat across the flowering bridge into Bell
Grove and checks the gate collider opens. The remaining chapter reaches its
finale. Journey presentation, Milo guidance and chapter migration also pass.
Evidence: `work/river-song-route-tests.log`.

The recent loading/audio/rendering rollback and fountain-only garden music are
preserved. Vercel login and deployment remain skipped.

## Final Web verification

Release `57d0e3181fa70633` is served at the existing local preview address,
`http://127.0.0.1:8908/`. All 95 file/hash/MIME/header checks passed. The focused
browser run completed the actual organ, harp and Call Bell controls, checked the
gate's next-task feedback after each step, confirmed the gate collider opens,
and returned to the Hub (`RESULT: RIVER SONG ROUTE PLAYABLE`). It also measured
the organ confirmation button inside the visible control area and captured its
layout. Evidence: `work/river-song-route-final-browser-run.log`,
`work/river-song-route-final-browser/`, and
`work/river-song-route-final-hosting-verify.log`.

The final confirmation placement also passed the complete-chapter and menu
regressions (`work/river-song-confirmation-tests.log`). Loader, shader warmup,
pack layout, project configuration, MusicManager and drawing music remain byte
identical to the performance rollback. This tests the connected route; it does
not inspect or reset the player's personal browser save.
