# Artéa

Artéa is a 3D narrative exploration game built in Godot 4, where players paint
artwork that becomes the seed for AI-generated explorable worlds. It combines
a hub-world/"Castle Universe" journey structure, a local on-device LLM
companion (Milo), narrative dialogue and NPCs, and a Flask-backed online
gallery where players' paintings are uploaded, rated, and browsed.

See [CHANGELOG.md](./CHANGELOG.md) for release history, and
[AGENT.md](./AGENT.md) for fuller technical/contributor guidance (test
suites, architecture conventions, known issues).

This document provides instructions for setting up and running the Artéa game project within the Godot Development Engine.

**Note on Development Integrity:** To ensure maximum project stability and to minimise issues related to file path case sensitivity and the Godot .NET runtime dependencies, it is strongly recommended that all developers work on a _**Windows operating system.**_

---

Guide to Running the Project
  1. **Engine Requirement:** Download and install Godot Engine version 4.4 or newer. Use the standard non-Mono build for Web exports. A .NET build and SDK are needed only if this checkout includes a C# project.
  2. **Import Project:** Import the project directory into the Godot Project Manager.
  3. **Initial Scene Launch:** To test the project, click the "Run Scene" button (F6). If the main scene is not already assigned, set it to:
    - "res://scenes/start_screen.tscn"

**Game client:**
- Godot Engine 4.4+ with .NET/Mono support (for C# compilation)
- Windows is the only platform the client is tested on (see note above) —
  file path case-sensitivity and .NET runtime issues are more likely on
  macOS/Linux
- Git + Git LFS — roughly **2.1 GB** of LFS-tracked assets (local LLM model
  files, native plugin binaries) are required for the game to run correctly

**Server:**
- Python 3.x (tested on 3.13 — see `server/MACOS_SETUP.md`); runs on
  Windows, macOS, or Linux
- Dependencies pinned in `server/requirements.txt` (Flask, SQLAlchemy, JWT,
  CORS, bcrypt, gunicorn) — no manual package list to keep in sync

---

# Project Structure

A map of the critical files and folders for orienting new developers — see
[AGENT.md](./AGENT.md) for deeper architectural conventions.

- **`artea/`** — the Godot project.
  - `scenes/` — game scenes (`.tscn`) and their attached scripts.
  - `scripts/` — GDScript gameplay code, including every `test_*.gd`
    headless test suite.
  - `scripts/API_Manager.gd` — the single source of truth for every backend
    URL; update here if the server address changes.
  - `scripts/JourneyState.gd` — autoload tracking player progress through
    the journey/"Castle Universe" system.
  - `scenes/chatbot.gd` — Milo, the AI companion (see
    [AI Integration](#ai-integration) below).
  - `scenes/drawing_tool.gd` / `scenes/GalleryManager.gd` — the painting →
    upload → online gallery flow.
  - `addons/` — third-party/engine plugins: `dialogue_manager`, `nobodywho`
    (local LLM), `terrain_3d`, `proton_scatter`. `godot-firebase` is present
    but unused — artwork storage moved to the Flask server below; its
    upload calls are commented out in `drawing_tool.gd`.
  - `CASTLE_UNIVERSE_IMPLEMENTATION.md` — deep dive into the hub/journey
    system and its test coverage.
- **`server/`** — the Flask backend (folder layout detailed under
  [Server Setup](#server-setup)).
- **`CHANGELOG.md`** — release history (v1.0, v2.0).
- **`AGENT.md`** — fuller technical/contributor guidance.

---

# Guide to Running the Project

1. **Engine Requirement:** Download and install Godot Engine version 4.4 or newer, specifically the version that includes .NET/Mono support (for C# compilation).
2. **Import Project:** Import the project directory into the Godot Project Manager.
3. **Initial Scene Launch:** To test the project, click the "Run Scene" button (F6). If the main scene is not already assigned, set it to `res://scenes/start_screen.tscn`.

---

# Web build

From the repository root, run `./web rebuild` to export and serve the browser
game, or `./web verify` to check Offline Guest play and measure the cold load.
Web export requires a standard non-Mono Godot binary and Python 3.

The export starts with a small title-and-hub pack. On the first trip to another
area, the loading screen downloads and mounts the remaining game content. The
build compares both packs with the full export before accepting the split, so
assets and scenes are retained. Desktop Godot uses its normal scene loading
path. See `artea/tools/vercel-pack-split/README.md` for deployment details.

---

# Project Setup

## Git Setup & Large File Requirements

This project uses **Git LFS (Large File Storage)** for large assets including:
- LLM model files (`.gguf`)
- Native plugin binaries (`.dll`, `.so`, `.pdb`)

These files are required for the project to run correctly (local/offline LLM).

### First-time setup (required for all developers)

Install Git LFS before pulling or checking out the project files:

```sh
git lfs install
git clone <repo>
git lfs pull
```

---

# Server Setup

## Folder Structure

The server should be deployed with the following structure:

```
server/
├── server.py          # the Flask backend
├── database.db        # user + artwork data (created automatically)
├── uploads/            # uploaded artwork files (created automatically)
├── venv/               # Python virtual environment
└── flaskapp.service    # systemd unit for automatic startup
```

## Accounts

**No seed or admin accounts ship with the project** — `database.db` is
created empty on first run. Create your own account:

```sh
curl -X POST http://127.0.0.1:8000/register \
  -H "Content-Type: application/json" \
  -d '{"username":"yourname","password":"yourpassword"}'
```

or use the in-game registration screen (`res://scenes/authentication.tscn`).
Then `POST /login` with the same credentials to get the JWT the client and
`curl` both use for the upload/gallery endpoints.

## Creating the Python Environment

From the server directory:

**macOS/Linux:**

```sh
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**Windows / PowerShell:**

```powershell
python -m venv venv
.\venv\Scripts\python.exe -m pip install -r requirements.txt
```

PowerShell's default execution policy blocks `.\venv\Scripts\activate`, so
Windows commands below call `.\venv\Scripts\python.exe` directly instead of
activating the venv first.

## Running the Server Manually

**macOS/Linux:**

```sh
source venv/bin/activate
python server.py
```

**Windows / PowerShell:**

```powershell
.\venv\Scripts\python.exe server.py
```

By default this binds `0.0.0.0:80`, which needs root/admin. On a dev machine,
override host/port and set a JWT secret instead:

**macOS/Linux:**

```sh
HOST=127.0.0.1 PORT=8000 JWT_SECRET_KEY=local-dev-test-secret python server.py
```

**Windows / PowerShell:**

```powershell
$env:HOST = "127.0.0.1"
$env:PORT = "8000"
$env:JWT_SECRET_KEY = "local-dev-test-secret"
.\venv\Scripts\python.exe server.py
```

`database.db` and `uploads/` are created automatically on first run — both are
gitignored and persist across restarts (stopping the server does not erase
registered accounts, only deleting `database.db` does).

Verify it's up:

```sh
curl http://127.0.0.1:8000/
# {"status":"server running"}
```

### Configuration

All of the following are optional and read from the environment, falling back
to development defaults if unset:

| Variable | Purpose |
| --- | --- |
| `HOST` / `PORT` | Bind address (default `0.0.0.0:80`, needs root) |
| `JWT_SECRET_KEY` | Signs login tokens — **must** be overridden with a real secret before any deploy reachable by others |
| `CORS_ALLOWED_ORIGINS` | Comma-separated allowed origins for a browser-hosted export (default `*`) |
| `MAX_UPLOAD_BYTES` | Artwork upload size cap (default 20 MB) |
| `OMNIROUTE_BASE_URL`, `OMNIROUTE_CREATIVE_GUIDE_API_KEY`, `OMNIROUTE_WORLD_BUILDER_API_KEY` | Enable the `/ai/creative-guide` and `/ai/world-builder` routes (see [AI Integration](#ai-integration)) |
| `OPENROUTER_API_KEY` | Enables `/ai/chat` — defined but not currently called by the Godot client |

## Enabling flaskapp.service (make server.py run upon booting the server)

```sh
sudo systemctl daemon-reload          # reload systemd
sudo systemctl enable flaskapp        # enable automatic startup
sudo systemctl start flaskapp         # start the service
sudo systemctl status flaskapp        # check status
sudo journalctl -u flaskapp -f        # view logs
sudo systemctl restart flaskapp       # restart after code changes
```

## Updating API Endpoints in Godot

The Godot project uses the `APIManager` singleton. If the server IP address
changes, update the URLs in `API_Manager.gd`:

```gdscript
const BASE_URL = "http://YOUR_SERVER_IP"
const LOGIN_URL = BASE_URL + "/login"
const REGISTER_URL = BASE_URL + "/register"
const UPLOAD_ARTWORK_URL = BASE_URL + "/upload_artwork"
const MY_ARTWORKS_URL = BASE_URL + "/my_artworks"
```

Replace `YOUR_SERVER_IP` with the public IP or domain name of the server.

## AI Integration

Artéa uses AI in two independent places, each with its own provider:

- **Milo's companion chat** (`artea/scenes/chatbot.gd`): native/desktop builds
  run a local, on-device model (Gemma-2-2B via the `nobodywho` addon), so
  typed messages never leave the device. Web builds can't bundle that native
  library, so they instead call a Cloudflare Worker that proxies Gemini — a
  separate system from the Flask server below, and entirely cloud-based.
  Whichever path is unavailable (missing model files, no network), Milo
  falls back to fully authored/static reflections, so the companion is
  never silent.
- **Painting → explorable world** (`/ai/creative-guide` and
  `/ai/world-builder` in `server.py`): always cloud-based, calling OmniRoute
  to turn a player's artwork into a creative brief and a walkable 3D world
  manifest. There is no local/offline mode for this path.

`server.py` also defines a third route, `/ai/chat` (OpenRouter), but it is
not called anywhere in the Godot client — it's left as a starting point for
a team that wants to add another cloud chat provider or a self-hosted model.

## Tests

Headless Godot test suites live in `artea/scripts/test_*.gd`:

```sh
Godot --headless --path artea --script res://scripts/<name>.gd
```

Replace YOUR_SERVER_IP with the public IP or domain name of the server.

## AI integration

Desktop uses the local NobodyWho model when its native extension is available.
The Flask `/ai/chat` route provides the browser-compatible provider and can use
OpenRouter or be replaced with another server-side model provider.

## Web architecture

The `Web` preset exports generated files to `artea/builds/web/`. Run `./web`
to prepare the web prerequisites, refresh the export when source has changed,
start the local backend, and serve the game. Use `./web rebuild` for a forced
fresh export. These commands fetch Web art assets from Git LFS and prepare the
Python environment and Godot import cache through `./setup.sh web`. They do not
require the desktop-only GGUF model
or a C# build. Do not edit generated files; change source under `artea/`.

Desktop builds prefer the bundled NobodyWho/GGUF model for Milo and emotion
analysis. Web builds exclude that native extension and model, and send the same
prompts through the Flask `/ai/chat` endpoint. If `OPENROUTER_API_KEY` is not
configured, the server provides a limited local fallback so both features remain
usable without placing a provider secret in the game or browser.

Desktop and local Web launches use the Flask server at `127.0.0.1:8000`. A
public Web build uses the page's own origin for API calls, so account login
requires a deployed API on that origin. For a separate API origin, define
`window.ARTEA_API_BASE_URL` in the hosting page before the Godot loader starts,
or set the Godot project setting `artea/network/api_base_url`. The API URL must
use HTTPS when the game uses HTTPS. `artea/scripts/deploy_web.sh` injects the
configured `ARTEA_PUBLIC_API_BASE_URL` into the generated hosting page and
refuses to publish without it. The API should be deployed and checked first.

The Flask server in `server/` can run as a separate Vercel project with managed
Postgres. Connect a persistent Postgres database to that project so Vercel sets
`DATABASE_URL`, and set a random `JWT_SECRET_KEY` and
`CORS_ALLOWED_ORIGINS=https://artea-web.vercel.app` in the production
environment. Then deploy `server/` and publish the game with
`ARTEA_PUBLIC_API_BASE_URL=https://<deployed-api-origin>` set. The deployed
API keeps artwork bytes in Postgres because Vercel's local filesystem is
temporary; its default upload cap is 4 MiB, while the local Flask server allows
20 MiB. Existing local SQLite accounts do not automatically migrate to the
hosted database, so players must register separately unless their data is
explicitly migrated.

For cross-origin hosting, set `CORS_ALLOWED_ORIGINS` on the Flask server to a
comma-separated list of exact web origins. For example:

    CORS_ALLOWED_ORIGINS=https://game.example.com,https://staging.example.com

Server secrets and optional model configuration are supplied through environment
variables rather than source files:

    JWT_SECRET_KEY=<random-production-secret>
    OPENROUTER_API_KEY=<provider-key>
    OPENROUTER_MODEL=openai/gpt-oss-20b:free

Google/Firebase sign-in derives its browser redirect from the deployed page.
That exact deployed URL still needs to be registered as an authorized redirect
with the Firebase/Google project.

Terrain3D remains enabled on desktop and web. Its checked-in GDExtension includes
both debug and release WebAssembly libraries. The web host must serve `.wasm`
files with the correct MIME type. Browser `user://` artwork and ratings use
Godot's persistent browser storage and therefore remain local to that browser
origin.

The hub's Proton Scatter nodes use the add-on's synchronous rebuild path only on
Web because the preset intentionally does not require browser
`SharedArrayBuffer` threads. Desktop retains Proton Scatter's normal threaded
path, and both paths generate the same scene instances.
