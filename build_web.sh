#!/usr/bin/env bash
#
# Builds ARTÉA for the web and serves it locally.
#
# Web export needs the non-Mono Godot editor and the matching non-Mono export
# templates. The Mono build cannot produce a web export for this project, and
# the two template sets are not interchangeable.
#
#   ./build_web.sh          build, then serve on http://localhost:8060
#   ./build_web.sh --build  build only
#
set -euo pipefail

GODOT="${GODOT:-/Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot}"
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/artea" && pwd)"
OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build/web"
PORT="${PORT:-8060}"

# Godot force-exports every registered GDExtension even when an export filter
# excludes its directory. NobodyWho has no Web library and contains ~890 MB of
# desktop/mobile binaries, so unregister it only for the duration of this Web
# export. The trap restores the editor state on success, failure, or Ctrl-C.
NOBODYWHO_EXTENSION="$PROJECT/addons/nobodywho/nobodywho.gdextension"
NOBODYWHO_UID="$NOBODYWHO_EXTENSION.uid"
EXTENSION_LIST="$PROJECT/.godot/extension_list.cfg"
WEB_STASH=""

restore_desktop_extensions() {
  if [[ -z "$WEB_STASH" || ! -d "$WEB_STASH" ]]; then
    return
  fi
  rm -f "$EXTENSION_LIST"
  [[ -f "$WEB_STASH/nobodywho.gdextension" ]] && mv "$WEB_STASH/nobodywho.gdextension" "$NOBODYWHO_EXTENSION"
  [[ -f "$WEB_STASH/nobodywho.gdextension.uid" ]] && mv "$WEB_STASH/nobodywho.gdextension.uid" "$NOBODYWHO_UID"
  [[ -f "$WEB_STASH/extension_list.cfg" ]] && mv "$WEB_STASH/extension_list.cfg" "$EXTENSION_LIST"
  rmdir "$WEB_STASH"
}

WEB_STASH="$(mktemp -d)"
trap restore_desktop_extensions EXIT INT TERM
[[ -f "$NOBODYWHO_EXTENSION" ]] && mv "$NOBODYWHO_EXTENSION" "$WEB_STASH/"
[[ -f "$NOBODYWHO_UID" ]] && mv "$NOBODYWHO_UID" "$WEB_STASH/"
[[ -f "$EXTENSION_LIST" ]] && mv "$EXTENSION_LIST" "$WEB_STASH/"

if [[ ! -x "$GODOT" ]]; then
  echo "error: non-Mono Godot not found at $GODOT" >&2
  echo "       set GODOT=/path/to/Godot to override" >&2
  exit 1
fi

# The web build is GDScript-only. A project that still declares C# will fail to
# open in the non-Mono editor.
if grep -q '"C#"' "$PROJECT/project.godot"; then
  echo "error: project.godot still declares C#; non-Mono Godot cannot open it" >&2
  exit 1
fi

mkdir -p "$OUT"

echo "==> importing assets"
# A fresh checkout has no .godot/ cache, and exporting without it produces an
# empty pack. --import populates it.
"$GODOT" --headless --path "$PROJECT" --import >/dev/null 2>&1 || true

echo "==> exporting web build"
"$GODOT" --headless --path "$PROJECT" \
  --export-release "Web" "$OUT/index.html"

restore_desktop_extensions
trap - EXIT INT TERM

echo
echo "==> built into $OUT"
ls -lh "$OUT" | tail -n +2 | awk '{printf "    %-34s %s\n", $9, $5}'

if [[ "${1:-}" == "--build" ]]; then
  exit 0
fi

# Godot web builds use SharedArrayBuffer, which browsers only hand out when the
# page is served with cross-origin isolation headers. Opening index.html from
# the filesystem will not work, so serve it with the headers set.
echo
echo "==> serving on http://localhost:$PORT  (ctrl-c to stop)"
cd "$OUT"
python3 - "$PORT" <<'PY'
import sys, http.server, socketserver

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Required for SharedArrayBuffer, which the Godot web runtime needs.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *args):
        pass

port = int(sys.argv[1])
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("", port), Handler) as httpd:
    httpd.serve_forever()
PY
