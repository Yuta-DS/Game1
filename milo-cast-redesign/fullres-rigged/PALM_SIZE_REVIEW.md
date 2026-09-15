# Palm size fit — 2026-08-28

Requested change: make the palm size fit Milo. This is a local hand-proportion revision, not a full character redesign or live-game replacement.

## Result

- Palm length at the middle knuckle: 79.39 → 63.74 mm, a 19.7% reduction.
- Knuckle span: 66.00 → 58.67 mm, an 11.1% reduction. Whole-hand width also reduces 11.1%.
- Wrist-to-fingertip extent: 153.55 → 131.36 mm, a 14.5% reduction. Fingers and thumb were reduced with the palm, retaining the existing joint layout.
- Wrist bone positions are unchanged. The buried wrist socket keeps its original dimensions, blending smoothly into the narrower/thinner palm. Face, clothes, cuff geometry, body and all other non-hand meshes are unchanged.
- Size changes are in the rest mesh and joint positions, not animated bone scaling. All 61 bones and seven clips remain. The cane was refitted through bounded joint angles and a small placement adjustment.

AnyCreature's silhouette/proportion and connected-part guidance informed the edit and independent image-only review. Blender 5.2 CLI performed the actual model edits, rigging, export and renders; no callable Blender plugin connection was available.

## Verification

Current GLB SHA-256: `388cbbf04eff2c7bc9ab6cc10f0b7ddb1d2a39a25add0f28cd78afc301ccf445`.
2,750,420 bytes; 67,486 triangles; 102 meshes; 61 bones; seven clips.

- `verify_palm_size.py`: bilateral dimensional reduction and unchanged wrist-position assertions pass against `palm-size-before/milo_fullres.glb`.
- `verify.py`: all 631 authored frames have finite geometry, normalized skin weights and matching loop endpoints. Both hands are connected closed meshes. Maximum hand edge stretch is 1.806514x; maximum whole-character stretch remains 2.741572x on a sleeve.
- `verify_hand_contacts.py`: zero detected left-hand self-intersections across all 145 mechanics-demo frames and zero right-hand self-intersections at Cane_Hold frame zero. Palmar distal-pad clearances at that cane frame are 1.286, 1.811, 1.704 and 1.496 mm.
- All 97 authored Cane_Hold frames have zero detected hand/cane triangle intersections. Near-contact is not a pressure/contact-force simulation or a guarantee for arbitrary poses.
- `verify_hand_mechanics.py` and `verify_palm_orientation.py`: finger hinge/coupling, joint-range, no digit scaling/translation, inward resting palms and greeting/cane orientation checks pass.
- `check_hand_scope.py`: all 100 non-hand mesh triangle geometries are unchanged within 0.0000001 m.
- Godot 4.7.1: seven clips import, finite-transform and finger-motion checks pass, and the real compatibility-renderer preview captures successfully.

## Visual review and previews

Primary review of the actual full-character, relaxed-hand, greeting, hook-curl and inside-cane renders: the smaller hand sits more compactly beneath the unchanged cuff; individual fingers remain readable and the wrist connection shows no visible gap. The smooth mitten-like surface and simplified thumb clamp remain stylized, not fully realistic. The independent image-only proportion reader did not return a verdict and was stopped; that independent gate remains unverified.

Current full-body and close-up handoff images are `milo_palm_fit_full.jpg` and `milo_palm_fit_closeup.jpg`. Both motion videos were regenerated from the resized GLB and checked: `milo_hand_mechanics.mp4` is 18 seconds/216 frames and `milo_motion.mp4` is 21 seconds/252 frames. The Godot capture now explicitly settles Idle before saving its full-body image, avoiding a leftover crossfade pose under the Idle label.

## Recovery and scope

`palm-size-before/` preserves the pre-resize Blender file, GLB, hand source, grip settings, key renders and verification records. Earlier backups remain intact. A disk-full error occurred before the initial edit; the intact source was checked and 468 regenerable JPEG video frames (about 15 MB) were removed. Models, final videos and user data were not removed. Video rendering now supports `--stream`, using one temporary frame instead of keeping a frame cache.

This proportion change does not establish full reference likeness, a production-ready realistic thumb clamp, or a complete AnyCreature quality-gate pass. Historical naturalness and likeness reviews are preserved separately. Nothing was committed, pushed, uploaded or changed in the live game.
