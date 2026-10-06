# Milo static likeness study — not approved

This is a separate rebuild responding to the user's rejection of the previous `reference-match` variant. The supplied image remains the target; resemblance to a generic cat scholar is not sufficient acceptance.

Files:

- `milo_likeness.blend`: editable static sculpt, with the user's unmodified turnaround packed as a reference-image empty.
- `milo_likeness.glb`: self-contained static export. No skeleton or animation clips.
- `front.jpg`, `hero.jpg`, `side.jpg`, `back.jpg`, `face.jpg`, `paws.jpg`, `turnaround.jpg`: actual exported-GLB renders, not generated concept imagery.
- `REFERENCE.md`: image-relative measurements from the independent reader.
- `verification.json`: structural checks only, not an artistic pass.

The AnyCreature cranium study was compiled successfully but warned about a steep crown profile slope. Its cross-section axes required mapping from the vertical-chain frame into Blender X-width/Y-depth. The study was then remeshed into a connected cranium and cheek form. White muzzle/ruff parts were reconstructed into one connected shell, while the coat and limbs were built without the previous rig's positional constraints.

First valid image review identified isolated cheek fins, goggle-like eye depth, and a coat opening/lapels too large relative to the reference. Repairs seated brows on the actual surface, replaced stacked iris shells with one coloured surface, widened/merged the cheek ruff, moved eyes closer to the face, shortened lapels, narrowed the opening, and repainted taupe areas directly on skull polygons. These operations are not proof that the requested likeness is achieved.

Current structural evidence: 87 meshes, 57,010 triangles, 1,182,616-byte self-contained GLB; no non-finite vertices. The exported cranium, connected muzzle/ruff, and both paws have zero nonmanifold edges after position welding for the topology check. Surface detail meshes were not certified manifold. No rig, animation, gameplay, collision or full AnyCreature quality certification is claimed.

Rebuild using `rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python /Users/davidsovann/S2603/milo-cast-redesign/likeness-sculpt/build.py`. Render with the sibling `render.py` and structurally inspect with `verify.py`. Run only one Blender process at a time because local disk space is limited.

All prior drafts and game assets are untouched. No Git commit, push, deployment, upload, package installation or publication was performed.

## Final independent likeness verdict

“No—faithful likeness is not yet achieved. This is a substantially improved approximation, but it still reads as a different sculpt of the same character concept.”

The reader identified crescent-like moustache blades and a projecting oval chin; taller pointed ears and wing-like cheek tufts; overly smooth amber eyes and oversized jagged forehead patches; simplified tie/badges/tailoring; and a tail longer and more sharply lifted than the reference. Glasses spacing, palette, coat length and basic body proportions were considered reasonably close, but the reader explicitly stated that these establish recognition, not a reference match.

Status: requested artistic likeness remains unfinished. Do not treat this study as approved, production ready, rig-ready or a replacement for the supplied design.
