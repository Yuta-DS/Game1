from flask import Flask, request, jsonify, send_file, g
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import (
    JWTManager,
    create_access_token,
    jwt_required,
    get_jwt_identity
)
import base64
import bcrypt
import binascii
import copy
import hashlib
import json
import os
import tempfile
import threading
import time
from datetime import timedelta, datetime, timezone
from io import BytesIO
from werkzeug.utils import secure_filename
from uuid import uuid4
import requests

app = Flask(__name__)
# Behind nginx (server/ec2) every request reaches gunicorn from 127.0.0.1, so
# the loopback-only AI guest access below would open to the whole internet and
# the admin-reset lockout would be one bucket for everyone. BEHIND_PROXY=1
# takes the caller's address from the X-Forwarded-For nginx sets instead. Only
# set it behind a proxy: without one, a client could send that header itself.
if os.environ.get("BEHIND_PROXY") == "1":
    app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1)

# =========================
# CONFIG
# =========================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
IS_VERCEL = bool(os.environ.get("VERCEL"))
WRITABLE_DIR = os.path.join(tempfile.gettempdir(), "artea") if IS_VERCEL else BASE_DIR


def load_local_environment(path):
    """Load a simple KEY=VALUE file without overriding deployment variables."""
    if not os.path.exists(path):
        return

    with open(path, "r", encoding="utf-8") as env_file:
        for raw_line in env_file:
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue

            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1]
            if key:
                os.environ.setdefault(key, value)


load_local_environment(os.path.join(BASE_DIR, ".env"))

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
USE_OPENROUTER = True

OMNIROUTE_BASE_URL = os.environ.get(
    "OMNIROUTE_BASE_URL",
    "http://127.0.0.1:20128/v1"
).rstrip("/")
OMNIROUTE_CREATIVE_GUIDE_API_KEY = os.environ.get(
    "OMNIROUTE_CREATIVE_GUIDE_API_KEY",
    os.environ.get("OMNIROUTE_API_KEY", "")
)
OMNIROUTE_WORLD_BUILDER_API_KEY = os.environ.get(
    "OMNIROUTE_WORLD_BUILDER_API_KEY",
    ""
)
OMNIROUTE_BACKUP_API_KEY = os.environ.get("OMNIROUTE_BACKUP_API_KEY", "")
OMNIROUTE_CREATIVE_GUIDE_MODEL = os.environ.get(
    "OMNIROUTE_CREATIVE_GUIDE_MODEL",
    os.environ.get("OMNIROUTE_ART_DIRECTOR_MODEL", "artea-art-director")
)
OMNIROUTE_WORLD_BUILDER_MODEL = os.environ.get(
    "OMNIROUTE_WORLD_BUILDER_MODEL",
    "artea-world-builder"
)
AI_IMAGE_MIME_TYPES = {"image/png", "image/jpeg", "image/webp"}
MAX_AI_IMAGE_BYTES = 8 * 1024 * 1024
MAX_AI_PROMPT_CHARS = 8000
MAX_WORLD_CONTEXT_CHARS = 60000
AI_CIRCUIT_COOLDOWN_SECONDS = float(os.environ.get(
    "AI_CIRCUIT_COOLDOWN_SECONDS",
    "15"
))
AI_HEALTH_CHECK_SECONDS = float(os.environ.get(
    "AI_HEALTH_CHECK_SECONDS",
    "10"
))
AI_UPSTREAM_TIMEOUT_SECONDS = float(os.environ.get(
    "AI_UPSTREAM_TIMEOUT_SECONDS",
    # Vision world manifests are larger than guide responses and routinely need
    # more than 25 seconds. Keep two-route failover inside the game's 90-second
    # wait while allowing either route enough time to return valid schema JSON.
    "40"
))
AI_CACHE_MAX_AGE_SECONDS = int(os.environ.get(
    "AI_CACHE_MAX_AGE_SECONDS",
    str(7 * 24 * 60 * 60)
))
AI_CACHE_DIR = os.path.join(WRITABLE_DIR, "ai_cache")
os.makedirs(AI_CACHE_DIR, exist_ok=True)

database_url = os.environ.get("DATABASE_URL", "")
if IS_VERCEL and not database_url:
    raise RuntimeError("DATABASE_URL must point to persistent Postgres on Vercel")
if database_url.startswith("postgres://"):
    database_url = "postgresql+psycopg://" + database_url[len("postgres://"):]
elif database_url.startswith("postgresql://"):
    database_url = "postgresql+psycopg://" + database_url[len("postgresql://"):]
app.config['SQLALCHEMY_DATABASE_URI'] = database_url or (
    'sqlite:///' + os.path.join(BASE_DIR, 'database.db')
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
if database_url:
    app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {"pool_pre_ping": True}

_DEFAULT_JWT_SECRET = 'dev_secret_change_later_12345'
app.config['JWT_SECRET_KEY'] = os.environ.get(
    "JWT_SECRET_KEY",
    _DEFAULT_JWT_SECRET
)
if IS_VERCEL and app.config['JWT_SECRET_KEY'] == _DEFAULT_JWT_SECRET:
    raise RuntimeError("JWT_SECRET_KEY must be configured on Vercel")
if app.config['JWT_SECRET_KEY'] == _DEFAULT_JWT_SECRET:
    print(
        "[server] WARNING: JWT_SECRET_KEY is not set - using the public "
        "default from source. Anyone who has read this repository can "
        "forge a valid login token. Set a real JWT_SECRET_KEY before "
        "deploying anywhere reachable by players."
    )
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(days=7)

# There's no player-facing password reset (no email on file for accounts),
# so a forgotten password is recovered by whoever holds this key running
# the /admin/reset-password endpoint below. Same env-var-with-dev-fallback
# pattern as JWT_SECRET_KEY above.
_DEFAULT_ADMIN_RESET_KEY = 'dev_admin_reset_change_later_12345'
ADMIN_RESET_KEY = os.environ.get("ADMIN_RESET_KEY", _DEFAULT_ADMIN_RESET_KEY)
if ADMIN_RESET_KEY == _DEFAULT_ADMIN_RESET_KEY:
    print(
        "[server] WARNING: ADMIN_RESET_KEY is not set - using the public "
        "default from source. Anyone who has read this repository can "
        "reset any player's password. Set a real ADMIN_RESET_KEY before "
        "deploying anywhere reachable by players."
    )

# A browser-hosted export talks to this API from a different origin than
# the one serving the game, so without CORS every request gets blocked
# client-side regardless of whether the server itself responds correctly.
# Comma-separated so a deploy can lock this down to the real game origin
# (e.g. "https://play.example.com") instead of leaving it wide open.
_cors_origins = os.environ.get("CORS_ALLOWED_ORIGINS", "*")
CORS(
    app,
    origins=[o.strip() for o in _cors_origins.split(",")] if _cors_origins != "*" else "*",
    supports_credentials=False
)

# Standard fix for an unauthenticated client filling the server disk via
# /upload_artwork: reject the request before it's fully read, rather than
# after it's already on disk.
app.config['MAX_CONTENT_LENGTH'] = int(os.environ.get(
    "MAX_UPLOAD_BYTES",
    4 * 1024 * 1024 if IS_VERCEL else 20 * 1024 * 1024
))

db = SQLAlchemy(app)
jwt = JWTManager(app)

UPLOAD_FOLDER = os.path.join(WRITABLE_DIR, "uploads")
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# =========================
# MODELS
# =========================

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.LargeBinary, nullable=False)
    # Hashed the same way as password_hash (bcrypt) - never stored or logged
    # in plaintext after it's shown to the player once at issuance. Nullable
    # because db.create_all() only creates missing tables, it never alters
    # existing ones - any account already in a live database.db has no
    # recovery code until a migration backfills this column, and self-reset
    # can't work for that account until a code is actually issued.
    recovery_code_hash = db.Column(db.LargeBinary, nullable=True)
    if os.environ.get("AUTH_PROVIDER") == "cognito":
        cognito_sub = db.Column(db.String(64), unique=True, nullable=True)

class Artwork(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(
    db.Integer,
    db.ForeignKey('user.id'),
    nullable=False
)
    title = db.Column(db.String(100), nullable=False)
    filename = db.Column(db.String(255), nullable=False)
    is_public = db.Column(db.Boolean, default=False)


class ArtworkBlob(db.Model):
    """Persist serverless uploads without changing the existing Artwork table."""
    artwork_id = db.Column(db.Integer, db.ForeignKey('artwork.id'), primary_key=True)
    image_data = db.Column(db.LargeBinary, nullable=False)

# Runs at import time, not just under `if __name__ == '__main__'`: a
# production WSGI server (gunicorn) imports this module and calls the `app`
# object directly, it never executes the __main__ block, so table creation
# has to happen here or a fresh deploy has no `user`/`artwork` tables at all.
if os.environ.get("AUTO_CREATE_SCHEMA", "true").lower() == "true":
    with app.app_context():
        db.create_all()

def current_user_id():
    return int(getattr(g, "cognito_user_id", None) or get_jwt_identity())


# =========================
# REGISTER
# =========================

# Players have no email on file, so a lost password otherwise means the
# admin-key tool is the only way back into an account. This code is the
# self-service alternative: returned in plaintext exactly once, in the
# /register response below, and never stored or logged anywhere after that -
# only its bcrypt hash lives in recovery_code_hash. If the player doesn't
# save it, they're back to the admin tool anyway.
def _generate_recovery_code():
    raw = secrets.token_hex(5).upper()
    formatted = f"{raw[0:4]}-{raw[4:8]}-{raw[8:10]}"
    hashed = bcrypt.hashpw(formatted.encode('utf-8'), bcrypt.gensalt())
    return formatted, hashed


@app.route('/register', methods=['POST'])
def register():
    data = request.get_json(silent=True) or {}

    username = data.get("username")
    password = data.get("password")

    if not username or not password:
        return jsonify({"error": "Missing username or password"}), 400

    if User.query.filter_by(username=username).first():
        return jsonify({"error": "Username already exists"}), 400

    hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
    recovery_code, recovery_code_hash = _generate_recovery_code()

    user = User(
        username=username,
        password_hash=hashed,
        recovery_code_hash=recovery_code_hash
    )
    db.session.add(user)
    db.session.commit()

    return jsonify({
        "message": "User registered successfully",
        "recovery_code": recovery_code
    }), 201

# =========================
# LOGIN
# =========================

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json(silent=True) or {}

    username = data.get("username")
    password = data.get("password")

    if not username or not password:
        return jsonify({"error": "Missing username or password"}), 400

    user = User.query.filter_by(username=username).first()

    if not user:
        return jsonify({"error": "Invalid credentials"}), 401

    if not bcrypt.checkpw(password.encode('utf-8'), user.password_hash):
        return jsonify({"error": "Invalid credentials"}), 401

    # One login per account, newest wins: this login's id replaces the last
    # one's, which signs out the other device on its next request.
    session_id = secrets.token_hex(16)
    active = db.session.get(ActiveSession, user.id)
    if active is None:
        db.session.add(ActiveSession(user_id=user.id, session_id=session_id))
    else:
        active.session_id = session_id
    db.session.commit()
    token = create_access_token(identity=str(user.id), additional_claims={"sid": session_id})

    return jsonify({"token": token})


# Rejects a token from an account's older login. A token without a session id
# (issued before this check existed) is only refused once the account has
# logged in again. Cognito (aws_app.py) manages its own sessions and tokens.
if os.environ.get("AUTH_PROVIDER") != "cognito":
    @jwt.token_in_blocklist_loader
    def _signed_in_elsewhere(_header, payload):
        active = db.session.get(ActiveSession, int(payload["sub"]))
        return active is not None and payload.get("sid") != active.session_id

    @jwt.revoked_token_loader
    def _signed_in_elsewhere_response(_header, _payload):
        return jsonify({
            "error": "signed_in_elsewhere",
            "message": "This account was signed in on another device.",
        }), 401


# The game asks this every so often, so a device signed out by a newer login
# finds out promptly rather than at its next save.
@app.route('/session', methods=['GET'])
@jwt_required()
def session_status():
    return jsonify({"ok": True}), 200

# =========================
# SELF-SERVICE PASSWORD RESET
# =========================

# Keyed on username rather than IP, unlike the admin lockout below: this
# project is used in schools and community programs (see
# facilitator_settings.gd), so many players can share one IP behind a
# school's NAT. Locking by IP would lock out a whole classroom after one
# kid mistypes a code a few times; locking by username only blocks further
# attempts against the one account actually being guessed at.
RECOVERY_RESET_LOCK = threading.Lock()
RECOVERY_RESET_ATTEMPTS = {}
RECOVERY_RESET_MAX_ATTEMPTS = 5
RECOVERY_RESET_LOCKOUT_SECONDS = 15 * 60


def _recovery_reset_is_locked_out(username):
    with RECOVERY_RESET_LOCK:
        state = RECOVERY_RESET_ATTEMPTS.get(username)
        if not state:
            return False
        return (
            state["failures"] >= RECOVERY_RESET_MAX_ATTEMPTS
            and time.monotonic() < state["locked_until"]
        )


def _record_recovery_reset_failure(username):
    with RECOVERY_RESET_LOCK:
        state = RECOVERY_RESET_ATTEMPTS.setdefault(
            username, {"failures": 0, "locked_until": 0.0}
        )
        state["failures"] += 1
        if state["failures"] >= RECOVERY_RESET_MAX_ATTEMPTS:
            state["locked_until"] = time.monotonic() + RECOVERY_RESET_LOCKOUT_SECONDS


def _clear_recovery_reset_failures(username):
    with RECOVERY_RESET_LOCK:
        RECOVERY_RESET_ATTEMPTS.pop(username, None)


@app.route('/reset-password-with-code', methods=['POST'])
def reset_password_with_code():
    data = request.json

    username = data.get("username")
    recovery_code = data.get("recovery_code")
    new_password = data.get("new_password")

    if not username or not recovery_code or not new_password:
        return jsonify({"error": "Missing username, recovery_code, or new_password"}), 400

    if _recovery_reset_is_locked_out(username):
        return jsonify({"error": "Too many attempts. Try again later."}), 429

    user = User.query.filter_by(username=username).first()

    # Same error for "no such user" and "wrong code" - a distinct "user not
    # found" response would let an attacker enumerate valid usernames just by
    # probing this endpoint.
    if not user or not user.recovery_code_hash or not bcrypt.checkpw(
        recovery_code.encode('utf-8'), user.recovery_code_hash
    ):
        _record_recovery_reset_failure(username)
        return jsonify({"error": "Invalid username or recovery code"}), 401

    _clear_recovery_reset_failures(username)

    user.password_hash = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt())

    # One-time use: the code just spent is replaced with a fresh one, handed
    # back the same way the original was at registration.
    new_recovery_code, new_recovery_code_hash = _generate_recovery_code()
    user.recovery_code_hash = new_recovery_code_hash

    db.session.commit()

    print(f"[server] Self-service password reset for user '{username}'")

    return jsonify({
        "message": "Password reset successfully",
        "recovery_code": new_recovery_code
    }), 200

# =========================
# ADMIN PASSWORD RESET
# =========================

# A wrong-but-unlimited admin_key guess is a brute-forceable key with no
# lockout - the thing /login already avoids via bcrypt being slow, but a
# plain secrets.compare_digest has no such cost. Locked out per source IP
# after a handful of failures, same in-memory dict+lock shape as the AI
# circuit breaker above rather than pulling in a rate-limiting dependency
# for one endpoint.
#
# Keyed on request.remote_addr: the real caller's address directly, or behind
# nginx the one it forwards (BEHIND_PROXY, at the top of this file).
ADMIN_RESET_LOCK = threading.Lock()
ADMIN_RESET_ATTEMPTS = {}
ADMIN_RESET_MAX_ATTEMPTS = 5
ADMIN_RESET_LOCKOUT_SECONDS = 15 * 60


def _admin_reset_is_locked_out(ip):
    with ADMIN_RESET_LOCK:
        state = ADMIN_RESET_ATTEMPTS.get(ip)
        if not state:
            return False
        return (
            state["failures"] >= ADMIN_RESET_MAX_ATTEMPTS
            and time.monotonic() < state["locked_until"]
        )


def _record_admin_reset_failure(ip):
    with ADMIN_RESET_LOCK:
        state = ADMIN_RESET_ATTEMPTS.setdefault(
            ip, {"failures": 0, "locked_until": 0.0}
        )
        state["failures"] += 1
        if state["failures"] >= ADMIN_RESET_MAX_ATTEMPTS:
            state["locked_until"] = time.monotonic() + ADMIN_RESET_LOCKOUT_SECONDS


def _clear_admin_reset_failures(ip):
    with ADMIN_RESET_LOCK:
        ADMIN_RESET_ATTEMPTS.pop(ip, None)


@app.route('/admin/reset-password', methods=['POST'])
def admin_reset_password():
    client_ip = request.remote_addr

    if _admin_reset_is_locked_out(client_ip):
        return jsonify({"error": "Too many attempts. Try again later."}), 429

    data = request.json

    admin_key = data.get("admin_key")
    username = data.get("username")
    new_password = data.get("new_password")

    if not admin_key or not secrets.compare_digest(admin_key, ADMIN_RESET_KEY):
        _record_admin_reset_failure(client_ip)
        print(f"[server] WARNING: failed admin password reset attempt from {client_ip}")
        return jsonify({"error": "Invalid credentials"}), 401

    _clear_admin_reset_failures(client_ip)

    if not username or not new_password:
        return jsonify({"error": "Missing username or new_password"}), 400

    user = User.query.filter_by(username=username).first()
    if not user:
        return jsonify({"error": "User not found"}), 404

    user.password_hash = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt())

    # An admin reset is also the moment to (re)issue a recovery code: the
    # player needed help getting back in at all, so handing them a fresh
    # self-service code now means next time they might not need to. This
    # also backfills accounts from before this feature existed, which
    # otherwise have recovery_code_hash = NULL forever.
    new_recovery_code, new_recovery_code_hash = _generate_recovery_code()
    user.recovery_code_hash = new_recovery_code_hash

    db.session.commit()

    print(f"[server] Admin password reset for user '{username}' from {client_ip}")

    return jsonify({
        "message": "Password reset successfully",
        "recovery_code": new_recovery_code
    }), 200

# =========================
# UPLOAD ARTWORK
# =========================

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "webp"}

def allowed_file(filename):
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/upload_artwork', methods=['POST'])
@jwt_required()
def upload_artwork():
    user_id = int(get_jwt_identity())

    image_data = request.data

    if not image_data:
        return jsonify({
            "message": "No image data received"
        }), 400

    title = request.headers.get("Artwork-Title", "Untitled")

    safe_title = secure_filename(title)

    if not safe_title:
        safe_title = "untitled"

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    unique_id = uuid4().hex[:8]

    filename = f"{safe_title}_{timestamp}_{unique_id}.png"

    artwork = Artwork(
        user_id=user_id,
        title=title,
        filename=filename,
        is_public=False
    )

    if not IS_VERCEL:
        user_folder = os.path.join(UPLOAD_FOLDER, f"user_{user_id}")
        os.makedirs(user_folder, exist_ok=True)
        save_path = os.path.join(user_folder, filename)
        with open(save_path, "wb") as artwork_file:
            artwork_file.write(image_data)

    db.session.add(artwork)
    db.session.flush()
    if IS_VERCEL:
        db.session.add(ArtworkBlob(artwork_id=artwork.id, image_data=image_data))
    db.session.commit()

    return jsonify({
        "message": "Artwork uploaded successfully"
    }), 200

# =========================
# DOWNLOAD ARTWORK
# =========================

@app.route('/download_artwork/<int:artwork_id>', methods=['GET'])
@jwt_required(optional=True)
def download_artwork(artwork_id):

    artwork = Artwork.query.filter_by(id=artwork_id).first()

    # A player's artwork is only ever available to their own account: anyone
    # else (or no login at all) gets the same answer as for a missing one. It
    # used to need no login, so any id could be fetched by anyone.
    identity = get_jwt_identity()
    if not artwork or identity is None or int(identity) != artwork.user_id:
        return jsonify({"error": "Artwork not found"}), 404

    stored_blob = db.session.get(ArtworkBlob, artwork.id)
    if stored_blob is not None:
        return send_file(BytesIO(stored_blob.image_data), mimetype="image/png",
                         download_name=artwork.filename)

    file_path = os.path.join(
        UPLOAD_FOLDER,
        f"user_{artwork.user_id}",
        artwork.filename
    )

    if not os.path.exists(file_path):
        return jsonify({"error": "File missing on server"}), 404

    return send_file(file_path)

# =========================
# DOWNLOAD 12 RECENT ARTWORKS
# =========================

@app.route('/my_artworks', methods=['GET'])
@jwt_required()
def my_artworks():
    user_id = current_user_id()

    artworks = Artwork.query.filter_by(user_id=user_id)\
        .order_by(Artwork.id.desc())\
        .limit(12)\
        .all()

    result = []

    for art in artworks:
        result.append({
            "id": art.id,
            "title": art.title,
            "filename": art.filename,
            "url": f"/download_artwork/{art.id}"
        })

    return jsonify(result), 200

# ==================================================
# FUTURE AI INTEGRATION
#
# Default project uses local LLM in Godot.
#
# To enable OpenRouter:
# 1. Insert API key
# 2. Set USE_OPENROUTER = True
# 3. Route NPC requests through /ai/chat
#
# Existing implementation tested and functional.
# ==================================================

@app.route('/ai/chat', methods=['POST'])
def ai_chat():
    print("OPENROUTER TEST MODE ACTIVE 1")
    data = request.json
    messages = data.get("messages", [])

    print("OPENROUTER TEST MODE ACTIVE 2")
    if not messages:
        print("OPENROUTER TEST MODE ACTIVE 3")
        return jsonify({"error": "No messages provided"}), 400

    last_message = messages[-1]["content"]

    # -------------------------
    # LOCAL MODE (GAME USE)
    # -------------------------
    local_reply = f"EC2 stub response: {last_message}"
    print("OPENROUTER TEST MODE ACTIVE 4")

    # -------------------------
    # OPENROUTER MODE
    # -------------------------

    if USE_OPENROUTER:
        print("OPENROUTER TEST MODE ACTIVE")
        result = call_openrouter(messages)

        if result:
            return jsonify({
                "status": "openrouter_test",
                "reply": result
            }), 200

    # fallback
    return jsonify({
        "status": "local_stub",
        "reply": local_reply
    }), 200

def call_openrouter(messages):
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "model": "openai/gpt-oss-20b:free",
        "messages": messages,
        "temperature": 0.7
    }

    try:
        response = requests.post(
            OPENROUTER_URL,
            headers=headers,
            json=payload,
            timeout=15
        )

        if response.status_code != 200:
            print("OpenRouter request failed with HTTP status:", response.status_code)
            return None

        data = response.json()

        return data["choices"][0]["message"]["content"]

    except Exception as e:
        print("OpenRouter exception:", str(e))
        return None


# =========================
# OMNIROUTE CREATIVE AI
# =========================

class OmniRouteRequestError(Exception):
    def __init__(self, message, status_code=None, retryable=True):
        super().__init__(message)
        self.status_code = status_code
        self.retryable = retryable


AI_CIRCUIT_LOCK = threading.Lock()
AI_CIRCUITS = {}
AI_HEALTH_MONITOR_LOCK = threading.Lock()
AI_HEALTH_MONITOR_THREAD = None
AI_HEALTH_MONITOR_STOP = threading.Event()


def _key_slots(service):
    primary_key = (
        OMNIROUTE_CREATIVE_GUIDE_API_KEY
        if service == "creative_guide"
        else OMNIROUTE_WORLD_BUILDER_API_KEY
    )
    candidates = [
        (f"{service}:primary", "primary", primary_key),
        (f"{service}:backup", "backup", OMNIROUTE_BACKUP_API_KEY)
    ]

    slots = []
    seen = set()
    for circuit_id, source, api_key in candidates:
        if api_key and api_key not in seen:
            slots.append((circuit_id, source, api_key))
            seen.add(api_key)
    return slots


def _circuit_state(circuit_id):
    with AI_CIRCUIT_LOCK:
        return dict(AI_CIRCUITS.get(circuit_id, {
            "failures": 0,
            "opened_until": 0.0,
            "last_error": "",
            "last_success": 0.0
        }))


def _circuit_is_available(circuit_id):
    return _circuit_state(circuit_id)["opened_until"] <= time.monotonic()


def _record_circuit_success(circuit_id):
    with AI_CIRCUIT_LOCK:
        AI_CIRCUITS[circuit_id] = {
            "failures": 0,
            "opened_until": 0.0,
            "last_error": "",
            "last_success": time.time()
        }


def _record_circuit_failure(circuit_id, error):
    with AI_CIRCUIT_LOCK:
        previous = AI_CIRCUITS.get(circuit_id, {})
        AI_CIRCUITS[circuit_id] = {
            "failures": int(previous.get("failures", 0)) + 1,
            "opened_until": time.monotonic() + AI_CIRCUIT_COOLDOWN_SECONDS,
            "last_error": str(error),
            "last_success": float(previous.get("last_success", 0.0))
        }


def _circuit_summary(service):
    summary = {}
    now = time.monotonic()
    for circuit_id, source, _api_key in _key_slots(service):
        state = _circuit_state(circuit_id)
        summary[source] = {
            "state": "open" if state["opened_until"] > now else "ready",
            "failures": state["failures"],
            "retry_in_seconds": max(0, round(state["opened_until"] - now, 1)),
            "last_success": state["last_success"] or None
        }
    return summary


def _validated_image_data_url(encoded_image, mime_type):
    if not encoded_image:
        return None

    if not isinstance(encoded_image, str):
        raise ValueError("artwork_base64 must be a string")

    raw_base64 = encoded_image.strip()
    detected_mime = mime_type or "image/png"

    if raw_base64.startswith("data:"):
        try:
            header, raw_base64 = raw_base64.split(",", 1)
            detected_mime = header[5:].split(";", 1)[0]
        except ValueError as exc:
            raise ValueError("Invalid artwork data URL") from exc

    if detected_mime not in AI_IMAGE_MIME_TYPES:
        raise ValueError("Artwork must be PNG, JPEG, or WebP")

    try:
        image_bytes = base64.b64decode(raw_base64, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise ValueError("Invalid base64 artwork") from exc

    if not image_bytes:
        raise ValueError("Artwork image is empty")
    if len(image_bytes) > MAX_AI_IMAGE_BYTES:
        raise ValueError("Artwork image is larger than 8 MB")

    return f"data:{detected_mime};base64,{raw_base64}"


def _json_from_model_text(content):
    if not isinstance(content, str) or not content.strip():
        raise OmniRouteRequestError("The AI returned an empty response")

    cleaned = content.strip()
    if cleaned.startswith("```"):
        lines = cleaned.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        cleaned = "\n".join(lines).strip()

    try:
        result = json.loads(cleaned)
    except json.JSONDecodeError as exc:
        raise OmniRouteRequestError("The AI response was not valid JSON") from exc

    if not isinstance(result, dict):
        raise OmniRouteRequestError("The AI response must be a JSON object")
    return result


def _call_single_omniroute_key(api_key, model, prompt, image_data_url=None):
    if image_data_url:
        user_content = [
            {"type": "text", "text": prompt},
            {"type": "image_url", "image_url": {"url": image_data_url}}
        ]
    else:
        user_content = prompt

    try:
        response = requests.post(
            f"{OMNIROUTE_BASE_URL}/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            },
            json={
                "model": model,
                "messages": [{"role": "user", "content": user_content}],
                "reasoning_effort": "none",
                "temperature": 0.35,
                "max_tokens": 1800,
                "stream": False
            },
            timeout=AI_UPSTREAM_TIMEOUT_SECONDS
        )
    except requests.RequestException as exc:
        raise OmniRouteRequestError(
            "The AI service could not be reached",
            retryable=True
        ) from exc

    if response.status_code != 200:
        retryable = response.status_code in {
            401, 403, 408, 409, 425, 429, 500, 502, 503, 504
        }
        raise OmniRouteRequestError(
            f"The AI service rejected the request (status {response.status_code})",
            status_code=response.status_code,
            retryable=retryable
        )

    try:
        payload = response.json()
        content = payload["choices"][0]["message"]["content"]
    except (ValueError, KeyError, IndexError, TypeError) as exc:
        raise OmniRouteRequestError(
            "The AI service returned an invalid response",
            retryable=True
        ) from exc

    return _json_from_model_text(content)


def _call_omniroute_json(service, model, prompt, image_data_url=None):
    slots = _key_slots(service)
    if not slots:
        raise OmniRouteRequestError("This AI service is not configured")

    attempted = []
    last_error = None
    for circuit_id, source, api_key in slots:
        if not _circuit_is_available(circuit_id):
            continue

        attempted.append(source)
        try:
            result = _call_single_omniroute_key(
                api_key,
                model,
                prompt,
                image_data_url
            )
            _record_circuit_success(circuit_id)
            return result, source
        except OmniRouteRequestError as exc:
            last_error = exc
            _record_circuit_failure(circuit_id, exc)
            if not exc.retryable:
                break

    if not attempted:
        raise OmniRouteRequestError(
            "AI recovery is waiting for the next health check",
            retryable=True
        )
    raise last_error or OmniRouteRequestError("No AI route was available")


def _cache_fingerprint(kind, request_context, image_data_url=None):
    fingerprint_data = {
        "kind": kind,
        "request": request_context,
        "image_sha256": (
            hashlib.sha256(image_data_url.encode("utf-8")).hexdigest()
            if image_data_url else None
        )
    }
    canonical = json.dumps(
        fingerprint_data,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":")
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def _cache_path(kind, fingerprint):
    safe_kind = "creative" if kind == "creative_guide" else "world"
    return os.path.join(AI_CACHE_DIR, f"{safe_kind}_{fingerprint}.json")


def _save_ai_cache(kind, fingerprint, payload):
    cache_path = _cache_path(kind, fingerprint)
    temp_path = f"{cache_path}.{threading.get_ident()}.tmp"
    record = {"saved_at": time.time(), "payload": payload}
    try:
        with open(temp_path, "w", encoding="utf-8") as cache_file:
            json.dump(record, cache_file, ensure_ascii=False, separators=(",", ":"))
        os.replace(temp_path, cache_path)
    except OSError:
        try:
            if os.path.exists(temp_path):
                os.remove(temp_path)
        except OSError:
            pass


def _load_ai_cache(kind, fingerprint):
    cache_path = _cache_path(kind, fingerprint)
    try:
        with open(cache_path, "r", encoding="utf-8") as cache_file:
            record = json.load(cache_file)
    except (OSError, ValueError, TypeError):
        return None

    saved_at = record.get("saved_at")
    payload = record.get("payload")
    if not isinstance(saved_at, (int, float)) or not isinstance(payload, dict):
        return None
    if time.time() - saved_at > AI_CACHE_MAX_AGE_SECONDS:
        return None
    return payload


def _offline_creative_guide(title):
    safe_title = title or "Your Artwork"
    return {
        "title": safe_title,
        "celebration": "Your idea already has its own special spark.",
        "scene_description": (
            "Your original artwork stays exactly as you made it while the creative "
            "guide reconnects."
        ),
        "enhancement_prompt": (
            "Preserve every original mark. Optionally add gentle lighting, clearer "
            "depth, and soft texture without changing the child's idea."
        ),
        "depth_layers": {
            "sky": "Keep the original background colors.",
            "far": "Use the smallest and softest shapes.",
            "mid": "Place supporting scenery here.",
            "near": "Keep the child's main shapes clear.",
            "ground": "Create a wide, safe walking surface."
        },
        "heightmap_guidance": "Use gentle slopes and preserve the main silhouettes.",
        "style_ideas": ["soft watercolor", "paper collage", "storybook pastel"],
        "safety_flags": [],
        "offline": True
    }


def _offline_world_manifest(title, creative_brief, existing_manifest):
    if existing_manifest:
        manifest = copy.deepcopy(existing_manifest)
        manifest.setdefault("world_title", title or "My Living Artwork")
        manifest["recovery"] = {
            "mode": "offline",
            "message": "The current world is preserved; the new idea can be retried automatically."
        }
        if not isinstance(manifest.get("player_edit_options"), list):
            manifest["player_edit_options"] = []
        manifest["player_edit_options"].append({
            "id": "pending_ai_edit",
            "label": "Save this idea for the creative guide",
            "available": True
        })
        return manifest

    palette = creative_brief.get("palette", []) if creative_brief else []
    if not isinstance(palette, list) or not palette:
        palette = ["sky blue", "sun gold", "leaf green", "soft pink"]

    return {
        "world_title": title or "My Living Artwork",
        "celebration": "Your artwork has opened into a gentle world.",
        "creative_intent": "Preserve the player's artwork until the AI reconnects.",
        "visual_style": "child-created storybook world",
        "palette": palette[:8],
        "environment": "A bright, calm meadow beneath the original artwork sky.",
        "zones": [{
            "id": "creation_meadow",
            "type": "safe_exploration_zone",
            "description": "A wide central space with room to draw and add ideas."
        }],
        "terrain": {
            "type": "gentle_meadow",
            "traversable": True,
            "max_slope_degrees": 18
        },
        "objects": [{
            "id": "original_art_portal",
            "type": "artwork_portal",
            "zone": "creation_meadow",
            "position_hint": "center",
            "scale_hint": "large",
            "source": "drawing",
            "asset_hint": "original artwork on a luminous plane",
            "child_editable": False
        }, {
            "id": "creation_light",
            "type": "friendly_light",
            "zone": "creation_meadow",
            "position_hint": "beside the portal",
            "scale_hint": "small",
            "source": "optional_suggestion",
            "asset_hint": "soft glowing orb",
            "child_editable": True
        }],
        "characters": [],
        "animations": [{
            "object_id": "creation_light",
            "action": "float",
            "speed": 0.5
        }],
        "interactions": [{
            "object_id": "original_art_portal",
            "action": "return_to_drawing"
        }],
        "audio": {"mood": "calm", "layers": ["soft wind", "gentle chimes"]},
        "lighting": {"mood": "warm daylight", "intensity": 0.8},
        "camera": {"mode": "third_person", "starting_view": "artwork portal"},
        "depth_map_prompt": "Wide safe ground, gentle middle distance, open sky.",
        "texture_prompts": ["Preserve the child's original colors and marks."],
        "optional_video_prompt": "",
        "player_edit_options": [{
            "id": "draw_more",
            "label": "Add another drawing to this world",
            "available": True
        }],
        "safety_notes": ["Offline template active", "No generated code is executed"],
        "recovery": {"mode": "offline", "retry_automatically": True}
    }


def _world_manifest_from_vision_brief(title, creative_brief):
    """Recover a semantic world from the successful vision-guide response.

    The creative guide and world builder use separate circuits. If the larger
    world request times out after vision already identified concrete subjects,
    preserve that AI result as a validated cache fallback instead of replacing
    it with an unrelated two-object meadow.
    """
    if not isinstance(creative_brief, dict) or not creative_brief:
        return None
    searchable = json.dumps(creative_brief, ensure_ascii=False).lower()
    subject_specs = (
        ("person", ("person", "girl", "boy", "child", "woman", "man"), "foreground center"),
        ("boat", ("boat", "canoe", "ship"), "foreground left"),
        ("pagoda", ("pagoda", "temple"), "background left"),
        ("tree", ("tree", "willow"), "midground right"),
        ("water", ("water", "lake", "river", "sea", "pond"), "foreground center"),
        ("mountain", ("mountain", "hill", "foothill"), "background center"),
        ("bridge", ("bridge",), "midground center"),
        ("house", ("house", "home", "cottage"), "midground left"),
        ("cloud", ("cloud",), "sky"),
        ("sun", ("sun",), "sky right"),
        ("flower", ("flower",), "foreground right"),
        ("bird", ("bird",), "sky left"),
    )
    objects = []
    for subject_type, aliases, position_hint in subject_specs:
        if not any(alias in searchable for alias in aliases):
            continue
        objects.append({
            "id": f"vision_{subject_type}_{len(objects) + 1}",
            "type": subject_type,
            "description": f"the {subject_type} identified by the creative vision guide",
            "position_hint": position_hint,
            "depth_layer": (
                "far" if "background" in position_hint or "sky" in position_hint
                else "near" if "foreground" in position_hint else "middle"
            ),
            "scale_hint": "large" if subject_type in {"water", "mountain"} else "medium",
            "source": "vision_guide_cache",
        })
    if len(objects) < 3:
        return None
    recovered = _upgrade_legacy_semantic_manifest({
        "world_title": title or creative_brief.get("title") or "My Living Artwork",
        "celebration": creative_brief.get("celebration", "Your artwork has opened into a world."),
        "environment": creative_brief.get("scene_description", ""),
        "visual_style": "faithful reconstruction from the creative vision guide",
        "objects": objects,
        "characters": [],
        "animations": [],
        "interactions": [],
    })
    return recovered if _semantic_world_manifest_is_complete(recovered) else None


def _probe_open_circuits_once():
    checked_keys = set()
    for service in ("creative_guide", "world_builder"):
        for circuit_id, _source, api_key in _key_slots(service):
            if api_key in checked_keys or _circuit_is_available(circuit_id):
                continue
            checked_keys.add(api_key)
            try:
                response = requests.get(
                    f"{OMNIROUTE_BASE_URL}/models",
                    headers={"Authorization": f"Bearer {api_key}"},
                    timeout=5
                )
                if response.status_code == 200:
                    for other_service in ("creative_guide", "world_builder"):
                        for other_id, _other_source, other_key in _key_slots(other_service):
                            if other_key == api_key:
                                _record_circuit_success(other_id)
            except requests.RequestException:
                continue


def _health_monitor_loop():
    while not AI_HEALTH_MONITOR_STOP.wait(AI_HEALTH_CHECK_SECONDS):
        _probe_open_circuits_once()


def _ensure_ai_health_monitor_started():
    global AI_HEALTH_MONITOR_THREAD
    if app.config.get("TESTING"):
        return
    if os.environ.get("AI_HEALTH_MONITOR_ENABLED", "true").lower() == "false":
        return

    with AI_HEALTH_MONITOR_LOCK:
        if AI_HEALTH_MONITOR_THREAD and AI_HEALTH_MONITOR_THREAD.is_alive():
            return
        AI_HEALTH_MONITOR_STOP.clear()
        AI_HEALTH_MONITOR_THREAD = threading.Thread(
            target=_health_monitor_loop,
            name="artea-ai-key-health-monitor",
            daemon=True
        )
        AI_HEALTH_MONITOR_THREAD.start()


def _request_json_body():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        raise ValueError("A JSON request body is required")
    return data


def _bounded_text(value, field_name, limit=MAX_AI_PROMPT_CHARS):
    if value is None:
        return ""
    if not isinstance(value, str):
        raise ValueError(f"{field_name} must be a string")

    value = value.strip()
    if len(value) > limit:
        raise ValueError(f"{field_name} is too long")
    return value


def _semantic_world_manifest_is_complete(manifest):
    """Reject manifests that would collapse artwork subjects into generic blocks."""
    if not isinstance(manifest, dict) or manifest.get("schema_version") != 2:
        return False
    subjects = []
    for key in ("objects", "characters"):
        collection = manifest.get(key, [])
        if not isinstance(collection, list):
            return False
        subjects.extend(collection)
    if not subjects:
        return False
    generic_types = {
        "structure", "object", "shape", "region", "art_shape", "unknown",
        "artwork_portal", "painted_subject"
    }
    subject_ids = set()
    for subject in subjects:
        if not isinstance(subject, dict):
            return False
        subject_id = str(subject.get("id", "")).strip()
        subject_type = str(subject.get("type", "")).strip().lower()
        if not subject_id or not subject_type or subject_type in generic_types:
            return False
        if subject_id in subject_ids:
            return False
        subject_ids.add(subject_id)
        bounds = subject.get("bounding_box")
        position = subject.get("normalized_position")
        has_bounds = isinstance(bounds, dict) and all(
            isinstance(bounds.get(axis), (int, float))
            for axis in ("x", "y", "width", "height")
        )
        has_position = isinstance(position, dict) and all(
            isinstance(position.get(axis), (int, float))
            for axis in ("x", "y")
        )
        if not has_bounds or not has_position:
            return False
    return True


def _specific_subject_type(subject):
    combined = " ".join(str(subject.get(key, "")) for key in (
        "type", "id", "label", "description", "asset_hint", "zone"
    )).lower()
    aliases = (
        ("person", ("person", "girl", "boy", "child", "human", "character", "avatar")),
        ("pagoda", ("pagoda", "temple")),
        ("mountain", ("mountain", "hill", "foothill")),
        ("bridge", ("bridge",)),
        ("boat", ("boat", "canoe", "ship")),
        ("tree", ("tree",)),
        ("house", ("house", "home", "cottage")),
        ("building", ("building", "tower")),
        ("water", ("water", "lake", "river", "sea", "pond")),
        ("path", ("path", "road", "dock", "walkway")),
        ("cloud", ("cloud",)),
        ("sun", ("sun",)),
        ("moon", ("moon",)),
        ("flower", ("flower",)),
        ("bird", ("bird",)),
        ("animal", ("animal",)),
    )
    for subject_type, words in aliases:
        if any(word in combined for word in words):
            return subject_type
    raw_type = str(subject.get("type", "")).strip().lower().replace(" ", "_")
    if raw_type not in {"", "structure", "object", "shape", "region", "unknown"}:
        return raw_type
    return "painted_subject"


def _legacy_subject_placement(subject, index, total):
    hint = " ".join(str(subject.get(key, "")) for key in (
        "zone", "position_hint", "depth_layer"
    )).lower()
    x = 0.2 + (0.6 * index / max(1, total - 1))
    y = 0.5
    if "center-left" in hint:
        x = 0.38
    elif "center-right" in hint:
        x = 0.62
    elif "left" in hint:
        x = 0.22
    elif "right" in hint:
        x = 0.78
    elif "center" in hint:
        x = 0.5
    if any(word in hint for word in ("upper", "sky", "background", "far")):
        y = 0.28
    elif any(word in hint for word in ("lower", "foreground", "near", "deck")):
        y = 0.70
    elif "mid" in hint:
        y = 0.5

    subject_type = _specific_subject_type(subject)
    width, height = {
        "person": (0.10, 0.28),
        "tree": (0.22, 0.48),
        "boat": (0.34, 0.20),
        "pagoda": (0.22, 0.34),
        "house": (0.24, 0.30),
        "building": (0.24, 0.34),
        "mountain": (0.38, 0.30),
        "water": (0.90, 0.28),
        "path": (0.32, 0.20),
    }.get(subject_type, (0.20, 0.25))
    scale_hint = str(subject.get("scale_hint", "medium")).lower()
    multiplier = 0.7 if scale_hint == "small" else 1.25 if scale_hint == "large" else 1.0
    width = min(0.94, width * multiplier)
    height = min(0.90, height * multiplier)
    return {
        "normalized_position": {"x": round(x, 3), "y": round(y, 3)},
        "bounding_box": {
            "x": round(max(0.0, min(1.0 - width, x - width / 2)), 3),
            "y": round(max(0.0, min(1.0 - height, y - height / 2)), 3),
            "width": round(width, 3),
            "height": round(height, 3),
        },
    }


def _upgrade_legacy_semantic_manifest(manifest):
    """Upgrade useful legacy vision labels into the strict spatial contract."""
    if not isinstance(manifest, dict):
        return manifest
    upgraded = copy.deepcopy(manifest)
    raw_subjects = []
    for key in ("objects", "characters"):
        values = upgraded.get(key, [])
        if isinstance(values, list):
            raw_subjects.extend(value for value in values if isinstance(value, dict))

    environment_text = json.dumps({
        "environment": upgraded.get("environment", ""),
        "terrain": upgraded.get("terrain", []),
        "zones": upgraded.get("zones", []),
    }).lower()
    present_types = {_specific_subject_type(item) for item in raw_subjects}
    for environment_type, words in (
        ("water", ("water", "lake", "river", "pond", "sea")),
        ("mountain", ("mountain", "foothill", "hill")),
        ("path", ("dock", "path", "road", "walkway")),
    ):
        if environment_type not in present_types and any(word in environment_text for word in words):
            raw_subjects.append({
                "id": f"painted_{environment_type}",
                "type": environment_type,
                "description": f"the painted {environment_type} environment",
                "zone": "background" if environment_type == "mountain" else "foreground",
                "scale_hint": "large",
                "source": "drawing",
            })
            present_types.add(environment_type)

    objects = []
    seen_ids = set()
    total = len(raw_subjects)
    for index, raw_subject in enumerate(raw_subjects):
        subject = copy.deepcopy(raw_subject)
        subject_id = str(subject.get("id", f"painted_subject_{index + 1}"))
        if subject_id in seen_ids:
            continue
        seen_ids.add(subject_id)
        subject_type = _specific_subject_type(subject)
        subject["id"] = subject_id
        subject["type"] = subject_type
        subject.setdefault(
            "description",
            str(subject.get("asset_hint", subject_id.replace("_", " ")))
        )
        placement = _legacy_subject_placement(subject, index, total)
        subject.setdefault("normalized_position", placement["normalized_position"])
        subject.setdefault("bounding_box", placement["bounding_box"])
        subject.setdefault("depth_layer", "middle")
        subject.setdefault("scale_hint", "medium")
        subject.setdefault("animation", "sway" if subject_type in {"tree", "flower"} else "breathe")
        objects.append(subject)

    upgraded["schema_version"] = 2
    upgraded["objects"] = objects
    upgraded["characters"] = []
    upgraded.setdefault("animations", [])
    upgraded.setdefault("interactions", [])
    return upgraded


def _ai_client_is_authorized():
    """Allow signed users everywhere and unsigned game clients on loopback only."""
    if get_jwt_identity() is not None:
        return True
    allow_local_guests = os.environ.get(
        "AI_ALLOW_LOOPBACK_GUESTS", "1"
    ).strip().lower() in {"1", "true", "yes", "on"}
    return allow_local_guests and request.remote_addr in {"127.0.0.1", "::1"}


@app.route('/ai/status', methods=['GET'])
def ai_status():
    _ensure_ai_health_monitor_started()
    return jsonify({
        "creative_guide": {
            "configured": bool(OMNIROUTE_CREATIVE_GUIDE_API_KEY),
            "model": OMNIROUTE_CREATIVE_GUIDE_MODEL,
            "circuits": _circuit_summary("creative_guide")
        },
        "world_builder": {
            "configured": bool(OMNIROUTE_WORLD_BUILDER_API_KEY),
            "model": OMNIROUTE_WORLD_BUILDER_MODEL,
            "circuits": _circuit_summary("world_builder")
        },
        "recovery": {
            "backup_key_configured": bool(OMNIROUTE_BACKUP_API_KEY),
            "offline_fallback": True,
            "cache": True,
            "automatic_health_check_seconds": AI_HEALTH_CHECK_SECONDS
        }
    }), 200


@app.route('/ai/creative-guide', methods=['POST'])
@jwt_required(optional=True)
def ai_creative_guide():
    if not _ai_client_is_authorized():
        return jsonify({"error": "Authentication required"}), 401
    try:
        _ensure_ai_health_monitor_started()
        data = _request_json_body()
        prompt = _bounded_text(
            data.get("prompt", "Please help me explore ideas for this artwork."),
            "prompt"
        )
        if not prompt:
            prompt = "Please help me explore ideas for this artwork."

        title = _bounded_text(data.get("title", "Untitled"), "title", 120)
        image_data_url = _validated_image_data_url(
            data.get("artwork_base64"),
            data.get("mime_type", "image/png")
        )
        guide_prompt = (
            f"Artwork title: {title or 'Untitled'}\n"
            f"Child's request: {prompt}\n"
            "Celebrate the child's choices, offer three optional creative directions, "
            "and prepare a gentle enhancement prompt without replacing their intent. "
            "Also inspect the entire image and include visual_inventory: one entry for "
            "every visible person, creature, plant, building, object, symbol, celestial "
            "body, and important environment region. Each inventory entry needs label, "
            "type, normalized bounding_box {x,y,width,height}, depth_layer, dominant_color, "
            "and suggested_motion. Do not combine separate visible subjects."
        )
        fingerprint = _cache_fingerprint(
            "creative_guide",
            {"title": title, "prompt": prompt},
            image_data_url
        )

        try:
            guide, ai_source = _call_omniroute_json(
                "creative_guide",
                OMNIROUTE_CREATIVE_GUIDE_MODEL,
                guide_prompt,
                image_data_url
            )
            _save_ai_cache("creative_guide", fingerprint, guide)
            status = "ok"
        except OmniRouteRequestError:
            guide = _load_ai_cache("creative_guide", fingerprint)
            if guide:
                ai_source = "cache"
                status = "cached_fallback"
            else:
                guide = _offline_creative_guide(title)
                ai_source = "offline"
                status = "offline_fallback"

        return jsonify({
            "status": status,
            "model": OMNIROUTE_CREATIVE_GUIDE_MODEL,
            "ai_source": ai_source,
            "degraded": ai_source in {"cache", "offline"},
            "guide": guide
        }), 200
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400


@app.route('/ai/world-builder', methods=['POST'])
@jwt_required(optional=True)
def ai_world_builder():
    if not _ai_client_is_authorized():
        return jsonify({"error": "Authentication required"}), 401
    try:
        _ensure_ai_health_monitor_started()
        data = _request_json_body()
        child_request = _bounded_text(
            data.get("prompt", "Turn my artwork into a gentle world I can explore."),
            "prompt"
        )
        title = _bounded_text(data.get("title", "Untitled World"), "title", 120)
        creative_brief = data.get("creative_brief")
        existing_manifest = data.get("existing_manifest")

        if creative_brief is not None and not isinstance(creative_brief, dict):
            raise ValueError("creative_brief must be a JSON object")
        if existing_manifest is not None and not isinstance(existing_manifest, dict):
            raise ValueError("existing_manifest must be a JSON object")

        context = json.dumps({
            "creative_brief": creative_brief or {},
            "existing_manifest": existing_manifest or {}
        }, ensure_ascii=False)
        if len(context) > MAX_WORLD_CONTEXT_CHARS:
            raise ValueError("World context is too large")

        image_data_url = _validated_image_data_url(
            data.get("artwork_base64"),
            data.get("mime_type", "image/png")
        )
        task = "update_world" if existing_manifest else "create_world"
        world_prompt = (
            f"Task: {task}\n"
            f"World title: {title or 'Untitled World'}\n"
            f"Child's request: {child_request}\n"
            f"Context JSON: {context}\n"
            "Return JSON using schema_version 2 with arrays named objects, characters, "
            "animations, and interactions. Inspect the artwork and "
            "represent every clearly visible subject (characters, animals, plants, "
            "buildings, sky objects, water, symbols, and important shapes) as its own "
            "entry in objects or characters. Give every entry a stable id, type, "
            "description, normalized_position with x and y from 0 to 1, normalized "
            "bounding_box {x,y,width,height}, depth_layer (near/middle/far), scale_hint, "
            "animation, and a safe interaction entry describing how it reacts when "
            "the player touches or activates it. Put sky, ground, roads and water in "
            "objects too, with their own bounds. Never return a single portal or one "
            "flat artwork object when multiple subjects are visible. The result must be a walkable 3D "
            "mini-world, not a flat image or video. When updating a world, preserve "
            "existing object ids and change only what the child requested. "
            "The top-level schema_version must be the number 2. Do not omit or rename "
            "bounding_box or normalized_position. A valid subject looks like: "
            '{"id":"painted_tree_1","type":"tree","description":"the tall pink tree",'
            '"normalized_position":{"x":0.72,"y":0.46},"bounding_box":'
            '{"x":0.64,"y":0.16,"width":0.18,"height":0.58},"depth_layer":"middle",'
            '"scale_hint":"large","animation":"sway"}. '
            "Use specific semantic types such as person, tree, boat, pagoda, house, "
            "bridge, mountain, river, cloud, sun, path, or flowerâ€”not structure/object."
        )
        fingerprint = _cache_fingerprint(
            "world_builder",
            {
                "title": title,
                "prompt": child_request,
                "creative_brief": creative_brief or {},
                "existing_manifest": existing_manifest or {}
            },
            image_data_url
        )

        try:
            manifest, ai_source = _call_omniroute_json(
                "world_builder",
                OMNIROUTE_WORLD_BUILDER_MODEL,
                world_prompt,
                image_data_url
            )
            manifest = _upgrade_legacy_semantic_manifest(manifest)
            if not _semantic_world_manifest_is_complete(manifest):
                retry_prompt = (
                    world_prompt
                    + "\nYour previous answer was rejected because schema_version 2, "
                    "specific semantic types, bounding_box, or normalized_position was "
                    "missing. Re-inspect the image and return one corrected JSON object now."
                )
                manifest, ai_source = _call_omniroute_json(
                    "world_builder",
                    OMNIROUTE_WORLD_BUILDER_MODEL,
                    retry_prompt,
                    image_data_url
                )
                manifest = _upgrade_legacy_semantic_manifest(manifest)
            if not _semantic_world_manifest_is_complete(manifest):
                raise OmniRouteRequestError(
                    "Vision returned an incomplete semantic world",
                    retryable=True
                )
            _save_ai_cache("world_builder", fingerprint, manifest)
            status = "ok"
        except OmniRouteRequestError:
            manifest = _load_ai_cache("world_builder", fingerprint)
            if manifest and _semantic_world_manifest_is_complete(manifest):
                ai_source = "cache"
                status = "cached_fallback"
            else:
                manifest = _world_manifest_from_vision_brief(
                    title, creative_brief or {}
                )
                if manifest:
                    ai_source = "cache"
                    status = "vision_brief_cache_fallback"
                    _save_ai_cache("world_builder", fingerprint, manifest)
                else:
                    manifest = _offline_world_manifest(
                        title,
                        creative_brief or {},
                        existing_manifest or {}
                    )
                    ai_source = "offline"
                    status = "offline_fallback"

        return jsonify({
            "status": status,
            "model": OMNIROUTE_WORLD_BUILDER_MODEL,
            "task": task,
            "ai_source": ai_source,
            "degraded": ai_source in {"cache", "offline"},
            "semantic_ready": (
                ai_source != "offline"
                and _semantic_world_manifest_is_complete(manifest)
            ),
            "world_manifest": manifest
        }), 200
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400
    


# =========================
# HEALTH CHECK
# =========================

@app.route('/')
def home():
    return jsonify({"status": "server running"})

# =========================
# MAIN
# =========================

if __name__ == '__main__':
    # This is Flask's own dev server - single-threaded, no hardening, and
    # its own startup banner says not to use it in production. Production
    # deploys run this module under gunicorn instead (see flaskapp.service),
    # which never reaches this block at all.
    app.run(
        host=os.environ.get('HOST', '0.0.0.0'),
        port=int(os.environ.get('PORT', 80)),
        debug=False
    )
