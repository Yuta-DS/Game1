# Compact paws and anatomical orientation correction

Historical revision. The later palm/finger naturalness pass is recorded in `NATURAL_HAND_REVIEW.md`; current assets and reports reflect that later pass.

User feedback: the palms did not suit Milo and the back of the palm should face the other direction. Implemented on the existing local draft, without changing live game files, committing, pushing or uploading.

## Changes

- Narrowed local paw width by 10%, shortened palm length by 15%, and shortened the fingers' longitudinal span by 32%. The wrist stays inside the existing cuff.
- Replaced the broad flat section with a rounded dorsal arch and shallower palmar surface. Resting fingers now curl gently into the palm.
- Corrected the inconsistent palm-side convention: the thumb placement denotes anatomical local +Z as the palm, so flexion uses positive X rotation. The previous finger curls bent to the other side.
- Rotated the two resting wrist frames by mirrored 55-degree angles. Palms point inward toward the coat, thumbs forward, and backs outward/front. The greeting turns the actual palm forward with the thumb on the body side. Cane_Hold shows dorsal knuckles forward and curls the fingers behind them.
- Retargeted the shorter fingers/thumb and cane placement, including a measured 6 mm final clearance adjustment. The cane geometry itself is unchanged.
- Turnaround/hero renders now show the exported relaxed Idle pose, not straight-finger authoring bind pose.

AnyCreature's part-readability and real-joint guidance informed the correction and image-only review; modeling, rigging and export used Blender directly because the Blender plugin connection was unavailable. This is not a full AnyCreature quality-gate pass or an approved likeness reconstruction.

## Evidence

- All 486 authored animation frames: finite geometry, normalized skin weights, exact loop endpoint match, no boot ground penetration.
- Both paws: one connected component, zero nonmanifold edges. Maximum hand edge stretch 2.700x, below the unchanged 3x limit.
- Cane frames 0, 48, 96: zero intersecting triangle pairs between the right paw and shaft, collar, crook or ferrule. This sampled surface test does not prove a tight contact grip or full-character collision freedom.
- Export orientation checks: minimum inward-palm dot 0.79474 at rest, greeting forward-palm dot 0.97526, cane forward-dorsal dot 1.0. Both resting thumbs point forward.
- Godot import tests also assert these palm/back directions and forward-facing resting thumbs; all six clips pass. Native preview captures confirm the settled greeting and cane poses render with the corrected orientation.
- All 100 non-hand meshes retain their triangle geometry within 0.0000001 m. 47-bone rig, six clips, 61,342 triangles overall.
- `palm-before/` preserves the previous Blender/GLB files, sources and images. `hand-before/` preserves the older pre-hand-rebuild version.

## Independent image-only review (verbatim)

Version B fits the character better: shorter, rounder fingers and smaller, compact palms echo the oversized head and squat body. A looks more like elongated human gloves.

- Rest: B’s front view shows narrower hand profiles, while its side view exposes the broad hand surface—consistent with palms turned inward toward the thighs and backs outward. The thumb appears forward-facing. A presents broad hands front-on and a thin, stick-like profile from the side.
- Wave: B has a clearer compact paw silhouette. The thumb is on image-left, versus image-right in A. It reads as the intended palm-facing greeting, although the featureless surface alone cannot conclusively distinguish palm from back.
- Cane grip: B shows the broad outer hand surface toward the viewer, with three fingers overlapping the shaft. The thumb is not clearly identifiable as an opposing digit, so the actual clasp remains less convincing than the rest and wave.

Residual issues: B’s hands are quite small at full-body scale; palm/back differentiation remains weak; the grip still reads somewhat like rounded fingers laid across a cane rather than visibly wrapped around it. These images do not establish rig correctness or collision-free contact.

## Status

The requested compact-paw and orientation changes are implemented and numerically checked. The model remains a local draft. Detailed palm/back surface treatment, more convincing grip contact, and the previously reported face/outfit reference-likeness gaps remain unapproved.
