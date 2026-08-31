# Milo blueprint conformance audit

Audit target: `milo_design_blueprint_v1.png` and
`milo_design_blueprint_v1.md`.

Audit evidence: the generated Blender workspace and GLB, four cardinal renders,
the imported Godot scene, the 72-frame live animation capture, and the focused
Milo regression suite.

## Cardinal views

| View | Evidence | Result |
| --- | --- | --- |
| Front | `artifacts/milo_360_front.png` | Pass: rear hair is invisible; face symmetry, soft brows, eye layers, restrained moustache, rose mouth, mayoral tailoring, paired paws, shoes and planted cane are readable. |
| Right | `artifacts/milo_360_right.png` | Pass: three restrained rear hair tips, ear volume, glasses temple, continuous sleeve, coat side seam and cane fist clearance are readable. |
| Back | `artifacts/milo_360_back.png` | Pass: three nested rear-head chevrons, uninterrupted coat back, short button strap, paired rear coat tails, center vent, shoes and grounded cane are readable. The non-blueprint yoke, full-width belt, long center seam and crossing tail were removed. |
| Left | `artifacts/milo_360_left.png` | Pass: crown taper, glasses temple, muzzle depth, sleeve-to-paw continuity, pocket thickness, coat split and shoe profile are readable. |

## Face callouts 01–12

| No. | Blueprint requirement | Build evidence | Result |
| --- | --- | --- | --- |
| 01 | Head shell and separate ears | `Head`, bilateral `EarOuter`, `EarInner` and `EarInnerFold`; ear shell minimum depth is asserted during the Blender build. | Pass |
| 02 | Three rear hair plates | Three separately named, head-bound curved chevron strips. Front exclusion, back width and lowest-chevron reach are build-time assertions. | Pass after correction |
| 03 | Embedded brow-frame fur | One shallow curved `BrowFrame` per side. The duplicate dark eyebrow accents were removed. | Pass after correction |
| 04 | Relaxed, half and closed upper lids | Six separately named face-curved lid meshes; each has a measured depth curve and is switched by the blink controller. | Pass |
| 05 | Recessed eye whites | Bilateral curved eye caps remain behind lids, irises and glasses. | Pass |
| 06 | Iris, pupil and catchlight | Bilateral layered purple irises, circular pupils and catchlights; focus motion is covered by the natural-animation test. | Pass |
| 07 | Cheek pads and muzzle | Bilateral upper/lower cheek leaves, face masks and rounded muzzle volumes are individually inspectable and head-bound. | Pass |
| 08 | Moustache plates | Bilateral swept moustache forms remain clear of the eyelids and speech socket. | Pass |
| 09 | Nose | Separate rounded rose nose and two recessed nostrils. | Pass |
| 10 | Mouth socket | Permanent shallow `MouthSocket` supports every speech mesh from behind. | Pass |
| 11 | Closed, small and wide mouth states | Three mouth states plus two small internal tongue inserts; visibility switching and clean return to closed are tested. | Pass |
| 12 | Glasses | Bilateral rims, bridge and full temple arms; minimum eyelid clearance is asserted at build time. | Pass |

## Body, hands and clothing

- The coat is a continuous closed body, not a front card.
- Front panels, lapels, cyan piping, gold edges, waistcoat facets, collar, tie,
  buttons, watch chain, pockets, cuffs, seams and rear tails remain separate
  named parts.
- The extra rear shoulder yoke that was not present in the blueprint was
  removed. The blueprint waist belt, paired buttons and center split remain.
- Sleeves use a continuous weighted skin across shoulder, elbow and wrist. They
  are not rigid boxes.
- Both hands use rounded tapered paw meshes with separate thumbs. The cane fist
  alignment error is measured during every Blender build; the current error is
  0.001818 model units.
- Both legs retain separate trousers, warm matte boots and soles.
- The cane retains its shaft, hook, two collars, ferrule and grounded tip.
- No tail mesh is generated because the authoritative front, side and back
  blueprint views use a clean tail-free coat silhouette.

## Rig and behaviour

The imported skeleton contains the blueprint chains and the donor rig's more
precise two-bone legs:

```text
root
├── hips
│   ├── upperleg.L -> lowerleg.L -> foot.L
│   └── upperleg.R -> lowerleg.R -> foot.R
└── chest
    ├── head
    ├── upperarm.L -> lowerarm.L -> wrist.L -> hand.L
    └── upperarm.R -> lowerarm.R -> wrist.R -> hand.R
```

The expanded character test checks every bone above, both-sided small parts,
all counsellor clips and the planted cane arm. The live 72-frame capture checks
idle, full blink, eye focus, alternating walk, hand motion, weight shift, cane
grounding, talking mouth states and the counsellor gesture.

## Verification result

- Blender build: pass, 123 separately named parts.
- Blueprint geometry assertions: pass.
- Four-view render inspection: pass.
- Expanded Godot structure and rig test: pass.
- Milo focused and regression suite: 12/12 pass.
- Live Godot animation capture: pass, 72/72 frames.
