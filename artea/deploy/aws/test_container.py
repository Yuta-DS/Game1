"""Local Linux/TLS PostgreSQL smoke test. Creates only disposable Docker resources."""
import argparse
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import secrets
import subprocess
import tempfile
import time
import urllib.request
import urllib.error

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", default="artea-api:aws-ready")
    parser.add_argument("--postgres-image", default="postgres:17")
    parser.add_argument("--port", default=8808, type=int)
    args = parser.parse_args()
    suffix = secrets.token_hex(5)
    network, database, api = ("artea-test-" + suffix + ending for ending in ["-network", "-db", "-api"])
    def run(*command, check=True):
        result = subprocess.run(["docker", *command], check=check, capture_output=True, text=True)
        if check and result.returncode: raise RuntimeError(result.stderr)
        return result
    def wait(predicate, seconds=90):
        until = time.monotonic() + seconds
        while time.monotonic() < until:
            if predicate(): return
            time.sleep(1)
        raise RuntimeError("Container readiness timed out")
    created_network = False
    created_containers = []
    with tempfile.TemporaryDirectory(prefix="artea-container-test-") as directory:
        directory = Path(directory)
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "postgres")])
        certificate = (x509.CertificateBuilder().subject_name(name).issuer_name(name)
            .public_key(key.public_key()).serial_number(x509.random_serial_number())
            .not_valid_before(datetime.now(timezone.utc) - timedelta(minutes=1))
            .not_valid_after(datetime.now(timezone.utc) + timedelta(days=1))
            .add_extension(x509.SubjectAlternativeName([x509.DNSName("postgres")]), critical=False)
            .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
            .sign(key, hashes.SHA256()))
        (directory / "server.crt").write_bytes(certificate.public_bytes(serialization.Encoding.PEM))
        (directory / "server.key").write_bytes(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
        owner_password, app_password, origin = (secrets.token_urlsafe(36) for _ in range(3))
        common = dict(DB_HOST="postgres", DB_NAME="artea", DB_SSL_CA="/certs/server.crt", AWS_REGION="ap-southeast-2",
            COGNITO_POOL_ID="ap-southeast-2_test", COGNITO_CLIENT_ID="testclient", ARTWORK_BUCKET="test-private-artwork",
            ORIGIN_SECRET=origin, JWT_SECRET_KEY="unused-cognito-RS256-only-test", AWS_EC2_METADATA_DISABLED="true",
            AWS_ACCESS_KEY_ID="test-only", AWS_SECRET_ACCESS_KEY="test-only", AUTO_CREATE_SCHEMA="false")
        def env_file(name, values):
            target = directory / name
            target.write_text("".join(f"{key}={value}\n" for key, value in values.items()), encoding="utf-8")
            return str(target)
        try:
            run("network", "create", network)
            created_network = True
            pg_env = env_file("pg.env", {"POSTGRES_PASSWORD": owner_password, "POSTGRES_DB": "artea"})
            setup = "cp /certs/server.crt /tmp/server.crt; cp /certs/server.key /tmp/server.key; chmod 600 /tmp/server.key; chown postgres:postgres /tmp/server.key /tmp/server.crt; exec docker-entrypoint.sh postgres -c ssl=on -c ssl_cert_file=/tmp/server.crt -c ssl_key_file=/tmp/server.key"
            run("run", "-d", "--name", database, "--network", network, "--network-alias", "postgres", "--env-file", pg_env,
                "-v", f"{directory}:/certs:ro", args.postgres_image, "bash", "-c", setup)
            created_containers.append(database)
            wait(lambda: run("exec", database, "pg_isready", "-U", "postgres", check=False).returncode == 0)
            migration_env = env_file("migration.env", dict(common, DB_USERNAME="postgres", DB_PASSWORD=owner_password, APP_DB_PASSWORD=app_password))
            run("run", "--rm", "--network", network, "--env-file", migration_env, "-v", f"{directory}:/certs:ro", args.image, "python", "manage_aws.py")
            print("PASS: TLS database schema and restricted role bootstrap", flush=True)
            runtime_env = env_file("runtime.env", dict(common, DB_USERNAME="artea_app", DB_PASSWORD=app_password))
            run("run", "-d", "--name", api, "--network", network, "--env-file", runtime_env, "-v", f"{directory}:/certs:ro",
                "-p", f"127.0.0.1:{args.port}:8000", args.image)
            created_containers.append(api)
            def healthy():
                try:
                    with urllib.request.urlopen(f"http://127.0.0.1:{args.port}/healthz", timeout=2) as response:
                        return json.load(response).get("status") == "ok"
                except Exception: return False
            wait(healthy)
            print("PASS: Gunicorn readiness includes verified TLS PostgreSQL access", flush=True)
            for headers, expected in [({}, 404), ({"X-Artea-Origin": origin}, 401)]:
                try: urllib.request.urlopen(urllib.request.Request(f"http://127.0.0.1:{args.port}/api/my_artworks", headers=headers), timeout=5)
                except urllib.error.HTTPError as error:
                    if error.code != expected: raise RuntimeError(f"Unexpected access status: {error.code}")
                else: raise RuntimeError("Private endpoint accepted unauthenticated request")
            print("PASS: origin isolation and authentication enforced in Linux container", flush=True)
            permission_test = "from server import app,db; from sqlalchemy import text; from sqlalchemy.exc import ProgrammingError; ctx=app.app_context(); ctx.push(); db.session.execute(text('CREATE TABLE forbidden_table(id int)'))"
            result = run("exec", api, "python", "-c", permission_test, check=False)
            if result.returncode == 0 or "permission denied" not in result.stderr.lower():
                raise RuntimeError("Runtime database role privilege check failed")
            print("PASS: runtime role cannot create schema objects", flush=True)
        finally:
            for name in reversed(created_containers): run("rm", "-f", "-v", name, check=False)
            if created_network: run("network", "rm", network, check=False)


if __name__ == "__main__": main()
