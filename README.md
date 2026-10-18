This document provides instructions for setting up and running the Artéa game project within the Godot Development Engine.

**Note on Development Integrity:** To ensure maximum project stability and to minimise issues related to file path case sensitivity and the Godot .NET runtime dependencies, it is strongly recommended that all developers work on a _**Windows operating system.**_


Guide to Running the Project
  1. **Engine Requirement:** Download and install Godot Engine version 4.4 or newer. Use the standard non-Mono build for Web exports. A .NET build and SDK are needed only if this checkout includes a C# project.
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

python3 -m venv venv

source venv/bin/activate


Install required packages:

pip install flask

pip install flask_sqlalchemy

pip install flask_jwt_extended

pip install bcrypt

pip install requests


## Running the Server Manually

Activate the virtual environment:

source venv/bin/activate

Run:

python server.py

The API should now be available on port 80.

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
use HTTPS when the game uses HTTPS. The current static Vercel deployment does
not include a hosted Flask account API; Offline Guest works there, while
account login needs a persistent hosted backend and an API URL or reverse proxy.

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
