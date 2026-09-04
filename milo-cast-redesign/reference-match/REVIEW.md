# Local Milo reference review — 2026-08-28

This records actual review outcomes, not an assertion of an exact image match. All image reviews compared Blender renders of the exported GLB with the two user-supplied images. The independent reader had an image-only task. Earlier candidate renders at the same filenames have since been regenerated; the rejected spherical construction is retained in `head_round_draft.py`.

## Spherical construction — first repair

Reader verdict: “The identity is readable; this is not yet a faithful likeness.”

The reader found elongated eyes/glasses, oversized curved muzzle lobes, a uniform cream spherical head, thin ears, missing taupe markings, spread arms, large wrists, bead-like fingers, and a rear strap that was hidden behind the coat. The round spectacles, smaller eyes/muzzle, closer arms, shorter cuffs and visible rear strap were repaired.

## Spherical construction — second repair

Reader verdict: “recognizable cat scholar, but likeness still fails. Rounder glasses and the rear coat strap help; the main geometry remains different.”

Approximate image-relative measurements: nose offset was about 0.65 lens diameters below eye centers instead of 0.3; overall height/head width was about 2.1 instead of 1.8; chin-to-floor/head width was about 1.17 instead of 0.95. A spherical skull with attached features remained the main construction problem.

Following the AnyCreature repair-limit guidance, the head concept was restarted using an explicit planar cage. The body was shortened 18% while retaining the head dimensions, the nose was raised, and the arms were narrowed coherently through rig/object scaling.

## Planar construction — first repair

Reader verdict: “substantial improvement, but still an approximate interpretation—not a faithful reference match.”

The reader reported convincing nose/eye spacing, round glasses and a much closer compact body. Remaining issues were a heavy central lower muzzle and doubled lip, a faceted barrel/checkerboard skull, sharp ears, uniform cheek blades, and oversized wrist/thumb bulges.

The second repair removed the large lower muzzle and separate chin piece, narrowed the low jaw, introduced staggered triangular skull planes with localized taupe markings, shortened the ears, varied the cheek tufts, and reduced the paw wrist/thumb. A low frontal fill light was added to expose the lower facial planes in the actual render instead of leaving them in dark shadow.

## Structural and motion checks

- Self-contained GLB: 21,358 triangles, 11 meshes, 41 bones; 926,524 bytes at the final geometry check.
- Finite geometry, valid indices and normalized skin weights: pass.
- Existing Idle, Walking_A, Guide and Speak channel data: retained and checked against the source export. These are not newly authored animations.
- Both remeshed paws: zero nonmanifold edges in the saved Blender file.
- A 232-frame, 24-fps preview is rendered from the exported model, covering excerpts of all four existing clips. Finite evaluated geometry is checked throughout. This does not prove collision-free motion or complete loop coverage.
- Final preview verification: H.264, 480×600, 232 frames, 9.666667 seconds, 982,428 bytes; zero non-finite evaluated vertices. Boot bounds reach approximately Z = -0.03045 during the sampled clips, below the studio floor at zero. Foot-contact cleanup is still required; the motion is not a collision/grounding pass.
- No game import, gameplay, collision, cloth, facial animation, articulated finger animation or cane-grip validation was performed. The shoulder/collar junction and coat deformation still warrant production rig cleanup; passing numeric checks does not make this animation-production-ready.

## Scope

Local review only. No game asset replacement, commits, pushes, deployment, uploads or publication. The canonical turnaround has no cane, as in the user's primary four-view reference. No full AnyCreature quality certification is claimed.

## Planar construction — second repair and lower-jaw restart

Reader verdict before the jaw restart: “clearly improved and recognizably the same cat-scholar design, but still a reference-inspired interpretation—not a faithful match.” The reader confirmed that the oversized lower-muzzle bulge was gone and the mouth visible. The main remaining mismatch was “too much exposed faceted jaw” and a long tapered chin. Recognition passed; faithful-reference likeness did not.

The failing lower-face part was then restarted as a broad, shallow jaw cage rather than preserving its pointed lower rings. Its front surface is cream, the assembly was fitted back to the collar, and eye/spectacle dimensions were preserved when restoring head height. The final saved geometry and renders reflect this reconstruction, not the previous long-chin candidate.

## Final independent image verdict

“Recognition passes: this clearly reads as the reference’s bespectacled cat scholar. The shortened jaw fixes the pointed-chin problem, and the head now meets the collar convincingly.”

“Faithful likeness remains unverified as a pass: it is a recognizable adaptation, not an exact match. The primary remaining mismatch is the facial sculpt—the smooth crescent muzzle and three uniform cheek blades look attached to a broad, flat-bottomed head. The reference’s muzzle, cheek fur and rounded jaw form a more integrated, expressive shape.”

Delivery classification: reference-inspired 3D reconstruction with improved proportions and facial spacing; remaining differences in facial sculpt and surface treatment. Do not rename this verdict to an exact-match approval or production-quality certification.
