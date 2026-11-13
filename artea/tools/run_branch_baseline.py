"""Bounded isolated Godot checks, retaining failures even when Godot exits zero."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("checkout", type=Path)
    parser.add_argument("--label", required=True)
    parser.add_argument("tests", nargs="+")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]+", args.label):
        parser.error("label must be filename-safe")
    output = ROOT / "artea/artifacts/branch_compatibility" / args.label
    output.mkdir(parents=True, exist_ok=True)
    sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=args.checkout).decode().strip()
    rows = []
    for test in args.tests:
        if not re.fullmatch(r"test_[a-zA-Z0-9_]+\.gd", test):
            parser.error("expected a test filename")
        source = args.checkout / "artea/scripts" / test
        row = dict(test=test, sha=sha)
        if not source.is_file():
            row["status"] = "UNAVAILABLE"
        else:
            command = [GODOT, "--headless", "--path", str(args.checkout / "artea"),
                       "--script", "res://scripts/" + test]
            start = time.monotonic()
            log = output / (source.stem + ".log")
            with log.open("w") as stream:
                try:
                    result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=90)
                    row["exit_code"] = result.returncode
                except subprocess.TimeoutExpired:
                    row["status"] = "TIMEOUT"
            content = log.read_text(errors="replace")
            row["seconds"] = round(time.monotonic() - start, 2)
            row["errors"] = [line for line in content.splitlines()
                             if re.search(r"SCRIPT ERROR:|^ERROR:|\bFAIL(?:ED)?\b", line)]
            row["warnings"] = [line for line in content.splitlines() if "WARNING:" in line]
            row["success_markers"] = [line for line in content.splitlines()
                                      if re.search(r"\bPASS\b|ALL.*PASSED", line)]
            row.setdefault("status", "FAIL" if row["exit_code"] != 0 or row["errors"] else "PASS")
            row["log"] = str(log)
        rows.append(row)
        (output / "results.json").write_text(json.dumps(rows, indent=2) + "\n")
        print(test, row["status"], flush=True)


if __name__ == "__main__":
    main()
