# Roof-edge light attachments

The driving roof is tapered, not rectangular. Its purple lower surface also
slopes along the train. A straight row at x=±4.26 left the forward hangers
outside the actual roof; a shared y=7.48 did not match its underside.

`scripts/train_roof_light_profile.gd` measures the rendered
`Engine_Rainbow_Violet` roof triangles in train-local coordinates. Lower engine
pieces that share that material are excluded from the roof measurement.

The 18 side balls follow the measured edges; five balls connect to the
rear beam. Each mount sits 0.12 m inside the outer edge, with a short gold
socket and a 0.008 m seating overlap. The green line stays 0.10 m below
the measured underside, with a gentle 0.04 m sag. The ball/cap/stem assembly
retains the existing colours, radius, and 0.40 m drop from the line.

The side rows still span z=-19.82 to -12.58. Their x/y coordinates now follow
the actual beam rather than fixed offsets. There is no front-edge light row.
Both passenger sections and their existing decorations are unchanged.

After the windscreen is built, `train_light_frame_clearance.gd` measures the
actual gold-frame triangles. The two amber/yellow corner globes at z=-18.915
previously intersected that frame. Their pendants move symmetrically outboard
on short connected gold arms; the roof sockets, row height, 0.40 m drop and all
other lights stay unchanged. The measured minimum globe-to-frame gap is
0.1273 m. Caps, stems and arms also clear the frame. Degenerate triangles in
small spherical fittings use a segment fallback so they cannot corrupt the
nearest-surface measurement.

`test_train_light_frame_clearance.gd` independently checks all 23 lights with
physics shapes against the real frame mesh, reproduces exactly two collisions
at the old positions, and verifies that both are resolved with positive clearance.

`scripts/test_train_roof_light_attachments.gd` checks all 23 sockets with an
independent physics-triangle proxy of the purple roof, plus continuous ball,
cap, stem and mount connections. It includes an old-position negative control,
edge-inset checks, symmetry, and attachment inheritance after moving/turning
the train. `test_train_drive_and_ride.gd` retains ornament counts and gameplay
checks; `test_train_driver_view.gd` protects the actual-eye clear forward view.
