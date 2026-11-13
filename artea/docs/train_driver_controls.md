# Animated train driver

Near the train, press **R** to enter the driving seat. **T** still selects the
nearest passenger section. The original rainbow chair geometry is unchanged;
the driver anchor now matches its measured cushion instead of the lower deck.

The driver stows the sword, settles into the chair, powers the cab, checks the
pressure dial, selects direction, releases the brake and applies the throttle.
Both arms use the shipped fox skeleton to reach the moving handle grips. Feet
rest on supported footplates. Exiting restores normal animations and equipment.

- **W:** request forward movement.
- **S:** request reverse; the driver brakes to a stop before moving the reverser.
- **Release W/S:** apply the service brake.
- **H:** sound the existing horn; the left hand reaches its separate control.
- **Q:** leave when docked. Startup can also be cancelled while docked.
- **3:** wider 95° first-person driver view; mouse still looks freely around.
- **4:** third-person view, restoring the entire locomotive exterior.
- **Move mouse:** look left/right/up/down without holding a button. Horizontal
  look turns a full circle; vertical look stops at ±89° to avoid camera flips.
- **Esc:** release the cursor and pause mouse look for menus.
- **Click game space:** resume mouse look/pointer capture. Clicking a menu
  button does not recapture it. **3/4** also resume look when selecting a view.

The old circular navigation wheel and its yoke grips are removed. First person
now sits between the character's actual eyes, not at an elevated cab viewpoint.
The fox's measured rest-mesh eye point `(0, 0.84, 0.205)` is converted into
head-bone space and follows its current pose and model scale. In the driving
seat this is approximately train-local `(0, 4.732, -15.665)`. The former camera
height of 8.465 m and selective locomotive hiding have been removed.
The cab and engine stay visible, with a physical sightline refit shared by all
camera modes. The imported dashboard is 1.25 m lower; the pearl boiler and its
fitted bands use matching 0.65 radial scaling with their base just above the
deck. The cover is 0.90 m lower, the chimney is shortened above its base, and
the side plumbing and engraved arc follow the refitted boiler. The seats,
working handles and passenger sections stay put.
The thick segmented ivory arch is replaced by a swept panoramic windscreen,
less than 8.86 m wide, with tapered shoulders and a gently crowned header.
The glass slopes rearward and wraps slightly at its edges. A fine champagne-gold
outer edge surrounds a satin titanium face and a recessed graphite gasket.
One tessellated, double-sided pane uses 2.8% opacity. Small parked wiper details
remain below the road view; they are decorative, not an animated wiper system.
The curved header stays just below the roof skin at y=7.44; two upper brackets
join the roof underside and two lower mounts join the body. There is no centre
divider, overlapping glass shell, bright inner outline, or floating arch tip.
Driver first person starts with a gentle 4° downward gaze. The road window is
clear and only the lower instruments/engine remain at the bottom of the frame.
Mouse look stays under player control; automatic head glances do not force the
camera's viewing direction. Driver orientation follows train turns/gradients.
Passenger and on-foot first person use the same eye socket. The player's own
visuals remain hidden in first person to prevent the head clipping into view.
First-person zoom-out uses field of view rather than moving behind the seat.
Third person and artwork inspection restore the scene's original FOV.

The HUD describes the current cab action. Startup takes about 1.8 seconds;
direction selection and brake release take another 0.75 seconds. Wheel/gear
motion remains tied to speed and direction, brake needles follow brake demand,
and pressure/steam follow startup readiness. This is a deliberately simplified
game procedure, not a locomotive operating simulator.

Every physical action has positional feedback. Boarding, power-up, pressure
valve, reverser, brake release and throttle sounds play from the close-range cab
source; the horn, service brake, doors and station-arrival chime play from the
locomotive source. Passenger seating and the arrival-choice confirmation are
also audible. These deterministic one-shots are generated as ordinary
`AudioStreamWAV` resources, so they require no native codec or thread and remain
available in the non-Mono Web export.

## Implementation

- `scripts/train_driver_actions.gd`: shared startup/brake/reverser state.
- `scripts/train_driver_console.gd`: reachable handles, pressure dial and footrests.
- `scripts/train_driver_pose.gd`: seated legs, arm IK, head glances, equipment restore.
- `scripts/train_driver_view.gd`: whole-piece navigation-wheel removal.
- `scripts/train_cab_sightline.gd`: whole-component dashboard/engine refit and clear front glazing.
- `scripts/train_front_windscreen.gd`: swept panoramic glazing, tapered trim, mounts and parked wiper details.
- `scripts/CameraFollow.gd`: character-eye first person and train-relative free look.
- `scripts/art_castle_story_railway.gd`: movement interlocks and visual synchronization.
- `player_3d.gd`: measured eye socket, vehicle-pose lifecycle and restoration of walking.

No new native plugin, network service, or animation asset is required; the
implementation uses Web-compatible GDScript and the existing fox GLB.

## Verification

Run `scripts/test_train_driver_actions.gd` with Godot `--headless --script`.
It exercises the real fox rig, measured hip placement, hand contact, startup,
forward/reverse, horn, braking, disembarking, cancellation and ordinary held W.
Use the same test without `--headless` and with `-- --capture-driver` for images
of the power-on, throttle, horn and braking poses under `artifacts/`.

`scripts/test_train_driver_view.gd` checks wheel removal, engine visibility,
real moving-camera alignment, free look, 3/4 switching, and station exit. A
test-only proxy of the rendered opaque geometry checks 2,501 rays through the
central road window, plus a positive check for low instruments at the bottom.
It also verifies that the old arch/pane components are absent, the new glass
fits entirely inside its frame, and the frame joins the roof and lower body.
Use `-- --capture-driver-view` without `--headless` for view screenshots.
`scripts/capture_train_clear_cab_world.gd` captures the actual gallery/world
scene with its real player and camera, both at the station and while driving.

`scripts/test_train_mouse_look.gd` loads the actual gallery and sends events
through its viewport. It checks R boarding, 3/4 views, mouse-look directions,
the eye/FOV, moving-train alignment, pitch limits, Esc release, GUI button
clicks, game-space recapture, inactive cameras and inspection. It does not call
the camera's `_input` directly or depend on pointer capture working headlessly.

Real-world inspiration: separate power, direction, throttle, brake and horn
controls described in the [FRA locomotive cab human-factors guidelines](https://railroads.dot.gov/sites/fra.dot.gov/files/fra_net/3291/Reports2011-2013.pdf).
