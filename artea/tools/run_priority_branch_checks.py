"""Run reviewed branch baselines in the agent-created detached checkout only.

Never force checkout, reset, merge, commit, or push. Stop on instruction changes.
"""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
CHECKOUT = Path("/private/tmp/mindspark-branch-check.fpIrPm")
BASE = "d5154fb27ef8803911d0a7b536c2b25791c214a0"
NAMES = ["Javid-fix-ipad-phone-scale", "splash-screen", "stutter-fix",
         "spawn-cleanup-and-performance-optimisation"]
TESTS = ["test_web_environment_compat.gd", "test_castle_entrance.gd",
         "test_player_ground_visual_alignment.gd", "test_art_castle_gallery_flow.gd",
         "test_world_minimap.gd", "test_story_crown_railway.gd"]


def main():
    output = ROOT / "artea/artifacts/branch_compatibility"
    branches = json.loads((output / "remote-matrix.json").read_text())["branches"]
    for name in (sys.argv[1:] or NAMES):
        row = next(item for item in branches if item["branch"] == name)
        instructions = subprocess.check_output(
            ["git", "diff", "--name-only", BASE, row["sha"], "--", "*AGENT*"], cwd=ROOT)
        if instructions.strip():
            raise RuntimeError(f"Read branch instructions before testing {name}")
        modifications = subprocess.check_output(
            ["git", "diff", "--name-only", "--", ".", ":!*.import"], cwd=CHECKOUT)
        if modifications.strip():
            raise RuntimeError("Unexpected non-import edits in isolated checkout; refusing switch")
        label = name + "-" + row["sha"][:8]
        with (output / (label + "-switch.log")).open("w") as log:
            subprocess.run(["git", "switch", "--detach", row["sha"]], cwd=CHECKOUT,
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        subprocess.run([sys.executable, str(ROOT / "artea/tools/run_branch_baseline.py"),
                        str(CHECKOUT), "--label", label, *TESTS], check=True)


if __name__ == "__main__":
    main()
