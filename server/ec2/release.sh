#!/usr/bin/env bash
# Packs a release for install.sh: the Flask server as committed (git HEAD) and
# the Web export in artea/builds/web, in one file the client can upload.
# Run from Git Bash in the repo, after `./web rebuild` and `./web verify`:
#
#   server/ec2/release.sh        -> artea/builds/artea-release.tar
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${ROOT}/artea/builds/web"
OUT="${ROOT}/artea/builds/artea-release.tar"
[[ -f "${BUILD}/index.html" ]] || { echo "No Web export in ${BUILD}: run ./web rebuild" >&2; exit 1; }
[[ -f "${BUILD}/.export-in-progress" ]] && { echo "The export is still running" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT
mkdir -p "${STAGE}/artea-release/www"
# autocrlf off: on Windows the archive would otherwise carry CRLF line endings,
# and bash on the server rejects scripts with them.
git -C "${ROOT}" -c core.autocrlf=false archive --prefix=artea-release/ HEAD server \
	| tar -x -C "${STAGE}"

# Only what the game loads: every top-level file except whole packs and the
# side module (both fetched as parts), editor .import files, build markers and
# stale unhashed parts, plus the hashed parts each manifest names. The build
# folder is ~1 GB; this is about 380 MB.
files="$(cd "${BUILD}" && python - <<'EOF'
import json, pathlib, re
names = []
for path in sorted(pathlib.Path(".").iterdir()):
    name = path.name
    if not path.is_file() or name.startswith(".") or name == "import.log" or name.endswith(".import"):
        continue
    if pathlib.Path(name + ".parts.json").exists() or re.search(r"\.pck\.part[a-z0-9]+$", name):
        continue
    names.append(name)
    if name.endswith(".parts.json"):
        parts = json.loads(path.read_text(encoding="utf-8")).get("parts")
        if not parts:
            raise SystemExit(f"{name} lists no hashed parts: re-export with ./web rebuild")
        names += [part["name"] for part in parts]
print("\n".join(names))
EOF
)"
files="$(echo "${files}" | tr -d '\r')"  # Windows Python ends lines with \r\n
(cd "${BUILD}" && echo "${files}" | tar -cf - -T -) | tar -x -C "${STAGE}/artea-release/www"

# What is in it, for when someone asks which version is running.
{
	echo "server: $(git -C "${ROOT}" log -1 --format='%h %cd' --date=short HEAD)"
	echo "game:   $(cat "${BUILD}/.export-git-head" 2>/dev/null || echo unknown) (built $(date -r "${BUILD}/index.html" +%F))"
} > "${STAGE}/artea-release/VERSION"

tar -cf "${OUT}" -C "${STAGE}" artea-release
echo "Wrote ${OUT} ($(du -m "${OUT}" | cut -f1) MB, $(echo "${files}" | wc -l) game files)"
cat "${STAGE}/artea-release/VERSION"
