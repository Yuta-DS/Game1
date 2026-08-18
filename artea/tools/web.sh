#!/usr/bin/env bash
# Build and play Artéa in a browser with one command.
#
#   ./artea/tools/web.sh              # export if needed, then serve + open
#   ./artea/tools/web.sh --rebuild    # force a fresh export first
#   ./artea/tools/web.sh --serve-only # skip the export, just serve what exists
#   ./artea/tools/web.sh --port 9000  # pick the port (default 8800)
#
# Why this exists:
#
# * The editor most often launched here is the Mono/.NET build, and Godot 4
#   cannot export to Web from a Mono build at all - it fails with "Exporting to
#   Web is currently not supported in Godot 4 when using C#/.NET".  So this
#   script hunts for a NON-Mono Godot and refuses to continue without one,
#   instead of producing a confusing half-failure.
# * A Godot web build cannot be opened from disk.  index.html fetches the pack
#   and the wasm, and file:// origins are opaque, so those requests fail.  It
#   needs a real HTTP origin, which is why serving is part of the same command.
# * The Vercel export path splits index.pck into parts and DELETES the whole
#   pack.  That is right for deploying and wrong for playing locally, so this
#   script exports plainly and keeps index.pck intact.
set -euo pipefail

port=8800
mode=auto

while [[ $# -gt 0 ]]; do
	case "$1" in
		--rebuild)    mode=rebuild; shift ;;
		--serve-only) mode=serve;   shift ;;
		--port)       port="${2:?--port needs a number}"; shift 2 ;;
		-h|--help)    sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
	esac
done

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${project_dir}/builds/web"
index="${build_dir}/index.html"

find_godot() {
	# Prefer an explicit GODOT_BIN, then anything on PATH, then the usual
	# install locations.  Any Mono build is skipped: it cannot export Web.
	local candidates=()
	[[ -n "${GODOT_BIN:-}" ]] && candidates+=("${GODOT_BIN}")
	command -v godot >/dev/null 2>&1 && candidates+=("$(command -v godot)")
	candidates+=(
		"${HOME}/Downloads/Godot.app/Contents/MacOS/Godot"
		"${HOME}/Applications/Godot.app/Contents/MacOS/Godot"
		"/Applications/Godot.app/Contents/MacOS/Godot"
	)
	for candidate in "${candidates[@]}"; do
		[[ -x "${candidate}" ]] || continue
		"${candidate}" --version 2>/dev/null | grep -qi mono && continue
		printf '%s' "${candidate}"
		return 0
	done
	return 1
}

if [[ "${mode}" != serve ]]; then
	if [[ "${mode}" == rebuild || ! -f "${index}" ]]; then
		godot_bin="$(find_godot)" || {
			echo "No non-Mono Godot 4 found." >&2
			echo "Web export does not work from a Mono/.NET build." >&2
			echo "Install the standard build, or set GODOT_BIN to it." >&2
			exit 1
		}
		echo "Exporting with ${godot_bin}"
		mkdir -p "${build_dir}"
		# Import once so freshly changed assets are in the pack.  Without this a
		# rebuilt .glb silently exports at its previous revision.
		"${godot_bin}" --headless --path "${project_dir}" \
			--editor --quit-after 2000 >/dev/null 2>&1 || true
		"${godot_bin}" --headless --path "${project_dir}" \
			--export-release Web "${index}"
		echo
	fi
fi

if [[ ! -f "${index}" ]]; then
	echo "No build at ${build_dir} - run without --serve-only to export one." >&2
	exit 1
fi

url="http://localhost:${port}/index.html"
echo "Serving ${build_dir}"
echo "  ${url}"
echo "First load pulls the whole pack - give it a minute. Ctrl-C to stop."
echo

( sleep 1; open "${url}" ) &

exec python3 -m http.server "${port}" --bind 127.0.0.1 --directory "${build_dir}"
