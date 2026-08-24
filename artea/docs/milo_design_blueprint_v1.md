# Milo design blueprint v1

![Milo production blueprint](../artifacts/milo_design_blueprint_v1.png)

## Design intent

Refine Milo into a soft, elegant counsellor while preserving his current identity: cream-and-caramel elder cat, purple eyes, round gold glasses, white moustache, navy suit and cane. The redesign uses modular low-poly pieces that remain inspectable in Blender and import reliably into Godot 4.

The visual sheet is a direction guide, not exact topology. Final meshes must preserve Milo's current proportions, safe deformation, readable expressions and game-camera silhouette.

## Face architecture: callouts 01–12

| No. | Component | Blender construction | Godot behaviour |
| --- | --- | --- | --- |
| 01 | Head shell and ears | Existing head ellipsoid plus separate outer-ear wedges and inner-ear surface panels; all weighted to `head` | Static head-bound geometry |
| 02 | Rear hair plates | Three broad nested chevron surface strips, fitted to the back of the head, kept separate for inspection and weighted to `head` | Moves with the head; never rises into the front silhouette; no simulation |
| 03 | Brow-frame fur | Two shallow curved surface strips embedded into the forehead/eye-mask depth | Moves with the head and visually anchors the lids |
| 04 | Upper eyelid set | Existing face-conforming `EyelidRelaxed`, `EyelidHalf` and `EyelidClosed` meshes | Existing visibility-driven blink controller |
| 05 | Eye whites | Existing curved eye caps, recessed behind eyelids | Remains part of the current focus/blink system |
| 06 | Iris, pupil and catchlight | Existing layered curved caps/spheres | Existing subtle player-focus offsets |
| 07 | Cheek pads and muzzle | Two rounded low-poly cheek pads plus central muzzle bridge, overlapping the head shell | Head-bound; provides a stable base for the mouth |
| 08 | Moustache plates | Existing left/right layered moustache forms, refined only at their roots | Head-bound and kept clear of eyelid/mouth motion |
| 09 | Nose | Existing shallow nose panel/volume | Head-bound |
| 10 | Mouth socket | A shallow recessed muzzle opening behind the visible mouth plates | Head-bound; prevents talking mouths appearing pasted on |
| 11 | Mouth-state set | Existing closed, small-open and wide-open meshes, adjusted to the new socket | Existing speech visibility switching; no jaw bone required |
| 12 | Glasses | Existing separate gold lens rims, bridge and arms | Head-bound; must keep clearance from eyelids and brow fur |

## Body and clothing architecture

- Preserve the current compact body, existing skeleton and cane side.
- Keep coat body, lapels, waistcoat facets, collar, tie, cuffs, pocket flaps, trim and buttons as separate inspectable pieces.
- Add only shallow thickness and cleaner overlap to the lapels, cuffs and short rear coat split.
- Keep sleeves as the existing continuous weighted skins across upper arm, lower arm and wrist.
- Keep paws, shoes and cane modular. The authoritative three-view silhouette is
  tail-free. No cloth, hair or physics simulation is required.

## Rig architecture

The redesign does not require a replacement skeleton. It uses the current imported rig chains:

```text
root
└── chest
    ├── head
    ├── upperarm.L -> lowerarm.L -> wrist.L -> hand.L
    └── upperarm.R -> lowerarm.R -> wrist.R -> hand.R

hips
├── upperleg.L -> lowerleg.L -> foot.L
└── upperleg.R -> lowerleg.R -> foot.R
```

The cane remains assigned to the planted cane hand. New head fur, brow framing, cheek pieces and the mouth socket are rigidly weighted to `head`, so the current idle, walk, gesture, blink, focus and talking systems remain compatible.

## Blender to Godot pipeline

```text
Procedural Blender part builder
    -> named modular meshes
    -> existing armature and vertex groups
    -> GLB export
    -> Godot import
    -> Milo skin/controller discovers named parts
    -> AnimationTree drives locomotion and gestures
    -> visibility controls blink and speech meshes
```

## Seven implementation parts

1. Build and verify the three rear hair chevrons: hidden from front, restrained
   tips from side, and nested layers from back.
2. Build and verify brow-frame fur and face-conforming eyelid clearance.
3. Build and verify cheek pads, muzzle, mouth socket and all three speech states.
4. Refine and verify outer/inner ears and glasses clearance.
5. Refine and verify coat layering, cuffs, pockets and rear coat split.
6. Refine and verify paws, cane grip, shoes, walk motion and grounded shadow.
7. Import into Godot and verify idle, walking, blinking, eye focus, speech, gestures, counselling poses and live-hub appearance.

Each part should be completed, rendered from useful angles, checked against its acceptance checklist, tested in Godot where applicable, and corrected before the next part begins.

## Feasibility checklist

- [x] Uses mesh primitives and surface panels already supported by the Blender builder.
- [x] Keeps every important component individually named and inspectable.
- [x] Requires no new skeleton or fragile facial bones.
- [x] Preserves the existing eyelid and mouth visibility controllers.
- [x] Preserves current eye-focus, walk, idle, gesture and cane behaviour.
- [x] Exports through the existing GLB workflow.
- [x] Imports into Godot 4 with standard meshes, materials, skeleton weights and `AnimationTree` control.
- [x] Avoids cloth simulation, strand fur, physics hair and unsupported rendering features.
- [x] Can be implemented and verified incrementally in seven isolated parts.
