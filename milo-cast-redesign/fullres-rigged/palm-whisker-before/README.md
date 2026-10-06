# Milo — full-resolution rigged local draft

**Status: implementation draft, not an approved reference match or production replacement.**

Latest revision: Milo's eyes now use the simple dark oval treatment found in the actual Rogue/Mage/Barbarian/Fox game assets. The head has a rounder crown, broad chubby jaw, compact connected cheek tufts, shorter ears, a smaller smooth moustache and lighter, closer-fitting gold spectacles. See `HEAD_STYLE_REVIEW.md`; `head-style-before/` preserves the immediately previous model, sources and previews.

The previous doubled palms, smooth fingers and medieval-inspired fantasy court coat/burgundy doublet are preserved. All 78 non-head meshes and materials, plus every non-eye animation channel, compare unchanged against that backup. Earlier hand/outfit development is documented in `MEDIEVAL_REVIEW.md` and `medieval-before/`.

The identity reference remains the original 1536 x 1024 image extracted unchanged from the user's DOCX at `../docx-source/word/media/image7.png`. The user's newer request to match the game's eye style takes precedence over the reference's amber irises. AnyCreature compiled the revised cranium profile; Blender shaped and joined the cheeks, refined the features and retargeted the two eye pivots. The Blender MCP/plugin connection was unavailable, so Blender 5.2 CLI was used explicitly as a fallback. Nothing was installed or published.

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
- `HEAD_STYLE_REVIEW.md`, `head_style_verification.json`, `head_scope_verification.json`: current changes, independent visual review and checks. Earlier review documents remain historical, not current acceptance evidence.
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
- Both paws are connected, closed meshes with authored joint-loop weights and smooth thumb-web transitions. Each has one connected component and zero nonmanifold edges. All-frame maximum hand stretch is 1.820x, below the conservative 3x limit; this measures deformation stability, not biological realism.
- Sculpted a shallow palm cup, integrated thumb heel, subtle dorsal knuckles and broad flexion folds into the connected skin. Finger lengths, thicknesses and relaxed curls now vary by digit; thumbs oppose gently rather than hanging straight. No pink pads, claws or detached detail primitives were added.
- Corrected the anatomical convention: local +Z is the palm, positive X finger curl bends into it. Resting palms turn toward the coat, thumbs forward, with backs outward. The wave presents the palm; the cane pose presents the back. Exported orientation assertions are recorded in `palm_orientation_verification.json`.
- Hand/cane surface tests find zero intersecting triangle pairs in all 97 authored frames of Cane_Hold. Palmar fingertip-pad clearances at frame zero are 1.4–1.9 mm, including 1.4 mm at the thumb. The hold is not force-solved. The left hand has zero detected self-intersections across all 145 Hand_Mechanics frames; these checks are not a full-character or arbitrary-pose collision guarantee.
- Compared all 78 non-head meshes, including both hands, clothing, tail, footwear and cane, with `head-style-before/`: triangle geometry is unchanged within 0.0000001 m; material definitions and all non-eye animation channels are unchanged. The skull and both eyes each reimport as one closed connected mesh with zero nonmanifold edges. Seven clips retain a working blink; the two eye pivots now follow the revised eye centers.
- Imported the GLB in Godot 4.7.1's compatibility renderer; all seven named clips load and pass transform checks. The dedicated hand test produces 72.94 degrees of finger-hinge motion with less than 0.001 m sampled wrist movement. Durations are 4, 2, 3, 3, 4, 4 and 6 seconds.
- Opened the real local Godot preview, exercised each clip and captured `godot_preview.png`.

## Remaining limitations — do not conceal these

- Historical exact-reference likeness was rated **moderate, not close**. This head revision deliberately follows the user's newer game-style eye request, rather than preserving the reference's amber irises.
- The current image-only review identifies a kindly older cat and finds the eyes closer to the cast. It does not establish an exact style match: Milo has more regular oval eyes, lighter brows and a smoother head than the other characters. See the review for the actual verdict and finishing-pass notes.
- Earlier outfit/hand concerns remain outside this head-only revision: Renaissance/storybook rather than distinctly medieval clothing, crowded finger joins, a stiff shell-like coat and a faceted tail. More triangles do not by themselves resolve every sculpting or style problem.
- Raised-arm sleeve stretch is measured across every authored frame in `verification.json`. All-frame finite-geometry and ground tests do not prove absence of full-character intersections.
- Blink is eye-bone compression, not a complete eyelid rig; Speak is not audio lip-sync. No cloth simulation, facial expressions library, cane walk, map/tablet animation or production LOD was implemented.
- The asset is dense: 179,124 triangles and 97 mesh objects, including 112,640 triangles across the two hands. Material/draw-call consolidation and LOD work remain before game integration.
- The existing game uses a different 41-bone rig plus runtime arm/cane overrides. This 61-bone asset is **not a drop-in replacement**. No live game assets, controllers or scenes were overwritten.

No Git commit, GitLab push, deployment or external upload was made.

## Rebuild locally

```sh
rtk proxy python3 /Users/davidsovann/.codex/plugins/cache/personal/anycreature/1.2.0+codex.local.20260828/scripts/anycreature.py compile /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/head_spec.json /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/head_seed.glb
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --threads 4 --python-exit-code 1 --python /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/build.py -- --rig
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --threads 4 --python-exit-code 1 --python /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/verify.py
```

Copy the rebuilt GLB to `preview/milo_fullres.glb` and run Godot's import before rechecking the preview. Re-render previews whenever the source changes; do not use older images as evidence of a newer export.
