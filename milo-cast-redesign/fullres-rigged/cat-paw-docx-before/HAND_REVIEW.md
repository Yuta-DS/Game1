# Hand-only revision — 2026-08-28

Historical first hand revision. The user's subsequent palm-shape/orientation feedback is implemented and documented in `PALM_REVIEW.md`; the measurements and image verdict below describe the preceding asset preserved in `palm-before/`.

The user's request was to improve Milo's hands. This revision replaces only the two paw meshes, adds eight distal digit bones, and updates hand poses and cane-hold placement. The face, outfit and other 100 meshes are geometrically unchanged. The local game has not been modified.

AnyCreature's connected-anatomy, real-joint and independent-image-review guidance informed the work. Geometry and rig changes were made in Blender 5.2 directly; the Blender MCP/plugin remained disconnected. No install, external upload, commit or push was performed.

## Changes and measured checks

- Replaced balloon-like voxel paws with connected subdivision cages, flatter tapered palms, short rounded fingers and side-extruded opposing thumbs.
- Added proximal/distal joints to each of the three fingers and each thumb. Authored loop weights prevent neighboring fingers from dragging each other.
- Reposed the greeting, pointing and relaxed fingers. Cane_Hold now uses a reachable wrist, two-joint curls and an opposing thumb; the accessory was shifted slightly within the hand's reach.
- Both hands are single connected closed surfaces with normalized skinning. All 486 authored frames remain finite and loop endpoints match exactly.
- Maximum hand edge stretch: 2.2734x in Cane_Hold, 1.7141x in Guide, approximately 1.2005x in the other clips. The old cane paw reached 4.6746x.
- At cane frames 0, 48 and 96, the hand has zero intersecting triangle pairs with the shaft, collar, crook or ferrule. This does not establish collision freedom for every pose or the whole character.
- `hand-before/` contains the recoverable previous .blend/.glb and before images. `check_hand_scope.py` confirms unchanged triangle geometry for all 100 non-hand meshes.

## Independent image-only verdict (verbatim)

B is materially better than A: cleaner silhouettes, clearer finger separation, and much less swollen/lumpy palm shaping.

- A `paws.jpg`: oversized bulbous palm and thumb lump; three drooping fingers have cramped, uneven roots.
- A `cane_grip.jpg`: a broad, lumpy hand sits behind the hook; finger/thumb relationships and the actual grasp are difficult to read.
- B `paws.jpg`: flatter, coherent palm with three clearly separated rounded fingers. The thumb is barely readable from this angle.
- B `cane_grip.jpg`: three curled finger ends on the left and a thumb on the right make holding the vertical shaft below the hook more legible. The shaft hides contact; this image does not clearly demonstrate a tight wrap. Palm-to-wrist shaping remains somewhat angular.
- B `greeting_hand.jpg`: clear three-finger-plus-thumb wave, continuous palm, no obvious collapse. Fingers remain uniform and tubular; narrow finger valleys and the broad, flat palm give it a simple rubber-glove appearance.
- B `pose_Greet.jpg`: the wave reads immediately at full-character scale; both hands have clean, recognizable silhouettes.

Verdict: a substantial visual improvement, especially the open hand. The cane grip is clearer but still less convincing than the greeting hand. These still images establish no animation or collision guarantees.

## Scope of acceptance

The hand geometry and numerical deformation checks pass. The overall character remains an unapproved local draft: the previous reference-likeness findings in `REVIEW.md` still apply. This revision is not a full AnyCreature quality-gate pass or a production/live-game integration.
