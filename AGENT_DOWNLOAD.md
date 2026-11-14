# Download and Restore Guide

This repository contains the Artéa project and additional local workspace snapshots.

## Which branch to download

- Use `main` for the normal project source.
- Use `codex/ignored-workspace-snapshot` to restore the complete uploaded workspace snapshot, including the `S2603-clone` and `S2603-worktrees` folders.

## Download the complete snapshot

Use Git and Git LFS. Do not use a browser ZIP download for the complete restore because large files are stored with Git LFS.

```bash
git clone --branch codex/ignored-workspace-snapshot https://github.com/Yuta-DS/Game1.git
cd Game1
git lfs pull
```

If Git LFS is not installed, install it first and run `git lfs install`.

## Set up the project

### Godot game

1. Install Godot 4.4 or newer. Use the .NET/Mono version if the checkout contains the C# project.
2. Open the `artea/` folder in the Godot Project Manager.
3. Let Godot finish importing the project and LFS assets.
4. Run the project. The startup scene is `res://scenes/start_screen.tscn`.

Windows is the recommended development platform because the project includes native plugins and .NET components. A standard non-Mono Godot build is used for Web exports.

### Flask server

The server is in `server/`. Python 3 is required.

macOS/Linux:

```bash
cd server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python server.py
```

Windows PowerShell:

```powershell
cd server
python -m venv venv
.\venv\Scripts\python.exe -m pip install -r requirements.txt
.\venv\Scripts\python.exe server.py
```

The local server normally runs at `http://127.0.0.1:8000`. It creates `server/database.db` and `server/uploads/` on first run. Register a new account in the game or with the `/register` endpoint.

### Restore local configuration

The uploaded `.env` files and `server/database.db` were intentionally excluded. Recreate the environment files from your private configuration and allow the server to create a new database, or restore a trusted database backup separately. Do not commit secrets.

If the Godot client needs a different server address, update the centralized API URL in `artea/scripts/API_Manager.gd` or the project setting documented in the project README.

### Optional Web export

From the repository root, use the included web helper after installing Python and a standard non-Mono Godot build:

```bash
./web rebuild
```

Use `./web verify` to check the exported browser build.

## What is included

The complete snapshot branch contains about 42,096 file paths, including:

- The main Artéa project.
- The uploaded `S2603-clone` files under `additional-local-folders/S2603-clone/`.
- The uploaded `S2603-worktrees` files under `additional-local-folders/S2603-worktrees/`.
- Large models, binaries, web packages, and other Git LFS files.

The copied folders' nested `.git` metadata is intentionally not included. Their working files are included.

## Files intentionally excluded

These local files were not uploaded:

- `.env` files, because they can contain credentials or machine-specific settings.
- `server/database.db`, because it is local database data.

Create or restore those files separately when setting up the project on a new laptop.

## Verify the download

From the cloned repository, list the uploaded paths:

```bash
git ls-tree -r --name-only HEAD > uploaded-files.txt
```

To find files listed by the snapshot but missing from a downloaded working tree:

```bash
find . -type f | sort > downloaded-files.txt
comm -23 uploaded-files.txt downloaded-files.txt
```

An empty result means no uploaded paths are missing from the downloaded tree.

