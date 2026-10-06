# Milo — gold-trimmed medieval-classic coat

Separate local wardrobe variant. The previous Milo model and all live game assets remain unchanged. No commit, push, upload or deployment.

## Outfit

- Long midnight-navy coat with a flared, open hem and notched blue lapels.
- Burgundy double-breasted waistcoat and ivory cravat with a gold brooch.
- Antique-gold borders on the lapels, front opening, hem, cuffs and pockets.
- Small heraldic leaf motifs, gold buttons and a short pocket chain.
- Matching dark trousers and espresso-colored shoes.

This is a fantasy blend of medieval court dress and classic tailoring, not a historically exact reconstruction. Broad color areas and simple geometry retain the game's chunky low-poly style. AnyCreature's part-readability guidance informed the restrained detail; the existing AnyCreature head is reused unchanged. Clothing was modeled and skinned in Blender.

## Files

- `hero.jpg`: close three-quarter view of the exported model.
- `lineup.jpg`: actual game cast under the same neutral Blender lighting, with Milo in the center.
- `milo_luxury_coat.blend`: editable Blender 5.2 scene, new skinned wardrobe and original actions.
- `milo_luxury_coat.glb`: self-contained export, 640,732 bytes, 6 meshes, 6,372 triangles, 41 bones.
- `outfit_motion.mp4`: 9.667-second preview: idle 0–1 s, two walk cycles 1–3.667 s, Guide 3.667–6.667 s, Speak 6.667–9.667 s.
- `verification.json`, `motion_check.json`: performed checks and limitations.

## Verification

The new GLB passes finite-geometry, normalized skin-weight and bone-index checks. Comparison against the previous GLB confirms that the face/identity geometry and all four animation tracks are unchanged. Loop endpoints remain exact. The costume was evaluated and rendered over 232 consecutive animation frames, then representative walk and gesture frames were visually inspected.

Independent image-only review: **PASS** for luxurious tailored-fantasy clothing and cast-style fit. No obvious detached clothing or broken geometry was seen in the front views. Caveat: the finer gold piping and buttons are denser than the surrounding cast's details and lose definition at lineup scale. This review did not certify animation.

This is skin-driven clothing, not cloth simulation. There is no new facial animation, terrain-aware cane contact, or Godot integration in this change. Existing movement limitations remain. This is not a full AnyCreature creature/combat certification.

## Reproduce

Run `dress_milo.py` with the installed Blender executable in background mode. It loads the parent folder's `milo_cast.blend` and writes only this variant folder. Run `verify_outfit.py` with host Python. Run `render_motion.py` and `render_outfit.py -- lineup` with Blender for the previews. Follow the workspace's `rtk` prefix rule for shell commands.
