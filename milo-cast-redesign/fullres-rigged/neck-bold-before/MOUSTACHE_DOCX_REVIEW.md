# Milo — DOCX moustache revision

Local Blender candidate, 29 August 2026. This is an improvement pass, not an exact-reference or production approval.

## Reference and scope

The original `word/media/image7.png` inside `World_One_Mind_Spark_Concise_Developer_Guide_Implementation_Blueprints.docx` was reopened and verified byte-identical to the retained extracted image. SHA-256: `1a1311d9e3c8eadc1504cca2e6cfed09f90c8e5ba6819fe33f619880bff05162`.

Panels 02 and 05 show full central moustache lobes, broad folded fur planes, fine outward/upward tips, and two compact overlapping cream cheek locks. Labels inside the artwork are reference content, not additional task instructions. The DOCX was not edited.

Only the moustache and cream cheek-fur meshes changed. The source skull, nose, eyes, brows, spectacles, paws, outfit, boots, tail, cane, all skinning on those meshes, all 61 bones, and all seven animation clips are protected against `moustache-docx-before/milo_fullres.glb`.

Baseline SHA-256: `2b0df04a1705f731a0d118d49c82182ffb2251f683366d201b767cf79d577bd8`.

Current SHA-256: `bd3b20a4be065f0837b51d1c122428732b84fb4d262cf6612600a4e00791e0fd`.

## Modeling decisions

The main moustache uses a closed shaped loft: high inner shoulders, a full low underside, two shallow swept surface folds, and tapered outer curls. The folds are in the mesh, not floating stripes or a substituted image.

The first connected cheek patch had an undesirable squared base and a radial-fan surface overlap. It was discarded. The final cheek fur uses two overlapping almond volumes sculpt-unioned into one closed mesh per side, with their shared roots buried inside the skull. No separate backing plate remains.

AnyCreature's connected-part and image-only-review guidance informed this choice. Its existing cranium seed is retained. Local Blender 5.2 CLI performed modeling and export; no callable Blender/AnyCreature MCP tools were available, and no plugin invocation, installation, new AnyCreature compile, or publication is claimed.

## Actual image-only review

First candidate, archived in `moustache-docx-round1/`, SHA `eecdac92bf926a0e57b994ac88b3a25a8cceacc3458208ab1da7b585661689a4`:

> Mixed result.
>
> - Moustache: closer in directional flow; added sweeping ridges resemble the source’s layered hair. But the three sharp, evenly spaced grooves look more mechanically ribbed than the source’s broad, softly faceted lobes.
> - Cheek tufts: further away. The earlier separate pointed tufts were closer; the current version joins them onto conspicuous thick, squared-off cream bases. The side view reinforces that bulky attachment.
>
> Largest remaining mismatch: the cheek-tuفت bases should disappear into compact, overlapping leaf-shaped tufts, not read as cream blocks attached to the cheeks.

The intermediate softened patch is preserved in `moustache-docx-round2/`, SHA `9fe536afaa1600cd1ccccb7352a59236542e90c536994c9b557e3303426f83e9`. It still failed the cheek self-intersection check (six nonadjacent triangle pairs on the first checked cheek), so it was replaced with the volumetric concept rather than accepted.

Final candidate, compared by reopening the reference, baseline face, current face and side images:

> Yes—modestly closer overall than the baseline. The moustache has a clearer swept upper ridge, and the smaller, separated cheek tufts avoid the previous bulky joined bases.
>
> Remaining mismatch: the source fur has broad, overlapping, softly faceted leaf shapes. The current moustache still reads as two smooth crescent cushions; the cheek tufts look blunt and peg-like in profile rather than flattened leaves.

“Separated” above describes the visible two-tip silhouette, not mesh connectivity. The geometry check confirms one connected cheek mesh per side. The assessment is preserved verbatim; it does not establish an exact likeness or user approval.

## Verification

`check_moustache_scope.py` compares all vertex attributes, triangle winding, skinning, materials, protected node transforms, inverse-bind matrices, and every animation channel. All 95 protected meshes, 61 bones and seven clips match the baseline (geometry attributes rounded to 1e-7; animation and rest-transform comparisons exact).

`verify_moustache.py` reimports the actual GLB. Both moustache halves and both cheek ruffs each have one component, zero nonmanifold edges, zero nonadjacent self-intersections, head-only weights, and positive skull attachment intersections. None intersects the eye or spectacle meshes in the checked rest pose.

The final model has 99 mesh objects and 216,648 triangles. This is still a dense local candidate, not a finished game LOD.

`moustache_regression_summary.json` records the complete rerun, including failures. `gate.json` and `delivery_media_manifest.json` bind the actual reports and refreshed media to the final asset hash. Prior CAT_PAW/COMPACT/HEAD reports are historical unless their hashes match.

Known pre-existing hand contact, palm opposition-fold and raised-sleeve deformation issues are not repaired or waived in this moustache-only scope. The unchanged rig is not a drop-in replacement for the game's different rig.

No live game replacements, Git commits, pushes, uploads or deployments.
