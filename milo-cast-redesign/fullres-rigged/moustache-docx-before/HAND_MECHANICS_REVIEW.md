# Human-inspired hand mechanics revision

Historical pre-size-fit revision. The current palm-size edit, current measurements and export hash are in `PALM_SIZE_REVIEW.md`. The implementation and independent verdict below describe the preserved `palm-size-before/` version.

Local implementation draft, 2026-08-28. The user's criticism was about how palms and fingers actually work, not merely surface polish. The old rig had a rigid palm, two joints per finger, and an aimed thumb without a separate opposition base. Those structural shortcuts were replaced. This is not a claim of complete realism or an approved character likeness.

## Implemented in the actual Blender/GLB asset

- 61 bones: each hand now has three articulated palm rays, three three-joint fingers (MCP, PIP, DIP), and a three-joint thumb chain (CMC, MCP, IP). Milo retains the stylized three-finger-plus-thumb silhouette.
- Base knuckles flex and spread. Middle and end finger joints are flexion hinges, with no sideways bending, bone scaling or free fingertip aiming. Spread decreases as the base knuckle closes. The authored DIP/PIP coupling is 0.65; that is an animation choice, not a universal anatomical ratio.
- Outer palm rays cup more than the index ray. Thumb motion begins at the base and combines sweep, abduction and axial rotation before the two flexion joints. There is now a real opposition control, although the rendered thumb-pad orientation remains insufficiently convincing for a fully human-like grip.
- Fingers were lengthened and slimmed slightly to give the three hinges room to bend. Broad joint-weight transitions reduce collapsing creases. Thumb-web weights diffuse through connected skin rather than switching abruptly between rigid bands. Palm/cuff size and all non-hand geometry remain unchanged.
- Idle, walking, greeting, pointing, speech and cane-hold poses were retargeted. Added the six-second `Hand_Mechanics` action: open, relaxed, hook curl, modest thumb opposition, release. Its three-view video is rendered from the exported GLB, not generated artwork.
- The cane fit adjusts bounded anatomical angles and accessory placement; it does not stretch bones or move fingertips independently. This remains a static stylized shaft hold, not a simulated load-bearing cane walk.

AnyCreature's connected-part, readability and real-joint guidance informed this revision and its independent image-only review. Blender 5.2 CLI performed editing, rigging, export and rendering because no callable Blender plugin connection was available. No plugin installation, external upload, live-game replacement, commit or push was performed.

Anatomical basis: finger MCP flexion/spread and PIP/DIP hinge structure are consistent with the model described by [Wu et al., Analysis of musculoskeletal loading of thumb during pipetting, 2014](https://stacks.cdc.gov/view/cdc/38377/cdc_38377_DS1.pdf). This stylized rig is not a clinical hand model, tendon simulation or motion-capture dataset. No direct access to pretraining examples is claimed.

## Exported-asset evidence

- SHA-256: `9484470ca52c5105b0aae22bb5d3f1d43cfbe5ea4df306bb28ba79bb59e0ac98`.
- 2,752,920 bytes; 67,486 triangles; 102 mesh objects; 61 bones; seven clips at 24 fps.
- All 631 authored frames pass finite-geometry, joint-range and normalized-weight checks. Loop endpoint vertex error is zero. Finger hinge sideways error is below 0.00001 degrees, and DIP/PIP coupling error below 0.00005 degrees. Digit translations are below 0.000001 m and scale error below 0.000001.
- Outer palm flexion reaches 7.2 degrees; maximum thumb-base rotation is 41.25 degrees. Godot independently imports all seven clips and measures 72.94 degrees of finger-hinge rotation during the hand test while wrist travel stays below 0.001 m.
- Maximum hand edge stretch is 1.82045x in Guide, down from 2.07361x in the prior 47-bone surface-polish draft. Cane hand maximum is 1.57576x. These are mesh edge ratios, not measurements of biological tissue realism.
- Each hand is one connected, closed mesh with zero nonmanifold edges. All 145 authored frames of the left-hand mechanics test have zero detected nonadjacent triangle self-intersections. The right-hand cane pose at frame zero also has none. This does not prove no self-intersection in untested poses or arbitrary manual controls.
- All 97 authored Cane_Hold frames have zero detected right-hand/cane triangle intersections. At frame zero, palmar distal-pad clearances are 1.327, 2.167 and 2.727 mm for the three fingers and 1.655 mm for the thumb. Near-contact is not firm pressure/contact force, and the visual grasp still needs work.
- Resting palms face inward with thumbs forward; greeting presents the palm, cane hold the dorsal surface. All 100 non-hand mesh triangle geometries match the preserved previous asset within 0.0000001 m.
- Godot compatibility import, seven-clip motion assertions, palm orientation and real preview rendering pass. The separate preview does not test the live game's old runtime rig overrides.

Early rebuilds exposed self-intersections at tight finger hinges and the thumb web. Finger segment space, joint blending and thumb-web weights were revised; the demo opposition was limited to a clean tested range. Those failed attempts are not being counted as passing gates.

## Independent image-only review, verbatim

The three-finger-plus-thumb silhouette is clear and suits a stylized cat.

- Open → relaxed → hook is visually coherent: fingertips progressively turn toward the palm, and the side view confirms actual curved fingers rather than merely shortened silhouettes. However, tight bends have pinched inner creases and bulbous ends; the relaxed pose’s ring-like folds look rubbery.
- The thumb visibly moves inward/upward toward the adjacent finger. That supports a pinch-like pose, but these views do not clearly establish full human-like opposition—particularly rotation of the thumb pad toward the finger pads or reach across the palm.
- The cane reads as held at character-viewing distance. Close inspection is less convincing: fingers resemble evenly spaced horizontal prongs, and the reverse view does not clearly show their pads closing firmly against the shaft. The thumb sits low beneath the fingers, without an obvious opposing clamp. Contact and a more enclosing grip need clearer evidence.
- The palm is broad and mitten-like; the thumb base lacks a distinct fleshy mound. These are acceptable stylizations, but weaken the human-inspired anatomical read. The smooth hand also contrasts sharply with the faceted surrounding character.

These stills establish distinct, broadly sensible poses—not smooth interpolation, stable joint motion, preserved volume throughout movement, or collision-free cane contact.

## Handoff and limits

`milo_hand_mechanics.mp4` shows the six-second test from palm, side and back. `mechanics_*.jpg`, `cane_grip.jpg`, `cane_grip_inside.jpg`, `relaxed_paw.jpg` and `godot_hand_Hand_Mechanics.png` are current renders. `mechanics-before/` preserves the 47-bone draft that preceded this structural revision; earlier backups remain intact.

The mechanical structure is improved and tested; the broad palm, rubbery-looking tight creases and visually weak thumb clamp remain unresolved art issues. Overall quality approval stays false. Historical whole-character likeness was moderate, not close; this hand-only pass did not address face or wardrobe. Raised sleeves still reach approximately 2.74x edge stretch. Full physics, human motion capture, facial production rig, cloth simulation, production LOD and live integration are not claimed.

An earlier 47-bone isolated-part reader reported: front—hand; side—hand; top—unidentifiable; hero—hand. That historical four-view identity gate was not repeated for this 61-bone version and is not promoted to a full AnyCreature pass.
