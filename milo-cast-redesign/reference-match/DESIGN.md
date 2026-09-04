# Milo — supplied character-sheet target

The two images attached by the user on 2026-08-28 are the visual target. Image 2 is the main front/three-quarter/side/back proportion reference. Image 1 supplies the face detail, cane and outfit accents. This is a new target, superseding the statue-only interpretation and the rejected natural-face-grip draft.

## Visual features to match

- Warm cream/taupe cat, with deliberately broad low-poly planes rather than a uniformly smooth sphere. The ear-to-chin region is approximately half the total height in the front reference; use this as a measured comparison target, not an exact orthographic specification.
- Wide cheeks, a short jaw and almost no exposed neck. Triangular ears with thick rims and pink-brown inner bowls. Subtle taupe forehead markings and a lighter central forehead shape.
- Large amber/brown eyes and round gold spectacles fitted closely to the face. No blue irises, raccoon-like orange eye masks, oversized floating spectacle rings or small bead eyes in empty rings.
- Ivory raised brows; small peach nose; connected white muzzle with a swept, layered two-sided moustache. Three small cheek-fur tiers on each side. The moustache must grow from the muzzle and taper into the cheeks, not look like two separate bananas.
- Compact ivory paws with a thumb and shallow finger separations; relaxed hands hang naturally beneath the cuffs. No angular boxes, oversized fists, long dangling fingers or dark human-like hands.
- Charcoal-navy open coat, comparatively straight sleeves, thin gold hem/cuff edging, fine muted-teal lapel piping, purple single-breasted waistcoat and small gold buttons. Ivory shirt collar and purple neckwear with a small gold accent. Small teal/green insignia on the left lapel. A back waist tab with two gold buttons.
- Short dark-brown trousers and rounded brown boots, not black block shoes.
- Thick curved cream/taupe tail behind the coat, with soft bands and a rounded pale end. Eliminate the current angular stalk and ball tip.
- Slender brown walking cane with a gold crook handle and ferrule. Keep the handle visible and shape the grip around it; avoid a shaft emerging inexplicably from a solid fist.

## Scope and acceptance

Build a separate local Blender/GLB review variant. Preserve prior drafts. Do not replace game assets, commit, push, publish or deploy. Text labels on the image are reference content, not independent authorization to alter cloth simulation, combat hitboxes or any game system. The small pose/prop panels are secondary references, not proof that those animations or props have been implemented.

Use AnyCreature for an editable shaped seed where appropriate and the available Blender executable for fitted anatomy, wardrobe, rig attachment and render verification. A connected Blender plugin tool is not currently available. Inspect front, three-quarter, side and back together before declaring likeness. Test close-up facial attachment, relaxed paws and held cane separately. Check the exported model, not just the editable scene. Structural success does not establish artistic likeness.

## Current status

A separate local model now exists as `milo_reference.blend` and the self-contained `milo_reference.glb`. Front, three-quarter, side, back, face and paw images are renders of the exported GLB, not generated concept art. Prior redesign folders remain untouched.

An AnyCreature head study was compiled and inspected. After the first spherical-head construction and two repair rounds still failed likeness review, the head was reconstructed in Blender using broad crown, temple, cheek and jaw planes. The retained study is `head_spec.json`/`head_seed.glb`; the rejected construction script is `head_round_draft.py`. The study compiler warned about a steep crown slope, so its output is not presented as a deformation-certified head. The final planar skull is reconstructed Blender geometry and rigidly weighted to the original head bone.

The body is 18% shorter and the arm stance narrower. Amber eyes, round gold spectacles, a raised compact muzzle, ivory brows, layered white cheek fur, navy/gold coat, purple single-breasted waistcoat, teal lapel piping, compact ivory paws, rear waist strap, brown boots and a lowered curved striped tail replace the preceding appearance. The canonical model is without a cane, matching the supplied four-view image; no new cane grip or secondary prop set is claimed.

The 41-bone hierarchy and the four existing body-action channel sets (Idle, Walking_A, Guide, Speak) are retained. The rig's X/Z proportions have changed, so retained channels are not a claim of identical world-space trajectories or newly authored animations. Export checks pass for self-containment, finite vertices, valid indices, normalized weights, joint indices and preservation of those four channel sets. See `verification.json` for the actual measured counts. No Godot/gameplay test, facial/finger rig, cloth simulation, combat implementation or full AnyCreature certification is claimed.

Independent reviews correctly rejected earlier likeness drafts. See `REVIEW.md` for the actual verdicts and remaining limitations. Artistic likeness must be assessed separately from structural export success. This remains a local review variant until the user approves its appearance; nothing is committed, pushed, published, deployed or installed into the game.
