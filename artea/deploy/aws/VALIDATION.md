# AWS preparation validation — 19 October 2026

Branch: `heart-melody-stability-pass`. Release: `a3636a9e73b72395`.
No AWS resources were provisioned and no live AWS deployment was tested.

## Checks completed

- Production API boundary tests: 7 passed, using real signed test tokens and mocked Cognito/S3.
- Existing AI route regression tests: 13 passed with mocked providers.
- Release packaging tests: 9 passed.
- Four CloudFormation templates pass `cfn-lint`.
- Linux backend image builds. Four container integration checks pass against temporary TLS PostgreSQL, including restricted runtime database permissions and readiness checks.
- Seven focused native game regressions pass. Managed account forms and cancellation of late login responses were also checked.
- Maintained split Web export completes. Pack validation finds no duplicate assets or patch deletions; the bootstrap pack is within its 100 MiB budget.
- Isolated Chrome full travel test reports `RESULT: PLAYABLE`, zero fatal resource/script errors, hub and castle movement, story entry, Mind Spark, Heart Melody, Heart Melody valley, Creator's Light, and return to the hub after each area.
- Prefetched areas enter without additional downloads; explicit story travel successfully requests content before background prefetch reaches it.
- The final compressed release reports `RESULT: STARTUP AND HUB PLAYABLE`, with no failed network requests or refetched parts.
- All 101 public release files match their SHA-256 manifest and hosted MIME, encoding, cache and isolation headers. All 98 unchanged runtime files decode identically to the full browser-tested split build; HTML supplies production configuration separately.

## Download and rendering measurements

- Bootstrap PCK: approximately 30.2 MiB, down from the previous approximately 253.9 MiB.
- Initial compressed runtime download: 38,067,886 bytes, including engine files.
- Complete staged release: 391,931,584 bytes. The landing page itself loads separately before the runtime.
- Final local cold-browser check: engine starts after 19.5 seconds; hub scene construction is logged after 43.9 seconds; controls become ready around 155.7 seconds. These are local headless-machine measurements, not internet or production performance promises.
- The headless full-travel run measured a 166.7 ms median idle hub frame interval. This does not establish acceptable performance on players' hardware. Real-device cold/cached loading, memory use, shader preparation and frame-rate budgets remain launch acceptance checks.

## Remaining launch checks

- Authenticate an AWS CLI profile, select the account, verify SES sending identity and production email access, then execute the documented deployment sequence.
- Exercise real Cognito signup, verification, recovery and refresh, and private artwork authorization across two accounts and a guest.
- Validate both API tasks across availability zones, task recovery, RDS failover/reconnect and backup restoration in AWS.
- Validate WAF with legitimate uploads/AI requests, traffic capacity, operational alarms, costs and retention policies.
- Journey/garden progress remains browser-local for both signed-in players and guests. Cross-device progress synchronization is not implemented; uploaded artwork uses durable private S3 storage in production.
- The legacy Firebase autoload reports its missing optional `.env`. Production authentication uses Cognito and Firebase credentials are not included in the release. Existing UID fallback warnings remain; the tested browser paths have zero fatal resource/script errors.

See [README.md](README.md) for architecture, deployment commands, costs and account prerequisites.
