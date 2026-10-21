"""Production adapter. Existing local Flask development remains available.

Passwords live in Cognito, metadata in PostgreSQL, images in private S3.
The CloudFront origin secret prevents bypassing edge WAF through API Gateway.
"""
import hmac
import base64
import hashlib
import io
import os
import warnings
from uuid import uuid4

import boto3
from botocore.exceptions import ClientError
from flask import Response, g, jsonify, request
from flask_jwt_extended import verify_jwt_in_request
from jwt import PyJWKClient, PyJWKClientError
import jwt as token_codec
from flask_jwt_extended.exceptions import JWTDecodeError
from PIL import Image, UnidentifiedImageError
from sqlalchemy.exc import IntegrityError
from sqlalchemy import text

os.environ.setdefault("AUTO_CREATE_SCHEMA", "false")
os.environ["AUTH_PROVIDER"] = "cognito"
os.environ.setdefault("AI_ALLOW_LOOPBACK_GUESTS", "0")
try:
    from .server import app, db, jwt, User, Artwork, current_user_id
except ImportError:
    from server import app, db, jwt, User, Artwork, current_user_id

if not os.environ.get("DB_HOST") and os.environ.get("ARTEA_TESTING") != "1":
    raise RuntimeError("Production requires a durable PostgreSQL database")
if any(os.environ.get(key) for key in ["OMNIROUTE_CREATIVE_GUIDE_API_KEY", "OMNIROUTE_WORLD_BUILDER_API_KEY", "OMNIROUTE_BACKUP_API_KEY"]) and not os.environ.get("OMNIROUTE_BASE_URL", "").startswith("https://"):
    raise RuntimeError("Production AI providers require HTTPS")

REGION = os.environ["AWS_REGION"]
POOL = os.environ["COGNITO_POOL_ID"]
CLIENT = os.environ["COGNITO_CLIENT_ID"]
BUCKET = os.environ["ARTWORK_BUCKET"]
ORIGIN_SECRET = os.environ["ORIGIN_SECRET"]
if len(ORIGIN_SECRET) < 32:
    raise RuntimeError("A strong origin secret is required")
ISSUER = f"https://cognito-idp.{REGION}.amazonaws.com/{POOL}"
keys = PyJWKClient(ISSUER + "/.well-known/jwks.json", cache_keys=True, lifespan=3600)
cognito = boto3.client("cognito-idp", region_name=REGION)
s3 = boto3.client("s3", region_name=REGION)
_client_secret = None
REFRESH_KEY = hmac.new(ORIGIN_SECRET.encode(), b"artea-refresh-envelope-v1", hashlib.sha256).digest()
Image.MAX_IMAGE_PIXELS = 16_000_000
app.config.update(JWT_ALGORITHM="RS256", JWT_DECODE_ISSUER=ISSUER,
                  JWT_IDENTITY_CLAIM="sub", JWT_TOKEN_LOCATION=["headers"])


class PrefixMiddleware:
    def __init__(self, inner): self.inner = inner
    def __call__(self, environ, start_response):
        path = environ.get("PATH_INFO", "")
        if path == "/api" or path.startswith("/api/"):
            environ["SCRIPT_NAME"] = "/api"
            environ["PATH_INFO"] = path[4:] or "/"
        return self.inner(environ, start_response)


app.wsgi_app = PrefixMiddleware(app.wsgi_app)


@app.before_request
def protect_origin():
    if request.path == "/healthz": return None
    if not hmac.compare_digest(request.headers.get("X-Artea-Origin", ""), ORIGIN_SECRET):
        return jsonify(error="Not found"), 404
    if request.path in {"/ai/chat", "/ai/status"}:
        verify_jwt_in_request()


@app.after_request
def private_responses(response):
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response


@app.get("/healthz")
def healthz():
    try: db.session.execute(text("SELECT 1"))
    except Exception:
        db.session.rollback()
        return jsonify(status="database unavailable"), 503
    return jsonify(status="ok")


@jwt.decode_key_loader
def signing_key(header, payload):
    # Never derive a key URL from untrusted token claims or allow HS256.
    if header.get("alg") != "RS256" or payload.get("iss") != ISSUER:
        raise JWTDecodeError("Invalid token issuer or algorithm")
    try: return keys.get_signing_key(header.get("kid", "")).key
    except PyJWKClientError: raise JWTDecodeError("Invalid signing key")


@jwt.token_verification_loader
def access_token_only(header, payload):
    return (payload.get("token_use") == "access"
            and payload.get("client_id") == CLIENT
            and isinstance(payload.get("sub"), str))


@jwt.token_verification_failed_loader
def failed_token(header, payload): return jsonify(error="Sign in again."), 401


@jwt.invalid_token_loader
def invalid_token(reason): return jsonify(error="Sign in again."), 401


@jwt.expired_token_loader
def expired_token(header, payload): return jsonify(error="Your session has expired. Sign in again."), 401


@jwt.user_lookup_loader
def local_profile(header, payload):
    sub = payload["sub"]
    user = User.query.filter_by(cognito_sub=sub).first()
    if user is None:
        user = User(username=payload.get("username", sub), cognito_sub=sub, password_hash=b"")
        db.session.add(user)
        try: db.session.commit()
        except IntegrityError:
            db.session.rollback()
            user = User.query.filter_by(cognito_sub=sub).first()
    if user is not None: g.cognito_user_id = user.id
    return user


def body():
    data = request.get_json(silent=True)
    if not isinstance(data, dict): raise ValueError("A JSON object is required")
    return data


def field(data, name, maximum=256):
    value = data.get(name, "")
    if not isinstance(value, str) or not value or len(value) > maximum:
        raise ValueError(f"A valid {name.replace('_', ' ')} is required")
    return value


def account_action(action):
    def view():
        try: return action(body())
        except ValueError as error: return jsonify(error=str(error)), 400
        except token_codec.InvalidTokenError: return jsonify(error="Sign in again."), 401
        except ClientError as error:
            code = error.response["Error"]["Code"]
            if code == "TooManyRequestsException": return jsonify(error="Please wait before trying again."), 429
            if code in {"NotAuthorizedException", "UserNotFoundException"}:
                return jsonify(error="Invalid username or password."), 401
            if code == "UserNotConfirmedException":
                return jsonify(error="Verify your email before signing in.", confirmation_required=True), 403
            messages = {
                "UsernameExistsException": "This username is unavailable.",
                "InvalidPasswordException": "Use at least 14 characters, including upper and lower case, a number and a symbol.",
                "CodeMismatchException": "The verification code is incorrect.",
                "ExpiredCodeException": "The code has expired. Request another code.",
                "LimitExceededException": "Please wait before requesting another code.",
            }
            return jsonify(error=messages.get(code, "The account request could not be completed. Please try again.")), 400
    return view


def secret_hash(username):
    global _client_secret
    if _client_secret is None:
        _client_secret = os.environ.get("COGNITO_CLIENT_SECRET") or cognito.describe_user_pool_client(
            UserPoolId=POOL, ClientId=CLIENT)["UserPoolClient"]["ClientSecret"]
    return base64.b64encode(hmac.new(_client_secret.encode(), (username + CLIENT).encode(), hashlib.sha256).digest()).decode()


def signup(data):
    username = field(data, "username", 80)
    cognito.sign_up(ClientId=CLIENT, Username=username, SecretHash=secret_hash(username),
                    Password=field(data, "password"),
                    UserAttributes=[{"Name": "email", "Value": field(data, "email")}])
    return jsonify(confirmation_required=True, message="Check your email for a verification code."), 201


def auth_result(result):
    if "AuthenticationResult" not in result:
        return jsonify(error="This account needs an additional sign-in step. Contact support."), 403
    tokens = result["AuthenticationResult"]
    response = {"token": tokens["AccessToken"], "expires_in": tokens["ExpiresIn"]}
    if "RefreshToken" in tokens:
        # The public game receives an opaque refresh envelope, never the app
        # client secret. Canonical username comes from Cognito, not JWT parsing.
        import time
        username = cognito.get_user(AccessToken=tokens["AccessToken"])["Username"]
        response["refresh_token"] = token_codec.encode({"iss": "artea-refresh", "aud": CLIENT,
            "username": username, "refresh": tokens["RefreshToken"], "exp": int(time.time()) + 7 * 86400}, REFRESH_KEY, algorithm="HS256")
    return jsonify(response)


def login(data):
    username = field(data, "username", 80)
    return auth_result(cognito.initiate_auth(ClientId=CLIENT, AuthFlow="USER_PASSWORD_AUTH",
        AuthParameters={"USERNAME": username, "PASSWORD": field(data, "password"), "SECRET_HASH": secret_hash(username)}))


def refresh(data):
    envelope = token_codec.decode(field(data, "refresh_token", 8192), REFRESH_KEY, algorithms=["HS256"], issuer="artea-refresh", audience=CLIENT)
    return auth_result(cognito.initiate_auth(ClientId=CLIENT, AuthFlow="REFRESH_TOKEN_AUTH",
        AuthParameters={"REFRESH_TOKEN": envelope["refresh"], "SECRET_HASH": secret_hash(envelope["username"])}))


def confirm(data):
    username = field(data, "username", 80)
    cognito.confirm_sign_up(ClientId=CLIENT, Username=username, SecretHash=secret_hash(username), ConfirmationCode=field(data, "code", 32))
    return jsonify(message="Email verified.")


def resend(data):
    username = field(data, "username", 80)
    cognito.resend_confirmation_code(ClientId=CLIENT, Username=username, SecretHash=secret_hash(username))
    return jsonify(message="Check your email.")


def forgot(data):
    username = field(data, "username", 80)
    try: cognito.forgot_password(ClientId=CLIENT, Username=username, SecretHash=secret_hash(username))
    except ClientError as error:
        if error.response["Error"]["Code"] not in {"UserNotFoundException", "InvalidParameterException"}: raise
    return jsonify(message="If the account can be recovered, a code has been sent.")


def reset(data):
    username = field(data, "username", 80)
    cognito.confirm_forgot_password(ClientId=CLIENT, Username=username, SecretHash=secret_hash(username),
        ConfirmationCode=field(data, "code", 32), Password=field(data, "password"))
    return jsonify(message="Password changed.")


app.view_functions["login"] = account_action(login)
app.view_functions["register"] = account_action(signup)
for path, action in [("refresh", refresh), ("confirm_registration", confirm),
                     ("resend_confirmation", resend), ("forgot_password", forgot), ("reset_password", reset)]:
    app.add_url_rule("/" + path, path, account_action(action), methods=["POST"])


def image_key(artwork): return f"users/{artwork.user_id}/{artwork.filename}"


def upload():
    verify_jwt_in_request()
    data = request.get_data()
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            image = Image.open(io.BytesIO(data))
            if image.format != "PNG": raise ValueError("Upload a PNG image.")
            image.verify()
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombWarning, Image.DecompressionBombError):
        return jsonify(error="Upload a valid PNG image of at most 16 million pixels."), 400
    art = Artwork(user_id=current_user_id(), title=request.headers.get("Artwork-Title", "Untitled")[:100],
                  filename=uuid4().hex + ".png", is_public=False)
    key = image_key(art)
    s3.put_object(Bucket=BUCKET, Key=key, Body=data, ContentType="image/png", ServerSideEncryption="AES256")
    try:
        db.session.add(art)
        db.session.commit()
    except Exception:
        db.session.rollback()
        s3.delete_object(Bucket=BUCKET, Key=key)
        raise
    return jsonify(message="Artwork uploaded successfully"), 200


def download(artwork_id):
    verify_jwt_in_request(optional=True)
    art = db.session.get(Artwork, artwork_id)
    if art is None or (not art.is_public and getattr(g, "cognito_user_id", None) != art.user_id):
        return jsonify(error="Artwork not found"), 404
    try: result = s3.get_object(Bucket=BUCKET, Key=image_key(art))
    except s3.exceptions.NoSuchKey: return jsonify(error="Artwork not found"), 404
    stream = result["Body"]
    def chunks():
        try: yield from stream.iter_chunks(chunk_size=65536)
        finally: stream.close()
    return Response(chunks(), mimetype="image/png", headers={"Content-Length": str(result["ContentLength"])})


app.view_functions["upload_artwork"] = upload
app.view_functions["download_artwork"] = download
