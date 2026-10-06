# Milo — cat paws and DOCX cheek tufts

Local editable candidate, not an approved exact-reference match or production replacement.

## Latest changes

Rounded feline paws with short grouped toes, an arched digit silhouette, a small opposing digit, and muted central/digital paw pads. Pads are part of the same skinned surface, with softly blended vertex color rather than separate floating pieces.

The central moustache has fuller inner lobes and thinner raised tips. Two unequal, angled cream cheek tufts on each side replace the long feather-like extensions. Their roots are buried in the skull and weighted to the head.

The original DOCX image was inspected directly and verified byte-identical to `../docx-source/word/media/image7.png`. The pads are an intentional feline-style addition, not a detail claimed to be clearly visible in that reference. See `CAT_PAW_DOCX_REVIEW.md` for actual image-review verdicts and deviations.

The pre-existing AnyCreature cranium seed is retained. AnyCreature's connected-shape and independent-review guidance informed the revision; Blender 5.2 performed the geometry and rig work. No callable Blender/AnyCreature MCP tools were available, so local Blender CLI was used. No plugin installation, new AnyCreature compile, upload or publication occurred.

## Open the result

- `milo_fullres.blend`: editable meshes, vertex colors/materials, 61-bone FK rig, seven baked NLA actions, packed source artwork. Enable one NLA track at a time; tracks are muted in the saved inspection pose.
- `milo_fullres.glb`: self-contained interchange model with the same seven clips and optional cane.
- `Open_Milo_Preview.command`: separate local Godot preview with clip selector, full-body/hand views, orbit, pause and half-speed playback.
- `hero.jpg`, `face.jpg`, `greeting_hand.jpg`, `relaxed_paw.jpg`, `turnaround.jpg`: actual model renders, not generated concept substitutes.
- `milo_motion.mp4`: 21-second exported-model animation preview.
- `milo_hand_mechanics.mp4`: 18-second palm/side/back paw-motion preview.
- `cat-paw-docx-before/`: recoverable previous model, source, reports and media.

## Rig and movement

The paws retain three articulated toe chains, three palm rays, and a three-joint opposing digit per side. Toe roots blend into the broad paw cushion. Short, thick toes use shallow distributed curls; they do not replay the former long-finger human hook. No digit scaling or translation is used to fake curl.

Resting palms face the coat, with thumbs forward and hand backs outward. Greeting shows the pads; the cane pose shows the back of the paw.

Clips at 24 fps: Idle (4 s), Walking_A (2 s), Greet (3 s), Guide (3 s), Speak (4 s), Cane_Hold (4 s), and Hand_Mechanics (6 s). This is authored cartoon movement, not motion capture or literal feline anatomy.

Walking is in-place; the preview can add +Z travel at 0.12 m/s. At import scale 1, soles sit approximately 0.012 m above the root. Scale movement speed and ground offset with the model.

## Verification and limitations

Current evidence is in `cat_regression_summary.json`, `cat_paw_verification.json`, `cat_paw_scope_verification.json`, `verification.json`, `hand_contact_verification.json`, and `gate.json`. Check the export hash before treating any report as current. Earlier COMPACT_PAW, PALM_WHISKER, HEAD_STYLE and MEDIEVAL review documents are historical, not acceptance evidence for this revision.

Checks cover exported skin weights/topology, 631 authored animation frames, hinge coupling, palm orientation, sampled cuff clearance, face/blink regression, protected geometry/materials/motion, and Godot import. Numeric checks are not proof of exact likeness or arbitrary-pose collision freedom.

The cane grip remains unfinished: not every toe pad meets the 3 mm contact-clearance target. `gate.json` deliberately records failures; do not describe this candidate as fully quality-approved. The existing raised-arm sleeve deformation also remains outside this paw/tuft edit.

The all-clip self-contact check also finds a small local palm fold during the Hand_Mechanics opposition pose (22 of 1,262 hand/frame samples, up to three triangle-pair overlaps). It is not an explosion, but it is a real failed check and is not hidden or waived.

Godot's imported paw material initially left vertex colors disabled despite retaining the GLB COLOR_0 arrays. The preview's `milo_paw_import.gd` post-import script enables them on the two paw materials; the import test checks that they remain active. Carry that import setting forward if integrating this asset into Godot.

The skull, eyes, ears, glasses, outfit, boots, tail and cane geometry are protected. Body/wrist/face animation is preserved; digit rest positions and poses and cane placement are intentionally refitted.

Other limitations remain: eye-squash blink rather than modeled eyelids; no audio lip-sync, cloth simulation, production LOD, cane walk, or map/tablet animation. The model remains dense and needs draw-call/LOD work before integration.

The game currently uses a different 41-bone rig and runtime arm/cane overrides. This 61-bone asset is not a drop-in replacement. No live game assets, scripts or scenes were overwritten.

## Rebuild and test

```sh
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --threads 4 --python-exit-code 1 --python /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/build.py -- --rig
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --threads 4 --python-exit-code 1 --python /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/verify_cat_delivery.py
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --threads 4 --python-exit-code 1 --python /Users/davidsovann/S2603/milo-cast-redesign/fullres-rigged/render_head_delivery.py
```

Copy a rebuilt GLB into the separate preview project and rerun Godot import before viewing. Re-render media after every model change.

No Git commit, push, deployment or external upload was made.
