#!/usr/bin/env bash
# Artea - first-time setup. Run once after cloning:
#     ./setup.sh
# Then start the game with:
#     ./setup.sh run
#
# Works on macOS and Linux. See Config&Setup.txt for the manual steps
# and for Windows.

set -euo pipefail

cd "$(dirname "$0")"
ROOT="$PWD"

say() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
die() { printf '\n\033[31mERROR: %s\033[0m\n' "$1" >&2; exit 1; }

# --- locate the Godot binary -----------------------------------------------
find_godot() {
    local target="${1:-desktop}" candidate resolved
    local candidates=()
    [ -n "${GODOT_BIN:-}" ] && candidates+=("$GODOT_BIN")
    if [ "$target" = "web" ]; then
        candidates+=(
            "$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
            "$HOME/Applications/Godot.app/Contents/MacOS/Godot"
            "/Applications/Godot.app/Contents/MacOS/Godot"
        )
    else
        candidates+=(
            "/Applications/Godot_mono.app/Contents/MacOS/Godot"
            "$HOME/Applications/Godot_mono.app/Contents/MacOS/Godot"
            "$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
            "/Applications/Godot.app/Contents/MacOS/Godot"
        )
    fi
    candidates+=(godot-mono godot4 godot)
    for c in "${candidates[@]}"; do
        if [ -x "$c" ]; then
            resolved="$c"
        elif command -v "$c" >/dev/null 2>&1; then
            resolved="$(command -v "$c")"
        else
            continue
        fi
        if [ "$target" = "web" ] && "$resolved" --version 2>/dev/null | grep -qi mono; then
            continue
        fi
        echo "$resolved"
        return
    done
    echo ""
}

python_env_ready() {
    [ -x "$ROOT/server/venv/bin/python" ] && \
        "$ROOT/server/venv/bin/python" -c \
        'import flask, flask_cors, flask_sqlalchemy, flask_jwt_extended, bcrypt, requests' \
        >/dev/null 2>&1
}

ensure_python_env() {
    python_env_ready && return
    say "Setting up Python environment"
    [ -d "$ROOT/server/venv" ] || python3 -m venv "$ROOT/server/venv"
    "$ROOT/server/venv/bin/python" -m pip install -q -r "$ROOT/server/requirements.txt"
    python_env_ready || die "Backend Python dependencies are incomplete."
}

# Godot's .godot directory is a disposable local cache and is intentionally
# excluded from Git. Validate the imported files that the hub needs instead of
# assuming that a non-empty cache is complete.
import_cache_ready() {
    local source import_file imported_path
    local required_sources=(
        "assets3D/houses/gltf/foliage_A.gltf"
        "assets3D/houses/gltf/foliage_B.gltf"
        "assets3D/houses/gltf/mailbox.gltf"
        "assets3D/houses/gltf/tree.gltf"
        "assets3D/houses/gltf/tree_large.gltf"
        "assets3D/houses/gltf/fence_straight.gltf"
        "assets3D/houses/gltf/fence_straight_long.gltf"
    )

    [ -f "$ROOT/artea/.godot/extension_list.cfg" ] || return 1
    grep -q 'res://addons/terrain_3d/terrain.gdextension' \
        "$ROOT/artea/.godot/extension_list.cfg" || return 1

    for source in "${required_sources[@]}"; do
        import_file="$ROOT/artea/$source.import"
        [ -f "$ROOT/artea/$source" ] || return 1
        [ -f "$import_file" ] || return 1
        imported_path="$(sed -n 's|^path="res://\(.*\)"$|\1|p' "$import_file" | head -1)"
        [ -n "$imported_path" ] || return 1
        [ -f "$ROOT/artea/$imported_path" ] || return 1
    done
}

build_import_cache() {
    local import_log="$ROOT/artea/.godot/setup-import.log"
    local count

    say "Building Godot import cache (a few minutes - do not interrupt)"
    mkdir -p "$ROOT/artea/.godot"
    if ! "$GODOT" --headless --path "$ROOT/artea" --import >"$import_log" 2>&1; then
        tail -n 80 "$import_log" >&2
        die "Godot import failed. Full log: $import_log"
    fi
    if ! import_cache_ready; then
        tail -n 80 "$import_log" >&2
        die "Godot import finished with required hub resources missing. Full log: $import_log"
    fi

    count="$(find "$ROOT/artea/.godot/imported" -type f 2>/dev/null | wc -l | tr -d ' ')"
    echo "Imported $count files."
}

ensure_import_cache() {
    import_cache_ready || build_import_cache
}

# Web needs the backend and imported assets from first-time setup. The GGUF
# model and C# assembly are native-only and are intentionally excluded by the
# non-Mono Web export preset.
if [ "${1:-}" = "web" ]; then
    command -v python3 >/dev/null || die "python3 not found."
    command -v git-lfs >/dev/null || die "git-lfs not found. macOS: brew install git-lfs"
    GODOT="$(find_godot web)"
    [ -n "$GODOT" ] || die "Non-Mono Godot not found. Set GODOT_BIN to the standard Godot executable."
    say "Pulling Web art assets from Git LFS"
    git lfs install --local >/dev/null 2>&1 || true
    git lfs pull --exclude="*.gguf,*.dll,*.so,*.pdb,*.blend" \
        || die "Web art asset LFS pull failed."
    ensure_python_env
    ensure_import_cache
    say "Web prerequisites ready"
    exit 0
fi

# --- run mode: start server (if needed) + game -----------------------------
if [ "${1:-}" = "run" ]; then
    GODOT="$(find_godot)"
    [ -n "$GODOT" ] || die "Godot not found. Run ./setup.sh first."

    ensure_import_cache

    if ! curl -fsS -m 3 http://127.0.0.1:8000/ >/dev/null 2>&1; then
        say "Starting server on 127.0.0.1:8000"
        mkdir -p "$ROOT/server/logs"
        ( cd "$ROOT/server" && HOST=127.0.0.1 PORT=8000 \
            ./venv/bin/python server.py >> logs/flaskapp.err.log 2>&1 & )
        for _ in $(seq 1 20); do
            curl -fsS -m 2 http://127.0.0.1:8000/ >/dev/null 2>&1 && break
            sleep 0.5
        done
    fi
    curl -fsS -m 3 http://127.0.0.1:8000/ >/dev/null 2>&1 \
        && say "Server up" || say "WARNING: server not responding (offline mode still works)"

    say "Launching game"
    # Always put the development window on the primary display. Godot can
    # remember a fullscreen Space or a disconnected monitor between runs;
    # in that case the process is healthy but ./setup.sh run appears to show
    # nothing. 960x540 fits Retina desktops whose logical width is only 1024.
    exec "$GODOT" --path "$ROOT/artea" \
        --windowed --screen 0 --position 32,48 --resolution 960x540 \
        res://scenes/start_screen.tscn
fi

# --- 1. prerequisites ------------------------------------------------------
say "Checking prerequisites"
command -v python3 >/dev/null || die "python3 not found."
command -v git-lfs >/dev/null || die "git-lfs not found. macOS: brew install git-lfs"
if find "$ROOT/artea" -maxdepth 1 -name '*.csproj' -print -quit | grep -q .; then
    command -v dotnet >/dev/null || die "dotnet SDK not found. macOS: brew install --cask dotnet-sdk"
fi

GODOT="$(find_godot)"
[ -n "$GODOT" ] || die "Godot (.NET/Mono build) not found. macOS: brew install --cask godot-mono"
echo "Godot:  $("$GODOT" --version 2>/dev/null | tail -1)"
if command -v dotnet >/dev/null 2>&1; then
    echo "dotnet: $(dotnet --version)"
fi

# --- 2. git lfs ------------------------------------------------------------
say "Pulling Git LFS assets (large, may take a while)"
git lfs install --local >/dev/null 2>&1 || true
git lfs pull || die "git lfs pull failed."

head -c 4 artea/nobodywhomodels/gemma-2-2b-it-Q4_K_M.gguf 2>/dev/null | grep -q GGUF \
    || die "LFS models are still pointer stubs. Re-run: git lfs pull"

# --- 3. python venv --------------------------------------------------------
ensure_python_env

# --- 4. godot import cache (REQUIRED - see Config&Setup.txt section 2.5) ---
ensure_import_cache

# --- 5. build c# -----------------------------------------------------------
if find "$ROOT/artea" -maxdepth 1 -name '*.csproj' -print -quit | grep -q .; then
    say "Building C# assembly"
    ( cd artea && dotnet build -v quiet --nologo ) || die "dotnet build failed."
else
    say "No C# project in this checkout; skipping .NET build"
fi

say "Setup complete"
cat <<'EOF'

Start the game:   ./setup.sh run

First time in:    click "Offline Guest" to play without an account,
                  or "Register" to create one against the local server.

Config & docs:    Config&Setup.txt
EOF
