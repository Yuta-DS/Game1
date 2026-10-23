# Loading improvements — 20 October 2026

The later [castle gate follow-up](CASTLE_GATE_PERFORMANCE.md) reduces the gate
transition further, from 59.7 s to 31.6 s in release `19a23713ba3cf4f1`.
The measurements below describe the earlier general loading pass.

Release: `289b62a189b89463`, branch `heart-melody-stability-pass`.

| Browser check | Previous run | New run | Reduction |
|---|---:|---:|---:|
| Startup to controllable hub | 155.7 s | 60.1 s | 61% |
| Prefetched castle entry | 96.6 s | 59.7 s | 38% |
| Castle → hub | 36.2 s | 18.2 s | 50% |
| Prefetched Mind Spark entry | 5.0 s | 2.1 s | 58% |
| Prefetched Heart Melody activity | 10.0 s | 5.1 s | 49% |
| Prefetched Heart Melody valley | 24.8 s | 8.0 s | 68% |
| Prefetched Creator's Light | 17.6 s | 7.0 s | 60% |
| Complete automated travel test | 588.4 s | 310.9 s | 47% |

These are local headless Chrome measurements on this machine, using fresh browser profiles, not internet or hardware-GPU performance guarantees. The startup baseline uses the previous compressed release. The previous full tour used uncompressed split files; the new tour uses the compressed release. Both tours entered prefetched activities/castle/valley with zero additional downloads, so those entry measurements exclude network waits. Full-tour elapsed time also includes fixed test pauses.

## Changes

- Stop rendering the full 3D world underneath the opaque loading screen on Web. The small shader-warmup viewport continues rendering independently. Scripts, physics, cameras and authored visibility remain active. Restore the original viewport setting before showing the world, and on failure/cancellation.
- Retain keys for shader variants that have actually warmed across scene changes. Identical shader sources share a key. Unseen or changed programs still warm normally; partial warmups do not mark unfinished variants as complete. The cache holds no scene or material objects.
- Start hub downloads using the browser bridge during sign-in, respecting Save Data. Observed hub downloads began around 7.7 s and completed around 9.2 s, before Guest entry around 14.7 s.
- Log resource, warmup and ready timestamps for future profiling.

## Validation

- All 11 focused/native regressions pass: loading performance, account setup, loader routes, Heart Melody merge/guidance/gate round trip, castle/gallery, minimap, embedded galaxy, station jumping and crown railway.
- Maintained full Web export and pack integrity/budget checks pass.
- All 101 packaged files pass integrity and hosted content/cache/isolation header checks.
- Full compressed-release browser tour reports `RESULT: PLAYABLE`, with zero fatal resource/script errors, hub and castle movement, story and every tested activity/valley, plus returns to the hub. Hub and valley screenshots were inspected to confirm 3D rendering is restored.
- Background prefetch completes, prefetched areas need no further downloads, and an early story entry correctly prioritizes its requested content.

The total staged download remains approximately 392 MB; this change does not remove game content or solve bandwidth limits. The headless idle hub frame interval was 116.7 ms; a normal hardware-GPU/device performance check is still required before launch. The local static preview has no Cognito API, so private artwork API requests cannot succeed there; production backend deployment remains separate.

The existing Vercel publishing check reports `Logged out`. No temporary/new Vercel project was created and no live deployment is claimed. AWS has not been provisioned. The tested static package is available under `artea/artifacts/aws/artea-aws-289b62a189b89463` with its adjacent ZIP.
