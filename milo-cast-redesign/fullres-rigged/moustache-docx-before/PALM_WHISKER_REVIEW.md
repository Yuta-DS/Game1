# Milo — palm contour and side moustache

Local implementation draft, 29 August 2026. Not production approval or an exact-reference match.

Asset SHA-256: `fc3c32cc2c104c55970e3bbabb21006d9e0d20f52e036b348b0b4c3b6b8ee9ea`.

## What changed

- Reduced the inflated lower-palm silhouette, tapered the little-finger-side heel, flattened the back and defined a shallow cup and thumb cushion in the existing connected skin.
- Central palm depth measures 0.07135 m versus 0.08769 m before: about 19% thinner. The measured lower-palm little-finger-side half-width is 0.07009 m versus 0.08661 m: about 19% narrower. These are local contour measurements, not a whole-hand rescale.
- Kept hand length, distal knuckle spacing, digit lengths, all 61 bone rest matrices and every channel of all seven baked animations unchanged. Each hand remains 56,320 triangles.
- Replaced the short cheek bumps with white three-tip fur fans joined to broader, upward-swept moustache ends. Each side is one closed smooth mesh, weighted to the head, with its root intentionally buried into the cheek. These are stylized fur/muttonchops, not separate whisker hairs.
- Preserved the cast-style eyes, spectacles, outfit, cane and remaining geometry/materials. The scope test compares all 92 protected meshes against `palm-whisker-before/`.

The first palm correction was too subtle. The stronger contour initially folded through itself during thumb opposition. Restoring width locally to the moving thumb-side saddle, while retaining the narrower little-finger-side heel, removed the detected fold without changing any animation or bone.

## Independent image-only reviews

The reviewer saw actual before/current renders, not implementation code or test results. These are bounded part reviews, not full AnyCreature quality-gate passes. The initial and second verdicts are preserved below; no numeric test substitutes for visual judgment.

### First correction — insufficient

> 1. Palm improvement is weak. The current palm is smoother and less lumpy, but its broad, swollen silhouette is essentially unchanged. Removing the earlier grooves also reduces visible structure; it reads more like an inflated glove than a shaped paw.
>
> 2. The white cheek pieces read as wing-shaped fur tufts or muttonchops, not individual whiskers. Their color and upward sweep complement the elderly moustache, but the narrow junctions still make them look like separate attached pieces—especially in profile.
>
> 3. Remaining visible defects:
> - Abrupt, angular wrist-to-cuff transition, conspicuous on the relaxed hand.
> - Horizontal shading bands across relaxed fingers and pinched, dark finger-web recesses.
> - Thick, rounded palm heel and mostly uniform tubular fingers.
> - Moustache lobes look inflated in profile; cheek-to-moustache transitions need more continuity.
> - Tail is conspicuously faceted beside the smoother character surfaces.
>
> Image-only verdict: some surface cleanup, but not a convincing palm-shape correction yet.

### Stronger contour and broader moustache joins

This review preceded the final local thumb-saddle deformation repair.

> - Palm: improvement is now clearly visible. The rounded heel bulge has been reduced into a flatter, tapered contour, with subtler palm shaping. It looks less inflated than BEFORE. The little-finger-side corner remains slightly blunt, and the fingers still read as soft tubes.
> - Moustache: continuity is clearly better. The broader joins make the cheek tufts and moustache read as one sweeping form, especially from the front. They still read as stylized fur/muttonchops rather than whisker strands. The profile remains thick and rounded, but no longer looks narrowly connected.
> - Remaining issues: angular wrist/cuff transitions, finger banding and pinched web shading on the relaxed hand, and the visibly faceted tail.
>
> Image-only verdict: this revision produces a meaningful improvement in both requested areas.

### Final exported-shape confirmation

After the thumb-saddle repair, the same reviewer re-opened all five before/current images and reported:

> Yes—the previous verdict still holds after re-viewing all five images.
>
> - Palm contour remains visibly slimmer and flatter than BEFORE, with less heel swelling.
> - Moustache and cheek tufts retain the broader, more continuous sweep.
> - No obvious tear or collapsed thumb web is visible in these static views.
>
> Remaining visible issues: angular wrist/cuff transitions, horizontal finger shading bands, dark pinched recesses between relaxed fingers, a slightly blunt outer palm corner, and conspicuous tail faceting. The moustache remains bulky in profile, and the side pieces read as stylized fur tufts rather than whisker strands.
>
> This confirms the visible improvements only, not deformation quality across other poses or production readiness.

## Export and motion checks

- Full Blender reimport regression sequence completed on the SHA above: `verify_palm_whisker_delivery.py`.
- 631 authored frames checked for finite geometry, normalized weights, ground minima and loop endpoints. Hands are closed, single-component meshes; maximum sampled hand edge stretch is 1.8207×, below the conservative 3× limit.
- Zero nonadjacent hand-surface intersections in all 145 left-hand `Hand_Mechanics` frames and right-hand `Cane_Hold` frame zero. This does not guarantee all-body or arbitrary-pose collision freedom.
- Zero hand/cane intersecting triangle pairs across all 97 authored `Cane_Hold` frames. Frame-zero palmar fingertip-pad clearances are 1.4–1.9 mm. This is an authored grip, not force simulation.
- Exported finger hinges/coupling, palm orientation, sampled cuff clearance, previous enlarged-hand/outfit contracts and blink checks pass.
- All seven clips import and move in the separate Godot 4.7.1 compatibility-renderer preview. The graphical preview also renders successfully.
- `palm_whisker_scope_verification.json` and `palm_whisker_verification.json` record preservation, shape, topology and attachment checks. `gate.json` remains overall false because pre-existing sleeve distortion and unfinished visual quality remain.

## Limitations and provenance

Visible finishing issues remain as identified above. In particular, smooth fingers are still tube-like, wrist/cuff transitions are angular and shading bands remain in curled poses. The full-character maximum edge stretch is still 3.2595× at the raised-arm sleeve. Tail faceting, stiff coat behavior, dense geometry (190,332 triangles/97 meshes), material consolidation and production LOD remain outside this palm/moustache pass. The 61-bone asset is not a drop-in replacement for the game's existing 41-bone character.

AnyCreature's connected-shape and independent-review guidance informed this work. The existing AnyCreature cranium seed was retained, not recompiled in this revision. Blender 5.2 CLI performed the actual modeling, skinning/export and renders because no callable Blender MCP/plugin tool was available. No generated concept image was substituted for the actual-model previews.

All changes stay in this local draft and its separate preview. The complete immediate baseline remains in `palm-whisker-before/`. No live game asset replacement, Git commit, GitLab push, installation, deployment or upload was performed.
