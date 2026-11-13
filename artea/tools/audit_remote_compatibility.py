"""Read-only remote comparison. Overlap is risk evidence, not a merge/test pass."""
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artea/artifacts/branch_compatibility"
PRIORITY = ["main", "performance-tweak", "Javid-fix-ipad-phone-scale",
            "splash-screen", "stutter-fix", "spawn-cleanup-and-performance-optimisation",
            "spawn-and-train-cleanup-with-performance-optimisation", "general_optimisation"]


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT).decode("utf-8")


def paths(*args):
    # Path-level risk inventory: retain both old/new paths for renames instead
    # of allowing Git's rename limit to silently change coverage on old refs.
    options = ("--no-renames",) if args[0] == "diff" else ()
    return set(filter(None, git(*args, *options, "-z").split("\0")))


def main():
    head = git("rev-parse", "HEAD").strip()
    changed = paths("diff", "--name-only", "HEAD")
    added = paths("ls-files", "--others", "--exclude-standard")
    local_paths = {p for p in changed | added if p.startswith("artea/")}
    fingerprint = hashlib.sha256()
    for path in sorted(local_paths):
        file = ROOT / path
        fingerprint.update(path.encode())
        if file.is_file():
            with file.open("rb") as source:
                for chunk in iter(lambda: source.read(1024 * 1024), b""):
                    fingerprint.update(chunk)
    refs = git("for-each-ref", "--format=%(refname)|%(objectname)|%(symref)", "refs/remotes/origin").splitlines()
    rows = []
    for item in refs:
        ref, sha, symbolic = item.split("|")
        if symbolic:
            continue
        name = ref.removeprefix("refs/remotes/origin/")
        try:
            base = git("merge-base", head, sha).strip()
        except subprocess.CalledProcessError:
            rows.append(dict(branch=name, sha=sha, status="NO_COMMON_ANCESTOR", runtime="NOT_TESTED"))
            continue
        remote_paths = paths("diff", "--name-only", base, sha)
        local_committed = paths("diff", "--name-only", base, head)
        shared = sorted(remote_paths & (local_paths | local_committed))
        tree = paths("ls-tree", "-r", "--name-only", sha)
        rows.append(dict(branch=name, sha=sha, merge_base=base,
                         remote_changed_files=len(remote_paths), overlapping_paths=shared,
                         dirty_worktree_overlaps=sorted(remote_paths & local_paths),
                         has_godot_project="artea/project.godot" in tree,
                         available_tests=sorted(p for p in tree if p.startswith("artea/scripts/test_") and p.endswith(".gd")),
                         status="SOURCE_OVERLAP" if shared else "NO_SOURCE_OVERLAP_DETECTED",
                         runtime="NOT_TESTED", integration="NOT_TESTED", performance="NOT_MEASURED"))
    rows.sort(key=lambda r: (PRIORITY.index(r["branch"]) if r["branch"] in PRIORITY else len(PRIORITY), r["branch"]))
    report = dict(created_utc=datetime.now(timezone.utc).isoformat(), head=head,
                  current_branch=git("branch", "--show-current").strip(),
                  local_artea_changes_sha256=fingerprint.hexdigest(), branches=rows,
                  limitation="Source overlap is not proof of conflict, compatibility, runtime correctness or performance. No branches merged or modified.")
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "remote-matrix.json").write_text(json.dumps(report, indent=2) + "\n")
    lines = ["# Remote compatibility baseline", "", report["limitation"], "",
             f"Current HEAD: `{head}`. Remote branches inventoried: {len(rows)}.", "",
             "| Branch | SHA | Changed upstream | Overlap | Runtime |",
             "|---|---|---:|---:|---|"]
    for row in rows:
        lines.append(f"| {row['branch']} | {row['sha'][:10]} | {row.get('remote_changed_files', '—')} | {len(row.get('overlapping_paths', []))} | NOT TESTED |")
    (OUT / "remote-matrix.md").write_text("\n".join(lines) + "\n")
    print(f"Inventoried {len(rows)} remote branches; no runtime/integration passes claimed.")
    for row in rows[:len(PRIORITY)]:
        print(f"{row['branch']}: {row['sha'][:10]}, {len(row.get('dirty_worktree_overlaps', []))} overlaps with uncommitted Artea changes")


if __name__ == "__main__":
    main()
