#!/usr/bin/env bash
# Serve a Godot web build over HTTP and open it in a browser.
#
# The build cannot be opened from the filesystem — index.html fetches the pack
# and the wasm, and file:// origins are opaque, so those requests fail. It needs
# a real HTTP origin, which is all this does.
#
#   ./artea/tools/serve-web.sh                    # default build, default browser
#   ./artea/tools/serve-web.sh 9000               # pick the port
#   ./artea/tools/serve-web.sh 9000 Safari        # pick the browser
#
# Ctrl-C to stop.
set -euo pipefail

port="${1:-8800}"
browser="${2:-}"
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${BUILD_DIR:-${project_dir}/builds/web_corey}"

if [[ ! -f "${build_dir}/index.html" ]]; then
	echo "No build at ${build_dir}" >&2
	echo "Export one first: Godot › Project › Export › Web, or set BUILD_DIR." >&2
	exit 1
fi

url="http://localhost:${port}/index.html"

echo "Serving ${build_dir}"
echo "  ${url}"
echo
echo "First load downloads the whole pack (~490 MB) — give it a minute."
echo "Ctrl-C to stop."
echo

# Hand the browser a moment to find the port after the server is up.
(
	sleep 1
	if [[ -n "${browser}" ]]; then
		open -a "${browser}" "${url}"
	else
		open "${url}"
	fi
) &

exec python3 -m http.server "${port}" --bind 127.0.0.1 --directory "${build_dir}"
