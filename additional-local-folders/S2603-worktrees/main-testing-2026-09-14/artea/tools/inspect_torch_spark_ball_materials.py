"""List ball-like Torch Spark Socket components and their materials."""

from pathlib import Path

import bpy


BLEND_FILE = Path(
    "/Users/davidsovann/GAME/Crystal_Star_Pedestal/"
    "crystal_star_pedestal_textured_master.blend"
)


def main() -> None:
    bpy.ops.wm.open_mainfile(filepath=str(BLEND_FILE))
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        material = obj.material_slots[0].material if obj.material_slots else None
        material_name = material.name if material else "<none>"
        name = f"{obj.name} {obj.data.name}".lower()
        if not (
            any(token in name for token in ("sphere", "orb", "node", "core"))
            or material_name in {"White_Star_Glow", "Violet_Energy", "Cyan_Energy", "Orb_Glass"}
        ):
            continue
        print(
            "BALL_MATERIAL "
            f"object={obj.name!r} mesh={obj.data.name!r} "
            f"material={material_name!r} polygons={len(obj.data.polygons)} "
            f"dimensions={tuple(round(v, 3) for v in obj.dimensions)} "
            f"location={tuple(round(v, 3) for v in obj.location)}"
        )


if __name__ == "__main__":
    main()
