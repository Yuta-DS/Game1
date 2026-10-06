# Train gear transmission

The exposed gold, pink and cyan gears now share a single mechanical phase.
The imported meshes lie in local XZ; local Y is the axle. The former Z-axis
rotation tipped the discs sideways. Every frame now reapplies rotation around
Y from the preserved rest transform, so shafts cannot drift or tumble.

The original 20/16/14-tooth meshes had different tooth pitches and arbitrary
speed ratios. This runtime-only refit uses 30/20/14 common-pitch involute teeth
at module 0.0925 and 25-degree pressure angle, with 0.006 tooth clearance.
It retains the authored materials, hubs, rings and 0.24 face width; the large
gear's 1.48 outer radius is unchanged. The medium/small outer radii are 1.0175
and 0.74 (previously 0.96/0.70).

Pitch radii are 1.3875, 0.925 and 0.6475. Adjacent shaft distances are 2.3125
and 1.5725. The drive shaft stays put; the other shafts move slightly along
their original arrangement. Hubs and energy rings move with their gear.
Angular ratios are +1, -1.5 and +15/7. Initial tooth phases put a tooth into
the neighboring gap. The bounded phase repeats after 14 driver revolutions.

The driving gear follows the existing wheel drive phase. Reversing reverses
the transmission; braking brings it to rest. Existing compact connecting-rod
motion follows that phase rather than continuing to oscillate while parked.
The rods remain the existing decorative short-stroke linkage, not a new
force/torque or steam-physics simulation. Pressure effects remain independent.
Autopilot derives direction from travel rather than a stale reverse selection.

Gear pitch/spacing reference: [KHK spur-gear technical information](https://khkgears.net/pdf/2025/spur-gears.pdf).
This is a visual game mechanism, not a manufacturing specification.

## Verification

Run `scripts/test_train_gear_transmission.gd` with standard Godot. It covers
both sides over the complete 14-turn repeating cycle, tooth-profile overlap,
fixed centres/axles, linked hubs/rings, exact speed ratios, phase wrapping,
30/120 Hz equivalence, actual cab startup/forward/brake/reverse/stop commands,
and autopilot direction. A negative control rejects the former Z rotation.

`scripts/capture_train_gear_transmission.gd` creates a native mechanism close-up
of forward, stop, reverse, stop. It does not replace the real-driving test.

