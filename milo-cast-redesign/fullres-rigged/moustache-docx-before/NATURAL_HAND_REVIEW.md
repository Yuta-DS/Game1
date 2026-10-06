# Natural palm and finger revision

Historical 47-bone revision, superseded by `HAND_MECHANICS_REVIEW.md` and the 61-bone export. The user rejected the underlying mechanics after this surface-shaping pass. Its figures and image reviews below describe the preserved prior version, not the current asset.

Requested scope: make Milo's palms and fingers more natural, retaining the corrected palm/back orientation. This changes the separate local draft, not the live game. No commit, push, deployment or upload.

## Implemented

- Shallow cupped palm with an integrated thumb heel and outer palm cushion, subtle dorsal knuckles, and restrained flexion folds sculpted into one connected mesh.
- Curved knuckle arc and anatomically mirrored index/middle/little proportions. Fingers vary in length and thickness, taper toward their pads, and bend at two real joints each.
- Relaxed finger cascade: index more open, little finger more curled. Gentle thumb opposition and a shorter thumb tip remove the straight dangling-thumb silhouette.
- Greeting opens the fingers with slightly different curl amounts. Guide preserves an extended index with curled companion digits. Idle, walk and speech have very small coordinated finger relaxation.
- Cane pose uses a lower, comfortable wrist target and a more open C-shaped curl. The unchanged cane is turned away from the cuff and surface-contact fitted. Inside and outside renders expose the actual grip, including its remaining loose contact.
- Existing 47-bone rig, six clips, palette, face, clothing and non-hand geometry preserved. All 100 non-hand mesh triangle geometries match the previous asset within 0.0000001 m.

AnyCreature's structured-part/readability and real-joint guidance informed the design and image-only reviews. Blender CLI performed modeling, rigging, export and rendering because no callable Blender plugin connection was available. This is not a claim that the full AnyCreature quality gate or reference likeness has passed.

## Measured checks on the exported GLB

- SHA-256: `12941dd7b0879f565e5e5d4fc6b674e713abe8a596f7eb372201dc366c38bf8b`.
- 2,505,200 bytes, 64,414 triangles, 102 mesh objects, 47 bones.
- All 486 authored frames across six clips have finite vertices. Skin weights are normalized; the GLB is self-contained. Loop endpoint maximum vertex error is zero.
- Both paws have one connected component and zero nonmanifold edges.
- Maximum hand edge stretch: 2.073604x in Cane_Hold, down from 2.700x in the prior compact-paw draft. Conservative limit remains 3x. Whole-character maximum remains 2.741572x on the raised sleeve.
- Palm orientation assertions pass: inward resting palms, forward resting thumbs, palmar greeting and dorsal-front cane pose.
- All 97 authored Cane_Hold frames have zero right-hand/cane surface triangle intersections. This is not a self-intersection, sleeve-contact or full-character collision guarantee.
- At cane frames 0, 48 and 96, nearest digit-to-shaft/collar distances are approximately 0.17 mm (little), 0.41 mm (middle), 3.73 mm (index), and 6.44 mm (thumb). The hold remains loose, not a tight four-digit grasp.
- Godot imports all six clips and passes finite bone-transform, motion and palm-orientation assertions.

The first working revision's stronger joint grooves looked like constricting rings. They were softened; its revised hand/cane intersections were also corrected before final export. Failed attempts were not recorded as passing gates.

## First working revision — independent image-only review, verbatim

Version B looks modestly more natural overall, especially in the relaxed pose.

- Palm: B has more volume variation and a clearer transition into the fingers. Both still have a broad, rather slab-like palm tapering sharply into the cuff.
- Fingers/joints: B’s varied lengths and bends feel less uniformly tubular. However, the greeting hand’s dark transverse joint grooves look like constricting rings; A has a cleaner, softer cartoon finish.
- Thumb: Both have a smooth, convincingly joined thumb base, but the thumb remains a fairly featureless tube. B’s hanging thumb looks slightly long beside its more curled fingers.
- Relaxed curl: B wins clearly. Its uneven finger curl creates a more relaxed silhouette; A mostly looks like straight fingers pointing down.
- Cane view: B’s finger projections are shorter and look more compact against the cane. Neither image clearly demonstrates fingers wrapping around it or an opposing thumb, so a secure grip is not established.
- Visible defects: B introduces pinched-looking joint bands and retains deep, sharp finger-web notches. The wrist/cuff transition remains abrupt in both.

Best direction: B’s proportions and curl, with softer, shallower joint shaping.

## Final independent image-only review, verbatim

Yes—the final version improves on original A, most clearly in the relaxed pose.

- Palm/fingers: More varied finger lengths, a subtly fuller finger-base area, and less uniform tube-like shaping make the hand feel more organic.
- Relaxed pose: The uneven curl reads more convincingly relaxed than A’s mostly straight hanging fingers.
- Joint bands: Noticeably softened versus the first B review. They now read primarily as broad bend shadows, though the shortest greeting finger still has a visible crease.
- Thumb: The dangling thumb is visibly shorter than earlier B and better balanced with the curled fingers. It remains simple and fairly tubular, appropriate to this style.

Remaining limitations: the palm is still broad and wedge-like near the cuff, with a fairly abrupt wrist transition and deep finger-web notches.

The inner cane view reveals an opposing thumb-side lobe, but the fingers look like rounded pads beside the shaft; continuous wrapping/contact is not clearly established. The gold handle-to-collar junction also has a conspicuous angular notch/offset. These images support improved hand styling, not a fully verified grip.

## Scope and recovery

`natural-before/` preserves the immediately previous Blender/GLB, hand source, rig source and key images. Earlier backups remain intact. The face/outfit likeness is still unapproved, and this asset is not a drop-in replacement for the live game's different rig.
