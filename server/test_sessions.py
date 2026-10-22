"""One login per account (newest wins) and private artwork downloads.

Run on its own, so the temporary database below is the one the server opens:
    server/venv/Scripts/python.exe -m unittest server.test_sessions
"""
import os
import tempfile
import unittest

# Windows keeps the database file locked until the process ends.
_TEMP = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
os.environ["DATABASE_URL"] = "sqlite:///" + os.path.join(_TEMP.name, "sessions_test.db")

import jwt as pyjwt  # noqa: E402
from flask_jwt_extended import create_access_token  # noqa: E402

from server import server  # noqa: E402

PASSWORD = "Passw0rd!long-enough"
# A real 1x1 PNG, so nothing about the upload depends on image validation.
PNG = bytes.fromhex(
    "89504e470d0a1a0a0000000d4948445200000001000000010806000000"
    "1f15c4890000000d49444154789c6360f8cf00000301010018dd8db40000"
    "000049454e44ae426082")


def bearer(token):
    return {"Authorization": f"Bearer {token}"}


class AccountTestCase(unittest.TestCase):
    """A test client, a temporary uploads folder and a login helper."""

    def setUp(self):
        server.app.config["TESTING"] = True
        self.client = server.app.test_client()
        self.uploads = tempfile.TemporaryDirectory()
        self.original_uploads = server.UPLOAD_FOLDER
        server.UPLOAD_FOLDER = self.uploads.name

    def tearDown(self):
        server.UPLOAD_FOLDER = self.original_uploads
        self.uploads.cleanup()

    def login(self, username):
        self.client.post("/register", json={"username": username, "password": PASSWORD})
        response = self.client.post("/login", json={"username": username, "password": PASSWORD})
        self.assertEqual(response.status_code, 200, response.get_json())
        return response.get_json()["token"]


class SessionTests(AccountTestCase):
    def test_newest_login_signs_out_the_older_one(self):
        first = self.login("sam")
        self.assertEqual(self.client.get("/session", headers=bearer(first)).status_code, 200)
        second = self.login("sam")
        self.assertEqual(self.client.get("/session", headers=bearer(second)).status_code, 200)
        older = self.client.get("/session", headers=bearer(first))
        self.assertEqual(older.status_code, 401)
        self.assertEqual(older.get_json()["error"], "signed_in_elsewhere")
        # Every route that needs a login refuses the older token, not just /session.
        self.assertEqual(self.client.get("/my_artworks", headers=bearer(first)).status_code, 401)

    def test_with_three_logins_only_the_newest_stays_signed_in(self):
        first, second, third = (self.login("kit") for _ in range(3))
        for name, token in (("first", first), ("second", second)):
            response = self.client.get("/session", headers=bearer(token))
            self.assertEqual(response.status_code, 401, f"{name} login should be signed out")
            self.assertEqual(response.get_json()["error"], "signed_in_elsewhere")
        self.assertEqual(self.client.get("/session", headers=bearer(third)).status_code, 200)

    def test_other_accounts_are_unaffected(self):
        alex = self.login("alex")
        self.login("blair")
        self.assertEqual(self.client.get("/session", headers=bearer(alex)).status_code, 200)

    def test_tokens_from_before_sessions_stop_at_the_next_login(self):
        self.login("casey")
        with server.app.app_context():
            user = server.User.query.filter_by(username="casey").first()
            server.db.session.delete(server.db.session.get(server.ActiveSession, user.id))
            server.db.session.commit()
            untagged = create_access_token(identity=str(user.id))
        # Issued before this check existed and never superseded: still valid...
        self.assertEqual(self.client.get("/session", headers=bearer(untagged)).status_code, 200)
        self.login("casey")
        # ...until the account logs in again.
        self.assertEqual(self.client.get("/session", headers=bearer(untagged)).status_code, 401)

    def test_artwork_is_only_downloadable_by_its_owner(self):
        owner = self.login("dana")
        stranger = self.login("eli")
        uploaded = self.client.post("/upload_artwork", data=PNG, headers={
            **bearer(owner), "Content-Type": "image/png", "Artwork-Title": "Heart"})
        self.assertEqual(uploaded.status_code, 200, uploaded.get_json())
        listing = self.client.get("/my_artworks", headers=bearer(owner)).get_json()
        url = listing[0]["url"]
        self.assertEqual(self.client.get(url, headers=bearer(owner)).status_code, 200)
        self.assertEqual(self.client.get(url, headers=bearer(stranger)).status_code, 404)
        self.assertEqual(self.client.get(url).status_code, 404)
        self.assertEqual(self.client.get("/my_artworks", headers=bearer(stranger)).get_json(), [])


class TamperingTests(AccountTestCase):
    """What a player could try by editing the game's JavaScript or calling the
    API directly: nothing the game itself checks counts, only the server."""

    PROTECTED = [("get", "/session"), ("get", "/my_artworks"), ("post", "/upload_artwork")]

    def assertRefused(self, headers, why):
        for method, path in self.PROTECTED:
            response = getattr(self.client, method)(path, headers=headers, data=PNG)
            self.assertIn(response.status_code, (401, 422), f"{why}: {method.upper()} {path}")

    def owner_with_artwork(self):
        owner = self.login("frankie")
        self.client.post("/upload_artwork", data=PNG, headers={
            **bearer(owner), "Content-Type": "image/png", "Artwork-Title": "Private"})
        return owner, self.client.get("/my_artworks", headers=bearer(owner)).get_json()[0]["url"]

    def test_no_token_or_the_guest_placeholder_is_refused(self):
        self.assertRefused({}, "no token")
        self.assertRefused(bearer("OFFLINE_GUEST_TOKEN"), "guest placeholder")

    def test_a_token_signed_with_another_key_is_refused(self):
        real = self.login("gale")
        payload = pyjwt.decode(real, options={"verify_signature": False})
        forged = pyjwt.encode(payload, "a-guessed-secret-key-of-32-plus-characters", algorithm="HS256")
        self.assertRefused(bearer(forged), "forged signature")

    def test_an_unsigned_token_is_refused(self):
        real = self.login("harper")
        payload = pyjwt.decode(real, options={"verify_signature": False})
        unsigned = pyjwt.encode(payload, None, algorithm="none")
        self.assertRefused(bearer(unsigned), "alg none")

    def test_editing_the_token_to_another_account_is_refused(self):
        _owner, url = self.owner_with_artwork()
        intruder = self.login("indy")
        payload = pyjwt.decode(intruder, options={"verify_signature": False})
        with server.app.app_context():
            payload["sub"] = str(server.User.query.filter_by(username="frankie").first().id)
        # Re-signed it can't be (the key never leaves the server), so the
        # edited token keeps the intruder's now-invalid signature.
        header, _body, signature = intruder.split(".")
        edited = ".".join([header, pyjwt.encode(payload, "x" * 32, algorithm="HS256").split(".")[1], signature])
        self.assertRefused(bearer(edited), "edited account id")
        self.assertIn(self.client.get(url, headers=bearer(edited)).status_code, (401, 404, 422))

    def test_artwork_ids_cannot_be_walked(self):
        _owner, url = self.owner_with_artwork()
        intruder = self.login("jules")
        artwork_id = int(url.rsplit("/", 1)[1])
        for guess in range(max(1, artwork_id - 3), artwork_id + 4):
            self.assertEqual(self.client.get(f"/download_artwork/{guess}", headers=bearer(intruder)).status_code,
                404, f"artwork {guess} must not reach another account")


if __name__ == "__main__":
    unittest.main()
