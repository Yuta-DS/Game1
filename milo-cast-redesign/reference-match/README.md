# Milo — local reference-model draft

The visual target is the user's supplied four-view cat-scholar reference, saved as `reference-turnaround.png`. The broader sheet is `reference-sheet.png`.

## Open these files

- `turnaround.jpg`: actual exported-model front, three-quarter, side and back renders.
- `face.jpg` and `paws.jpg`: close-up renders.
- `milo_reference.blend`: editable local Blender model and original rig/actions.
- `milo_reference.glb`: self-contained skinned model with Idle, Walking_A, Guide and Speak.
- `milo_reference_motion.mp4`: 24-fps, 232-frame preview of excerpts from those existing body clips.
- `REVIEW.md`: actual independent likeness verdicts, structural checks and limitations.

The reference's compact proportions, raised muzzle, cream/taupe head, amber eyes, round gold glasses, navy/gold coat, purple waistcoat, teal lapels, ivory paws, rear waist strap, brown boots and low curved tail have been rebuilt. This is an appearance-review draft, not an exact-match or animation-production-ready certification. The original four body clips are retained, not newly authored. The canonical model intentionally has no cane, matching the main four-view reference.

AnyCreature was used for the initial editable head study. The final silhouette and fitted details were reconstructed in Blender after image-only review rejected the spherical construction. Blender CLI was used because no connected Blender plugin tool was available. No external service upload, runtime installation or publication was performed.

## Reproduce locally

Run one Blender process at a time; the machine is low on disk space. These scripts write only this review folder. `build_model.py` reads the preserved `../luxury-coat/milo_luxury_coat.blend` as its rig/action source, then constructs replacement meshes in memory. It never overwrites that source or any game asset.

```sh
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python /Users/davidsovann/S2603/milo-cast-redesign/reference-match/build_model.py
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python /Users/davidsovann/S2603/milo-cast-redesign/reference-match/render_review.py
rtk proxy python3 /Users/davidsovann/S2603/milo-cast-redesign/reference-match/verify_export.py
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python /Users/davidsovann/S2603/milo-cast-redesign/reference-match/render_motion.py
```

No Git commit, push, deployment or live game replacement has been performed. Prior redesign folders remain available.
