#!/usr/bin/env bash
# Build and play Artéa in a browser with one command.
#
#   ./artea/tools/web.sh              # export if needed, then serve + open
#   ./artea/tools/web.sh --rebuild    # force a fresh export first
#   ./artea/tools/web.sh --serve-only # skip the export, just serve what exists
#   ./artea/tools/web.sh --port 9000  # pick the port (default 8800)
#   ./artea/tools/web.sh --no-open    # serve without launching a browser
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
open_browser=1

while [[ $# -gt 0 ]]; do
	case "$1" in
		--rebuild)    mode=rebuild; shift ;;
		--serve-only) mode=serve;   shift ;;
		--no-open)    open_browser=0; shift ;;
		--port)       port="${2:?--port needs a number}"; shift 2 ;;
		-h|--help)    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

# Serve the same split layout the deploy uses.
#
# pck-loader.js intercepts index.pck and expects index.pck.partNN plus a
# manifest. Without them it fires 128 parallel HEAD probes that all 404, then
# falls back to fetching the whole pack in one blocking request - and python's
# http.server ignores Range headers, so that is a single unstreamed 708 MB
# response. The page just sits there, which reads as the build being broken
# when it is only the local server layout differing from the deployed one.
split_for_local() {
	# pck-loader.js intercepts both index.pck and index.side.wasm, so both need
	# the split layout locally or the loader stalls probing for parts that are
	# not there.
	local pck="$1"
	[[ -f "${pck}" ]] || return 0
	local pck_size
	# GNU stat (Linux, Git Bash on Windows) accepts -c; BSD stat (macOS) does
	# not and falls through to -f. The reverse order is a trap: GNU stat -f
	# means "filesystem status" and exits 0 with the wrong number instead of
	# erroring, so a -f-first probe silently poisons pck_size on those platforms.
	pck_size=$(stat -c '%s' "${pck}" 2>/dev/null || stat -f '%z' "${pck}")
	# Re-split whenever the file no longer matches its manifest. Skipping merely
	# because a manifest exists left a re-export serving the PREVIOUS export's
	# parts: the loader streamed a pack that disagreed with GODOT_CONFIG's
	# fileSizes, and the page sat at the loading bar forever with no error.
	if [[ -f "${pck}.parts.json" ]]; then
		local manifest_size
		manifest_size=$(sed -E 's/.*"bytes":([0-9]+).*/\1/' "${pck}.parts.json")
		[[ "${manifest_size}" == "${pck_size}" ]] && return 0
		echo "  $(basename "${pck}"): stale parts, re-splitting"
	fi
	rm -f "${pck}".part?? "${pck}.parts.json"
	split -b 8m "${pck}" "${pck}.part"
	local idx=0
	for part in "${pck}".part??; do
		mv "${part}" "$(printf '%s.part%02d' "${pck}" "${idx}")"
		idx=$((idx + 1))
	done
	printf '{"count":%d,"bytes":%d,"partBytes":%d}\n' \
		"${idx}" "${pck_size}" $((8 * 1024 * 1024)) \
		> "${pck}.parts.json"
	echo "  $(basename "${pck}"): ${idx} parts"
}

# The Web preset injects pck-loader.js through html/head_include, but a plain
# export does not copy it - only the Vercel export script does. Without it the
# page 404s the loader and the parts below go unused.
cp "${project_dir}/tools/vercel-pack-split/pck-loader.js" "${build_dir}/pck-loader.js"

echo "Checking split layout for local serving…"
split_for_local "${build_dir}/index.pck"
split_for_local "${build_dir}/index.side.wasm"

url="http://localhost:${port}/index.html"
echo "Serving ${build_dir}"
echo "  ${url}"
echo "First load pulls the whole pack - give it a minute. Ctrl-C to stop."
echo

open_url() {
	command -v open >/dev/null 2>&1 && { open "$1"; return; }       # macOS
	command -v xdg-open >/dev/null 2>&1 && { xdg-open "$1"; return; } # Linux
	command -v start >/dev/null 2>&1 && { start "$1"; return; }      # Git Bash / Windows
	echo "Don't know how to open a browser here - visit $1" >&2
}

if [[ "${open_browser}" == 1 ]]; then
	( sleep 1; open_url "${url}" ) &
fi

# Serve with caching switched off.  The stock `python3 -m http.server` sends
# neither Cache-Control nor ETag, so browsers fall back to heuristic freshness
# and can pair a cached index.js or index.wasm from an earlier export with a
# freshly exported pack.  The engine then fetches a pack whose size disagrees
# with its own GODOT_CONFIG and sits on the loading bar with no error at all.
exec python3 - "${port}" "${build_dir}" <<'PYSERVE'
import functools
import http.server
import sys


class NoStoreHandler(http.server.SimpleHTTPRequestHandler):
	def end_headers(self):
		self.send_header("Cache-Control", "no-store, must-revalidate")
		self.send_header("Pragma", "no-cache")
		super().end_headers()


port = int(sys.argv[1])
handler = functools.partial(NoStoreHandler, directory=sys.argv[2])
http.server.ThreadingHTTPServer(("127.0.0.1", port), handler).serve_forever()
PYSERVE
