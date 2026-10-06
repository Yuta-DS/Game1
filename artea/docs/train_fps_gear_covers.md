# Driver-FPS gear surround: open front and back faces

The curved pearl perimeter covers the top and bottom of the gear system.
Scalloped pearl infill now fills unused corner spaces, with a thin champagne-gold
lip tracing the joined gear openings. Both broad front/back faces remain open
over the entire rotating gears and their meshing points: no service panel or
vents obscure them. Short cross-feet connect the surround to the deck at y=1.30 m.

The outline uses the three full swept gear discs on each side, measured after
the transmission establishes its pitch centres. A 0.18 m perimeter offset and
0.04 m rail radius reserve at least 0.135 m rail-to-tooth clearance. The shell
retains over 0.13 m clearance from the swept teeth. Rails are
centred at absolute x=5.40 and x=6.04 m. Foot tops are measured against the
outline's lower edge rather than extending up over the gear teeth. The
0.045 m-thick pearl shell has both inner and outer surfaces. No transparent
glass or opaque panel fills either gear opening. The infill is clipped against
the union of all three gear-tip discs plus 0.15 m clearance; a 0.02 m gold lip
finishes the opening. Both faces use the same measured pattern. The outer shell
edges keep their narrow thickness rims.

The existing `TrainTankViews` selector enables the covers only for driver FPS.
Third person, walking, passengers and inspection retain the original exterior.
This remains a single-active-viewport treatment, not per-camera split screen.
The original gear meshes, parents, animations, camera settings, tank, controls,
boarding and movement are unchanged. Covers add no gameplay collision.

## Verification

- `test_train_fps_gear_covers.gd` checks all 576 sampled swept-edge rays and
  six gear-centre rays against the covers from the measured driver eye: none
  may hit the housing. Another 576 rays pass through both broad faces, proving
  neither gear face is blocked. Every infill triangle also stays more than
  0.14 m from all swept gear discs. Top and bottom rays must still hit the retained
  surround, guarding against accidentally removing the whole cover. It also
  tests shell/rail clearance, foot contact, rotating mechanisms, repeated view
  changes, inspection, passenger view and exit. These tests concern the cover
  openings, not whether unrelated cab parts disappear.
- `test_train_driver_view.gd` checks the real fox-eye camera while driving,
  all 2,501 central road rays, FOV/free look and actual boarding/disembarking.
  `--capture-driver-view --capture-gear-motion` additionally captures 48 native
  frames from the real forward-driving loop (every fifth 60 Hz input step).
- Existing tank-view and transmission tests protect the original exterior,
  forward/reverse motion, ratios and non-intersecting teeth.
