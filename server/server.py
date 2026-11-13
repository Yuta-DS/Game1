from flask import Flask, request, jsonify, send_file
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import (
    JWTManager,
    create_access_token,
    jwt_required,
    get_jwt_identity
)
import bcrypt
import os
from datetime import timedelta, datetime
from werkzeug.utils import secure_filename
from uuid import uuid4
import requests

app = Flask(__name__)

WEB_ALLOWED_ORIGINS = {
    origin.strip()
    for origin in os.environ.get(
        "ARTEA_WEB_ALLOWED_ORIGINS",
        "http://localhost:8060,http://127.0.0.1:8060",
    ).split(",")
    if origin.strip()
}


@app.after_request
def add_web_api_headers(response):
    """Allow the local Godot web build; production uses the same-origin proxy."""
    origin = request.headers.get("Origin", "")
    if origin in WEB_ALLOWED_ORIGINS:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        response.headers["Vary"] = "Origin"
    return response

# =========================
# CONFIG
# =========================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
USE_OPENROUTER = bool(OPENROUTER_API_KEY)

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(BASE_DIR, 'database.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

app.config['JWT_SECRET_KEY'] = os.environ.get(
    'ARTEA_JWT_SECRET_KEY',
    'dev_secret_change_later_12345',
)
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(days=7)

db = SQLAlchemy(app)
jwt = JWTManager(app)

UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads")
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# =========================
# MODELS
# =========================

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.LargeBinary, nullable=False)

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

# =========================
# REGISTER
# =========================

@app.route('/register', methods=['POST'])
def register():
    data = request.json

    username = data.get("username")
    password = data.get("password")

    if not username or not password:
        return jsonify({"error": "Missing username or password"}), 400

    if User.query.filter_by(username=username).first():
        return jsonify({"error": "Username already exists"}), 400

    hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())

    user = User(username=username, password_hash=hashed)
    db.session.add(user)
    db.session.commit()

    return jsonify({"message": "User registered successfully"}), 201

# =========================
# LOGIN
# =========================

@app.route('/login', methods=['POST'])
def login():
    data = request.json

    username = data.get("username")
    password = data.get("password")

    user = User.query.filter_by(username=username).first()

    if not user:
        return jsonify({"error": "Invalid credentials"}), 401

    if not bcrypt.checkpw(password.encode('utf-8'), user.password_hash):
        return jsonify({"error": "Invalid credentials"}), 401

    token = create_access_token(identity=str(user.id))

    return jsonify({"token": token})

# =========================
# UPLOAD ARTWORK
# =========================

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "webp"}

def allowed_file(filename):
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/upload_artwork', methods=['POST'])
@jwt_required()
def upload_artwork():
    print("HEADERS:", dict(request.headers))
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

    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    unique_id = uuid4().hex[:8]

    filename = f"{safe_title}_{timestamp}_{unique_id}.png"

    user_folder = os.path.join(
        UPLOAD_FOLDER,
        f"user_{user_id}"
    )

    os.makedirs(user_folder, exist_ok=True)

    save_path = os.path.join(user_folder, filename)

    with open(save_path, "wb") as f:
        f.write(image_data)

    artwork = Artwork(
        user_id=user_id,
        title=title,
        filename=filename,
        is_public=False
    )

    db.session.add(artwork)
    db.session.commit()

    return jsonify({
        "message": "Artwork uploaded successfully"
    }), 200

# =========================
# DOWNLOAD ARTWORK
# =========================

@app.route('/download_artwork/<int:artwork_id>', methods=['GET'])
def download_artwork(artwork_id):

    artwork = Artwork.query.filter_by(id=artwork_id).first()

    if not artwork:
        return jsonify({"error": "Artwork not found"}), 404

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
    user_id = int(get_jwt_identity())

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
            print("OpenRouter error:", response.text)
            return None

        data = response.json()

        return data["choices"][0]["message"]["content"]

    except Exception as e:
        print("OpenRouter exception:", str(e))
        return None
    


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
    with app.app_context():
        db.create_all()

    app.run(
        host='0.0.0.0',
        port=int(os.environ.get('ARTEA_PORT', '80')),
        debug=False
    )
