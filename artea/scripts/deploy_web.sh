#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
build_dir="${project_dir}/builds/web"
public_alias="artea-web.vercel.app"
project_alias="artea-web-dsovann80-2407s-projects.vercel.app"
local_manifest="${build_dir}/index.pck.parts.json"

if [[ ! -f "${local_manifest}" ]]; then
	echo "No split Web pack found. Run scripts/export_web.sh first." >&2
	exit 1
fi

(
	cd "${build_dir}"
	npx vercel --prod --yes
	npx vercel alias set "${project_alias}" "${public_alias}"
)

remote_manifest="$(curl -fsSL \
	"https://${public_alias}/index.pck.parts.json?build=$(date +%s)")"
python3 - "${local_manifest}" "${remote_manifest}" <<'PY'
import json
import pathlib
import sys

local = json.loads(pathlib.Path(sys.argv[1]).read_text())
remote = json.loads(sys.argv[2])
if local != remote:
    raise SystemExit(
        f"Public Web pack does not match local export: local={local}, remote={remote}"
    )
print(
    "Production alias verified: "
    f"{remote['count']} parts, {remote['bytes']} bytes"
)
PY
