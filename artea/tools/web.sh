#!/usr/bin/env bash
# Build and play Artéa in a browser with one command.
#
#   ./artea/tools/web.sh              # export if needed, then serve + open
#   ./artea/tools/web.sh --rebuild    # force a fresh export first
#   ./artea/tools/web.sh --serve-only # skip the export, just serve what exists
#   ./artea/tools/web.sh --export-only # refresh the build without serving
#   ./artea/tools/web.sh --port 9000  # pick the port (default 8800)
#   ./artea/tools/web.sh --no-open    # serve without launching a browser
#   ./artea/tools/web.sh --prod-cache # serve with the deployed cache headers
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
cache_mode=no-store

while [[ $# -gt 0 ]]; do
	case "$1" in
		--rebuild)    mode=rebuild; shift ;;
		--serve-only) mode=serve;   shift ;;
		--export-only) mode=export; shift ;;
		--no-open)    open_browser=0; shift ;;
		--prod-cache) cache_mode=prod; shift ;;
		--port)       port="${2:?--port needs a number}"; shift 2 ;;
		-h|--help)    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
	esac
done

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${project_dir}/builds/web"
index="${build_dir}/index.html"
pack="${build_dir}/index.pck"
export_head="${build_dir}/.export-git-head"

export_is_stale() {
	[[ -f "${index}" && -f "${pack}" && -f "${export_head}" ]] || return 0
	local current_head
	current_head="$(git -C "${project_dir}" rev-parse HEAD 2>/dev/null)" || return 0
	[[ "$(cat "${export_head}")" == "${current_head}" ]] || return 0
	# Generated imports and outputs change while exporting; only project inputs
	# should make the next ./web rebuild automatically.
	if find "${project_dir}" \
		\( -type d \( -name .godot -o -name builds -o -name artifacts \
			-o -name __pycache__ \) -prune \) -o \
		\( -type f ! -name '*.import' ! -name '*.uid' ! -name '*.log' \
			! -name '*.md' ! -name '*.gguf' ! -name '.DS_Store' \
			-newer "${pack}" -print -quit \) \
		| grep -q .; then
		return 0
	fi
	return 1
}

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
	if [[ "${mode}" == rebuild ]] || export_is_stale; then
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
		# The wrapper turns on the Web-only export plugins (texture slimming,
		# issue #39) without enabling them for desktop exports.
		"${project_dir}/tools/with-web-export-plugins.sh" \
			"${godot_bin}" --headless --path "${project_dir}" \
			--export-release Web "${index}"
		python3 "${project_dir}/tools/patch_web_release_loader.py" "${index}"
		git -C "${project_dir}" rev-parse HEAD > "${export_head}"
		echo
	fi
fi

if [[ ! -f "${index}" ]]; then
	echo "No build at ${build_dir} - run without --serve-only to export one." >&2
	exit 1
fi

# Serve the same split layout the deploy uses.
#
# pck-loader.js intercepts index.pck and index.side.wasm and expects a manifest
# plus parts. Without them it fires 128 parallel HEAD probes that all 404, then
# falls back to fetching the whole pack in one blocking request - and python's
# http.server ignores Range headers, so that is a single unstreamed 708 MB
# response. The page just sits there, which reads as the build being broken
# when it is only the local server layout differing from the deployed one.
#
# split-pack.sh names parts by the file's content hash and re-splits whenever
# the hash changes, so a re-export can never serve the previous export's parts
# (web.txt Problem 2) - the old size check only caught exports that also
# changed size.
# The Web preset injects pck-loader.js through html/head_include, but a plain
# export does not copy it - only the Vercel export script does. Without it the
# page 404s the loader and the parts below go unused.
cp "${project_dir}/tools/vercel-pack-split/pck-loader.js" "${build_dir}/pck-loader.js"

echo "Checking split layout for local serving…"
for big in "${build_dir}/index.pck" "${build_dir}/index.side.wasm"; do
	[[ -f "${big}" ]] && "${project_dir}/tools/split-pack.sh" "${big}"
done

if [[ "${mode}" == export ]]; then
	echo "Web build ready at ${build_dir}"
	exit 0
fi

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
#
# --prod-cache applies the deployed rules instead (vercel.json / _headers):
# content-hashed parts/ immutable, everything else no-cache, revalidated via
# Last-Modified. It exists so `./web verify --repeat` can measure a repeat
# visit locally; day-to-day local serving stays no-store.
exec python3 - "${port}" "${build_dir}" "${cache_mode}" <<'PYSERVE'
import functools
import http.server
import sys


class CacheHandler(http.server.SimpleHTTPRequestHandler):
	def end_headers(self):
		if MODE == "prod":
			if self.path.split("?")[0].startswith("/parts/"):
				self.send_header("Cache-Control", "public, max-age=31536000, immutable")
			else:
				self.send_header("Cache-Control", "no-cache")
		else:
			self.send_header("Cache-Control", "no-store, must-revalidate")
			self.send_header("Pragma", "no-cache")
		super().end_headers()


port = int(sys.argv[1])
MODE = sys.argv[3]
handler = functools.partial(CacheHandler, directory=sys.argv[2])
http.server.ThreadingHTTPServer(("127.0.0.1", port), handler).serve_forever()
PYSERVE
