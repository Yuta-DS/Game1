# Rooftop bow replaced with royal fountain — 28 August 2026

## Local result

Removed the rooftop ballista construction and replaced it with a two-tier,
cream/blue-grey stone fountain with a small gold spout. Four animated crown
jets feed the upper basin and four cascades feed the lower basin. Both water
surfaces have animated ripples. No new lights, particles, textures or external
asset dependencies were added.

The fountain stays in the former display's quadrant, moved 0.65 m inward to
leave an aisle beside the perimeter planting. The stone bowls, rims and
pedestal are solid. Basin floors match their visible stone surfaces; water is
only 15 mm above them. Existing rooftop floor, barriers and stairs are unchanged.
The lean-build skill guided reuse of the palace palette and current build path.

## Checks passed in this cycle

- Fountain: bow absent, water-animation clocks advance, eight solid rim ray
  probes, eight player impacts/escapes, complete surrounding aisle, three real
  capsule landing/exits onto basin/rim/upper-bowl regions. Gravity was allowed
  to settle the player after stepping off; the test does not teleport exits.
- Rooftop garden/palace traversal and planter landings: PASS.
- All three spiral stair lanes and crown circuit: PASS.
- Six rooftop perimeter impact/escape cases: PASS.
- Castle professional regression: PASS, 182 bridge-volume meshes / two lights.
  Its underlying-floor ray test now excludes the intentionally solid fountain;
  fountain support is tested separately rather than mistaken for a floor gap.
- Web environment compatibility policy: PASS.
- Restricted source whitespace check: PASS.
- Native Godot Compatibility renderer captured roof views 15–20. Overview and
  `20_royal_fountain_detail.png` were visually inspected. Water shaders compiled.

## Publishing limitation

Disk space remains insufficient: the latest check showed only 619 MiB free,
after earlier checks at 116 MiB. Previous exports already failed from a full
disk. No export or production deployment was attempted in this cycle, and no
new deployment ID or browser verification exists for the fountain update.
https://artea-web.vercel.app/ is the existing destination, not a verified live
version of this result.

Free at least 3 GB to resume export, deployment and real WebGL2 startup/gameplay
verification. No unrelated files were deleted. No commit or push was performed.
