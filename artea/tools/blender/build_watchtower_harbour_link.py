"""Editable village-style watchtower terrace. Coordinates below are Godot Y-up."""
import math
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).parent))
import build_coastal_harbour as kit


def xyz(p):
    return (p[0], -p[2], p[1])


def main():
    kit.reset_scene()
    target = kit.collection("WATCHTOWER_HARBOUR_LINK")
    root = kit.parent_root("WatchtowerHarbourLink", (0, 0, 0), target)
    mats = {
        "wood": kit.material("HoneyWood", (.48, .23, .095)),
        "light": kit.material("SunBleachedWood", (.66, .36, .16)),
        "dark": kit.material("DarkWood", (.27, .12, .065)),
        "iron": kit.material("VillageIron", (.19, .28, .34)),
        "red": kit.material("VillageRoofRed", (.78, .045, .065)),
        "cream": kit.material("PearlSail", (.91, .90, .81)),
        "stone": kit.material("CoastalStone", (.38, .44, .43)),
        "lamp": kit.material("WarmOilLamp", (1, .48, .12), emission=.7),
    }

    def box(name, p, size, mat="wood", collision=False, bevel=.04):
        obj = kit.cube(name, xyz(p), (size[0], size[2], size[1]), mats[mat], target, bevel)
        if collision:
            obj["harbour_collision"] = True
        return obj

    def bar(name, a, b, radius=.11, mat="wood", collision=False):
        obj = kit.beam(name, xyz(a), xyz(b), radius, mats[mat], target)
        if collision:
            obj["harbour_collision"] = True
        return obj

    def slab(name, points, bottom, top, mat, collision=False):
        verts = [xyz((x, y, z)) for y in (bottom, top) for x, z in points]
        n = len(points)
        faces = [tuple(range(n)), tuple(reversed(range(n, n * 2)))]
        faces += [(i + n, (i + 1) % n + n, (i + 1) % n, i) for i in range(n)]
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(verts, [], faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        target.objects.link(obj)
        obj.data.materials.append(mats[mat])
        if collision:
            obj["harbour_collision"] = True
        return obj

    def polar(r, a):
        return (r * math.cos(a), r * math.sin(a))

    # A low masonry footing meets the original tower's raised entrance exactly.
    slab("TowerStoneFooting", [polar(4.95, i * math.tau / 16) for i in range(16)],
         -.3, 1.8, "stone", True)
    for i in range(16):
        a, b = i * math.tau / 16, (i + 1) * math.tau / 16
        pts = [polar(4.7, a), polar(8, a), polar(8, b), polar(4.7, b)]
        slab(f"TerraceFloor_{i:02}", pts, 1.44, 1.77, "dark", True)
        # Broad tapered timber boards; fine seams do not split the collision floor.
        for j in range(5):
            r0, r1 = 4.7 + j * .66 + .025, 4.7 + (j + 1) * .66 - .025
            slab(f"RadialDeckBoard_{i:02}_{j}",
                 [polar(r0, a + .002), polar(r1, a + .002),
                  polar(r1, b - .002), polar(r0, b - .002)],
                 1.76, 1.8, "light" if (i + j) % 3 == 0 else "wood")
        x, z = polar(7.85, a)
        if i != 1:
            bar(f"TerracePile_{i:02}", (x, -.65, z), (x, 2.88, z), .19, collision=True)
            box(f"PileIronBand_{i:02}", (x, 2.6, z), (.44, .15, .44), "iron")
            box(f"PileCap_{i:02}", (x, 2.93, z), (.48, .15, .48), "light")
        # The first two eastern spans are the wide, unobstructed dock opening.
        if i not in (0, 1):
            ex, ez = polar(7.85, b)
            for height in (2.18, 2.72):
                bar(f"TerraceRail_{i:02}_{height}", (x, height, z),
                    (ex, height, ez), .10, "iron", True)
            bar(f"TerraceBrace_{i:02}", (x, .35, z), (ex, 1.4, ez), .13, "dark")

    # Scribe the bridge to the 16-sided terrace and stop at the berth edge.
    # No rectangular deck laid over either neighbour: this prevents z-fighting.
    bend = polar(8, math.pi / 8)
    corner = polar(8, math.pi / 4)
    north_x = 8 + (bend[0] - 8) * 1.443 / bend[1]
    south_x = bend[0] + (corner[0] - bend[0]) * (4.743 - bend[1]) / (corner[1] - bend[1])
    footprint = [(north_x, 1.443), (8.7049, 1.443), (8.7049, 4.743),
                 (south_x, 4.743), bend]
    slab("ConnectingWalkwayFloor", footprint, 1.44, 1.77, "dark", True)

    def clip_x(points, boundary, keep_greater):
        result = []
        for p, q in zip(points, points[1:] + points[:1]):
            pin = p[0] >= boundary if keep_greater else p[0] <= boundary
            qin = q[0] >= boundary if keep_greater else q[0] <= boundary
            if pin:
                result.append(p)
            if pin != qin:
                t = (boundary - p[0]) / (q[0] - p[0])
                result.append((boundary, p[1] + t * (q[1] - p[1])))
        return result

    for i in range(7):
        lo = south_x + i * (8.7049 - south_x) / 7
        hi = south_x + (i + 1) * (8.7049 - south_x) / 7
        points = clip_x(clip_x(footprint, lo + .012, True), hi - .012, False)
        if len(points) >= 3:
            slab(f"BridgePlank_{i:02}", points, 1.77, 1.8, "light" if i % 4 == 0 else "wood")
    for name, z, start in [("Shore", 1.443, north_x), ("Sea", 4.743, south_x)]:
        box(f"BridgeEdgeFascia_{name}", ((start + 8.7049) / 2, 1.55, z),
            (8.7049 - start, .3, .12), "light", bevel=.018)
    box("BridgeThreshold", (8.67, 1.79, 3.093), (.07, .02, 3.3), "dark", bevel=.004)
    # Rails meet the terrace rim without placing posts across the walking lane.
    for side, z, start in [("Shore", 1.443, 7.56), ("Sea", 4.743, 6.35)]:
        for h in (2.18, 2.72):
            bar(f"BridgeRail_{side}_{h}", (start, h, z), (8.70, h, z), .1, "iron", True)
        for x in (start, 8.70):
            bar(f"BridgePost_{side}_{x}", (x, -.4, z), (x, 2.85, z), .16, collision=True)
            box(f"BridgeCap_{side}_{x}", (x, 2.91, z), (.42, .16, .42), "light")
    for a, b in [((7.85, 0), (7.56, 1.443)), ((6.35, 4.743), (5.55, 5.55))]:
        for h in (2.18, 2.72):
            bar("OpeningReturnRail", (a[0], h, a[1]), (b[0], h, b[1]), .1, "iron", True)

    # Red gabled porch at the existing south-facing door, matching village roofs.
    for x in (-1.6, 1.6):
        # Wall brackets replace foot-level posts to leave the terrace unobstructed.
        bar("PorchWallBracket", (x, 4.25, 4.35), (x, 5.2, 5.95), .12, "dark")
    box("PorchHeader", (0, 5.2, 5.5), (3.7, .28, .3), "cream")
    for sign in (-1, 1):
        roof = box("PorchRedRoof", (sign * .92, 5.58, 5.12), (2.06, .18, 2.4), "red")
        roof.rotation_euler[1] = sign * math.radians(24)
    bar("PorchRidge", (0, 6.0, 3.8), (0, 6.0, 6.45), .13, "red")

    # Reading/fishing nook stays outside the 1.5m continuous walking lane.
    box("LookoutBenchSeat", (-4.85, 2.3, 0), (.66, .18, 2.4), "light", True)
    box("LookoutBenchBack", (-4.48, 2.72, 0), (.14, .64, 2.4), "wood", True)
    for z in (-.85, .85):
        box("BenchLeg", (-4.85, 2.02, z), (.4, .44, .23), "dark")
    for i, (x, z) in enumerate([(-5.45, 5.45), (-5.45, -5.45), (5.45, -5.45), (8.7, 1.443)]):
        bar(f"HarbourLampPost_{i}", (x, 1.8, z), (x, 4.5, z), .11, "dark", True)
        box(f"HarbourLampGlass_{i}", (x, 4.12, z), (.36, .5, .36), "lamp")
        for h in (3.83, 4.42):
            box(f"HarbourLampFrame_{i}_{h}", (x, h, z), (.49, .12, .49), "iron")
        kit.cone(f"HarbourLampRoof_{i}", xyz((x, 4.58, z)), .37, .05, .3, mats["red"], target, 4)
    root["style_reference"] = "Existing red-roof village and sea watchtower; no crystals"
    kit.reparent([o for o in target.objects if o != root], root)
    kit.export(root, kit.ASSET_DIR / "artea_watchtower_link.glb")
    bpy.ops.wm.save_as_mainfile(filepath=str(kit.SOURCE_DIR / "watchtower_harbour_link.blend"))
    print("WATCHTOWER_LINK_BUILD: PASS")


if __name__ == "__main__":
    main()
