# Milo 2 — Independent Character

This directory is the complete, independent Milo 2 implementation. It does not load,
modify, inherit from, or overwrite the original Milo character.

## Ownership

- `reference/` — the user-approved visual target.
- `spec/` — measurable design and runtime contracts.
- `blender/` — a blank-scene Blender generator written specifically for Milo 2.
- `assets/` — generated `.blend` and web-compatible `.glb` files.
- `godot/` — Milo 2's independent skin, character scene, and controller.
- `tests/` — isolation, rig, animation, and integration checks.
- `artifacts/` — rendered proof and quality reports.

## Rebuild

```sh
blender --background --python milo2/blender/build_milo2_from_scratch.py
```

The generator begins with `read_factory_settings(use_empty=True)` and references no
Milo 1 model or script. It produces one unified triangulated skinned mesh plus one
41-bone armature—not a collection of body-part objects. Head, face, torso, coat,
arms, paws, fingers, legs, boots, and tail remain separately controllable through
materials and bone-weight groups. It produces a smooth, chubby elder cat with the approved
ivory head, gold spectacles, bold white moustache, navy-and-gold medieval/classic
coat, burgundy waistcoat, natural four-finger cat paws, boots, and striped tail.
