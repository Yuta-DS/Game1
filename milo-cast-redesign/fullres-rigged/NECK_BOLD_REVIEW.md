# Milo — refined neck and bold moustache

Local Blender revision, 29 August 2026. User request: improve the neck and make the moustache bold. “Bold” is interpreted as a wider, fuller silhouette, not a color change.

## Scope and backup

Baseline: `neck-bold-before/milo_fullres.glb`, SHA-256 `bd3b20a4be065f0837b51d1c122428732b84fb4d262cf6612600a4e00791e0fd`.

Current: `milo_fullres.glb`, SHA-256 `167fc4c92f7fe1049baf83f85652cb0cf41ae37ea18fbd419480128777b47845`.

Only central moustache geometry, chin geometry/skinning, mouth placement and a new neck transition were changed. The original skull already extended into the collar, but its abrupt taper and the forward-projecting separate chin made the connection read poorly. The skull itself was preserved.

The 95 other meshes—including cheek fur, eyes, glasses, paws, outfit, boots, tail and cane—retain their geometry, normals, colors, materials and skin weights. All 61 bone rest transforms/inverse binds and every animation channel in the seven clips remain unchanged. See `neck_bold_scope_verification.json`.

## Changes

- The chin is now a rounded underside that recedes into the throat, replacing the projecting shelf. Its front follows the existing jaw animation; the rear blends to the head.
- A short tapered fur neck fills the transition behind the collar. Its weights blend from chest through neck to head; no new bones or animation curves were added.
- The small smile was reattached to the new chin surface instead of retaining its former floating position.
- The central moustache is 20.4% wider and 44.0% taller. Its closed-mesh volume is 2.65 times the previous version, with fuller central lobes, wider curls and stronger swept folds. This is an intentional boldness change, not an exact-DOCX likeness claim.

AnyCreature's connected-form, visible-part and independent image-review guidance informed the work. The existing AnyCreature skull seed is retained. Local Blender 5.2 CLI performed the modeling/export; no callable Blender/AnyCreature MCP tools were available. No plugin installation or new AnyCreature compilation occurred.

## Image-only review of the first build

The following actual verdict concerns the first build, preserved in `neck-bold-round1/`, SHA `5e5bafc888df51862eb414e0e2b2ebd12bef47f652c72d7cb7ea48d7f3daff04`:

> Image-only verdict: both requested changes are clearly visible.
>
> - Neck/chin transition is better: the separate dangling chin shape in the old side view is gone, replaced by a continuous jaw-to-collar connection.
> - Moustache is noticeably wider, thicker, and more prominent in both views.
> - Tradeoff: it now dominates the lower face and crowds the glasses slightly; from the side it reads as a rounded bulb more than a curled moustache.
> - Remaining limitation: the neck still reads very short, almost hidden by the collar. The front chin has a slightly angular, shaded transition, though it is more integrated overall.

That build failed the neck/collar intersection check. The back of the neck was tucked inward and the complete check rerun; the front moustache and jaw design were preserved.

Final image-only review after reopening the refreshed face, side and neck-detail images:

> Yes—chin-to-neck integration is visibly improved, with the old dangling chin shape replaced by a continuous connection, and the moustache is unmistakably thicker and wider. The close-up still reveals an angular chin/neck transition and a very short exposed neck; the moustache also sits close to the glasses and looks bulbous in profile.

These remaining visual caveats are not hidden by the numeric checks. The short neck and very full moustache are retained as the current local candidate, not represented as exact reference likeness or user approval.

## Verification and limitations

`verify_neck_bold.py` measures the moustache against the actual baseline GLB and checks the exported neck, chin and mouth. Each has one connected component, no nonmanifold edges and no nonadjacent self-intersections in the checked rest topology. All 631 authored frames preserve neck/head, neck/chin, chin/head and mouth/chin surface contact; the final neck has zero intersections with the high collar in those frames.

`verify_moustache.py` checks both moustache halves and both cheek ruffs for closed topology, skull attachment, head-only weighting, and clearance from eye/spectacle geometry. Numeric clearance does not negate the visual observation that the large moustache crowds the lower glasses area.

The complete current regression is recorded in `neck_bold_regression_summary.json`; media/export hashes are in `delivery_media_manifest.json`. `gate.json` deliberately retains pre-existing palm-fold, cane-pad-clearance and raised-sleeve deformation failures. These were not part of the neck/moustache repair and are not waived.

The model has 100 mesh objects, 237,216 triangles, 61 bones and seven clips. It remains a dense local candidate, not a production LOD or drop-in replacement for the game's different rig. Earlier moustache/paw review documents and hash-mismatched reports are historical.

No live game asset replacement, Git commit, push, upload or deployment.
