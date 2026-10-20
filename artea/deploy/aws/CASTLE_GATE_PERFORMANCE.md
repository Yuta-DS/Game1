# Castle gate loading — 20 October 2026

Tested release: `19a23713ba3cf4f1`, branch `heart-melody-stability-pass`.

Castle entry fell from **59.7 seconds to 31.6 seconds**, a **47% shorter wait**.
The comparison uses the previous compressed release `289b62a189b89463` and
fresh headless Chrome profiles on this machine. Both runs had already
prefetched the castle assets. These are local browser measurements, not
internet or hardware-GPU performance guarantees.

## Implementation

- Repeated castle and railway primitives share scene-owned mesh resources.
  Nodes, materials, transforms, animations and collision shapes remain separate.
- The maintained Web exporter generates `generated/castle_tree.scn` before
  calculating pack dependencies. This prepares the complete detailed tree,
  including foliage transforms, materials and collisions, outside the browser.
  The generated file is ignored by Git and recreated on every export.
- The preparation step reloads the saved scene and compares hierarchy,
  geometry, material properties/textures, transforms, foliage instance buffers,
  metadata and collision bounds against the original generated tree. Imported
  scene boundaries are flattened to prevent duplicated children.
- Web entry loads that prepared tree and reconnects its rotating mechanisms
  and both ambient tracks. Native/editor play retains procedural construction.
- The castle prepares its actual arrival view underneath the opaque loader,
  avoiding a separate synthetic shader pass with different lighting. The loader
  still waits for actual rendered frames before handing over control. Distant
  shaders not used by the arrival view can compile when first encountered.

Measured cumulative loader phases were resources 1.75 s, construction 8.15 s,
actual-view preparation 27.90 s, and ready 29.43 s. The external browser
transition measurement, including request/mount overhead, was 31.6 s.

## Validation and delivery

- All 11 existing loading/account/gameplay regressions passed with the prepared
  tree enabled, including the castle/gallery, embedded world, minimap, Heart
  Melody gates, station jumping and Crown Line railway.
- The additional prepared-tree regression passed placement, collision presence,
  imported-child uniqueness, ambient playback and actual crystal rotation.
- Full maintained non-Mono Web export, pack dependency/integrity checks and
  startup size budget passed. Bootstrap remains approximately 30.2 MiB.
- All 102 packaged files passed SHA-256 and hosted content/cache/isolation
  header validation. The total staged package is about 402 MB; preparing the
  tree adds approximately 10 MB to the background castle download.
- The final Chrome tour reported `RESULT: PLAYABLE`, zero fatal script/resource
  errors, hub and castle movement, story, Mind Spark, Heart Melody activity and
  valley, Creator's Light, and all returns. No additional castle PCK download
  was needed at entry. The castle screenshot was visually inspected.

Local preview: <http://127.0.0.1:8883/>.

Package: `artea/artifacts/aws/artea-aws-19a23713ba3cf4f1` and adjacent ZIP.
Browser evidence: `work/castle-prepared-browser-run.log` and
`work/castle-prepared-browser/`.

Vercel CLI still reports `Logged out`, so no production deployment is claimed.
AWS has not been provisioned. The existing production project/alias was not
changed and no temporary project was created.
