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


class SessionTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
