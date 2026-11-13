# AGENT.md

Guidance for coding agents working in this repository.

## Project overview

Artéa is a Godot 4.4 (.NET/Mono, C#) game with a Flask-backed online
gallery and authentication server.

## Structure

- `artea/` — the Godot project: scenes, scripts (GDScript and C#),
  assets, and addons (`dialogue_manager`, `nobodywho` for the local LLM
  chatbot, `terrain_3d`).
- `server/` — the Flask backend (`server.py`, `schema.sql`,
  `flaskapp.service`).
- `CHANGELOG.md` — release history (v1.0, v2.0). Check there instead
  of duplicating history in this file.

## Setup / running the game

- Install Godot Engine 4.4+ with .NET/Mono support, then import `artea/`
  into the Godot Project Manager.
- Main scene: `res://scenes/start_screen.tscn`.
- This project uses **Git LFS** for large assets (`.gguf` LLM models,
  native plugin binaries). Run `git lfs install` and `git lfs pull`
  after cloning — without this the project will not run correctly.

## Running the server

From `server/`:

```
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python server.py
```

**Windows / PowerShell:**

```powershell
cd server
python -m venv venv
.\venv\Scripts\python.exe -m pip install -r requirements.txt
$env:HOST = "127.0.0.1"
$env:PORT = "8000"
$env:JWT_SECRET_KEY = "local-dev-test-secret"
.\venv\Scripts\python.exe server.py
```

Leave that running in its own terminal - it's the server, not a one-shot
command - and launch the game from a separate terminal/window. The Godot
client's `APIManager.BASE_URL` (`artea/scripts/API_Manager.gd`) is hardcoded
to `http://127.0.0.1:8000`, so `HOST`/`PORT` must stay exactly that for the
game to find it. Verify it's up with `curl http://127.0.0.1:8000/` -
`{"status":"server running"}` means it's ready. `Ctrl+C` stops it.

First run creates `server/database.db` and `server/uploads/` automatically
(both gitignored). That file persists across restarts - stopping the server
does not erase registered accounts, only deleting `database.db` does.

The API listens on port 80 by default. In production it runs via the
`flaskapp.service` systemd unit (`sudo systemctl restart flaskapp`
after code changes), behind nginx on one EC2 server: see
`server/ec2/README.md`.

Port 80 needs root, so on a dev machine override it:

```
HOST=127.0.0.1 PORT=8000 python server.py
```

`HOST`, `PORT`, `JWT_SECRET_KEY` and `OPENROUTER_API_KEY` all read from
the environment and fall back to the previous hardcoded values. See
`server/MACOS_SETUP.md` for the full rationale and a list of
outstanding security issues.

## Conventions

- Server URLs are centralized in the Godot `APIManager` singleton
  (`APIManager.gd`) — update endpoints there, not scattered through
  scripts.
- Gameplay is GDScript. `Artea.csproj` exists and .NET is enabled, but there
  is no C# gameplay code — prefer GDScript unless a measured cost demands
  otherwise.
- Runtime-built UI is the house style: `gallery_ceremony.gd`,
  `journey_privacy.gd`, `facilitator_settings.gd` and the viewfinder HUD all
  construct their own nodes rather than editing scene files, so a feature can
  be removed cleanly and `.tscn` diffs stay small.
- Journey progress lives in the `JourneyState` autoload (see
  `artea/CASTLE_UNIVERSE_IMPLEMENTATION.md`). Record player acts through its
  own `record_*` methods so they persist, count, and are wiped by
  `clear_journey()` along with everything else.
- The Lens of Seeing (`artea/scripts/viewfinder/`) does runtime mesh surgery
  on props tagged to 3D physics layer 4, `Cuttable`. Never put Terrain3D or
  ProtonScatter/MultiMesh output on that layer — clipmaps and MultiMesh have
  no per-instance mesh to cut.

## Tests

Headless suites in `artea/scripts/test_*.gd`, run with
`Godot --headless --path artea --script res://scripts/<name>.gd`. See the
Verification section of `artea/CASTLE_UNIVERSE_IMPLEMENTATION.md` for the full
list and what each one locks in.

`test_castle_universe.gd` (the old whole-world suite) does not finish — it
loads the gallery, which pulls in the local LLM and runs past a several-minute
budget — and its first assertion fails on an unmodified baseline. Prefer the
scene-scoped suites.
- The in-game chatbot uses a local LLM via `nobodywho`. `server.py` has
  a test OpenRouter path under `/ai/chat` intended as a starting point
  for swapping in a cloud model provider later.

## Agent skills

### Issue tracker

Issues are tracked in this repo's GitHub Issues (wsu-comp3018/COMP3018-S26-G3), via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context layout (no CONTEXT-MAP.md). See `docs/agents/domain.md`.
