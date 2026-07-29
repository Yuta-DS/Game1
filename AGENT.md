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
pip install flask flask_sqlalchemy flask_jwt_extended bcrypt requests
python server.py
```

The API listens on port 80. In production it runs via the
`flaskapp.service` systemd unit (`sudo systemctl restart flaskapp`
after code changes).

## Conventions

- Server URLs are centralized in the Godot `APIManager` singleton
  (`APIManager.gd`) — update endpoints there, not scattered through
  scripts.
- The in-game chatbot uses a local LLM via `nobodywho`. `server.py` has
  a test OpenRouter path under `/ai/chat` intended as a starting point
  for swapping in a cloud model provider later.
