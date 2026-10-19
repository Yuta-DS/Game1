This document provides instructions for setting up and running the Artéa game project within the Godot Development Engine.

**Note on Development Integrity:** To ensure maximum project stability and to minimise issues related to file path case sensitivity and the Godot .NET runtime dependencies, it is strongly recommended that all developers work on a _**Windows operating system.**_


Guide to Running the Project
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

## Future AI Integration

The current project uses a local LLM inside Godot.

A test OpenRouter implementation exists in server.py under:

@app.route('/ai/chat')

Future teams may replace this implementation with another cloud model provider or a self-hosted model.

## Hosted Web account login

The browser game uses the same Flask account API as desktop. A public Web
export needs a persistent HTTPS API: deploy `server/` as a Vercel Python project,
connect managed Postgres so Vercel supplies `DATABASE_URL`, and set a random
`JWT_SECRET_KEY` plus
`CORS_ALLOWED_ORIGINS=https://artea-web.vercel.app` in its production
environment. Deploy the API before exporting the game. Never commit these
values to the repository.

For a Vercel game export, run
`ARTEA_PUBLIC_API_BASE_URL=https://artea-api.vercel.app artea/tools/vercel-pack-split/export_web.sh`.
That script embeds the public API origin in the generated HTML. Local `./web`
continues to use the backend at `127.0.0.1:8000`; `./setup.sh run` uses that
same local backend. Local SQLite accounts and hosted Postgres accounts are
separate until data is explicitly migrated. On Vercel, uploaded artwork bytes
are stored in Postgres and uploads are limited to 4 MiB; the local server allows
20 MiB.
