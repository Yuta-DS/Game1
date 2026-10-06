# Curved gold cab, captain's seat and flat snowflakes

## Driver's seat

The new `DriverCaptainSeat` replaces 30 measured original chair components,
including the old leaf-shaped back. It keeps the original pedestal/swivel,
passenger seats, driver anchor `(0, 3.55, -15.05)`, fox pose and working controls.
The restyled chair has a softly arched backrest, pearl shell, narrow champagne
gold surround, diamond-quilted rainbow upholstery, curved arm supports and a
small inset six-armed snowflake crest. One contoured back pad replaces the three
rectangular pads; the cushion and two arm pads retain their original footprint.
Gold piping finishes the cushion edge, and pearl inlays soften the arm trays.
The curved supports attach to both the seat pan and the arm trays.

`shaders/train_captain_upholstery.gdshader` gives only the driver chair a slow,
complete seven-colour aurora cycle with fine diamond stitching and restrained
silk sheen. Passenger materials and geometry are unchanged.

The cushion top is at 3.15 m, below the measured fox thigh pivots at about
3.32 m. The cushion ends before the lower legs. The reclined back begins above
3.55 m, leaving the tail at about 3.25 m clear beneath it. No camera or player
anchor was moved to accommodate the chair.

## Front windscreen

The full 14 cm perimeter is now warm gold, replacing the previous 2.5 cm gold
stripe and broad dark-metal face. The pane, gasket and surround use one shared
rounded profile and surface function. Corner radius increased to 1.02 m; the
horizontal wrap increased from 0.15 m to 0.48 m, with 10% shoulder taper.
Gold lower posts and upper brackets join the surround to the cab.

There is still one double-sided transparent pane, not overlapping glass boxes.
Its alpha is 0.045, with no centre bar. The parked wipers remain below the road
view. Existing side glass, roof lights and driving controls are retained.

## Roof snowflakes

All three crowns are nearly flat. The arm centreline varies by only 0.14 m
instead of 1.00 m at the driver roof and 1.26 m at the passenger roofs.
Six arms, 24 branches, fine gold veins and pearl tips remain on each crown.
Slimmer arms and lower emission reveal the branch details. The original roof
foot locations are retained; short brackets connect the lower crowns to them.
A slim central support joins the lowered driver crown to its existing raised
celestial ornament. The halo mechanisms are preserved.

## Verification

`scripts/test_train_cab_redesign.gd` checks removal of the old chair, measured
seat fit, tail/leg clearance, rainbow materials, full gold/glass/gasket perimeter
alignment, glass bounds and wrap, and snowflake slope, thickness and detail.
`scripts/test_train_driver_view.gd` checks actual character-eye camera placement
and 2,501 central sightline rays. Other train regressions cover driver animation,
forward/reverse gears, boarding, passengers and roof-light attachment.

`scripts/capture_train_cab_redesign.gd` captures five native views, including
empty/occupied seating, the curved cab and all three snowflakes. These do not
substitute for Web export and production browser verification.
Use `-- --chair-only` for front, detail and occupied redesigned-chair captures.
