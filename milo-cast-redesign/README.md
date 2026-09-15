# Milo — cast-matched local redesign

Start with `lineup.png`: Milo is the center character, beside actual Rogue, Mage, Barbarian and Fox assets. This comparison uses neutral Blender lighting, not a Godot screenshot. `hero.png` and `face.png` show the new design closely.

## Deliverables

- `milo_cast.blend`: editable Blender 5.2 model, 41-bone cast skeleton and baked animation actions.
- `milo_cast.glb`: self-contained skinned export, 6 mesh objects, 4,692 triangles, 15 material primitives, 537,008 bytes.
- `motion.mp4`: consecutive exported-model frames at 24 fps. Idle 0–3 s; two walk loops 3–5.667 s; Guide 5.667–8.667 s; Speak 8.667–11.667 s.
- `DESIGN.md`: code trace, actual references and visual design decisions.
- `glb_validation.json`, `motion_validation.json`: performed checks, not a production certification.

## What changed

The rejected studio-style face and long-legged body are replaced with the game's chunky cast proportions, small dark eyes, broad matte colors and slightly chubby feline cheeks. AnyCreature generated the new head; Blender integrates it with the existing Rogue body/skin weights and native 41-bone skeleton. Milo keeps his spectacles, white moustache, scarf and cane.

Movement retains the cast walk, slowed to a 1.333-second cycle, with a stabilized cane arm. Idle and Speak are exact 3-second loops. Guide is a restrained 3-second gesture. These are body animations, not phoneme lip-sync or a facial expression rig.

## Verification and limitations

- Independent image-only review: **style fit PASS**. Cat/elder-scholar identity and chubby face read clearly. Reviewer noted that the muzzle reads like a large moustache; optional polish was softer muzzle facets and slightly thicker glasses at gameplay scale.
- GLB structure, finite geometry, normalized weights, expected actions and loop endpoints pass.
- 25 samples per exported clip show no invalid skinning. The walk has up to about 4.2 mm of interpolated boot-floor penetration; the cane is carried slightly above the floor, not procedurally planted on terrain.
- No browser viewer or Godot gameplay integration was verified. Runtime movement speed, terrain contact and transitions still require an in-game pass.
- The AnyCreature spec is a **head-only isolation build**, not a whole-creature/attack certification.
- The disk reached its write limit during final minor refinement. The validated model and full video remain intact; no claim is made that the optional last refinements were applied.

## Local only

No game asset replacements, commits, pushes or deployment were performed. Existing dirty files under `artea/` were preserved. The current live Milo still uses `milo_exact_target_parts.glb`; this is a review candidate, not a drop-in replacement for the existing part-name-driven controller.

Preserve the original project asset licensing for the reused Rogue body and animation data; no new CC0 or publishing claim is made.

## Rebuild

Use the installed AnyCreature dispatcher to compile `head_spec.json` to `head_seed.glb`. Run `build_cast_milo.py`, then `polish_animation.py` with Blender in background mode. Run `validate_glb.py` with host Python and `check_motion.py` with Blender. `render_review.py -- lineup`, `-- face`, and `render_motion.py` produce the previews. All scripts write only in this folder. Follow the workspace's `rtk` command prefix.
