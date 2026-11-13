#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
build_dir="${project_dir}/builds/web"
public_alias="artea-web.vercel.app"
project_alias="artea-web-dsovann80-2407s-projects.vercel.app"
local_manifest="${build_dir}/index.pck.parts.json"
content_manifest="${build_dir}/content.pck.parts.json"
public_api_url="${ARTEA_PUBLIC_API_BASE_URL:-}"

if [[ -z "${public_api_url}" ]]; then
	echo "Set ARTEA_PUBLIC_API_BASE_URL to the deployed HTTPS Artéa API before publishing." >&2
	exit 1
fi

if [[ ! -f "${local_manifest}" ]]; then
	echo "No split Web pack found. Run scripts/export_web.sh first." >&2
	exit 1
fi
if [[ ! -f "${content_manifest}" ]]; then
	echo "No split content pack found. Run scripts/export_web.sh first." >&2
	exit 1
fi

# ./web rebuild recreates this generated directory without the deployment
# metadata that export_web.sh installs. Keep both local build paths deployable.
cp "${project_dir}/tools/vercel-pack-split/vercel.json" "${build_dir}/vercel.json"
cp "${project_dir}/tools/vercel-pack-split/.vercelignore" "${build_dir}/.vercelignore"

# The Godot client uses this value on a public host. Local ./web still selects
# 127.0.0.1:8000 and never needs a hosted account server.
python3 - "${build_dir}/index.html" "${public_api_url}" <<'PY'
import json
from pathlib import Path
import sys
from urllib.parse import urlparse

index = Path(sys.argv[1])
api_url = sys.argv[2].rstrip("/")
parsed = urlparse(api_url)
if parsed.scheme != "https" or not parsed.netloc or parsed.path:
    raise SystemExit("ARTEA_PUBLIC_API_BASE_URL must be an HTTPS origin")
html = index.read_text(encoding="utf-8")
marker = '<script src="pck-loader.js"></script>'
config = f'<script>window.ARTEA_API_BASE_URL = {json.dumps(api_url)};</script>'
if marker not in html:
    raise SystemExit("Cannot find the Godot loader in index.html")
if "window.ARTEA_API_BASE_URL =" not in html:
    html = html.replace(marker, config + "\n" + marker, 1)
else:
    import re
    html = re.sub(r'<script>window\.ARTEA_API_BASE_URL = .*?</script>',
                  config, html, count=1)
index.write_text(html, encoding="utf-8")
PY

(
	cd "${build_dir}"
	# build_dir is generated and may have lost its .vercel link after a rebuild.
	# Bind it to the existing production project before uploading anything.
	npx vercel link --yes --project artea-web
	# A link may download a short-lived OIDC token into this generated folder.
	# The deployment only needs .vercel/project.json; never upload the token.
	rm -f .env.local
	npx vercel --prod --yes
	npx vercel alias set "${project_alias}" "${public_alias}"
)

for attempt in {1..8}; do
	if ! remote_manifest="$(curl -fsSL \
		"https://${public_alias}/index.pck.parts.json?build=$(date +%s)-${attempt}")" \
		|| ! remote_content_manifest="$(curl -fsSL \
		"https://${public_alias}/content.pck.parts.json?build=$(date +%s)-${attempt}")"; then
		[[ "${attempt}" -lt 8 ]] && sleep 2
		continue
	fi
	if python3 - "${local_manifest}" "${remote_manifest}" \
		"${content_manifest}" "${remote_content_manifest}" <<'PY'
import json
import pathlib
import sys

local = json.loads(pathlib.Path(sys.argv[1]).read_text())
remote = json.loads(sys.argv[2])
local_content = json.loads(pathlib.Path(sys.argv[3]).read_text())
remote_content = json.loads(sys.argv[4])
if local != remote or local_content != remote_content:
    raise SystemExit(
        "Public Web pack manifests do not match the local export"
    )
print(
    "Production alias verified: core "
    f"{remote['count']} parts, {remote['bytes']} bytes; content "
    f"{remote_content['count']} parts, {remote_content['bytes']} bytes"
)
PY
	then
		exit 0
	fi
	if [[ "${attempt}" -lt 8 ]]; then
		sleep 2
	fi
done
echo "Production alias did not serve the new pack manifest after retrying." >&2
exit 1
