# Original tank exterior, unchanged driver FPS view

The exterior tank is restored to the full-size pearl-and-gold version from
before the driver sightline reduction. Its measured barrel is 4.1472 m in
diameter and 6.6670 m long, centred at y=4.72 m. The earlier user-requested
enlargement and gold/rainbow trim remain; this does not reset the tank to the
smaller initial Blender design.

Driver first person retains the exact existing low-profile tank rendering:
65% radial size, centre y=2.8 m and unchanged length. The camera code, actual
character-eye location, 95-degree FOV, -4-degree initial pitch and free look
are unchanged. Seat, curved windscreen, snowflakes and controls are unchanged.

`TrainTankViews` selects the exterior model for ordinary cameras, third person,
inspection, passengers and walking. Only the active driver's first-person
camera selects the clearance model. Leaving or switching away restores the
full exterior. The selection runs after the camera each frame.

Static tank components are extracted intact from the original imported mesh,
preserving material, UV, colour, normal and tangent data. Only one shell and
trim set is visible at a time. Moving pressure orbs, valves and the exhaust
remain single shared mechanisms; placement mounts switch their original/FPS
positions without duplicating animation or changing pivots. Collision and
train movement are unchanged.

This is a single-active-viewport visual treatment, not a physical resizing
of the tank during play. `test_train_original_tank_views.gd` measures both
models and exercises repeated driver view switches, inspection, disembarking,
passenger view and a separate active capture camera. The real driver-view test
checks 2,501 sightline rays and the moving character-eye camera.

