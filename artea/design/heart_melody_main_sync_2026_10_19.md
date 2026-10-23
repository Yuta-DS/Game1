# Heart Melody sync with GitHub main ? 19 October 2026

Main baseline: `66b180ac`. Heart Melody baseline: `dce035aa`.
Backup branch: `backup/heart-melody-before-main-sync-20261019`.

## Resolution

- Preserve main's open kingdom routes, World One layout, station and railway changes, loading/music handover, pack prefetch, and Web tooling.
- Preserve World 2's independent garden, flower/instrument interactions, progression, camera continuity, Castle return, and recorded Milo guidance.
- Combine main's recorded-speech normalization with the World 2 narration hooks.
- Relocate the World 2 entrance to main's current Heart station landing. Add a level corner landing and preserve a continuous collision-backed walking route in both directions.
- Keep Milo's escort pace close to the player on the longer route, including catching up after the player stops. This is conditional on the World 2 escort flag; main's ordinary companion gait remains intact.
- Include the World 2 scene in the Art Castle Web pack because the Castle instantiates it as an embedded walking destination. Direct scene entry uses main's SceneLoader and the same pack.
- Use SceneLoader.can_open for campaign entry so an unmounted Web pack does not appear to be a missing kingdom.
- Update integration tests for main's open routes, loading transition, current station landing, and input clearing during artwork entry.

## Validation

Passed focused headless checks: scene swaps use loader; Heart main integration; Milo recorded guidance; flower/instrument feedback; gate round trip; station-to-garden walking with Milo, shared camera and HUD, return walk and Castle gate; full chapter; musical garden; Castle gallery flow; minimap; embedded floating world; station jump traversal; Crown railway; World One station/causeway.

Logs and machine-readable results are under `work/main-sync-*`. Earlier failing iterations are retained there; final station and Milo results are in `work/main-sync-final-tests.json`, gallery flow passed before the final station-only recheck, and route-policy/garden rechecks are in `work/main-sync-rechecks.json`.

The separate World One preview branch contains an arrival-camera test that is absent from main; it was not imported into this merge.

## Web delivery limitation

The standard non-Mono Web export was exercised with main's pack pipeline. The export reports legacy resource/addon errors and UID warnings that require review before claiming a clean production build. The Vercel CLI reports Logged out, so no production deployment or production-browser verification was performed. Do not describe this merge as deployed.
