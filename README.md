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

# Guide to Running the Project

1. **Engine Requirement:** Download and install Godot Engine version 4.4 or newer, specifically the version that includes .NET/Mono support (for C# compilation).
2. **Import Project:** Import the project directory into the Godot Project Manager.
3. **Initial Scene Launch:** To test the project, click the "Run Scene" button (F6). If the main scene is not already assigned, set it to `res://scenes/start_screen.tscn`.

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
| `OPENROUTER_API_KEY` | Enables the cloud AI creative-guide/world-builder routes |

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

## Future AI Integration

The current project uses a local LLM inside Godot. A test OpenRouter
implementation exists in `server.py` under the `@app.route('/ai/chat')` route.
Future teams may replace this implementation with another cloud model
provider or a self-hosted model.

## Tests

Headless Godot test suites live in `artea/scripts/test_*.gd`:

```sh
Godot --headless --path artea --script res://scripts/<name>.gd
```

See `artea/CASTLE_UNIVERSE_IMPLEMENTATION.md` for the full list and what each
one verifies.
