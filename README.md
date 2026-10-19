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


# Guide to Running the Project
  1. **Engine Requirement:** Download and install Godot Engine version 4.4 or newer, specifically the version that includes .NET/Mono support (for C# compilation).
  2. **Import Project:** Import the project directory into the Godot Project Manager.
  3. **Initial Scene Launch:** To test the project, click the "Run Scene" button (F6). If the main scene is not already assigned, set it to:
    - "res://scenes/start_screen.tscn"


---

# Project Setup

## Git Setup & Large File Requirements

This project uses **Git LFS (Large File Storage)** for large assets including:
- LLM model files (`.gguf`)
- Native plugin binaries (`.dll`, `.so`, `.pdb`)

These files are required for the project to run correctly (local/offline LLM).

---

### First-time setup (required for all developers)

Install Git LFS before pulling or checking out the project files:

git lfs install

git clone <repo>

git lfs pull


# Server Setup

## Folder Structure

The server should be deployed with the following structure:

server/

  server.py

  database.db

  uploads/

  venv/

  flaskapp.service


server.py contains the Flask backend.

database.db stores user and artwork information. (created automatically)

uploads/ stores uploaded artwork files. (created automatically)

venv/ contains the Python virtual environment.

flaskapp.service allows the server to run automatically through systemd.


## Creating the Python Environment

From the server directory:

macOS/Linux:

python3 -m venv venv

source venv/bin/activate


Windows / PowerShell:

python -m venv venv

.\venv\Scripts\activate


Install dependencies from the pinned requirements file:

pip install -r requirements.txt


## Running the Server Manually

Activate the virtual environment:

macOS/Linux:

source venv/bin/activate

Windows / PowerShell:

.\venv\Scripts\activate

Run:

python server.py

By default this binds `0.0.0.0:80`, which needs root. On a dev machine, override
host/port and set a JWT secret instead:

macOS/Linux:

HOST=127.0.0.1 PORT=8000 JWT_SECRET_KEY=local-dev-test-secret python server.py

Windows / PowerShell:

$env:HOST = "127.0.0.1"
$env:PORT = "8000"
$env:JWT_SECRET_KEY = "local-dev-test-secret"
python server.py

`database.db` and `uploads/` are created automatically on first run — both are
gitignored and persist across restarts (stopping the server does not erase
registered accounts, only deleting `database.db` does).

Verify it's up:

curl http://127.0.0.1:8000/
# {"status":"server running"}

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

Reload systemd:

sudo systemctl daemon-reload

Enable automatic startup:

sudo systemctl enable flaskapp

Start the service:

sudo systemctl start flaskapp

Check status:

sudo systemctl status flaskapp

View logs:

sudo journalctl -u flaskapp -f

Restart after code changes:

sudo systemctl restart flaskapp

## Updating API Endpoints in Godot

The Godot project uses the APIManager singleton.

If the server IP address changes, update the URLs in:

APIManager.gd

Typical values:

  const BASE_URL = "http://YOUR_SERVER_IP"

  const LOGIN_URL = BASE_URL + "/login"

  const REGISTER_URL = BASE_URL + "/register"

  const UPLOAD_ARTWORK_URL = BASE_URL + "/upload_artwork"

  const MY_ARTWORKS_URL = BASE_URL + "/my_artworks"


Replace YOUR_SERVER_IP with the public IP or domain name of the server.

## Future AI Integration

The current project uses a local LLM inside Godot.

A test OpenRouter implementation exists in server.py under:

@app.route('/ai/chat')

Future teams may replace this implementation with another cloud model provider or a self-hosted model.

## Tests

Headless Godot test suites live in `artea/scripts/test_*.gd`:

Godot --headless --path artea --script res://scripts/<name>.gd

See `artea/CASTLE_UNIVERSE_IMPLEMENTATION.md` for the full list and what each
one verifies.