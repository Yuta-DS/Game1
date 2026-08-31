# Trunk core and energy veins — detailed implementation contract

This specification implements `trunk_core_energy_veins_detail_v1.png` and fits
inside the approved `simple_tree_architecture_v2` design.

## Locked dimensions

| Element | Dimension |
| --- | --- |
| Trunk core height | 18.0 m |
| Root-flare outer diameter | 9.0 m |
| Neck outer diameter | 4.0 m |
| Doorway clear opening | 3.0 m wide x 4.2 m high |
| Heart-niche centre | 12.0 m above the foundation |
| Heart-niche clear volume | 5.0 m wide x 4.0 m high x 1.2 m deep |
| Structural bark ribs | 6 |
| Primary energy veins | 6 |
| Root-manifold outlets | 6 |
| Bough-socket endpoints | 8 |

## Blender source architecture

Use a collection named `TOL_TRUNK_CORE_SOURCE` containing:

1. `TOL_InnerShell` — a watertight tapered shell with modest radial topology.
2. `TOL_BarkRib_01` through `TOL_BarkRib_06` — six broad interwoven structural
   ribs following the shell surface.
3. `TOL_DoorwayArch` — the visible south-facing doorway frame.
4. `TOL_HeartRecess` — the recessed niche backing and mounting surface.
5. `TOL_RootManifold` — the six-outlet energy distribution ring.
6. `TOL_EnergyVein_01` through `TOL_EnergyVein_06` — bevelled source curves.
7. `SOCKET_Bough_01` through `SOCKET_Bough_08` — named empties at the neck.

The doorway and heart recess may be made with Blender Boolean modifiers, but
the modifiers must be applied in the export copy. Godot performs no runtime
booleans. Keep the editable curve and modifier versions in the source `.blend`.

### Inner shell

- Build the main taper as a 32-sided surface with three to five vertical control
  loops plus extra loops only around the doorway and niche.
- Keep the inside hollow and walkable. The interior floor connects directly to
  the foundation path.
- Model the doorway opening into the shell; do not place an opaque door mesh over
  a closed trunk.
- Use smooth shading with weighted normals. Bark micro-detail belongs in normal
  textures, not dense geometry.

### Structural ribs

- Six ribs start at evenly spaced root positions and braid by approximately 60°
  over the 18 m rise.
- Each rib is a low-resolution curve or strip during editing, then a mesh in the
  export collection.
- Three ribs pass left of the heart niche and three pass right. None may enter
  the protected clear volume.
- Ribs remain visual geometry. They do not receive individual collision shapes.

## Energy system

Six primary veins begin at the six root-manifold outlets and follow the six bark
ribs. At the heart niche, route three channels left and three right, preserving
the entire clear volume. They reconnect visually above the niche before reaching
the bough sockets.

Map six primary routes to eight sockets as follows:

| Vein | Socket destination |
| --- | --- |
| 01 | 01 |
| 02 | 02 |
| 03 | 03 and 04 |
| 04 | 05 and 06 |
| 05 | 07 |
| 06 | 08 |

Veins 03 and 04 each fork once above the heart clear zone. No other vein forks.

### Curve and export rules

- Use a 0.07–0.10 m bevel radius and a six-sided bevel profile.
- Set curve tilt so the profile does not twist at the niche split.
- Generate continuous longitudinal UVs: `UV.y = 0` at the root manifold and
  increases toward the bough sockets.
- glTF does not export Blender curves as runtime curves. Duplicate and convert
  the six veins to meshes in `TOL_TRUNK_CORE_EXPORT`; keep the original curves
  editable in the source collection.
- Join the export veins into one mesh with six disconnected islands and one cyan
  emissive material slot.

## Godot scene contract

```text
TrunkCore (Node3D)
├── InnerShellVisual (MeshInstance3D)
├── BarkRibsVisual (MeshInstance3D)
├── DoorwayArchVisual (MeshInstance3D)
├── HeartRecessVisual (MeshInstance3D)
├── EnergyVeinsVisual (MeshInstance3D, ShaderMaterial)
├── BoughSockets (Node3D: 8 Marker3D children)
└── CollisionProxies (StaticBody3D)
    ├── TrunkShellCollision
    ├── DoorwayLeftCollision
    ├── DoorwayRightCollision
    └── DoorwayTopCollision
```

Import the GLB modules as separate nodes. Energy veins are visual-only. Use the
inner-shell proxy and three doorway boxes for stable traversal collision.

### Web-safe emissive flow shader

The vein mesh uses one unshaded or lightly shaded cyan `ShaderMaterial`. Animate
only the emission value from longitudinal UVs and `TIME`:

```glsl
float phase = fract(UV.y * pulse_repeat - TIME * pulse_speed);
float pulse = smoothstep(0.70, 0.92, phase) * (1.0 - smoothstep(0.92, 1.0, phase));
EMISSION = base_cyan * (base_energy + pulse * pulse_energy);
```

This creates upward-moving light without bones, particles, per-frame GDScript,
or geometry animation. Clamp emission for the Web preset to avoid bloom washout.

## Geometry and runtime budgets

| System | Budget |
| --- | --- |
| Inner shell and openings | 20,000 triangles maximum |
| Six bark ribs | 24,000 triangles maximum combined |
| Doorway and heart recess | 6,000 triangles maximum combined |
| Root manifold and six veins | 10,000 triangles maximum combined |
| Trunk materials | bark, dark interior, cyan emissive, gold maximum |
| Animated objects | shader only; zero animated transforms |

## Acceptance checks

1. A 3.0 m wide player proxy can walk through the 4.2 m doorway without touching
   detailed bark collision.
2. Front and side projections show no rib or vein inside the heart clear volume.
3. The export contains exactly six primary veins and eight named bough sockets.
4. Every vein begins at a manifold outlet and ends at its assigned socket.
5. Vein UVs increase continuously from root to socket and the pulse travels up.
6. The Web build uses the same vein mesh and shader without particles or bones.
7. All source curves and modifiers remain editable in the `.blend` file.

