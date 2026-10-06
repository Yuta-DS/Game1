"""Build the World One root-stalker spec from the installed AnyCreature fixture.

The fixture supplies a tested quadruped rig; this variant changes its silhouette,
palette and motion to fit the Hope Path's living-root enemy.
"""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(
    "/Users/davidsovann/.codex/plugins/cache/personal/anycreature/"
    "1.2.0+codex.local.20260828/toolkit/example/wolf.json"
)
TARGET = ROOT / "assets3D/mind_spark/anycreature/root_stalker.json"

creature = json.loads(SOURCE.read_text())
creature["name"] = "hope_path_root_stalker"
creature["_template"] = (
    "World One enemy: a low, root-grown quadruped with heavier forequarters, "
    "paired branch antlers, a bark tail and mint-glowing eyes."
)
creature["palette"].update(
    {
        "fur_body": {"color": "#5d735f", "rough": 0.96},
        "fur_head": {"color": "#617c65", "rough": 0.96},
        "fur_tail": {"color": "#415a49", "rough": 0.96},
        "fur_leg": {"color": "#6d6854", "rough": 0.97},
        "fur_paw": {"color": "#514e41", "rough": 0.97},
        "nose": {"color": "#303e37", "rough": 0.85},
        "ear": {"color": "#50634d", "rough": 0.94},
        "eye": {"color": "#7ce9d9", "rough": 0.25},
        "root_antler": {"color": "#8d6f4b", "rough": 0.92},
    }
)
for volume in creature["volumes"]:
    if volume["chain"] == "body":
        volume["profile"][3][1] *= 1.24
        volume["profile"][3][2] *= 1.13
        volume["colors"]["arcs"] = [
            {"from": 0, "to": 55, "color": "#354d40"},
            {"from": 135, "to": 180, "color": "#627b65"},
        ]
    elif volume["chain"] == "head":
        volume["colors"]["arcs"] = [
            {"from": 0, "to": 52, "color": "#3d5d4a"},
            {"from": 128, "to": 180, "color": "#73937a"},
        ]
    elif volume["chain"] == "tail":
        for row in volume["profile"]:
            row[1] *= 1.22
            row[2] *= 1.22
        volume["colors"]["arcs"] = [
            {"from": 0, "to": 55, "color": "#294638"}
        ]

creature["parts"].append(
    {
        "type": "curve",
        "host": "HeadRoot",
        "material": "root_antler",
        "mirrored": True,
        "offset": [0.14, 0.13, -0.10],
        "dir": [0.82, 0.42, -0.18],
        "sides": 7,
        "segments": [
            {"len": 0.19, "r": 0.060, "rise": 8},
            {"len": 0.21, "r": 0.045, "behind": 13},
            {"len": 0.18, "r": 0.018, "rise": 9, "taper": True},
        ],
    }
)

creature["animations"]["attack"] = {
    "duration": 0.7,
    "loop": False,
    "tracks": {
        "Hips": {"tz": [[0, 0], [0.25, -0.04], [0.55, 0.12], [1, 0]]},
        "Chest": {"rx": [[0, 0], [0.25, -5], [0.55, 8], [1, 0]]},
        "NeckB": {"rx": [[0, 0], [0.3, -6], [0.58, 16], [1, 0]]},
        "HeadRoot": {"rx": [[0, 0], [0.3, -8], [0.58, 14], [1, 0]]},
    },
}
TARGET.parent.mkdir(parents=True, exist_ok=True)
TARGET.write_text(json.dumps(creature, indent=2) + "\n")
print(TARGET)
