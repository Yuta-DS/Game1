# Milo — cast-matched redesign

Local review candidate; no live game assets replaced, no commits, no push, no deployment.

## Reference and trace

The actual hub NPCs instantiate Rogue, Mage, Barbarian, Knight and Rogue_Hooded from `artea/assets3D/characters/`. The player uses `fox.glb` at 1.5 scale with unshaded texture overrides. `cast_reference.png` compares those assets to the rejected Milo v2 under the same lighting.

The active Milo route is `project.godot` → `MiloCompanionManager.gd` → `milo_animations.tscn` → `milo_scholar.tscn` → `milo_villager_skin.tscn` → `milo_exact_target_parts.glb`. Behavior and part animation live in `milo_animations.gd` and `milo_villager_skin.gd`. These contain existing user changes and are not touched by this review build.

## Design contract

- Match the villagers' chunky torso, short legs, broad hands and boots; reuse the project's Rogue body and animation skeleton.
- New AnyCreature head: rounded-square cranium, slightly fuller lower cheeks, solid triangular cat ears.
- Small black bean eyes, no sclera, irises, glass transmission, realistic eyelids or multiple catchlights.
- Simple warm biscuit fur, navy/teal scholar tunic, muted scarf, leather belt and boots. Broad matte color areas with restrained variation.
- Keep Milo's white moustache, bronze spectacles, thoughtful brows and walking stick; remove fine tailoring, jewelry and studio-style surface detail.
- Judge against the actual cast at consistent scale, not an isolated beauty render.

The head is a part-isolation AnyCreature build, not a complete-creature/combat certification. Noncombat NPC movement is checked separately in Blender and the exported GLB.
