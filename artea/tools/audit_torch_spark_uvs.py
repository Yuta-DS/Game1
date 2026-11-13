"""Report whether Torch Spark Socket materials have usable, non-degenerate UVs."""

from __future__ import annotations

from collections import defaultdict
from pathlib import Path

import bpy


BLEND_FILE = Path(
    "/Users/davidsovann/GAME/Crystal_Star_Pedestal/"
    "crystal_star_pedestal_textured_master.blend"
)


def main() -> None:
    bpy.ops.wm.open_mainfile(filepath=str(BLEND_FILE))
    totals = defaultdict(lambda: {"objects": 0, "degenerate": 0, "tiny": 0, "samples": []})
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or not obj.data.polygons or not obj.data.uv_layers:
            continue
        material = obj.material_slots[0].material
        name = material.name if material else "<none>"
        uv_data = obj.data.uv_layers.active.data
        coords = [uv_data[loop_index].uv for polygon in obj.data.polygons for loop_index in polygon.loop_indices]
        min_u = min(uv.x for uv in coords)
        max_u = max(uv.x for uv in coords)
        min_v = min(uv.y for uv in coords)
        max_v = max(uv.y for uv in coords)
        area = (max_u - min_u) * (max_v - min_v)
        row = totals[name]
        row["objects"] += 1
        row["degenerate"] += int(area <= 1e-8)
        row["tiny"] += int(area < 0.01)
        if len(row["samples"]) < 4:
            row["samples"].append((obj.name, round(area, 5), len({(round(uv.x, 5), round(uv.y, 5)) for uv in coords})))
    for name, row in sorted(totals.items()):
        print(
            f"UV_AUDIT {name}: objects={row['objects']} degenerate={row['degenerate']} "
            f"tiny={row['tiny']} samples={row['samples']}"
        )


if __name__ == "__main__":
    main()
