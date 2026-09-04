# Milo — head-to-shoulder connection pass

Local editable candidate, not an approved exact-reference match or production replacement.

## Latest changes

This pass lowers Milo's complete head and hidden articulation hierarchy by 5.5 cm, seating the lower cranium directly into the high medieval collar and shoulder mantle. The visible `Neck_Transition` remains removed; the hidden `neck` and `head` rig bones remain so head turns and all seven existing animation clips continue to work.

The current export has 99 mesh objects, 224,804 triangles, 61 bones and seven clips. Head/cranium and chin contact the collar/throat assembly in all 631 authored frames, with at least 1,281 overlapping triangle pairs per frame. Against the immediate backup, the head meshes and hidden articulation were only translated downward; all 78 non-head meshes and their rig/animation channels remain unchanged.

The outfit, body, paws, tail and cane geometry are unchanged. The eye bones were rebased to the reshaped face; every other rest transform and every non-eye-translation animation channel is unchanged. All seven clips remain available and were re-imported in Godot.

The existing AnyCreature-derived form remains the base, and Blender 5.2 performed this narrow geometry, rig-preservation and render pass. No upload, publication, live-game replacement, Git commit or push occurred.

## Open the result

- `milo_fullres.blend`: editable meshes, vertex colors/materials, 61-bone FK rig, seven baked NLA actions, packed source artwork. Enable one NLA track at a time; tracks are muted in the saved inspection pose.
- `milo_fullres.glb`: self-contained interchange model with the same seven clips and optional cane.
- `Open_Milo_Preview.command`: separate local Godot preview with clip selector, full-body/hand views, orbit, pause and half-speed playback.
- `hero.jpg`, `face.jpg`, `neck_detail.jpg`, `greeting_hand.jpg`, `relaxed_paw.jpg`, `turnaround.jpg`: actual model renders, not generated concept substitutes.
- `milo_motion.mp4`: 21-second exported-model animation preview.
- `milo_hand_mechanics.mp4`: 18-second palm/side/back paw-motion preview.
- `prototype-proportion-before/`: recoverable immediate previous model, sources and key media.
- `visible-neck-before/`: recoverable model, sources and key media immediately before visible-neck removal.
- `shoulder-connected-before/`: recoverable immediate model and media before the 5.5 cm head seating correction.
- `neck-bold-before/`: earlier recoverable neck/moustache baseline.
- `neck-bold-round1/`: first build and its failed collar-intersection report, preserved for comparison.

## Rig and movement

The paws retain three articulated toe chains, three palm rays, and a three-joint opposing digit per side. Toe roots blend into the broad paw cushion. Short, thick toes use shallow distributed curls; they do not replay the former long-finger human hook. No digit scaling or translation is used to fake curl.

Resting palms face the coat, with thumbs forward and hand backs outward. Greeting shows the pads; the cane pose shows the back of the paw.

Clips at 24 fps: Idle (4 s), Walking_A (2 s), Greet (3 s), Guide (3 s), Speak (4 s), Cane_Hold (4 s), and Hand_Mechanics (6 s). This is authored cartoon movement, not motion capture or literal feline anatomy.

Walking is in-place; the preview can add +Z travel at 0.12 m/s. At import scale 1, soles sit approximately 0.012 m above the root. Scale movement speed and ground offset with the model.

## Verification and limitations

Current evidence is in `shoulder_connection_regression_summary.json`, `shoulder_connection_scope_verification.json`, `no_visible_neck_verification.json`, `moustache_verification.json`, `head_style_verification.json`, `verification.json`, `hand_contact_verification.json`, and `gate.json`. Check the export hash before treating any report as current. Earlier review documents are historical, not acceptance evidence for this revision.

Checks cover exported skin weights/topology, 631 authored animation frames, hinge coupling, palm orientation, sampled cuff clearance, face/blink regression, protected geometry/materials/motion, and Godot import. Numeric checks are not proof of exact likeness or arbitrary-pose collision freedom.

The cane grip remains unfinished: not every toe pad meets the 3 mm contact-clearance target. `gate.json` deliberately records failures; do not describe this candidate as fully quality-approved. The existing raised-arm sleeve deformation also remains outside this neck/moustache edit.

The all-clip self-contact check also finds a small local palm fold during the Hand_Mechanics opposition pose (22 of 1,262 hand/frame samples, up to three triangle-pair overlaps). It is not an explosion, but it is a real failed check and is not hidden or waived.

Godot's imported paw material initially left vertex colors disabled despite retaining the GLB COLOR_0 arrays. The preview's `milo_paw_import.gd` post-import script enables them on the two paw materials; the import test checks that they remain active. Carry that import setting forward if integrating this asset into Godot.

All 78 protected body/outfit/paw/tail/cane meshes, including materials, vertex attributes and skinning, are unchanged against the immediate backup. The 59 non-eye bones and their inverse-bind matrices are unchanged; only the two eye rest placements and their exported translation channels were rebased to the reshaped face. No paws, cane placement or digit poses were refitted.

Other limitations remain: eye-squash blink rather than modeled eyelids; no audio lip-sync, cloth simulation, production LOD, cane walk, or map/tablet animation. The model remains dense and needs draw-call/LOD work before integration.

The game currently uses a different 41-bone rig and runtime arm/cane overrides. This 61-bone asset is not a drop-in replacement. No live game assets, scripts or scenes were overwritten.

## Rebuild and test

```sh
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --threads 4 --python-exit-code 1 --python /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/build.py -- --rig
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --threads 4 --python-exit-code 1 --python /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/verify_prototype_proportion.py
rtk proxy /usr/bin/python3 /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/check_prototype_proportion_scope.py
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --threads 4 --python-exit-code 1 --python /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/render_neck_bold_delivery.py
```

Copy a rebuilt GLB into the separate preview project and rerun Godot import before viewing. Re-render media after every model change.

No Git commit, push, deployment or external upload was made.
