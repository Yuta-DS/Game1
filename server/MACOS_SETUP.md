# Running the Artéa server on macOS

Notes on getting `server/server.py` running on a macOS development machine,
and a record of what changed in the source to make that possible.

The production Ubuntu deployment is **unaffected** — every change below is a
default-preserving override. With no environment variables set, `server.py`
behaves exactly as it did before.

---

## Quick start

```
cd server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

HOST=127.0.0.1 PORT=8000 python server.py
```

Server comes up at <http://127.0.0.1:8000>. `database.db` and `uploads/` are
created automatically on first run.

Verify:

```
curl http://127.0.0.1:8000/
# {"status":"server running"}
```

---

## Changes made to `server.py`

### 1. Port and host are now configurable — *this was the macOS blocker*

**Original:**

```python
app.run(
    host='0.0.0.0',
    port=80,
    debug=False
)
```

**Now:**

```python
app.run(
    host=os.environ.get('HOST', '0.0.0.0'),
    port=int(os.environ.get('PORT', 80)),
    debug=False
)
```

**Why:** Port 80 is a privileged port. On the Ubuntu server this is fine
because systemd starts the service as root. On macOS, running
`python server.py` as a normal user fails to bind port 80. The alternative
would have been `sudo python server.py`, which is worse — it runs the whole
app as root and leaves root-owned `database.db` and `uploads/` files behind.

Binding `127.0.0.1` instead of `0.0.0.0` also keeps the dev server off the
local network. On a shared or campus Wi-Fi network, `0.0.0.0` means anyone on
that network can reach the API.

Defaults are unchanged, so systemd still gets `0.0.0.0:80`.

### 2. JWT secret key can come from the environment

**Original:**

```python
app.config['JWT_SECRET_KEY'] = 'dev_secret_change_later_12345'
```

**Now:**

```python
app.config['JWT_SECRET_KEY'] = os.environ.get(
    "JWT_SECRET_KEY",
    'dev_secret_change_later_12345'
)
```

**Why:** The hardcoded literal remains as the fallback so nothing breaks, but
production can now set a real secret without editing source. This matters:
anyone who can read the repository can forge a valid token for any user
account, because the signing key is the only thing standing between them and
a token that says "I am user 1". See *Outstanding security issues* below.

### 3. OpenRouter API key can come from the environment

**Original:**

```python
OPENROUTER_API_KEY = ""
```

**Now:**

```python
OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
```

**Why:** The key was an empty string in source — that slot is where a live
API key would be pasted, and a pasted key gets committed to git. Reading from
the environment means the key never enters the repository. Behavior with no
key set is identical to before (`/ai/chat` falls back to the local stub).

### 4. Fixed a deprecation warning on Python 3.12+

**Original:**

```python
timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
```

**Now:**

```python
timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
```

**Why:** `datetime.utcnow()` is deprecated as of Python 3.12 and emits a
`DeprecationWarning`; it is scheduled for removal. The replacement produces
the same UTC timestamp string. `timezone` was added to the existing
`datetime` import. Not macOS-specific — it surfaces on any machine running
Python 3.12 or newer.

---

## Other repository changes

### `server/requirements.txt` (new file)

Pins the five actual dependencies:

```
Flask==3.1.3
Flask-SQLAlchemy==3.1.1
Flask-JWT-Extended==4.7.4
bcrypt==5.0.0
requests==2.34.2
```

Previously the install step was a bare `pip install flask flask_sqlalchemy ...`
with no versions, so two people setting up the project could end up on
different releases.

### `.gitignore` additions

```
server/venv/
server/database.db
server/uploads/
.DS_Store
__MACOSX/
__pycache__/
*.pyc
```

None of these belong in version control. `database.db` in particular contains
user password hashes.

### Repository state fix

The working tree had 11,632 files staged as deletions — the result of a
`git rm -r --cached` somewhere in the history. The files were all present on
disk; only the index was wrong. Cleared with `git reset`, which touches the
index only and modifies no files.

---

## What was *not* changed

### `flaskapp.service`

Untouched. It is a systemd unit and systemd does not exist on macOS, so
`sudo systemctl ...` commands from the deployment docs have no local
equivalent. On macOS you just run `python server.py` directly.

For reference, the unit expects the repository at `/home/ubuntu/server`
exactly — deploying to a different path breaks its `ExecStart` line.

### Upload validation

`ALLOWED_EXTENSIONS` and `allowed_file()` are defined at lines 111–114 but
never called. `/upload_artwork` reads `request.data` and writes it to disk as
`.png` regardless of what the bytes actually are, with no size limit.

Left alone deliberately: adding validation would start rejecting uploads the
Godot client currently sends successfully, which is a behavior change for the
game, not a macOS fix. Worth raising with the team separately.

---

## Outstanding security issues

Not fixed here because they are deployment decisions, not local-setup
problems. Flagging for the team before the next deploy:

1. **Default JWT secret is public.** `dev_secret_change_later_12345` is in
   the repository. Anyone who reads it can mint a token for any user id and
   access that user's artworks. Set `JWT_SECRET_KEY` to a real random value
   in the systemd unit before deploying. The environment hook is now in place
   (change 2 above) — it just needs a value.

2. **`flaskapp.service` runs as `User=root`.** Any remote-code-execution bug
   in the Flask app gives an attacker the whole machine. Should be
   `User=ubuntu`. Note that dropping from root means port 80 can no longer be
   bound directly — the usual fix is to run the app on a high port and put
   nginx in front, or grant the binary `CAP_NET_BIND_SERVICE`.

3. **The Flask development server is serving production.** The startup banner
   says so explicitly: *"This is a development server. Do not use it in a
   production deployment."* It is single-threaded and has no hardening. A
   production WSGI server (gunicorn, waitress) should run it instead.

4. **No upload size limit.** A client can POST an arbitrarily large body to
   `/upload_artwork` and fill the server disk. Flask's
   `MAX_CONTENT_LENGTH` config setting is the standard fix.

---

## Verified working

Tested locally on macOS (Darwin 25.5.0, Python 3.13) against
`http://127.0.0.1:8000`:

| Endpoint | Result |
| --- | --- |
| `GET /` | 200, `{"status":"server running"}` |
| `POST /register` | 201, user created |
| `POST /login` | 200, JWT returned |
| `POST /upload_artwork` | 200, file written to `uploads/user_<id>/` |
| `GET /my_artworks` | 200, artwork listed |
| `GET /download_artwork/<id>` | 200, file served |

Test users and uploads created during verification were deleted afterwards —
`database.db` is empty.

**Note on uploading:** `/upload_artwork` reads the raw request body
(`request.data`), so the request needs
`Content-Type: application/octet-stream`. A plain
`curl --data-binary @file.png` without that header sends form-encoded data,
leaves `request.data` empty, and gets back
`{"message": "No image data received"}`. The Godot client sends the correct
header already. Working example:

```
curl -X POST http://127.0.0.1:8000/upload_artwork \
  -H "Authorization: Bearer $TOKEN" \
  -H "Artwork-Title: My Piece" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @artwork.png
```

---

## Still outstanding: Git LFS

Four LFS-tracked files have not been pulled:

```
artea/addons/nobodywho/nobodywho-godot-x86_64-pc-windows-msvc-debug.pdb
artea/addons/nobodywho/nobodywho-godot-x86_64-unknown-linux-gnu-debug.so
artea/nobodywhomodels/gemma-2-2b-it-Q4_K_M.gguf
artea/nobodywhomodels/user-bge-m3-q8_0.gguf
```

`git-lfs` is not installed on this machine — `git lfs install` fails with
`git: 'lfs' is not a git command`. To fix:

```
brew install git-lfs
git lfs install
cd ~/S2603 && git lfs pull
```

This affects the **Godot game only** (the local LLM chatbot models and native
plugin binaries), not the Flask server. The server runs fine without them.
