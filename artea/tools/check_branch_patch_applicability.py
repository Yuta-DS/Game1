"""Dry-run tracked local Artea edits against pinned remote trees; never merge.

This deliberately excludes untracked assets and committed feature history.
A clean patch check is NOT full integration or runtime proof.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artea/artifacts/branch_compatibility"


def main():
    inventory = json.loads((OUT / "remote-matrix.json").read_text())
    patch = subprocess.check_output(
        ["git", "diff", "--binary", "--no-ext-diff", "HEAD", "--", "artea/"], cwd=ROOT)
    rows = []
    with tempfile.TemporaryDirectory(prefix="mindspark-patch-index-") as temporary:
        env = dict(os.environ, GIT_INDEX_FILE=str(Path(temporary) / "index"))
        for branch in inventory["branches"]:
            subprocess.run(["git", "read-tree", branch["sha"]], cwd=ROOT, env=env, check=True)
            result = subprocess.run(["git", "apply", "--cached", "--check", "--whitespace=nowarn", "-"],
                                    input=patch, cwd=ROOT, env=env, capture_output=True)
            rows.append(dict(branch=branch["branch"], sha=branch["sha"],
                             tracked_patch="APPLIES" if result.returncode == 0 else "DOES_NOT_APPLY",
                             diagnostic=result.stderr.decode(errors="replace")))
    report = dict(patch_sha256=hashlib.sha256(patch).hexdigest(), branches=rows,
                  scope="Only tracked uncommitted Artea diff against HEAD. No untracked assets or committed feature integration; no runtime or performance proof.")
    (OUT / "tracked-patch-check.json").write_text(json.dumps(report, indent=2) + "\n")
    for row in rows:
        print(row["branch"], row["tracked_patch"])


if __name__ == "__main__":
    main()
