# Milo — cast-style eyes and rounded head

Local implementation draft. No live-game replacement, commit, push, upload or deployment.

## What changed

The actual game's Rogue, Mage, Barbarian and Fox models use restrained dark eyes without colored iris rings. Milo's previous amber iris bands, bright sparkle meshes, large eye discs, faceted skull and three stacked cheek plates created a different visual language.

- Recompiled the cranium profile with local AnyCreature, then shaped the crown, jaw and connected cheek sweeps in Blender. Rounded-square/chubby silhouette, smaller ears, smooth normals and a simpler warm-cream material.
- One closed charcoal oval per eye; removed iris/sclera rings, separate glints and socket outlines. Eye size is 0.092 × 0.132 m in the authoring scale.
- Kept Milo's gold spectacles, white elder brows, cat nose and moustache. Reduced moustache bulk, simplified its surface, thinned the spectacle frames and brought them nearer the face. Chin now shares the head fur color.
- Moved only the two eye rest pivots to follow the new eye centers. Kept the 61-bone rig, seven clips, doubled palms and medieval-inspired outfit.

The Blender MCP/plugin tools were not callable. The installed AnyCreature dispatcher and Blender 5.2 CLI were used locally; no installation or substitute generated concept image was used.

The user's newer request for game-cast eye styling supersedes the earlier amber-eye concept detail. This is not an exact reproduction of either the concept sheet or another cast member.

## Final asset and checks

- GLB SHA-256: `6104765c6620e379d1d078c84554ef534f7bdeb1a32209bc562faeb9863bf61f`
- 5,562,032 bytes; 179,124 triangles; 97 mesh objects; 61 bones; seven baked clips.
- `head-style-before/` contains the immediately previous Blender/GLB, face sources and previews. Earlier backups remain untouched.
- `check_head_scope.py`: all 78 non-head meshes have unchanged triangle geometry within 1e-7 m and unchanged material definitions. All non-eye animation channel samples compare exactly unchanged across seven clips.
- `verify_head_style.py`: skull and both eyes each have one connected component, zero nonmanifold edges, smooth faces. Each eye has one dark material and is weighted to its own eye control. All 631 authored frames retain finite eye geometry and a working blink. Open/closing/blink/reopened images were rendered from the final exported GLB.
- `verify.py`: final GLB reimport, normalized weights, finite vertices across 631 authored frames, zero loop endpoint error, no boot ground penetration; 97 cane-hold frames have zero detected hand/cane surface intersections.
- Exported finger-mechanics, palm orientation, sampled cuff clearance, and prior hand-size/outfit assertions were rerun. The two hands remain 56,320 triangles each.
- Reran the separate hand self-contact check: all 145 left-hand Hand_Mechanics samples and the right-hand cane pose have zero detected nonadjacent intersecting triangle pairs; cane fingertip-pad clearance checks pass. These are not whole-character collision tests.
- Godot 4.7.1 imports all seven clips and checks motion and palm orientation. Both eye controls compress to approximately 0.27056 at the sampled blink time. The real local compatibility-renderer preview was captured.

`gate.json` remains **not fully passed**: the pre-existing raised-arm sleeve reaches 3.2595× edge stretch, above the conservative 3× target. This head revision does not fix or hide that issue.

AnyCreature's seed compiler emitted a crowded-profile slope warning near the crown. The final skull is subsequently reshaped, remeshed and rigidly weighted to the head, not bent with that seed chain; the exported final topology passes the checks above. This is not a claim that every upstream AnyCreature quality gate was run.

## Independent image-only review

Reviewer viewed only the current face, full-body hero and actual-cast comparison renders; no source was provided. The initial review led to bringing the spectacles closer to the face and removing the contrasting chin patch. Final re-review, verbatim:

> Re-viewed all three updated images.
>
> - Eyes: Substantially closer to Rogue/Fox than “before”: simple dark shapes without prominent irises or sparkle clusters. They remain rounder, more exposed, and less brow-framed, giving Milo a gentler, wide-eyed expression.
> - Head: Clearly reads as a kindly elderly cat, particularly through the white moustache/brows and spectacles. The broad rounded-square silhouette supports that identity.
> - Finishing: The glasses look more settled against the face, and the chin is less conspicuously separate.
> - Remaining mismatches: Smooth head versus faceted reference characters and tail; visible ring-like glasses shadows; extremely regular eyes that lack the references’ stronger lid/brow expression. No obvious major clipping in these views. This supports visual improvement, not an exact style match or production approval.

## Honest limits

The head is deliberately softer than the faceted cast; it is closer in eye treatment, not identical in every surface or expression. Blink is eye-bone compression, not a full eyelid rig. Broad forehead and oversized head remain stylized. The unchanged tail, hands and outfit retain the earlier review's limitations. Dense geometry, draw-call consolidation, production LOD and live-controller integration remain unfinished. The existing game rig/controller is not a drop-in match for this local 61-bone draft.

`cast_eye_comparison.jpg` uses the actual Rogue and Fox assets plus the immediately previous and revised Milo, with approximate equal head width and shared lighting. It is not a body-scale comparison. Current stills and videos are rendered from the final GLB, not the concept artwork.
