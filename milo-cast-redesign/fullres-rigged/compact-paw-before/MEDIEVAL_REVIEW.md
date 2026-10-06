# Milo — larger palms, smoother fingers, medieval-inspired outfit

Local implementation draft, 28 August 2026. This is not an approved likeness or production replacement.

## Requested changes

- Twice the previous compact palm length and knuckle width. Finger and palm depth scales are enlarged to match, while the buried wrist socket is preserved. This means 2× linear dimensions, not 2× volume.
- Hand subdivision increased from level 2 to 3. Each connected hand now contains 56,320 triangles rather than 14,080. All hand faces use smooth shading. This is actual exported geometry, not only a lighting effect.
- Replaced the modern notched lapels, tie, waistcoat, pocket welts and old cuffs. The new fantasy court outfit has a deep peacock coat, short shoulder mantle, high collar, burgundy doublet, gold frog clasps, embroidered four-lobed motifs, belt/buckle, padded sleeves and flared gold-trimmed cuffs.
- Retargeted the raised arm and cane grip for the larger hands. Thumb opposition now approaches with more abduction to avoid clipping. Thumb-web weight diffusion scales with mesh resolution. Cuffs have real openings; distal sleeves blend toward the wrist and cuffs follow the hand.

The existing AnyCreature cranium seed is retained. The AnyCreature skill influenced connected-part construction and independent visual review. Blender 5.2 CLI performed the actual mesh/rig/export work because no callable Blender MCP connection was available. No plugin execution, historical costume accuracy or full AnyCreature gate pass is claimed.

## Evidence

Final export: 169,508 triangles, 115 mesh objects, 61 bones, seven clips, 5,563,588 bytes. SHA-256: `e25647bd815f8d6eed975dc4dfad8b0f878b31480eda80b51f268f88b2020a94`.

All 631 authored frames passed finite-geometry, loop-endpoint and hand-joint checks. Maximum hand edge stretch is 1.820×. Hand/cane intersections are zero across all 97 cane frames; left-hand self-intersections are zero across all 145 hand-demo frames. Seventy sampled hand/cuff checks pass beyond the intentionally buried wrist region. The sleeve reaches 3.260× edge stretch during a raised-arm transition, above the conservative 3× finish target; this remains an explicit failed quality gate. Technical import and hand tests do not imply production approval.

Current machine-readable evidence lives in `verification.json`, `medieval_update_verification.json`, `medieval_scope_verification.json`, `hand_contact_verification.json`, `hand_mechanics_verification.json`, `palm_orientation_verification.json`, `cuff_clearance_verification.json` and `preview/godot_import_verification.json`. `gate.json` records the final export hash and distinguishes technical checks from unresolved visual quality.

`medieval-before/` preserves the immediately previous compact version. The 49 protected head, tail, trouser, footwear and cane meshes are compared against it. Clothing geometry and required arm/prop animation changes are intentional.

Previews are rendered from the exported GLB. `milo_motion.mp4` shows the six original clips; `milo_hand_mechanics.mp4` shows the dedicated hand test from three views. These are not generated concept images.

## Independent image-only review — verbatim

The reader inspected the revised hero and turnaround before the final hollow-cuff and raised-wrist correction; it did not inspect code, animation or hidden geometry.

> The creature reads clearly as a friendly, elderly cream-colored cat: oversized head, pointed ears, curled tail, white moustache-like muzzle, and round gold spectacles.
>
> The outfit suggests a fantasy scholar or prosperous merchant—teal, gold-trimmed coat over a burgundy doublet/waistcoat, belt, dark trousers, and brown shoes. It feels Renaissance/storybook rather than distinctly medieval.
>
> Hands are recognizable, with visible thumbs and dangling fingers, especially in profile. However, the fingers look soft and partially fused in the frontal views; they are not crisply articulated.
>
> Surfaces are mixed: clothing, glasses, and shoes appear relatively smooth, but the head, muzzle, cheek tufts, and tail are visibly faceted.
>
> Most important visible flaws:
>
> 1. Pronounced polygon facets across the forehead, back of the skull, muzzle, and tail interrupt the otherwise soft character style.
> 2. Finger shapes and joins are lumpy and crowded, weakening hand readability.
> 3. The coat looks rigid and shell-like, with very little cloth folding or tension around the belt and elbows.
>
> The character identity and color design work well; surface consistency is the clearest finish-quality issue.

## Limitations and scope

The latest brief changes hands and clothing, not the face. The earlier reference likeness remains unapproved. Extra hand triangles smooth the surface but do not make every join or curl look anatomically natural. Cloth folds, full-body collision testing, LODs, material consolidation and live-controller retargeting remain outside this pass. The grip is posed, not force-solved. The costume is medieval-inspired fantasy, not a historical reconstruction.

All edits remain in this separate local draft and its preview. No live game assets were overwritten. No Git commit, GitLab push, deployment or external upload was made. Older palm/hand review documents and backups remain historical evidence, not approval of this revision.
