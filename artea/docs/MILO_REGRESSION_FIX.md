# Milo regression fix

## Changes

- Arrival greeting now completes and returns to idle instead of remaining in GREETING and replaying every five seconds. It cannot interrupt an active conversation.
- Cane recovery no longer wraps an early-release negative phase offset to the end of recovery. This removes the forward/backward snap while retaining exact hand-to-cane attachment.
- Natural-animation assertions now address the real preserved Milo 1 face meshes (`EyeWhite`, `BrowFrame`, `MoustachePad`), not retired prototype names. Mesh resources must exist; no placeholder nodes were added.
- Speech-gesture tests explicitly opt into speech. Production remains muted by default. Activity tests cover both muted listening and enabled talking.

## Evidence

Recorded baseline: `artifacts/branch_compatibility/milo-regressions-before/results.json` reproduced both original suites: one follow failure and nine animation failures.

Final focused results: `artifacts/branch_compatibility/milo-regressions-release-check/results.json`:

- Natural animation: PASS. Maximum forearm step 4.25 degrees against unchanged 7-degree limit; maximum elbow flex 35.04 degrees against unchanged 48-degree limit. Baseline forearm step was about 29.4 degrees.
- Companion follow: PASS, including arrival greeting, idle settling, no repeated wave, personal space and movement checks.
- Speech animation, activity states, conversation context: PASS.

Additional results: `artifacts/branch_compatibility/milo-live-compatibility/results.json`:

- Independent Milo generations and missing-walk fallback: PASS.
- Live hub visibility harness: not clean. Preloading the full hub reports missing Global/GameManager identifiers in other scripts. Do not treat its exit status or visual assertions alone as a clean pass.

The first expanded test run stopped on the activity test's outdated speech assertion; its runner then raised a missing-exit-code error on timeout. The corrected test was rerun successfully in the final focused batch; the failed diagnostic artifacts are retained.

## Delivery boundary

The maintained non-Mono Web export succeeded (`milo-regressions-final-web-export.log`), with existing UID/fallback and ObjectDB warnings. No assets or production voice defaults changed. No commit, push, merge or production deployment was performed. Full-project/remote-branch release verification is not established by these focused tests.

Local browser verification of `http://127.0.0.1:18080/?build=milo-regressions-fixed`: start screen rendered, Offline Guest entered the coloured hub, Milo 2 was visible, and pressing T opened his conversation UI. This smoke test is not a visual measurement of the preserved Milo 1 cane gait; that measurement comes from the evaluated-rig regression above.
