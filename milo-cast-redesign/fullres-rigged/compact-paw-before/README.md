# Milo — full-resolution rigged local draft

**Status: implementation draft, not an approved reference match or production replacement.**

Latest revision: tapered palms with flatter backs, a more defined thumb cushion and a rounded heel; broad swept white moustache ends blend into compact three-tip cheek-fur fans. The lower palm is about 19% narrower on the little-finger side and the central palm about 19% thinner. Hand length, finger-joint spacing, all 61 bone rest transforms and all seven baked animations are unchanged. See `PALM_WHISKER_REVIEW.md`; `palm-whisker-before/` preserves the immediately previous model, sources and previews.

The previous enlarged hand proportions, smooth fingers, dark oval cast-style eyes, gold glasses and medieval-inspired fantasy court coat/burgundy doublet are retained. All 92 meshes and materials outside the palms, moustache and local cheek skin compare unchanged against the immediate backup. Earlier head and outfit development is documented in `HEAD_STYLE_REVIEW.md` and `MEDIEVAL_REVIEW.md`; those reviews are historical, not new approvals of this revision.

The identity reference remains the original 1536 x 1024 image extracted unchanged from the user's DOCX at `../docx-source/word/media/image7.png`. The user's newer request to match the game's eye style takes precedence over the reference's amber irises. This revision retains the previously compiled AnyCreature cranium seed and uses its connected-shape and independent-review guidance. Blender sculpted the palm and cheek/moustache geometry. No callable Blender MCP/plugin tools were available, so Blender 5.2 CLI was used explicitly as a fallback. Nothing was installed or published.

## Deliverables

- `milo_fullres.blend`: editable meshes, named materials, 61-bone FK rig, seven baked NLA actions, packed source artwork. Enable one NLA track at a time to preview it; tracks are muted in the saved inspection pose.
- `milo_fullres.glb`: self-contained game interchange asset, with all seven animations and an optional cane.
- `milo_hand_mechanics.mp4`: 18-second close-up showing the six-second open–curl–opposition–release test from palm, side and back, rendered from the actual exported model.
- `milo_motion.mp4`: 21-second render of the exported GLB, not a generated concept image. Order: idle, two walk cycles, greet, guide, speak, cane hold.
- `Open_Milo_Preview.command`: opens the separate Godot preview on this Mac.
- `preview/project.godot`: local compatibility-renderer preview with clip selection, hand close-up/full-body toggle, pause, half speed, orbit, zoom and optional ground travel.
- `pose_*.jpg`, `relaxed_paw.jpg`, `greeting_hand.jpg`, `cane_grip.jpg`, `cane_grip_inside.jpg`, `turnaround.jpg`: current posed and relaxed-Idle renders of the exported asset.
- `cast_eye_comparison.jpg`: actual Rogue and Fox assets alongside the immediately previous and revised Milo, rendered in the same light at approximately equal head width. This is a face-style comparison, not a body-scale comparison.
- `face.jpg`, `face_open.jpg`, `face_closing.jpg`, `face_blink.jpg`, `face_reopened.jpg`: actual exported face and blink renders.
- `PALM_WHISKER_REVIEW.md`, `palm_whisker_verification.json`, `palm_whisker_scope_verification.json`: current changes, actual independent visual verdicts, measurements and preservation checks. Earlier review documents remain historical, not current acceptance evidence. Head/blink regression checks are refreshed in `head_style_verification.json`.
- `verification.json`, `gate.json`, `REVIEW.md`: measured results and unresolved quality findings.

## Rig and motion

The rig has root, hips, spine, chest, neck, head, jaw, two eye controls, brows and ears; two complete arm/hand chains with three articulated palm rays, three three-joint fingers and a three-joint thumb each; legs and feet; two coat controls; three tail joints; and one cane bone. Base knuckles flex/spread, middle/end finger joints act as hinges, and thumb opposition begins at its own base. The GLB contains baked transforms, not Blender-only IK constraints. This is human-inspired kinematics adapted to a cartoon silhouette, not literal human anatomy or motion capture.

| Clip | Duration | Authored movement |
| --- | ---: | --- |
| Idle | 4 s | Low-amplitude breathing, head balance, tail sway and a blink |
| Walking_A | 2 s | Alternating fixed-length leg solving, flat stance feet, eased swing lift, torso weight transfer and counter-swinging arms |
| Greet | 3 s | Raised hand with palm-plane control, eased return to rest |
| Guide | 3 s | Outward presenting/pointing arm arc and head turn |
| Speak | 4 s | Paired hand gestures, small jaw motion and head movement |
| Cane_Hold | 4 s | Separate cane, reachable wrist, three-joint finger curls, fitted thumb and accessory placement |
| Hand_Mechanics | 6 s | Held wrist; open, relaxed, hook curl, modest thumb opposition and release |

Actions use 24 fps. The video samples at 12 fps. Walking is in-place: the preview optionally supplies +Z travel at 0.12 m/s to match the stance trajectory. At import scale 1, the sole is approximately 0.012 m above the model root; a live controller must account for that ground offset. Scale speed and offset together if the character is resized.

## Verification performed

- Reimported the final GLB into Blender, checked all 631 authored animation frames for finite geometry, edge stretch, foot minima and loop endpoints. Exported finger hinge/coupling and no-scaling/no-translation checks pass.
- Verified every exported mesh has normalized skin weights and the file has no external buffers or images.
- Both paws are connected, closed meshes with authored joint-loop weights and smooth thumb-web transitions. Each has one connected component and zero nonmanifold edges. All-frame maximum hand stretch remains below the conservative 3x limit; see `verification.json` for the measured value. This measures deformation stability, not biological realism.
- Sculpted a shallow palm cup, integrated thumb heel, subtle dorsal knuckles and broad flexion folds into the connected skin. Finger lengths, thicknesses and relaxed curls now vary by digit; thumbs oppose gently rather than hanging straight. No pink pads, claws or detached detail primitives were added.
- Corrected the anatomical convention: local +Z is the palm, positive X finger curl bends into it. Resting palms turn toward the coat, thumbs forward, with backs outward. The wave presents the palm; the cane pose presents the back. Exported orientation assertions are recorded in `palm_orientation_verification.json`.
- Hand/cane surface tests find zero intersecting triangle pairs in all 97 authored frames of Cane_Hold. Palmar fingertip-pad clearances at frame zero are 1.4–1.9 mm, including 1.4 mm at the thumb. The hold is not force-solved. The left hand has zero detected self-intersections across all 145 Hand_Mechanics frames; these checks are not a full-character or arbitrary-pose collision guarantee.
- Compared all 92 protected meshes, including eyes, glasses, clothing, tail, footwear and cane, with `palm-whisker-before/`: triangle geometry is unchanged within 0.0000001 m; their materials and every baked animation channel are unchanged. All 61 bone rest matrices are unchanged. The skull, eyes and each joined moustache/cheek fan reimport as closed connected meshes. Moustache roots are intentionally buried into the cheeks, not floating off the face. Seven clips retain the existing blink.
- Imported the GLB in Godot 4.7.1's compatibility renderer; all seven named clips load and pass transform checks. The dedicated hand test produces 72.94 degrees of finger-hinge motion with less than 0.001 m sampled wrist movement. Durations are 4, 2, 3, 3, 4, 4 and 6 seconds.
- Opened the real local Godot preview, exercised each clip and captured `godot_preview.png`.

## Remaining limitations — do not conceal these

- Historical exact-reference likeness was rated **moderate, not close**. This head revision deliberately follows the user's newer game-style eye request, rather than preserving the reference's amber irises.
- The current image-only review finds meaningful improvement in palm contour and moustache continuity, not a finished or exact-reference match. Remaining visible concerns include blunt palm corners, soft tubular fingers, angular wrist/cuff transitions, finger banding, pinched web shading and a faceted tail. The side moustache reads as stylized cheek fur/muttonchops, not individual whisker strands. See `PALM_WHISKER_REVIEW.md` for the actual verdicts.
- Earlier style concerns remain: smoother head and more regular eyes than the cast, Renaissance/storybook rather than distinctly medieval clothing, and a stiff shell-like coat. More triangles do not by themselves resolve every sculpting or style problem.
- Raised-arm sleeve stretch is measured across every authored frame in `verification.json`. All-frame finite-geometry and ground tests do not prove absence of full-character intersections.
- Blink is eye-bone compression, not a complete eyelid rig; Speak is not audio lip-sync. No cloth simulation, facial expressions library, cane walk, map/tablet animation or production LOD was implemented.
- The asset is dense: 190,332 triangles and 97 mesh objects, including 112,640 triangles across the two hands. Material/draw-call consolidation and LOD work remain before game integration.
- The existing game uses a different 41-bone rig plus runtime arm/cane overrides. This 61-bone asset is **not a drop-in replacement**. No live game assets, controllers or scenes were overwritten.

No Git commit, GitLab push, deployment or external upload was made.

## Rebuild locally

```sh
rtk proxy python3 /Users/davidsovann/.codex/plugins/cache/personal/anycreature/1.2.0+codex.local.20260828/scripts/anycreature.py compile /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/head_spec.json /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/head_seed.glb
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --threads 4 --python-exit-code 1 --python /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/build.py -- --rig
rtk proxy python3 /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/check_palm_whisker_scope.py
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --threads 4 --python-exit-code 1 --python /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/verify_palm_whisker_delivery.py
```

Copy the rebuilt GLB to `preview/milo_fullres.glb` and run Godot's import before rechecking the preview. Re-render previews whenever the source changes; do not use older images as evidence of a newer export.
