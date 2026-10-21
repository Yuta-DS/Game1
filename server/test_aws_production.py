"""AWS boundary tests use signed tokens and mock AWS clients, not live resources."""
import io
import os
import tempfile
import time
import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch

import jwt as pyjwt
from botocore.exceptions import ClientError
from botocore.response import StreamingBody
from cryptography.hazmat.primitives.asymmetric import rsa
from PIL import Image

temporary = tempfile.TemporaryDirectory()
os.environ.update(DATABASE_URL="sqlite:///" + temporary.name.replace("\\", "/") + "/test.db",
                  ARTEA_TESTING="1", AUTO_CREATE_SCHEMA="false", AWS_REGION="ap-southeast-2",
                  COGNITO_CLIENT_SECRET="test-only-client-secret", COGNITO_POOL_ID="ap-southeast-2_example", COGNITO_CLIENT_ID="exampleclient",
                  ARTWORK_BUCKET="test-private-artwork", ORIGIN_SECRET="test-origin-secret-with-more-than-32-characters",
                  AWS_ACCESS_KEY_ID="test-only", AWS_SECRET_ACCESS_KEY="test-only",
                  AWS_EC2_METADATA_DISABLED="true", JWT_SECRET_KEY="test-only-32-character-secret-not-used-for-RS256")
from server import aws_app as production


class AwsProductionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

    @classmethod
    def tearDownClass(cls):
        with production.app.app_context():
            production.db.session.remove()
            production.db.engine.dispose()
        temporary.cleanup()

    def setUp(self):
        production.app.config["TESTING"] = True
        self.client = production.app.test_client()
        self.origin = {"X-Artea-Origin": production.ORIGIN_SECRET}
        self.cognito = patch.object(production, "cognito").start()
        self.cognito.get_user.return_value = {"Username": "player"}
        self.storage = patch.object(production, "s3").start()
        patch.object(production.keys, "get_signing_key", return_value=SimpleNamespace(key=self.key.public_key())).start()
        self.addCleanup(patch.stopall)
        with production.app.app_context():
            production.db.drop_all()
            production.db.create_all()

    def token(self, sub="player-one", **extra):
        payload = dict(iss=production.ISSUER, sub=sub, username=sub,
                       client_id=production.CLIENT, token_use="access", iat=int(time.time()), exp=int(time.time()) + 3600)
        payload.update(extra)
        return pyjwt.encode(payload, self.key, algorithm="RS256", headers={"kid": "test-key"})

    def headers(self, sub="player-one", **extra):
        return dict(self.origin, Authorization="Bearer " + self.token(sub, **extra))

    def test_origin_is_private_even_for_signup(self):
        self.assertEqual(self.client.post("/api/register", json={}).status_code, 404)
        self.assertEqual(self.client.get("/healthz").status_code, 200)

    def test_signup_keeps_passwords_out_of_database(self):
        response = self.client.post("/api/register", headers=self.origin,
            json=dict(username="player", password="A-test-password!2026", email="player@example.com"))
        self.assertEqual(response.status_code, 201)
        self.assertTrue(response.json["confirmation_required"])
        with production.app.app_context(): self.assertEqual(production.User.query.count(), 0)
        self.assertEqual(self.cognito.sign_up.call_args.kwargs["UserAttributes"][0]["Name"], "email")

    def test_login_refresh_and_confirmation(self):
        self.cognito.initiate_auth.return_value = {"AuthenticationResult": {"AccessToken": "access", "ExpiresIn": 3600, "RefreshToken": "refresh"}}
        response = self.client.post("/api/login", headers=self.origin, json={"username": "player", "password": "secret"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["token"], "access")
        envelope = response.json["refresh_token"]
        self.assertNotEqual(envelope, "refresh")
        self.assertIn("SECRET_HASH", self.cognito.initiate_auth.call_args.kwargs["AuthParameters"])
        response = self.client.post("/api/refresh", headers=self.origin, json={"refresh_token": envelope})
        self.assertEqual(response.status_code, 200)
        self.assertIn("no-store", response.headers["Cache-Control"])
        self.assertEqual(self.client.post("/api/refresh", headers=self.origin, json={"refresh_token": "forged"}).status_code, 401)
        for path, data in [("confirm_registration", {"username": "player", "code": "123456"}), ("reset_password", {"username": "player", "code": "123456", "password": "new-secret"})]:
            self.assertEqual(self.client.post("/api/" + path, headers=self.origin, json=data).status_code, 200)

    def test_account_errors_are_sanitized(self):
        self.cognito.initiate_auth.side_effect = ClientError({"Error": {"Code": "NotAuthorizedException", "Message": "sensitive provider detail"}}, "InitiateAuth")
        response = self.client.post("/api/login", headers=self.origin, json={"username": "player", "password": "wrong"})
        self.assertEqual(response.status_code, 401)
        self.assertNotIn("provider", response.get_data(as_text=True))
        self.assertEqual(self.client.post("/api/register", headers=self.origin, json=[]).status_code, 400)

    def test_wrong_client_id_id_token_and_expired_token_rejected(self):
        for extra in [{"client_id": "another-app"}, {"token_use": "id"}, {"exp": int(time.time()) - 60}, {"iss": "https://attacker.invalid"}]:
            response = self.client.get("/api/my_artworks", headers=self.headers(**extra))
            self.assertIn(response.status_code, [401, 422])
        token = pyjwt.encode({"sub": "fake", "exp": int(time.time()) + 60}, "known-secret-for-algorithm-rejection-test", algorithm="HS256")
        self.assertIn(self.client.get("/api/my_artworks", headers=dict(self.origin, Authorization="Bearer " + token)).status_code, [401, 422])

    def test_private_artwork_is_authorized_and_stored_in_s3(self):
        png = io.BytesIO()
        Image.new("RGB", (8, 8), "red").save(png, format="PNG")
        response = self.client.post("/api/upload_artwork", data=png.getvalue(), headers=dict(self.headers(), **{"Artwork-Title": "My work"}))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.storage.put_object.call_args.kwargs["Bucket"], production.BUCKET)
        self.assertTrue(self.storage.put_object.call_args.kwargs["Key"].startswith("users/1/"))
        with production.app.app_context():
            user = production.User.query.first()
            self.assertEqual(user.password_hash, b"")
            art_id = production.Artwork.query.first().id
        path = f"/api/download_artwork/{art_id}"
        self.assertEqual(self.client.get(path, headers=self.origin).status_code, 404)
        self.assertEqual(self.client.get(path, headers=self.headers("other-player")).status_code, 404)
        self.storage.get_object.return_value = {"Body": StreamingBody(io.BytesIO(png.getvalue()), len(png.getvalue())), "ContentLength": len(png.getvalue())}
        self.assertEqual(self.client.get(path, headers=self.headers()).data, png.getvalue())

    def test_rejects_fake_images(self):
        response = self.client.post("/api/upload_artwork", headers=self.headers(), data=b"not an image")
        self.assertEqual(response.status_code, 400)
        self.storage.put_object.assert_not_called()


if __name__ == "__main__": unittest.main()
